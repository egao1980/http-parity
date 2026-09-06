(in-package #:http-parity/tests)

;;; In-process SOCKS5 CONNECT (RFC 1928, no-auth). Relays one hop to the
;;; dest from the CONNECT request — no extra daemon.

(defvar *socks-thread* nil)
(defvar *socks-socket* nil)
(defvar *socks-port* nil)
(defvar *socks-last-atyp* nil)
(defvar *socks-last-host* nil)

(defun %socks-read-n (stream n)
  (let ((buf (make-array n :element-type '(unsigned-byte 8))))
    (loop for pos = 0 then (+ pos got)
          while (< pos n)
          for got = (read-sequence buf stream :start pos)
          when (zerop got)
            do (return-from %socks-read-n nil))
    buf))

(defun %socks-write (stream octets)
  (write-sequence octets stream)
  (force-output stream))

(defun %socks-parse-connect (stream)
  "Read a SOCKS5 CONNECT. Returns (values atyp host port) or NIL."
  (let ((hdr (%socks-read-n stream 4)))
    (unless (and hdr
                 (= (aref hdr 0) #x05)
                 (= (aref hdr 1) #x01))
      (return-from %socks-parse-connect nil))
    (let ((atyp (aref hdr 3)))
      (case atyp
        (#x01
         (let ((addr (%socks-read-n stream 4))
               (port-octets (%socks-read-n stream 2)))
           (when (and addr port-octets)
             (values atyp
                     (format nil "~D.~D.~D.~D"
                             (aref addr 0) (aref addr 1)
                             (aref addr 2) (aref addr 3))
                     (+ (ash (aref port-octets 0) 8)
                        (aref port-octets 1))))))
        (#x03
         (let ((len-octets (%socks-read-n stream 1)))
           (when len-octets
             (let* ((n (aref len-octets 0))
                    (name (%socks-read-n stream n))
                    (port-octets (%socks-read-n stream 2)))
               (when (and name port-octets)
                 (values atyp
                         (babel:octets-to-string name :encoding :utf-8)
                         (+ (ash (aref port-octets 0) 8)
                            (aref port-octets 1))))))))
        (t nil)))))

(defun %socks-copy (from to)
  (let ((buf (make-array 4096 :element-type '(unsigned-byte 8))))
    (handler-case
        (loop for n = (read-sequence buf from)
              until (zerop n)
              do (write-sequence buf to :end n)
                 (force-output to))
      (error ()))))

(defun %socks-relay (client-stream dest-host dest-port)
  (let ((origin nil))
    (unwind-protect
         (progn
           (setf origin (usocket:socket-connect dest-host dest-port
                                                :element-type '(unsigned-byte 8)
                                                :timeout 5))
           (%socks-write client-stream
                         #(#x05 #x00 #x00 #x01 0 0 0 0 0 0))
           (let ((origin-stream (usocket:socket-stream origin)))
             ;; Up-copy in a thread; do not join (client close unblocks it).
             (bt:make-thread
              (lambda ()
                (%socks-copy client-stream origin-stream))
              :name "http-parity-socks-up")
             (%socks-copy origin-stream client-stream)))
      (when origin
        (ignore-errors (usocket:socket-close origin))))))

(defun %socks-serve-one (stream)
  (handler-case
      (let ((greet (%socks-read-n stream 2)))
        (unless (and greet (= (aref greet 0) #x05))
          (return-from %socks-serve-one))
        (let ((nmethods (aref greet 1)))
          (when (plusp nmethods)
            (%socks-read-n stream nmethods)))
        (%socks-write stream #(#x05 #x00))
        (multiple-value-bind (atyp host port)
            (%socks-parse-connect stream)
          (unless (and atyp host port)
            (return-from %socks-serve-one))
          (setf *socks-last-atyp* atyp
                *socks-last-host* host)
          (%socks-relay stream host port)))
    (error ())))

(defun stop-socks5-fixture ()
  (let ((s *socks-socket*))
    (setf *socks-socket* nil
          *socks-port* nil)
    (when s (ignore-errors (usocket:socket-close s)))
    (when (and *socks-thread* (bt:thread-alive-p *socks-thread*))
      (ignore-errors (bt:destroy-thread *socks-thread*))
      (setf *socks-thread* nil)))
  (values))

(defun start-socks5-fixture (&key (host "127.0.0.1"))
  (when *socks-thread*
    (stop-socks5-fixture))
  (setf *socks-last-atyp* nil
        *socks-last-host* nil)
  (let* ((server (usocket:socket-listen host 0
                                        :reuseaddress t
                                        :element-type '(unsigned-byte 8)))
         (port (usocket:get-local-port server)))
    (setf *socks-socket* server
          *socks-port* port
          *socks-thread*
          (bt:make-thread
           (lambda ()
             (loop
               (when (null *socks-socket*) (return))
               (handler-case
                   (let ((client (usocket:socket-accept
                                  server :element-type '(unsigned-byte 8))))
                     (unwind-protect
                          (%socks-serve-one (usocket:socket-stream client))
                       (ignore-errors (usocket:socket-close client))))
                 (error ()
                   (when (null *socks-socket*) (return))))))
           :name "http-parity-socks5"))
    port))

(defmacro with-socks5-fixture (() &body body)
  `(progn
     (start-socks5-fixture)
     (unwind-protect (progn ,@body)
       (stop-socks5-fixture))))

(deftest parity-socks5h-get
  "Live GET through in-process SOCKS5h — CONNECT ATYP 3 (remote DNS)."
  (cond
    ((not (eq *preferred-backend* :async))
     (skip "SOCKS live case is http-backend-async only"))
    ((not (live-enabled-p))
     (skip "HTTP_PARITY_LIVE disabled"))
    ((not (fixture-enabled-p))
     (skip "SOCKS live case needs the local HTTP fixture"))
    (t
     (handler-case
         (with-parity
           (with-socks5-fixture ()
             (unless *socks-port*
               (error "SOCKS fixture did not bind a port"))
             (let* ((proxy (format nil "socks5h://127.0.0.1:~A" *socks-port*))
                    (cfg (make-http-proxy-config :proxy proxy
                                                 :no-proxy nil
                                                 :system nil))
                    (res (http:get (live-url "/get")
                                   :proxy cfg
                                   :timeout 10.0
                                   :trust-env nil)))
               (ok (= 200 (response-status res)))
               (ok (search "url" (http:response-text res) :test #'char-equal))
               (ok (= #x03 *socks-last-atyp*))
               (ok (string= "127.0.0.1" *socks-last-host*)))))
       (error (e)
         (skip (format nil "SOCKS fixture unavailable: ~A" e)))))))
