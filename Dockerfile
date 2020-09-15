FROM centos:7

# Install build packages
RUN yum update -y && \
    yum install -y epel-release && \
    yum install -y \
    # Generic build packages
    autoconf \
    automake \
    gcc \
    gcc-c++ \
    git \
    libtool \
    make \
    nasm \
    perl-devel \
    zlib-devel \
    tar \
    nc \
    xz \
    python3 \
    python-pip3 \
    # Ruby
    libyaml-devel \
    openssl-devel \
    libreadline-dev \
    zlib-devel && \
    yum clean all

RUN pip3 install boto3

ARG RUBY_MAJOR=2.7
ARG RUBY_VERSION=2.7.1
ARG RUBY_DOWNLOAD_SHA256=d418483bdd0000576c1370571121a6eb24582116db0b7bb2005e90e250eae418

# Ruby
ENV PATH=/opt/ruby-${RUBY_MAJOR}/bin:$PATH
RUN DIR=$(mktemp -d) && cd ${DIR}

RUN curl -fOLs https://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz && \
    echo "${RUBY_DOWNLOAD_SHA256}  ruby-${RUBY_VERSION}.tar.gz" > sha256check.txt && \
    sha256sum --quiet --strict --check sha256check.txt && \
    tar xzf ruby-$RUBY_VERSION.tar.gz && \
    cd ruby-$RUBY_VERSION && \
    ./configure --prefix=/opt/ruby-${RUBY_VERSION} --bindir=/opt/ruby-${RUBY_VERSION}/bin --disable-install-doc && \
    make -j 8 && \
    make install && \
    make distclean && \
    rm -rf ${DIR} && \
    cd /opt/ && ln -sfn ruby-${RUBY_VERSION} ruby-${RUBY_MAJOR}

RUN gem update --system
RUN gem install bundler -v 2.1.4 --no-document -f
RUN bundle config --global jobs 7

RUN pip3 install -q --upgrade pip\<10

# Install supervisord
RUN pip3 install supervisor

# Copy the gem related stuff now, but wait for the application code.
COPY ./src/Gemfile /home/download_mover/app/src/
WORKDIR /home/download_mover/app/src
RUN bundle install && \
    bundle clean --force

# Copy entrypoint and supporting files
# Setup the entry point file for easier startup
COPY ./files_docker/docker-entrypoint.sh /
RUN chmod a+x /docker-entrypoint.sh

# Finally, copy supervisord.conf, app
RUN mkdir -p /var/run/supervisor
COPY ./files_docker/supervisord.conf /etc/supervisord.conf
COPY ./src/ /home/download_mover/app/src
RUN chmod +x /home/download_mover/app/src/worker.rb

RUN mkdir -p /var/log/download_mover

VOLUME ["/var/log/download_mover", "/tmp"]

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
