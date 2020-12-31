#!/usr/bin/env bash

source ../functions.sh
source ../env_var.sh
source ../environments.sh

for ENV in ${ENVS[*]}; do
  makeDir
  delete "environments/$ENV/$CONTEXT"
  copy
done
compress
