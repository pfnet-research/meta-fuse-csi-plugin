FROM ubuntu:22.04 as ros3fs-builder

RUN apt update && apt upgrade -y
RUN apt-get install -y cmake g++ git libfuse3-dev ninja-build zlib1g-dev libcurl4-openssl-dev libssl-dev ccache pkg-config
RUN git clone https://github.com/akawashiro/ros3fs.git
WORKDIR /ros3fs
RUN mkdir build
RUN ./build-aws-sdk-cpp.sh ./build
RUN cmake -S . -B build
RUN cmake --build build -- -j

FROM golang:1.20.7 as fuse-starter-builder

WORKDIR /meta-fuse-csi-plugin
ADD . .
RUN make fuse-starter BINDIR=/bin

FROM ubuntu:22.04
ARG TARGETARCH

RUN apt update && apt upgrade -y
RUN apt install -y ca-certificates wget libfuse2 fuse3

# prepare for MinIO
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc -O /usr/bin/mc && chmod +x /usr/bin/mc

COPY <<EOF /test.txt
This is a test file for minio
EOF

COPY <<EOF /configure_minio.sh
#!/bin/bash
set -eux
/usr/bin/mc alias set k8s-minio-dev http://localhost:9000 minioadmin minioadmin
/usr/bin/mc mb k8s-minio-dev/test-bucket
/usr/bin/mc cp /test.txt k8s-minio-dev/test-bucket/subdir/
EOF
RUN chmod +x /configure_minio.sh

RUN apt install -y libfuse3-dev ninja-build zlib1g-dev libcurl4-openssl-dev libssl-dev 

COPY --from=ros3fs-builder /ros3fs/build/ros3fs /ros3fs

RUN mkdir /mfcp-bin
COPY --from=fuse-starter-builder /bin/fuse-starter /mfcp-bin/fuse-starter
