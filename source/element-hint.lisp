(in-package :next/web-mode)

(define-parenscript add-element-hints (&key annotate-full-document)
  (defun qs (context selector)
    "Alias of document.querySelector"
    (ps:chain context (query-selector selector)))
  
  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))

  (defun code-char (n)
    "Alias of String.fromCharCode"
    (ps:chain -string (from-char-code n)))

  (defun add-stylesheet ()
    (unless (qs document "#next-stylesheet")
      (ps:try
       (ps:let* ((style-element (ps:chain document (create-element "style")))
                 (box-style (ps:lisp (box-style (current-buffer))))
                 (highlighted-style (ps:lisp (highlighted-box-style (current-buffer)))))
         (setf (ps:@ style-element id) "next-stylesheet")
         (ps:chain document head (append-child style-element))
         (ps:chain style-element sheet (insert-rule box-style 0))
         (ps:chain style-element sheet (insert-rule highlighted-style 1)))
       (:catch (error)))))

  (defun hint-determine-position (rect)
    "Determines the position of a hint according to the element"
    (ps:create :top  (+ (ps:@ window page-y-offset) (ps:@ rect top))
               :left (+ (ps:@ window page-x-offset) (- (ps:@ rect left) 20))))

  (defun hint-create-element (element hint)
    "Creates a DOM element to be used as a hint"
    (ps:let* ((rect (ps:chain element (get-bounding-client-rect)))
              (position (hint-determine-position rect))
              (element (ps:chain document (create-element "span"))))
      (setf (ps:@ element class-name) "next-hint")
      (setf (ps:@ element style position) "absolute")
      (setf (ps:@ element style left) (+ (ps:@ position left) "px"))
      (setf (ps:@ element style top) (+ (ps:@ position top) "px"))
      (setf (ps:@ element id) (+ "next-hint-" hint))
      (setf (ps:@ element text-content) hint)
      element))

  (defun hint-add (element hint)
    "Adds a hint on a single element. Additionally sets a unique
identifier for every hinted element."
    (ps:chain element (set-attribute "next-identifier" hint))
    (ps:let ((hint-element (hint-create-element element hint)))
      (ps:chain document body (append-child hint-element))))

  (defun element-drawable-p (element)
    (if (or (ps:chain element offset-width)
            (ps:chain element offset-height)
            (ps:chain element (get-client-rects) length))
        t nil))

  (defun element-in-view-port-p (element)
    (ps:let* ((rect (ps:chain element (get-bounding-client-rect))))
      (if (and (>= (ps:chain rect top) 0)
               (>= (ps:chain rect left) 0)
               (<= (ps:chain rect right) (ps:chain window inner-width))
               (<= (ps:chain rect bottom) (ps:chain window inner-height)))
          t nil)))

  (defun object-create (element hint)
    (cond ((equal "A" (ps:@ element tag-name))
           (ps:create "type" "link" "hint" hint "href" (ps:@ element href) "body" (ps:@ element |innerHTML|)))
          ((equal "BUTTON" (ps:@ element tag-name))
           (ps:create "type" "button" "hint" hint "identifier" hint "body" (ps:@ element |innerHTML|)))
          ((equal "INPUT" (ps:@ element tag-name))
           (ps:create "type" "input" "hint" hint "identifier" hint))
          ((equal "TEXTAREA" (ps:@ element tag-name))
           (ps:create "type" "textarea" "hint" hint "identifier" hint))))

  (defun hints-add (elements)
    "Adds hints on elements"
    (ps:let* ((elements-length (length elements))
              (hints (hints-generate elements-length)))
      (ps:chain |json|
                (stringify
                 (loop for i from 0 to (- elements-length 1)
                       when (and (element-drawable-p (elt elements i))
                                 (element-in-view-port-p (elt elements i)))
                       do (hint-add (elt elements i) (elt hints i))
                       when (or (and (element-drawable-p (elt elements i))
                                     (ps:lisp annotate-full-document))
                                (and (element-drawable-p (elt elements i))
                                     (element-in-view-port-p (elt elements i))))
                       collect (object-create (elt elements i) (elt hints i)))))))

  (defun hints-determine-chars-length (length)
    "Finds out how many chars long the hints must be"
    (floor (+ 1 (/ (log length) (log 26)))))

  (defun hints-generate (length)
    "Generates hints that will appear on the elements"
    (strings-generate length (hints-determine-chars-length length)))

  (defun strings-generate (length chars-length)
    "Generates strings of specified length"
    (ps:let ((minimum (1+ (ps:chain -math (pow 26 (- chars-length 1))))))
      (loop for i from minimum to (+ minimum length)
            collect (string-generate i))))

  (defun string-generate (n)
    "Generates a string from a number"
    (if (>= n 0)
        (+ (string-generate (floor (- (/ n 26) 1)))
           (code-char (+ 65
                         (rem n 26)))) ""))

  (add-stylesheet)
  (hints-add (qsa document (list "a" "button" "input" "textarea"))))

