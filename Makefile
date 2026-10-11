.PHONY: test test-interactively test-emacs-defaults-interactively

test:
	emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el \
	  -f ert-run-tests-batch-and-exit

test-interactively:
	emacs -Q -L . -l smart-bury -l $@

test-emacs-defaults-interactively:
	emacs -Q -L . -l $@
