#!/bin/bash

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-
#
# Installs monitoring tools for Algorand node runners: Prometheus, Node Exporter, Algod Metrics Emitter, Grafana, and dashboard
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

  echo "Usage: $0 [--1|--2|--3|--4|--5|--6|--help]"
  echo ""
  echo "Options:"
  echo "   --help   Show the help menu"
  echo "   --1      Install Prometheus"
  echo "   --2      Install Node Exporter"
  echo "   --3      Install Algod Metrics Emitter"
  echo "   --4      Install Push Gateway" # skip this for now...
  echo "   --5      Install Grafana"
  echo "   --6      Install Algorand dashboard"
  echo ""
 
}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Checks for required commands
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
    (exit 1)
  fi
  
  # Check system architecture compatibility
  if [ "$foundArch" = "aarch64" ]; then
    getArch="arm64" # Running on arm arch (probably RasPi)
  elif [ "$foundArch" = "x86_64" ]; then
    getArch="amd64" # Running on intel/amd
  else
    echo "Unsupported architecture: $foundArch!"
    (exit 1)
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
  {
    echo ""
    echo "  - job_name: 'algod-metrics'"
    echo "    metrics_path: '/metrics'"
    echo "    static_configs:"
    echo "      - targets: ['localhost:9100']"
    echo "        labels:"
    echo "          alias: 'algod'"
  } >> prometheus.yml

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
    echo "  --web.external-url=http://localhost:9090/prometheus \\" # To secure from external access, leave the port closed
    echo "  --web.route-prefix=/prometheus"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } > prometheus.service

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
  echo "  http://your-node-host-ip:9090/"
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
    echo "  --collector.bonding \\"
    echo "  --collector.conntrack \\"
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
    echo "  --collector.textfile \\"
    echo "  --collector.textfile.directory=/etc/prometheus/node_exporter/collector_textfile/ \\"
    echo "  --collector.thermal \\"
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
  
  # Update Prometheus configuration
  echo "Configuring Prometheus"
  cp /etc/prometheus/prometheus.yml .
  {
    echo ""
    echo "  - job_name: 'host-metrics'"
    echo "    scrape_interval: 5s"
    echo "    metrics_path: '/metrics'"
    echo "    static_configs:"
    echo "      - targets: ['localhost:9101']"
    echo "        labels:"
    echo "          alias: 'host'"
  } >> prometheus.yml
  sudo cp prometheus.yml /etc/prometheus/
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

