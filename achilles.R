#!/usr/bin/Rscript
# Wrapper around OHDSI Achilles and OHDSI DataQualityDashboard
# edenceHealth NV <info@edence.health>

library(Achilles)
library(DataQualityDashboard)
library(docopt)
library(stringr)

wrapper_version_str <- "1.9"

'Achilles Wrapper

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
' -> doc_str


# Argument & environment variable parsing
parse_bool <- function(str_value) {
  toupper(str_value) %in% c("1", "TRUE", "YES", "Y", "ON")
}

version_str <- paste(
  "edenceHealth Achilles/DQD Wrapper:", wrapper_version_str,
  "/ Achilles:", packageVersion("Achilles"),
  "/ DataQualityDashboard:", packageVersion("DataQualityDashboard"),
  "\n"
)
args <- docopt(doc_str, version = version_str)
arg_defaults <- docopt(doc_str, args = c(), version = version_str)
arg_names <- names(args)

# environment variables like DQD_WEB_HOST override args like --dqd-web-host if
# the args have their default value. (user-set cli args must override envvars)
for (name in arg_names[!grepl("--", arg_names, fixed = TRUE)]) {
  envvar_name <- toupper(name)
  envvar_value <- Sys.getenv(c(envvar_name), NA)
  if (!is.na(envvar_value)) {
    if (args[[name]] == arg_defaults[[name]]) {
      if (typeof(arg_defaults[[name]]) == "logical") {
        print(str_glue("Importing logical envvar {envvar_name} into {name}"))
        args[[name]] <- parse_bool(envvar_value)
      } else {
        print(str_glue("Importing string envvar {envvar_name} into {name}"))
        args[[name]] <- envvar_value
      }
    } else {
      print(str_glue("Ignoring envvar {envvar_name}, CLI arg has precedence"))
    }
  }
}

# arg conversions: null to string
for (i in seq_along(args)) {
  if (is.null(args[[i]])) {
    args[[i]] <- ""
  }
}

# arg conversions: string to numeric
numeric_args <- c("db_port", "dqd_web_port", "num_threads")
for (name in numeric_args) {
  args[[name]] <- as.numeric(args[[name]])
}

# arg conversions: csv to vector
args$dqd_check_names <- unlist(strsplit(args$dqd_check_names, ","))
args$dqd_check_levels <- toupper(unlist(strsplit(args$dqd_check_levels, ",")))
args$dqd_exclude_tables <- unlist(strsplit(args$dqd_exclude_tables, ","))

# arg conversions: misc
if (args$timestamp == "AUTO") {
  args$timestamp <- strftime(Sys.time(), format = "%Y-%m-%dT%H.%M.%S")
}

# achilles::achilles wants a cdmVersion argument that doesn't include a patch
# version number: "Use major release number or minor number only (e.g. 5, 5.3)"
# this regex sub strips the patch number from a semver, we want the following:
# given: return
# 5     : 5
# 5.3   : 5.3
# 5.3.1 : 5.3
# NOTE: we're storing this in args for convenience so that it gets reported on
# startup, but we're not allowing it to be set directly by cli args nor envvars
args$short_cdm_version <- sub(
  "^(\\d+(?:\\.\\d+)?)(\\.\\d+)?$", "\\1",
  args$cdm_version,
  perl = TRUE
)

# print parsed runtime configuration to stdout at startup
filtered_args <- args
for (name in arg_names[grepl("password", arg_names, fixed = TRUE)]) {
  filtered_args[name] <- "REDACTED"
}
for (name in arg_names[grepl("--", arg_names, fixed = TRUE)]) {
  filtered_args[name] <- NULL
}
filtered_args["help"] <- NULL
cat("Runtime configuration:\n")
print(filtered_args)

valid_dbms <- list(
  "bigquery",
  "netezza",
  "oracle",
  "pdw",
  "postgresql",
  "redshift",
  "sql server",
  "sqlite",
  "duckdb"
)

# these dbms require the database name to be appended to the hostname
name_concat_dbms <- list(
  "netezza",
  "oracle",
  "postgresql",
  "redshift"
)

no_index_dbms <- list(
  "netezza",
  "redshift"
)

# ensure output paths
output_path <- file.path(
  args$output_base,
  args$source_name,
  args$timestamp
)
json_output_path <- file.path(
  args$json_output_base,
  args$source_name,
  args$timestamp
)
dqd_output_path <- file.path(
  args$dqd_output_base,
  args$source_name,
  args$timestamp
)
for (path in c(output_path, json_output_path, dqd_output_path)) {
  dir.create(path, showWarnings = FALSE, recursive = TRUE, mode = "0755")
}

