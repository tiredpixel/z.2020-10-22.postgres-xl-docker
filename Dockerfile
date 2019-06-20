#===============================================================================
FROM debian:9

ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
ARG PG_USER_HEALTHCHECK=_healthcheck
#-------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y \
        bison \
        build-essential \
        daemontools \
        flex \
        libreadline-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN useradd ${PG_USER} -d ${PG_HOME} && \
    mkdir -p ${PG_LIB} ${PG_HOME} && \
    chown -R ${PG_USER}:${PG_USER} ${PG_LIB} ${PG_HOME}
#-------------------------------------------------------------------------------
WORKDIR ${PG_HOME}

COPY --chown=postgres:postgres lib/ ./lib/
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}/lib/postgres-xl

RUN ./configure --prefix ${PG_LIB} && \
    make
#-------------------------------------------------------------------------------
USER root

RUN make install
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}

ENV PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data

COPY bin/* ${PG_LIB}/bin/
COPY ci/ ./ci/

VOLUME ${PG_HOME}

ENV PG_USER_HEALTHCHECK ${PG_USER_HEALTHCHECK}
#===============================================================================
