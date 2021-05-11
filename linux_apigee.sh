#!/usr/bin/env bash

function dosUnix() {
  cd "$folder" || exit
  dos2unix ./*.* >/dev/null
  dos2unix ./* 2>/dev/null
  chmod +x ./*.sh 2>/dev/null
}

for folder in */; do
  (
    dosUnix &
    wait
  )
done
