(in-package #:http-parity/tests)

(defun %finance-live-p ()
  "Skip unless HTTP_PARITY_FINANCE=1 (live HTTPS + CE)."
  (let ((v (uiop:getenv "HTTP_PARITY_FINANCE")))
    (member v '("1" "true" "yes" "on") :test #'string-equal)))

(deftest parity-finance-demo-live
  "Frankfurter FX queries + Fin-node br download with CD filename."
  (cond
    ((not (%finance-live-p))
     (skip "HTTP_PARITY_FINANCE not set — live finance demo skipped"))
    ((not (live-enabled-p))
     (skip "HTTP_PARITY_LIVE disabled"))
    (t
     (ignore-errors (asdf:load-system "http-encoding-brotli"))
     (ignore-errors (asdf:load-system "http-encoding-chipz"))
     (unless (content-coding-supported-p :br)
       (skip "brotli codec not available"))
     ;; fixture off — hit public HTTPS origins
     (let ((old (uiop:getenv "HTTP_PARITY_FIXTURE")))
       (setf (uiop:getenv "HTTP_PARITY_FIXTURE") "0")
       (unwind-protect
            (with-parity
              (let* ((outdir (merge-pathnames
                              (format nil "http-parity-finance-test-~A/"
                                      (get-universal-time))
                              (uiop:temporary-directory)))
                     (result (run-finance-demo :outdir outdir
                                               :tickers '("AAPL")
                                               :accept-encoding :default)))
                (ok (getf result :fx-latest))
                (ok (getf result :downloads))
                (let ((d (first (getf result :downloads))))
                  (ok (string-equal "AAPL.json" (getf d :filename)))
                  (ok (probe-file (if (typep (getf d :path) 'path:path)
                                      (path:as-posix (getf d :path))
                                      (getf d :path)))))
                (ok (every (lambda (c) (getf c :decoded-p))
                           (getf result :ce-checks)))
                (ok (getf result :fx-eur-gzip))))
         (when old
           (setf (uiop:getenv "HTTP_PARITY_FIXTURE") old)))))))
