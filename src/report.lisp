(in-package #:http-parity)

;;; Static feature matrix (requests / httpx vocabulary → stack status).

(defparameter *matrix*
  '(;; area  requests/httpx          status   notes
    ("verbs" "get/post/put/patch/delete/head/options" :have "stack-http facade")
    ("async" "AsyncClient / *-async" :have "blackbird promises; sync SEND awaits")
    ("session" "Session / Client cookies+base_url" :have "with-session")
    ("json" "json= / r.json()" :have ":json + response-json")
    ("form" "data= urlencoded" :have ":form-data (http-protocol 0.2)")
    ("files" "files= multipart" :have "coerce-files / path-http-file")
    ("download" "path write" :have "download / download-async")
    ("upload" "path read" :have "upload / upload-async")
    ("text" "r.text / charset" :have "response-text")
    ("content" "r.content" :have "response-content")
    ("ok" "r.ok / raise_for_status" :have "response-ok-p / raise-for-status")
    ("stream" "iter_bytes / iter_lines" :have "want-stream H1+H2 (async 0.2.6)")
    ("stream-h2" "http2=True + stream=True" :have "H2 :want-stream + trailers; live HTTP_PARITY_H2")
    ("gzip" "Content-Encoding gzip" :have "http-encoding-chipz")
    ("deflate" "Content-Encoding deflate" :have "http-encoding-chipz")
    ("br" "Content-Encoding br" :partial "soft-load http-encoding-brotli")
    ("zstd" "Content-Encoding zstd" :partial "soft-load http-encoding-zstd")
    ("basic" "HTTPBasicAuth" :have ":auth (:basic u p)")
    ("bearer" "Authorization Bearer" :have ":auth (:bearer tok)")
    ("digest" "HTTPDigestAuth" :have "stack-http digest-auth retry (sync)")
    ("netrc" "trust_env + ~/.netrc" :have "trust-env t")
    ("redirect" "allow_redirects / history" :have "protocol redirects")
    ("timeout" "timeout=" :have "http-timeout")
    ("proxy" "proxies=" :have "http-proxy-config / env")
    ("socks" "socks5://" :partial "async SOCKS5; not all backends")
    ("http2" "http2=True" :have "http-protocol 0.3.0 preference/ALPN; async/winhttp wire")
    ("oauth2" "auth plugins" :sep "cl-stack-oauth2")
    ("jwt" "JWT helpers" :sep "cl-stack-jwt")
    ("ws" "WebSocket" :sep "ws-protocol"))
  "Parity matrix rows: (area python-name status notes).
   Status: :have :partial :missing :sep (separate package).")

(defun print-matrix (&optional (stream *standard-output*))
  (format stream "~&~%~40A  ~8A  ~A~%" "area" "status" "notes")
  (format stream "~&~40A  ~8A  ~A~%"
          (make-string 40 :initial-element #\-)
          (make-string 8 :initial-element #\-)
          "-----")
  (dolist (row *matrix*)
    (destructuring-bind (area py status notes) row
      (format stream "~&~40A  ~8A  ~A~%"
              (format nil "~A (~A)" area py)
              (string-downcase (symbol-name status))
              notes)))
  (format stream "~&")
  (values))

(defun run (&key (backend *preferred-backend*))
  "Print matrix + run Rove suite. Returns T on success."
  (let ((*preferred-backend* backend))
    (ensure-fixture)
    (format t "~&; http-parity backend=~S base=~S fixture=~A live=~A~%"
            *preferred-backend* *live-base*
            (fixture-enabled-p) (live-enabled-p))
    (print-matrix)
    (unwind-protect
         (handler-case
             (progn (asdf:test-system "http-parity") t)
           (error (e)
             (format *error-output* "~&; http-parity failed: ~A~%" e)
             nil))
      (when (fixture-enabled-p)
        (stop-fixture)))))