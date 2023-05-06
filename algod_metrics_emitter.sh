#!/bin/bash

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-
#
#   Implements the Algorand service (algod) metrics emitter
#     - Uses "top" or "ps" commands to return basic process information
#     - Also calls "algod" or obtains other information from systemd or the data directory for the service
#     - Creates properly formatted .prom files for the textfile collector
#     - Saves the text files to the target directory
#     - Requires function "get_metric_emitter_source", and then may  
#
#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

  # Source
  source_file="$(dirname $(realpath "$0"))/process_metrics_emitter.sh"; echo "Source file:" ${source_file}
  [ -f ${source_file} ] || (echo "Source file ${source_file} not found!"; (exit 1);); echo "Check: ${source_file} ok!"
  source ${source_file}; ((${debug})) && echo "Source ${source_file} set!"

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Process Metrics
IFS=' ' read -r algod_pid algod_uptime_seconds algod_instance algod_instance_data_dir <<< $(ps -p $(pidof algod) -o pid,etimes,cmd --no-header | awk '{print $1,$2,$3,$5}')
IFS=' ' read -r algod_cpu_pct algod_mem_pct <<< $(top -bn 1 -p $(pidof algod) | tail -1 | awk '{print $5,$6}')
algod_cpu_pct_adj=$(d=4 && printf "%.${d}f\n" $(echo "scale=${d}; $algod_cpu_pct/($(nproc --all))" | bc))

# Process - one or more in an array
process=("algod"); for i in "${process[@]}"; do echo ${i}; done;

# Command
cmd="sudo -u algorand goal node status";
get_cmd_output "${cmd}"

# Parse
for i in "${cmd_output[@]}"
do
  IFS=: read -r label metric <<< $((tr '[:upper:]' '[:lower:]') <<< ${i})
  metric=$(echo ${metric} | awk '{$1=$1};1' | sed 's/s$//')
  case ${label} in
    "last committed block")
      algod_last_committed_block=${metric};;
    "time since last block")
      algod_time_since_last_block_seconds=${metric};;
    "sync time")
      algod_sync_time_seconds=${metric};;
    "round for next consensus protocol")
      algod_next_consensus_round=${metric};;
  esac
done

# df --output=fstype,used,avail /var/lib/algorand | awk 'FNR==2{print $1,$2,$3}' -- to get disk use for the data directory

algod_is_active=$(systemctl is-active --quiet algorand && echo 1 || echo 0); ((${debug})) && echo "metric: algod_is_active: " ${algod_is_active}
algod_version=$(sudo -u algorand algod -v | grep "stable" | awk '{print $1}'); ((${debug})) && echo "metric: algod_version: " ${algod_version}

algod_start_timestamp_seconds=$((${metric_dtmu}-${algod_uptime_seconds})); ((${debug})) && echo "metric: algod_start_timestamp_seconds: " ${algod_start_timestamp_seconds}
algod_port=$(cat ${algod_instance_data_dir}/algod-listen.net | tac -s: | head -1); ((${debug})) && echo "metric: algod_port: " ${algod_port}
algod_genesis_id="$(sudo -u algorand algod -G)"; ((${debug})) && echo "metric: algod_genesis_id: " ${algod_genesis_id}
algod_metric_label="${metric_label}, algod_version=\"${algod_version}\", algod_port=\"${algod_port}\", algod_genesis_id=\"${algod_genesis_id}\", algod_instance=\"${algod_instance}\", algod_instance_data_dir=\"${algod_instance_data_dir}\", algod_pid=\"${algod_pid}\""; ((${debug})) && echo "metric_label: algod_metric_label: " ${algod_metric_label}

emit_counter "algod_last_committed_block" "${algod_last_committed_block}" "${algod_metric_label}" "The most recent block of the Algorand blockchain that was received and committed to the ledger."
emit_counter "algod_next_consensus_round" "${algod_next_consensus_round}" "${algod_metric_label}" "The next consensus round (block) for the Algorand blockchain."
emit_gauge "algod_time_since_last_block_seconds" "${algod_time_since_last_block_seconds}" "${algod_metric_label}" "Time since the most recent block of the Algorand blockchain was received in seconds."
emit_gauge "algod_sync_time_seconds" "${algod_sync_time_seconds}" "${algod_metric_label}" "Time required to synchronize the ledger to the current Algorand blockchain state in seconds."
emit_gauge "algod_pid" "${algod_pid}" "${algod_metric_label}" "The current algod service process ID."
emit_gauge "algod_is_active" "${algod_is_active}" "${algod_metric_label}" "The current active state of the algod service."
emit_counter "algod_start_timestamp_seconds" "${algod_start_timestamp_seconds}" "${algod_metric_label}" "Timestamp when algod service was last started in seconds since epoch (1970)."
emit_gauge "algod_uptime_seconds" "${algod_uptime_seconds}" "${algod_metric_label}" "Time in seconds since the algod service was last started."
emit_gauge "algod_cpu_pct" "${algod_cpu_pct_adj}" "${algod_metric_label}" "Percent CPU usage for the algod service reported by ps command."
emit_gauge "algod_mem_pct" "${algod_mem_pct}" "${algod_metric_label}" "Percent memory usage for the algod service reported by ps command."
emit_counter "algod_metrics_last_collected_timestamp_seconds" "${metric_dtmu}" "${algod_metric_label}" "Timestamp when algod metrics were last collected in seconds since epoch (1970)."

finalize_metric_file