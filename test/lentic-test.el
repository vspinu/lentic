(require 'lentic)
(require 'lentic-latex-code)
(require 'lentic-asciidoc)
(require 'lentic-org)
(require 'f)


(defvar lentic-test-dir
  (concat
   (file-name-directory
    (find-lisp-object-file-name 'lentic-init 'defvar))
   "dev-resources/"))

(defun lentic-test-file (filename)
  (let ((file
         (concat lentic-test-dir filename)))
    (when (not (file-exists-p file))
      (error "Test File does not exist: %s" file))
    file))

(defun lentic-test-equal-loudly (a b)
  "Actually, this just tests equality and shouts if not."
  ;; change this to t to disable noisy printout
  (if nil
      (string= a b)
    (if (string= a b)
        t
      (message "Results:\n%s\n:Complete\nShouldbe:\n%s\nComplete:" cloned-results cloned-file)
      (let* ((a-buffer
              (generate-new-buffer "a"))
             (b-buffer
              (generate-new-buffer "b"))
             (a-file
              (make-temp-file
               (buffer-name a-buffer)))
             (b-file
              (make-temp-file
               (buffer-name b-buffer))))
        (with-current-buffer
            a-buffer
          (insert a)
          (write-file a-file))
        (with-current-buffer
            b-buffer
          (insert b)
          (write-file b-file))
        (message "diff:%senddiff:"
                 (with-temp-buffer
                   (call-process
                    "diff"
                    nil
                    (current-buffer)
                    nil
                    "-c"
                    a-file
                    b-file)
                   (buffer-string))))
      nil)))

(defun lentic-test-clone-equal (init file cloned-file)
  (let ((cloned-file
         (f-read
          (lentic-test-file cloned-file)))
        (cloned-results
         (lentic-batch-clone-with-config
          (lentic-test-file file) init)))
    (lentic-test-equal-loudly cloned-file cloned-results)))

(defun lentic-test-clone-equal-generate
  (init file cloned-file)
  "Generates the test file for `lentic-batch-clone-equal'."
  (f-write
   (lentic-batch-clone-with-config
    (lentic-test-file file) init)
   'utf-8
   (concat lentic-test-dir cloned-file))
  ;; return nil, so if we use this in a test by mistake, it will crash out.
  nil)

(defvar conf-default
  (lentic-default-configuration "bob"))

(ert-deftest lentic-conf ()
  (should
   (equal 'normal-mode
          (oref conf-default :linked-mode))))

(ert-deftest lentic-simple ()
  (should
   (equal "simple\n"
          (lentic-batch-clone-with-config
           (lentic-test-file "simple-contents.txt")
           'lentic-default-init))))

(ert-deftest lentic-clojure-latex ()
  (should
   (lentic-test-clone-equal
    'lentic-clojure-latex-init
    "block-comment.clj" "block-comment-out.tex")))


(ert-deftest lentic-asciidoc-clojure ()
  (should
   (lentic-test-clone-equal
    'lentic-asciidoc-clojure-init
    "asciidoc-clj.txt" "asciidoc-clj-out.clj")))

;; org mode start up prints out "OVERVIEW" from the cycle. Can't see any way
;; to stop this
(ert-deftest lentic-org-el ()
  (should
   (lentic-test-clone-equal
    'lentic-org-el-init
    "org-el.org" "org-el.el")))

(ert-deftest lentic-el-org ()
  (should
   (lentic-test-clone-equal
    'lentic-el-org-init
    "el-org.el" "el-org.org")))

(ert-deftest lentic-orgel-org()
  (should
   (lentic-test-clone-equal
    'lentic-orgel-org-init
    "orgel-org.el" "orgel-org.org")))

(ert-deftest lentic-org-orgel()
  (should
   (lentic-test-clone-equal
    'lentic-org-orgel-init
    "org-orgel.org" "org-orgel.el")))


(ert-deftest lentic-org-clojure ()
  (should
   (lentic-test-clone-equal
    'lentic-org-clojure-init
    "org-clojure.org" "org-clojure.clj"
    )))


;; incremental testing
;; these test that buffers which are created and then changed are correct.
;; At the moment, this does not check that the changes are actually
;; incremental, cause that's harder.
(defun lentic-test-clone-and-change-with-config
  (filename init &optional f-this f-that retn-that)
  "Clone file and make changes to check incremental updates.
Using INIT clone FILE, then apply F in the buffer, and return the
results."
  ;; most of this is the same as batch-clone..
  (let ((retn nil)
        (f-this
         (or f-this
             (lambda ())))
        (f-that
         (or f-that
             (lambda ()))))
    (let (this that)
      (unwind-protect
          (with-current-buffer
              (setq this
                    (find-file-noselect filename))
            (setq lentic-init init)
            (progn
              (setq that
                    (lentic-init-create))
              (funcall f-this)
              (with-current-buffer
                  that
                (funcall f-that)
                (unless retn-that
                  (setq retn
                        (buffer-substring-no-properties
                         (point-min)
                         (point-max))))
                (set-buffer-modified-p nil)))
            (when retn-that
              (setq retn
                    (buffer-substring-no-properties
                     (point-min)
                     (point-max))))
            (set-buffer-modified-p nil)
            retn)

        ;; unwind forms
        (when this (kill-buffer this))
        (when that (kill-buffer that))))
    ))

(defun lentic-test-clone-and-change-equal
  (init file cloned-file
        &optional f-this f-that retn-that)
  (let ((cloned-file
         (f-read
          (lentic-test-file cloned-file)))
        (cloned-results
         (lentic-test-clone-and-change-with-config
          (lentic-test-file file) init f-this f-that
          retn-that)))
    (if
        (string= cloned-file cloned-results)
        t
      ;; comment this out if you don't want it.
      (lentic-test-equal-loudly cloned-file cloned-results)
      nil)))

(defun lentic-test-clone-and-change-equal-generate
  (init file cloned-file f)
  "Generates the test file for `lentic-test-clone-and-change-with-config'."
  (f-write
   (lentic-test-clone-and-change-with-config
    (lentic-test-file file) init
    f)
   'utf-8
   (concat lentic-test-dir  cloned-file))
  ;; return nil, so that if we use this in a test by mistake, it returns
  ;; false, so there is a good chance it will fail the test.
  nil)

(defvar lentic-test-last-transform "")

(defadvice lentic-insertion-string-transform
  (before store-transform
         (string)
         activate)
  (setq lentic-test-last-transform string))

(ert-deftest lentic-simple-with-change ()
  "Test simple-contents with a change, mostly to check my test machinary."
  (should
   (and
    (equal "simple\nnot simple"
           (lentic-test-clone-and-change-with-config
            (lentic-test-file "simple-contents.txt")
            'lentic-default-init
            (lambda ()
              (goto-char (point-max))
              (insert "not simple"))))
    (equal lentic-test-last-transform "not simple"))))

(ert-deftest lentic-simple-with-change-file()
  "Test simple-contents with a change and compare to file.
This mostly checks my test machinary."
  (should
   (and
    (lentic-test-clone-and-change-equal
     'lentic-default-init
     "simple-contents.txt" "simple-contents-chg.txt"
     (lambda ()
       (goto-char (point-max))
       (insert "simple")))
    (equal lentic-test-last-transform "simple"))))

(ert-deftest lentic-clojure-latex-incremental ()
  (should
   (and
    (lentic-test-clone-and-change-equal
     'lentic-clojure-latex-init
     "block-comment.clj" "block-comment-changed-out.tex"
     (lambda ()
       (forward-line 1)
       (insert ";; inserted\n")))
    (equal lentic-test-last-transform ";; inserted\n")))

  (should
   (and
    (lentic-test-clone-and-change-equal
     'lentic-latex-clojure-init
     "block-comment.tex" "block-comment-changed-1.clj"
     (lambda ()
       (forward-line 1)
       (insert ";; inserted\n")))
    (equal lentic-test-last-transform ";; inserted\n")))

  (should
   (and
    (lentic-test-clone-and-change-equal
     'lentic-latex-clojure-init
     "block-comment.tex" "block-comment-changed-2.clj"
     (lambda ()
       (search-forward "\\begin{code}\n")
       (insert "(form inserted)\n")))
    (equal lentic-test-last-transform "(form inserted)\n"))))

(ert-deftest clojure-latex-first-line ()
  "Tests for a bug after introduction of incremental blocks."
  (should
   (lentic-test-clone-and-change-equal
    'lentic-clojure-latex-init
    "block-comment.clj" "block-comment.tex"
    (lambda ()
      (delete-char 1)
      (delete-char 1)
      (insert ";")
      (insert ";")))))

(ert-deftest clojure-latex-empty-line ()
  "Tests for a deletion of an empty line"
  (should
   (lentic-test-clone-and-change-equal
    'lentic-clojure-latex-init
    "block-comment.clj" "block-comment.tex"
    nil
    (lambda ()
      (goto-char (point-min))
      (forward-line 1)
      (delete-char 1)
      (insert "\n")))))

(ert-deftest orgel-org-incremental ()
  (should
   (lentic-test-clone-and-change-equal
    'lentic-orgel-org-init
    "orgel-org.el" "orgel-org.el"
    nil
    (lambda ()
      (show-all)
      (goto-char (point-min))
      (forward-line)
      (insert "a")
      (delete-char -1))
    t)))
