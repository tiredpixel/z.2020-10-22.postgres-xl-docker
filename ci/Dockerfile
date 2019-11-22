#===============================================================================
FROM debian:9

ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
#-------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libreadline-dev \
        rsync \
        netcat && \
    rm -rf /var/lib/apt/lists/*

RUN useradd ${PG_USER} -d ${PG_HOME} && \
    mkdir -p ${PG_LIB} ${PG_HOME} && \
    chown -R ${PG_USER}:${PG_USER} ${PG_LIB} ${PG_HOME}
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}

ENV PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data \
    PG_USER_HEALTHCHECK=_healthcheck

COPY postgresql ${PG_LIB}

VOLUME ${PG_HOME}
#===============================================================================
