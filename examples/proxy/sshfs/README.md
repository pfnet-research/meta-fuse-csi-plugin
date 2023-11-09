# fusermount3-proxy with sshfs

sshfs uses libfuse to handle FUSE operations.

libfuse uses fusermount3 only when it succeeded to open "/dev/fuse" and failed to mount FUSE due to EPERM.
The detail is shown in https://github.com/libfuse/libfuse/blob/05b696edb347dc555f937c1439ffda6a1c40416e/lib/mount.c#L523

To allow libfuse to fusermount3, touch /dev/fuse in a container as a workaround.
