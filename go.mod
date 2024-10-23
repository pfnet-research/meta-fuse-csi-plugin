module github.com/pfnet-research/meta-fuse-csi-plugin

go 1.20

require (
	github.com/container-storage-interface/spec v1.8.0
	github.com/kubernetes-csi/csi-lib-utils v0.15.0
	github.com/spf13/pflag v1.0.5
	golang.org/x/net v0.23.0
	google.golang.org/grpc v1.57.1
	k8s.io/apimachinery v0.28.1
	k8s.io/klog/v2 v2.100.1
	k8s.io/mount-utils v0.28.1
)

require (
	github.com/go-logr/logr v1.2.4 // indirect
	github.com/golang/protobuf v1.5.3 // indirect
	github.com/moby/sys/mountinfo v0.6.2 // indirect
	golang.org/x/sys v0.18.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20230525234030-28d5490b6b19 // indirect
	google.golang.org/protobuf v1.30.0 // indirect
	k8s.io/utils v0.0.0-20230406110748-d93618cff8a2 // indirect
)
