SHELL=/bin/bash -o pipefail

BIN_DIR?=$(shell pwd)/tmp/bin
GRAFANA_DEF_CONF=$(shell pwd)/tmp/grafana-sample.ini

JB_BIN=$(BIN_DIR)/jb
GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
JSONNET_BIN=$(BIN_DIR)/jsonnet
TOOLING=$(JB_BIN) $(GOJSONTOYAML_BIN) $(JSONNET_BIN)

.PHONY: manifests

manifests: main.jsonnet addons components vendor
	rm -rf manifests && mkdir manifests
	$(JSONNET_BIN) -J vendor -m manifests -c "main.jsonnet" | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML_BIN) > {}.yaml' -- {}
	find manifests -type f ! -name '*.yaml' -delete && rm kustomization

.PHONY: update

update: update_dependency $(GRAFANA_DEF_CONF)

.PHONY: update_dependency

update_dependency: $(JB_BIN)
	$(JB_BIN) update

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from tools.go
	@cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % go build -modfile=go.mod -o $(BIN_DIR) %

$(GRAFANA_DEF_CONF): versions.json
	@wget -O $(GRAFANA_DEF_CONF) https://raw.githubusercontent.com/grafana/grafana/v`cat versions.json | grep grafana | grep -oE "[0-9]+(\.[0-9]+)*"`/conf/sample.ini