;;;; Phase 2: overlay OpenSSL on loader path, then run parity suite.

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

(setf asdf:*compile-file-failure-behaviour* :warn)

(defun call-with-ci-muffles (fn)
  #+sbcl
  (handler-bind ((sb-ext:defconstant-uneql
                  (lambda (c)
                    (declare (ignore c))
                    (let ((r (find-restart 'continue)))
                      (when r (invoke-restart r))))))
    (funcall fn))
  #-sbcl
  (funcall fn))

(call-with-ci-muffles (lambda () (asdf:load-system "cl-repository-client")))

(cl-repository-client/asdf-integration:configure-asdf-source-registry)
(cl-repository-client/asdf-integration:load-system-init-files)

(let* ((backend (string-downcase (or (uiop:getenv "HTTP_ASYNC_EVENT_BACKEND") "libuv")))
       (event-sys (cond ((string= backend "libuv") "event-backend-libuv")
                        ((string= backend "libev") "event-backend-libev")
                        (t (error "Unknown HTTP_ASYNC_EVENT_BACKEND: ~a" backend)))))
  (format t "~&; ci: test backend=~a event=~a parity-backend=~a~%"
          backend event-sys (or (uiop:getenv "HTTP_PARITY_BACKEND") "async"))
  (format t "~&; ci: pins http-protocol=~a cl-stack-http=~a async=~a~%"
          (or (uiop:getenv "HTTP_PROTOCOL_VERSION") "?")
          (or (uiop:getenv "CL_STACK_HTTP_VERSION") "?")
          (or (uiop:getenv "HTTP_BACKEND_ASYNC_VERSION") "?"))
  (call-with-ci-muffles
   (lambda ()
     (asdf:load-system "cl+ssl")
     (asdf:load-system "cl-stack-ssl")
     (asdf:load-system event-sys)
     (asdf:load-system "http-backend-async")
     (asdf:load-system "cl-stack-http")
     (asdf:load-system "http-parity")
     (http-parity:print-matrix)
     (asdf:test-system "http-parity"))))

(uiop:quit 0)
