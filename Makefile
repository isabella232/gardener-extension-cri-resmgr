#
# Copyright 2022 Intel Corporation. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
.PHONY: build clean e2e-test test start _install-binaries _build-agent-image build-images push-images _build-extension-image _build-installation-image

REGISTRY                         := localhost:5001/
EXTENSION_IMAGE_NAME             := gardener-extension-cri-resmgr
INSTALLATION_IMAGE_NAME          := gardener-extension-cri-resmgr-installation
TAG                              := latest

# Please keep it up to date with agent image in charts/images.yaml
CRI_RM_VERSION                   := 0.7.2
CRI_RM_ARCHIVE_NAME              := cri-resource-manager-$(CRI_RM_VERSION).x86_64.tar.gz
CRI_RM_URL_RELEASE               := https://github.com/intel/cri-resource-manager/releases/download/v$(CRI_RM_VERSION)/$(CRI_RM_ARCHIVE_NAME)


# make start options
IGNORE_OPERATION_ANNOTATION 	 := false

build:
	go build -v ./cmd/gardener-extension-cri-resmgr
	go test -c -v  ./test/e2e/cri-resmgr-extension/. -o gardener-extension-cri-resmgr.e2e-tests
	go test -c -v ./pkg/controller/lifecycle -o ./gardener-extension-cri-resmgr.actuator.test
	go test -c -v ./pkg/configs -o ./gardener-extension-cri-resmgr.configs.test

test:
	# Those tests (renders charts, uses env to read files) change CWD during execution (required because rely on charts and fixtures).
	ginkgo ./pkg/...

clean:
	go clean -cache -modcache -testcache
	rm cri-resmgr-extension.test
	rm gardener-extension-cri-resmgr

e2e-test:
	@echo "Note1:"
	@echo "Make sure following hosts are defined in etc/hosts"
	@echo "127.0.0.1 api.e2e-default.local.external.local.gardener.cloud"
	@echo "127.0.0.1 api.e2e-default.local.internal.local.gardener.cloud"
	@echo ""
	@echo "Note2:"
	@echo "KUBECONFIG should point to kind-local gardener cluster"
	@echo ""
	@echo "Note3:"
	@echo "ControllerRegistration and ControllerDeployment CRDs must be already deployed to cluster"
	@echo 
	@echo "Note4:"
	@echo "Following labels are available: enable, reenable, disable"
	# Note seed 1 is used to keep order from simples to more complex cases (TODO to be replaced with SERIAL)
	ginkgo run -v --progress --seed 1 --slow-spec-threshold 2h --timeout 2h ./test/e2e/cri-resmgr-extension

start:
	go run ./cmd/gardener-extension-cri-resmgr --ignore-operation-annotation=$(IGNORE_OPERATION_ANNOTATION)

_install-binaries:
	# WARNING: this should be run in container
	wget --directory-prefix=/cri-resmgr-installation $(CRI_RM_URL_RELEASE)
	tar -xvf /cri-resmgr-installation/$(CRI_RM_ARCHIVE_NAME) --directory /cri-resmgr-installation
	rm /cri-resmgr-installation/$(CRI_RM_ARCHIVE_NAME)

_build-extension-image:
	docker build -t $(REGISTRY)$(EXTENSION_IMAGE_NAME):$(TAG) -f Dockerfile --target $(EXTENSION_IMAGE_NAME) .
_build-installation-image:
	docker build -t $(REGISTRY)$(INSTALLATION_IMAGE_NAME):$(TAG) -f Dockerfile --target $(INSTALLATION_IMAGE_NAME) .

build-images: _build-extension-image _build-installation-image

push-images:
	docker push $(REGISTRY)$(EXTENSION_IMAGE_NAME):$(TAG)
	docker push $(REGISTRY)$(INSTALLATION_IMAGE_NAME):$(TAG)


UPSTREAM_AGENT_IMAGE_NAME 		 := intel/cri-resmgr-agent
UPSTREAM_AGENT_IMAGE		     := docker.io/$(UPSTREAM_AGENT_IMAGE_NAME):v$(CRI_RM_VERSION)
LOCAL_AGENT_IMAGE 				 := $(REGISTRY)$(UPSTREAM_AGENT_IMAGE_NAME):v$(CRI_RM_VERSION)
cache-agent-image:
	# download cri-resmgr agent image and push it to registry pointed by REGISTRY
	docker pull $(UPSTREAM_AGENT_IMAGE)
	docker tag $(UPSTREAM_AGENT_IMAGE) $(LOCAL_AGENT_IMAGE)
	docker push $(LOCAL_AGENT_IMAGE)


AGENT_IMAGE_NAME            := gardener-extension-cri-resmgr-agent
CRI_RM_SRC_ARCHIVE_NAME     := vendored-cri-resource-manager-$(CRI_RM_VERSION).tar.gz
CRI_RM_URL_SRC              := https://github.com/intel/cri-resource-manager/releases/download/v$(CRI_RM_VERSION)/$(CRI_RM_SRC_ARCHIVE_NAME)
_build-agent-image:
	-mkdir tmpbuild
	wget --directory-prefix=tmpbuild -nc $(CRI_RM_URL_SRC)
	tar -C tmpbuild -xzvf tmpbuild/$(CRI_RM_SRC_ARCHIVE_NAME)
	# Use existing Dockerfile from cri-resource-manager source code.
	# TODO: consider using provide image https://github.com/intel/gardener-extension-cri-resmgr/issues/41
	docker build -t $(REGISTRY)$(AGENT_IMAGE_NAME):$(TAG) -f tmpbuild/cri-resource-manager-$(CRI_RM_VERSION)/cmd/cri-resmgr-agent/Dockerfile  tmpbuild/cri-resource-manager-$(CRI_RM_VERSION)
	docker push $(REGISTRY)$(AGENT_IMAGE_NAME):$(TAG)