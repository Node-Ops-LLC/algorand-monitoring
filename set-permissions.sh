# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# !/bin/bash

# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# Statics
source="$(readlink -f "{$0}")"
echo "source: ${source}"
source_dir="$(dirname "${source}")"
echo "source_dir: ${source_dir}"

# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# Code

# switch to the script directory
cd "${source_dir}" && pwd;

# apply permissions to data directories
chown -R nobody:nogroup prometheus/data # Prometheus
chown -R 1000:1000 elasticsearch/data #Elasticsearch