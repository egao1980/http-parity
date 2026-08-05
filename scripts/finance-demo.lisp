;;;; Live finance demo: ros -l scripts/finance-demo.lisp
;;;; Needs network. Prefers async + brotli (fin-node/frankfurter serve br).

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&FINANCE DEMO FAIL: ~A~%" c)
        (uiop:quit 1)))

(asdf:load-system "http-parity")
(ignore-errors (asdf:load-system "http-encoding-brotli"))
(ignore-errors (asdf:load-system "http-encoding-chipz"))

(let ((result (http-parity:run-finance-demo)))
  (format t "~&~%; === finance demo result ===~%")
  (format t "; outdir: ~A~%" (getf result :outdir))
  (format t "; FX rates: ~S~%"
          (let ((fx (getf result :fx-latest)))
            (if (hash-table-p fx)
                (alexandria:hash-table-alist
                 (or (gethash "rates" fx) (make-hash-table)))
                fx)))
  (format t "; downloads:~%")
  (dolist (d (getf result :downloads))
    (format t ";   ~A → ~A (~A prices, updated ~A)~%"
            (getf d :filename) (getf d :path)
            (getf d :prices) (getf d :updated)))
  (format t "; codecs: ~S~%" (getf result :codecs))
  (format t "; FX EUR default/gzip: ~A / ~A~%"
          (getf result :fx-eur) (getf result :fx-eur-gzip))
  (format t "; content-encoding checks:~%")
  (dolist (c (getf result :ce-checks))
    (format t ";   ~A status=~A AE=~S CE=~S decoded=~A cd=~S file=~S bytes=~A~%"
            (or (getf c :label) (getf c :url))
            (getf c :status)
            (getf c :accept-encoding)
            (getf c :content-encoding)
            (getf c :decoded-p)
            (getf c :content-disposition)
            (getf c :filename)
            (or (getf c :file-bytes) (getf c :body-len))))
  (uiop:quit 0))
