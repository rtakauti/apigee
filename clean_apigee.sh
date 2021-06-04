#!/usr/bin/env bash

source env_var.sh
source functions.sh

setActivity
export ACTIVITY
rm -rf ./backup/*
rm -rf ./report/*
rm -rf ./bundles/*
rm -rf ./zips/*.zip
rm -rf ./revisions/*
rm -rf ./uploads/*
mass