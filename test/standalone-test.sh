#!/bin/bash

mkdir -p $HOME/tmp/bundle/rootfs/dev
mkdir -p /tmp/runu-root

. $(dirname "${BASH_SOURCE[0]}")/common.sh


fold_start test.0 "preparation test"
# get script from moby
curl https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh \
     -o /tmp/download-frozen-image-v2.sh

# get image runu-base
mkdir -p /tmp/runu
bash /tmp/download-frozen-image-v2.sh /tmp/runu/ thehajime/runu-base:$DOCKER_IMG_VERSION-$TRAVIS_OS_NAME

# extract images from layers
for layer in `find /tmp/runu -name layer.tar`
do
 tar xvfz $layer -C $HOME/tmp/bundle/rootfs
done

# sync /usr/lib for chrooted env
create_osx_chroot $HOME/tmp/bundle/rootfs/

# prepare RUNU_AUX_DIR
create_runu_aux_dir

rm -f config.json
runu spec

fold_end test.0

run_test()
{
    flag=$1

    sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root run --bundle=$HOME/tmp/bundle foo
    sleep 5
    if [ "$flag" != "immediate" ]; then
        sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root kill foo 9
    fi
    sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root delete foo
}

# test hello-world
fold_start test.1 "test hello"
cat config.json | jq '.process.args |=["hello"] ' > $HOME/tmp/bundle/config.json
run_test "immediate"
fold_end test.1

# test ping
fold_start test.2 "test ping"
cat config.json | jq '.process.args |=["ping", "-c5", "127.0.0.1"] ' > $HOME/tmp/bundle/config.json
run_test
fold_end test.2

# test python
fold_start test.3 "test python"
cat config.json | \
    jq '.process.args |=["python", "-c", "print(\"hello world from python(runu)\")"] ' | \
    jq '.process.env |= .+["LKL_ROOTFS=imgs/python.img", "RUMP_VERBOSE=1", "HOME=/", "PYTHONHOME=/python"]' > $HOME/tmp/bundle/config.json
run_test "immediate"
fold_end test.3

#test nginx
fold_start test.4 "test nginx"
cat config.json | \
    jq '.process.args |=["nginx"]' | \
    jq '.process.env |= .+["LKL_ROOTFS=imgs/data.iso"]' \
    > $HOME/tmp/bundle/config.json
RUMP_VERBOSE=1 run_test
fold_end test.4


if [ $TRAVIS_OS_NAME != "linux" ] ; then
    echo "alpine image test only supports on Linux host. Skipped"
    exit 0
fi

# download alpine image
fold_start test.0 "test alpine"
mkdir -p /tmp/alpine
mkdir -p $HOME/tmp/alpine/bundle/rootfs/dev
bash /tmp/download-frozen-image-v2.sh /tmp/alpine alpine:latest
for layer in `find /tmp/alpine -name layer.tar`
do
 tar xvfz $layer -C $HOME/tmp/alpine/bundle/rootfs
done

ls -lR $HOME/tmp/alpine/bundle/rootfs

# prepare RUNU_AUX_DIR
create_runu_aux_dir

run_test_alpine()
{
    flag=$1

    sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root run --bundle=$HOME/tmp/alpine/bundle foo
    sleep 5
    if [ "$flag" != "immediate" ]; then
        sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root kill foo 9
    fi
    sudo $GOPATH/bin/runu --debug --root=/tmp/runu-root delete foo
}

#test alpine
cat config.json | \
    jq '.process.args |=["ls", "-l", "/"]' | \
    jq '.process.env |= .+["RUNU_AUX_DIR='$RUNU_AUX_DIR'"]' \
    > $HOME/tmp/alpine/bundle/config.json
RUMP_VERBOSE=1 run_test_alpine "immediate"
fold_end test.0
