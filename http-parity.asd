(defsystem "http-parity"
  :version "0.1.0"
  :description "Demo/test: cl-stack-http feature parity vs requests/httpx (async preferred)"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-http"
               "http-backend-async"
               "event-protocol"
               "http-protocol"
               "alexandria"
               "babel"
               "blackbird"
               "bordeaux-threads"
               "usocket"
               "quri"
               "rove")
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
