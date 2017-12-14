FROM buildpack-deps:jessie-scm

# A few problems with compiling Java from source:
#  1. Oracle.  Licensing prevents us from redistributing the official JDK.
#  2. Compiling OpenJDK also requires the JDK to be installed, and it gets
#       really hairy.
RUN echo 'deb http://mirrors.aliyun.com/debian jessie main non-free contrib\n' > /etc/apt/sources.list
RUN echo 'deb http://mirrors.aliyun.com/debian jessie-proposed-updates main non-free contrib\n' >> /etc/apt/sources.list
RUN echo 'deb http://mirrors.aliyun.com/debian-security/ jessie/updates non-free contrib\n' >> /etc/apt/sources.list
RUN echo 'deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/debian jessie edge\n' >> /etc/apt/sources.list

RUN echo 'deb http://mirrors.ustc.edu.cn/ubuntu/ trusty main restricted universe multiverse\n' >> /etc/apt/sources.list
RUN echo 'deb-src http://mirrors.ustc.edu.cn/ubuntu/ trusty main restricted universe multiverse\n' >> /etc/apt/sources.list

RUN echo 'deb http://mirrors.ustc.edu.cn/ubuntu/ trusty-security main restricted universe multiverse\n' >> /etc/apt/sources.list
RUN echo 'deb-src http://mirrors.ustc.edu.cn/ubuntu/ trusty-security main restricted universe multiverse\n' >> /etc/apt/sources.list

RUN echo 'deb http://mirrors.ustc.edu.cn/ubuntu/ trusty-updates main restricted universe multiverse\n' >> /etc/apt/sources.list
RUN echo 'deb-src http://mirrors.ustc.edu.cn/ubuntu/ trusty-updates main restricted universe multiverse\n' >> /etc/apt/sources.list

RUN echo 'deb http://mirrors.ustc.edu.cn/ubuntu/ trusty-backports main restricted universe multiverse\n' >> /etc/apt/sources.list
RUN echo 'deb-src http://mirrors.ustc.edu.cn/ubuntu/ trusty-backports main restricted universe multiverse\n' >> /etc/apt/sources.list

RUN echo "APT::Get::AllowUnauthenticated 1 ;\n" >> /etc/apt/apt.conf

RUN gpg --keyserver pgpkeys.mit.edu --recv-key 7EA0A9C3F273FCD8
RUN gpg -a --export  7EA0A9C3F273FCD8 | apt-key add -

# Add the "PHP 7" ppa
RUN echo "deb http://ppa.launchpad.net/ondrej/php/ubuntu trusty main\n" >> /etc/apt/sources.list
RUN echo "deb-src http://ppa.launchpad.net/ondrej/php/ubuntu trusty main\n" >> /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E5267A6C 
# Install "PHP Extentions", "libraries", "Software's"
RUN apt-get update && \
    apt-get install -y --force-yes \
        libssl1.0.0 \
        libcurl3 \
        libgd3 \
        libjpeg8 \
        php-common \
        php7.1-cli \
        php7.1-common \
        php7.1-curl \
        php7.1-json \
        php7.1-xml \
        php7.1-mbstring \
        php7.1-mcrypt \
        php7.1-mysql \
        php7.1-pgsql \
        php7.1-sqlite \
        php7.1-sqlite3 \
        php7.1-zip \
        php7.1-bcmath \
        php7.1-memcached \
        php7.1-gd \
        php7.1-dev \
        pkg-config \
        libcurl4-openssl-dev \
        libedit-dev \
        libssl-dev \
        libxml2-dev \
        xz-utils \
        libsqlite3-dev \
        sqlite3 \
        curl \
        bzip2 \
        unzip \
        vim \
        xz-utils && rm -rf /var/lib/apt/lists/*

RUN echo 'deb http://mirrors.163.com/debian/ jessie-backports main non-free contrib\n' > /etc/apt/sources.list.d/jessie-backports.list
RUN echo 'deb-src http://mirrors.163.com/debian/ jessie-backports main non-free contrib\n' >> /etc/apt/sources.list.d/jessie-backports.list

# Default to UTF-8 file.encoding
ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
    echo '#!/bin/sh'; \
    echo 'set -e'; \
    echo; \
    echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
  } > /usr/local/bin/docker-java-home \
  && chmod +x /usr/local/bin/docker-java-home

# do some fancy footwork to create a JAVA_HOME that's cross-architecture-safe
RUN ln -svT "/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)" /docker-java-home
ENV JAVA_HOME /docker-java-home

ENV JAVA_VERSION 8u131
ENV JAVA_DEBIAN_VERSION 8u131-b11-1~bpo8+1

# see https://bugs.debian.org/775775
# and https://github.com/docker-library/java/issues/19#issuecomment-70546872
ENV CA_CERTIFICATES_JAVA_VERSION 20161107~bpo8+1

RUN set -ex; \
  \
  apt-get update; \
  apt-get install -y --force-yes \
    openjdk-8-jdk="$JAVA_DEBIAN_VERSION" \
    ca-certificates-java="$CA_CERTIFICATES_JAVA_VERSION" \
  ; \
  rm -rf /var/lib/apt/lists/*; \
  \
# verify that "docker-java-home" returns what we expect
  [ "$(readlink -f "$JAVA_HOME")" = "$(docker-java-home)" ]; \
  \
# update-alternatives so that future installs of other OpenJDK versions don't change /usr/bin/java
  update-alternatives --get-selections | awk -v home="$(readlink -f "$JAVA_HOME")" 'index($3, home) == 1 { $2 = "manual"; print | "update-alternatives --set-selections" }'; \
# ... and verify that it actually worked for one of the alternatives we care about
  update-alternatives --query java | grep -q 'Status: manual'

# see CA_CERTIFICATES_JAVA_VERSION notes above
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

#####################################
# Composer:
#####################################

# Install composer and add its bin to the PATH.
RUN curl -s http://getcomposer.org/installer | php && \
    echo "export PATH=${PATH}:/var/www/vendor/bin" >> ~/.bashrc && \
    mv composer.phar /usr/local/bin/composer

# Source the bash
RUN . ~/.bashrc
RUN echo "alias ll='ls -l'" >> ~/.bashrc
RUN composer config -g repo.packagist composer https://packagist.phpcomposer.com

#####################################
# nodejs:
#####################################

# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
  ; do \
    gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
  done

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 8.1.3

RUN curl -SLO "https://mirrors.ustc.edu.cn/node/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO --compressed "https://mirrors.ustc.edu.cn/node/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

RUN npm install -g cnpm --registry=https://registry.npm.taobao.org \