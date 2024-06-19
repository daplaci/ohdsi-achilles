FROM edence/rcore:1
LABEL maintainer="edenceHealth <info@edence.health>"

RUN set -eux; \
  export \
    AG="apt-get -yq" \
    DEBIAN_FRONTEND="noninteractive" \
  ; \
  apt-get -yq update; \
  apt-get -yq install --no-install-recommends \
    awscli \
    apt-file \
  ; \
  $AG autoremove; \
  $AG autoclean; \
  $AG clean; \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/lib/dpkg/*-old \
    /var/cache/debconf/*-old \
    /var/cache/apt \
  ;

COPY renv.lock ./

# Set flags for compilation in R
RUN mkdir -p ~/.R && echo "MAKEFLAGS = -j6" >> ~/.R/Makevars;
RUN --mount=type=cache,sharing=private,target=/renv_cache \
  set -eux; \
  Rscript \
  -e 'renv::activate("/app");' \
  -e 'renv::restore(exclude = "duckdb");' \
;

# Need ALL_CXXFLAGS for duckdb only, see: https://duckdb.org/docs/dev/building/troubleshooting
RUN echo "ALL_CXXFLAGS = $(PKG_CXXFLAGS) -fPIC $(SHLIB_CXXFLAGS) $(CXXFLAGS)" >> ~/.R/Makevars;
RUN --mount=type=cache,sharing=private,target=/renv_cache \
  set -eux; \
  Rscript \
  -e 'renv::activate("/app");' \
  -e 'renv::restore(packages = "duckdb");' \
  -e 'renv::isolate();' \
;

# https://ohdsi.github.io/DatabaseConnector/articles/Connecting.html#the-jar-folder
ENV DATABASECONNECTOR_JAR_FOLDER="/usr/local/lib/DatabaseConnectorJars"
RUN set -eux; \
  Rscript -e 'DatabaseConnector::downloadJdbcDrivers("all")';

WORKDIR /output

COPY ["achilles.R", "entrypoint.sh", "/app/"]
USER nonroot

ENTRYPOINT ["/app/entrypoint.sh"]
