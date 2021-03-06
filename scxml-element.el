;;; scxml-element --- scxml element level functions -*- lexical-binding: t -*-

;;; COMMENTARY:
;; The scxml-element is used as the base class for any <element
;; with="attributes">or child</element> in a valid <scxml> document.

;;; Code:
(require 'eieio)
(require 'seq)
(require 'cl-macs)
(require 'scxml-element-core)

(defclass scxml-element (scxml--core)
  ((_attributes :initarg :attributes
                ;; TODO - remove the initarg for this?
                ;; :accessor scxml-element-attributes
                :initform nil
                :type (or hash-table null))
   (_children :initform nil
              :type (or list null))
   (_parent :initform nil
            :type (or null scxml-element)))
  :abstract 't)
(cl-defgeneric scxml-print ((element scxml-element))
  "Return a string representing ELEMENT for human eyes"
  (with-slots (_attributes _parent) element
    (format "parent:%s children:%s attributes:[%s]"
            (and _parent (scxml-xml-element-name _parent))
            (scxml-num-children element)
            (let ((parts))
              (scxml-map-attrib element (lambda (k v)
                                          (push (format "%s=%.10s" k v) parts)))
              (mapconcat 'identity parts ", ")))))
(cl-defmethod cl-print-object ((object scxml-element) stream)
  "Pretty print the OBJECT to STREAM."
  (princ (scxml-print object) stream))
(cl-defgeneric scxml-xml-attributes ((element scxml-element))
  "Return an alist of ELEMENT's attributes for XML rendering.

Note: at present it is not supported to have an attribute exist but have no =\"\" after it.  So this is possible: <thing attrib=\"\" /> but this in not: <thing attrib />.

This function should never return any attribute with a nil value.")
(cl-defmethod scxml-xml-attributes ((element scxml-element))
  "Return an alist of ELEMENT's attributes for XML rendering."
  (let ((attribs nil))
    (scxml-map-attrib element
                      (lambda (key val)
                        (push (cons key val) attribs)))
    attribs))
(cl-defgeneric scxml-children ((element scxml-element))
  "Return the children of ELEMENT.")
(cl-defmethod scxml-children ((element scxml-element))
  ;; TODO - this can just be a reader??
  "Return the children of ELEMENT."
  (oref element _children))
(cl-defmethod scxml-num-children ((element scxml-element))
  "Return the number of child elements for ELEMENT."
  (length (oref element _children)))
(cl-defmethod scxml-parent ((element scxml-element))
  ;; TODO - this can just be a reader????
  "Return the parent of ELEMENT."
  (oref element _parent))
(cl-defgeneric scxml-siblings ((element scxml-element))
  "Return the siblings of ELEMENT")
(cl-defmethod scxml-siblings ((element scxml-element))
  "Return the siblings of ELEMENT"
  (let ((parent (scxml-parent element)))
    (if parent
        (seq-filter (lambda (parents-child)
                      (not (eq parents-child element)))
                    (scxml-children parent))
      nil)))
(cl-defgeneric scxml-make-orphan ((element scxml-element))
  "Break ELEMENT away from any parent elements.")
(cl-defmethod scxml-make-orphan ((element scxml-element))
  "Break ELEMENT away from any parent elements."
  (with-slots (_parent) element
    ;; element has a parent, break the link from parent->child
    (when _parent
      (oset _parent _children
            (cl-remove-if (lambda (child) (eq child element))
                          (scxml-children _parent)
                          :count 1)))
    (setf _parent 'nil)))
(cl-defgeneric scxml-add-child ((parent scxml-element) (new-child scxml-element) &optional append)
  "Make NEW-CHILD a child element of PARENT, returning PARENT.

When APPEND is non-nil NEW-CHILD will become the last child.  When APPEND is nil NEW-CHILD will become the first child.")
(cl-defmethod scxml-add-child ((parent scxml-element) (new-child scxml-element) &optional append)
  "Modify PARENT adding NEW-CHILD as a child returning PARENT.

When APPEND is non-nil NEW-CHILD will become the last child.  When APPEND is nil NEW-CHILD will become the first child."
  (scxml-make-orphan new-child)   ;; make sure new-child isn't connected someplace else.
  (oset new-child _parent parent)
  (if append
      (oset parent _children (nconc (oref parent _children) (list new-child)))
    (push new-child (oref parent _children)))
  parent)
(cl-defmethod scxml-add-children ((parent scxml-element) &rest new-children)
  "Make NEW-CHILDREN into child elements of PARENT, returning PARENT."
  (mapc (lambda (child) (scxml-add-child parent child))
        (reverse new-children))
  parent)
(defun scxml---ensure-attributes (element)
  "If ELEMENT doesn't have an attribute hash table, put on there."
  (when (null (oref element _attributes))
    (oset element _attributes
          (make-hash-table :size 10 :test 'equal))))
(cl-defgeneric scxml-map-attrib ((element scxml-element) function)
  "Map over attributes in ELEMENT calling ('FUNCTION key value).

Return is unspecified.")
(cl-defmethod scxml-map-attrib ((element scxml-element) function)
  "Map over attributes in ELEMENT calling ('FUNCTION key value).

Return is unspecified."
  (with-slots (_attributes) element
    (when _attributes
      (maphash function _attributes))))
(cl-defmethod scxml-num-attrib ((element scxml-element))
  "Return the number of attributes in ELEMENT's hashtable."
  (with-slots (_attributes) element
    (if _attributes
        (hash-table-count _attributes)
      0)))
(cl-defgeneric scxml-put-attrib ((element scxml-element) key value)
  "Put VALUE into ELEMENT's attributes with a name of KEY.

Return is unspecified.")
(cl-defmethod scxml-put-attrib ((element scxml-element) key value)
  "Put VALUE into ELEMENT's attributes with a name of KEY.

Return is unspecified."
  (scxml---ensure-attributes element)
  (puthash key value (oref element _attributes)))
(cl-defgeneric scxml-delete-attrib ((element scxml-element) key)
  "Delete the attribute with name of KEY if exists.

Return is unspecified.")
(cl-defmethod scxml-delete-attrib ((element scxml-element) key)
  "Delete the attribute with name of KEY if exists.

Return is unspecified."
  (with-slots (_attributes) element
    (remhash key _attributes)))
(cl-defgeneric scxml-get-attrib ((element scxml-element) key &optional default)
  "Return ELEMENT's attribute value for KEY, defaulting to DEFAULT")
(cl-defmethod scxml-get-attrib ((element scxml-element) key &optional default)
  "Return ELEMENT's attribute value for KEY, defaulting to DEFAULT"
  (with-slots (_attributes) element
    (if _attributes
        (gethash key _attributes default)
      default)))
(cl-defgeneric scxml-root-element ((element scxml-element))
  "Given any ELEMENT in an scxml-element tree, find the root of the tree.")
(cl-defmethod scxml-root-element ((element scxml-element))
  "Given any ELEMENT in an scxml-element tree, find the root of the tree."
  (let ((last element)
        (parent (scxml-parent element)))
    (while parent
      (setq last parent)
      (setq parent (scxml-parent last)))
    last))
(cl-defgeneric scxml-visit ((element scxml-element) visitor &optional filter child-fn)
  "Visit all children of ELEMENT with VISITOR and optionally FILTER first.

Visitation starts at ELEMENT and descends per child.  Other than
visiting ELEMENT first the order of visitation is undefined.

VISITOR must be of form (lambda (element) ...)
FILTER must be of form (lambda (element) ...)

When CHILD-FN is specified it will be called to produce the child
elements of any given element as (funcall child-fn element).
When CHILD-FN is not specified `scxml-children' will be used.

Return value is undefined.")
(cl-defmethod scxml-visit ((element scxml-element) visitor &optional filter child-fn)
  "Visit all children of ELEMENT with VISITOR and optionally FILTER first.

Visitation starts at ELEMENT and descends per child.  Other than
visiting ELEMENT first the order of visitation is undefined.

VISITOR must be of form (lambda (element) ...)
FILTER must be of form (lambda (element) ...)

Return value is undefined."
  ;; TODO - seems like this could be easily optimized though I'm not
  ;; sure what the gain would be, probably small.  It could fork off
  ;; to 4 function: visit, visit-with-filter, visit-with-child-fn,
  ;; visit-with-child-fn-and-filter.
  (unless child-fn
    (setq child-fn #'scxml-children))
  (if (or (not filter)
          (funcall filter element))
      (funcall visitor element))
  (mapc (lambda (child)
          (scxml-visit child visitor filter))
        (funcall child-fn element)))

(cl-defgeneric scxml-visit-all ((element scxml-element) visitor &optional filter child-fn)
  "Visit all elements (parent or child, recursively) starting at the root element.")
(cl-defmethod scxml-visit-all ((element scxml-element) visitor &optional filter child-fn)
  "Visit all elements (parent or child, recursively) starting at the root element"
  (scxml-visit (scxml-root-element element) visitor filter child-fn))
(cl-defgeneric scxml-collect ((element scxml-element) filter)
    "Return a list of ELEMENT and ELEMENT's children filtered by FILTER.

May include ELEMENT or children at any depth if they satisfy
FILTER.")
(cl-defmethod scxml-collect ((element scxml-element) filter)
  "Return a list of ELEMENT and ELEMENT's children filtered by FILTER.

May include ELEMENT or children at any depth if they satisfy
FILTER."
  (let ((matches nil))
    (scxml-visit element
                 (lambda (x) (push x matches))
                 filter)
    matches))
(cl-defgeneric scxml-collect-all ((element scxml-element) filter)
  "Return a list of all elements passing FILTER which are parent, child or siblings of ELEMENT.")
(cl-defmethod scxml-collect-all ((element scxml-element) filter)
  "Return a list of all elements passing FILTER which are parent, child or siblings of ELEMENT."
  (scxml-collect (scxml-root-element element) filter))
(defalias 'scxml-lcca 'scxml-find-nearest-mutual-parent
  "Return the scxml's LCCA (Least Common Compound Ancestor) of all elements.

Aliased to mesh up with the scxml example algorithm.")
(cl-defmethod scxml-find-nearest-mutual-parent (&rest elements)
  "Given a series of elements return their closest mutual ancestor.

Currently does not validate that elements are actually
scxml-elements.  Possibly it should do that?"
  (cl-flet ((build-parent-list
             (element)
             (let ((parents)
                   (parent (scxml-parent element)))
               (while parent
                 (push parent parents)
                 (setq parent (scxml-parent parent)))
               (nreverse parents))))
    (let* ((parent-lists (mapcar #'build-parent-list elements))
           (first-parent-list (first parent-lists))
           (rest-parent-lists (rest parent-lists)))
      (cl-block find-parent
        (cl-loop for first-list-element in first-parent-list
                 when (cl-every (lambda (other-ancestry)
                                  (cl-find-if (lambda (entry)
                                                (eq entry first-list-element))
                                              other-ancestry))
                                rest-parent-lists)
                 do (cl-return-from find-parent first-list-element))
        ))))
(cl-defgeneric scxml-visit-parents ((element scxml-element) visitor)
  "Visit all the parents of ELEMENT with VISITOR in increasing parent order.")
(cl-defmethod scxml-visit-parents ((element scxml-element) visitor)
  "Visit all the parents of ELEMENT with VISITOR in increasing parent order.

ELEMENT is not visited.  Visitor should be of the
form (lambda (parent-element) ...)."
  (let ((parent (scxml-parent element)))
    (while parent
      (funcall visitor parent)
      (setq parent (scxml-parent parent)))))
(cl-defgeneric scxml-find-ancestor-if ((element scxml-element) predicate)
  "Return ELEMENT's first ancestor satisfying PREDICATE.")
(cl-defmethod scxml-find-ancestor-if ((element scxml-element) predicate)
  "Return ELEMENT's first ancestor satisfying PREDICATE."
  (cl-block find-parent-if
    (scxml-visit-parents element
                         (lambda (ancestor)
                           (when (funcall predicate ancestor)
                             (cl-return-from find-parent-if ancestor))))
    nil))
(cl-defgeneric scxml-is-descendant ((element scxml-element) (possible-descendant scxml-element))
  "Return non-nil if POSSIBLE-DESCENDANT is a descendant of ELEMENT.

Note: argument order is flipped between this function and the
scxml reference algorithm.  When the arguments are equal the
return value is nil.")
(cl-defmethod scxml-is-descendant ((element scxml-element) (possible-descendant scxml-element))
  "Return non-nil if POSSIBLE-DESCENDANT is a descendant of ELEMENT.

Note: argument order is flipped between this function and the
scxml reference algorithm.  When the arguments are equal the
return value is nil.

TODO: it seems like it might be a lot more efficient to use
scxml-is-ancestor with the argument order flipped for this."
  (cl-block find-upward
    (scxml-visit-parents possible-descendant
                         (lambda (looking-upward)
                           (when (eq looking-upward element)
                             (cl-return-from find-upward t))))
    nil))
(cl-defgeneric scxml-is-ancestor ((element scxml-element) (possible-ancestor scxml-element))
  "Return non-nil if POSSIBLE-ANCESTOR is an ancestor of ELEMENT.

When the arguments are equal the return value is nil.")
(cl-defgeneric scxml-is-ancestor ((element scxml-element) (possible-ancestor scxml-element))
  "Return non-nil if POSSIBLE-ANCESTOR is an ancestor of ELEMENT.

When the arguments are equal the return value is nil."
  (let ((parent (scxml-parent element))
        (is-ancestor))
    (while (and parent (not is-ancestor))
      (if (eq parent possible-ancestor)
          (setq is-ancestor t)
        (setq parent (scxml-parent parent))))
    is-ancestor))
(cl-defgeneric scxml-xml-document-coordinate ((element scxml-element) &optional (relative-to scxml-element))
  "Return the xml document coordinate of ELEMENT.

Xml Document Coordinate is defined as a list of Xml Document
Ordinates in descending order (from document root to ELEMENT).

Xml Document Ordinate is defined is the index of a child element
within it's parent.  e.g. <parent><a /><b /></parent> would have
element <a /> at the 0-th index and <b /> as the 1st index.

Given:
 <grandparent>
  <parent-a />
  <parent-b>
   <child-a />
   <child-b />
  </parent-b>
 </grandparent>

the coordinate of element <child-a> would be '(1 0).

When RELATIVE-TO is set the coordinate returned will be the
coordinate of ELEMENT relative to RELATIVE-TO as opposed to the
root of the scxml document.

Note: a root element would have a coordinate of nil."
  (if (eq element relative-to)
      ;; short-circut: coordinate relative to yourself is nil
      nil
    (let ((ordinates)
          (current-element element)
          (current-parent (scxml-parent element)))
      (while current-parent
        (let* ((siblings (scxml-children current-parent))
               (ordinate (position current-element siblings)))
          (unless ordinate
            (error "Invalid element tree"))
          (push ordinate ordinates)
          (if (and relative-to (eq relative-to current-parent))
              (setq current-parent nil)
            (setq current-element current-parent)
            (setq current-parent (scxml-parent current-element)))))
      ordinates)))
(defun scxml-xml-document-order-predicate (a b)
  "Return non-nil if A comes before B in document order."
  (let ((a-coordinates (scxml-xml-document-coordinate a))
        (b-coordinates (scxml-xml-document-coordinate b)))
    ;; Note - if one of these is the root element you could still technically sort it.
    (unless (and a-coordinates b-coordinates)
      (error "Either trying to sort the root element or invalid elements"))
    (cl-loop for a-ordinate in a-coordinates
             for b-ordinate in b-coordinates
             unless (eq a-ordinate b-ordinate)
             do (cl-return (< a-ordinate b-ordinate))
             finally return nil)))

(defclass scxml-element-with-id ()
  ((id :initarg :id
       :reader scxml-get-id
       :writer scxml-set-id
       :initform nil
       :type (or string null)
       ;; TODO - documentation doesn't work here?  If you run help on
       ;; this function you'll get that the generic version of the
       ;; function is not documented.  Am I just using the wrong
       ;; keyword symbol?
       :documentation "Return the elements 'id' attribute value if it exists."))
  :abstract t
  :documentation "Apply to an scxml element if it has an 'id'
  attribute that's significant.")
(defun scxml-element-with-id-class-p (any-object)
  "Equivalent of (object-of-class-p ANY-OBJECT 'scxml-element-with-id)"
  (object-of-class-p any-object 'scxml-element-with-id))
(cl-defmethod scxml-set-id :before (id (element scxml-element-with-id))
  "Validate the id before setting.

This should function with the :writer slot option for defclass
but that does not appear to be working?"
  (when id
    ;; must validate
    (when (scxml-element-find-by-id (scxml-root-element element) id)
      (error "An element with id of %s already exists" id)))
  (oset element id id))
(cl-defmethod scxml-print ((idable-element scxml-element-with-id))
  (format "id:%s, %s"
          (scxml-get-id idable-element)
          (cl-call-next-method)))
;; TODO- rename this to just be 'scxml-find-by-id'
(cl-defgeneric scxml-element-find-by-id ((search-root scxml-element) (id-to-find string))
  "Find element with ID-TO-FIND starting at SEARCH-ROOT and going down.

Function will not traverse the whole tree, only the portion at or
below SEARCH-ROOT")
(cl-defmethod scxml-element-find-by-id ((search-root scxml-element) (id-to-find string))
  "Find element with ID-TO-FIND at or below SEARCH-ROOT."
  (cl-block scxml-element-find-by-id-block
    (scxml-visit search-root
                 (lambda (element)
                   (when (string-equal (scxml-get-id element) id-to-find)
                     (cl-return-from scxml-element-find-by-id-block element)))
                 (lambda (element)
                   (object-of-class-p element 'scxml-element-with-id)))
    nil))

(defclass scxml-element-with-initial ()
  ((initial :initarg :initial
            :reader scxml-get-initial
            ;;writer scxml-set-initial  ; handled below.
            :initform nil
            :type (or string null)))
  :abstract t
  :documentation "Apply to an scxml element if it has an
  'initial' attribute that is significant.")
(defun scxml-element-with-initial-class-p (any-object)
  "Equivalent of (object-of-class-p ANY-OBJECT 'scxml-element-with-initial)"
  (object-of-class-p any-object 'scxml-element-with-initial))
(cl-defmethod scxml-print ((initialable-element scxml-element-with-initial))
  (format "initial:%s, %s"
          (scxml-get-initial initialable-element)
          (cl-call-next-method)))
(cl-defgeneric scxml-set-initial ((element scxml-element-with-initial) value &optional do-not-validate)
  "Set INITIAL's initial to be VALUE.

When DO-NOT-VALIDATE is non-nil no validation will be done."
  ;; initial must reference a valid child and none of the
  ;; existing children can be <initial> elements.
  (when (and value (not do-not-validate))
    ;; must validate
    (let ((found))
      (mapc (lambda (child)
              (when (object-of-class-p child 'scxml-initial)
                (error "Unable to set initial attribute when a child <initial> element exists"))
              (when (and (not found)
                         (object-of-class-p child 'scxml-element-with-id)
                         (equal (scxml-get-id child) value))
                (setq found t)))
            (scxml-children element))
      (when (not found)
        (error "Unable to find valid child element with id: %s" value))))
  (oset element initial value))

(provide 'scxml-element)
;;; scxml-element.el ends here
