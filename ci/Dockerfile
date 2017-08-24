#===============================================================================
FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
ARG PG_USER_HEALTHCHECK=_healthcheck
#-------------------------------------------------------------------------------
RUN useradd ${PG_USER} -d ${PG_HOME} \
    && \
    mkdir -p ${PG_LIB} ${PG_HOME} \
    && \
    chown -R ${PG_USER}:${PG_USER} ${PG_LIB} ${PG_HOME}
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}

ENV PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data

COPY lib/postgresql/* ${PG_LIB}/

VOLUME ${PG_HOME}

ENV PG_USER_HEALTHCHECK ${PG_USER_HEALTHCHECK}
#===============================================================================
