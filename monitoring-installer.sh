#!/bin/bash

# Performs a multi-step installation of Prometheus, Node Exporter, Grafana, Algorand dashboards
# Intended to simplify monitoring tool installation for node runners
# Tested on Ubuntu 20.04.5 LTS - compatibility with other operating systems has not been verified
# REF: https://github.com/ava-labs/avalanche-monitoring/blob/main/grafana/monitoring-installer.sh
# REF: https://linuxopsys.com/topics/install-prometheus-on-ubuntu

# stop on errors
set -e

# helper function that prints usage
usage () {
  echo "Usage: $0 [--1|--2|--3|--4|--help]"
  echo ""
  echo "Options:"
  echo "   --help   Shows this message"
  echo "   --1      Step 1: Installs Prometheus"
  echo "   --2      Step 2: Installs Node Exporter"
  echo "   --3      Step 3: Installs Grafana"
  echo "   --4      Step 4: Installs Grafana dashboards for Algorand"
  echo ""
  echo "Run without any options, this script will download and install the latest version of the Grafana dashboards for Algorand."
}

# helper function to check for presence of required commands, and install if missing
check_reqs () {
  if ! command -v curl &> /dev/null
  then
      echo "curl could not be found, attempting to install..."
      sudo apt-get install curl -y
  fi
  if ! command -v wget &> /dev/null
  then
      echo "wget could not be found, attempting to install..."
      sudo apt-get install wget -y
  fi
}

# helper function to check for supported environment
get_environment() {
  check_reqs
  foundArch="$(uname -m)"                         # get system architecture
  foundOS="$(uname)"                              # get OS
  if [ "$foundOS" != "Linux" ]; then
    #sorry, don't know you.
    echo "Unsupported operating system: $foundOS!"
    echo "Exiting."
    exit
  fi
  if [ "$foundArch" = "aarch64" ]; then
    getArch="arm64"                               # running on arm arch (probably RasPi)
    # echo "Found arm64 architecture..."
  elif [ "$foundArch" = "x86_64" ]; then
    getArch="amd64"                               # running on intel/amd
    # echo "Found amd64 architecture..."
  else
    #sorry, don't know you.
    echo "Unsupported architecture: $foundArch!"
    echo "Exiting."
    exit
  fi
}

get_environment

if [ $# -ne 0 ] #arguments check
then
  case $1 in
    --1) #install prometheus
      install_prometheus
      exit 0
      ;;
    --2) #install node_exporter
      install_exporter
      exit 0
      ;;
    --3) #install grafana
      install_grafana
      exit 0
      ;;
    --4) #install Algorand dashboards
      install_dashboards
      exit 0
      ;;
    --help)
      usage
      exit 0
      ;;
  esac
fi

install_dashboards

exit 0
