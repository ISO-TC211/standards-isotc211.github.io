SHELL := /bin/bash

all: _site

bundle:
	bundle

npm:
	npm install

clean:
	bundle exec jekyll clean
	rm -rf build_source .build_source_stamp

.build_source_stamp:
	rm -rf build_source
	mkdir -p build_source
	cp -a source/* build_source/
	@touch $@

_site: bundle npm .build_source_stamp
	bundle exec jekyll build

serve: bundle npm .build_source_stamp
	bundle exec jekyll serve

.PHONY: all clean serve bundle npm
