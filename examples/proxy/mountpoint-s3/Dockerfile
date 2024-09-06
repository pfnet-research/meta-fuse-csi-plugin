FROM golang:1.20.7 as fusermount3-proxy-builder

WORKDIR /meta-fuse-csi-plugin
ADD . .
RUN make fusermount3-proxy BINDIR=/bin

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

RUN if [ "$TARGETARCH" = "amd64" ]; then TARGETARCH=x86_64; fi && wget https://s3.amazonaws.com/mountpoint-s3-release/latest/${TARGETARCH}/mount-s3.deb -O mount-s3.deb && dpkg -i mount-s3.deb

COPY --from=fusermount3-proxy-builder /bin/fusermount3-proxy /bin/fusermount3
RUN ln -sf /bin/fusermount3 /bin/fusermount
