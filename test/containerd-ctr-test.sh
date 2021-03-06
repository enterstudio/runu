#!/bin/bash

if [ $TRAVIS_OS_NAME != "osx" ] ; then
    echo "containerd and ctr runtime test only support with osx host. Skipped"
    exit 0
fi

. $(dirname "${BASH_SOURCE[0]}")/common.sh

# build custom containerd
fold_start test.containerd.0 "containerd build"
HOMEBREW_NO_AUTO_UPDATE=1 brew install libos-nuse/lkl/containerd
fold_end test.containerd.0 ""

# prepare containerd
fold_start test.containerd.0 "boot containerd"
curl https://gist.githubusercontent.com/thehajime/aba357f73da4e14bc3f5cbeb00aeaea4/raw/dde9af3f5ec40a3ec084064fd4baf0a26e09f51e/gistfile1.txt \
     -o /tmp/config.toml
containerd -l debug -c /tmp/config.toml &
sleep 3
killall containerd
sudo containerd -l debug -c /tmp/config.toml &
sleep 3
chmod 755 /tmp/ctrd
ls -lRa /tmp/ctrd
fold_end test.containerd.0 ""


# pull an image
fold_start test.containerd.0 "pull image"
ctr -a /tmp/ctrd/run/containerd/containerd.sock i pull docker.io/thehajime/runu-base:$DOCKER_IMG_VERSION
fold_end test.containerd.0 "pull image"

# test hello-world
fold_start test.containerd.1 "test hello"
ctr --debug -a /tmp/ctrd/run/containerd/containerd.sock \
    run --fifo-dir /tmp/ctrd --env RUMP_VERBOSE=1 \
    docker.io/thehajime/runu-base:$DOCKER_IMG_VERSION hello0 hello &
sleep 1
sudo killall -9 containerd-shim-v1-darwin | true
fold_end test.containerd.1

# test ping
fold_start test.containerd.2 "test ping"
ctr --debug -a /tmp/ctrd/run/containerd/containerd.sock \
    run --fifo-dir /tmp/ctrd --env RUMP_VERBOSE=1 \
    --env LKL_ROOTFS=imgs/python.iso \
    docker.io/thehajime/runu-base:$DOCKER_IMG_VERSION hello1 \
    ping -c5 127.0.0.1 &
sleep 6
sudo killall -9 containerd-shim-v1-darwin | true
fold_end test.containerd.2

# test python
fold_start test.containerd.3 "test python"
ctr --debug -a /tmp/ctrd/run/containerd/containerd.sock \
    run --fifo-dir /tmp/ctrd --env RUMP_VERBOSE=1 \
    --env HOME=/ --env PYTHONHOME=/python \
    --env LKL_ROOTFS=imgs/python.img \
    docker.io/thehajime/runu-base:$DOCKER_IMG_VERSION hello2 \
    python -c "print(\"hello world from python(docker-runu)\")" &
sleep 3
sudo killall -9 containerd-shim-v1-darwin | true
fold_end test.containerd.3

# test nginx
fold_start test.containerd.4 "test nginx"
ctr --debug -a /tmp/ctrd/run/containerd/containerd.sock \
    run --fifo-dir /tmp/ctrd --env RUMP_VERBOSE=1 \
    --env LKL_ROOTFS=imgs/data.iso \
    docker.io/thehajime/runu-base:$DOCKER_IMG_VERSION nginx1 \
    nginx &
sleep 3
sudo killall -9 containerd-shim-v1-darwin | true
fold_end test.containerd.4
