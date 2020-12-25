# Apigee Client

It is possible to run on git bash, linux terminal and mac terminal.

## Installation

To install it is necessary to:

1. install jq for windows, linux or mac
1. install 7zip for windows, linux or mac
1. install dos2unix for linux
1. rename `env_var1.sh` to `env_var.sh`
1. Edit `env_var.sh` with data from the Apigee account and path

## How to use

### To make backup of all components
>`cd apigee` to the root folder
> 
>`./backup_apigee.sh` to generate all backups
### To make backup of individual components ex.: company
>`cd apigee/companies` to the companies folder
> 
>`./backup_companies.sh` to generate companies' backup

### To generate zip bundles from swagger file
>Copy your swagger files in `.json` format into swaggers folder
> 
> `cd apigee` to the root folder
> 
>`./create_bundles.sh` to generate bundles from swagger