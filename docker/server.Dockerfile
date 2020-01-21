ARG UBUNTU_VERSION=18.04
FROM        ubuntu:${UBUNTU_VERSION} as test_appserver_build_env

ARG GRPC_RELEASE_TAG=v1.22.0
ARG ENABLE_LLVM="True"
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    #TERM=screen \
    PATH=/usr/local/bin/:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    GIT_AUTHOR_NAME=$GIT_USERNAME \
    GIT_AUTHOR_EMAIL=$GIT_EMAIL \
    GIT_COMMITTER_NAME=$GIT_USERNAME \
    GIT_COMMITTER_EMAIL=$GIT_EMAIL \
    WDIR=/opt
RUN mkdir -p $WDIR
ARG APT="apt-get -qq --no-install-recommends"
# docker build --build-arg NO_SSL="False" APT="apt-get -qq --no-install-recommends" .
ARG NO_SSL="True"
# https://askubuntu.com/a/1013396
# https://github.com/phusion/baseimage-docker/issues/319
# RUN export DEBIAN_FRONTEND=noninteractive
# Set it via ARG as this only is available during build:
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN set -ex \
  && \
  ldconfig \
  && \
  if [ "$NO_SSL" = "True" ]; then \
    echo 'NODE_TLS_REJECT_UNAUTHORIZED=0' >> ~/.bashrc \
    && \
    echo "strict-ssl=false" >> ~/.npmrc \
    && \
    echo "registry=http://registry.npmjs.org/" > ~/.npmrc \
    && \
    echo ':ssl_verify_mode: 0' >> ~/.gemrc \
    && \
    echo "sslverify=false" >> /etc/yum.conf \
    && \
    echo "sslverify=false" >> ~/.yum.conf \
    && \
    echo "APT{Ignore {\"gpg-pubkey\"; }};" >> /etc/apt.conf \
    && \
    echo "Acquire::http::Verify-Peer \"false\";" >> /etc/apt.conf \
    && \
    echo "Acquire::https::Verify-Peer \"false\";" >> /etc/apt.conf \
    && \
    echo "APT{Ignore {\"gpg-pubkey\"; }};" >> ~/.apt.conf \
    && \
    echo "Acquire::http::Verify-Peer \"false\";" >> ~/.apt.conf \
    && \
    echo "Acquire::https::Verify-Peer \"false\";" >> ~/.apt.conf \
    && \
    echo "Acquire::http::Verify-Peer \"false\";" >> /etc/apt/apt.conf.d/00proxy \
    && \
    echo "Acquire::https::Verify-Peer \"false\";" >> /etc/apt/apt.conf.d/00proxy \
    && \
    echo "check-certificate = off" >> /etc/.wgetrc \
    && \
    echo "check-certificate = off" >> ~/.wgetrc \
    && \
    echo "insecure" >> /etc/.curlrc \
    && \
    echo "insecure" >> ~/.curlrc \
    ; \
  fi \
  && \
  $APT update \
  && \
  $APT install -y --reinstall software-properties-common \
  && \
  $APT install -y gnupg2 wget \
  && \
  if [ ! -z "$http_proxy" ]; then \
    apt-key adv --keyserver-options http-proxy=$http_proxy --keyserver keyserver.ubuntu.com --recv-keys 94558F59 \
    && \
    apt-key adv --keyserver-options http-proxy=$http_proxy --keyserver keyserver.ubuntu.com --recv-keys 1E9377A2BA9EF27F \
    && \
    apt-key adv --keyserver-options http-proxy=$http_proxy --keyserver keyserver.ubuntu.com --recv-keys 2EA8F35793D8809A \
    ; \
  else \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 94558F59 \
    && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1E9377A2BA9EF27F \
    && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2EA8F35793D8809A \
    ; \
  fi \
  apt-key adv --keyserver-options http-proxy=$http_proxy --fetch-keys http://llvm.org/apt/llvm-snapshot.gpg.key \
  && \
  apt-add-repository -y "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu $(lsb_release -sc) main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-7 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main" \
  && \
  $APT update \
  && \
  $APT install -y \
                    ca-certificates \
                    software-properties-common \
                    git \
                    wget \
                    locales \
  && \
  if [ "$NO_SSL" = "True" ]; then \
    git config --global http.sslVerify false \
    && \
    git config --global http.postBuffer 1048576000 \
    && \
    # solves 'Connection time out' on server in company domain. \
    git config --global url."https://github.com".insteadOf git://github.com \
    && \
    export GIT_SSL_NO_VERIFY=true \
    ; \
  fi \
  && \
  $APT install -y \
                    make \
                    autoconf automake autotools-dev libtool \
                    git \
                    curl \
                    vim \
  && \
  $APT install -y build-essential \
  && \
  $APT install -y libboost-dev \
                    openmpi-bin \
                    openmpi-common \
                    libopenmpi-dev \
                    libevent-dev \
                    libdouble-conversion-dev \
                    libgoogle-glog-dev \
                    libgflags-dev \
                    libiberty-dev \
                    liblz4-dev \
                    liblzma-dev \
                    libsnappy-dev \
                    zlib1g-dev \
                    binutils-dev \
                    libjemalloc-dev \
                    libssl-dev \
                    pkg-config \
                    autoconf-archive \
                    bison \
                    flex \
                    gperf \
                    joe \
                    libboost-all-dev \
                    libcap-dev \
                    libkrb5-dev \
                    libpcre3-dev \
                    libpthread-stubs0-dev \
                    libnuma-dev \
                    libsasl2-dev \
                    libsqlite3-dev \
                    libtool \
                    netcat-openbsd \
                    unzip \
                    gcc \
                    g++ \
                    gnutls-bin \
                    openssl \
                    libgtest-dev \
                    fakeroot \
                    dpkg-dev \
                    libcurl4-openssl-dev \
                    libzstd-dev \
  && \
  $APT install -y mesa-utils \
                            libglu1-mesa-dev \
                            dbus-x11 \
                            libx11-dev \
                            xorg-dev \
                            libssl-dev \
                            python3 \
                            python3-pip \
                            python3-dev \
                            python3-setuptools  \
  # For convenience, alias (but don't sym-link) python & pip to python3 & pip3 as recommended in: \
  # http://askubuntu.com/questions/351318/changing-symlink-python-to-python3-causes-problems \
  && \
  echo "alias python='python3'" >> /root/.bash_aliases \
  && \
  echo "alias pip='pip3'" >> /root/.bash_aliases \
  && \
  $APT install -y nano \
                            mc \
                            bash \
  && \
  mkdir -p $HOME/.pip/ \
  && \
  echo "[global]" >> $HOME/.pip/pip.conf \
  && \
  echo "timeout = 60" >> $HOME/.pip/pip.conf \
  && \
  echo "index-url = https://pypi.python.org/simple" >> $HOME/.pip/pip.conf \
  && \
  echo "extra-index-url = http://151.101.112.223/root/pypi/+simple" >> $HOME/.pip/pip.conf \
  && \
  echo "                  http://pypi.python.org/simple" >> $HOME/.pip/pip.conf \
  && \
  echo "trusted-host = download.zope.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               pypi.python.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               secondary.extra.host" >> $HOME/.pip/pip.conf \
  && \
  echo "               https://pypi.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               pypi.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               pypi.org:443" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.128.223" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.128.223:443" >> $HOME/.pip/pip.conf \
  && \
  echo "               https://pypi.python.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               pypi.python.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               pypi.python.org:443" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.112.223" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.112.223:443" >> $HOME/.pip/pip.conf \
  && \
  echo "               https://files.pythonhosted.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               files.pythonhosted.org" >> $HOME/.pip/pip.conf \
  && \
  echo "               files.pythonhosted.org:443" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.113.63" >> $HOME/.pip/pip.conf \
  && \
  echo "               151.101.113.63:443" >> $HOME/.pip/pip.conf \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN set -ex \
    && \
    ldconfig \
    && \
    git clone -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /var/local/git/grpc \
    && \
    cd /var/local/git/grpc \
    && \
    git submodule update --init --recursive \
    && \
    echo "-- installing protobuf" \
    && \
    cd /var/local/git/grpc/third_party/protobuf \
    && \
    git submodule update --init --recursive \
    && \
    ./autogen.sh && ./configure --enable-shared \
    && \
    make -j$(nproc) && make install && make clean && ldconfig \
    && \
    echo "-- installing grpc (requires protobuf)" \
    && \
    cd /var/local/git/grpc \
    && \
    make -j$(nproc) && make install && make clean && ldconfig \
    && \
    rm -rf /var/local/git/grpc

