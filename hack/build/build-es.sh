#!/usr/bin/env bash
#
# This file is part of the KubeVirt project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright 2017 Red Hat, Inc.
#

set -e

source hack/build/common.sh
source hack/build/config.sh
source hack/build/version.sh

if [ -z "$1" ]; then
    echo "invalid param, one parameter is required"
    exit 1
else
    target=$1
    shift
fi

if [ $# -eq 0 ]; then
    args=$binaries
    build_tests="true"
else
    args=$@
fi

PLATFORM=$(uname -m)
case ${PLATFORM} in
x86_64* | i?86_64* | amd64*)
    ARCH="amd64"
    ;;
aarch64* | arm64*)
    ARCH="arm64"
    ;;
*)
    echo "invalid Arch, only support x86_64 and aarch64"
    exit 1
    ;;
esac


# mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
# sed -i 's/\$releasever/7/g' /etc/yum.repos.d/CentOS-*.repo
# yum makecache

# yum install -y epel-release
# yum install -y dnf

dnf install -y wget cpio diffutils git python3-pip python3-devel mercurial gcc gcc-c++ glibc-devel findutils autoconf automake libtool jq rsync-daemon rsync patch libnbd-devel qemu-img xen-libs capstone nbdkit-devel unzip java-11-openjdk-devel btrfs-progs-devel device-mapper-devel --skip-broken


# handle binaries

eval "$(go env)"
BIN_NAME=${target}
OUTPUT_DIR=/usr/bin

if [ "${target}" = "cdi-cloner" ]; then
    cp cmd/cdi-cloner/cloner_startup.sh ${OUTPUT_DIR}
elif [ "${target}" = "cdi-importer" ]; then
    go build -a -o ${OUTPUT_DIR}/cdi-containerimage-server tools/cdi-containerimage-server/main.go && chmod +x ${OUTPUT_DIR}/cdi-containerimage-server
    go build -a -o ${OUTPUT_DIR}/cdi-source-update-poller tools/cdi-source-update-poller/main.go && chmod +x ${OUTPUT_DIR}/cdi-source-update-poller
elif [ "${target}" = "cdi-operator" ]; then
    go build -a -o ${OUTPUT_DIR}/csv-generator tools/csv-generator/csv-generator.go && chmod +x ${OUTPUT_DIR}/csv-generator
fi


# always build and link the binary based on CPU Architecture
LINUX_NAME=${BIN_NAME}-linux-${ARCH}

go vet ./cmd/${target}/...
cd cmd/${target}

echo "building dynamic binary $BIN_NAME"
GOOS=linux GOARCH=${ARCH} go build -tags selinux -o ${OUTPUT_DIR}/${LINUX_NAME}

(cd ${OUTPUT_DIR} && ln -sf ${LINUX_NAME} ${BIN_NAME})
