#!/usr/bin/env bash

alias jq=/c/jq-win64.exe

#export makes the variable available to sub-processes.
export jq='/c/jq-win64.exe'
export zip='/c/7z.exe'
TEMP=$(mktemp)
export TEMP
export USERNAME=email
export PASSWORD=password
export ORG=eval
export ENV=test
export ROOT_DIR=/c/users/user/apigee
export APIGEE=https://api.enterprise.apigee.com
export URL="$APIGEE/v1/organizations/$ORG"
export COMPANY="Test"
export DELETE="ON"
export AUTH="$USERNAME:$PASSWORD"
if [[ -z $DATE ]]; then
    DATE=$(date +"%Y-%m-%d_%H-%M-%S")
    export DATE
fi
export LIST
