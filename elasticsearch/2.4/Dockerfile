# base image
FROM elasticsearch:2.4

USER root

# configure plugins
RUN /usr/share/elasticsearch/bin/plugin install analysis-icu

# elasticsearch config
ADD elasticsearch.yml /usr/share/elasticsearch/config/
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml

# run as elasticsearch user
USER elasticsearch
