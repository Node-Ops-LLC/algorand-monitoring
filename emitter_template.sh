# Template for Process Metrics Emitter - place at the top of your process emitter script
# Note: process metrics emitter file should be named ${process_name}_metrics_emitter.sh ex: "algod_metrics_emitter.sh"

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

  # Source file "process_metrics_emitter.sh" must be found in the same directory as your custom emitter
  source_file="$(dirname $(realpath "$0"))/process_metrics_emitter.sh"; ((${debug})) && echo "Source file:" ${source_file}
  [ -f ${source_file} ] || (echo "Source file ${source_file} not found!"; (exit 1);); ((${debug})) && echo "Check: ${source_file} ok!"
  source ${source_file}; ((${debug})) && echo "Source ${source_file} set!"

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

