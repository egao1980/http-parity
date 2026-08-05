(in-package #:http-parity/tests)

(deftest parity-basic-auth
  "requests HTTPBasicAuth → /basic-auth/user/pass"
  (with-live
    (let ((res (http:get (live-url "/basic-auth/user/pass")
                         :auth '(:basic "user" "pass")
                         :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res))
          (format nil "basic-auth status=~a body=~s www-authenticate=~s"
                  (response-status res)
                  (http:response-text res)
                  (response-header res "www-authenticate")))
      (ok (search "authenticated" (http:response-text res) :test #'char-equal)))))

(deftest parity-bearer-auth
  "RFC 6750 Bearer — origin echoes Authorization when present."
  (with-live
    (let ((res (http:get (live-url "/bearer")
                         :auth '(:bearer "parity-token")
                         :timeout 20.0 :trust-env nil)))
      (if (= 404 (response-status res))
          (skip "origin has no /bearer")
          (ok (= 200 (response-status res)))))))

(deftest parity-digest-auth
  "requests HTTPDigestAuth (sync challenge retry)."
  (with-live
    (let ((res (http:get (live-url "/digest-auth/auth/user/pass")
                         :auth (http:digest-auth "user" "pass")
                         :timeout 25.0 :trust-env nil)))
      (ok (= 200 (response-status res))))))
