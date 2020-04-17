#===============================================================================
# FROMFREEZE docker.io/library/debian:9
FROM docker.io/library/debian@sha256:d844caef45253dab4cb7543b5781f529c1c3f140fcf9cd6172e1d6cb616a51c3

ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
#-------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bison \
        build-essential \
        daemontools \
        flex \
        libreadline-dev \
        rsync \
        netcat \
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
    make && \
    cd contrib/pgxc_monitor && \
    make
#-------------------------------------------------------------------------------
USER root

RUN make install && \
    cd contrib/pgxc_monitor && \
    make install
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}

ENV PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data \
    PG_USER_HEALTHCHECK=_healthcheck

COPY bin/* ${PG_LIB}/bin/
COPY ci/ ./ci/

VOLUME ${PG_HOME}
#===============================================================================