# create database connection details
if (!args$skip_achilles || args$dqd) {
  if (!(args$db_dbms %in% valid_dbms)) {
    stop("Cannot proceed with invalid dbms: ", args$db_dbms)
  }

  # Some connection packages need the database on the server argument.
  # see ?createConnectionDetails after loading library(Achilles)
  if (args$db_dbms %in% name_concat_dbms) {
    server <- paste(args$db_hostname, args$db_name, sep = "/")
  } else {
    server <- args$db_hostname
  }

  extra_settings <- NULL
  if (args$db_extra_settings != "") {
    extra_settings <- args$db_extra_settings
  }

  connection_string <- NULL
  if (args$db_dbms == "sql server") {
    connection_string <- paste(
      "jdbc:",
      gsub("\\s", "", args$db_dbms),  # removing the space in "sql server"
      "://",
      args$db_hostname,
      ":",
      args$db_port,
      ";databaseName=",
      args$db_name,
      sep = ""
    )
  }
  connection_details <- createConnectionDetails(
    dbms = args$db_dbms,
    user = args$db_username,
    password = args$db_password,
    server = server,
    port = args$db_port,
    extraSettings = extra_settings,
    connectionString = connection_string,
    pathToDriver = args$databaseconnector_jar_folder
  )
}

# run achilles
if (!args$skip_achilles) {
    cat("---> Starting Achilles\n")

  # https://ohdsi.github.io/Achilles/reference/achilles.html
  achilles(
    connection_details,
    cdmDatabaseSchema = args$cdm_schema,
    resultsDatabaseSchema = args$results_schema,
    vocabDatabaseSchema = args$vocab_schema,
    sourceName = args$source_name,
    cdmVersion = args$short_cdm_version,
    createIndices = !(args$db_dbms %in% no_index_dbms),
    numThreads = args$num_threads,
    outputFolder = output_path,
    optimizeAtlasCache = args$optimize_atlas_cache
  )

  cat("---> Starting achilles exportToJson\n")
  if (args$json_export) {
    # Export Achilles results to output path in JSON format
    exportToJson(
      connection_details,
      cdmDatabaseSchema = args$cdm_schema,
      resultsDatabaseSchema = args$results_schema,
      vocabDatabaseSchema = args$vocab_schema,
      outputPath = json_output_path,
      compressIntoOneFile = args$json_compress
    )
  }
}

# run DataQualityDashboard
if (args$dqd) {
  cat("---> Starting DataQualityDashboard checks\n")

  output_file <- str_glue("DQD_Results{args$timestamp}.json")

  # https://ohdsi.github.io/DataQualityDashboard/reference/executeDqChecks.html
  executeDqChecks(
    connectionDetails = connection_details,
    cdmDatabaseSchema = args$cdm_schema,
    resultsDatabaseSchema = args$results_schema,
    vocabDatabaseSchema = args$vocab_schema,
    cdmSourceName = args$source_name,
    numThreads = args$num_threads,
    sqlOnly = args$dqd_sql_only,
    outputFolder = dqd_output_path,
    outputFile = output_file,
    verboseMode = args$dqd_verbose,
    writeToTable = !(args$dqd_skip_db_write),
    checkLevels = args$dqd_check_levels,
    checkNames = args$dqd_check_names,
    tablesToExclude = args$dqd_exclude_tables,
    cdmVersion = args$cdm_version,
    tableCheckThresholdLoc = args$dqd_table_threshold_file,
    fieldCheckThresholdLoc = args$dqd_field_threshold_file,
    conceptCheckThresholdLoc = args$dqd_concept_threshold_file
  )

  # This envvar sets the DQDViz input file
  Sys.setenv(jsonPath = output_file)
}

# run dqd_web (dqdviz)
if (args$dqd_web) {
  cat("---> Starting DataQualityDashboard web app\n")
  if (Sys.getenv("jsonPath") == "") {
    # DQDViz relies on the envvar jsonPath;
    # * if the envvar "jsonPath" is already set, use it
    # * else if args$dqd_web_input_json is not "AUTO", use its value
    # * otherwise find the most recently modified results file and use that
    if (args$dqd_web_input_json != "AUTO") {
      Sys.setenv(jsonPath = args$dqd_web_input_json)
    } else {
      # find the most recent results file if the user didn't specify one
      results_files <- file.info(list.files(
        path = args$dqd_output_base,
        pattern = "DQD_Results.+\\.json",
        all.files = TRUE,
        full.names = TRUE,
        recursive = TRUE,
        ignore.case = TRUE,
        include.dirs = FALSE,
        no.. = TRUE
      ))
      if (nrow(results_files) > 0) {
        newest <- rownames(
          results_files[
            with(results_files, order(as.POSIXct(mtime), decreasing = TRUE)),
          ]
        )[[1]]
        Sys.setenv(jsonPath = newest)
        print(str_glue("Using most recently modified results file: {newest}"))

      } else {
        print("WARNING: didn't find any results files for dqd_web to display!")
      }
    }
  }

  shiny::runApp(
    appDir = system.file("shinyApps", package = "DataQualityDashboard"),
    host = args$dqd_web_host,
    port = args$dqd_web_port,
    display.mode = args$dqd_web_display_mode,
    launch.browser = FALSE
  )
}

if (args$s3_target != "") {
  # https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/system
  system(
    paste("aws", "s3", "sync", sQuote(args$output_base), sQuote(args$s3_target)),
    intern = FALSE,
    ignore.stdout = FALSE,
    ignore.stderr = FALSE,
    wait = TRUE,
    input = NULL,
    show.output.on.console = TRUE,
    minimized = FALSE,
    invisible = TRUE,
    timeout = 0
  )
}
