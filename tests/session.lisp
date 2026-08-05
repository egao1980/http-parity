(in-package #:http-parity/tests)

(deftest parity-session-cookies
  "requests Session cookie persistence (set → echo)."
  (with-live
    (http:with-session (s :preferred *preferred-backend*
                          :base-url (format nil "~A/" *live-base*)
                          :trust-env nil
                          :timeout 20.0)
      (let ((r1 (http:session-get s "cookies/set?session=parity")))
        (ok (<= 200 (response-status r1) 399)))
      (let* ((r2 (http:session-get s "cookies"))
             (text (http:response-text r2)))
        (ok (= 200 (response-status r2)))
        (ok (or (search "session" text :test #'char-equal)
                (search "parity" text :test #'char-equal)))))))

(deftest parity-session-params
  "Session default query params + relative URL via base-url."
  (with-live
    (http:with-session (s :preferred *preferred-backend*
                          :base-url (format nil "~A/" *live-base*)
                          :params '(("from" . "parity"))
                          :trust-env nil
                          :timeout 20.0)
      (let ((text (http:response-text (http:session-get s "get"))))
        (ok (search "from" text :test #'char-equal))
        (ok (search "parity" text :test #'char-equal))))))
