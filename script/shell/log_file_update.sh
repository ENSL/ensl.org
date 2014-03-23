#!/bin/bash

LIMIT=5985
a=4268

while [ "$a" -le $LIMIT ]
do
  wget -O /dev/null http://www.ensl.org/log_files/handle/"$a"
  let "a+=1"
done
