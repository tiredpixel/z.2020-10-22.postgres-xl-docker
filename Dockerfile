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

RUN useradd postgres-xl \
        -d /var/lib/postgres-xl

RUN mkdir -p \
        /usr/local/lib/postgres-xl \
        /usr/local/src/postgres-xl \
        /var/lib/postgres-xl \
        /var/lib/postgres-xl/.ssh \
    && \
    chown -R postgres-xl:postgres-xl \
        /usr/local/lib/postgres-xl \
        /usr/local/src/postgres-xl \
        /var/lib/postgres-xl \
        /var/lib/postgres-xl/.ssh

USER postgres-xl

RUN git clone \
        -b XL9_5_STABLE \
        git://git.postgresql.org/git/postgres-xl.git \
        /usr/local/src/postgres-xl

WORKDIR /usr/local/src/postgres-xl

RUN ./configure \
        --prefix /usr/local/lib/postgres-xl \
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

USER postgres-xl

WORKDIR /var/lib/postgres-xl

RUN echo 'export PATH=$PATH:/usr/local/lib/postgres-xl/bin' >> .bashrc

USER root

COPY postgres-xl/init.sh .

RUN chown postgres-xl:postgres-xl init.sh

VOLUME \
    /var/lib/postgres-xl \
    /var/lib/postgres-xl/.ssh

COPY supervisor/supervisord.conf /etc/supervisord.d/supervisord.conf

WORKDIR /

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.d/supervisord.conf"]
