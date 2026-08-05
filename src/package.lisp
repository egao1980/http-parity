(defpackage #:http-parity
  (:use #:cl #:http-protocol)
  (:local-nicknames (#:http #:cl-stack-http)
                    (#:stack #:cl-stack-http)
                    (#:path #:cl-stack-pathlib))
  (:export
   #:*preferred-backend*
   #:*live-base*
   #:*fixture-base*
   #:live-enabled-p
   #:fixture-enabled-p
   #:live-url
   #:ensure-fixture
   #:start-fixture
   #:stop-fixture
   #:with-parity
   #:await
   #:print-matrix
   #:run
   #:run-demo
   #:run-finance-demo
   #:reset-demo-api))
