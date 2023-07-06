#!/bin/bash
set -e
TOP_DIR=$(cd $(dirname "$0") && pwd)

# configurations
RESULT_DIR="$TOP_DIR/results"
BUILD_DIR="/home/srq/ceph/build/"
FIO_CONF="/home/srq/ceph/rbd_write.fio"
POOL_NAME="rbd"
POOL_NUM=128
TOTAL_ROUND=3
IMAG_NAME="fio_test"

# Note: currently only support single OSD to measure write amplification
# correctly.
if [ -e $RESULT_DIR ]; then
  echo "'$RESULT_DIR' dir already exists, remove it or select a different one"
  exit 1
fi

mkdir -p $RESULT_DIR
cd $BUILD_DIR
CURRENT_ROUND=0
TARGET_ROUND=$(( CURRENT_ROUND + TOTAL_ROUND ))

CEPH_DEV=1 ./bin/ceph osd pool create $POOL_NAME $POOL_NUM $POOL_NUM
CEPH_DEV=1 ./bin/ceph osd pool set --yes-i-really-mean-it $POOL_NAME size 1 && ./bin/ceph osd pool --yes-i-really-mean-it set $POOL_NAME  min_size 1
CEPH_DEV=1 ./bin/rbd create $IMAG_NAME --size 2G --image-format=2 --rbd_default_features=3

CEPH_DEV=1 ./bin/ceph tell osd.0 dump_metrics | tee $RESULT_DIR/result_${CURRENT_ROUND}_metrics.log 
while [ $CURRENT_ROUND -lt $TARGET_ROUND ]
do
  (( ++CURRENT_ROUND ))
  echo "start round $CURRENT_ROUND ..."
  CEPH_DEV=1 fio $FIO_CONF --output=$RESULT_DIR/result_${CURRENT_ROUND}_bench.log
  CEPH_DEV=1 ./bin/ceph tell osd.0 dump_metrics | tee $RESULT_DIR/result_${CURRENT_ROUND}_metrics.log 
  echo "finish round $CURRENT_ROUND"
  echo
  sleep 2
done
echo "done!"
cd $TOP_DIR
