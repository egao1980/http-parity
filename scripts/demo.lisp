;;;; Realistic demo: ros -l scripts/demo.lisp
;;;; Env: HTTP_PARITY_BACKEND=async (default), HTTP_PARITY_FIXTURE=1

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&DEMO FAIL: ~A~%" c)
        (uiop:quit 1)))

(asdf:load-system "http-parity")
(let ((result (http-parity:run-demo)))
  (format t "~&~%; === demo result ===~%")
  (format t "; token: ~A~%" (getf result :token))
  (format t "; created: ~S~%" (getf result :created))
  (format t "; downloads:~%")
  (dolist (d (getf result :downloads))
    (format t ";   id=~A bytes=~A path=~A~%"
            (getf d :id) (getf d :bytes) (getf d :path)))
  (format t "; outdir: ~A~%" (getf result :outdir))
  (http-parity:stop-fixture)
  (uiop:quit 0))
