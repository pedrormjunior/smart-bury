.PHONY: test compile checkdoc package-lint demo-check demo-preview demo test-interactively test-emacs-defaults-interactively

test:
	emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el \
	  -f ert-run-tests-batch-and-exit

compile:
	emacs -batch --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile smart-bury.el
	rm -f smart-bury.elc

checkdoc:
	emacs -batch -l checkdoc --eval \
	  "(progn (defvar warnings 0) \
	          (setq checkdoc-verb-check-experimental-flag t) \
	          (advice-add 'display-warning :before \
	                      (lambda (&rest _) (setq warnings (1+ warnings)))) \
	          (checkdoc-file \"smart-bury.el\") \
	          (kill-emacs (min warnings 1)))"

# Uses package-lint from the user's installed packages when available;
# otherwise (e.g. in CI) installs it from MELPA into a local .elpa/.
package-lint:
	emacs -batch --eval \
	  "(progn (package-initialize) \
	          (unless (require 'package-lint nil t) \
	            (setq package-user-dir (expand-file-name \".elpa\")) \
	            (add-to-list 'package-archives \
	                         '(\"melpa\" . \"https://melpa.org/packages/\") t) \
	            (package-initialize) \
	            (package-refresh-contents) \
	            (package-install 'package-lint) \
	            (require 'package-lint)))" \
	  -f package-lint-batch-and-exit smart-bury.el

# The demo animation lives in demo/, a separate uv project (see
# demo/pyproject.toml).  demo-check replays the README cases on the
# Python model of the algorithm that drives the animation.
demo-check:
	cd demo && uv run python smart_bury_sim.py

# Fast, low-quality render (480p15) into demo/smart-bury-demo-preview.mp4.
demo-preview: demo-check
	cd demo && uv run manim -ql --media_dir media \
	  -o smart-bury-demo-preview smart_bury_demo.py SmartBuryDemo
	cp demo/media/videos/smart_bury_demo/480p15/smart-bury-demo-preview.mp4 demo/

# Final render (1080p60) into demo/smart-bury-demo.mp4.
demo: demo-check
	cd demo && uv run manim -qh --media_dir media \
	  -o smart-bury-demo smart_bury_demo.py SmartBuryDemo
	cp demo/media/videos/smart_bury_demo/1080p60/smart-bury-demo.mp4 demo/

test-interactively:
	emacs -Q -L . -l smart-bury -l $@

test-emacs-defaults-interactively:
	emacs -Q -L . -l $@
