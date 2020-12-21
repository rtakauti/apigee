#!/usr/bin/env bash

source ./env_var.sh
source ./functions.sh

ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
export ACTIVITY

dos2unix ./*.*
mass
