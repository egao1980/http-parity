(in-package #:http-parity/tests)

(deftest parity-raise-for-status
  "requests Response.raise_for_status"
  (with-live
    (ok (signals (http:get (live-url "/status/404")
                           :raise-for-status t
                           :timeout 20.0 :trust-env nil)
                 'http-error))
    (let ((res (http:get (live-url "/status/404")
                         :timeout 20.0 :trust-env nil)))
      (ok (= 404 (response-status res)))
      (ok (not (http:response-ok-p res))))))

(deftest parity-timeout
  "requests timeout= — /delay/10 with short timeout."
  (with-live
    (ok (signals (http:get (live-url "/delay/10")
                           :timeout 1.0 :trust-env nil)
                 'http-error))))
