# Copyright 2018 The Kubernetes Authors.
# Copyright 2022 Google LLC
# Copyright 2023 Preferred Networks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export STAGINGVERSION ?= $(shell git describe --long --tags --match='v*' --dirty 2>/dev/null || git rev-list -n1 HEAD)
export BUILD_DATE ?= $(shell date +"%Y-%m-%dT%H:%M:%S%z")
BINDIR ?= bin
LDFLAGS ?= -s -w -X main.version=${STAGINGVERSION} -X main.builddate=${BUILD_DATE} -extldflags '-static'

DRIVER_BINARY = meta-fuse-csi-plugin
STARTER_BINARY = fuse-starter
FUSERMOUNT3PROXY_BINARY = fusermount3-proxy

REGISTRY ?= ghcr.io/pfnet-research/meta-fuse-csi-plugin
DRIVER_IMAGE = ${REGISTRY}/${DRIVER_BINARY}
STARTER_IMAGE = ${REGISTRY}/${STARTER_BINARY}
EXAMPLE_IMAGE = ${REGISTRY}/mfcp-example

DOCKER_BUILD_ARGS ?= --build-arg STAGINGVERSION=${STAGINGVERSION}
ifneq ("$(shell docker buildx build --help | grep 'provenance')", "")
DOCKER_BUILD_ARGS += --provenance=false
endif

BUILDX_BUILDER = mfcp-builder

LOAD_TO_KIND ?= false
PUBLISH_IMAGE ?= false

$(info STAGINGVERSION is ${STAGINGVERSION})
$(info DRIVER_IMAGE is ${DRIVER_IMAGE})
$(info STARTER_IMAGE is ${STARTER_IMAGE})

.PHONY: all

all: build-driver build-examples

driver:
	mkdir -p ${BINDIR}
	CGO_ENABLED=0 GOOS=linux go build -ldflags "${LDFLAGS}" -o ${BINDIR}/${DRIVER_BINARY} cmd/csi_driver/main.go

fuse-starter:
	mkdir -p ${BINDIR}
	CGO_ENABLED=0 GOOS=linux go build -ldflags "${LDFLAGS}" -o ${BINDIR}/${STARTER_BINARY} cmd/fuse_starter/main.go

fusermount3-proxy:
	mkdir -p ${BINDIR}
	CGO_ENABLED=0 GOOS=linux go build -ldflags "${LDFLAGS}" -o ${BINDIR}/${FUSERMOUNT3PROXY_BINARY} cmd/fusermount3-proxy/main.go

build-driver:
	$(eval IMAGE_NAME := ${DRIVER_IMAGE}:${STAGINGVERSION})
	docker buildx build --load ${DOCKER_BUILD_ARGS} ${DOCKER_CACHE_ARGS} \
		--file ./cmd/csi_driver/Dockerfile \
		--tag ${IMAGE_NAME} \
		.
	if [ "${LOAD_TO_KIND}" = "true" ]; then \
		kind load docker-image ${IMAGE_NAME};\
	fi

.PHONY: init-buildx-driver
init-buildx-driver:
	- docker buildx rm mfcp-builder
	docker buildx create --name ${BUILDX_BUILDER}

.PHONY: push-driver
push-driver: init-buildx-driver
	docker buildx build ${DOCKER_BUILD_ARGS} ${DOCKER_CACHE_ARGS} \
		--file ./cmd/csi_driver/Dockerfile \
		--tag ${DRIVER_IMAGE}:${STAGINGVERSION} \
		--tag ${DRIVER_IMAGE}:latest \
		--builder ${BUILDX_BUILDER} \
		--platform linux/amd64,linux/arm64 .

define example-template
ifneq ("$(BUILD_EXAMPLES)", "")
BUILD_EXAMPLES += build-example-$(1)-$(2)
PUSH_EXAMPLES += push-example-$(1)-$(2)
else
BUILD_EXAMPLES := build-example-$(1)-$(2)
PUSH_EXAMPLES := push-example-$(1)-$(2)
endif

.PHONY: build-example-$1-$2
build-example-$(1)-$(2):
	$(eval IMAGE_NAME := ${EXAMPLE_IMAGE}-$1-$2:${STAGINGVERSION})
	docker buildx build --load ${DOCKER_BUILD_ARGS} ${DOCKER_CACHE_ARGS} \
		--file ./examples/$1/$2/Dockerfile \
		--tag ${IMAGE_NAME} \
		.
	if [ "${LOAD_TO_KIND}" = "true" ]; then \
		kind load docker-image ${IMAGE_NAME};\
	fi

.PHONY: push-example-$1-$2
push-example-$(1)-$(2):
	docker buildx build ${DOCKER_BUILD_ARGS} ${DOCKER_CACHE_ARGS} \
		--file ./examples/$1/$2/Dockerfile \
		--tag ${EXAMPLE_IMAGE}-$1-$2:${STAGINGVERSION} \
		--tag ${EXAMPLE_IMAGE}-$1-$2:latest \
		--builder ${BUILDX_BUILDER} \
		--platform linux/amd64,linux/arm64 .
endef

$(eval $(call example-template,proxy,mountpoint-s3))
$(eval $(call example-template,proxy,goofys))
$(eval $(call example-template,proxy,s3fs))
$(eval $(call example-template,proxy,ros3fs))
$(eval $(call example-template,proxy,gcsfuse))
$(eval $(call example-template,proxy,sshfs))
$(eval $(call example-template,starter,ros3fs))
$(eval $(call example-template,starter,sshfs))


.PHONY: build-examples
build-examples: $(BUILD_EXAMPLES)

.PHONY: push-examples
push-examples: $(PUSH_EXAMPLES)

define test-example-template
ifneq ("$(EXAMPLE_TESTS)", "")
EXAMPLE_TESTS += test-example-$(1)-$(2)
else
EXAMPLE_TESTS := test-example-$(1)-$(2)
endif

.PHONY: test-example-$1-$2
test-example-$(1)-$(2):
	./examples/check.sh ./$1/$2 mfcp-example-$1-$2 $3 $4 $5 $6
endef

$(eval $(call test-example-template,proxy,mountpoint-s3,starter,/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,proxy,goofys,starter,/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,proxy,s3fs,starter,/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,proxy,ros3fs,starter,/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,proxy,sshfs,starter,/root/sshfs-example/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,starter,ros3fs,starter,/test.txt,busybox,/data/test.txt))
$(eval $(call test-example-template,starter,sshfs,starter,/root/sshfs-example/test.txt,busybox,/data/test.txt))

.PHONY: test-examples
test-examples: $(EXAMPLE_TESTS)

.PHONY: test-e2e
test-e2e:
	- kind delete cluster
	kind create cluster
	./test_e2e.sh
