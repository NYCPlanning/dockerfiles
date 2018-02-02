#!/bin/bash

# get timestamp
PELIAS_TIMESTAMP=`date +%s`

# build nycpad docker image
docker-compose build nycpad

# set unique indexName using timestamp
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/\"pelias.*\"/\"pelias_${PELIAS_TIMESTAMP}\"/g" pelias.json
else
  sed -i  "s/\"pelias.*\"/\"pelias_${PELIAS_TIMESTAMP}\"/g" pelias.json
fi
# create index
docker-compose run --rm schema npm run create_index

# download data
docker-compose run --rm nycpad npm run download

#get filename of downloaded csv
FILENAME=$(jq .imports.nycpad.import[0].filename pelias.json | sed "s/\"//g")
echo $FILENAME

# get rowcount of downloaded CSV
ROWCOUNT=$(wc -l < /tmp/nycpad/$FILENAME)
ROWCOUNT=$(($ROWCOUNT - 1)) # subtract 1 for csv header row
echo "Row count:" $ROWCOUNT

curl -X POST \
-H 'Content-type: application/json' \
--data '{"text": "Starting NYCPAD import `pelias_'"$PELIAS_TIMESTAMP"'` from `'"$FILENAME"'` containing `'"$ROWCOUNT"'` addresses", "channel": "#labs-geocoder-api", "username": "GeoSearch Import Bot", "icon_emoji": ":robot_face:"}' \
$SLACK_WEBHOOK_URL

# import downloaded data
docker-compose run --rm nycpad npm start

# get rowcount from DB
curl -XPOST "http://localhost:9200/pelias_"$PELIAS_TIMESTAMP"/_refresh"

ES_ROWCOUNT=$(curl "http://localhost:9200/pelias_"$PELIAS_TIMESTAMP"/address/_count" | jq .count)
echo $(curl "http://localhost:9200/pelias_"$PELIAS_TIMESTAMP"/address/_count")
echo $ES_ROWCOUNT

echo "CSV Rowcount" $ROWCOUNT
echo "ES Rowcount" $ES_ROWCOUNT

docker-compose build tests
docker-compose run tests

TESTS_STATUS=$(curl "https://planninglabs.nyc3.digitaloceanspaces.com/geosearch-acceptance-tests/status.json" | jq .status | sed "s/\"//g")
echo $TESTS_STATUS

if [[ "$TESTS_STATUS" = "passed" ]]; then
  if [ "$ROWCOUNT" -eq "$ES_ROWCOUNT" ]; then
    MESSAGE="Rowcounts Match, setting alias \`pelias\` on index \`pelias_"$PELIAS_TIMESTAMP"\` <https://planninglabs.nyc3.digitaloceanspaces.com/geosearch-acceptance-tests/status.json|Tests Passed>"

    # clear all aliases
    curl -XPOST 'localhost:9200/_aliases?pretty' -H 'Content-Type: application/json' -d'
    {
     "actions" : [
        { "remove" : { "index" : "*", "alias" : "pelias" } }
     ]
    }
    '

    # set alias
    curl -XPOST 'localhost:9200/_aliases?pretty' -H 'Content-Type: application/json' -d'
    {
        "actions" : [
            { "add" : { "index" : "pelias_'"$PELIAS_TIMESTAMP"'", "alias" : "pelias" } }
        ]
    }
    '
  else
    MESSAGE="I am sorry to inform you that the rowcounts did not match, something went wrong with this import..."
  fi

else
  MESSAGE="I regret to inform you that the test suite failed."
fi

echo $MESSAGE


curl -X POST \
-H 'Content-type: application/json' \
--data '{"text": "'"$MESSAGE"'", "channel": "#labs-geocoder-api", "username": "GeoSearch Import Bot", "icon_emoji": ":robot_face:"}' \
$SLACK_WEBHOOK_URL
echo $MESSAGE
