#!/usr/bin/env bash

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
export DATE

source ./env_var.sh
source ./functions.sh

makeDir
mass
compress
