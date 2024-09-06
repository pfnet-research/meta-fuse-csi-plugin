FROM golang:1.20.7 as fuse-starter-builder

WORKDIR /meta-fuse-csi-plugin
ADD . .
RUN make fuse-starter BINDIR=/bin

FROM ubuntu:22.04
ARG TARGETARCH

RUN apt update && apt upgrade -y
RUN apt install -y ca-certificates wget libfuse2 fuse3

# install sshfs
RUN apt install -y sshfs

# thanks to https://docs.docker.jp/engine/examples/running_ssh_service.html
RUN apt install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:screencast' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
RUN ssh-keygen -f /root/.ssh/example -P ""
RUN cat /root/.ssh/example.pub > /root/.ssh/authorized_keys

COPY <<EOF /root/.ssh/config
Host *
    StrictHostKeyChecking no

Host localhost
    User root
    IdentityFile /root/.ssh/example
EOF

RUN mkdir -p /root/sshfs-example/subdir
RUN echo "This file is an example for sshfs" > /root/sshfs-example/subdir/test.txt

COPY <<EOF /entrypoint.sh
#!/bin/bash

/usr/sbin/sshd -D &
sleep 1

/mfcp-bin/fuse-starter --fd-passing-socket-path /fuse-fd-passing/fuse-csi-ephemeral.sock -- /usr/bin/sshfs root@localhost:/root/sshfs-example /dev/fd/3 -f &

wait -n
exit $?
EOF

RUN chmod +x /entrypoint.sh

RUN mkdir /mfcp-bin
COPY --from=fuse-starter-builder /bin/fuse-starter /mfcp-bin/fuse-starter

CMD ["/entrypoint.sh"]
