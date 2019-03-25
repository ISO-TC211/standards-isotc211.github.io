SHELL := /bin/bash

all: _site

bundle:
	bundle

clean:
	rm -rf _site build_source

build_source:
	mkdir -p $@; \
	cp -a source/* build_source; \
	cp -a standards/* build_source; \

_site: bundle build_source
	bundle exec jekyll build

serve: _site
	bundle exec jekyll serve

update-init:
	git submodule update --init

update-modules:
	git submodule foreach git pull origin master

.PHONY: all clean serve update-init update-modules
