(require 's)
(require 'f)
(require 'dash)

(defun lzs/batchlist-expand (batchlist)
  "Expand a list of batch set specs.
e.g. '(\"1,2,6-10\" \"11,12\") which would expand to '(1 2 6 7 8 9 10 11 12)"
  (-mapcat 'lzs/batch-expand batchlist))

(defun lzs/batch-expand (batchspec)
  "Expand a single batch set spec.
e.g. \"1,2,6-10\" which would expand to '(1 2 6 7 8 9 10)"
  (let* ((ranges (s-split "," batchspec)))
    (-mapcat 'lzs/range-expand ranges)))

(defun lzs/range-expand (range)
  "Expand a range (part of a batch set spec).  A range may or may not have a dash in it.  Without a dash it expands to a singleton list.
e.g. \"6-10\"   -> '(6 7 8 9 10)
     \"3\"      -> '(3)"
  (-let [parts (mapcar 'string-to-number (s-split "-" range))]
    (pcase parts
      (`(,start ,end) (cl-loop
                       for x from start to end collect x))
      (`(,single) `(,single))
      (_ (throw 'lzs/range-parse-error range)))))

;; (lzs/batchlist-expand (list "1" "2,3,4" "5-8" "12,13-18,20-22"))

(defun lzs/get-indexed-batches ()
  "Return the list of batch numbers with entries in batch_index.txt.
Whether the files those batch numbers refer to actually exist is ignored."
  (let* ((lines (s-lines (f-read-text "batch_index.txt")))
         (entries (--map (nth 1 it)
                         (--filter it
                                   (--map (s-match "^\\([0-9,-]+\\)" it) lines)))))
    (sort (lzs/batchlist-expand entries) '<)))


(defun lzs/fname-batch-number (fname)
  "Extract batch number from a batch member's filename."
  (-when-let (the-match (s-match "^b\\([0-9]+\\)_" fname))
    (string-to-number (nth 1 the-match))))

;; (lzs/fname-batch-number "b00123_p001.pdf")  ; 123 


(defun lzs/file-needs-indexing? (indexed-list fname)
  (-when-let (file-batchno (lzs/fname-batch-number fname))
    (not (-contains? indexed-list file-batchno))))

(defun lzs-dired/mark-needs-indexing ()
  "Mark batch member files that need to be indexed in a Dired buffer"
  (interactive)
  (-if-let (indexed (lzs/get-indexed-batches))
      (dired-mark-if (-when-let (fname (dired-get-filename 'no-dir t))
                       (lzs/file-needs-indexing? indexed fname))
                     "unindexed batch member")
    (message "Could not get index list or index is empty")))


;;; Operations on index file


(defun lzs-index/point-on-entry? ()
  (-when-let (line (thing-at-point 'line))
    (s-match "^[0-9,-]+" line)))

(defun lzs-index/-goto-top-for-batch (batchnum)
  (goto-char (point-min))
  ;; Skip over initial comments and blank lines
  (while (and (not (eobp))
              (not (lzs-index/point-on-entry?)))
    (forward-line 1))
  ;; Find our position
  (while (and (not (eobp))
              (> batchnum (-max (lzs-index/batches-at-line))))
    (forward-line 1))
  ;; Return whether we're looking at the given batch number's entry
  (lzs-index/line-covers-batch? batchnum))

(defun lzs-index/goto-pos-for-batch (batchnum)
  "Go to position for new batch entry"
  (interactive "nBatch: ")
  (lzs-index/-goto-top-for-batch batchnum)  ; don't care if it succeeds
  ;; Go to last possible line so we insert at end of run
  (while (and (not (eobp))
              (lzs-index/line-covers-batch? batchnum))
    (forward-line 1)))

(defun lzs-index/batches-at-line ()
  "List the batches covered by line at point"
  (-when-let* ((line (thing-at-point 'line))
               ((match) (s-match "^[0-9,-]+" line)))
    (lzs/batch-expand match)))

(defun lzs-index/line-covers-batch? (batchnum)
  (memq batchnum (lzs-index/batches-at-line)))

(defun lzs-index/new-entry (batchnum)
  (interactive "nBatch: ")
  (lzs-index/goto-pos-for-batch batchnum)
  (open-line 1)
  (insert (number-to-string batchnum) " "))

(defun lzs-index/goto-entry (batchnum)
  (interactive "nBatch: ")
  (-if-let (batch-pos (lzs-index/batch-entry-pos batchnum))
      (goto-char batch-pos)
    (message (format "Batch %d not in index" batchnum))))

(defun lzs-index/batch-entry-pos (batchnum)
  (save-excursion
    (when (lzs-index/-goto-top-for-batch batchnum)
      (point))))


;;; Make entries from sensible context

(defun lzs/chosen-member ()
  (pcase major-mode
    ('dired-mode (dired-get-filename 'no-dir t))
    (_ (file-name-nondirectory (buffer-file-name)))))

(defun lzs/chosen-member-batchnum ()
  (-when-let (fname (lzs/chosen-member))
    (lzs/fname-batch-number fname)))

(defun lzs/chosen-member-new-index-entry ()
  (interactive)
  (-if-let (batchnum (lzs/chosen-member-batchnum))
      (progn (find-file-other-window "batch_index.txt")
             (lzs-index/new-entry batchnum))
    (message "Cannot determine member batch number")))

(defun lzs/chosen-member-goto-index-entry ()
  (interactive)
  ;; TODO don't display index buffer if not found
  (-if-let (batchnum (lzs/chosen-member-batchnum))
      (progn (find-file-other-window "batch_index.txt")
             (lzs-index/goto-entry batchnum))
    (message "Cannot determine member batch number")))
