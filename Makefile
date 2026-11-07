a.out:git


HOSTNAME := $(shell hostname)

git:
ifeq ($(HOSTNAME),P1)
	@if [ -n "$$(git status --porcelain)" ]; then \
	echo "##> ✗ 未コミットの変更があります。先に commit してください"; \
	     git status --short; \  		exit 1; \
	     fi
	     @git log --oneline @{u}..HEAD
	git push
else
	@echo "$(HOSTNAME): サブ機からはpushしません（pullのみ）"
	git pull --rebase
endif

# ------------------------------------------------------------
# [Read-only] This file opens in read-only mode automatically.
# Toggle editable: C-c C-e  or  qq
# ------------------------------------------------------------
# Local Variables:
# buffer-read-only: t
# End:
