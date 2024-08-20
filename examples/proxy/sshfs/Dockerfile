FROM golang:1.20.7 as fusermount3-proxy-builder

WORKDIR /meta-fuse-csi-plugin
ADD . .
RUN make fusermount3-proxy BINDIR=/bin

FROM ubuntu:22.04

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

RUN mkdir /root/sshfs-example
RUN echo "This file is an example for sshfs" > /root/sshfs-example/test.txt

COPY <<EOF /entrypoint.sh
#!/bin/bash

/usr/sbin/sshd -D &
sleep 1

touch /dev/fuse # This allows libfuse to use fusermount3. Its detail is described in README.md
/usr/bin/sshfs root@localhost:/root/sshfs-example /tmp -f &

wait -n
exit $?
EOF

RUN chmod +x /entrypoint.sh

COPY --from=fusermount3-proxy-builder /bin/fusermount3-proxy /bin/fusermount3
RUN ln -sf /bin/fusermount3 /bin/fusermount

CMD ["/entrypoint.sh"]
