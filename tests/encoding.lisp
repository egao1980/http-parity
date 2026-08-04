(in-package #:http-parity/tests)

;;; Content-Encoding — mirrors psf/requests httpbin cases.

(deftest parity-gzip
  "requests TestRequests.test_decompress_gzip"
  (with-live
    (let* ((res (http:get (live-url "/gzip")
                          :accept-encoding '(:gzip)
                          :timeout 20.0 :trust-env nil))
           (text (http:response-text res)))
      (ok (= 200 (response-status res)))
      (ok (search "gzipped" text :test #'char-equal))
      (ok (null (response-header res :content-encoding))))))

(deftest parity-deflate
  (with-live
    (let* ((res (http:get (live-url "/deflate")
                          :accept-encoding '(:deflate)
                          :timeout 20.0 :trust-env nil))
           (text (http:response-text res)))
      (ok (= 200 (response-status res)))
      (ok (or (search "deflated" text :test #'char-equal)
              (search "deflate" text :test #'char-equal)))
      (ok (null (response-header res :content-encoding))))))

(deftest parity-brotli-optional
  "Soft-skip when br backend / origin unavailable."
  (with-live
    (unless (ignore-errors (asdf:load-system "http-encoding-brotli") t)
      (skip "http-encoding-brotli not available"))
    (unless (content-coding-supported-p :br)
      (skip "br coding not registered"))
    (let* ((url (or (uiop:getenv "HTTP_PARITY_BR_URL")
                    (live-url "/brotli")))
           (res (http:get url
                          :accept-encoding '(:br)
                          :timeout 25.0 :trust-env nil)))
      (unless (<= 200 (response-status res) 299)
        (skip (format nil "br origin returned ~A" (response-status res))))
      (ok (null (response-header res :content-encoding)))
      (ok (plusp (length (http:response-content res)))))))
