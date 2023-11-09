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

# Build fuse-starter go binary
FROM golang:1.20.7 as fuse-starter-builder

ARG STAGINGVERSION

WORKDIR /meta-fuse-csi-plugin
ADD . .
RUN make fuse-starter BINDIR=/bin

# go/gke-releasing-policies#base-images
# We use `gcr.io/distroless/base` because it includes glibc.
FROM gcr.io/distroless/base-debian11

# Copy the binaries
COPY --from=fuse-starter-builder /bin/fuse-starter /fuse-starter

ENTRYPOINT ["/meta-fuse-csi-plugin-fuse-starter"]
