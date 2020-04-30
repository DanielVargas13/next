;;; start.lisp --- main entry point into Next

(in-package :next)

(export-always '*init-file-path*)
(defvar *init-file-path* (make-instance 'data-path
                                        :basename "init"
                                        :dirname (uiop:xdg-config-home +data-root+))
  "The path of the initialization file.")

(export-always '*socket-path*)
(defvar *socket-path* (make-instance 'data-path :basename "next.socket")
  "Path string of the Unix socket used to communicate between different
instances of Next.

This path cannot be set from the init file because we want to be able to set and
use the socket without parsing any init file.")

(defmethod expand-data-path ((path (eql *init-file-path*)) (profile data-profile))
  "Return path of the init file."
  (cond
    ((getf *options* :no-init)
     nil)
    (t (match (getf *options* :init)
         ("-" "-")
         (nil (expand-default-path path))
         (new-path
          (expand-default-path (make-instance 'init-file-data-path
                                              :basename new-path
                                              :dirname (directory path))))))))

(defmethod expand-data-path ((path (eql *socket-path*)) (profile data-profile))
  "Return path of the socket."
  (cond
    ((getf *options* :no-socket)
     nil)
    (t (match (getf *options* :socket)
         (nil (expand-default-path path))
         (new-path
          (expand-default-path (make-instance 'socket-data-path
                                              :basename new-path
                                              :dirname (directory path))))))))

(defun handle-malformed-cli-arg (condition)
  (format t "Error parsing argument ~a: ~a.~&" (opts:option condition) condition)
  (opts:describe)
  (uiop:quit))

(defun parse-cli-args ()
  "Parse command line arguments."
  (opts:define-opts
    (:name :help
           :description "Print this help and exit."
           :short #\h
           :long "help")
    (:name :verbose
           :short #\v
           :long "verbose"
           :description "Print debugging information to stdout.")
    (:name :version
           :long "version"
           :description "Print version and exit.")
    (:name :init
           :short #\i
           :long "init"
           :arg-parser #'identity
           :description "Set path to initialization file.
Set to '-' to read standard input instead.")
    (:name :no-init
           :short #\I
           :long "no-init"
           :description "Do not load the user init file.")
    (:name :socket
           :short #\s
           :long "socket"
           :arg-parser #'identity
           :description "Set path to socket.
Unless evaluating remotely (see --remote), Next starts in single-instance mode a socket is set.")
    (:name :no-socket
           :short #\S
           :long "no-socket"
           :description "Do not use any socket.")
    (:name :eval
           :short #\e
           :long "eval"
           :arg-parser #'identity
           :description "Eval the Lisp expressions.  Can be specified multiple times.")
    (:name :load
           :short #\l
           :long "load"
           :arg-parser #'identity
           :description "Load the Lisp file.  Can be specified multiple times.")
    (:name :script
           :long "script"
           :arg-parser #'identity
           :description "Load the Lisp file (skip #! line if any), skip init file, then exit.")
    (:name :remote
           :short #\r
           :long "remote"
           :description "Send the --eval and --load arguments to the running instance of Next.
The remote instance must be listening on a socket which you can specify with --socket.")
    (:name :profile
           :short #\p
           :long "profile"
           :arg-parser #'identity
           :description "Use the given data profile.
A profile is an exported variable that evaluate to a subclass of `data-profile'.")
    (:name :list-profiles
           :long "list-profiles"
           :description "List the known data profiles and exit.
A profile is an exported variable that evaluate to a subclass of `data-profile'.")
    (:name :with-path
           :long "with-path"
           :arg-parser (lambda (arg) (str:split "=" arg :limit 2))
           :description "Set data path reference to the given path.
Can be specified multiple times.
Example: --with-path bookmarks=/path/to/bookmarks"))
  (handler-bind ((opts:unknown-option #'handle-malformed-cli-arg)
                 (opts:missing-arg #'handle-malformed-cli-arg)
                 (opts:arg-parser-failed #'handle-malformed-cli-arg))
    (opts:get-opts)))

(define-command quit ()
  "Quit Next."
  (hooks:run-hook (before-exit-hook *browser*))
  (loop for window in (window-list)
        do (ffi-window-delete window))
  (ffi-kill-browser *browser*)
  (when (socket-thread *browser*)
    (ignore-errors
     (bt:destroy-thread (socket-thread *browser*))))
  (let ((socket-path (expand-path *socket-path*)))
    (when (uiop:file-exists-p )
      (log:info "Deleting socket ~a" socket-path)
      (uiop:delete-file-if-exists socket-path)))
  (unless *keep-alive*
    (uiop:quit 0 nil)))

(define-command quit-after-clearing-session ()
  "Clear session then quit Next."
  (setf
   (session-store-function *browser*) nil
   (session-restore-function *browser*) nil)
  (uiop:delete-file-if-exists (expand-path (session-path *browser*)))
  (quit))

;; From sbcl/src/code/load.lisp
(defun maybe-skip-shebang-line (stream)
  (let ((p (file-position stream)))
    (when p
      (flet ((next () (read-byte stream nil)))
        (unwind-protect
             (when (and (eq (next) (char-code #\#))
                        (eq (next) (char-code #\!)))
               (setf p nil)
               (loop for x = (next)
                     until (or (not x) (eq x (char-code #\newline)))))
          (when p
            (file-position stream p)))))))

(export-always 'entry-point)
(defun entry-point ()
  "Read the CLI arguments and start the browser."
  (multiple-value-bind (options free-args)
      (parse-cli-args)
    (setf *keep-alive* nil)             ; Not a REPL.
    (in-package :next-user)
    (apply #'start options free-args)))

(defparameter *load-init-error-message* "Error: Could not load the init file")
(defparameter *load-init-type-error-message* (str:concat *load-init-error-message*
                                                         " because of a type error"))

(declaim (ftype (function (trivial-types:pathname-designator &key (:package (or null package))))
                load-lisp))
(defun load-lisp (file &key package)
  "Load the Lisp FILE (or stream).
If FILE is \"-\", read from the standard input."
  (let ((*package* (or (find-package package) *package*)))
    (flet ((safe-load ()
             (when (equal "" file)
               (error "Can't load empty file name."))
             (cond
               ((and (not (streamp file)) (string= (pathname-name file) "-"))
                (progn
                  (format t "Loading Lisp from standard input...")
                  (loop for object = (read *standard-input* nil :eof)
                        until (eq object :eof)
                        do (eval object))))
               ((streamp file)
                (load file))
               ((uiop:file-exists-p file)
                (format t "~&Loading Lisp file ~s...~&" file)
                (load file)))))
      (if *keep-alive*
          (safe-load)
          (handler-case
              (safe-load)
            (error (c)
              (let ((message (if (subtypep (type-of c) 'type-error)
                                 *load-init-type-error-message*
                                 *load-init-error-message*)))
                (echo-warning "~a: ~a" message c)
                (notify (str:concat message ".")))))))))

(define-command load-file ()
  "Load the prompted Lisp file."
  (with-result (file-name-input (read-from-minibuffer
                                 (make-minibuffer
                                  :input-prompt "Load file"
                                  :show-completion-count nil)))
    (load-lisp file-name-input)))

(define-command load-init-file (&key (init-file (expand-path *init-file-path*)))
  "Load or reload the init file."
  (load-lisp init-file :package (find-package :next-user)))

(defun eval-expr (expr)
  "Evaluate the form EXPR (string) and print the result of the last expresion."
  (handler-case
      (with-input-from-string (input expr)
        (format t "~a~&"
                (loop with result = nil
                      for object = (read input nil :eof)
                      until (eq object :eof)
                      do (setf result (eval object))
                      finally (return result))))
    (error (c)
      (format *error-output* "~%~a~&~a~&" (cl-ansi-text:red "Evaluation error:") c)
      (uiop:quit 1))))

(defun default-startup (&optional urls)
  "Make a window and load URLS in new buffers.
This function is suitable as a `browser' `startup-function'."
  (let ((window (window-make *browser*))
        (buffer (help)))
    (if urls
        (open-urls urls)
        (window-set-active-buffer window buffer)))
  (when (startup-error-reporter-function *browser*)
    (funcall-safely (startup-error-reporter-function *browser*)))
  (unless (expand-path (session-path *browser*))
    (flet ((restore-session ()
             (when (and (session-restore-function *browser*)
                        (uiop:file-exists-p (expand-path (session-path *browser*))))
               (log:info "Restoring session '~a'" (expand-path (session-path *browser*)))
               (funcall (session-restore-function *browser*)))))
      (match (session-restore-prompt *browser*)
        (:always-ask
         (with-confirm ("Restore previous session?")
           (restore-session)))
        (:always-restore
         (restore-session))
        (:never-restore (log:info "Not restoring session."))))))

(defun open-external-urls (urls)
  (if urls
      (log:info "Externally requested URL(s): ~{~a~^, ~}" urls)
      (log:info "Externally pinged."))
  (ffi-within-renderer-thread
   *browser*
   (lambda () (open-urls urls))))

(defun listen-socket ()
  (let ((socket-path (expand-path *socket-path*)))
    (when socket-path
      (ensure-parent-exists socket-path)
      ;; TODO: Catch error against race conditions?
      (iolib:with-open-socket (s :address-family :local
                                 :connect :passive
                                 :local-filename socket-path)
        (loop as connection = (iolib:accept-connection s)
              while connection
              do (progn (match (alex:read-stream-content-into-string connection)
                          ((guard expr (not (uiop:emptyp expr)))
                           (log:info "External evaluation request: ~s" expr)
                           (eval-expr expr))
                          (_
                           (log:info "External process pinged Next.")))
                        ;; If we get pinged too early, we do not have a current-window yet.
                        (when (current-window)
                          (ffi-window-to-foreground (current-window))))))
      (log:info "Listening on socket ~s" socket-path))))

(defun listening-socket-p ()
  (ignore-errors
   (iolib:with-open-socket (s :address-family :local
                              :remote-filename (expand-path *socket-path*))
     (iolib:socket-connected-p s))))

(defun bind-socket-or-quit (urls)
  "If another Next is listening on the socket, tell it to open URLS.
Otherwise bind socket."
  (let ((socket-path (expand-path *socket-path*)))
    (if (listening-socket-p)
        (progn
          (if urls
              (log:info "Next already started, requesting to open URL(s): ~{~a~^, ~}" urls)
              (log:info "Next already started." urls))
          (iolib:with-open-socket (s :address-family :local
                                     :remote-filename socket-path)
            (format s "~s" `(open-external-urls ',urls)))
          (uiop:quit))
        (progn
          (uiop:delete-file-if-exists socket-path)
          (setf (socket-thread *browser*) (bt:make-thread #'listen-socket))))))

(defun remote-eval (expr)
  "If another Next is listening on the socket, tell it to evaluate EXPR."
  (if (listening-socket-p)
      (progn
        (iolib:with-open-socket (s :address-family :local
                                   :remote-filename (expand-path *socket-path*))
          (write-string expr s))
        (uiop:quit))
      (progn
        (log:info "No instance running.")
        (uiop:quit))))

(export-always 'start)
(defun start (&optional options &rest free-args)
  "Parse options (either from command line or from the REPL) and perform the
corresponding action.
With no action, start the browser.

REPL examples:

- Display version and return immediately:
  (next:start '(:version t))

- Start the browser and open the given URLs.
  (next:start nil \"https://next.atlas.engineer\" \"https://en.wikipedia.org\")"
  ;; Options should be accessible anytime, even when run from the REPL.
  (setf *options* options)

  (cond
    ((getf options :help)
     (opts:describe :prefix "Next command line usage:

next [options] [urls]"))

    ((getf options :version)
     (format t "Next version ~a~&" +version+))

    ((getf options :list-profiles)
     (unless (or (getf *options* :no-init)
                 (not (expand-path *init-file-path*)))
       (load-lisp (expand-path *init-file-path*) :package (find-package :next-user)))
     (mapcar (lambda (pair)
               (format t "~a~10t~a~&" (first pair) (second pair)))
             (mapcar #'rest (package-data-profiles))))

    ((getf options :script)
     (with-open-file (f (getf options :script) :element-type :default)
       (maybe-skip-shebang-line f)
       (load-lisp f)))

    ((or (getf options :load)
         (getf options :eval))
     (start-load-or-eval))

    (t
     (start-browser free-args)))

  (unless *keep-alive* (uiop:quit)))

(defun start-load-or-eval ()
  "Evaluate Lisp.
The evaluation may happen on its own instance or on an already running instance."
  (unless (or (getf *options* :no-init)
              (not (expand-path *init-file-path*)))
    (load-lisp (expand-path *init-file-path*) :package (find-package :next-user)))
  (loop for (opt value . _) on *options*
        do (match opt
             (:load (let ((value (uiop:truename* value)))
                      ;; Absolute path is necessary since remote process may have
                      ;; a different working directory.
                      (if (getf *options* :remote)
                          (remote-eval (format nil "~s" `(load-lisp ,value)))
                          (load-lisp value))))
             (:eval (if (getf *options* :remote)
                        (remote-eval value)
                        (eval-expr value))))))

(defun start-browser (free-args)
  "Load INIT-FILE if non-nil.
Instantiate `*browser*'.
Start Next and load URLS if any.
Finally,run the `*after-init-hook*'."
  (let ((startup-timestamp (local-time:now))
        (startup-error-reporter nil))
    (format t "Next version ~a~&" +version+)
    (if (getf *options* :verbose)
        (progn
          (log:config :debug)
          (format t "Arguments parsed: ~a and ~a~&" *options* free-args))
        (log:config :pattern "<%p> [%D{%H:%M:%S}] %m%n"))

    (unless (or (getf *options* :no-init)
                (not (expand-path *init-file-path*)))
      (handler-case
          (load-lisp (expand-path *init-file-path*) :package (find-package :next-user))
        (error (c)
          (setf startup-error-reporter
                (lambda ()
                  (error-in-new-window "*Init file errors*" (format nil "~a" c)))))))
    (setf *browser* (make-instance *browser-class*
                                   :startup-error-reporter-function startup-error-reporter
                                   :startup-timestamp startup-timestamp))
    (when (expand-path *socket-path*)
      (bind-socket-or-quit free-args))
    (ffi-initialize *browser* free-args startup-timestamp)))

(define-command next-init-time ()
  "Return the duration of Next initialization."
  (echo "~,2f seconds" (slot-value *browser* 'init-time)))
