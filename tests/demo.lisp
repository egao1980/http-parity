(in-package #:http-parity/tests)

(deftest parity-realistic-demo
  "End-to-end: login → JSON list/create → download files (async)."
  (with-live
    (let* ((outdir (merge-pathnames
                    (format nil "http-parity-demo-test-~A/" (get-universal-time))
                    (uiop:temporary-directory)))
           (result (run-demo :outdir outdir)))
      (ok (getf result :token))
      (ok (getf result :created))
      (ok (plusp (length (getf result :downloads))))
      (dolist (d (getf result :downloads))
        (ok (probe-file (getf d :path)))
        (ok (plusp (getf d :bytes)))))))