WORKDIR $WDIR

RUN pip3 install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org wheel \
  && \
  pip3 install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org virtualenv \
  && \
  pip3 install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org conan \
  && \
  pip3 install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org conan_package_tools \
  && \
  conan remote update conan-center https://conan.bintray.com False \
  # TODO: use conan profile new https://github.com/conan-io/conan/issues/1541#issuecomment-321235829 \
  && \
  mkdir -p $HOME/.conan/profiles/ \
  && \
  echo "[settings]" >> ~/.conan/profiles/clang \
  && \
  echo "os_build=Linux" >> ~/.conan/profiles/clang \
  && \
  echo "os=Linux" >> ~/.conan/profiles/clang \
  && \
  echo "arch_build=x86_64" >> ~/.conan/profiles/clang \
  && \
  echo "arch=x86_64" >> ~/.conan/profiles/clang \
  && \
  echo "compiler=clang" >> ~/.conan/profiles/clang \
  && \
  echo "compiler.version=6.0" >> ~/.conan/profiles/clang \
  && \
  echo "compiler.libcxx=libstdc++11" >> ~/.conan/profiles/clang \
  && \
  echo "" >> ~/.conan/profiles/clang \
  && \
  echo "[env]" >> ~/.conan/profiles/clang \
  && \
  echo "CC=/usr/bin/clang-6.0" >> ~/.conan/profiles/clang \
  && \
  echo "CXX=/usr/bin/clang++-6.0" >> ~/.conan/profiles/clang \
  && \
  # TODO: use conan profile new https://github.com/conan-io/conan/issues/1541#issuecomment-321235829 \
  mkdir -p $HOME/.conan/profiles/ \
  && \
  echo "[settings]" >> ~/.conan/profiles/gcc \
  && \
  echo "os_build=Linux" >> ~/.conan/profiles/gcc \
  && \
  echo "os=Linux" >> ~/.conan/profiles/gcc \
  && \
  echo "arch_build=x86_64" >> ~/.conan/profiles/gcc \
  && \
  echo "arch=x86_64" >> ~/.conan/profiles/gcc \
  && \
  echo "compiler=gcc" >> ~/.conan/profiles/gcc \
  && \
  echo "compiler.version=7" >> ~/.conan/profiles/gcc \
  && \
  echo "compiler.libcxx=libstdc++11" >> ~/.conan/profiles/gcc \
  && \
  echo "" >> ~/.conan/profiles/gcc \
  && \
  echo "[env]" >> ~/.conan/profiles/gcc \
  && \
  echo "CC=/usr/bin/gcc" >> ~/.conan/profiles/gcc \
  && \
  echo "CXX=/usr/bin/g++" >> ~/.conan/profiles/gcc

