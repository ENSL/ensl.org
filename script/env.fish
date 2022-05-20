#!/usr/bin/fish
# use source script/env.fish

if test (count $argv) = 0
  set -a argv ".env"
end

for FILE in $argv
  echo "Loading and EXPORTING env vars from: $FILE"
  echo "---"
  set ARGS (cat $FILE |grep -vE '^[[:space:]]*(#.*)*$')
  
  for ARG in $ARGS
    # echo $ARG
    set KEY (echo $ARG|sed -nr 's/(.*)=(.*)/\1/p')
    set VAL (echo $ARG|sed -nr 's/(.*)=(.*)/\2/p')
    printf "%-30s %-30s\n" $KEY $VAL
    set -x $KEY "$VAL"
  end
  echo
end