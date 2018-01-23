
Dockerfiles for NYC Geosearch Services.

NYC Geosearch is an JSON API for autocomplete geocoding of NYC addresses, built on the open source [Pelias](https://github.com/pelias/pelias) geocoder and [NYC's Property Address Database (PAD)](https://www1.nyc.gov/site/planning/data-maps/open-data.page)

## Overview

<img width="751" alt="screen shot 2018-01-18 at 1 12 07 pm" src="https://user-images.githubusercontent.com/1833820/35113991-48b04abc-fc51-11e7-8a4f-7664ddba6492.png">


These dockerfiles allow for quickly standing up all of the services that work together to run the pelias geocoder, and is used in both production and development.  These include:

- pelias api - The node.js app that handles HTTP requests
- elasticsearch - the database where all address results are stored
- placeholder -
- pip service - a service that provides point-in-polygon lookups, providing administrative boundaries that a point falls within (borough, city, state, etc)

This repo (and readme) serves as "home base" for the GeoSearch project, as the dockerfiles tie everything together.  Other relevant code for our Pelias deployment:
- [geosearch-pad-normalize](https://github.com/NYCPlanning/labs-geosearch-pad-normalize) - an R script that starts with the raw Property Address Database, and interpolates valid address ranges.
- [geosearch-pad-importer](https://github.com/NYCPlanning/labs-geosearch-pad-importer) - a Pelias importer for normalized NYC PAD data.
- [geosearch-docs](https://github.com/NYCPlanning/labs-geosearch-docs) - an interactive documentation site for the Geosearch API
- [labs-geosearch-acceptance-tests](https://github.com/NYCPlanning/labs-geosearch-acceptance-tests) - nyc-specific test suite for geosearch

Docker Compose allows us to quickly spin up the pelias services we need, and run scripts manually in the containers.  It also makes use of volumes and internal hostnames so the various services can communicate with each other.  See below for the commands necessary to get started.

For more information on Pelias services, including many which we are not using here at City Planning, check out this [self-contained workshop](how_to_guide.pdf). This is the tutorial that got us started, and we recommend anyone working with Pelias start here.

## Running Pelias Services
In both production and development, several Pelias services need to be up and running before address data can be imported in the database. Before any data are imported, either locally or in production, you should have mastery of the long-running Pelias services outlined here, and how to get them started/restarted.

### Config-Driven
Much of this environment is config-driven, and the two files you should pay attention to are:
- [docker-compose.yml](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/docker-compose.yml) - configurations for each of the named services, including which docker image to run, which volumes, to use, etc
- [pelias.json](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/pelias.json) - a common config file used by all of the pelias services.  This identifies the hostnames for various services, and importer-specific configuration.

### WhosOnFirst Data

Aside from the addresses that will be imported into the database, Pelias needs administrative boundary data.  Mapzen maintains a global dataset of admin boundaries in the [whosonfirst](https://whosonfirst.mapzen.com/) project, but for our purposes we only need admin boundaries for New York City (importPlace 85977539).  

To download whosonfirst data for a smaller slice of the planet, we add config to `pelias.json`, and then run a script that reads the config and downloads the data via the whosonfirst API.

In `pelias.json`, add `whosonfirst` to the `imports` key, with `importPlace` specific to NYC:
```
"imports": {
  "whosonfirst": {
    "datapath": "/data/whosonfirst",
    "importVenues": false,
    "importPostalcodes": true,
    "importPlace": "85977539",
    "api_key": "{mapzenkey}"
  }
}
```
Then, run:

`docker-compose run --rm whosonfirst npm run download` - downloads the whosonfirst data for the `importPlace` specified in `pelias.json`.  The data is now in `/tmp/whosonfirst`, and is ready to be used by the pip-service.

### Pull Images
Before you can run the pelias services via docker, you must first get all of the images.  The Pelias team has pre-built them and hosted them on dockerhub, so we can skip the time-consuming step of building the images manually.

`docker-compose pull` will get all of the pelias images from dockerhub.

For our PAD importer, there is no pre-built image, and how you include it is different in production and development.  See below for how to get the PAD importer working in each environment.

### elasticsearch database
To start a new database:

`docker-compose up -d elasticsearch` - spin up an empty elasticsearch database
`docker-compose run --rm schema npm run create_index` - create the `pelias` index

The database is now ready to receive data from an importer.

### pip-service
The PIP service depends on data in a directory called `whosonfirst` in the shared data directory.  This will contain all of the possible lookup geometries for various administrative levels.  

`docker-compose up -d pip-service`

If the pip service is running properly with nyc data, you should see admin boundaries results if you load `http://localhost:4200/-74.00274/40.71666?layers=neighbourhood,borough,locality,localadmin,county,macrocounty,region,macroregion,dependency,country`

The pip service is used by the pad importer, and appends admin boundaries to each record before pushing it to the database.  It's critical that it is up and running with the appropriate whosonfirst data before importing.

### pelias api
`docker-compose up -d api`

You should be able to query the API at `http://localhost:4000/v1/autocomplete?text={sometext}`, but there's no data in the database yet!

### PAD importer

The PAD importer serves two functions, it downloads the latest normalized PAD dataset, and imports each row into elasticsearch.  Each of these is run manually via an npm command.

#### Development
Our development workflow consists of editing geosearch-pad-importer code locally, running its npm scripts locally, all of which will interact with pelias services that were stood up with docker-compose commands in this repo.  

The geosearch-pad-importer contains its own `pelias.json` for local development.  This contains references to services that work outside of the docker-compose world.  

With the rest of the pelias services up and running, we can manually run the pad importer's npm scripts, specifying the development `pelias.json` as an environment variable:
`PELIAS_CONFIG=./pelias.json npm run download` - downloads the latest normalized PAD data.
`PELIAS_CONFIG=./pelias.json npm start` - starts the import (this can take over an hour)

Once the import starts, you can check the database to see that things are being added properly:
`curl http://localhost:9200/_cat/indices?v` - Shows document counts, etc, for the `pelias` index.
`curl http://localhost:9200/_search?pretty=true&q=*:*&size=50` - returns the first 50 results in the `pelias` index.

#### Production
For our PAD importer, there is no pre-built image.  `docker-compose.yml` contains a reference to the github repository.
`docker-compose build nycpad` will download this repository and build it into a docker image.

The bash script `import-pad.sh` automates the import, using elasticsearch aliases to import data without affecting the current live database:
- Modify `pelias.json` to set a unique `indexName` for the new pelias import. (The indexName will be `pelias_{unixepoch}`)  
- Run `docker-compose run --rm schema npm run create_index` to make a new index with the unique name.
- Run `docker-compose run --rm nycpad npm run download` to download the latest normalized pad data.
- Run `docker-compose run --rm nycpad npm start` to start the download
- Run a curl command to clear all `pelias` aliases in the database
- Run a curl command to assign the alias `pelias` our uniquely named index.

On subsequent runs, the process repeats.  The pelias API is just looking for an index named `pelias`, and gets data back for whichever index is properly aliased.

The full PAD import takes over an hour (and growing!), but results will be available immediately via the API.

## Production Domain

In production, we added a [custom nginx configuration](https://github.com/NYCPlanning/labs-geosearch-dockerfiles/blob/master/nginx.conf) to handle SSL, and route traffic to the pelias api running internally on port 4000.  A sample of the custom nginx config is saved in this repo for posterity as nginx.conf

The nginx config should be stored in /etc/nginx/conf.d/{productiondomain}.conf

This nginx config also proxies all requests that aren't API calls to the geosearch docs site, so that both the API and the docs can share the same production domain.
