#!/usr/bin/env bash

alias jq=/c/jq-win64.exe
#export makes the variable available to sub-processes.
export jq='/c/jq-win64.exe'
export zip='/c/7z.exe'
TEMP=$(mktemp)
export TEMP
TEMPO=$(mktemp)
export TEMPO
export USERNAME=email
export PASSWORD=password
export ORG=eval
export ENV
export SUFFIX
export URI
declare -a ARGUMENTS
export ARGUMENTS
export ROOT_DIR=/c/users/user/apigee
export URL=https://api.enterprise.apigee.com
export COMPANY='Test'
export DELETE='OFF'
export UPDATE='OFF'
export GIT='OFF'
export AUTH="$USERNAME:$PASSWORD"
if [[ -z $DATE ]]; then
    DATE=$(date +"%Y-%m-%d_%H-%M-%S")
    export DATE
fi
export PERIOD
export LIST
export REPO="git@github.com:user/repository"
