(in-package #:http-parity)

;;; Realistic end-to-end demo: login → JSON catalog → create → download.
;;; Uses local fixture /api/* (async backend by default).

(defun %ht-get (table key)
  "JSON object getter (json-protocol: string-keyed hash-table)."
  (or (gethash key table)
      (gethash (string-downcase key) table)
      (gethash (string-upcase key) table)))

(defun %json-field (data key)
  (cond
    ((hash-table-p data) (%ht-get data key))
    ((listp data) (cdr (assoc key data :test #'string-equal)))
    (t nil)))

(defun %ensure-dir (pathname)
  (ensure-directories-exist
   (uiop:ensure-directory-pathname pathname)))

(defun file-size (pathname)
  (with-open-file (in pathname :element-type '(unsigned-byte 8) :if-does-not-exist nil)
    (if in (file-length in) 0)))

(defun %check-ok (res label)
  (unless (<= 200 (response-status res) 299)
    (error "~A failed: ~A ~A" label (response-status res) (http:response-text res)))
  res)

(defun run-demo (&key (outdir (merge-pathnames "http-parity-demo/"
                                               (uiop:temporary-directory)))
                   (username "demo")
                   (password "s3cret")
                   (backend *preferred-backend*))
  "Authenticate, fetch/create JSON catalog items, download blobs.

   Returns a plist:
     :token :items :created :downloads :outdir

   Side effects: writes files under OUTDIR."
  (let ((*preferred-backend* backend))
    (ensure-fixture)
    (%ensure-dir outdir)
    (with-parity
      (http:with-session (s :preferred backend
                            :base-url (format nil "~A/" *live-base*)
                            :trust-env nil
                            :timeout 20.0)
        (format t "~&; demo: login as ~A against ~A~%" username *live-base*)
        (let* ((login-res (%check-ok
                           (http:session-post s "api/login"
                                              :json `(("username" . ,username)
                                                      ("password" . ,password)))
                           "login"))
               (login-json (http:response-json login-res))
               (token (%json-field login-json "token"))
               (auth (list :bearer token)))
          (unless (and token (plusp (length (string token))))
            (error "login response missing token: ~S" login-json))
          (format t "~&; demo: token ~A…~%"
                  (subseq (string token) 0 (min 12 (length (string token)))))

          (let* ((list-res (%check-ok (http:session-get s "api/catalog" :auth auth)
                                      "catalog list"))
                 (catalog (http:response-json list-res))
                 (items (%json-field catalog "items")))
            (format t "~&; demo: catalog has ~A item(s)~%" (length items))

            (let* ((create-res (%check-ok
                                (http:session-post s "api/catalog"
                                                   :auth auth
                                                   :json `(("title" . "notes.txt")
                                                           ("data" . "hello from http-parity demo")))
                                "create item"))
                   (created (http:response-json create-res))
                   (new-id (%json-field created "id")))
              (format t "~&; demo: created id=~A~%" new-id)

              (let* ((one-res (%check-ok
                               (http:session-get s (format nil "api/catalog/~A" new-id)
                                                 :auth auth)
                               "fetch item"))
                     (one (http:response-json one-res)))
                (format t "~&; demo: item ~A~%" (%json-field one "title")))

              (let ((downloads nil)
                    ;; json-protocol parses JSON arrays as vectors — use MAP, not MAPCAR.
                    (ids (remove nil
                                 (append
                                  (map 'list (lambda (it) (%json-field it "id")) items)
                                  (list new-id)))))
                (dolist (id ids)
                  (let* ((title (format nil "item-~A.bin" id))
                         (dest (merge-pathnames title outdir))
                         (url (format nil "api/catalog/~A/blob" id)))
                    (format t "~&; demo: download ~A → ~A~%" url dest)
                    (http:download url dest
                                   :backend (http:session-backend s)
                                   :client (http:session-client s)
                                   :auth auth
                                   :overwrite t
                                   :trust-env nil
                                   :timeout 20.0)
                    (push (list :id id :path dest :bytes (file-size dest)) downloads)))
                (setf downloads (nreverse downloads))
                (format t "~&; demo: done — ~A file(s) in ~A~%"
                        (length downloads) outdir)
                (list :token token
                      :items items
                      :created created
                      :downloads downloads
                      :outdir outdir)))))))))
