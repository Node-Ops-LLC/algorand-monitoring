#!/bin/bash

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-
#
# Installs monitoring tools for Algorand node runners: Prometheus, Node Exporter, Grafana, and dashboards
# Tested on Ubuntu 20.04.5 LTS - compatibility with other operating systems has not been verified
# REF: https://github.com/ava-labs/avalanche-monitoring/blob/main/grafana/monitoring-installer.sh
# REF: https://linuxopsys.com/topics/install-prometheus-on-ubuntu 
# Support: https://discord.gg/algorand # node runners
#
#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Stop on errors
set -e

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Prints usage information
usage () {

  echo "Usage: $0 [--1|--2|--3|--4|--help]"
  echo ""
  echo "Options:"
  echo "   --help   Shows this message"
  echo "   --1      Step 1: Installs Prometheus"
  echo "   --2      Step 2: Installs Node Exporter"
  echo "   --3      Step 3: Installs Grafana"
  echo "   --4      Step 4: Installs Algorand dashboards"
  echo ""
  echo "When run without any options, this script will download and install the latest version of the Algorand dashboards."

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Checks for presence of required commands, and attempts to install them if missing
check_reqs () {

  # Check for curl
  if ! command -v curl &> /dev/null; then # If curl is not found...
    echo "curl could not be found, attempting to install..."
    sudo apt-get install curl -y
  fi
  
  # Check for wget
  if ! command -v wget &> /dev/null; then # If wget is not found...
    echo "wget could not be found, attempting to install..."
    sudo apt-get install wget -y
  fi

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Checks for supported environments
get_environment() {

  # Check system requirements
  check_reqs
  
  # Get operating environment
  foundArch="$(uname -m)" # Get system architecture
  foundOS="$(uname)" # Get OS
  
  # Check operating system compatibility
  if [ "$foundOS" != "Linux" ]; then
    echo "Unsupported operating system: $foundOS!"
    echo "Exiting."
    exit
  fi
  
  # Check system architecture compatibility
  if [ "$foundArch" = "aarch64" ]; then
    getArch="arm64" # Running on arm arch (probably RasPi)
  elif [ "$foundArch" = "x86_64" ]; then
    getArch="amd64" # Running on intel/amd
  else
    echo "Unsupported architecture: $foundArch!"
    echo "Exiting."
    exit
  fi

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs Prometheus
install_prometheus() {

  # Print header
  echo "";
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Prometheus";
  echo "";

  # Get the latest release
  promFileName="$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep -o "http.*linux-${getArch}\.tar\.gz")"
  if [[ $(wget -S --spider "${promFileName}"  2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
    echo "Prometheus install archive found: $promFileName"
  else
    echo "Unable to find Prometheus install archive. Exiting."
    exit
  fi

  # Download and extract the latest release
  echo "Attempting to download: ${promFileName}"
  wget -nv --show-progress -O prometheus.tar.gz "${promFileName}"
  sudo mkdir -pm744 prometheus
  tar -xvf prometheus.tar.gz -C prometheus --strip-components=1
  cd prometheus

  # Add group, user and directories
  sudo groupadd --system prometheus
  sudo useradd -s /sbin/nologin -M --system -g prometheus prometheus
  sudo mkdir -pm744 /etc/prometheus /var/lib/prometheus

  # Move files to target directories and apply permissions
  sudo cp {prometheus,promtool} /usr/local/bin/
  sudo cp -r {consoles,console_libraries} /etc/prometheus/
  sudo cp prometheus.yml /etc/prometheus/
  sudo chown -R prometheus:prometheus /etc/prometheus/ /var/lib/prometheus/ /usr/local/bin/{prometheus,promtool}
  sudo chmod -R 744 /etc/prometheus/ /var/lib/prometheus/ /usr/local/bin/{prometheus,promtool}

  # Create the service file
  echo "Creating the service file"
  {
    echo "[Unit]"
    echo "Description=Prometheus"
    echo "Documentation=https://prometheus.io/docs/introduction/overview/"
    echo "Wants=network-online.target"
    echo "After=network-online.target"
    echo ""
    echo "[Service]"
    echo "Type=simple"
    echo "Restart=always"
    echo "User=prometheus"
    echo "Group=prometheus"
    echo "SyslogIdentifier=prometheus"
    echo "ExecReload=/bin/kill -HUP \${MAINPID}"
    echo "ExecStart=/usr/local/bin/prometheus \\"
    echo "  --config.file=/etc/prometheus/prometheus.yml \\" # Configuration file location
    echo "  --storage.tsdb.path=/var/lib/prometheus/ \\" # Database storage location
    echo "  --storage.tsdb.retention.size=100GB \\" # Configure this limit as desired
    echo "  --storage.tsdb.retention.time=120d \\" # Configure this limit as desired
    echo "  --web.console.templates=/etc/prometheus/consoles \\"
    echo "  --web.console.libraries=/etc/prometheus/console_libraries \\"
    echo "  --web.listen-address=0.0.0.0:9090 \\" # Query interface
    echo "  --web.external-url=http://localhost:9090/prometheus \\" # To secure from external access, leave the port closed
    echo "  --web.route-prefix=/prometheus"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } > prometheus.service

  # Initialize the service
  sudo cp prometheus.service /etc/systemd/system/prometheus.service
  sudo systemctl daemon-reload
  sudo systemctl start prometheus
  sudo systemctl enable prometheus
  cd ..

  # Print footer
  echo ""
  echo "Prometheus is installed!"
  echo ""
  echo "Please verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status prometheus"
  echo ""
  echo "You can query the database using this endpoint:"
  echo "  http://your-node-host-ip:9090/"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

  exit 0
  
}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Checks the operating environment
get_environment

# Checks input arguments
if [ $# -ne 0 ]; then
  case $1 in
    --1) # Install Prometheus
      install_prometheus
      exit 0
      ;;
    --2) # Install Node Exporter
      install_node_exporter
      exit 0
      ;;
    --3) # Install Grafana
      install_grafana
      exit 0
      ;;
    --4) # Install Algorand dashboards
      install_dashboards
      exit 0
      ;;
    --help) # Print usage
      usage
      exit 0
      ;;
  esac
fi

# Performs the default action if no input is supplied
install_dashboards

exit 0
