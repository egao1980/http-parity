(in-package #:http-parity/tests)

(deftest parity-redirect-follow
  "requests allow_redirects=True — /redirect/1 → /get"
  (with-live
    (let ((res (http:get (live-url "/redirect/1")
                         :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res)))
      (ok (plusp (length (response-history res)))))))

(deftest parity-redirect-history
  (with-live
    (let ((res (http:get (live-url "/redirect/2")
                         :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res)))
      (ok (>= (length (response-history res)) 1)))))

(deftest parity-max-redirects
  "Exceeding max-redirects → http-redirect-error (2 hops, budget 1)."
  (with-live
    (ok (signals (http:get (live-url "/redirect/2")
                           :max-redirects 1
                           :timeout 20.0 :trust-env nil)
                 'http-error))))
