FROM alpine:3.11 as intermediate

ARG PRODUCCIO
ARG B3_DB_PASSWORD
ARG B3_DB_USER
ARG LDAP_SERVER
ARG LDAP_USER
ARG LDAP_PASSWORD
ARG LS_SERVER
ARG LS_USER
ARG LS_PASSWORD
ARG SOA_USER
ARG SOA_PASSWORD
ARG TOKEN_HORARIS_UPC

COPY ./etsetb.conf /etc/etsetb.conf
COPY ./b3.conf /etc/si_bd/b3.conf

RUN apk update && \
    apk add \
    make \
    perl \
    gettext \
    moreutils \
    bash && \
    envsubst < /etc/etsetb.conf | sponge /etc/etsetb.conf && \
    chmod 640 /etc/etsetb.conf && \
    envsubst < /etc/si_bd/b3.conf | sponge /etc/si_bd/b3.conf

FROM httpd:2.4-bookworm

ARG PERL_VERSION=5.36.0

ENV MOD_PERL_VERSION 2.0.12
ENV MOD_PERL_CHECKSUM f5b821b59b0fdc9670e46ed0fcf32d8911f25126189a8b68c1652f9221eee269
ENV PERL_VERSION $PERL_VERSION

ENV PATH /opt/perl-$PERL_VERSION/bin:$PATH

RUN apt-get update; \
    apt-get install -yq --no-install-recommends perl ca-certificates curl build-essential libapr1-dev libaprutil1-dev && \
    curl -sfL https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - $PERL_VERSION /opt/perl-$PERL_VERSION/ -Duseshrplib -Duseithreads -j "$(nproc)" && \
    curl -sfLO https://dlcdn.apache.org/perl/mod_perl-$MOD_PERL_VERSION.tar.gz && \
    echo "$MOD_PERL_CHECKSUM *mod_perl-$MOD_PERL_VERSION.tar.gz" | sha256sum -c && \
    tar xzf mod_perl-$MOD_PERL_VERSION.tar.gz && \
    cd mod_perl-$MOD_PERL_VERSION && \
    /opt/perl-$PERL_VERSION/bin/perl Makefile.PL && \
    make -j "$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf mod_perl-$MOD_PERL_VERSION mod_perl-$MOD_PERL_VERSION.tar.gz && \
    apt-get remove -yq perl build-essential && \
    apt-get autoremove -yq && \
    rm -rf /var/lib/apt/lists/*

COPY --from=intermediate /etc/etsetb.conf /etc/etsetb.conf
COPY --from=intermediate /etc/si_bd /etc/si_bd
COPY web_etsetb /usr/local/apache2/htdocs/web_etsetb
COPY perl_etsetb /root/perl_etsetb
COPY cpanfiles /cpanfiles

RUN apt-get update; \
    apt-get -y install \
    cpanminus \
    default-mysql-client \
    default-libmysqlclient-dev \
    default-mysql-client-core \
    gcc \
    libdb-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    nfs-common \
    openssl \
    perlmagick \
    tar \
    zlib1g-dev && \
    cat /cpanfiles | xargs /opt/perl-$PERL_VERSION/bin/perl -MCPAN -e 'install($_) for @ARGV'

RUN curl --compressed -fsSL https://git.io/cpm | \
    /opt/perl-$PERL_VERSION/bin/perl - install -g \
    DBIx::Class::InflateColumn::Currency \
    SOAP::Lite && \
    cd /root/perl_etsetb && perl instala.pl && \
    ln -sf /dev/stderr /usr/local/apache2/logs/error_log && \
    ln -sf /dev/stdout /usr/local/apache2/logs/access_log

COPY ./my-httpd.conf /usr/local/apache2/conf/httpd.conf
ADD httpd-mod_perl.conf /usr/local/apache2/conf/extra/

EXPOSE 8080
CMD ["httpd-foreground"]
