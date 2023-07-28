FROM httpd:2.4-bookworm

ARG PERL_VERSION=5.36.0

ENV MOD_PERL_VERSION 2.0.12
ENV MOD_PERL_CHECKSUM f5b821b59b0fdc9670e46ed0fcf32d8911f25126189a8b68c1652f9221eee269
ENV PERL_VERSION $PERL_VERSION

ENV PATH /opt/perl-$PERL_VERSION/bin:$PATH

COPY cpanfiles /cpanfiles

RUN apt-get update; \
    apt-get install -yq --no-install-recommends 
    perl \
    ca-certificates \
    curl \
    build-essential \
    libapr1-dev \
    libaprutil1-dev \
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
    rm -rf /var/lib/apt/lists/* && \
    cat /cpanfiles | xargs /opt/perl-$PERL_VERSION/bin/perl -MCPAN -e 'install($_) for @ARGV' && \
    curl --compressed -fsSL https://git.io/cpm | \
    /opt/perl-$PERL_VERSION/bin/perl - install -g \
    DBIx::Class::InflateColumn::Currency \
    SOAP::Lite
