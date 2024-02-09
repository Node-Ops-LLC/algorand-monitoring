# -~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-+-~-
# !/bin/bash

(curl -XPUT -H "Content-Type: application/json" "http://localhost:9200/_template/template_1" \
  -d '{"index_patterns" : ["*"], "order": 0, "settings": {"number_of_shards": 1, "number_of_replicas": 0}}' && \
 curl -s http://localhost:9200/_cat/health | grep -q "green\|yellow") || exit 1;