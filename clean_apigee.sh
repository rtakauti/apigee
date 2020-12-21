#!/usr/bin/env bash

source ./env_var.sh
source ./functions.sh

ACTIVITY="$(echo "${0##*/}" | cut -d'_' -f1)"
export ACTIVITY
rm -rf ./backup/*
rm -rf ./create/*
rm -rf ./recover/*
rm -rf ./bundles/*
rm -rf ./update/*
rm -rf ./change/*
rm -rf ./remove/*
rm -rf ./delete/*
rm -rf ./zips/*.zip
rm -rf ./revision/apis/*
rm -rf ./revision/sharedflows/*
mass