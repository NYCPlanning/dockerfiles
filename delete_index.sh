set -e
set -x

for INDEX in "$@"
do
  echo "deleting index '"$INDEX"'"
  curl -XDELETE "http://localhost:9200/$INDEX"
done

