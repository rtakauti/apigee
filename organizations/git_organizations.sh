#!/usr/bin/env bash

source ../env_var.sh
source ../functions.sh
source ../organizations.sh
source ../environments.sh

discover
ssh_create "$CONTEXT"
json "$CONTEXT"
