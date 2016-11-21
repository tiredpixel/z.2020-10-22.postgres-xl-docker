FROM centos:7

MAINTAINER tiredpixel <tiredpixel@posteo.de>

RUN yum -y install \
        epel-release \
    && \
    yum clean all

RUN yum -y install \
        git \
        openssh-server \
        supervisor \
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

RUN useradd postgres \
        -d /var/lib/postgres

RUN mkdir -p \
        /usr/local/lib/postgres \
        /usr/local/src/postgres \
        /var/lib/postgres \
        /var/lib/postgres/.ssh \
    && \
    chown -R postgres:postgres \
        /usr/local/lib/postgres \
        /usr/local/src/postgres \
        /var/lib/postgres \
        /var/lib/postgres/.ssh

USER postgres

RUN git clone \
        -b XL9_5_STABLE \
        git://git.postgresql.org/git/postgres-xl.git \
        /usr/local/src/postgres

WORKDIR /usr/local/src/postgres

RUN ./configure \
        --prefix /usr/local/lib/postgres \
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

USER postgres

WORKDIR /var/lib/postgres

RUN echo 'export PATH=$PATH:/usr/local/lib/postgres/bin' >> .bashrc

USER root

COPY postgres/init.sh .

RUN chown postgres:postgres init.sh

VOLUME \
    /etc/ssh \
    /var/lib/postgres \
    /var/lib/postgres/.ssh

COPY supervisor/supervisord.conf /etc/supervisord.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.d/supervisord.conf"]
