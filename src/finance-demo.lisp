(in-package #:http-parity)

;;; Live finance demo — real HTTPS APIs + Content-Encoding + CD filenames.
;;;
;;; Sources (no API key):
;;;   Frankfurter  https://api.frankfurter.dev  — FX rates (query params)
;;;   Fin-node     https://www.fin-node.net/api — equity bundles (br + CD)

(defparameter *frankfurter-base* "https://api.frankfurter.dev/v1"
  "ECB FX reference rates (Frankfurter).")

(defparameter *fin-node-base* "https://www.fin-node.net/api"
  "Fin-node daily equity JSON bundles.")

(defun %ensure-ce-backends ()
  "Soft-load gzip + brotli codecs (fin-node/frankfurter serve br by default)."
  (ignore-errors (asdf:load-system "http-encoding-chipz"))
  (ignore-errors (asdf:load-system "http-encoding-brotli"))
  (ignore-errors (asdf:load-system "http-encoding-zstd"))
  (values))

(defun %json-keys (data)
  (cond
    ((hash-table-p data)
     (loop for k being the hash-keys of data collect k))
    ((listp data) (mapcar #'car data))
    (t nil)))

(defun %as-dir (pathname)
  (uiop:ensure-directory-pathname pathname))

(defun %path-namestring (p)
  (if (typep p 'path:path)
      (path:as-posix p)
      (namestring p)))

(defun %path-basename (p)
  (let ((s (%path-namestring p)))
    (subseq s (1+ (or (position #\/ s :from-end t) -1)))))

(defun run-finance-demo
    (&key (outdir (merge-pathnames "http-parity-finance/"
                                   (uiop:temporary-directory)))
          (tickers '("AAPL" "NVDA" "MSFT"))
          (base-currency "USD")
          (symbols "EUR,GBP,JPY,CHF")
          (backend *preferred-backend*)
          (accept-encoding :default))
  "Query FX + equity APIs over HTTPS; verify CE decode + CD filenames.

   ACCEPT-ENCODING — :default (stack AE incl. br), :gzip, :br, or \"identity\".

   Returns plist:
     :fx-latest :fx-history :downloads :ce-checks :outdir"
  (let ((*preferred-backend* backend)
        (outdir (%as-dir outdir)))
    (%ensure-ce-backends)
    (ensure-directories-exist outdir)
    (with-parity
      (format t "~&; finance-demo: backend=~S AE=~S out=~A~%"
              backend accept-encoding outdir)
      (let* ((ae accept-encoding)
             (fx-url (format nil "~A/latest?base=~A&symbols=~A"
                             *frankfurter-base* base-currency symbols))
             (hist-url (format nil "~A/2024-01-01..2024-01-31?base=~A&symbols=EUR"
                               *frankfurter-base* base-currency))
             (ce-checks nil)
             (downloads nil))

        (format t "~&; finance-demo: codecs=~{~A~^,~}~%"
                (available-content-codings :warn nil))

        ;; --- FX: latest (default AE — typically br from Cloudflare) ---
        (format t "~&; finance-demo: GET ~A~%" fx-url)
        (let* ((fx-res (http:get fx-url
                                 :accept-encoding ae
                                 :timeout 25.0 :trust-env nil))
               (fx (progn (%check-ok fx-res "fx latest")
                          (http:response-json fx-res)))
               (ce (response-header fx-res :content-encoding)))
          (push (list :label "fx-latest" :url fx-url
                      :accept-encoding ae
                      :status (response-status fx-res)
                      :content-encoding ce
                      :decoded-p (null ce)
                      :body-string-p (stringp (http:response-content fx-res))
                      :body-len (length (http:response-content fx-res)))
                ce-checks)
          (format t "~&; finance-demo: FX base=~A rates=~A (CE after decode=~S)~%"
                  (%json-field fx "base")
                  (%json-keys (%json-field fx "rates"))
                  ce)

          ;; --- FX: force gzip AE (proves chipz path, not just br) ---
          (format t "~&; finance-demo: GET ~A (Accept-Encoding: gzip)~%" fx-url)
          (let* ((gz-res (http:get fx-url
                                   :accept-encoding "gzip"
                                   :timeout 25.0 :trust-env nil))
                 (gz (progn (%check-ok gz-res "fx latest gzip")
                            (http:response-json gz-res)))
                 (ce-gz (response-header gz-res :content-encoding))
                 (eur (ignore-errors (%json-field (%json-field fx "rates") "EUR")))
                 (eur-gz (ignore-errors (%json-field (%json-field gz "rates") "EUR"))))
            (push (list :label "fx-latest+gzip" :url fx-url
                        :accept-encoding "gzip"
                        :status (response-status gz-res)
                        :content-encoding ce-gz
                        :decoded-p (null ce-gz)
                        :body-string-p (stringp (http:response-content gz-res))
                        :body-len (length (http:response-content gz-res)))
                  ce-checks)
            (when (and eur eur-gz (not (equal eur eur-gz)))
              (error "gzip AE FX EUR mismatch: default=~S gzip=~S" eur eur-gz))
            (format t "~&; finance-demo: FX gzip-AE EUR=~A (CE after decode=~S)~%"
                    eur-gz ce-gz)

            ;; --- FX: history range (path + query) ---
            (format t "~&; finance-demo: GET ~A~%" hist-url)
            (let* ((hist-res (http:get hist-url
                                       :accept-encoding ae
                                       :timeout 25.0 :trust-env nil))
                   (hist (progn (%check-ok hist-res "fx history")
                                (http:response-json hist-res)))
                   (ce2 (response-header hist-res :content-encoding))
                   (dates (%json-keys (%json-field hist "rates"))))
              (push (list :label "fx-history" :url hist-url
                          :accept-encoding ae
                          :status (response-status hist-res)
                          :content-encoding ce2
                          :decoded-p (null ce2)
                          :body-string-p (stringp (http:response-content hist-res))
                          :body-len (length (http:response-content hist-res)))
                    ce-checks)
              (format t "~&; finance-demo: FX history days=~A (CE=~S)~%"
                      (length dates) ce2)

              ;; --- Equities: download JSON bundles into directory (CD filename) ---
              (dolist (ticker tickers)
                (let* ((url (format nil "~A/~A.json" *fin-node-base* ticker)))
                  (format t "~&; finance-demo: download ~A → ~A~%" url outdir)
                  (multiple-value-bind (dest res)
                      (http:download url outdir
                                     :accept-encoding ae
                                     :filename :content-disposition
                                     :overwrite t
                                     :trust-env nil
                                     :timeout 30.0)
                    (%check-ok res (format nil "download ~A" ticker))
                    (let* ((ce3 (response-header res :content-encoding))
                           (cd (response-header res :content-disposition))
                           (name (%path-basename dest))
                           (expected (format nil "~A.json" ticker))
                           (text (uiop:read-file-string (%path-namestring dest)))
                           (data (http:decode-json text)))
                      (unless (string-equal name expected)
                        (error "CD filename mismatch: got ~S want ~S (cd=~S)"
                               name expected cd))
                      (unless (and (hash-table-p data)
                                   (equalp (%json-field data "symbol") ticker))
                        (error "decoded ~A missing symbol: keys=~S"
                               name (%json-keys data)))
                      (push (list :label (format nil "download-~A" ticker)
                                  :url url :status (response-status res)
                                  :accept-encoding ae
                                  :content-encoding ce3
                                  :decoded-p (null ce3)
                                  :content-disposition cd
                                  :filename name
                                  :body-len (length (http:response-content res))
                                  :file-bytes (file-size (%path-namestring dest)))
                            ce-checks)
                      (push (list :ticker ticker :path dest :filename name
                                  :prices (length (%json-field data "prices"))
                                  :updated (%json-field data "updated"))
                            downloads)
                      (format t "~&; finance-demo: saved ~A (~A price rows, CE=~S, CD=~S)~%"
                              name
                              (length (%json-field data "prices"))
                              ce3 cd)))))

              (setf ce-checks (nreverse ce-checks)
                    downloads (nreverse downloads))
              (format t "~&; finance-demo: done — ~A download(s), ~A CE check(s)~%"
                      (length downloads) (length ce-checks))
              (unless (every (lambda (c) (getf c :decoded-p)) ce-checks)
                (error "finance-demo: Content-Encoding not stripped after decode: ~S"
                       (remove-if (lambda (c) (getf c :decoded-p)) ce-checks)))
              (list :fx-latest fx
                    :fx-history hist
                    :fx-eur eur
                    :fx-eur-gzip eur-gz
                    :downloads downloads
                    :ce-checks ce-checks
                    :outdir outdir
                    :codecs (available-content-codings :warn nil)))))))))
