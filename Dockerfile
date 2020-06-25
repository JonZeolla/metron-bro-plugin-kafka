#
#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
ARG FROM_IMAGE="centos"
ARG FROM_IMAGE_TAG="8"

FROM "${FROM_IMAGE}":"${FROM_IMAGE_TAG}"

# upgrade existing dnf packages
RUN dnf -y upgrade-minimal && \
    dnf -y clean all

# install powertools for libpcap-devel
RUN dnf -y install 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled PowerTools && \
    dnf -y clean all

# install zeek prereqs
RUN dnf -y install --setopt=install_weak_deps=False epel-release \
                                                    cmake \
                                                    make \
                                                    gcc \
                                                    gcc-c++ \
                                                    flex \
                                                    bison \
                                                    libpcap \
                                                    libpcap-devel \
                                                    openssl-devel \
                                                    python3 \
                                                    platform-python-devel \
                                                    swig \
                                                    zlib-devel \
                                                    git && \
    dnf -y clean all

# install zeek
WORKDIR /root
RUN git clone https://github.com/zeek/zeek
WORKDIR zeek/
ARG ZEEK_VERSION
RUN git checkout "v${ZEEK_VERSION}" && \
    git submodule update --init --recursive && \
    ./configure && \
    make && \
    make install && \
    make clean
ENV PATH="${PATH}:/usr/local/zeek/bin:/usr/bin"

# install librdkafka prereqs
RUN dnf -y install --setopt=install_weak_deps=False cyrus-sasl \
                                                    cyrus-sasl-devel \
                                                    cyrus-sasl-gssapi && \
    dnf clean all

# install librdkafka
WORKDIR /root
ARG LIBRDKAFKA_VERSION
RUN curl -L "https://github.com/edenhill/librdkafka/archive/v${LIBRDKAFKA_VERSION}.tar.gz" | tar xvz
WORKDIR "librdkafka-${LIBRDKAFKA_VERSION}/"
RUN ./configure --enable-sasl && \
    make && \
    make install

# install and configure zkg
WORKDIR /root
COPY e2e/containers/zeek/requirements.txt requirements.txt
RUN dnf -y install --setopt=install_weak_deps=False python3-pip \
                                                    which && \
    dnf clean all && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt && \
    zkg autoconfig

# install the plugin
WORKDIR /root
COPY . code
ARG PLUGIN_VERSION
RUN ./code/e2e/containers/zeek/build_plugin.sh --plugin-version="${PLUGIN_VERSION}"
RUN ./code/e2e/containers/zeek/configure_plugin.sh

# install prereqs for the e2e tests and other misc helper packages
RUN dnf -y install 'dnf-command(config-manager)' && \
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf -y install --setopt=install_weak_deps=False jq \
                                                    screen \
                                                    tree \
                                                    vim && \
    dnf -y install --setopt=install_weak_deps=False docker-ce --nobest && \
    dnf -y clean all

# copy in the .screenrc
COPY e2e/containers/zeek/.screenrc /root

ENTRYPOINT ["/root/code/e2e/containers/zeek/zeek_entrypoint.sh"]