# allows individual sections to be run by doing: docker build --target ...
FROM        test_appserver_build_env as test_appserver_target
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ARG APT="apt-get -qq --no-install-recommends"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    #TERM=screen \
    PATH=/usr/local/bin/:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    GIT_AUTHOR_NAME=$GIT_USERNAME \
    GIT_AUTHOR_EMAIL=$GIT_EMAIL \
    GIT_COMMITTER_NAME=$GIT_USERNAME \
    GIT_COMMITTER_EMAIL=$GIT_EMAIL \
    WDIR=/opt
RUN mkdir -p $WDIR
# https://askubuntu.com/a/1013396
# https://github.com/phusion/baseimage-docker/issues/319
# RUN export DEBIAN_FRONTEND=noninteractive
# Set it via ARG as this only is available during build:
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN ldconfig

# NOTE: create folder `.ca-certificates` with custom certs
# switch to root
#USER root
COPY ./.ca-certificates/* /usr/local/share/ca-certificates/
RUN update-ca-certificates --fresh
# switch back to custom user
#USER docker

WORKDIR $WDIR

# NOTE: ADD invalidate the cache for the copy
ADD . $WDIR/project_copy

# need some git config to apply git patch
RUN git config --global user.email "$GIT_EMAIL" \
  && \
  git config --global user.name "$GIT_USERNAME" \
  && \
  git submodule update --init --recursive --depth 50 || true

# Uninstall the default version provided by Ubuntu package manager, so we can install custom one
RUN set -ex \
  && \
  $APT purge -y cmake || true

WORKDIR $WDIR/project_copy

RUN ["chmod", "+x", "scripts/start_test_appserver.sh"]

RUN ["chmod", "+x", "scripts/install_cmake.sh"]
RUN ["chmod", "+x", "scripts/install_libunwind.sh"]

RUN ["bash", "-c", "bash $WDIR/project_copy/scripts/install_cmake.sh \
                        && \
                        bash $WDIR/project_copy/scripts/install_libunwind.sh"]

RUN export CC=gcc \
  && \
  export CXX=g++ \
  #&& \
  #cmake -E remove_directory build \
  #&& \
  #cmake -E remove_directory *-build \
  && \
  # create build dir \
  cmake -E make_directory build \
  && \
  # configure \
  cmake -E chdir build conan install --build=missing --profile gcc .. \
  && \
  cmake -E chdir build cmake -E time cmake -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DCMAKE_BUILD_TYPE=Debug .. \
  && \
  # build \
  cmake -E chdir build cmake -E time cmake --build . -- -j6 \
  && \
  # install lib and CXTPL_tool \
  cmake -E chdir build make install \
  #&& \
  #cmake -E remove_directory build \
  #&& \
  # \
  #cmake -E remove_directory *-build \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# remove unused apps after install
RUN set -ex \
  && \
  rm -rf $WDIR/project_copy \
  && \
  $APT remove -y \
                    git \
                    wget \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && \
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config

#RUN service ssh restart

#ENV DEBIAN_FRONTEND teletype

# default
FROM        test_appserver_target
WORKDIR $WDIR
ENTRYPOINT ["/bin/bash", "scripts/start_test_appserver.sh"]
