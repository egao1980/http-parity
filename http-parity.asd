(defsystem "http-parity"
  :version "0.1.1"
  :description "Demo/test: cl-stack-http feature parity vs requests/httpx (async preferred)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-http"
               "http-backend-async"
               "event-protocol"
               "http-protocol"
               "encoding-protocol"
               "alexandria"
               "babel"
               "blackbird"
               "bordeaux-threads"
               "usocket"
               "quri"
               "rove")
  :properties
  (:cl-repo
   (:ci (:with ("cl-stack-ssl" "http-encoding-chipz" "http-encoding-brotli"
                "http-encoding-zstd" "cl-stack-brotli" "cl-stack-zstd")
         :sources (("encoding-protocol" :oci))
         :load-before-test ("cl+ssl" "cl-stack-ssl" "http-backend-async" "cl-stack-http")
         :record-versions (("cl-stack-ssl" . "CL_STACK_SSL_VERSION")
                           ("http-protocol" . "HTTP_PROTOCOL_VERSION")
                           ("cl-stack-http" . "CL_STACK_HTTP_VERSION")
                           ("http-backend-async" . "HTTP_BACKEND_ASYNC_VERSION")))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "demo-api")
               (:file "fixture")
               (:file "harness")
               (:file "demo")
               (:file "finance-demo")
               (:file "report"))
  :in-order-to ((test-op (test-op "http-parity/tests"))))

(defsystem "http-parity/tests"
  :depends-on ("http-parity" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "verbs")
               (:file "params")
               (:file "json")
               (:file "session")
               (:file "auth")
               (:file "redirect")
               (:file "encoding")
               (:file "stream")
               (:file "files")
               (:file "status")
               (:file "demo")
               (:file "finance-demo"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "http-parity tests failed"))))
