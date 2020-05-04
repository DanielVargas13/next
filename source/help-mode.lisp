(uiop:define-package :next/help-mode
  (:use :common-lisp :trivia :next)
  (:import-from #:keymap #:define-key #:define-scheme)
  (:documentation "Mode for help pages"))
(in-package :next/help-mode)

(define-mode help-mode ()
  "Mode for displaying documentation."
  ((keymap-scheme
    :initform
    (define-scheme "help"
      scheme:emacs
      (list
       "C-p" 'scroll-up
       "C-n" 'scroll-down)
      scheme:vi-normal
      (list
       "k" 'scroll-up
       "j" 'scroll-down)))))
