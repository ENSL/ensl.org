#!/usr/bin/env bash

# use source script/env.sh

args=("$@")

if [[ $# -eq 0 ]]; then
  args+=(.env)
fi

for FILE in "${args[@]}"
do
  # Check if file exists
  if [ ! -f "$FILE" ]; then 
    continue
  fi
  
  echo "Loading env vars from: $FILE"
  set -a
  # shellcheck disable=SC1090
  . "$FILE"
  set +a
  grep -vE '^[[:space:]]*(#.*)*$' "$FILE"
  echo
done

