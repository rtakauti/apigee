#!/usr/bin/env bash

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
export DATE
MASS=true

source env_var.sh
source functions/basic.sh
source functions.sh

discover
makeDir
mass
compress
