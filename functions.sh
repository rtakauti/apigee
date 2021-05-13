#!/usr/bin/env bash

for file in "$ROOT_DIR"/functions/*.sh; do
  source "$file"
done
#source "$ROOT_DIR/functions/01_basics.sh"
#source "$ROOT_DIR/functions/02_requests.sh"
#source "$ROOT_DIR/functions/03_mass.sh"
#source "$ROOT_DIR/functions/git.sh"
