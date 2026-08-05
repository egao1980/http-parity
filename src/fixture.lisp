(in-package #:http-parity)

;;; Minimal httpbin-shaped cleartext origin for deterministic parity tests.
;;; Prefer this over live HTTPS (httpbingo Fly edge often 402s our async TLS).

(defvar *fixture-thread* nil)
(defvar *fixture-socket* nil)
(defvar *fixture-port* nil)
(defvar *fixture-base* nil
  "http://127.0.0.1:<port> when fixture is running.")

(defun fixture-enabled-p ()
  "T unless HTTP_PARITY_FIXTURE is 0/false/no/off.
   Default ON — local origin. Set 0 + HTTP_PARITY_BASE for public live."
  (let ((v (uiop:getenv "HTTP_PARITY_FIXTURE")))
    (not (member v '("0" "false" "no" "off") :test #'string-equal))))

(defun %read-line-octets (stream)
  (let ((out (make-array 0 :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0)))
    (loop for b = (read-byte stream nil nil)
          while b
          do (vector-push-extend b out)
             (when (and (>= (length out) 2)
                        (= (aref out (- (length out) 2)) 13)
                        (= (aref out (- (length out) 1)) 10))
               (return)))
    (when (plusp (length out))
      (babel:octets-to-string out :encoding :utf-8 :errorp nil))))

(defun %split-space (string)
  (loop for start = 0 then (1+ pos)
        for pos = (position #\Space string :start start)
        collect (subseq string start (or pos (length string)))
        while pos))

(defun %header (headers name)
  (cdr (assoc name headers :test #'string-equal)))

(defun %query (path)
  "Return (values path-without-query query-string)."
  (let ((q (position #\? path)))
    (if q
        (values (subseq path 0 q) (subseq path (1+ q)))
        (values path nil))))

(defun %query-param (query key)
  (when query
    (loop for part in (uiop:split-string query :separator "&")
          for eq = (position #\= part)
          when eq
            do (when (string-equal key (subseq part 0 eq))
                 (return (quri:url-decode (subseq part (1+ eq))))))))

(defun %json-escape (s)
  (with-output-to-string (out)
    (write-char #\" out)
    (loop for c across (string s)
          do (case c
               (#\" (write-string "\\\"" out))
               (#\\ (write-string "\\\\" out))
               (#\Newline (write-string "\\n" out))
               (t (write-char c out))))
    (write-char #\" out)))

(defun %octets (string)
  (babel:string-to-octets string :encoding :utf-8))

(defun %ensure-chipz ()
  (ignore-errors (asdf:load-system "http-encoding-chipz") t))

(defun %md5-hex (string)
  (unless (find-package :ironclad)
    (asdf:load-system "ironclad"))
  (let* ((digest-sequence (find-symbol "DIGEST-SEQUENCE" :ironclad))
         (bytes->hex (find-symbol "BYTE-ARRAY-TO-HEX-STRING" :ironclad))
         (octets (babel:string-to-octets string :encoding :utf-8))
         (digest (funcall digest-sequence :md5 octets)))
    (funcall bytes->hex digest)))

(defun %b64-decode (s)
  (asdf:load-system "cl-base64")
  (let ((fn (or (find-symbol "BASE64-STRING-TO-STRING" :cl-base64)
                (error "cl-base64:BASE64-STRING-TO-STRING missing"))))
    (funcall fn s)))

(defun %basic-ok-p (headers user pass)
  "Accept Authorization: Basic <b64(user:pass)> (case-insensitive scheme)."
  (let ((auth (%header headers "authorization")))
    (when (and auth
               (>= (length auth) 6)
               (eql 0 (search "basic " (string-downcase auth) :test #'char=)))
      (handler-case
          (equal (format nil "~A:~A" user pass)
                 (%b64-decode (string-trim '(#\Space #\Tab)
                                           (subseq auth 6))))
        (error (e)
          (warn "parity fixture basic-auth decode failed: ~A" e)
          nil)))))

(defun %digest-ok-p (headers method path user pass realm nonce)
  (let ((auth (%header headers "authorization")))
    (unless (and auth (search "digest" (string-downcase auth) :test #'char=))
      (return-from %digest-ok-p nil))
    (let* ((parse (find-symbol "%PARSE-AUTH-PARAMS" :cl-stack-http))
           (plist (when (and parse (fboundp parse))
                    (funcall parse auth)))
           (uri (or (getf plist :uri) path))
           (resp (getf plist :response))
           (ha1 (%md5-hex (format nil "~A:~A:~A" user realm pass)))
           (ha2 (%md5-hex (format nil "~A:~A" (string-upcase (string method)) uri)))
           (expect (%md5-hex (format nil "~A:~A:~A" ha1 nonce ha2))))
      (and resp (string-equal resp expect)))))

(defun %parity-handler (method path headers body)
  "httpbingo/httpbin-shaped routes used by http-parity tests."
  (multiple-value-bind (api-status api-hdrs api-body)
      (%demo-api-handler method path headers body)
    (when api-status
      (return-from %parity-handler (values api-status api-hdrs api-body))))
  (multiple-value-bind (path* query) (%query path)
    (cond
      ((member path* '("/get" "/headers") :test #'string=)
       (let* ((args (if query
                        ;; httpbin: repeated keys → JSON array (valid for yason)
                        (let ((bag (make-hash-table :test #'equal)))
                          (loop for part in (uiop:split-string query :separator "&")
                                for eq = (position #\= part)
                                when eq
                                  do (let ((k (quri:url-decode (subseq part 0 eq)))
                                           (v (quri:url-decode (subseq part (1+ eq)))))
                                       (setf (gethash k bag)
                                             (nconc (gethash k bag) (list v)))))
                          (format nil "{~{~A~^,~}}"
                                  (loop for k being the hash-keys of bag using (hash-value vs)
                                        collect (format nil "~A:~A"
                                                        (%json-escape k)
                                                        (if (cdr vs)
                                                            (format nil "[~{~A~^,~}]"
                                                                    (mapcar #'%json-escape vs))
                                                            (%json-escape (first vs)))))))
                        "{}"))
              (payload (format nil "{\"url\":~A,\"args\":~A,\"headers\":{}}"
                               (%json-escape
                                (if query
                                    (format nil "~A~A?~A" *fixture-base* path* query)
                                    (format nil "~A~A" *fixture-base* path*)))
                               args)))
         (values 200 '(("content-type" . "application/json")) (%octets payload))))

      ((member path* '("/post" "/put" "/patch" "/delete") :test #'string=)
       (let* ((text (if body
                        (babel:octets-to-string body :encoding :utf-8 :errorp nil)
                        ""))
              (payload (format nil "{\"url\":~A,\"data\":~A,\"files\":{},\"form\":{}}"
                               (%json-escape (format nil "~A~A" *fixture-base* path*))
                               (%json-escape text))))
         (values 200 '(("content-type" . "application/json")) (%octets payload))))

      ((string= path* "/json")
       (values 200 '(("content-type" . "application/json"))
               (%octets "{\"slideshow\":{\"title\":\"parity\"}}")))

      ((string= path* "/gzip")
       (if (and (%ensure-chipz) (content-coding-supported-p :gzip))
           (values 200
                   '(("content-type" . "application/json")
                     ("content-encoding" . "gzip"))
                   (encode-content-coding :gzip (%octets "{\"gzipped\": true}")))
           (values 501 '(("content-type" . "text/plain")) (%octets "no gzip"))))

      ((string= path* "/deflate")
       (if (and (%ensure-chipz) (content-coding-supported-p :deflate))
           (values 200
                   '(("content-type" . "application/json")
                     ("content-encoding" . "deflate"))
                   (encode-content-coding :deflate (%octets "{\"deflated\": true}")))
           (values 501 '(("content-type" . "text/plain")) (%octets "no deflate"))))

      ((string= path* "/brotli")
       (values 404 '(("content-type" . "text/plain")) (%octets "no brotli fixture")))

      ((or (and (>= (length path*) 7) (string= (subseq path* 0 7) "/bytes/"))
           (and (>= (length path*) 14) (string= (subseq path* 0 14) "/stream-bytes/")))
       (let* ((n-str (subseq path* (1+ (position #\/ path* :from-end t))))
              (n (max 0 (or (parse-integer n-str :junk-allowed t) 0)))
              (buf (make-array n :element-type '(unsigned-byte 8))))
         (loop for i below n do (setf (aref buf i) (mod i 256)))
         (values 200 '(("content-type" . "application/octet-stream")) buf)))

      ((and (>= (length path*) 12) (string= (subseq path* 0 12) "/cookies/set"))
       (let* ((name (or (%query-param query "session") "session"))
              (val (or (%query-param query "session")
                       (%query-param query name)
                       "parity"))
              ;; /cookies/set?session=parity → Set-Cookie: session=parity
              (cookie (format nil "session=~A; Path=/" val)))
         (values 200
                 (list (cons "content-type" "text/plain")
                       (cons "set-cookie" cookie))
                 (%octets "set"))))

      ((string= path* "/cookies")
       (values 200 '(("content-type" . "application/json"))
               (%octets (format nil "{\"cookies\":{\"raw\":~A}}"
                                (%json-escape (or (%header headers "cookie") ""))))))

      ((and (>= (length path*) 10) (string= (subseq path* 0 10) "/redirect/"))
       (let* ((n (or (parse-integer (subseq path* 10) :junk-allowed t) 0))
              (loc (if (<= n 1) "/get" (format nil "/redirect/~D" (1- n)))))
         (values 302
                 (list (cons "location" loc)
                       (cons "content-type" "text/plain"))
                 (%octets "go"))))

      ((and (>= (length path*) 12) (string= (subseq path* 0 12) "/basic-auth/"))
       (let* ((rest (subseq path* 12))
              (slash (position #\/ rest))
              (user (if slash (subseq rest 0 slash) "user"))
              (pass (if slash (subseq rest (1+ slash)) "pass")))
         (if (%basic-ok-p headers user pass)
             (values 200 '(("content-type" . "application/json"))
                     (%octets "{\"authenticated\": true}"))
             (values 401
                     '(("www-authenticate" . "Basic realm=\"parity\"")
                       ("content-type" . "text/plain"))
                     (%octets "unauthorized")))))

      ((string= path* "/bearer")
       (let ((auth (%header headers "authorization")))
         (if (and auth (search "bearer" (string-downcase auth) :test #'char=))
             (values 200 '(("content-type" . "application/json"))
                     (%octets "{\"authenticated\": true}"))
             (values 401 '(("content-type" . "text/plain"))
                     (%octets "unauthorized")))))

      ((and (>= (length path*) 18)
            (string= (subseq path* 0 18) "/digest-auth/auth/"))
       (let* ((rest (subseq path* 18))
              (slash (position #\/ rest))
              (user (if slash (subseq rest 0 slash) "user"))
              (pass (if slash (subseq rest (1+ slash)) "pass"))
              (realm "parity")
              (nonce "deadbeef"))
         (if (%digest-ok-p headers method path* user pass realm nonce)
             (values 200 '(("content-type" . "application/json"))
                     (%octets "{\"authenticated\": true}"))
             (values 401
                     (list (cons "www-authenticate"
                                 (format nil "Digest realm=\"~A\", nonce=\"~A\", algorithm=MD5"
                                         realm nonce))
                           (cons "content-type" "text/plain"))
                     (%octets "unauthorized")))))

      ((and (>= (length path*) 8) (string= (subseq path* 0 8) "/status/"))
       (let ((code (or (parse-integer (subseq path* 8) :junk-allowed t) 200)))
         (values code '(("content-type" . "text/plain"))
                 (%octets (format nil "status ~A" code)))))

      ((and (>= (length path*) 7) (string= (subseq path* 0 7) "/delay/"))
       (let ((sec (or (ignore-errors (read-from-string (subseq path* 7))) 0)))
         (sleep (min (float sec 1.0d0) 30.0d0))
         (values 200 '(("content-type" . "application/json"))
                 (%octets "{\"delayed\": true}"))))

      (t
       (values 404 '(("content-type" . "text/plain")) (%octets "nope"))))))

(defun %serve-one (stream)
  (handler-case
      (let* ((req-line (%read-line-octets stream))
             (headers nil)
             (content-length 0))
        (unless req-line (return-from %serve-one nil))
        (loop for line = (%read-line-octets stream)
              while (and line
                         (not (string= line (format nil "~C~C" #\Return #\Newline)))
                         (not (string= line (string #\Newline)))
                         (> (length line) 2))
              do (let* ((s (string-right-trim '(#\Return #\Newline) line))
                        (colon (position #\: s)))
                   (when colon
                     (let ((name (string-downcase (subseq s 0 colon)))
                           (val (string-trim '(#\Space #\Tab) (subseq s (1+ colon)))))
                       (push (cons name val) headers)
                       (when (string= name "content-length")
                         (setf content-length
                               (or (parse-integer val :junk-allowed t) 0)))))))
        (let* ((parts (%split-space (string-right-trim '(#\Return #\Newline) req-line)))
               (method (intern (string-upcase (first parts)) :keyword))
               (raw-target (second parts))
               (path (or raw-target "/"))
               (body (when (plusp content-length)
                       (let ((buf (make-array content-length
                                              :element-type '(unsigned-byte 8))))
                         (read-sequence buf stream)
                         buf))))
          (multiple-value-bind (status hdrs resp-body)
              (%parity-handler method path (nreverse headers) body)
            (let* ((body* (or resp-body #()))
                   (hdr-str
                    (with-output-to-string (s)
                      (format s "HTTP/1.1 ~D ~A~C~C"
                              status
                              (if (<= 200 status 299) "OK" "ERR")
                              #\Return #\Newline)
                      (dolist (h hdrs)
                        (format s "~A: ~A~C~C" (car h) (cdr h)
                                #\Return #\Newline))
                      (unless (assoc "content-length" hdrs :test #'string-equal)
                        (format s "Content-Length: ~D~C~C" (length body*)
                                #\Return #\Newline))
                      (format s "Connection: close~C~C~C~C"
                              #\Return #\Newline #\Return #\Newline)))
                   (head (%octets hdr-str)))
              (write-sequence head stream)
              (write-sequence body* stream)
              (force-output stream)
              nil))))
    (error () nil)))

(defun stop-fixture ()
  (let ((s *fixture-socket*))
    (setf *fixture-socket* nil
          *fixture-port* nil
          *fixture-base* nil)
    (when s (ignore-errors (usocket:socket-close s)))
    (when (and *fixture-thread* (bt:thread-alive-p *fixture-thread*))
      (ignore-errors (bt:destroy-thread *fixture-thread*))
      (setf *fixture-thread* nil)))
  (values))

(defun start-fixture (&key (host "127.0.0.1"))
  (when *fixture-thread*
    (stop-fixture))
  ;; Basic-auth path needs cl-base64 in the accept thread — load now.
  (asdf:load-system "cl-base64")
  (reset-demo-api)
  (let* ((server (usocket:socket-listen host 0
                                        :reuseaddress t
                                        :element-type '(unsigned-byte 8)))
         (port (usocket:get-local-port server)))
    (setf *fixture-socket* server
          *fixture-port* port
          *fixture-base* (format nil "http://~A:~A" host port)
          *fixture-thread*
          (bt:make-thread
           (lambda ()
             (loop
               (when (null *fixture-socket*) (return))
               (handler-case
                   (let ((client (usocket:socket-accept
                                  server :element-type '(unsigned-byte 8))))
                     (unwind-protect
                          (%serve-one (usocket:socket-stream client))
                       (ignore-errors (usocket:socket-close client))))
                 (error ()
                   (when (null *fixture-socket*) (return))))))
           :name "http-parity-fixture"))
    *fixture-base*))

(defun ensure-fixture ()
  "Start local fixture when enabled; bind *live-base* to it. Returns base URL."
  (cond
    ((not (fixture-enabled-p))
     *live-base*)
    (*fixture-base*
     (setf *live-base* *fixture-base*)
     *fixture-base*)
    (t
     (let ((base (start-fixture)))
       (setf *live-base* base)
       base))))
