
Dockerfiles for NYC Geosearch Services.

NYC Geosearch is an JSON API for geocoding of NYC addresses, built on the open source [Pelias](https://github.com/pelias/pelias) geocoder and [NYC's Property Address Directory (PAD)](https://www1.nyc.gov/site/planning/data-maps/open-data.page)

## Overview

<img width="751" alt="screen shot 2018-01-18 at 1 12 07 pm" src="https://user-images.githubusercontent.com/1833820/35113991-48b04abc-fc51-11e7-8a4f-7664ddba6492.png">


These dockerfiles allow for quickly standing up all of the services that work together to run the pelias geocoder, and is used in both production and development.  These include:

- pelias API - node.js app that does parses search strings and finds results in the database
- elasticsearch - the database where all address results are stored
- [geosearch API](https://github.com/NYCPlanning/labs-geosearch-api) - A node.js proxy API that appends custom metadata to responses from the Pelias API.

This repo (and readme) serves as "home base" for the GeoSearch project, as the dockerfiles tie everything together.  Other relevant code for our Pelias deployment:
- [geosearch-pad-normalize](https://github.com/NYCPlanning/labs-geosearch-pad-normalize) - an R script that starts with the raw Property Address Database, and interpolates valid address ranges.
- [geosearch-pad-importer](https://github.com/NYCPlanning/labs-geosearch-pad-importer) - a Pelias importer for normalized NYC PAD data.
- [geosearch-docs](https://github.com/NYCPlanning/labs-geosearch-docs) - an interactive documentation site for the Geosearch API
- [geosearch-acceptance-tests](https://github.com/NYCPlanning/labs-geosearch-acceptance-tests) - nyc-specific test suite for geosearch
- [geosearch-api](https://github.com/NYCPlanning/labs-geosearch-api)- A node.js proxy API that appends custom metadata to responses from the Pelias API.

Docker Compose allows us to quickly spin up the pelias services we need, and run scripts manually in the containers.  It also makes use of volumes and internal hostnames so the various services can communicate with each other.  See below for the commands necessary to get started.

For more information on Pelias services, including many which we are not using here at City Planning, check out this [self-contained workshop](how_to_guide.pdf). This is the tutorial that got us started, and we recommend anyone working with Pelias start here.

## Running Pelias Services
In both production and development, several Pelias services need to be up and running before address data can be imported in the database. Before any data are imported, either locally or in production, you should have mastery of the long-running Pelias services outlined here, and how to get them started/restarted.

### Config-Driven
Much of this environment is config-driven, and the two files you should pay attention to are:
- [docker-compose.yml](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/docker-compose.yml) - configurations for each of the named services, including which docker image to run, which volumes, to use, etc
- [pelias.json](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/pelias.json) - a common config file used by all of the pelias services.  This identifies the hostnames for various services, and importer-specific configuration.

### Pull Images
Before you can run the pelias services via docker, you must first get all of the images.  The Pelias team has pre-built them and hosted them on dockerhub, so we can skip the time-consuming step of building the images manually.

`docker-compose pull` will get all of the pelias images from dockerhub.

For our PAD importer, there is no pre-built image, and how you include it is different in production and development.  See below for how to get the PAD importer working in each environment.

### elasticsearch database
To start a new database:

`docker-compose up -d elasticsearch` - spin up an empty elasticsearch database
`docker-compose run --rm schema npm run create_index` - create the `pelias` index

The database is now ready to receive data from an importer.

### pelias api
`docker-compose up -d api`

You should be able to query the API at `http://localhost:4000/v1/autocomplete?text={sometext}`, but there's no data in the database yet!

### PAD importer

The PAD importer serves two functions, it downloads the latest normalized PAD dataset, and imports each row into elasticsearch.  Each of these is run manually via an npm command.

The pad importer is run via docker-compose in both production and development:

```
sh import-pad.sh
```
This script will create new uniquely named pelias index, download the latest normalized pad data, start the import, and do some quality control checks.  Lastly, it will swap out the alias "pelias", applying it to the new index, making it the production index.

Before running the importer, be sure to delete all old indices that are not being used.  There is a helper scrip `delete_index.sh` that you can use for this.

In a development environment, if you want to develop on  `geosearch-api` or `geosearch-pad-importer` locally, be sure to change the build context for each in `docker-compose.yml`.  This will tell docker-compose to build off of the local repos instead of whatever the latest is on github.

## Production Domain

In production, we added a [custom nginx configuration](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/nginx.conf) to handle SSL, and route traffic to the pelias api running internally on port 4000.  A sample of the custom nginx config is saved in this repo for posterity as nginx.conf

The nginx config should be stored in /etc/nginx/conf.d/{productiondomain}.conf

This nginx config also proxies all requests that aren't API calls to the geosearch docs site, so that both the API and the docs can share the same production domain.
