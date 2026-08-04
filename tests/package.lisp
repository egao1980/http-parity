(defpackage #:http-parity/tests
  (:use #:cl #:rove #:http-protocol #:http-parity)
  (:shadowing-import-from #:rove #:run)
  (:local-nicknames (#:http #:cl-stack-http)
                    (#:stack #:cl-stack-http)
                    (#:path #:cl-stack-pathlib)))

(in-package #:http-parity/tests)

(defmacro with-live (&body body)
  "Run BODY under WITH-PARITY. Skip only when HTTP_PARITY_LIVE is off.
   Fixture mode (default): errors fail the test.
   Public live (HTTP_PARITY_FIXTURE=0): network errors → skip."
  `(if (not (live-enabled-p))
       (skip "HTTP_PARITY_LIVE disabled")
       (if (fixture-enabled-p)
           (with-parity ,@body)
           (handler-case
               (with-parity ,@body)
             (error (e)
               (skip (format nil "live network unavailable: ~A" e)))))))
