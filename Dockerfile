#===============================================================================
FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

ARG DOCKER_BIN=/usr/local/bin
ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
ARG PG_USER_HEALTHCHECK=_healthcheck
#-------------------------------------------------------------------------------
RUN yum -y install \
        automake \
        bison \
        flex \
        gcc \
        gcc-c++ \
        git \
        kernel-devel \
        make \
        readline-devel \
        zlib-devel \
    && \
    yum clean all

RUN useradd ${PG_USER} -d ${PG_HOME} \
    && \
    mkdir -p ${PG_LIB} ${PG_HOME} \
    && \
    chown -R ${PG_USER}:${PG_USER} ${PG_LIB} ${PG_HOME}

WORKDIR ${PG_HOME}

COPY . .
RUN chown -R ${PG_USER}:${PG_USER} ${PG_HOME}
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}/lib/postgres-xl

RUN ./configure --prefix ${PG_LIB} \
    && \
    make \
    && \
    cd contrib/pgxc_ctl \
    && \
    make
#-------------------------------------------------------------------------------
USER root

RUN make install \
    && \
    cd contrib/pgxc_ctl \
    && \
    make install
#-------------------------------------------------------------------------------
USER ${PG_USER}

WORKDIR ${PG_HOME}

ENV PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data

COPY bin/* ${DOCKER_BIN}/

VOLUME ${PG_HOME}

ENV PG_USER_HEALTHCHECK ${PG_USER_HEALTHCHECK}
#===============================================================================
