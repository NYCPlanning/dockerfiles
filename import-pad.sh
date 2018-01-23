#!/bin/bash
if [ -z "$STY" ]; then exec screen -m -S import-pad /bin/bash "$0"; fi

# get timestamp
PELIAS_TIMESTAMP=`date +%s`

# set unique indexName using timestamp
sed -i  "s/\"pelias.*\"/\"pelias_${PELIAS_TIMESTAMP}\"/g" pelias.json

# create index
docker-compose run --rm schema npm run create_index

# download data
docker-compose run --rm nycpad npm run download

# import downloaded data
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL docker-compose run --rm nycpad npm start &&

# clear all aliases
curl -XPOST 'localhost:9200/_aliases?pretty' -H 'Content-Type: application/json' -d'
{
 "actions" : [
    { "remove" : { "index" : "*", "alias" : "pelias" } }
 ]
}
' | tee -a curl_log &&

# set alias
curl -XPOST 'localhost:9200/_aliases?pretty' -H 'Content-Type: application/json' -d'
{
    "actions" : [
        { "add" : { "index" : "pelias_'"$PELIAS_TIMESTAMP"'", "alias" : "pelias" } }
    ]
}
' | tee -a curl_log 
