SHELL := /bin/bash

PYTHON := .venv/bin/python
BUNDLE_PIPELINE := tools/pdf_to_bundle.py
TESSDATA_PREFIX ?= /Users/wn.lin/vscode-git/dba_career/KnowledgeBase/collector/imported/tessdata
lang ?= chi_tra+eng

.PHONY: help check-key run query clean-md

help:
	@printf "Usage:\n"
	@printf "  make check-key\n"
	@printf "  make run pdf=PATH [out_dir=PATH] [lang=chi_tra+eng] [model=gpt-5-mini]\n"
	@printf "  make query q=\"...\" docs=PATH embeddings=PATH [top_k=5]\n"
	@printf "  make clean-md input=PATH output=PATH [model=gpt-5-mini]\n"

check-key:
	@if [ -z "$$OPENAI_API_KEY" ]; then \
		printf "OPENAI_API_KEY is not set.\n"; \
		printf "Set it in your shell, e.g.:\n"; \
		printf "  export OPENAI_API_KEY=\"sk-...\"\n"; \
		printf "Then re-run make.\n"; \
		exit 1; \
	else \
		printf "OPENAI_API_KEY is set.\n"; \
	fi

run: check-key
	@if [ -z "$(pdf)" ]; then \
		printf "Missing pdf. Example:\n"; \
		printf "  make run pdf=0a5cc77baa6fdac01c4cad8e5669fa86.pdf out_dir=0a5cc77baa6fdac01c4cad8e5669fa86.pdf-<uuid>\n"; \
		exit 1; \
	fi
	@OUT_DIR="$(out_dir)"; \
	if [ -z "$$OUT_DIR" ]; then \
		OUT_DIR=$$(TESSDATA_PREFIX="$(TESSDATA_PREFIX)" \
			$(PYTHON) $(BUNDLE_PIPELINE) \
				--pdf "$(pdf)" \
				--skip-origin \
				--lang "$(lang)" | \
			$(PYTHON) -c 'import json,sys; print(json.load(sys.stdin)["out_dir"])'); \
	else \
		TESSDATA_PREFIX="$(TESSDATA_PREFIX)" \
			$(PYTHON) $(BUNDLE_PIPELINE) \
				--pdf "$(pdf)" \
				--out-dir "$$OUT_DIR" \
				--skip-origin \
				--lang "$(lang)"; \
	fi; \
	$(PYTHON) tools/clean_full_md.py \
		--input "$$OUT_DIR/full.md" \
		--output "$$OUT_DIR/full2.md" \
		$(if $(model),--model "$(model)",)

query: check-key
	@if [ -z "$(q)" ] || [ -z "$(docs)" ] || [ -z "$(embeddings)" ]; then \
		printf "Missing q, docs, or embeddings. Example:\n"; \
		printf "  make query q=\"zero-downtime upgrades\" docs=outputs/xxx.jsonl embeddings=outputs/xxx.embeddings.jsonl\n"; \
		exit 1; \
	fi
	@$(PYTHON) tools/retrieve_chunks.py \
		--query "$(q)" \
		--docs "$(docs)" \
		--embeddings "$(embeddings)" \
		$(if $(top_k),--top-k "$(top_k)",)

clean-md: check-key
	@if [ -z "$(input)" ] || [ -z "$(output)" ]; then \
		printf "Missing input or output. Example:\n"; \
		printf "  make clean-md input=path/to/full.md output=path/to/full2.md\n"; \
		exit 1; \
	fi
	@$(PYTHON) tools/clean_full_md.py \
		--input "$(input)" \
		--output "$(output)" \
		$(if $(model),--model "$(model)",)
