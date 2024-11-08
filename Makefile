# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Use bash explicitly in this Makefile to avoid unexpected platform
# incompatibilities among Linux distros.
#
SHELL := /bin/bash

VERSION ?= 1.0.1
KUSTOMIZE_VERSION := v4.5.4
IMAGE_NAME ?= quay.io/phantomjinx/camel-helloworld

#
# Situations when user wants to override
# the image name and version
# - used in kustomize install
# - used in making bundle
# - need to preserve original image and version as used in other files
#
CUSTOM_IMAGE ?= $(IMAGE_NAME)
CUSTOM_VERSION ?= $(VERSION)


MAKE := make --no-print-directory

default: build

docker:
ifeq (, $(shell command -v docker 2> /dev/null))
	$(error "No docker found in PATH. Please install docker and re-run")
else
MAVEN=$(shell command -v docker 2> /dev/null)
endif

build: docker
	@echo "####### Building $(IMAGE_NAME) ..."
	docker build -t $(CUSTOM_IMAGE):$(CUSTOM_VERSION) -f Dockerfile .

image-push:
	docker push $(CUSTOM_IMAGE):$(CUSTOM_VERSION)

.PHONY: docker build image-push

#
# Allows for resources to be loaded from outside the root location of
# the kustomize config file. Ensures that resource don't need to be
# copied around the file system.
#
# See https://kubectl.docs.kubernetes.io/faq/kustomize
#
KOPTIONS := --load-restrictor LoadRestrictionsNone

kubectl:
ifeq (, $(shell command -v kubectl 2> /dev/null))
	$(error "No kubectl found in PATH. Please install and re-run")
endif

kustomize:
ifeq (, $(shell command -v kustomize 2> /dev/null))
	$(error "No kustomize found in PATH. Please install and re-run")
else
KUSTOMIZE=$(shell command -v kustomize 2> /dev/null)
endif

#
# Vars that can be overridden by external env vars
#
DRY_RUN ?= false
NAMESPACE ?= hawtio-dev

# Cluster on which to install [ openshift | k8s ]
CLUSTER_TYPE ?= k8s

# Uninstall all hawtio-onlineresources: [true|false]
UNINSTALL_ALL ?= false

DEPLOY := deploy
PATCHES := patches
PLACEHOLDER := placeholder

#
# Macro for editing kustomization to define
# the image reference
#
# Parameter: directory of the kustomization.yaml
#
define set-kustomize-image
	$(if $(filter $(IMAGE_NAME),$(CUSTOM_IMAGE):$(CUSTOM_VERSION)),,\
		@cd $(1) || exit 1 && \
			$(KUSTOMIZE) edit set image $(IMAGE_NAME)=$(CUSTOM_IMAGE):$(CUSTOM_VERSION))
endef

#
# Macro for editing kustomization to define
# the namespace
#
# Parameter: directory of the kustomization.yaml
#
define set-kustomize-namespace
	@cd $(1) || exit 1 && \
		$(KUSTOMIZE) edit set namespace $(NAMESPACE)
endef

#
# Checks if the cluster user has the necessary privileges to be a cluster-admin
# In this case if the user can list the CRDs then probably a cluster-admin
#
check-admin: kubectl
	@output=$$(kubectl get crd 2>&1) || (echo "****" && echo "**** ERROR: Cannot continue as user is not a Cluster-Admin ****" && echo "****"; exit 1)

#---
#
#@ install
#
#== Install the deployment into the cluster
#
#=== Calls kustomize
#=== Calls kubectl
#
#* PARAMETERS:
#** CLUSTER_TYPE:        Set the cluster type to install on [ openshift | k8s ]
#** NAMESPACE:           Set the namespace for the resources
#** CUSTOM_IMAGE:        Set a custom image to install from
#** CUSTOM_VERSION:      Set a custom version to install from
#** DRY_RUN:             Print the resources to be applied instead of applying them [ true | false ]
#
#---
install: kustomize kubectl
# Set the namespace in the setup kustomization yaml
	@$(call set-kustomize-namespace, $(DEPLOY)/$(CLUSTER_TYPE))
# Set the image reference of the kustomization
	@$(call set-kustomize-image, $(DEPLOY)/$(CLUSTER_TYPE))
#
# Build the resources
# Either apply to the cluster or output to CLI
# Post-processes any remaining 'placeholder'
# that may remain, eg. in rolebindings
#
ifeq ($(DRY_RUN), false)
	@$(KUSTOMIZE) build $(KOPTIONS) $(DEPLOY)/$(CLUSTER_TYPE) | \
		sed 's/$(PLACEHOLDER)/$(NAMESPACE)/' | kubectl apply -f -
else
	@$(KUSTOMIZE) build $(KOPTIONS) $(DEPLOY)/$(CLUSTER_TYPE) | \
		sed 's/$(PLACEHOLDER)/$(NAMESPACE)/'
endif

#---
#
#@ uninstall
#
#== Uninstall the resources previously installed.
#
#=== Cluster-admin privileges are required.
#
#* PARAMETERS:
#** CLUSTER_TYPE:   Set the cluster type to install on [ openshift | k8s ]
#** NAMESPACE:      Set the namespace to uninstall the resources from
#** UNINSTALL_ALL:  Uninstall all Camel K resources including crds and cluster roles installed by setup-cluster [true|false]
#** DRY_RUN:        Print the resources to be applied instead of applying them [true|false]
#
#---
uninstall: kubectl kustomize
# Set the namespace in the all target kustomization yaml
	@$(call set-kustomize-namespace, $(DEPLOY)/$(CLUSTER_TYPE))
ifeq ($(DRY_RUN), false)
	@$(KUSTOMIZE) build $(KOPTIONS) $(DEPLOY)/$(CLUSTER_TYPE) | kubectl delete --ignore-not-found=true -f -
else
	@$(KUSTOMIZE) build $(KOPTIONS) $(DEPLOY)/$(CLUSTER_TYPE) | kubectl delete --dry-run=client -f -
endif

.DEFAULT_GOAL := help

help: ## Show this help screen.
	@awk 'BEGIN { printf "\nUsage: make \033[31m<PARAM1=val1 PARAM2=val2>\033[0m \033[36m<target>\033[0m\n"; printf "\nAvailable targets are:\n" } /^#@/ { printf "\033[36m%-15s\033[0m", $$2; subdesc=0; next } /^#===/ { printf "%-14s \033[32m%s\033[0m\n", " ", substr($$0, 5); subdesc=1; next } /^#==/ { printf "\033[0m%s\033[0m\n\n", substr($$0, 4); next } /^#\*\*/ { printf "%-14s \033[31m%s\033[0m\n", " ", substr($$0, 4); next } /^#\*/ && (subdesc == 1) { printf "\n"; next } /^#\-\-\-/ { printf "\n"; next }' $(MAKEFILE_LIST)



.PHONY: kubectl kustomize check-admin install uninstall help
