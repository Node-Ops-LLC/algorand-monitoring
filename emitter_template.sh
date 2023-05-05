# Template for Process Metric Emitter Sources - remove this line and place at the top of emitter script

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

  # Source
  source_file="$(dirname $(realpath "$0"))/process_metric_emitter.sh"; echo "Source file:" ${source_file}
  [ -f ${source_file} ] || (echo "Source file ${source_file} not found!"; (exit 1);); echo "Check: ${source_file} ok!"
  source ${source_file}; ((${debug})) && echo "Source ${source_file} set!"

  # Emitter script should be named using the pattern ${process_name}_metric_emitter.sh
  # If >1 process, override process list, but default is ${process_name} from file name prefix, ie "algod_process_emitter"

#-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-

