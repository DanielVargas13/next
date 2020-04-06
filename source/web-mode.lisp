(uiop:define-package :next/web-mode
  (:use :common-lisp :trivia :next)
  (:import-from #:keymap #:define-key #:define-scheme)
  (:documentation "Mode for web pages"))
(in-package :next/web-mode)

(trivial-package-local-nicknames:add-package-local-nickname :sera :serapeum)

;; TODO: Remove web-mode from special buffers (e.g. help).
;; This is required because special buffers cannot be part of a history (and it breaks it).
;; Bind C-l to set-url-new-buffer?  Wait: What if we click on a link?  url
;; changes in special buffers should open a new one.
;; Or else we require that all special-buffer-generting commands open a new buffer.

(define-mode web-mode ()
  "Base mode for interacting with documents."
  ((history :accessor history
            :type htree:history-tree
            :initarg :history
            :initform (htree:make))
   (keymap-schemes
    :initform
    (define-scheme "web"
      scheme:cua
      (list
       "C-M-right" #'history-forwards-all-query
       "C-M-left" #'history-all-query
       "M-shift-right" #'history-forwards-query
       "M-shift-left" #'history-backwards-query
       "M-right" #'history-forwards
       "M-left" #'history-backwards
       "C-g" #'follow-hint
       "M-g" #'follow-hint-new-buffer-focus
       "C-u M-g" #'follow-hint-new-buffer
       "C-x C-w" #'copy-hint-url
       "C-v" #'paste
       "C-c" #'copy
       "button9" #'history-forwards
       "button8" #'history-backwards
       "C-p" #'scroll-up
       "C-n" #'scroll-down
       "C-x C-=" #'zoom-in-page
       "C-x s-+" #'zoom-in-page
       "C-x C-s-+" #'zoom-in-page
       "C-x C-+" #'zoom-in-page
       "C-x +" #'zoom-in-page
       "C-x C-hyphen" #'zoom-out-page
       "C-x hyphen" #'zoom-out-page
       "C-x C-0" #'unzoom-page
       "C-x 0" #'unzoom-page
       "C-r" #'reload-current-buffer
       "C-R" #'reload-buffer
       "C-m o" #'set-url-from-bookmark
       "C-m s" #'bookmark-current-page
       "C-m C-s" #'bookmark-page
       "C-m g" #'bookmark-hint
       "C-f" #'search-buffer
       "M-f" #'remove-search-hints
       "C-." #'jump-to-heading
       "M-s->" #'scroll-to-bottom
       "M-s-<" #'scroll-to-top
       "M->" #'scroll-to-bottom
       "M-<" #'scroll-to-top
       ;; "C-v" #'scroll-page-down
       "M-v" #'scroll-page-up
       "C-w" #'copy-url
       "M-w" #'copy-title
       ;; Leave SPACE unbound so that the paltform port decides wether to
       ;; insert of scroll.
       "s-space" #'scroll-page-up

       ;; keypad:
       "pageup" #'scroll-page-up
       "pagedown" #'scroll-page-down
       "pageend" #'scroll-to-bottom
       "pagehome" #'scroll-to-top
       ;; keypad, gtk:
       "keypadleft" #'scroll-left
       "keypaddown" #'scroll-down
       "keypadup" #'scroll-up
       "keypadright" #'scroll-right
       "keypadend" #'scroll-to-bottom
       "keypadhome" #'scroll-to-top
       "keypadnext" #'scroll-page-down
       "keypadpageup" #'scroll-page-up
       "keypadprior" #'scroll-page-up)

      scheme:emacs
      (list
       "C-M-f" #'history-forwards-all-query
       "C-M-b" #'history-all-query
       "M-f" #'history-forwards-query
       "M-b" #'history-backwards-query
       "C-f" #'history-forwards
       "C-b" #'history-backwards
       "C-g" #'follow-hint
       "M-g" #'follow-hint-new-buffer-focus
       "C-u M-g" #'follow-hint-new-buffer
       "C-x C-w" #'copy-hint-url
       "M-y" #'paste
       "C-y" #'copy
       "button9" #'history-forwards
       "button8" #'history-backwards
       "C-p" #'scroll-up
       "C-n" #'scroll-down
       "C-x C-=" #'zoom-in-page
       "C-x s-+" #'zoom-in-page
       "C-x C-s-+" #'zoom-in-page
       "C-x C-+" #'zoom-in-page
       "C-x +" #'zoom-in-page
       "C-x C-hyphen" #'zoom-out-page
       "C-x hyphen" #'zoom-out-page
       "C-x C-0" #'unzoom-page
       "C-x 0" #'unzoom-page
       "C-r" #'reload-current-buffer
       "C-R" #'reload-buffer
       "C-m o" #'set-url-from-bookmark
       "C-m s" #'bookmark-current-page
       "C-m C-s" #'bookmark-page
       "C-m g" #'bookmark-hint
       "C-s s" #'search-buffer
       "C-s k" #'remove-search-hints
       "C-." #'jump-to-heading
       "M-s->" #'scroll-to-bottom
       "M-s-<" #'scroll-to-top
       "M->" #'scroll-to-bottom
       "M-<" #'scroll-to-top
       ;; "C-v" #'scroll-page-down
       "M-v" #'scroll-page-up
       "C-w" #'copy-url
       "M-w" #'copy-title
       ;; Leave SPACE unbound so that the paltform port decides wether to
       ;; insert of scroll.
       "s-space" #'scroll-page-up

       ;; keypad:
       "pageup" #'scroll-page-up
       "pagedown" #'scroll-page-down
       "pageend" #'scroll-to-bottom
       "pagehome" #'scroll-to-top
       ;; keypad, gtk:
       "keypadleft" #'scroll-left
       "keypaddown" #'scroll-down
       "keypadup" #'scroll-up
       "keypadright" #'scroll-right
       "keypadend" #'scroll-to-bottom
       "keypadhome" #'scroll-to-top
       "keypadnext" #'scroll-page-down
       "keypadpageup" #'scroll-page-up
       "keypadprior" #'scroll-page-up)

      scheme:vi-normal
      (list
       "H" #'history-backwards
       "L" #'history-forwards
       "M-h" #'history-backwards-query
       "M-l" #'history-forwards-query
       "M-H" #'history-all-query
       "M-L" #'history-forwards-all-query
       "f" #'follow-hint
       "F" #'follow-hint-new-buffer-focus
       "; f" #'follow-hint-new-buffer
       "button9" #'history-forwards
       "button8" #'history-backwards

       "h" #'scroll-left
       "j" #'scroll-down
       "k" #'scroll-up
       "l" #'scroll-right
       "left" #'scroll-left
       "down" #'scroll-down
       "up" #'scroll-up
       "right" #'scroll-right
       ;; keypad:
       "pageend" #'scroll-to-bottom
       "pagehome" #'scroll-to-top
       ;; keypad, gtk:
       "keypadleft" #'scroll-left
       "keypaddown" #'scroll-down
       "keypadup" #'scroll-up
       "keypadright" #'scroll-right
       "keypadend" #'scroll-to-bottom
       "keypadhome" #'scroll-to-top
       "keypadnext" #'scroll-page-down
       "keypadpageup" #'scroll-page-up
       "keypadprior" #'scroll-page-up

       "C-v" #'paste
       "z i" #'zoom-in-page
       "z o" #'zoom-out-page
       "z z" #'unzoom-page
       "R" #'reload-current-buffer
       "r" #'reload-buffer
       "m o" #'set-url-from-bookmark
       "m m" #'bookmark-page
       "m M" #'bookmark-current-page
       "m f" #'bookmark-hint
       "y u" #'copy-url
       "y t" #'copy-title
       "g h" #'jump-to-heading ; REVIEW: VI binding?  "gh" is probably good enough.
       "/" #'search-buffer
       "?" #'remove-search-hints
       "G" #'scroll-to-bottom
       "g g" #'scroll-to-top
       "C-f" #'scroll-page-down
       "C-b" #'scroll-page-up
       "space" #'scroll-page-down
       "s-space" #'scroll-page-up
       "pageup" #'scroll-page-up
       "pagedown" #'scroll-page-down))))
  ;; Init.
  ;; TODO: Do we need to set the default URL?  Maybe not.
  ;; (set-url (default-new-buffer-url (buffer %mode))
  ;;                 (buffer %mode))
  )

(declaim (ftype (function (htree:node &optional buffer)) set-url-from-history))
(defun set-url-from-history (history-node &optional (buffer (current-buffer)))
  "Go to HISTORY-NODE's URL."
  (let ((history (history (find-submode buffer 'web-mode))))
    (if (eq history-node (htree:current history))
        (echo "History entry is already the current URL.")
        (progn
          (setf (htree:current history) history-node)
          (set-url (url (htree:data history-node)))))))

(define-command history-backwards (&optional (buffer (current-buffer)))
  "Go to parent URL in history."
  (let* ((mode (find-submode buffer 'web-mode)))
    (if (eq (htree:root (history mode)) (htree:current (history mode)))
        (echo "No backward history.")
        (progn
          (htree:back (history mode))
          (match (htree:current (history mode))
            ((guard n n) (set-url (url (htree:data n)))))))))

(define-command history-forwards (&optional (buffer (current-buffer)))
  "Go to forward URL in history."
  (let* ((mode (find-submode buffer 'web-mode)))
    (if (htree:children-nodes (history mode))
        (progn
          (htree:forward (history mode))
          (match (htree:current (history mode))
            ((guard n n) (set-url (url (htree:data n))))))
        (echo "No forward history."))))

(defun history-backwards-completion-filter (&optional (mode (find-submode
                                                             (current-buffer)
                                                             'web-mode)))
  "Completion function over all parent URLs."
  (let ((parents (htree:parent-nodes (history mode))))
    (lambda (input)
      (if parents
          (fuzzy-match input parents)
          (error "Cannot navigate backwards.")))))

(define-command history-backwards-query ()
  "Query parent URL to navigate back to."
  (with-result (input (read-from-minibuffer
                       (make-minibuffer
                        :input-prompt "Navigate backwards to"
                        :completion-function (history-backwards-completion-filter))))
    (when input
      (set-url-from-history input))))

(defun history-forwards-completion-filter (&optional (mode (find-submode
                                                            (current-buffer)
                                                            'web-mode)))
  "Completion function over forward-children URL."
  (let ((children (htree:forward-children-nodes (history mode))))
    (lambda (input)
      (if children
          (fuzzy-match input children)
          (error "Cannot navigate forwards.")))))

(define-command history-forwards-query ()
  "Query forward-URL to navigate to."
  (with-result (input (read-from-minibuffer
                       (make-minibuffer
                        :input-prompt "Navigate forwards to"
                        :completion-function (history-forwards-completion-filter))))
    (when input
      (set-url-from-history input))))

(define-command history-forwards-maybe-query (&optional (mode (find-submode
                                                               (current-buffer)
                                                               'web-mode)))
  "If current node has multiple chidren, query forward-URL to navigate to.
Otherwise go forward to the only child."
  (if (<= 2 (length (htree:children-nodes (history mode))))
      (history-forwards-all-query)
      (history-forwards)))

(defun history-forwards-all-completion-filter (&optional (mode (find-submode
                                                                (current-buffer)
                                                                'web-mode)))
  "Completion function over children URL from all branches."
  (let ((children (htree:children-nodes (history mode))))
    (lambda (input)
      (if children
          (fuzzy-match input children)
          (error "Cannot navigate forwards.")))))

(define-command history-forwards-all-query ()
  "Query URL to forward to, from all child branches."
  (with-result (input (read-from-minibuffer
                       (make-minibuffer
                        :input-prompt "Navigate forwards to (all branches)"
                        :completion-function (history-forwards-all-completion-filter))))
    (when input
      (set-url-from-history input))))

(defun history-all-completion-filter (&optional (mode (find-submode
                                                       (current-buffer)
                                                       'web-mode)))
  "Completion function over all history URLs."
  (let ((urls (htree:all-nodes (history mode))))
    (lambda (input)
      (if urls
          (fuzzy-match input urls)
          (error "No history.")))))

(define-command history-all-query ()
  "Query URL to go to, from the whole history."
  (with-result (input (read-from-minibuffer
                       (make-minibuffer
                        :input-prompt "Navigate to"
                        :completion-function (history-all-completion-filter))))
    (when input
      (set-url-from-history input))))

(define-command buffer-history-tree (&optional (buffer (current-buffer)))
  "Open a new buffer displaying the whole history tree."
  (labels ((traverse (node current)
             (when node
               `(:ul :class "tree" (:li (:a :href ,(url (htree:data node))
                              ,(let ((title (or (match (title (htree:data node))
                                                  ((guard e (not (str:emptyp e))) e))
                                                (url (htree:data node)))))
                                 (if (eq node current)
                                     `(:b ,title)
                                     title))))
                     ,@(match (mapcar (lambda (n) (traverse n current))
                                      (htree:children node))
                         ((guard l l) l))))))
    (let* ((style (cl-css:css
                   `((".tree, .tree ul"
                      :list-style-type "none"
                      :margin-left "0 0 0 10px"
                      :padding 0
                      :position "relative"
                      :overflow "hidden")
                     (".tree li"
                      :margin 0
                      :padding "0 12px"
                      :position "relative")
                     (".tree li::before, .tree li::after"
                      :content "''"
                      :position "absolute"
                      :left 0)
                     (".tree li::before"
                      :border-top "1px solid #999"
                      :top "10px"
                      :width "10px"
                      :height 0)
                     (".tree li:after"
                      :border-left "1px solid #999"
                      :height "100%"
                      :width "0px"
                      :top "-10px")
                     (".tree > li::after"
                      :top "10px")
                     (".tree > li:last-child::after"
                      :display "none"))))
           (buffer-name (format nil "*History-~a*" (id buffer)))
           (output-buffer (or (find-if (lambda (b) (string= buffer-name (title b)))
                                       (buffer-list))
                              (help-mode :activate t :buffer (make-buffer :title buffer-name))))
           (history (history (find-submode buffer 'web-mode)))
           (tree (traverse (htree:root history)
                           (htree:current history)))
           (content (markup:markup*
                     `(:head (:style (cl-markup:raw ,style)))
                     '(:h1 "History")
                     tree))
           (insert-content (ps:ps (setf (ps:@ document Body |innerHTML|)
                                        (ps:lisp content)))))
      (print content)
      (ffi-buffer-evaluate-javascript output-buffer insert-content)
      (set-current-buffer output-buffer))))

(define-command copy-url ()
  "Save current URL to clipboard."
  (copy-to-clipboard (url (current-buffer)))
  (echo "~a copied to clipboard." (url (current-buffer))))

(define-command copy-title ()
  "Save current page title to clipboard."
  (copy-to-clipboard (title (current-buffer)))
  (echo "~a copied to clipboard." (title (current-buffer))))

(define-parenscript %paste ((input-text (ring-insert-clipboard (clipboard-ring *browser*))))
  (let* ((active-element (ps:chain document active-element))
         (start-position (ps:chain active-element selection-start))
         (end-position (ps:chain active-element selection-end)))
    (setf (ps:chain active-element value)
          (+ (ps:chain active-element value (substring 0 start-position))
             (ps:lisp input-text)
             (ps:chain active-element value
                       (substring end-position
                                  (ps:chain active-element value length)))))))

(define-command paste ()
  "Paste from clipboard into active-element."
  (%paste))

(defun ring-completion-filter (ring)
  (let ((ring-items (ring:recent-list ring)))
    (lambda (input)
      (fuzzy-match input ring-items))))

(define-command paste-from-ring ()
  "Show `*browser*' clipboard ring and paste selected entry."
  (with-result (ring-item (read-from-minibuffer
                           (make-minibuffer
                            :completion-function (ring-completion-filter
                                                  (clipboard-ring *browser*)))))
    (%paste :input-text ring-item)))

(define-parenscript %copy ()
  "Return selected text from javascript."
  (ps:chain window (get-selection) (to-string)))

(defun copy-to-clipboard (input)
  "Save INPUT text to clipboard, and ring."
  (ring:insert (clipboard-ring *browser*) (trivial-clipboard:text input)))

(define-command copy ()
  "Copy selected text to clipboard."
  (with-result (input (%copy))
    (copy-to-clipboard input)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Warning: To specialize `did-commit-navigation' we must be in the right package.
(in-package :next)
(defmethod did-commit-navigation ((mode next/web-mode::web-mode) url)
  (echo "Loading: ~a." url))

(defmethod did-finish-navigation ((mode next/web-mode::web-mode) url)
  (let* ((buffer (active-buffer (current-window))))
    ;; TODO: Setting the default zoom level works with pure Javascript, but it
    ;; can only be done after the URL has been loaded which is a bit of a
    ;; kludge.  Instead we could add an RPC endpoint,
    ;; e.g. webkit_web_view_set_zoom_level.
    (unzoom-page :buffer buffer)
    (set-window-title (current-window) buffer)
    (htree:add-child (make-instance 'buffer-description
                                    :url url
                                    :title (title buffer))
                     (next/web-mode::history mode)
                     :test #'equals)
    (when url
      (history-add url :title (title buffer)))
    (match (session-store-function *browser*)
      ((guard f f) (funcall f))))
  (echo "Finished loading: ~a." url)
  ;; TODO: Wait some time before dismissing the minibuffer.
  (echo-dismiss))

(defmethod object-string ((node htree:node))
  (object-string (when node (htree:data node))))
