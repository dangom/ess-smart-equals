;;; ess-smart-equals.el -- better smart-assignment with = in R, no underscores  -*- lexical-binding: t; -*-

;; Copyright (C) 2010-2015 Christopher R. Genovese, all rights reserved.

;; Author: Christopher R. Genovese <genovese@cmu.edu>
;; Maintainer: Christopher R. Genovese <genovese@cmu.edu>
;; Keywords: helm, sources, matching, convenience
;; URL: http://sulu.github.io
;; Version: 0.1.1
;; Package-Version: 0.1.1
;; Package-Requires: ((emacs "24") (ess "10.00"))


;;; License:
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;


;;; Commentary:
;;
;;  Assignment in R is syntactically complicated by two features: 1. the
;;  historical role of '_' (underscore) as an assignment character in
;;  the S language (SPlus may still allow this) and 2. the somewhat
;;  inconvenient to, type, if conceptually pure, '<-' operator as the
;;  preferred assignment operator.
;;
;;  ESS uses '_' as a (default) smart assignment character which expands
;;  to the '<-' with one invokation and gives an underscore on two.
;;  This makes it somewhat painful to use underscores in variable, field,
;;  and function names. Moreover, _ no longer has any association with
;;  assignment in R, so the mnemonic is strained.
;;
;;  It is possible to reassign the special underscore to another character,
;;  such as '=', but that raises other inconviences becuase of the
;;  multiple roles that '=' can play.
;;
;;  This package gives an alternative smart assignment for R and S code
;;  that is tied to the `=' key. It works under the assumption that
;;  binary operators involving `=' will be surrounded by spaces but that
;;  default argument assignment with `=' *will not*.
;;
;;  This package defines a global minor mode `ess-smart-equals-mode',
;;  that when enabled causes the following behaviors on seeing an `=' key:
;;
;;   1. In a string or comment or with a non-S language, insert `='.
;;   2. If a space (or tab) preceeds the `=', insert a version of `ess-S-assign'
;;      with no leading space. (Other preceeding spaces are left alone.)
;;   3. If any of =<>! preceed the current `=', insert an `= ', but
;;      if no space preceeds the preceeding character, insert a space
;;      so that the binary operator is surrounded by spaces.
;;   4. Otherwise, just insert an `='.
;;
;;  These insertions ensure that binary operators have a space on either
;;  end but they do not otherwise adjust spacing on either side. Disabling
;;  the minor mode restores (as well as possible) the previous ESS assignment
;;  setup.
;;

;;; Change Log:


;;; Code:

(defvar ess-smart-equals--last-assign-key
  ess-smart-S-assign-key
  "Cached value of previous smart assignment key.")

(defvar ess-smart-equals--last-assign-str
  ess-S-assign
  "Cached value of previous assignment string.")

(defun ess-smart-equals--strip-leading-space (string)
  "Strip one leading space from string, if present."
  (replace-regexp-in-string "\\` " "" string))

(defun ess-smart-equals--restore-leading-space (string)
  "Add one leading space to string, if none are present."
  (replace-regexp-in-string "\\`\\(\\S-\\)" " \\1" string))

(defun ess-smart-equals--maybe-narrow ()
  "Narrow to relevant part of buffer in various ess-related modes."
  (ignore-errors
    (when (and (eq major-mode 'inferior-ess-mode)
               (> (point) (process-mark (get-buffer-process (current-buffer)))))
      (narrow-to-region (process-mark (ess-get-process)) (point-max)))
    (and ess-noweb-mode
         (ess-noweb-in-code-chunk)
         (ess-noweb-narrow-to-chunk))
    (and (fboundp 'pm/narrow-to-span)
         polymode-mode
         (pm/narrow-to-span))))

(defun ess-smart-equals--after-assign-p ()
  "Are we looking backward at `ess-S-assign'? 
If so, return number of characters to its beginning; otherwise, nil."
  (let ((ess-assign-len (length ess-S-assign)))
    (when (and (>= (point) (+ ess-assign-len (point-min))) ; enough room back
               (save-excursion
                 (backward-char ess-assign-len)
                 (looking-at-p ess-S-assign)))
      ess-assign-len)))

(defun ess-smart-equals (&optional raw)
  "Insert an R assignment for equal signs preceded by spaces.
For equal signs not preceded by spaces, as in argument lists,
just use equals. This can effectively distinguish the two uses
of equals in every case."
  (interactive "P")
  (save-restriction
    (ess-smart-equals--maybe-narrow)
    (let ((prev-char (preceding-char)))
      (cond
       ((or raw
            (not (equal ess-language "S"))
            (not (string-match-p "[ \t=]" (string prev-char)))
            (ess-inside-string-or-comment-p (point)))
        (insert ?=))
       ((char-equal prev-char ?=)
        (when (save-excursion
                (goto-char (- (point) 2)) ; OK if we go past beginning (ignore-errors (backward-char 2))
                (not (looking-at-p "[ \t]")))
          (delete-char -1)
          (insert " ="))
        (insert "= "))
       (t
        (let ((back-by (ess-smart-equals--after-assign-p)))
          (if (not back-by)
              (insert ess-S-assign)
            (delete-char (- back-by))
            (insert "== "))))))))

(define-minor-mode ess-smart-equals-mode
     "Minor mode for setting = key to intelligently handle assignment.
When enabled for S-language modes, an `=' key that follows a
space is converted to an assignment (the string `ess-S-assign')
except in strings and comments. An `=' key that follows any other
character or in a string or comment is inserted as is; and `C-q =' 
always inserts the character as is.

This is a global minor mode that will affect the use of '=' in
all ess-mode and inferior-ess-mode buffers. A local mode
may be included in a future version.

Do not set the variable `ess-smart-equals-mode' directly; use the
function of the same name instead. Also any changes to
`ess-smart-S-assign-key' while this mode is enabled will have no
affect and will be lost when it is disabled."
     :lighter nil
     :require 'ess-site
     (if (not ess-smart-equals-mode)
         (progn ; reset to default with previous assign key
           (setq ess-S-assign ess-smart-equals--last-assign-str)
           (ess-toggle-S-assign nil) ; clear smart assignment
           (setq ess-smart-S-assign-key ess-smart-equals--last-assign-key)
           (ess-toggle-S-assign t))
       (setq ess-smart-equals--last-assign-key ess-smart-S-assign-key)
       (setq ess-smart-equals--last-assign-str ess-S-assign)
       (setq ess-S-assign (ess-smart-equals--strip-leading-space ess-S-assign))
       (setq ess-smart-S-assign-key "=")
       (ess-toggle-S-assign nil)   ;; reset ess map bindings
       (define-key ess-mode-map ess-smart-S-assign-key 'ess-smart-equals)
       (define-key inferior-ess-mode-map ess-smart-S-assign-key
         'ess-smart-equals)))

