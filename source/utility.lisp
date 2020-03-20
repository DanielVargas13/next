;;; utility.lisp --- utility classes and functions
;; Split this file into smaller ones when it becomes relevant.

(in-package :next)
(annot:enable-annot-syntax)

@export
(defmethod object-string ((object t))
  (princ-to-string object))

(defmethod object-display ((object t))
  "Text shown by completion candidates in the minibuffer."
  (object-string object))

(defmethod object-string ((package package))
  (if (eq (package-name package) (find-package :next))
      ""
      (str:replace-all "next/" "" (str:downcase (package-name package)))))

(define-command start-swank (&optional (swank-port *swank-port*))
  "Start a Swank server that can be connected to, for instance, in Emacs via
SLIME."
  (swank:create-server :port swank-port :dont-close t))

@export
(defun xdg-data-home (&optional (file-name ""))
  "Return XDG_DATA_HOME as per XDG directory specification.
FILE-NAME is appended to the result."
  (merge-pathnames
   file-name
   (merge-pathnames
    (make-pathname :directory '(:relative "next"))
    (uiop:xdg-data-home))))

@export
(defun xdg-config-home (&optional (file-name ""))
  "Return XDG_CONFIG_HOME as per XDG directory specification.
FILE-NAME is appended to the result."
  (merge-pathnames
   file-name
   (merge-pathnames
    (make-pathname :directory '(:relative "next"))
    (uiop:xdg-config-home))))

(defun ensure-parent-exists (path)
  "Create parent directories of PATH if they don't exist and return PATH."
  (ensure-directories-exist (directory-namestring path))
  path)

(defun find-slot (class slot-name)
  "CLASS can be a symbol or a class."
  (when (symbolp class)
    (setf class (closer-mop:ensure-finalized (find-class class))))
  (find-if (lambda (slot)
             (eq (closer-mop:slot-definition-name slot)
                 slot-name))
           (closer-mop:class-slots class)))

@export
(defun get-default (class-name slot-name)
  "Get default value of slot SLOT-NAME from class CLASS-NAME.
The second value is the initfunction."
  (let* ((class (closer-mop:ensure-finalized (find-class class-name)))
         (slot (find-slot class slot-name))
         (value (closer-mop:slot-definition-initform slot)))
    ;; When querying quoted lists, the return value of slot-definition-initform
    ;; is quoted.  For lists declared with LIST, the return value is a list starting with symbol LIST.
    ;; In those cases, we eval it here so that the caller does not have to do it.
    ;; Besides, when the slot value is updated with SETF, the list is stored
    ;; unquoted / without LIST.  By evaluating here, we make sure that all calls to GET-DEFAULT
    ;; have consistent return types.  WARNING: This could be limitating if slot
    ;; was meant to actually store a quoted list.  Should this happen, we would
    ;; have to take some provision.
    (if (and (listp value)
             (or
              (eq 'quote (first value))
              (eq 'list (first value))))
        (eval value)
        value)))

@export
(defun member-string (string list)
  "Return the tail of LIST beginning whose first element is STRING."
  (check-type string string)
  (member string list :test #'string=))

@export
(defun notify (msg)
  "Echo this message and display it with a desktop notification system (notify-send on linux, terminal-notifier on macOs)."
  (echo-safe msg)
  (ignore-errors
    (uiop:launch-program
     #+linux
     (list "notify-send" msg)
     #+darwin
     (list "terminal-notifier" "-title" "Next" "-message" msg))))

@export
(defun launch-and-notify (command &key (success-msg "Command succeded.") (error-msg "Command failed."))
  "Run this program asynchronously and notify when it is finished."
  (bt:make-thread
   (lambda ()
     (let ((exit-code (uiop:wait-process
                       (uiop:launch-program command))))
       (notify (if (zerop exit-code) success-msg error-msg))))))

(defmethod write-output-to-log ((browser browser))
  "Set the *standard-output* and *error-output* to write to a log file."
  (values
   (setf *standard-output*
         (open (standard-output-path browser) :direction :output
                                                :if-does-not-exist :create :if-exists :append))
   (setf *error-output*
         (open (error-output-path browser) :direction :output :if-does-not-exist :create
                                             :if-exists :append))))

(defun funcall-safely (f &rest args)
  "Like `funcall' except that if `*keep-alive*' is nil (e.g. the program is run
from a binary) then any condition is logged instead of triggering the debugger."
  (handler-case
      (apply f args)
    (error (c)
      (if *keep-alive*
          (error c)
          ;; TODO: Echo this in a status bar or else it won't be seen if it
          ;; happens when the minibuffer is up.
          (log:error "Error in ~a: ~a" f c))
      nil)))
