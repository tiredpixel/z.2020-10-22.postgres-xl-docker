#===============================================================================
FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

ARG PG_HOME=/var/lib/postgresql
ARG PG_LIB=/usr/local/lib/postgresql
ARG PG_USER=postgres
ARG SRC_BRANCH=XL9_5_STABLE
ARG SRC_REPO=git://git.postgresql.org/git/postgres-xl.git
#-------------------------------------------------------------------------------
RUN useradd ${PG_USER} \
        -d ${PG_HOME} \
    && \
    mkdir -p \
        ${PG_LIB} \
        ${PG_HOME} \
    && \
    chown -R ${PG_USER}:${PG_USER} \
        ${PG_LIB} \
        ${PG_HOME}

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
    export TMP_PG=$(mktemp -d) \
    && \
    chown ${PG_USER}:${PG_USER} $TMP_PG \
    && \
    su ${PG_USER} sh -c ' \
        git clone --depth=1 \
            -b ${SRC_BRANCH} \
            ${SRC_REPO} \
            $TMP_PG \
        && \
        cd $TMP_PG \
        && \
        ./configure \
            --prefix ${PG_LIB} \
        && \
        make \
        && \
        cd contrib/pgxc_ctl \
        && \
        make \
    ' \
    && \
    cd $TMP_PG \
    && \
    make install \
    && \
    cd contrib/pgxc_ctl \
    && \
    make install \
    && \
    su ${PG_USER} sh -c ' \
        rm -rf $TMP_PG \
    ' \
    && \
    yum -y autoremove \
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

USER ${PG_USER}

ENV \
    PATH=${PG_LIB}/bin:$PATH \
    PGDATA=${PG_HOME}/data

WORKDIR ${PG_HOME}
#===============================================================================
ENV \
    GTM_PROXY_HOST=0.0.0.0 \
    GTM_PROXY_PORT=6666 \
    GTM_PROXY_NODE=gtm-proxy-1 \
    GTM_HOST=0.0.0.0 \
    GTM_PORT=6666
#-------------------------------------------------------------------------------
RUN initgtm -Z gtm_proxy -D ${PGDATA}

VOLUME ${PGDATA}

CMD gtm_proxy -D ${PGDATA} \
    -h ${GTM_PROXY_HOST} \
    -p ${GTM_PROXY_PORT} \
    -i ${GTM_PROXY_NODE} \
    -s ${GTM_HOST} \
    -t ${GTM_PORT} \
    -l /dev/stdout

EXPOSE ${GTM_PROXY_PORT}
