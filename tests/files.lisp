(in-package #:http-parity/tests)

(deftest parity-multipart-files
  "httpx files= — in-memory httpx tuple (no FS)."
  (with-live
    (let* ((octets (babel:string-to-octets "parity-upload" :encoding :utf-8))
           (res (http:post (live-url "/post")
                           :files `(("file" ("note.txt" ,octets "text/plain")))
                           :timeout 25.0 :trust-env nil))
           (text (http:response-text res)))
      (ok (= 200 (response-status res)))
      (ok (or (search "parity-upload" text)
              (search "note.txt" text)
              (search "file" text :test #'char-equal))))))

(deftest parity-download-upload-roundtrip
  "pathlib download → upload (temp file)."
  (with-live
    (uiop:with-temporary-file (:pathname p :prefix "http-parity-" :type "bin")
      (http:download (live-url "/bytes/128") p :overwrite t
                     :timeout 20.0 :trust-env nil)
      (ok (probe-file p))
      (ok (= 128 (with-open-file (in p :element-type '(unsigned-byte 8))
                   (file-length in))))
      (let ((res (http:upload p (live-url "/post") :as :files
                              :timeout 25.0 :trust-env nil)))
        (ok (= 200 (response-status res)))))))
