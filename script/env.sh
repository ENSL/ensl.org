#!/bin/bash
# use source script/env.sh

args=("$@")

if [[ $# -eq 1 ]]; then
  args+=(.env)
fi

for FILE in "$@"
do
  echo "Loading env vars from: $FILE"
  ARGS=$(cat $FILE |grep -vE '^[[:space:]]*(#.*)*$')

  export $(echo $ARGS|xargs)
  echo "$ARGS"
  echo
done

