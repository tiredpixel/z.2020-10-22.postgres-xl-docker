FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

RUN useradd postgres \
        -d /var/lib/postgres \
    && \
    mkdir -p \
        /usr/local/lib/postgres \
        /var/lib/postgres \
        /var/lib/postgres/.ssh \
    && \
    chown -R postgres:postgres \
        /usr/local/lib/postgres \
        /var/lib/postgres \
        /var/lib/postgres/.ssh

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
    chown postgres:postgres $TMP_PG \
    && \
    su postgres sh -c ' \
        git clone --depth=1 \
            -b XL9_5_STABLE \
            git://git.postgresql.org/git/postgres-xl.git \
            $TMP_PG \
        && \
        cd $TMP_PG \
        && \
        ./configure \
            --prefix /usr/local/lib/postgres \
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
    su postgres sh -c ' \
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

RUN yum -y install \
        epel-release \
    && \
    yum -y install \
        openssh-server \
        supervisor \
    && \
    yum -y autoremove \
        epel-release \
    && \
    yum clean all

WORKDIR /var/lib/postgres

RUN echo 'export PATH=$PATH:/usr/local/lib/postgres/bin' >> .bashrc

COPY postgres/init.sh .
RUN chown postgres:postgres init.sh

COPY supervisor/supervisord.conf /etc/supervisord.d/supervisord.conf

VOLUME \
    /etc/ssh \
    /var/lib/postgres \
    /var/lib/postgres/.ssh

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.d/supervisord.conf"]
