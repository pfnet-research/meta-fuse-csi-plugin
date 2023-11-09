/*
Copyright 2018 The Kubernetes Authors.
Copyright 2022 Google LLC
Copyright 2023 Preferred Networks, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"os"
	"os/signal"
	"sync"
	"syscall"

	starter "github.com/pfnet-research/meta-fuse-csi-plugin/pkg/fuse_starter"
	"k8s.io/klog/v2"
)

var (
	fdPassingSocketPath = flag.String("fd-passing-socket-path", "", "unix domain socket path for FUSE fd passing")
	// This is set at compile time.
	version   = "unknown"
	builddate = "unknown"
)

func main() {
	klog.InitFlags(nil)
	flag.Parse()

	klog.Infof("Running meta-fuse-csi-plugin fuse-starter version %v (BuildDate %v)", version, builddate)
	klog.Infof("fd-passing-socket-path: %q", *fdPassingSocketPath)

	// parsing command args after "--"
	mounterArgsIdx := 0
	for ; mounterArgsIdx < len(os.Args); mounterArgsIdx += 1 {
		if os.Args[mounterArgsIdx] == "--" {
			mounterArgsIdx += 1
			break
		}
	}

	if len(os.Args) == mounterArgsIdx {
		klog.Error("mounter does not specified")
		return
	}

	mounterPath := os.Args[mounterArgsIdx]
	mounterArgs := os.Args[mounterArgsIdx+1:]
	klog.Infof("mounter(%s) args are %v", mounterPath, mounterArgs)

	if *fdPassingSocketPath == "" {
		klog.Error("fd-passing-socket-path does not specified")
		return
	}

	mounter := starter.New(mounterPath, mounterArgs)
	var wg sync.WaitGroup

	mc, err := starter.PrepareMountConfig(*fdPassingSocketPath)
	if err != nil {
		klog.Errorf("failed prepare mount config: socket path %q: %v\n", *fdPassingSocketPath, err)
		return
	}

	c := make(chan os.Signal, 1)

	wg.Add(1)
	go func(mc *starter.MountConfig) {
		defer wg.Done()
		cmd, err := mounter.Mount(mc)
		if err != nil {
			klog.Errorf("failed to mount volume %q: %v\n", mc.VolumeName, err)
			return
		}

		if err = cmd.Start(); err != nil {
			klog.Errorf("failed to start mounter with error: %v\n", err)
			return
		}

		// Since the mounter has taken over the file descriptor,
		// closing the file descriptor to avoid other process forking it.
		syscall.Close(mc.FileDescriptor)
		if err = cmd.Wait(); err != nil {
			klog.Errorf("mounter exited with error: %v\n", err)
		} else {
			klog.Infof("[%v] mounter exited normally.", mc.VolumeName)
		}

		// Process may exit early.
		c <- syscall.SIGTERM
	}(mc)

	signal.Notify(c, syscall.SIGTERM)
	klog.Info("waiting for SIGTERM signal...")

	<-c // blocking the process

	klog.Info("received SIGTERM signal, waiting for all the mounter processes exit...")

	// TODO: send SIGKILL to kill hang mounter process
	err = mounter.Cmd.Process.Signal(syscall.SIGTERM)
	if err != nil {
		klog.Warning("failed to send SIGTERM signal to mounter process")
	}
	wg.Wait()

	klog.Info("exiting fuse-starter...")
}
