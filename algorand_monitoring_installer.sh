#!/bin/bash

<<~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

Installs Algorand Node Monitoring Tools:
	- Prometheus: a time-series database to store your metrics locally
	- Node Exporter: a set of collectors that gather information from your host computer - exposes a scrape target for Prometheus
	- Process Metrics Emitter: a script that emits "top" host process metrics, and that can be configured with a process watch list (TBD)
	- Algod Metrics Emitter: a script that emits metrics about the Algorand service to Node Exporter via the textfile collector
	- Push Gateway: a REST endpoint that allows intermittent event information to be scraped by Prometheus - optional (but useful)
	- Grafana: an open-source visualization tool that can organize, group and display information beautifully on a local or cloud interface
	- Algorand Monitoring Dashboard: a monitoring dashboard built for Algorand nodes that can be run locally or in Grafana cloud

References:
	- https://grafana.com/grafana/dashboards/1860-node-exporter-full/
	- https://github.com/ava-labs/avalanche-monitoring/blob/main/grafana/monitoring-installer.sh
	- https://linuxopsys.com/topics/install-prometheus-on-ubuntu 
	- https://devconnected.com/monitoring-linux-processes-using-prometheus-and-grafana/
	- https://medium.com/swlh/intro-to-server-monitoring-b782fc82911e

Support:
	- https://discord.gg/algorand # node runners
	- This script has been tested on Ubuntu 20.04 and 22.04 - compatibility with other operating systems has not been verified

~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

# Prints usage menu
usage () {

cat <<-//
	
	Usage: $0 [-1|-2|-3|-4|-5|-6|-help]
	
	Options:
	  -1: Install Prometheus
	  -2: Install Node Exporter
	  -3: Install Algod and Process Metrics Emitters
	  -4: Install Push Gateway
	  -5: Install Grafana
	  -6: Install Algorand dashboard
	
//

}

#~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

# Checks for required commands
check_requirements () {

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

	# Check for bc
	if ! command -v bc &> /dev/null; then # If bc is not found...
		echo "bc could not be found, attempting to install..."
		sudo apt-get install bc -y
	fi

}

#~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

# Checks for supported environments
check_environment() {

	# Check system requirements
	check_requirements

	# Get operating environment
	system_arch=$(uname -m) # Get system architecture
	system_os=$(uname) # Get OS

	# Check operating system compatibility
	if [ ${system_os} != "Linux" ]; then
		echo "Unsupported operating system: ${system_os}!"
		(exit 1)
	fi

	# Check system architecture compatibility
	if [ ${system_arch} = "aarch64" ]; then
		system_arch="arm64" # Running on arm arch (probably RasPi)
	elif [ ${system_arch} = "x86_64" ]; then
		system_arch="amd64" # Running on intel/amd
	else
		echo "Unsupported architecture: ${system_arch}!"
		(exit 1)
	fi

}

<< ~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

