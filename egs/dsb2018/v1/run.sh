#!/bin/bash

set -e # exit on error
. ./path.sh

stage=0

. parse_options.sh  # e.g. this parses the --stage option if supplied.


. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.

local/check_dependencies.sh


# train/validate split
train_prop=0.9
seed=0
if [ $stage -le 0 ]; then
  # data preparation
  local/prepare_data.sh --train_prop $train_prop --seed $seed
fi


epochs=120
depth=5
dir=exp/unet_${depth}_${epochs}_sgd
if [ $stage -le 1 ]; then
  # training
  local/run_unet.sh --dir $dir --epochs $epochs --depth $depth
fi

logdir=$dir/segment/log
nj=10
if [ $stage -le 2 ]; then
    echo "doing segmentation...."
  $cmd JOB=1:$nj $logdir/segment.JOB.log local/segment.py \
       --train-image-size 128 \
       --model model_best.pth.tar \
       --test-data data/stage1_test \
       --dir $dir/segment \
       --csv sub-dsbowl2018.csv \
       --job JOB --num-jobs $nj

fi

if [ $stage -le 3 ]; then
  echo "doing evaluation..."
  local/scoring.py \
    --ground-truth data/download/stage1_solution.csv \
    --predict $dir/segment/sub-dsbowl2018.csv \
    --result $dir/segment/result.txt
fi
