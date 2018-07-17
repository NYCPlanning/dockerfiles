#!/bin/bash

set -e
set -x

[ -z "$DATA_DIR" ] && echo "env var DATA_DIR not set" && exit 1

# bring containers down
# note: the -v flag deletes ALL persistent data volumes
docker-compose down || true

# pull images from docker hub. Building them manually is not suggested in normal cases
docker-compose pull

time ./prep_data.sh

time ./run_services.sh