(define-parenscript remove-element-hints ()
  (defun hints-remove-all ()
    "Removes all the elements"
    (ps:dolist (element (qsa document ".next-hint"))
      (ps:chain element (remove))))
  (hints-remove-all))

(define-parenscript click-button (&key next-identifier)
  (defun qs (context selector)
    "Alias of document.querySelector"
    (ps:chain context (query-selector selector)))
  (ps:chain (qs document (ps:lisp (format nil "[next-identifier=\"~a\"]" next-identifier))) (click)))

(define-parenscript focus-element (&key next-identifier)
  (defun qs (context selector)
    "Alias of document.querySelector"
    (ps:chain context (query-selector selector)))
  (ps:chain (qs document (ps:lisp (format nil "[next-identifier=\"~a\"]" next-identifier))) (focus))
  (ps:chain (qs document (ps:lisp (format nil "[next-identifier=\"~a\"]" next-identifier))) (select)))

(define-parenscript highlight-selected-hint (&key link-hint scroll)
  (defun qs (context selector)
    "Alias of document.querySelector"
    (ps:chain context (query-selector selector)))

  (defun update-hints ()
    (ps:let* ((new-element (qs document (ps:lisp (format nil "#next-hint-~a" (identifier link-hint))))))
      (when new-element
        (unless ((ps:@ new-element class-list contains) "next-highlight-hint")
          (ps:let ((old-elements (qsa document ".next-highlight-hint")))
            (ps:dolist (e old-elements)
              (setf (ps:@ e class-name) "next-hint"))))
        (setf (ps:@ new-element class-name) "next-hint next-highlight-hint")
        (if (ps:lisp scroll)
            (ps:chain new-element (scroll-into-view
                                   (ps:create block "nearest")))))))

  (update-hints))

(define-parenscript remove-focus ()
  (ps:let ((old-elements (qsa document ".next-highlight-hint")))
    (ps:dolist (e old-elements)
      (setf (ps:@ e class-name) "next-hint"))))

(defun query-hints (prompt function &key multi-selection-p annotate-full-document)
  (let* ((buffer (current-buffer))
         minibuffer)
    (with-result (elements-json (add-element-hints :annotate-full-document annotate-full-document))
      (setf minibuffer (make-minibuffer
                        :input-prompt prompt
                        :history nil
                        :multi-selection-p multi-selection-p
                        :completion-function
                        (hint-completion-filter (elements-from-json elements-json))
                        :changed-callback
                        (let ((subsequent-call nil))
                          (lambda ()
                            ;; when the minibuffer initially appears, we don't
                            ;; want update-selection-highlight-hint to scroll
                            ;; but on subsequent calls, it should scroll
                            (update-selection-highlight-hint
                             :scroll subsequent-call
                             :buffer buffer
                             :minibuffer minibuffer)
                            (setf subsequent-call t)))
                        :cleanup-function
                        (lambda ()
                          (with-current-buffer buffer
                            (remove-element-hints)))))
      ;; TODO: ADD offscreen hints in background from full document annotation
      (with-result (result (read-from-minibuffer minibuffer))
        (funcall-safely function result)))))

