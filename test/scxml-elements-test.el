(require 'ert)

(require 'scxml-elements)

(ert-deftest scxml--element-factory-test-scxml ()
  (let* ((attribs '((initial . "test-initial")
                    (test-property . "anything")))
         (element (scxml--element-factory 'scxml attribs)))
    (should (equal (scxml-get-name element)
                   nil))
    (should (equal (scxml-get-initial element)
                   "test-initial"))
    (should (equal (scxml-get-attrib element 'test-property)
                   "anything"))
    (should (eq (scxml-num-attrib element)
                1))))
(ert-deftest scxml--element-factory-test-state ()
  (let* ((attribs '((id . "test-id")
                    (anything . "else")))
         (element (scxml--element-factory 'state attribs)))
    (should (equal (scxml-get-id element)
                   "test-id"))
    (should (equal (scxml-get-initial element)
                   nil))
    (should (equal (scxml-get-attrib element 'anything)
                   "else"))
    (should (eq (scxml-num-attrib element)
                1))))
(ert-deftest scxml--element-factory-test-final ()
  )
(ert-deftest scxml--element-factory-test-initial ()
  )
(ert-deftest scxml--element-factory-test-parallel ()
  )
(ert-deftest scxml--element-factory-test-transition ()
  )

(ert-deftest scxml--element-validate-add-child-initial-test ()
  (let ((my-parent (scxml-state :id "parent")))
    ;; Empty <initial> elements are never valid to add.
    (should-error
     (scxml-validate-add-child my-parent (scxml-initial)))
    (let ((my-child (scxml-state :id "child"))
          (another-child (scxml-state :id "another-child")))
      (scxml-add-child my-parent my-child)
      (scxml-add-child my-parent another-child)

      ;; should not be able to add an empty <initial>
      (should-error
       (scxml-validate-add-child my-parent (scxml-initial)))

      ;; should not be able to add an initial with a an invalid transition.
      (should-error
       (scxml-validate-add-child my-parent
                                  (scxml-add-child (scxml-initial)
                                                   (scxml-transition :target "invalid"))))
      ;; parent is not valid either.
      (should-error
       (scxml-validate-add-child my-parent
                                  (scxml-add-child (scxml-initial)
                                                   (scxml-transition :target "parent"))))

      ;; Only possible valid <initial>
      (scxml-validate-add-child my-parent
                                 (scxml-add-child (scxml-initial)
                                                  (scxml-transition :target "child")))
      ;; actually add it.
      (scxml-add-child my-parent
                       (scxml-add-child (scxml-initial)
                                        (scxml-transition :target "child")))

      ;; should not allow a second initial, even if it is valid as a first <initial>
      (should-error
       (scxml-validate-add-child my-parent
                                  (scxml-add-child (scxml-initial)
                                                   (scxml-transition :target "another-child")))))))

(ert-deftest scmxl--transition-creation-tests ()
  "When creating a transition, the event attribute may be specified in a number of ways"

  (let ((transition (scxml-transition :target "X" :events "A")))
    (should (equal "X" (scxml-get-target-id transition)))
    (should (eq 1 (length (scxml-get-events transition))))
    (should (equal "A" (first (scxml-get-events transition)))))

  (let ((transition (scxml-transition :target "X" :events (list "A" "B"))))
    (should (equal "X" (scxml-get-target-id transition)))
    (should (eq 2 (length (scxml-get-events transition))))
    (should (equal "A" (first (scxml-get-events transition))))
    (should (equal "B" (second (scxml-get-events transition)))))

  (let ((transition (scxml-transition :target "X" :events "A B C")))
    (should (equal "X" (scxml-get-target-id transition)))
    (should (eq 3 (length (scxml-get-events transition))))
    (should (equal "A" (first (scxml-get-events transition))))
    (should (equal "B" (second (scxml-get-events transition))))
    (should (equal "C" (third (scxml-get-events transition)))))
    )

(provide 'scxml-elements-test)
