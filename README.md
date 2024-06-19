[![Docker-ghcr](https://github.com/daplaci/ohdsi-achilles/actions/workflows/docker-publish.yml/badge.svg?branch=main)](https://github.com/daplaci/ohdsi-achilles/actions/workflows/docker-publish.yml)

# Achilles (and DQD) Container Image

https://ohdsi.github.io/Achilles/articles/RunningAchilles.html

This repo contains the source code for edenceHealth's Docker image containing both [OHDSI Achilles](https://github.com/OHDSI/Achilles) and [OHDSI DataQualityDashboard](https://github.com/OHDSI/DataQualityDashboard). These two tools share some basic dependenices and have a similar use cases, so we bundle them together. The image adds a lightweight wrapper around  these tools which simplifies the process of calling them without a separate R installation.

For more information about the tools, see the following links:

* **OHDSI Achilles**
    * [source code](https://github.com/OHDSI/Achilles)
    * [documentation](https://ohdsi.github.io/Achilles/)
* **OHDSI DataQualityDashboard**
    * [source code](https://github.com/OHDSI/DataQualityDashboard)
    * [documentation](https://ohdsi.github.io/DataQualityDashboard/)

The container can be used and configured via command-line arguments (for example passed to `docker run`) and with environment variables.

## Configuration via Command-line Arguments

The following text is printed when invoking the container with the `-h` or `--help` arguments.

```
Achilles Wrapper

Usage:
  achilles.R [options]

General options:
  -h, --help              Show this help message.
  --num-threads=<n>       The number of threads to use when running achilles [default: 1]
  --optimize-atlas-cache  Enables the optimizeAtlasCache option to the achilles function
  --source-name=<name>    The source name used by the achilles function and included as part of the output path [default: NA]
  --timestamp=<time_str>  The timestamp-style string to use when calculating some file output paths. Defaults to a string derived from the current date & time. [default: AUTO]
  --skip-achilles         This option prevents Achilles from running, which can be useful for running the other utilities like the DQD Shiny App
  --output-base=<str>     The output path used by achilles [default: /output]
  --s3-target=<str>       Optional AWS S3 bucket path to sync with the output_base directory (for uploading results to S3)

CDM Options:
  --cdm-version=<semver>  Which standard version of the CDM to use [default: 5]

Schema Options:
  --cdm-schema=<name>      DB schema name for CDM data [default: public]
  --results-schema=<name>  DB schema name for results data [default: results]
  --vocab-schema=<name>    DB schema name for vocabulary data [default: vocabulary]

CDM DB Options:
  --db-dbms=<name>         The database management system for the CDM database [default: postgresql]
  --db-hostname=<name>     The hostname the database server is listening on [default: db]
  --db-port=<n>            The port the database server is listening on [default: 5432]
  --db-name=<name>         The name of the database on the database server [default: cdm]
  --db-username=<name>     The username to connect to the database server with [default: pgadmin]
  --db-password=<name>     The password to connect to the database server with [default: postgres]
  --db-extra-settings=<s>  Optional additional settings for the database driver (in JDBC connection format)
  --databaseconnector-jar-folder=<directory>  The path to the driver jar files used by the DatabaseConnector to connect to various DBMS [default: /usr/local/lib/DatabaseConnectorJars]

JSON Export Options:
  --json-export           Whether to run the Achilles exportToJson function
  --json-compress         JSON files should be compressed into one zip file
  --json-output-base=<DIRECTORY>  The output path used by exportToJson [default: /output]

DataQualityDashboard Options:
  --dqd                                Whether to run the DataQualityDashboard functions
  --dqd-sql-only                       Return DQD queries but do not run them
  --dqd-verbose                        Whether to write DataQualityDashboard info
  --dqd-json-file                      Whether to write a JSON file to disk
  --dqd-skip-db-write                  Skip writing results to the dqdashboard_results table in the results schema
  --dqd-check-names=<list>             Optional comma-separated list of check names to execute
  --dqd-check-levels=<list>            Comma-separated list of which DQ check levels to execute [default: TABLE,FIELD,CONCEPT]
  --dqd-exclude-tables=<list>          Comma-separated list of CDM tables to exclude from the checks
  --dqd-output-base=<DIRECTORY>        The output path used by the dqd functions [default: /output]
  --dqd-table-threshold-file=<file>    The optional location of the threshold file for evaluating the table checks; this is useful for overriding thresholds [default: default]
  --dqd-field-threshold-file=<file>    The optional location of the threshold file for evaluating the field checks; this is useful for overriding thresholds [default: default]
  --dqd-concept-threshold-file=<file>  The optional location of the threshold file for evaluating the concept checks; this is useful for overriding thresholds [default: default]

DQDWeb Options:
  --dqd-web                      Whether to run the DataQualityDashboard Shiny App
  --dqd-web-host=<hostname>      The network host address the DataQualityDashboard Shiny App should listen on  [default: 0.0.0.0]
  --dqd-web-port=<n>             The network port number the DataQualityDashboard Shiny App should listen on [default: 5641]
  --dqd-web-display-mode=<mode>  The Shiny App display.mode to use for the app, options include "showcase" or "normal" [default: normal]
  --dqd-web-input-json=<PATH>    Optionally override the input path used by the DataQualityDashboard Shiny App, by default this is derived from the output path by the DQD step [default: AUTO]
```

Running the container with the `--version` argument prints the version information:

```
edenceHealth Achilles/DQD Wrapper: 1.8 / Achilles: 1.7 / DataQualityDashboard: 1.4.1
```

## Configuration via Environment Variables

Each command line argument has an equivalent environment variable, to determine name of the environment variable:

1. start with the argument and remote the leading dashes
2. convert to uppper-case
3. replace dashes with underscores
4. boolean, flag-style arguments like `--skip-achilles` are assumed to be false, but they can be enabled by setting them with the values: `1`, `TRUE`, `YES`, `Y`, or `ON`

For example:
  * `--skip-achilles` becomes `SKIP_ACHILLES=1`
  * `--output-base=xyz` becomes `OUTPUT_BASE=xyz`