# Installs Algod Metrics Emitter
install_algod_metrics_emitter() {

  # Print header
  echo;
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-";
  echo "Installing Algod Metrics Emitter";
  echo;

  # Confirm directories are added and navigate
  sudo mkdir -pm744 node_exporter/collector_textfile && cd node_exporter # just in case

  # Create the algod metrics emitter
  filePrefix="algod_metrics"
  metricsEmitter="${filePrefix}_emitter"

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
    echo "SyslogIdentifier=${metricsEmitter}"	
    echo "ExecStart=/bin/bash /etc/prometheus/node_exporter/${metricsEmitter}.sh"
  } > ${metricsEmitter}.service

  # Create the metrics emitter timer file
  {
    echo "[Unit]"
    echo "Description=\"Timer to run the algod service metrics emitter\""
    echo ""
    echo "[Timer]"
    echo "Unit=${metricsEmitter}.service"
    echo "OnCalendar=*:*:0/15" # run the target every 15 seconds
    echo ""
    echo "[Install]"
    echo "WantedBy=timers.target"
  } > ${metricsEmitter}.timer

  # Move the service and timer files to systemd
  find . -name "${metricsEmitter}.*" -exec mv '{}' /etc/systemd/system/ \;  
  
  # Create algod metrics emitter
  {
    echo '#!/bin/bash'
    echo ""
    echo "path=\$( cd -- \"\$( dirname -- \"\${BASH_SOURCE[0]}\" )\" &> /dev/null && pwd )"
    echo "cd \${path}"
    echo "dataPath=\"\${path}/collector_textfile\""
    echo "fileName=\"${filePrefix}.prom\""
    echo "file=\"\${dataPath}/\${fileName}\""
    echo "tmpFile=\"\${file}.tmp\""
    echo "lastCollected=(\$(date +%s))"
    echo ""
    echo "mapfile -t goalStatus < <(sudo -u algorand goal node status)"
    echo ""
    echo "for i in \"\${goalStatus[@]}\""
    echo "do"
    echo "  IFS=: read -r label metric <<< \$((tr '[:upper:]' '[:lower:]') <<< \${i})"
    echo "  metric=\$(echo \${metric} | awk '{\$1=\$1};1' | sed 's/s\$//')"
    echo "  case \${label} in"
    echo "    \"last committed block\")"
    echo "      lastBlock=\${metric};;"
    echo "    \"time since last block\")"
    echo "      timeSinceLastBlock=\${metric};;"
    echo "    \"sync time\")"
    echo "      syncTime=\${metric};;"
    echo "    \"round for next consensus protocol\")"
    echo "      nextConsensusRound=\${metric};;"
    echo "  esac"
    echo "done"	
    echo ""
    echo "host=\$(hostname)"
    echo "alias=\"algod\""
    echo "job=\"algod-metrics\""
    echo "label=\"host=\\\"${host}\\\", alias=\\\"${alias}\\\", job=\\\"${job}\\\"\""
    echo ""
    echo "algod_is_active=\$(systemctl is-active --quiet algorand && echo 1 || echo 0)"
    echo "algod_version=\$(algod -v | grep \"$(algod -c)\" | cut -d[ -f1 | awk '{\$1=\$1};1')"
    echo "currentDtmz=\$(date -u +%s) # get the current datetime in epoch seconds"
    echo "IFS=' ' read -r algod_pid algod_uptime_seconds algod_cpu_pct algod_mem_pct algod_instance algod_instance_data_dir <<< \$(ps -p \$(pidof algod) -o pid,etimes,%cpu,%mem,cmd --no-header | tr -s ' ' | cut -d ' ' -f1,2,3,4,5,7)"
    echo "algod_start_timestamp_seconds=\$((\${currentDtmz}-\${algod_uptime_seconds}))"
    # echo "date -d @${algod_start_timestamp_seconds} -Iseconds # prints the service start time in ISO format
    echo "label_meta=\"\${label}, algod_version=\\\"${algod_version}\\\", algod_instance=\\\"${algod_instance}\\\", algod_instance_data_dir=\\\"${algod_instance_data_dir}\\\"\""
    echo ""
    echo "{"
    echo "  echo \"# HELP algod_last_committed_block The most recent block of the Algorand blockchain that was received and committed to the ledger.\""
    echo "  echo \"# TYPE algod_last_committed_block gauge\""
    echo "  echo \"algod_last_committed_block {\${label}} \${lastBlock}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_time_since_last_block_seconds Time since the most recent block of the Algorand blockchain was received in seconds.\""
    echo "  echo \"# TYPE algod_time_since_last_block_seconds gauge\""
    echo "  echo \"algod_time_since_last_block_seconds {\${label}} \${timeSinceLastBlock}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_sync_time_seconds Time required to synchronize the ledger to the current Algorand blockchain state in seconds.\""
    echo "  echo \"# TYPE algod_sync_time_seconds gauge\""
    echo "  echo \"algod_sync_time_seconds {\${label}} \${syncTime}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_next_consensus_round The next consensus round (block) for the Algorand blockchain.\""
    echo "  echo \"# TYPE algod_next_consensus_round gauge\""
    echo "  echo \"algod_next_consensus_round {\${label}} \${nextConsensusRound}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_pid The current algod service process ID.\""
    echo "  echo \"# TYPE algod_pid gauge\""
    echo "  echo \"algod_pid {\${label_meta}} \${algod_pid}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_is_active The current active state of the algod service.\""
    echo "  echo \"# TYPE algod_is_active gauge\""
    echo "  echo \"algod_is_active {\${label_meta}} \${algod_is_active}\""
    echo "  echo \"\""    
    echo "  echo \"# HELP algod_start_timestamp_seconds Timestamp when algod service was last started in seconds since epoch (1970).\""
    echo "  echo \"# TYPE algod_start_timestamp_seconds gauge\""
    echo "  echo \"algod_start_timestamp_seconds {\${label_meta}} \${algod_start_timestamp_seconds}\""
    echo "  echo \"\""    
    echo "  echo \"# HELP algod_uptime_seconds Time in seconds since the algod service was last started.\""
    echo "  echo \"# TYPE algod_uptime_seconds gauge\""
    echo "  echo \"algod_uptime_seconds {\${label_meta}} \${algod_uptime_seconds}\""
    echo "  echo \"\""    
    echo "  echo \"# HELP algod_cpu_pct Percent CPU usage for the algod service reported by ps command.\""
    echo "  echo \"# TYPE algod_cpu_pct gauge\""
    echo "  echo \"algod_cpu_pct {\${label_meta}} \${algod_cpu_pct}\""
    echo "  echo \"\""
    echo "  echo \"# HELP algod_mem_pct Percent memory usage for the algod service reported by ps command.\""
    echo "  echo \"# TYPE algod_mem_pct gauge\""
    echo "  echo \"algod_mem_pct {\${label_meta}} \${algod_mem_pct}\""
    echo "  echo \"\""    
    echo "  echo \"# HELP algod_metrics_last_collected_timestamp_seconds Timestamp when algod metrics were last collected in seconds since epoch (1970).\""
    echo "  echo \"# TYPE algod_metrics_last_collected_timestamp_seconds gauge\""
    echo "  echo \"algod_metrics_last_collected_timestamp_seconds {\${label}} \${lastCollected}\""
    echo "  echo \"\""    
    echo "} | tee \"\${tmpFile}\" > /dev/null && sudo chown prometheus:prometheus \${tmpFile}"
    echo ""
    echo "mv -f \${tmpFile} \${file}"
  } | sudo -u prometheus tee ${metricsEmitter}.sh > /dev/null && sudo chmod 774 *.sh

  # visudo --file=/etc/sudoers.d/prometheus # this is how you would manually add execution permissions using visudo
  # The commands below would create the permissions file, but I don't think they're needed
  # {
  #   echo "root ALL=(prometheus) NOPASSWD: /etc/prometheus/node_exporter/algod_metrics_emitter.sh"
  #   echo "prometheus ALL=(algorand) NOPASSWD: /usr/bin/goal"
  #   echo "prometheus ALL=(root) NOPASSWD: /usr/bin/tee /usr/bin/mv /etc/prometheus/node_exporter/algod_metrics_emitter.sh"
  # } > prometheus && mv -f prometheus /etc/sudoers.d/prometheus

  # Initialize the service
  echo "Initializing custom metrics emitter"
  sudo systemctl daemon-reload
  sudo systemctl start ${metricsEmitter}.timer
  sudo systemctl enable ${metricsEmitter}.timer

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
    echo "    editable: false"
  } > prom.yaml
  sudo cp prom.yaml /etc/grafana/provisioning/datasources/
  sudo chown -R root:grafana /etc/grafana/provisioning/datasources/
  sudo chmod -R 755 /etc/grafana/provisioning/datasources/

  echo "Initializing service"
  sudo systemctl daemon-reload
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server.service
  cd ..

  # Print footer
  echo ""
  echo "Grafana is installed!"
  echo ""
  echo "Verify the service is running with the following command (q to exit):"
  echo "  \$ sudo systemctl status grafana-server"
  echo ""
  echo "View the interface using this endpoint:"
  echo "  http://your-node-host-ip:3000"
  echo ""
  echo "-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-"
  echo ""

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-
# GRAFANA DASHBOARDS FOR ALGORAND

}

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Checks the operating environment
get_environment

# Check input argument
if [ -z $1 ]; then
  echo "Please choose an option"
else
  case $1 in
    --1) # Install Prometheus
      install_prometheus;;
    --2) # Install Node Exporter
      install_node_exporter;;
    --3) # Install Algod Metrics Emitter
      install_algod_metrics_emitter;;
    --4) # Install Push Gateway - skip this step for now, the install will be retained if needed in the future
      install_push_gateway;;
    --5) # Install Grafana
      install_grafana;;
    --6) # Install Algorand dashboard
      install_dashboard;;
    --help) # Print usage
      usage;;
    *) # Any other argument
      echo "Please choose a supported option"
      (exit 1);;
  esac
fi

(exit 0)
