;;;; Ordered loads: ssl overlay, matrix event backend, then the HTTP stack.

(let* ((backend (string-downcase (or (uiop:getenv "HTTP_ASYNC_EVENT_BACKEND") "libuv")))
       (event-sys (cond ((string= backend "libuv") "event-backend-libuv")
                        ((string= backend "libev") "event-backend-libev")
                        (t (error "Unknown HTTP_ASYNC_EVENT_BACKEND: ~a" backend)))))
  (format t "~&; ci: pre-test backend=~a event=~a parity-backend=~a~%"
          backend event-sys (or (uiop:getenv "HTTP_PARITY_BACKEND") "async"))
  (format t "~&; ci: pins http-protocol=~a cl-stack-http=~a async=~a~%"
          (or (uiop:getenv "HTTP_PROTOCOL_VERSION") "?")
          (or (uiop:getenv "CL_STACK_HTTP_VERSION") "?")
          (or (uiop:getenv "HTTP_BACKEND_ASYNC_VERSION") "?"))
  (asdf:load-system "cl+ssl")
  (asdf:load-system "cl-stack-ssl")
  (asdf:load-system event-sys)
  (asdf:load-system "http-backend-async")
  (asdf:load-system "cl-stack-http")
  (asdf:load-system "http-parity")
  (uiop:symbol-call :http-parity :print-matrix))
