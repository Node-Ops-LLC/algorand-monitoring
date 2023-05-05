#!/bin/bash

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-
#
#   Process Metrics Emitter
#     - built to use the Prometheus Node Exporter textfile collector
#     - "emits" process metrics as properly-formatted .prom files in the textfile collector directory to be scraped by Prometheus
#     - employs commonly-available programs and shell commands to generate properly formatted .prom files with process metrics
#     - Process Exporter is available but not maintained by the project, so this is an independent and simple implementation
#     - can be used as a source file for process-specific implementations, or when called by default will collect "top" process metrics 
#
#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

# Directives
set -e
debug=1; ((${debug})) && echo "Debug:" ${debug}

# Functions
function append { local s=""; for i in "$@"; do s="${s}${i}"; done; echo "${s}"; }
function append_dir { append "${1}" "/" "${2}"; }
function append_ext { append "${1}" "." "${2}"; }
function break_point { exit 0; }
function trim { echo "${1}" | sed 's/^[ \t]*//;s/[ \t]*$//'; }
function strip_prefix { echo "${1/#${2}}"; }
function strip_suffix { echo "${1/%${2}}"; }
function strip_ext { echo "${1%.*}"; }
function check_dir { [ -d ${1} ] && return || false; }
function check_file { [ -f ${1} ] && return || false; }
function get_dtm_epoch_ms { date +%s%3N; }
function get_cmd_output {
  local cmd="${1}"
  readarray -t cmd_output < <(${cmd})
  ((${debug})) && (echo -e "Command Output:\n${sep}"; for i in "${cmd_output[@]}"; do echo ${i}; done; echo ${sep};)
  }

# Statics
sep="-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-"
script_full_name=$(basename "$0"); ((${debug})) && echo "Script full name:" ${script_full_name}
script_name=$(strip_ext ${script_full_name}); ((${debug})) && echo "Script name:" ${script_name}
script_prefix=$(strip_suffix ${script_name} "_emitter"); ((${debug})) && echo "Script prefix:" ${script_prefix}
metric_prefix=$(strip_suffix ${script_prefix} "_metric"); ((${debug})) && echo "Metric prefix:" ${metric_prefix}
script_path=$(trim $(realpath "$0")); ((${debug})) && echo "Script path:" ${script_path}
script_dir=$(trim $(dirname ${script_path})); ((${debug})) && echo "Script dir:" ${script_dir}
prom_dir="/etc/prometheus"; ((${debug})) && echo "Prom dir:" ${prom_dir}
exporter_dir=$(append_dir ${prom_dir} "node_exporter"); ((${debug})) && echo "Exporter dir:" ${exporter_dir}
metric_dir=$(append_dir ${exporter_dir} "collector_textfile"); ((${debug})) && echo "Metric dir:" ${metric_dir}
top_dir=$(append_dir ${prom_dir} "top") && HOME=${top_dir}; ((${debug})) && echo "Top dir:" ${top_dir}
top_config_dir=$(append_dir ${top_dir} ".config/procps"); ((${debug})) && echo "Top config dir:" ${top_config_dir}
top_config_file_name="toprc"; ((${debug})) && echo "Top config file name:" ${top_config_file_name}
top_config_file=$(append_dir ${top_config_dir} ${top_config_file_name}); ((${debug})) && echo "Top config file:" ${top_config_file}
top_config_git_url="https://raw.githubusercontent.com/node-ops-llc/algorand-monitoring/main/toprc"; ((${debug})) && echo "Top config Git URL:" ${top_config_git_url}
metric_file_ext="prom"; ((${debug})) && echo "Metric file ext:" ${metric_file_ext}
tmp_file_ext="tmp"; ((${debug})) && echo "Tmp file ext:" ${tmp_file_ext}
host=$(hostname); ((${debug})) && echo "Host:" ${host}
metric_type_gauge="gauge"; ((${debug})) && echo "Metric type gauge:" ${metric_type_gauge}
metric_type_counter="counter"; ((${debug})) && echo "Metric type counter:" ${metric_type_counter}

# Check Script Dir
[ ${script_dir}==${exporter_dir} ] || { echo "Script should be in ${exporter_dir} not ${script_dir}!"; (exit 1); }; ((${debug})) && echo "Check: ${script_dir} ok!"