(defun hint-completion-filter (hints)
  (lambda (minibuffer)
    (with-slots (input-buffer) minibuffer
      (let* ((matched-hints (remove-if-not (lambda (x) (str:starts-with-p input-buffer (hint x) :ignore-case t)) hints))
             (fuzzy-matched-hints (fuzzy-match input-buffer (set-difference hints matched-hints))))
        (append matched-hints fuzzy-matched-hints)))))

(defun elements-from-json (elements-json)
  (loop for element in (cl-json:decode-json-from-string elements-json)
        collect (let ((object-type (cdr (assoc :type element))))
                  (cond ((equal "link" object-type)
                         (make-instance 'link-hint
                                        :hint (cdr (assoc :hint element))
                                        :identifier (cdr (assoc :hint element))
                                        :url (cdr (assoc :href element))
                                        :body (plump:text (plump:parse (cdr (assoc :body element))))))
                        ((equal "button" object-type)
                         (make-instance 'button-hint
                                        :identifier (cdr (assoc :identifier element))
                                        :hint (cdr (assoc :hint element))
                                        :body (plump:text (plump:parse (cdr (assoc :body element))))))
                        ((equal "input" object-type)
                         (make-instance 'input-hint
                                        :identifier (cdr (assoc :identifier element))
                                        :hint (cdr (assoc :hint element))))
                        ((equal "textarea" object-type)
                         (make-instance 'textarea-hint
                                        :identifier (cdr (assoc :identifier element))
                                        :hint (cdr (assoc :hint element))))))))

(defclass hint ()
  ((hint :accessor hint :initarg :hint)
   (identifier :accessor identifier :initarg :identifier)
   (body :accessor body :initarg :body
         :documentation "The body of the anchor tag.")))

(defclass button-hint (hint) ())

(defclass link-hint (hint)
  ((url :accessor url :initarg :url)))

(defclass input-hint (hint) ())

(defclass textarea-hint (hint) ())

(defmethod object-string ((link-hint link-hint))
  (url link-hint))

(defmethod object-display ((link-hint link-hint))
  (format nil "~a  ~a  ~a" (hint link-hint) (body link-hint) (url link-hint)))

(defmethod object-string ((button-hint button-hint))
  (body button-hint))

(defmethod object-display ((button-hint button-hint))
  (format nil "~a  ~a  Button" (hint button-hint) (body button-hint)))

(defmethod object-string ((input-hint input-hint))
  (hint input-hint))

(defmethod object-display ((input-hint input-hint))
  (format nil "~a  Input" (hint input-hint)))

(defmethod object-string ((textarea-hint textarea-hint))
  (hint textarea-hint))

(defmethod object-display ((textarea-hint textarea-hint))
  (format nil "~a  Textarea" (hint textarea-hint)))

(defmethod %follow-hint ((link-hint link-hint))
  (set-url* (url link-hint) :buffer (current-buffer) :raw-url-p t))

(defmethod %follow-hint ((button-hint button-hint))
  (click-button :next-identifier (identifier button-hint)))

(defmethod %follow-hint ((input-hint input-hint))
  (focus-element :next-identifier (identifier input-hint)))

(defmethod %follow-hint ((textarea-hint textarea-hint))
  (focus-element :next-identifier (identifier textarea-hint)))

(defmethod %follow-hint-new-buffer-focus ((link-hint link-hint))
  (let ((new-buffer (make-buffer)))
    (set-url* (url link-hint) :buffer new-buffer :raw-url-p t)
    (set-current-buffer new-buffer)))

(defmethod %follow-hint-new-buffer-focus ((hint hint))
  (echo "Unsupported operation for hint: can't open in new buffer."))

(defmethod %follow-hint-new-buffer ((link-hint link-hint))
  (let ((new-buffer (make-buffer)))
    (set-url* (url link-hint) :buffer new-buffer :raw-url-p t)))

(defmethod %follow-hint-new-buffer ((hint hint))
  (echo "Unsupported operation for hint: can't open in new buffer."))

(defmethod %copy-hint-url ((link-hint link-hint))
  (trivial-clipboard:text (url link-hint)))

