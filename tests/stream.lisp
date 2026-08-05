(in-package #:http-parity/tests)

(deftest parity-want-stream
  "httpx stream=True / iter_bytes — sync await slurps via async engine."
  (with-live
    (let ((res (http:stream :get (live-url "/stream-bytes/64")
                            :timeout 20.0 :trust-env nil)))
      (cond
        ((= 404 (response-status res))
         ;; fallback path for origins without /stream-bytes
         (let ((res2 (http:stream :get (live-url "/bytes/64")
                                  :timeout 20.0 :trust-env nil)))
           (ok (= 200 (response-status res2)))
           (ok (streamp (response-body res2)))
           (let ((n 0))
             (http:map-response-bytes res2 (lambda (b) (declare (ignore b)) (incf n)))
             (ok (= 64 n)))
           (http:close-response res2)))
        (t
         (ok (= 200 (response-status res)))
         (ok (or (streamp (response-body res))
                 (plusp (length (http:response-content res)))))
         (http:close-response res))))))

(deftest parity-stream-async
  (with-live
    (let ((res (await (http:stream-async :get (live-url "/bytes/32")
                                         :timeout 20.0 :trust-env nil)
                      :timeout 25.0)))
      (if (= 404 (response-status res))
          (skip "origin has no /bytes/N")
          (progn
            (ok (= 200 (response-status res)))
            (ok (streamp (response-body res)))
            (http:close-response res))))))
