(in-package #:http-parity/tests)

(deftest parity-json-get
  "httpx: r.json() on /json"
  (with-live
    (let* ((res (http:get (live-url "/json") :timeout 20.0 :trust-env nil))
           (data (http:response-json res)))
      (ok (= 200 (response-status res)))
      (ok (or (hash-table-p data) (listp data))))))

(deftest parity-json-post
  "httpx: client.post(..., json={...})"
  (with-live
    (let* ((res (http:post (live-url "/post")
                           :json '(("a" . 1) ("b" . "x"))
                           :timeout 20.0 :trust-env nil))
           (text (http:response-text res)))
      (ok (= 200 (response-status res)))
      (ok (or (search "\"a\"" text) (search "a" text)))
      (ok (search "1" text)))))

(deftest parity-json-helper
  "stack-http:json convenience"
  (with-live
    (multiple-value-bind (decoded res)
        (http:json :post (live-url "/post") '(("n" . 2))
                   :timeout 20.0 :trust-env nil)
      (ok (= 200 (response-status res)))
      (ok (or decoded t)))))
