(uiop:define-package :next/application-mode
    (:use :common-lisp :trivia :next)
  (:documentation "Forward all keybindings to the web view except those in the `override-map'."))
(in-package :next/application-mode)

;; Moving modes out of the `modes' slot is a bad idea: too many parts rely on
;; the presence of the `modes' slot.

(define-mode application-mode ()
  "Mode that forwards all keys to the renderer."
  ((destructor
    :initform
    (lambda (mode)
      (hooks:remove-hook (current-keymaps-hook (buffer mode))
                         'keep-override-map)))
   (constructor
    :initform
    (lambda (mode)
      (if (current-keymaps-hook (buffer mode))
          (hooks:add-hook (current-keymaps-hook (buffer mode))
                          (make-handler-keymaps-buffer #'keep-override-map))
          (make-hook-keymaps-buffer
             :combination #'hooks:combine-composed-hook
             :handlers (list #'keep-override-map)))))))

(declaim (ftype (function (list-of-keymaps buffer) (values list-of-keymaps buffer))
                keep-override-map))
(defun keep-override-map (keymaps buffer)
  (if (active-minibuffers (current-window))
      (values keymaps buffer)
      (values (list (override-map buffer)) buffer)))
