#!/usr/bin/env bash

for file in "$ROOT_DIR"/functions/*.sh; do
  source "$file"
done
