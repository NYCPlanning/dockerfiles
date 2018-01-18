# delete pelias index
curl -XDELETE 'http://localhost:9200/pelias'

# create pelias index
docker-compose run --rm schema npm run create_index;
