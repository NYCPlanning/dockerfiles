set -e
set -x

curl http://localhost:9200/_cat/aliases?v
