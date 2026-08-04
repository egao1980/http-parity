(in-package #:http-parity/tests)

(deftest parity-multi-value-params
  "requests/httpx: list param values → repeated query keys; NIL dropped."
  (with-live
    (let* ((r (http:get (live-url "/get")
                        :params '(("key1" . "value1")
                                  ("key2" . ("value2" "value3"))
                                  ("skip" . nil))
                        :trust-env nil
                        :timeout 15.0))
           (url (or (response-url r) ""))
           (json (http:response-json r))
           (args (and (hash-table-p json) (gethash "args" json))))
      (ok (= 200 (response-status r)))
      (ok (search "key1=value1" url :test #'char-equal))
      (ok (search "key2=value2" url :test #'char-equal))
      (ok (search "key2=value3" url :test #'char-equal))
      (ok (not (search "skip=" url :test #'char-equal)))
      (ok (hash-table-p args))
      (ok (equal "value1" (gethash "key1" args)))
      (let ((k2 (gethash "key2" args)))
        (ok (or (equalp k2 #("value2" "value3"))
                (equal k2 '("value2" "value3"))))))))
