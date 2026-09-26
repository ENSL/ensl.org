#!/usr/bin/fish
# use source script/env.fish [environment]

if test (count $argv) = 0
  set -a argv ".env"
else if test (count $argv) = 1; and not string match -q '.env*' -- "$argv[1]"
  set argv ".env" ".env.$argv[1]" ".env.local"
end

for FILE in $argv
  if not test -f "$FILE"
    continue
  end

  set ENV_LABEL (string replace -r '^.*\.env\.?' '' -- "$FILE")
  if test -z "$ENV_LABEL"
    set ENV_LABEL ENV
  end

  set ENV_LABEL (string upper -- "$ENV_LABEL")
  set ENV_COLOR (set_color brcyan)
  switch "$ENV_LABEL"
    case '*PRODUCTION*'
      set ENV_COLOR (set_color brred)
    case '*DEVELOPMENT*'
      set ENV_COLOR (set_color brgreen)
    case '*STAGING*'
      set ENV_COLOR (set_color bryellow)
    case '*TEST*'
      set ENV_COLOR (set_color brmagenta)
  end

  printf '%s(%s)%s Loading and exporting env vars from: %s\n' "$ENV_COLOR" "$ENV_LABEL" (set_color normal) "$FILE"
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

if set -q RAILS_ENV
  set -g ENV_FISH_PROMPT (string upper -- "$RAILS_ENV")
else if set -q RACK_ENV
  set -g ENV_FISH_PROMPT (string upper -- "$RACK_ENV")
end

if not functions -q __env_fish_original_prompt
  functions --copy fish_prompt __env_fish_original_prompt

  function fish_prompt
    if set -q ENV_FISH_PROMPT
      set prompt_color brcyan
      switch "$ENV_FISH_PROMPT"
        case '*PRODUCTION*'
          set prompt_color brred
        case '*DEVELOPMENT*'
          set prompt_color brgreen
        case '*STAGING*'
          set prompt_color bryellow
        case '*TEST*'
          set prompt_color brmagenta
      end

      set_color --bold $prompt_color
      printf '(%s) ' "$ENV_FISH_PROMPT"
      set_color normal
    end

    __env_fish_original_prompt
  end
end