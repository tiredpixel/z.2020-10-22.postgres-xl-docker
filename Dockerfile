FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

ENV GOSU_VERSION 1.9
ENV GOSU_ARCH amd64
RUN set -x \
    && \
    curl -SL -o /usr/local/bin/gosu \
        "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$GOSU_ARCH" \
    && \
    curl -SL -o /usr/local/bin/gosu.asc \
        "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$GOSU_ARCH.asc" \
    && \
    export GNUPGHOME="$(mktemp -d)" \
    && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys \
        B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && \
    gpg --batch --verify \
        /usr/local/bin/gosu.asc \
        /usr/local/bin/gosu \
    && \
    rm -r \
        "$GNUPGHOME" \
        /usr/local/bin/gosu.asc \
    && \
    chmod +x \
        /usr/local/bin/gosu \
    && \
    gosu nobody true

RUN yum -y install \
        git \
        openssh-server \
    && \
    yum clean all

RUN yum -y install \
        automake \
        gcc \
        gcc-c++ \
        kernel-devel \
        make \
    && \
    yum clean all

RUN yum -y install \
        bison \
        flex \
        readline-devel \
        zlib-devel \
    && \
    yum clean all

RUN useradd postgres-xl \
        -d /var/lib/postgres-xl

RUN mkdir -p \
        /usr/local/src/postgres-xl/src \
        /var/lib/postgres-xl \
    && \
    chown -R postgres-xl:postgres-xl \
        /usr/local/src/postgres-xl/src \
        /var/lib/postgres-xl

VOLUME /var/lib/postgres-xl

USER postgres-xl

RUN git clone \
        -b XL9_5_STABLE \
        git://git.postgresql.org/git/postgres-xl.git \
        /usr/local/src/postgres-xl/src

WORKDIR /usr/local/src/postgres-xl/src

RUN ./configure \
        --prefix /usr/local/src/postgres-xl \
        --bindir /usr/local/bin \
    && \
    make \
    && \
    cd contrib/pgxc_ctl \
    && \
    make

USER root

RUN make install \
    && \
    cd contrib/pgxc_ctl \
    && \
    make install

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["bash"]

WORKDIR /var/lib/postgres-xl
