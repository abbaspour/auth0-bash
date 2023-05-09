SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

PLAN_FILE=sns.plan
report="sns.html"

HOST:=$(shell hostname)
ifeq ($(HOST), C62W6K1696x)
	PREFIX=gk e -p pro-services-dev --
else
	PREFIX=
endif

region:=$(shell $(PREFIX) terraform output aws_region)

main: plan

plan:
	$(PREFIX) terraform plan -out $(PLAN_FILE)

apply:
	$(PREFIX) terraform apply $(PLAN_FILE)

show:
	$(PREFIX) terraform show

init:
	$(PREFIX) terraform init -upgrade

clean:
	rm $(PLAN_FILE)
	rm -rf dist
	rm -f sns-put-lambda.zip

listen-apns:
	while [[ true ]]; do \
		$(PREFIX) aws --region $(region) sqs receive-message --queue-url $(shell $(PREFIX) terraform output apns_queue_url) --wait-time-seconds 20; \
	done

graph:
	$(PREFIX) terraform graph | dot -Tsvg > graph.svg

.PHONY: all clean plan

all: sns-put-lambda.zip

dist:
	mkdir -p dist

dist/index.js: src/index.ts
	npm run build

node_modules: package.json
	npm i

sns-put-lambda.zip: dist/index.js node_modules
	zip -r9 sns-put-lambda.zip dist node_modules