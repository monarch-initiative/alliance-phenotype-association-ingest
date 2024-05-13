ROOTDIR = $(shell pwd)
RUN = poetry run
VERSION = $(shell poetry -C src/alliance_phenotype_association_ingest version -s)

### Help ###

define HELP
╭───────────────────────────────────────────────────────────╮
  Makefile for alliance_phenotype_association_ingest			    
│ ───────────────────────────────────────────────────────── │
│ Usage:                                                    │
│     make <target>                                         │
│                                                           │
│ Targets:                                                  │
│     help                Print this help message           │
│                                                           │
│     all                 Install everything and test       │
│     fresh               Clean and install everything      │
│     clean               Clean up build artifacts          │
│     clobber             Clean up generated files          │
│                                                           │
│     install             Poetry install package            │
│     download            Download data                     │
│     run                 Run the transform                 │
│                                                           │
│     docs                Generate documentation            │
│                                                           │
│     test                Run all tests                     │
│                                                           │
│     lint                Lint all code                     │
│     format              Format all code                   │
╰───────────────────────────────────────────────────────────╯
endef
export HELP

.PHONY: help
help:
	@printf "$${HELP}"


### Installation and Setup ###

.PHONY: fresh
fresh: clean clobber all

.PHONY: all
all: install test

.PHONY: install
install: 
	poetry install


### Documentation ###

.PHONY: docs
docs:
	$(RUN) mkdocs build


### Testing ###

.PHONY: test
test: download
	$(RUN) pytest tests

### Running ###

.PHONY: download
download:
	$(RUN) ingest download

###
.PHONY: post-download
post-download:
	gunzip -f data/BGI_*.gz || true
	cat data/BGI_*.json | jq '.data[].basicGeneticEntity.primaryId' | sed 's@\"@@g'  | sed 's@$$@\tbiolink:Gene@g' > data/alliance_gene.tsv
	gunzip -f data/VARIANT-ALLELE*.tsv.gz || true
	cat data/VARIANT-ALLELE_NCBITaxon*.tsv | grep -v "^#" | grep -v "^Taxon" | cut -f 3 | sort | uniq | sed 's@$$@\tbiolink:SequenceVariant@g' > data/alliance_allele.tsv
	gunzip -f data/AGM_*.json.gz || true
	cat data/AGM_*.json | jq '.data[].primaryID' | sed 's@\"@@g'  | sed 's@$$@\tbiolink:Genotype@g' > data/alliance_genotype.tsv


.PHONY: run
run: download post-download
	$(RUN) ingest transform
	$(RUN) python scripts/generate-report.py


### Linting, Formatting, and Cleaning ###

.PHONY: clean
clean:
	rm -f `find . -type f -name '*.py[co]' `
	rm -rf `find . -name __pycache__` \
		.venv .ruff_cache .pytest_cache **/.ipynb_checkpoints

.PHONY: clobber
clobber:
	# Add any files to remove here
	@echo "Nothing to remove. Add files to remove to clobber target."

.PHONY: lint
lint: 
	$(RUN) ruff check --diff --exit-zero
	$(RUN) black -l 120 --check --diff src tests

.PHONY: format
format: 
	$(RUN) ruff check --fix --exit-zero
	$(RUN) black -l 120 src tests
