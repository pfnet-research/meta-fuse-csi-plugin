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

	driver "github.com/pfnet-research/meta-fuse-csi-plugin/pkg/csi_driver"
	csimounter "github.com/pfnet-research/meta-fuse-csi-plugin/pkg/csi_mounter"
	"k8s.io/klog/v2"
	"k8s.io/mount-utils"
)

var (
	endpoint = flag.String("endpoint", "unix:/tmp/csi.sock", "CSI endpoint")
	nodeID   = flag.String("nodeid", "", "node id")

	// These are set at compile time.
	version   = "unknown"
	builddate = "unknown"
)

func main() {
	klog.InitFlags(nil)
	flag.Parse()

	var err error
	var mounter mount.Interface
	if *nodeID == "" {
		klog.Fatalf("NodeID cannot be empty for node service")
	}

	mounter, err = csimounter.New("")
	if err != nil {
		klog.Fatalf("Failed to prepare CSI mounter: %v", err)
	}

	config := &driver.DriverConfig{
		Name:    driver.DefaultName,
		Version: version,
		NodeID:  *nodeID,
		Mounter: mounter,
	}

	d, err := driver.NewDriver(config)
	if err != nil {
		klog.Fatalf("Failed to initialize meta-fuse-csi-plugin: %v", err)
	}

	klog.Infof("Running meta-fuse-csi-plugin version %v (BuildDate %v)", version, builddate)
	d.Run(*endpoint)

	os.Exit(0)
}
