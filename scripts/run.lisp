;;;; Local runner: ros -l scripts/run.lisp
;;;; Env: HTTP_PARITY_BACKEND (async|dexador|winhttp), HTTP_PARITY_BASE, HTTP_PARITY_LIVE

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&UNHANDLED: ~A~%" c)
        (uiop:quit 1)))

(asdf:load-system "http-parity")
(uiop:quit (if (http-parity:run) 0 1))
