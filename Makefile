SHELL := /bin/bash

all: _site

bundle:
	bundle

npm:
	npm install

clean:
	bundle exec jekyll clean

_site: bundle npm
	bundle exec jekyll build

serve: bundle npm
	bundle exec jekyll serve

.PHONY: all clean serve bundle npm
