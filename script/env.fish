#!/usr/bin/fish
# use source script/env.fish

if test (count $argv) = 0
  set -a argv ".env"
end

for FILE in $argv
  if not test -f "$FILE"
    continue
  end

  echo "Loading and EXPORTING env vars from: $FILE"
  echo "---"
  while read -l ARG
    if string match -qr '^\s*(#|$)' -- "$ARG"
      continue
    end

    set PAIR (string split -m 1 '=' -- "$ARG")
    set KEY $PAIR[1]
    set VAL $PAIR[2]
    printf "%-30s %-30s\n" $KEY $VAL
    set -gx $KEY "$VAL"
  end < "$FILE"
  echo
end