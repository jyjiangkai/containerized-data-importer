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


dnf install -y libnbd-devel nbdkit-devel


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
elif [ "${target}" = "cdi-uploadserver" ]; then
    # sudo dnf install libnbd-devel.x86_64
    wegt http://mirrors.163.com/fedora/updates/33/Everything/x86_64/Packages/l/libnbd-1.6.5-1.fc33.x86_64.rpm -O /tmp/libnbd-1.6.5-1.fc33.x86_64.rpm
    wegt http://mirrors.163.com/fedora/updates/33/Everything/x86_64/Packages/q/qemu-img-5.1.0-9.fc33.x86_64.rpm -O /tmp/qemu-img-5.1.0-9.fc33.x86_64.rpm
    wegt http://mirrors.163.com/fedora/updates/33/Everything/x86_64/Packages/x/xen-libs-4.14.3-2.fc33.x86_64.rpm -O /tmp/xen-libs-4.14.3-2.fc33.x86_64.rpm
    wegt https://mirrors.tuna.tsinghua.edu.cn/fedora/releases/33/Everything/x86_64/os/Packages/l/libaio-0.3.111-10.fc33.x86_64.rpm -O /tmp/libaio-0.3.111-10.fc33.x86_64.rpm
    wegt https://mirrors.tuna.tsinghua.edu.cn/fedora/releases/33/Everything/x86_64/os/Packages/c/capstone-4.0.2-3.fc33.x86_64.rpm -O /tmp/capstone-4.0.2-3.fc33.x86_64.rpm
    wegt http://mirrors.163.com/fedora/updates/33/Everything/x86_64/Packages/l/liburing-0.7-3.fc33.x86_64.rpm -O /tmp/liburing-0.7-3.fc33.x86_64.rpm
    rpm -ivh /tmp/libnbd-1.6.5-1.fc33.x86_64.rpm
    rpm -ivh /tmp/qemu-img-5.1.0-9.fc33.x86_64.rpm
    rpm -ivh /tmp/xen-libs-4.14.3-2.fc33.x86_64.rpm
    rpm -ivh /tmp/libaio-0.3.111-10.fc33.x86_64.rpm
    rpm -ivh /tmp/capstone-4.0.2-3.fc33.x86_64.rpm
    rpm -ivh /tmp/liburing-0.7-3.fc33.x86_64.rpm
fi


# always build and link the binary based on CPU Architecture
LINUX_NAME=${BIN_NAME}-linux-${ARCH}

go vet ./cmd/${target}/...
cd cmd/${target}

echo "building dynamic binary $BIN_NAME"
GOOS=linux GOARCH=${ARCH} go build -tags selinux -o ${OUTPUT_DIR}/${LINUX_NAME} -ldflags '-extldflags "static"' -ldflags "$(cdi::version::ldflags)"

(cd ${OUTPUT_DIR} && ln -sf ${LINUX_NAME} ${BIN_NAME})