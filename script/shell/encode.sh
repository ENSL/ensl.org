#!/bin/bash

FILE=`echo -n $1 | sed -e 's/\.\w\{3\}$//gi'`

if [ -e "$FILE"_preview.mp4 ]; then
	exit 0
fi

ffmpeg -i "$1" -ar 44100 -ab 96k -vcodec libx264 -level 41 -crf 25 -bufsize 20000k -maxrate 2500k -g 250 -r 20 -s 640x480 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -flags2 +brdo+dct8x8+bpyramid -me umh -subq 7 -me_range 16 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -rc_eq 'blurCplx^(1-qComp)' -bf 16 -b_strategy 1 -bidir_refine 1 -refs 6 -deblockalpha 0 -deblockbeta 0 "$FILE"_preview.mp4
