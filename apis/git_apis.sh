#!/usr/bin/env bash

source ../env_var.sh
source "$ROOT_DIR/functions.sh"
source "$ROOT_DIR/organizations.sh"
object="conciliation-v"

setContext
clone
#createSsh "$CONTEXT"
#json "$CONTEXT"
revision "$CONTEXT" "$object"
revisionZip "$CONTEXT" "$object"
