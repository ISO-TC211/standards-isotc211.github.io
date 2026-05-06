SHELL := /bin/bash

all: _site

bundle:
	bundle

bundle-modspec:
	BUNDLE_GEMFILE=Gemfile.modspec BUNDLE_PATH=vendor/modspec bundle install

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

_site: bundle bundle-modspec npm .build_source_stamp
	bundle exec jekyll build

serve: bundle bundle-modspec npm .build_source_stamp
	bundle exec jekyll serve

.PHONY: all clean serve bundle bundle-modspec npm