# Installs Prometheus
install_prometheus() {

  # Print header
  echo "";
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Prometheus";
  echo "";

  # Check if Prometheus is already installed
  if command -v  prometheus &> /dev/null; then
	 echo "Prometheus is already installed: $(command -v prometheus)"
	 (exit 1)
  fi

  # Get the latest release
  promFileName="$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep -o "http.*linux-${getArch}\.tar\.gz")"
  if [[ $(wget -S --spider "${promFileName}"  2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
	 echo "Prometheus install archive found: $promFileName"
  else
	 echo "Unable to find Prometheus install archive"
	 (exit 1)
  fi

  # Download and extract the latest release
  echo "Downloading: ${promFileName}"
  wget -nv --show-progress -O prometheus.tar.gz "${promFileName}"
  sudo mkdir -pm744 prometheus
  tar -xvf prometheus.tar.gz -C prometheus --strip-components=1
  cd prometheus

  # Add group, user and directories
  sudo groupadd --system prometheus
  sudo useradd -s /sbin/nologin -M --system -g prometheus prometheus
  sudo mkdir -pm744 /etc/prometheus /var/lib/prometheus

  # Modify the configuration file to scrape the Algod metrics endpoint
  # even if telemetry is not enabled, then 9101 will still work, and 9100 target will fail silently
  {
	 echo ""
	 echo "  - job_name: \"node-metrics\""
	 echo "    metrics_path: \"/metrics\""
	 echo "    honor_labels: true"
	 echo "    static_configs:"
	 echo "      - targets: [\"localhost:9100\", \"localhost:9101\"]"  # , \"localhost:9091\"]" # 2 node exporter, 1 push gateway
	 echo "        labels:"
	 echo "          host: \"$(hostname)\""
  } >> prometheus.yml

  # REF: https://utcc.utoronto.ca/~cks/space/blog/sysadmin/PrometheusAddHostnameLabel
  #relabel_configs:
  #- source_labels: [__address__]
  #  regex: (.*):9100
  #  replacement: $1
  #  target_label: cshost

  # Move files to target directories and apply permissions
  sudo cp {prometheus,promtool} /usr/local/bin/
  sudo cp -r {consoles,console_libraries,prometheus.yml} /etc/prometheus/
  sudo chown -R prometheus:prometheus /etc/prometheus/ /var/lib/prometheus/ /usr/local/bin/{prometheus,promtool}
  sudo chmod -R 744 /etc/prometheus/ /var/lib/prometheus/ /usr/local/bin/{prometheus,promtool}

  # Create the service file
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
	 echo "  --web.external-url=http://localhost:9090 \\" # To secure from external access, leave the port closed
	 echo "  --web.route-prefix=/ \\"
#    echo "  --enable-feature=expand-external-labels" # REF: https://promlabs.com/blog/2021/05/16/whats-new-in-prometheus-2-27 # didn't seem to work anyway, maybe try some other time
	 echo ""
	 echo "[Install]"
	 echo "WantedBy=multi-user.target"
  } > prometheus.service

  # Configure top command...
  # REF: https://superuser.com/questions/1052688/how-to-choose-columns-for-top-command-in-batch-mode
  echo "Configuring top command for process metrics..."
  # home_dir="/etc/prometheus/top" # ~/.config/procps/toprc
  config_file_dir="~/.config/procps"
  sudo mkdir -pm744 ${config_file_dir}
  # get the config file from GitHub
  wget -nd -m -nv https://raw.githubusercontent.com/node-ops-llc/algorand-monitoring/main/toprc
  sudo mv toprc ${config_file_dir}
  sudo chown -R prometheus:prometheus ${config_file_dir}

  # Initialize the service
  echo "Initializing service"
  sudo cp prometheus.service /etc/systemd/system/prometheus.service
  sudo systemctl daemon-reload
  sudo systemctl start prometheus
  sudo systemctl enable prometheus
  cd ..

  # Print footer
  echo ""
  echo "Prometheus is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status prometheus"
  echo ""
  echo "Query the database using this endpoint:"
  echo "  http://<your-host-ip>:9090"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs Node Exporter
install_node_exporter() {

  # Print header
  echo;
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Node Exporter";
  echo;

  # Check if Node Exporter is already installed
  # if command -v  node_exporter &> /dev/null; then
  # echo "Node Exporter is already installed: $(command -v node_exporter)"
  # (exit 1)
  # fi # This should be implemented, but the default Algod install includes node_exporter in /usr/bin/ as part of the managed package
  # This would instead need to check for node_exporter in path /usr/local/bin/

  # Get the latest release
  nodeExFileName="$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep -o "http.*linux-${getArch}\.tar\.gz")"
  if [[ $(wget -S --spider "${nodeExFileName}"  2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
	 echo "Node Exporter install archive found: $nodeExFileName"
  else
	 echo "Unable to find Node Exporter install archive"
	 (exit 1)
  fi
  
  # Download and extract the latest release
  echo "Downloading: ${nodeExFileName}"
  wget -nv --show-progress -O node_exporter.tar.gz "${nodeExFileName}"
  sudo mkdir -pm744 node_exporter
  tar -xvf node_exporter.tar.gz -C node_exporter --strip-components=1
  cd node_exporter

  # Add directory
  sudo mkdir -pm744 /etc/prometheus/node_exporter/collector_textfile

  # Move files to target directories and apply permissions
  sudo cp node_exporter /usr/local/bin
  sudo chown -R prometheus:prometheus /usr/local/bin/node_exporter /etc/prometheus/
  sudo chmod -R 744 /usr/local/bin/node_exporter /etc/prometheus/

  # Create the service file
  # REF: https://github.com/prometheus/node_exporter#node-exporter
  {
	 echo "[Unit]"
	 echo "Description=Prometheus Node Exporter"
	 echo "Documentation=https://github.com/prometheus/node_exporter"
	 echo "Wants=network-online.target"
	 echo "After=network-online.target"
	 echo ""
	 echo "[Service]"
	 echo "Type=simple"
	 echo "Restart=always"
	 echo "User=prometheus"
	 echo "Group=prometheus"
	 echo "SyslogIdentifier=node_exporter"
	 echo "ExecReload=/bin/kill -HUP \$MAINPID"
	 echo "ExecStart=/usr/local/bin/node_exporter \\"
	 echo "  --web.listen-address=:9101 \\" # Note: Algorand uses 9100 for its default metrics endpoint, so use 9101
	 echo "  --web.telemetry-path=\"/metrics\" \\"
	 echo "  --collector.disable-defaults \\"
	 echo "  --collector.textfile \\"
	 echo "  --collector.textfile.directory=/etc/prometheus/node_exporter/collector_textfile/ \\"
	 echo "  --collector.bonding \\" # starting from this entry down, we could eliminate everything that is duplicated on 9100 - but only if telemetry is enabled!
	 echo "  --collector.conntrack \\" # note: I never went through to determine which of these collectors is enabled for 9100, but it might be a good idea to eliminate the dups for performance and storage conservation...
	 echo "  --collector.cpu \\"
	 echo "  --collector.diskstats \\"
	 echo "  --collector.filefd \\"
	 echo "  --collector.filesystem \\"
	 echo "  --collector.hwmon \\"
	 echo "  --collector.loadavg \\"
	 echo "  --collector.mdadm \\"
	 echo "  --collector.meminfo \\"
	 echo "  --collector.netclass \\"
	 echo "  --collector.netdev \\"
	 echo "  --collector.netstat \\"
	 echo "  --collector.nvme \\"
	 echo "  --collector.os \\"
	 echo "  --collector.powersupplyclass \\"
	 echo "  --collector.processes \\"
	 echo "  --collector.systemd \\"
	 # echo "  --collector.thermal \\"
	 echo "  --collector.time \\"
	 echo "  --collector.uname \\"
	 echo "  --collector.vmstat \\"
	 echo "  --collector.zfs"
	 echo ""
	 echo "[Install]"
	 echo "WantedBy=multi-user.target"
  } > node_exporter.service
  
  # Initialize the service
  echo "Initializing service"
  sudo cp node_exporter.service /etc/systemd/system/node_exporter.service
  sudo systemctl daemon-reload
  sudo systemctl start node_exporter
  sudo systemctl enable node_exporter
  sudo systemctl restart prometheus

  cd ..

  # Print footer
  echo ""
  echo "Prometheus Node Exporter is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status node_exporter"
  echo ""
  echo "View metrics using this endpoint:"
  echo "  http://<your-host-ip>:9101/metrics"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""
  
}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs Metrics Emitters
install_algod_metrics_emitter() {

  # Print header
  echo;
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Algod Metrics Emitter";
  echo;

  # Confirm directory exists
  target_dir="/etc/prometheus/node_exporter"
  sudo mkdir -pm744 ${target_dir}/collector_textfile
  sudo chown -R prometheus:prometheus ${target_dir}
  cd node_exporter # this should already exist

  # Create the algod metrics emitter
  file_prefix="algod_metrics"
  metrics_emitter="${file_prefix}_emitter"

  # Create metrics emitter service file
  # REF: https://www.putorius.net/using-systemd-timers.html
  {
	 echo "[Unit]"
	 echo "Description=\"Runs the algod service metrics emitter, publishing custom metrics to be consumed by the Prometheus Node Exporter textfile collector\""
	 echo "Wants=network-online.target"
	 echo "After=network-online.target"
	 echo "After=algorand.service"
	 echo "Requires=algorand.service"
	 echo ""
	 echo "[Service]"
	 echo "SyslogIdentifier=${metrics_emitter}"	
	 echo "ExecStart=/bin/bash /etc/prometheus/node_exporter/${metrics_emitter}.sh"
  } > ${metrics_emitter}.service

  # Create the metrics emitter timer file
  {
	 echo "[Unit]"
	 echo "Description=\"Timer to run the algod service metrics emitter\""
	 echo ""
	 echo "[Timer]"
	 echo "Unit=${metrics_emitter}.service"
	 echo "OnCalendar=*:*:0/15" # run the target every 15 seconds
	 echo ""
	 echo "[Install]"
	 echo "WantedBy=timers.target"
  } > ${metrics_emitter}.timer

  # Move the service and timer files to systemd
  find . -name "${metrics_emitter}.*" -exec mv '{}' /etc/systemd/system/ \;  

  # Download the shell script from GitHub instead of trying to print it out from here, it's getting too complicated.
  wget -nd -m -nv https://raw.githubusercontent.com/node-ops-llc/algorand-monitoring/main/process_metrics_emitter.sh
  wget -nd -m -nv https://raw.githubusercontent.com/node-ops-llc/algorand-monitoring/main/algod_metrics_emitter.sh

  # Apply permissions and move script to target directory
  sudo chmod 774 *.sh
  sudo chown prometheus:prometheus *.sh
  sudo cp *.sh ${target_dir}

  # Create the process metrics emitter
#  file_prefix="process_metrics"
#  metrics_emitter="${file_prefix}_emitter"
#  target_dir="/etc/prometheus/push_gateway"
#  sudo mkdir -pm744 ${target_dir}

  # Create process metrics emitter service file
  # REF: https://www.putorius.net/using-systemd-timers.html
 # {
#    echo "[Unit]"
#    echo "Description=\"Runs the process metrics emitter, publishing top service metrics to be consumed by the Prometheus Push Gateway\""
#    echo "Wants=network-online.target"
#    echo "After=network-online.target"
#    echo ""
#    echo "[Service]"
#    echo "SyslogIdentifier=${metrics_emitter}"	
#    echo "ExecStart=/bin/bash ${target_dir}/${metrics_emitter}.sh"
#  } > ${metrics_emitter}.service

  # Create the process metrics emitter timer file
#  {
#    echo "[Unit]"
#    echo "Description=\"Timer to run the process metrics emitter\""
#    echo ""
#    echo "[Timer]"
#    echo "Unit=${metrics_emitter}.service"
#    echo "OnCalendar=*:*:0/15" # run the target every 15 seconds
#    echo ""
#    echo "[Install]"
#    echo "WantedBy=timers.target"
#  } > ${metrics_emitter}.timer

  # Move the service and timer files to systemd
#  find . -name "${metrics_emitter}.*" -exec mv '{}' /etc/systemd/system/ \;  
  
  # Apply permissions and move script to target directory
#  sudo chmod 774 *.sh
#  sudo cp ${metrics_emitter}.sh ${target_dir}
#  sudo chown -R prometheus:prometheus ${target_dir}

  # Initialize the service
  echo "Initializing custom metrics emitter"
  sudo systemctl daemon-reload
  sudo systemctl start ${metrics_emitter}.timer
  sudo systemctl enable ${metrics_emitter}.timer

  cd ..

  # Print footer
  echo ""
  echo "Algod Metrics Emitter for Node Exporter is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status algod_metrics_emitter"
  echo ""
  echo "View algod metrics using this endpoint:"
  echo "  http://<your-host-ip>:9101/metrics"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs Push Gateway
install_push_gateway() {

  # REF: https://github.com/prometheus/pushgateway
  # REF: https://utcc.utoronto.ca/~cks/space/blog/sysadmin/PrometheusPushgatewayDropMetrics
  # REF: https://devconnected.com/monitoring-linux-processes-using-prometheus-and-grafana/
  # REF: https://prometheus.io/docs/practices/pushing/
  # REF: https://www.metricfire.com/blog/prometheus-pushgateways-everything-you-need-to-know/
  # You can skip this install, it's not being used for now.

  # Example: https://github.com/prometheus/pushgateway
  # This is one reason why the Push Gateway is so nice - it is very simple to push metrics to the endpoint...
  # It also allows cached metrics to be deleted, and has other API functions - see the documentation
  # Metrics push to the gateway are never removed - the gateway should be used for oneshot or batch
  # programs that have metrics of their final results, and need to save that data - the information
  # sent to push gateway should always be true - for ephemeral data, use the textfile collector instead
  #
  # cat << EOF | curl -X PUT --data-binary @- http://localhost:9091/metrics/job/algod-metrics/alias/algod
  # TYPE algod_metric_example1 gauge
  # algod_metric_example1{label="val1"} 42
  # TYPE algod_metric_example2 gauge
  # HELP algod_metric_example2 Just an example.
  # algod_metric_example1 2398.283
  # EOF
  #

  # Print header
  echo "";
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Push Gateway";
  echo "";

  # Check if Push Gateway is already installed
  # if command -v  TKTK &> /dev/null; then
  #   echo "TKTK is already installed: $(command -v TKTK)"
  # (exit 1)
  # fi

  # Get the latest release
  pushGatewaytFileName="$(curl -s https://api.github.com/repos/prometheus/pushgateway/releases/latest | grep -o "http.*linux-${getArch}\.tar\.gz")"
  if [[ $(wget -S --spider "${pushGatewayFileName}"  2>&1 | grep 'HTTP/1.1 200 OK') ]]; then
	 echo "Push Gateway install archive found: $pushGatewayFileName"
  else
	 echo "Unable to find Push Gateway install archive"
	 (exit 1)
  fi

  # Download and extract the latest release
  echo "Downloading: ${pushGatewayFileName}"
  wget -nv --show-progress -O push_gateway.tar.gz "${pushGatewayFileName}"
  sudo mkdir -pm744 push_gateway
  tar -xvf pushGateway.tar.gz -C push_gateway --strip-components=1
  cd push_gateway
  working_dir=$(pwd)

  # TKTK  # Move files to target directories and apply permissions
  sudo chmod -R 744 push_gateway
  sudo chown -R prometheus:prometheus push_gateway
  sudo cp push_gatway /usr/local/bin/
  # sudo chown -R prometheus:prometheus /usr/local/bin/push_gateway
  # sudo chmod -R 744 /usr/local/bin/push_gateway

  # Create the service file
  {
	 echo "[Unit]"
	 echo "Description=Push Gateway"
	 echo "Documentation=https://github.com/prometheus/pushgateway"
	 echo "Wants=network-online.target"
	 echo "After=network-online.target"
	 echo ""
	 echo "[Service]"
	 echo "Type=simple"
	 echo "Restart=always"
	 echo "User=prometheus"
	 echo "Group=prometheus"
	 echo "SyslogIdentifier=push_gateway"
	 echo "ExecReload=/bin/kill -HUP \${MAINPID}"
	 echo "ExecStart=/usr/local/bin/push_gateway \\"
	 echo "  --web.listen-address=0.0.0.0:9091 \\" # API endpoint
	 echo "  --web.persistence.file=/etc/prometheus/push_gateway/cache"
	 echo ""
	 echo "[Install]"
	 echo "WantedBy=multi-user.target"
  } > push_gateway.service

  # Initialize the service
  echo "Initializing service"
  sudo cp push_gateway.service /etc/systemd/system/push_gateway.service
  sudo systemctl daemon-reload
  sudo systemctl start push_gateway
  sudo systemctl enable push_gateway

  cd ..

  # Print footer
  echo ""
  echo "Push Gateway is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status push_gateway"
  echo ""
  echo "Submit metrics to this endpoint:"
  echo "  http://<your-host-ip>:TKTK/"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs Grafana
install_grafana() {

  # Print header
  echo;
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Grafana";
  echo;

  # Check if Grafana is already installed
  if command -v grafana-server &> /dev/null; then
	 echo "Grafana is already installed: $(command -v grafana-server)"
	 (exit 1)
  fi

  # Get the latest release
  # REF: https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/
  echo "Installing package"
  sudo apt-get install -y software-properties-common wget
  sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
  echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
  sudo apt-get update -y
  sudo apt-get install grafana-enterprise -y
  sudo mkdir -pm744 grafana
  cd grafana

  # Configure the Prometheus datasource
  echo "Configuring data source"
  {
	 echo "apiVersion: 1"
	 echo ""
	 echo "datasources:"
	 echo "  - name: Prometheus"
	 echo "    type: prometheus"
	 echo "    access: proxy"
	 echo "    orgId: 1"
	 echo "    url: http://localhost:9090"
	 echo "    isDefault: true"
	 echo "    version: 1"
	 echo "    editable: true"
  } > prom.yaml
  sudo cp prom.yaml /etc/grafana/provisioning/datasources/
  sudo chown -R grafana:grafana /etc/grafana/provisioning/datasources/
  sudo chmod -R 774 /etc/grafana/provisioning/datasources/

  # Create the geojson file
  geojson_path="/usr/share/grafana/public/maps"
  geojson_file="node.geojson"
  host=$(hostname)
  location="Pleasantville, Maryland"
  longitude="-76.442887"
  latitude="39.542517"
  ip_address="0.0.0.0"
  provider="Verizon"

  {
	 echo "{"
	 echo "  \"type\":\"FeatureCollection\","
	 echo "  \"features\":["
	 echo "    { \"type\":\"Feature\","
	 echo "      \"id\":\"Node\","
	 echo "      \"properties\": {"
	 echo "        \"Host\": \"${host}\","
	 echo "        \"Location\":\"${location}\","
	 echo "        \"IP Address\": \"${ip_address}\","
	 echo "        \"Provider\": \"${provider}\" },"
	 echo "      \"geometry\": {"
	 echo "        \"type\":\"Point\","
	 echo "        \"coordinates\": [${longitude},${latitude}] }}]"
	 echo "}"
  } > ${geojson_file} && cp ${geojson_file} ${geojson_path}

  # Install any required plugins now...

  echo "Initializing service"
  sudo systemctl daemon-reload
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server.service
  
  cd ..

  # REF: https://github.com/grafana/grafana/issues/12638#issuecomment-479855405
  #
  # Important: if you blow it and lose the admin password after reset, then install sqlite3 and run the following commands to reset the password:
  # sudo apt-get install sqlite3
  # sudo sqlite3 /var/lib/grafana/grafana.db
  # sqlite> update user set password = '59acf18b94d7eb0694c61e60ce44c110c7a683ac6a8f09580d626f90f4a242000746579358d77dd9e570e83fa24faa88a8a6', salt = 'F3FAxVm33R' where login = 'admin';
  # sqlite> .exit
  # https://jenciso.github.io/recovery-admin-password-for-grafana
  # Now login using username:admin, password:admin and reset the admin password.
  #
  # Resetting the password using the grafana-cli should also be possible with the following commands:
  # ln -s /var/lib/grafana  /usr/share/grafana/data # creates a link
  # ln -s /var/log/grafana /usr/share/grafana/data/logs
  # cd /usr/share/grafana && sudo grafana-cli --homepath "/usr/share/grafana" admin reset-admin-password admin
  # however, the command is bugged and fails even though it states it succeeds - don't lose your admin password!

  # Print footer
  echo ""
  echo "Grafana is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status grafana-server"
  echo ""
  echo "View the interface using this endpoint:"
  echo "  http://<your-host-ip>:3000"
  echo ""
  echo "Be sure to modify your geojson file to provide your correct node location and other information:"
  echo "  - Find the file here: ${geojson_path}/${geojson_file}"
  echo "  - First, update the content, then rename the file to remove the \".tmp\" extension"
  echo "  - Grafana is very stubborn about the geojson source - so try to get your longitude and latitude right! ;-)"
  echo "  - It might help to restart the service if you make a change \$ sudo systemctl restart grafana-server"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Installs the Algorand Monitoring Dashboard for Grafana
install_dashboard() {

  # REF: https://devconnected.com/monitoring-linux-processes-using-prometheus-and-grafana/
  # REF: https://grafana.com/grafana/dashboards/10795-1-node-exporter-0-16-for-prometheus-monitoring-display-board/
  # REF: https://medium.com/swlh/intro-to-server-monitoring-b782fc82911e
  # The Algo dashboard is a work in progress...

  # Print header
  echo;
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Algorand Monitoring Dashboard";
  echo;

  # Verify Grafana is installed
  if command -v grafana-server &> /dev/null; then

	 echo "Downloading dashboard from Github..."
	 sudo mkdir -pm744 grafana_dashboard
	 cd grafana_dashboard
	 wget -nd -m -nv https://raw.githubusercontent.com/node-ops-llc/algorand-monitoring/main/algorand_monitoring_dashboard.json
	 chown grafana:grafana *.json && chmod 744 *.json
	 sudo mkdir -p /etc/grafana/dashboards && chown grafana:grafana /etc/grafana/dashboards
	 sudo cp *.json /etc/grafana/dashboards

	 echo "Provisioning dashboards..."
	 {
		echo "apiVersion: 1"
		echo ""
		echo "providers:"
		echo "  - name: 'Algorand Node Monitoring Dashboard'"
		echo "    orgId: 1"
		echo "    folder: ''"
		echo "    folderUid: ''"
		echo "    type: file"
		echo "    disableDeletion: false"
		echo "    updateIntervalSeconds: 30"
		echo "    allowUiUpdates: true"
		echo "    options:"
		echo "      path: /etc/grafana/dashboards"
		echo "      foldersFromFilesStructure: true"
	 } > algorand_node_monitoring_dashboard.yaml && chown grafana:grafana *.yaml && chmod 744 *.yaml
	 sudo cp *.yaml /etc/grafana/provisioning/dashboards/

	 echo "Restarting service"
	 sudo systemctl daemon-reload
	 sudo systemctl restart grafana-server

	 cd..

  else
  
	 echo "Grafana is not installed!"
	 (exit 1)

  fi

  # Print footer
  echo ""
  echo "Grafana Dashboard is installed!"
  echo ""
  echo "Verify the dashboard is installed by accessing Grafana:"
  echo "  http://<your-host-ip>:3000"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""
  
}

~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~

# Checks the operating environment
check_environment

# Check input argument
case $1 in
	--1|-1|1) install_prometheus;;
	--2|-2|2) install_node_exporter;;
	--3|-3|3) install_algod_metrics_emitter;;
	--4|-4|4) install_push_gateway;;
	--5|-5|5) install_grafana;;
	--6|-6|6) install_dashboard;;
	*) usage;;
esac

(exit 0)

#~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~
