# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# !/bin/bash

# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# Statics
source="$(readlink -f "$0}")"
source_dir="$(dirname "${source}")"

# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# Code

# switch to the script directory
echo "source_dir: ${source_dir}"
cd "${source_dir}";

# apply permissions to data directories
chown -R nobody:nogroup prometheus/data # Prometheus
chown -R 1000:1000 elasticsearch/data #Elasticsearch