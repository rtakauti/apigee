#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../environments.sh

for ENV in ${ENVS[*]}; do
  makeDir
  create "environments/$ENV/$CONTEXT"
  copy
done
compress