# Check Metric Dir
check_dir ${metric_dir} || { echo "Metric directory ${metric_dir} does not exist!"; (exit 1); }; ((${debug})) && echo "Check: ${metric_dir} ok!"

# Check Top Config
check_file ${top_config_file} || {
    wget -nd -m -nv -P ${top_config_dir} ${top_config_git_url} # Git er done
    if [ $? -ne 0 ]; then # if download failed...
      echo "Top configuration file ${top_config_file} is not found!"
      (exit 1)
      fi
    }; ((${debug})) && echo "Check: ${top_config_file} ok!"
 
# Dependent Functions
function get_metric_file_name { append_ext "${1}" "${metric_file_ext}"; }
function get_metric_file { append_dir "${1}" "$(get_metric_file_name ${2})"; }
function get_tmp_file { append_ext "${1}" "${tmp_file_ext}"; }
function finalize_metric_file { mv -f ${metric_tmp_file} ${metric_file}; }

function append_metric_label { # new_key, new_value, current_label_string or empty
  local label=$(append "${1}" "=\"" "${2}" "\"") current_label="${3}"
  [ -z "${current_label}" ] && echo "${label}" || append "${current_label}" ", " "${label}"; }

function emit_metric { # metric_key, metric_value, metric_type, metric_label, metric_help
  # Note: prom format also supports a "metric_timestamp", in unix epoch ms, that can follow the value, but textfile collector will ignore
  local metric_key="${1}" metric_value="${2}" metric_type="${3}" metric_label="${4}" metric_help="${5}"
  local metric_key_value metric=()
  [ -z "${metric_key}" ] && { echo "Metric key must be defined!"; (exit 1); }
  [ -z "${metric_value}" ] && { echo "Metric value must be defined!"; (exit 1); }
  [ -z "${metric_label}" ] && \
    metric_key_value=$(append "${metric_key}" " " "${metric_value}") || \
    metric_key_value=$(append "${metric_key}" " {" "${metric_label}" "} " "${metric_value}")
  [ -z "${metric_help}" ] || metric+=("$(append "# HELP " "${metric_key}" " " "${metric_help}")")
  [ -z "${metric_type}" ] || metric+=("$(append "# TYPE " "${metric_key}" " " "${metric_type}")")
  [ -z "${metric_key_value}" ] || metric+=("${metric_key_value}")
  for i in "${metric[@]}"; do echo "${i}" >> ${metric_tmp_file}; done; }

function emit_gauge { # metric_key, metric_value, metric_label, metric_help
  local metric_key="${1}" metric_value="${2}" metric_label="${3}" metric_help="${4}"
  emit_metric "${metric_key}" "${metric_value}" "${metric_type_gauge}" "${metric_label}" "${metric_help}"; }

function emit_counter { # metric_key, metric_value, metric_label, metric_help
  local metric_key="${1}" metric_value="${2}" metric_label="${3}" metric_help="${4}"
  emit_metric "${metric_key}" "${metric_value}" "${metric_type_counter}" "${metric_label}" "${metric_help}"; }

# function get_process_metrics { # returns basic process metrics when supplied with a process name
# }

# Dependent Statics
metric_file=$(get_metric_file ${metric_dir} ${script_prefix}); ((${debug})) && echo "Metric file:" ${metric_file}
metric_tmp_file=$(get_tmp_file ${metric_file}); ((${debug})) && echo "Metric tmp file:" ${metric_tmp_file}
metric_label=$(append_metric_label "host" "${host}"); ((${debug})) && echo "Metric label:" ${metric_label}
metric_dtmu=$(get_dtm_epoch_ms); ((${debug})) && echo "Metric datetime (unix ms):" ${metric_dtmu}

# Manage Temp File
touch ${metric_tmp_file};
sudo chown prometheus:prometheus ${metric_tmp_file};

# Process Metrics
# top -bn1 -p $(pidof algod) | awk 'NR==3 {print $5,$6}'
# mapfile procs < <(HOME="/etc/algorand-monitoring" top -bn1 | awk '{f="|";c="id -un "$2;if($5>0||$6>0){c|getline u;s=$1f$2f u f$3f$4f$5f$6f$7f$8f$9;if(NF>9) s=s f substr($0,index($0,$10));else s=s f;print s;close(cmd);}}')
#mem=$(free | awk 'FNR==2 {print $2}')
#ps -eo pid,uid,pri,stat,%cpu,%mem,times,rss,etimes,comm,command # shows the all-time %cpu and %mem, calculated from times/etimes and rss/tot_mem
#echo "scale=6; $rss/$mem*100" | bc # prints the precise %memory for a given process
#echo "scale=6; $times/$etimes*100" | bc # prints the precise %cpu over the process lifetime (total cpu time over elapsed time)
# top -bn1 # shows the current short-sampled %cpu and %mem
# you can toggle the single-cpu vs multi-cpu calculation method in top using shift+i, but since there is only one decimal, the precision goes down by core count
# REF: https://serverfault.com/questions/169676/how-to-check-disk-i-o-utilization-per-process # diskstats and procstats

# PME  by default generates a "top" list of processes by CPU and MEM
# PME could possibly also collect IO by process...
    # iotop -boPqqqkn 10 | awk '{print $1,$4,$6,$10}' > iotop # this runs iotop 10 times, samples IO write/read/pct and prints the numerics to a file
    # iotop -boPaqqqkn 10 # this will show the accumulated IO instead of the bandwidth
    # rm io;(iotop -boPaqqqkn 2 -d 10 | ts %.s | awk '{print $1,$2,$5,$7,$11}') >> io # requires moreutils for ts, prints an accumulated sample result to a file
    # rm io;(iotop -boPaqqqkn 2 -d 10 | ts %.s | awk '{"ps -p"$2" -o comm --no-headers"|getline e;print $1,$2,e,$5,$7,$11}') >> io # adds the process name-ish - but this is just a dog and pony trick, rather get it on read - the valuable command here is ps -p PID -o comm --no-headers
    # f="io_$(date +%s%3N)";(iotop -boPaqqqkn 2 -d 10 | awk '{print $1,$4,$6,$10}') >> ${f} # writes to a time-dated file
    # readarray -t io_out< <(iotop -boPaqqqkn 2 -d 10 | awk '{print $1,$4,$6,$10}') # writes to an array! I like this one..
    # readarray -tO "${#io_out[@]}" io_out< <(iotop -boPaqqqkn 3 -d 5 | awk '{print $1,$4,$6,$10}' | ts %.s) # this syntax appends to the end of the array properly
    # io_out=();readarray -tO "${#io_out[@]}" io_out< <(iotop -boPqqqk -p3747033 | awk '{print $1,$4,$6,$10}' | ts %.s) 
    # iotop -bPotqqqkn50 -u algorand | grep $(pidof algod) # adds a basic timestamp to each row
        # I've discovered that iotop will use Process mode when a -u user is selected, but will not do so when a -p pid is selected 
        # when a single pid is requested, it only displays the actual IO of that specific PID
        # in user+process mode, the parent PID that displays is a rollup of all the child processes/threads, so then you can just grep by the process PID
# PME has a function to return the same stats for one or more listed PIDs
# PME also has a function to convert a list of process names into currently PIDs
# PME has a function to return a formatted metric if passed in the elements (metric_name, help_text, type, label, value, maybe tmp file to append?)

# any other logic must be implemented by individual emitters to add stats to their output

# read -r fstype size used avail <<< $(df -B1 --output=fstype,size,used,avail /var/lib/algorand | awk 'FNR==2{print $1,$2,$3,$4}')
# get the total, available, and used sizes of the filesystem at a specific location
# read -r reserved <<< $(echo "scale=3;($size-($used+$avail))" | bc)
# derive the reserved space of the filesystem from the output of the command above

# get a list of PIDs for any process matching the search term - paste is a spiffy command that will wrap the lines together with the specified delimter ","
# s -NC ps,grep -o pid,comm,cmd | grep "psad" | awk '{print $1}' | paste -sd,
# ps -NC ps,grep -o pid,comm,cmd | grep "algo"
# top -bp$(ps -NC ps,grep -o pid,comm,cmd | grep "algo")
# top -bn1 -p $(ps -NC ps,grep -o pid,comm,cmd | grep "algo" | awk '{print $1}' | paste -sd,) # gets performance data from a process by PID using a search term instead of "pidof", which can fail depending upon how the executable is called or initialized
# snag current %CPU and %mem from top using a search term for the pid instead of an exact match on the process name, as required by "pidof"
# top -bn1 -p $(ps -NC ps,grep -o pid,comm,cmd | grep "algo" | awk '{print $1}' | paste -sd,) | awk 'NR==3{print $5,$6}'
