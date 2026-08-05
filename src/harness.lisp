(in-package #:http-parity)

;;; Live harness patterned on http-backend-async live tests + cl-stack-http DX.
;;; Prefer :async (libuv). Set HTTP_PARITY_BACKEND=dexador|winhttp to override.
;;; Event engine: HTTP_ASYNC_EVENT_BACKEND / HTTP_PARITY_EVENT_BACKEND = libuv|libev.
;;; Origin: local fixture by default (HTTP_PARITY_FIXTURE); else HTTP_PARITY_BASE.

(defvar *preferred-backend*
  (let ((v (uiop:getenv "HTTP_PARITY_BACKEND")))
    (if (and v (plusp (length v)))
        (intern (string-upcase v) :keyword)
        :async))
  "Backend keyword for WITH-PARITY (:async default).")

(defvar *live-base*
  (or (uiop:getenv "HTTP_PARITY_BASE") "https://httpbingo.org")
  "Origin for cases. Overridden by ENSURE-FIXTURE when fixture mode is on.")

(defun live-enabled-p ()
  "T unless HTTP_PARITY_LIVE is 0/false/no/off."
  (let ((v (uiop:getenv "HTTP_PARITY_LIVE")))
    (not (member v '("0" "false" "no" "off") :test #'string-equal))))

(defun live-url (path)
  (concatenate 'string *live-base* path))

(defun %event-backend-key ()
  (let ((v (or (uiop:getenv "HTTP_PARITY_EVENT_BACKEND")
               (uiop:getenv "HTTP_ASYNC_EVENT_BACKEND")
               "libuv")))
    (intern (string-upcase v) :keyword)))

(defun %make-event-backend ()
  "Load + construct libuv (default) or libev event backend."
  (let* ((key (%event-backend-key))
         (sys (ecase key
                (:libuv "event-backend-libuv")
                (:libev "event-backend-libev")))
         (pkg (ecase key
                (:libuv :event-backend-libuv)
                (:libev :event-backend-libev)))
         (maker-name (ecase key
                       (:libuv "MAKE-LIBUV-BACKEND")
                       (:libev "MAKE-LIBEV-BACKEND"))))
    (asdf:load-system sys)
    (funcall (symbol-function (find-symbol maker-name pkg)))))

(defmacro with-parity (&body body)
  "Bind stack-http backend + codecs. For :async, bind event backend+loop+maker
   like http-backend-async's WITH-ASYNC-TEST (required for sync SEND and AWAIT)."
  `(progn
     (ensure-fixture)
     (if (eq *preferred-backend* :async)
         (let* ((eb (%make-event-backend))
                (el (event-protocol:make-event-loop eb))
                (http-backend-async:*event-backend-maker* (lambda () eb)))
           (event-protocol:with-event-backend (eb)
             (event-protocol:with-event-loop-var (el)
               (stack:with-backend (:async)
                 (stack:with-default-codecs ()
                   ,@body)))))
         (stack:with-backend (*preferred-backend*)
           (stack:with-default-codecs ()
             ,@body)))))

(defun await (promise &key (timeout 25.0))
  "Run event loop until PROMISE resolves (async API path). Sync SEND already awaits."
  (multiple-value-bind (eb el)
      (funcall (find-symbol "%ENSURE-EVENT-CONTEXT" :http-backend-async))
    (let ((result nil)
          (err nil)
          (done nil))
      (blackbird:catcher
        (blackbird:attach promise
                          (lambda (v)
                            (setf result v done t)
                            (event-protocol:stop eb el)))
        (error (e)
          (setf err e done t)
          (event-protocol:stop eb el)))
      (event-protocol:sleep* eb el timeout
                             :callback (lambda ()
                                         (unless done
                                           (setf err (make-condition
                                                      'http-timeout-error
                                                      :message "parity await timed out")
                                                 done t)
                                           (event-protocol:stop eb el))))
      (event-protocol:with-event-backend (eb)
        (event-protocol:with-event-loop-var (el)
          (event-protocol:run eb el :stop-when-idle nil)))
      (when err (error err))
      result)))
