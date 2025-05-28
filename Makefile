.PHONY: help f_release f_prod
PWD := $(shell (pwd))
FULL_VERSION := $(shell (cat pubspec.yaml | grep "version" | awk '{print $$2}'))
STRING_VERSION := $(shell (echo $(FULL_VERSION) | awk -F+ '{print $$1}'))
NUMBER_VERSION := $(shell (echo $(FULL_VERSION) | awk -F+ '{print $$2}'))
GREEN  := \033[0;32m
RESET  := \033[0m

help: ## This help dialog.
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//'`); \
	for help_line in $${help_lines[@]}; do \
		IFS=$$'#' ; \
		help_split=($$help_line) ; \
		help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		printf "%-30s %s\n" $$help_command $$help_info ; \
	done

f_release: ## This is flutter release step.
	@echo "$(GREEN)|- Running release script 🔨-|$(RESET)"
	@flutter "build" "apk" "--release"
	@open "build/app/outputs/flutter-apk/"
	@echo "$(GREEN)|- Release script finished 🚀-|$(RESET)"

f_prod: ## This is flutter build appbundle step.
	@echo "$(GREEN) ⊢ Running build appbundle ⊣ $(RESET)"
	@flutter build appbundle
	@open "build/app/outputs/bundle/release"
	@echo "$(GREEN)|- Build appbundle finished 🚀-|$(RESET)"