(defmethod %copy-hint-url ((hint hint))
  (echo "Unsupported operation for hint: can't copy URL."))

(defun update-selection-highlight-hint (&key completions scroll follow
                                          (minibuffer (current-minibuffer))
                                          (buffer (current-buffer)))
  (let ((hint (flet ((hintp (hint-candidate)
                       (if (typep hint-candidate '(or link-hint button-hint match))
                           hint-candidate
                           nil)))
                (if completions
                    (hintp (first completions))
                    (when minibuffer
                      (let ((hint-candidate (nth (next::completion-cursor minibuffer)
                                                 (next::completions minibuffer))))
                        (hintp hint-candidate)))))))
    (when hint
      (when (and follow
                 (slot-exists-p hint 'buffer)
                 (not (equal (buffer hint) buffer)))
        (set-current-buffer (buffer hint))
        (setf buffer (buffer hint)))
      (if (or
           (not (slot-exists-p hint 'buffer))
           (and (slot-exists-p hint 'buffer)
                (equal (buffer hint) buffer)))
          (with-current-buffer buffer
            (highlight-selected-hint :link-hint hint
                                     :scroll scroll))
          (remove-focus)))))

(define-command follow-hint (&key annotate-full-document)
  "Show a set of element hints, and go to the user inputted one in the
currently active buffer."
  (query-hints "Go to element:" '%follow-hint
               :annotate-full-document annotate-full-document))

(define-command follow-hint-new-buffer (&key annotate-full-document)
  "Show a set of element hints, and open the user inputted one in a new
buffer (not set to visible active buffer)."
  (query-hints "Open element in new buffer:"
               (lambda (result) (mapcar #'%follow-hint-new-buffer result))
               :multi-selection-p t
               :annotate-full-document annotate-full-document))

(define-command follow-hint-new-buffer-focus (&key annotate-full-document)
  "Show a set of element hints, and open the user inputted one in a new
visible active buffer."
  (query-hints "Go to element in new buffer:"
               (lambda (result)
                 (%follow-hint-new-buffer-focus (first result))
                 (mapcar #'%follow-hint-new-buffer (rest result)))
               :multi-selection-p t
               :annotate-full-document annotate-full-document))

(define-command copy-hint-url (&key annotate-full-document)
  "Show a set of element hints, and copy the URL of the user inputted one."
  (query-hints "Copy element URL:" '%copy-hint-url
               :annotate-full-document annotate-full-document))

(define-command bookmark-hint ()
  "Show link hints on screen, and allow the user to bookmark one"
  (with-result* ((elements-json (add-element-hints))
                 (result (read-from-minibuffer
                          (make-minibuffer
                           :input-prompt "Bookmark hint"
                           :history nil
                           :completion-function
                           (hint-completion-filter (elements-from-json elements-json))
                           :cleanup-function
                           (lambda ()
                             (remove-element-hints)))))
                 (tags (read-from-minibuffer
                        (make-minibuffer
                         :input-prompt "Space-separated tag(s)"
                         :default-modes '(set-tag-mode minibuffer-mode)
                         :input-buffer (url-bookmark-tags (url result))
                         :completion-function (tag-completion-filter)))))
    (when result
      (bookmark-add (url result) :tags tags))))

(define-command download-hint-url ()
  "Download the file under the URL hinted by the user."
  (query-hints "Download link URL:" (lambda (selected-link)
                                      (download selected-link)
                                      (unless (find-buffer 'download-mode)
                                        (download-list)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package :next/minibuffer-mode)
(define-command select-next-follow (&optional (minibuffer (current-minibuffer)))
  "Select next entry in minibuffer and focus the referencing hint/match
if there is one such."
  (select-next minibuffer)
  (next/web-mode::update-selection-highlight-hint :follow t :scroll t))

(define-command select-previous-follow (&optional (minibuffer (current-minibuffer)))
  "Select previous entry in minibuffer and focus the referencing hint/match
if there is one such."
  (select-previous minibuffer)
  (next/web-mode::update-selection-highlight-hint :follow t :scroll t))
