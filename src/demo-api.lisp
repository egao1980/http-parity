(in-package #:http-parity)

;;; Tiny in-memory catalog API for the realistic demo app.
;;; Mounted under /api/* on the parity fixture.

(defvar *demo-users*
  '(("demo" . "s3cret")
    ("alice" . "wonderland"))
  "username → password for /api/login.")

(defvar *demo-tokens* (make-hash-table :test #'equal)
  "bearer token → username")

(defvar *demo-items* nil
  "Alist id → plist (:id :title :bytes).")

(defvar *demo-next-id* 1)

(defun reset-demo-api ()
  (clrhash *demo-tokens*)
  (setf *demo-items* nil
        *demo-next-id* 1)
  ;; seed catalog
  (demo-api-put-item "readme" (babel:string-to-octets
                               "http-parity demo catalog v1" :encoding :utf-8))
  (demo-api-put-item "sample.bin" (make-array 64 :element-type '(unsigned-byte 8)
                                              :initial-contents
                                              (loop for i below 64 collect (mod (* i 3) 256))))
  (values))

(defun demo-api-put-item (title octets)
  (let* ((id *demo-next-id*)
         (entry (list :id id :title title :bytes octets)))
    (incf *demo-next-id*)
    (push (cons id entry) *demo-items*)
    entry))

(defun demo-api-find (id)
  (cdr (assoc id *demo-items* :test #'eql)))

(defun %json-get (text key)
  "Naive extract of \"key\":\"value\" or \"key\":number from JSON text."
  (let* ((pat (format nil "\"~A\"" key))
         (pos (search pat text :test #'char-equal)))
    (when pos
      (let* ((colon (position #\: text :start (+ pos (length pat))))
             (rest (and colon (string-trim '(#\Space #\Tab #\Newline) (subseq text (1+ colon))))))
        (when rest
          (cond
            ((and (plusp (length rest)) (char= (char rest 0) #\"))
             (let ((end (position #\" rest :start 1)))
               (when end (subseq rest 1 end))))
            (t
             (let ((end (or (position-if (lambda (c) (member c '(#\, #\} #\Space))) rest)
                            (length rest))))
               (subseq rest 0 end)))))))))

(defun %bearer-user (headers)
  (let ((auth (%header headers "authorization")))
    (when (and auth (>= (length auth) 7)
               (string-equal "bearer " auth :end2 7))
      (gethash (string-trim '(#\Space) (subseq auth 7)) *demo-tokens*))))

(defun %require-auth (headers)
  (or (%bearer-user headers)
      (return-from %require-auth
        (values 401
                '(("content-type" . "application/json")
                  ("www-authenticate" . "Bearer"))
                (%octets "{\"error\":\"unauthorized\"}")))))

(defun %demo-api-handler (method path headers body)
  "Handle /api/* — returns NIL if not an API path."
  (multiple-value-bind (path* query) (%query path)
    (declare (ignore query))
    (unless (and (>= (length path*) 4)
                 (string= (subseq path* 0 4) "/api"))
      (return-from %demo-api-handler (values nil nil nil)))
    (cond
      ;; POST /api/login  {"username","password"} → {"token","user"}
      ((and (eq method :post) (string= path* "/api/login"))
       (let* ((text (if body
                        (babel:octets-to-string body :encoding :utf-8 :errorp nil)
                        ""))
              (user (%json-get text "username"))
              (pass (%json-get text "password"))
              (ok (and user pass (equal pass (cdr (assoc user *demo-users* :test #'string=))))))
         (if ok
             (let ((token (format nil "tok-~A-~X" user (random (expt 2 32)))))
               (setf (gethash token *demo-tokens*) user)
               (values 200 '(("content-type" . "application/json"))
                       (%octets (format nil "{\"token\":~A,\"user\":~A}"
                                        (%json-escape token)
                                        (%json-escape user)))))
             (values 401 '(("content-type" . "application/json"))
                     (%octets "{\"error\":\"invalid credentials\"}")))))

      ;; GET /api/catalog
      ((and (eq method :get) (string= path* "/api/catalog"))
       (multiple-value-bind (user status hdrs body*)
           (let ((u (%bearer-user headers)))
             (if u
                 (values u nil nil nil)
                 (values nil 401
                         '(("content-type" . "application/json"))
                         (%octets "{\"error\":\"unauthorized\"}"))))
         (declare (ignore user))
         (when status (return-from %demo-api-handler (values status hdrs body*)))
         (let ((items (mapcar (lambda (pair)
                                (let ((e (cdr pair)))
                                  (format nil "{\"id\":~A,\"title\":~A,\"size\":~A}"
                                          (getf e :id)
                                          (%json-escape (getf e :title))
                                          (length (getf e :bytes)))))
                              (reverse *demo-items*))))
           (values 200 '(("content-type" . "application/json"))
                   (%octets (format nil "{\"items\":[~{~A~^,~}]}" items))))))

      ;; POST /api/catalog  {"title":"...","data":"..."}  data = utf8 text for demo
      ((and (eq method :post) (string= path* "/api/catalog"))
       (unless (%bearer-user headers)
         (return-from %demo-api-handler
           (values 401 '(("content-type" . "application/json"))
                   (%octets "{\"error\":\"unauthorized\"}"))))
       (let* ((text (if body
                        (babel:octets-to-string body :encoding :utf-8 :errorp nil)
                        ""))
              (title (or (%json-get text "title") "untitled"))
              (data (or (%json-get text "data") ""))
              (entry (demo-api-put-item title (%octets data))))
         (values 201 '(("content-type" . "application/json"))
                 (%octets (format nil "{\"id\":~A,\"title\":~A,\"size\":~A}"
                                  (getf entry :id)
                                  (%json-escape (getf entry :title))
                                  (length (getf entry :bytes)))))))

      ;; GET /api/catalog/:id
      ((and (eq method :get)
            (>= (length path*) 13)
            (string= (subseq path* 0 13) "/api/catalog/")
            (not (search "/blob" path*)))
       (unless (%bearer-user headers)
         (return-from %demo-api-handler
           (values 401 '(("content-type" . "application/json"))
                   (%octets "{\"error\":\"unauthorized\"}"))))
       (let* ((id (parse-integer (subseq path* 13) :junk-allowed t))
              (entry (and id (demo-api-find id))))
         (if entry
             (values 200 '(("content-type" . "application/json"))
                     (%octets (format nil "{\"id\":~A,\"title\":~A,\"size\":~A}"
                                      (getf entry :id)
                                      (%json-escape (getf entry :title))
                                      (length (getf entry :bytes)))))
             (values 404 '(("content-type" . "application/json"))
                     (%octets "{\"error\":\"not found\"}")))))

      ;; GET /api/catalog/:id/blob
      ((and (eq method :get)
            (>= (length path*) 18)
            (string= (subseq path* 0 13) "/api/catalog/")
            (let ((rest (subseq path* 13)))
              (and (find #\/ rest) (string= (subseq rest (1+ (position #\/ rest))) "blob"))))
       (unless (%bearer-user headers)
         (return-from %demo-api-handler
           (values 401 '(("content-type" . "application/json"))
                   (%octets "{\"error\":\"unauthorized\"}"))))
       (let* ((slash (position #\/ path* :start 13))
              (id (parse-integer (subseq path* 13 slash) :junk-allowed t))
              (entry (and id (demo-api-find id))))
         (if entry
             (values 200
                     (list (cons "content-type" "application/octet-stream")
                           (cons "content-disposition"
                                 (format nil "attachment; filename=\"~A\""
                                         (getf entry :title))))
                     (getf entry :bytes))
             (values 404 '(("content-type" . "application/json"))
                     (%octets "{\"error\":\"not found\"}")))))

      (t
       (values 404 '(("content-type" . "application/json"))
               (%octets "{\"error\":\"unknown api route\"}"))))))
