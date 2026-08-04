(defpackage #:http-parity
  (:use #:cl #:http-protocol)
  (:local-nicknames (#:http #:cl-stack-http)
                    (#:stack #:cl-stack-http))
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
   #:run))