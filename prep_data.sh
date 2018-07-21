#!/bin/bash

set -e
set -x

# start elasticsearch if it's not already running
if ! [ $(curl --output /dev/null --silent --head --fail http://localhost:9200) ]; then
    docker-compose up -d elasticsearch

    # wait for elasticsearch to start up
    echo 'waiting for elasticsearch service to come up'
    until $(curl --output /dev/null --silent --head --fail http://localhost:9200); do
      printf '.'
      sleep 2
    done
fi

# create the index in elasticsearch before importing data
docker-compose run --rm schema npm run create_index

# download all the data to be used by imports
docker-compose run --rm whosonfirst npm run download &
docker-compose run --rm nycpad npm run download &
wait


docker-compose run --rm placeholder npm run extract
docker-compose run --rm placeholder npm run build

docker-compose up -d pip-service

docker-compose run --rm nycpad npm start &
wait
