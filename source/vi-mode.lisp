(uiop:define-package :next/vi-mode
  (:use :common-lisp :trivia :next)
  (:import-from #:keymap #:define-key)
  (:documentation "VI-style bindings."))
(in-package :next/vi-mode)

(define-mode vi-normal-mode ()
  "Enable VI-style modal bindings (normal mode)"
  ((keymap-schemes
    :initform
    (let ((map (keymap:make-keymap)))
      (define-key map
        "i" #'vi-insert-mode
        "button1" #'vi-button1)
      (list :vi-normal map)))
   (destructor
    :initform
    (lambda (mode)
      (setf (current-keymap-scheme (buffer mode))
            (get-default 'buffer 'current-keymap-scheme))
      (setf (forward-input-events-p (buffer mode))
            (get-default 'buffer 'current-keymap-scheme))))
   (constructor
    :initform
    (lambda (mode)
      (let ((active-buffer (buffer mode)))
        (vi-insert-mode :activate nil :buffer active-buffer)
        (setf (current-keymap-scheme active-buffer) :vi-normal)
        (setf (forward-input-events-p active-buffer) nil))))))

;; TODO: Move ESCAPE binding to the override map?
(define-mode vi-insert-mode ()
  "Enable VI-style modal bindings (insert mode)"
  ((keymap-schemes
    :initform
    (let ((map (keymap:make-keymap)))
      (define-key map
        ;; TODO: Forwarding C-v crashes cl-webkit.  See
        ;; https://github.com/atlas-engineer/next/issues/593#issuecomment-599051350
        "C-v" #'next/web-mode:paste
        "ESCAPE" #'vi-normal-mode
        "button1" #'vi-button1)
      (list :vi-insert map)))
   (destructor
    :initform
    (lambda (mode)
      (setf (current-keymap-scheme (buffer mode))
            (get-default 'buffer 'current-keymap-scheme))))
   (constructor
    :initform
    (lambda (mode)
      (let ((active-buffer (buffer mode)))
        (vi-normal-mode :activate nil :buffer active-buffer)
        (setf (current-keymap-scheme active-buffer) :vi-insert))))))

(define-parenscript %clicked-in-input? ()
  (ps:chain document active-element tag-name))

(declaim (ftype (function (string)) input-tag-p))
(defun input-tag-p (tag)
  (or (string= tag "INPUT")
      (string= tag "TEXTAREA")))

(define-command vi-button1 (&optional (buffer (current-buffer)))
  "Enable VI insert mode when focus is on an input element on the web page."
  (let ((root-mode (find-mode buffer 'root-mode)))
    ;; First we generate a button1 event so that the web view element is clicked
    ;; (e.g. a text field gets focus).
    (ipc-generate-input-event
     (ipc-window-active *browser*)
     (last-event (buffer root-mode)))
    (%clicked-in-input?
     :callback (lambda (response)
                 (cond
                   ((and (input-tag-p response)
                         (find-submode (buffer root-mode) 'vi-normal-mode))
                    (vi-insert-mode))
                   ((and (not (input-tag-p response))
                         (find-submode (buffer root-mode) 'vi-insert-mode))
                    (vi-normal-mode)))))))

(defmethod did-finish-navigation ((mode vi-insert-mode) url)
  (declare (ignore url))
  (vi-normal-mode))
