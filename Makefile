SHELL := /bin/bash

all: build

bundle:
	bundle install

npm:
	npm install

build: bundle
	npm run build

serve:
	npm run dev

test: bundle
	bundle exec rspec spec

clean:
	rm -rf dist .astro src/data/standards-catalog.json src/data/standards-pages.json

.PHONY: all build serve test clean bundle npm
