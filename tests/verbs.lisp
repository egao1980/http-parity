(in-package #:http-parity/tests)

;;; requests Session.request / httpx Client — verb helpers.

(deftest parity-get
  "requests: GET httpbin/get"
  (with-live
    (let ((res (http:get (live-url "/get") :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res)))
      (ok (http:response-ok-p res))
      (ok (search "url" (http:response-text res) :test #'char-equal)))))

(deftest parity-get-async
  "httpx AsyncClient.get — promise path"
  (with-live
    (let ((res (await (http:get-async (live-url "/get") :timeout 20.0 :trust-env nil)
                      :timeout 25.0)))
      (ok (= 200 (response-status res)))
      (ok (plusp (length (http:response-content res)))))))

(deftest parity-post-echo
  "requests: POST /post"
  (with-live
    (let ((res (http:post (live-url "/post")
                          :content "hello-parity"
                          :headers '(("content-type" . "text/plain"))
                          :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res)))
      (ok (search "hello-parity" (http:response-text res))))))

(deftest parity-head
  (with-live
    (let ((res (http:head (live-url "/get") :timeout 20.0 :trust-env nil)))
      (ok (= 200 (response-status res))))))

(deftest parity-options
  (with-live
    (let ((res (http:options (live-url "/get") :timeout 20.0 :trust-env nil)))
      (ok (<= 200 (response-status res) 299)))))

(deftest parity-put-patch-delete
  (with-live
    (ok (= 200 (response-status
                (http:put (live-url "/put") :content "{}" :timeout 20.0 :trust-env nil))))
    (ok (= 200 (response-status
                (http:patch (live-url "/patch") :content "{}" :timeout 20.0 :trust-env nil))))
    (ok (= 200 (response-status
                (http:delete (live-url "/delete") :timeout 20.0 :trust-env nil))))))
