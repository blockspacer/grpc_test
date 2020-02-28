ARG UBUNTU_VERSION=18.04
FROM ubuntu:${UBUNTU_VERSION} as cxx_build_env
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    #TERM=screen \
    PATH=/usr/bin/:/usr/local/bin/:/go/bin:/usr/local/go/bin:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    GIT_AUTHOR_NAME=$GIT_USERNAME \
    GIT_AUTHOR_EMAIL=$GIT_EMAIL \
    GIT_COMMITTER_NAME=$GIT_USERNAME \
    GIT_COMMITTER_EMAIL=$GIT_EMAIL \
    WDIR=/opt \
    GOLANG_VERSION=1.12.4 \
    GOPATH=/go \
    CONAN_REVISIONS_ENABLED=1 \
    CONAN_PRINT_RUN_COMMANDS=1 \
    CONAN_LOGGING_LEVEL=10 \
    CONAN_VERBOSE_TRACEBACK=1

ARG APT="apt-get -qq --no-install-recommends"
# docker build --build-arg NO_SSL="False" APT="apt-get -qq --no-install-recommends" .
ARG NO_SSL="True"
ARG VIM_FROM_APT="False"
ARG BOOST_FROM_APT="False"
ARG OPENMPI_FROM_APT="False"
ARG GLU_FROM_APT="False"
ARG LIBEVENT_FROM_APT="False"
ARG NETTOOLS_FROM_APT="False"
ARG HTOP_FROM_APT="False"
ARG LIBDCOV_FROM_APT="False"
ARG BISON_FROM_APT="False"
ARG FLEX_FROM_APT="False"
ARG LIBX11_FROM_APT="False"
ARG GLOG_FROM_APT="False"
ARG GFLAGS_FROM_APT="False"
ARG IBERTY_FROM_APT="False"
ARG LZ4_FROM_APT="False"
ARG LZMA_FROM_APT="False"
ARG SNAPPY_FROM_APT="False"
ARG ZLIB_FROM_APT="True"
# NOTE: cmake from apt may be outdated
ARG CMAKE_FROM_APT="True"
ARG NETCAT_FROM_APT="False"
ARG PCRE3_FROM_APT="False"
ARG LIBKRB5_FROM_APT="False"
ARG LIBCAP_FROM_APT="False"
ARG LIBSASL2_FROM_APT="False"
ARG LIBSQLITE3_FROM_APT="False"
ARG FAKEROOT_FROM_APT="False"
ARG ZSTD_FROM_APT="False"
ARG GTEST_FROM_APT="False"
ARG NUMA_FROM_APT="False"
ARG GPERF_FROM_APT="False"
ARG JOE_FROM_APT="False"
ARG JEMALLOC_FROM_APT="False"
ARG BINUTILS_FROM_APT="False"
ARG LIBTOOL_FROM_APT="True"
ARG DPKG_FROM_APT="False"
ARG NANO_FROM_APT="False"
ARG MC_FROM_APT="False"
ARG PY3_DEV_FROM_APT="False"
# SEE: http://kefhifi.com/?p=701
ARG GIT_WITH_OPENSSL="True"
ARG PY3_SETUPTOOLS_FROM_APT="True"
# NOTE: conan requires python3, python3-pip, python3-setuptools
ARG INSTALL_CONAN="True"
ARG CONAN="conan"
# Example: conan-local http://localhost:8081/artifactory/api/conan/conan False
ARG CONAN_EXTRA_REPOS=""
# Example: user -p password -r conan-local admin
ARG CONAN_EXTRA_REPOS_USER=""
ARG INSTALL_GO="False"
# see git config --global http.sslCAInfo
ARG GIT="git"
ARG GIT_CA_INFO=""
ARG GO="go"
ARG PIP="pip3"
# NOTE: you may want to remove `--trusted-host`
ARG PIP_INSTALL="$PIP install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org"
# https://askubuntu.com/a/1013396
# https://github.com/phusion/baseimage-docker/issues/319
# RUN export DEBIAN_FRONTEND=noninteractive
# Set it via ARG as this only is available during build:

# NOTE: destination must end with a /
COPY ".ca-certificates/" $WDIR/.ca-certificates

RUN set -ex \
  && \
  mkdir -p $WDIR \
  && \
  (cp -r $WDIR/.ca-certificates/* /usr/local/share/ca-certificates/ || true) \
  && \
  (rm -rf $WDIR/.ca-certificates || true) \
  && \
  cd $WDIR \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  ldconfig \
  && \
  if [ "$NO_SSL" = "True" ]; then \
    echo 'WARNING: SSL CHECKS DISABLED! SEE NO_SSL FLAG IN DOCKERFILE' \
    && \
    export NODE_TLS_REJECT_UNAUTHORIZED=0 \
    && \
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
  ldconfig \
  && \
  $APT update \
  && \
  $APT install -y --reinstall software-properties-common \
  && \
  $APT install -y gnupg2 wget \
  && \
  export GNUPGHOME="$(mktemp -d)" \
  && \
  (mkdir ~/.gnupg || true) \
  && \
  echo "keyserver-options auto-key-retrieve" >> ~/.gnupg/gpg.conf \
  && \
  wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key --no-check-certificate | apt-key add - \
  && \
  # Try more keyservers to fix unstable builds \
  # see https://unix.stackexchange.com/a/361220 \
  keyservers="hkp://keyserver.ubuntu.com:80"\ "keyserver.ubuntu.com:80"\ "pool.sks-keyservers.net"\ "keyserver.ubuntu.com"\ "ipv4.pool.sks-keyservers.net"\ "Zpool.sks-keyservers.net"\ "keyserver.pgp.com"\ "ha.pool.sks-keyservers.net"\ "hkp://p80.pool.sks-keyservers.net:80"\ "pgp.mit.edu" \
  && \
  keys=94558F59\ 1E9377A2BA9EF27F\ 2EA8F35793D8809A \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: GPG SSL CHECKS DISABLED! SEE http_proxy IN DOCKERFILE' \
    && \
    for key in $keys; do \
    for server in $keyservers; do \
    echo "Fetching GPG key ${key} from ${server}" \
    && \
    (gpg --keyserver "$server" --keyserver-options http-proxy=$http_proxy --recv-keys "${key}" || true) \
    ; done \
    ; done \
    ; \
  else \
    for key in $keys; do \
    for server in $keyservers; do \
    echo "Fetching GPG key ${key} from ${server}" \
    && \
    (gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "${key}" || true) \
    ; done \
    ; done \
    ; \
  fi \
  && \
  gpg --list-keys \
  && \
  (apt-key adv --keyserver-options http-proxy=$http_proxy --fetch-keys http://llvm.org/apt/llvm-snapshot.gpg.key || true) \
  && \
  echo "added llvm-snapshot.gpg.key" \
  #&& \
  #apt-add-repository -y "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu $(lsb_release -sc) main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-6.0 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-7 main" \
  && \
  apt-add-repository -y "deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main" \
  && \
  echo "added llvm-toolchain repository" \
  && \
  ldconfig \
  && \
  $APT update \
  && \
  ldconfig \
  && \
  $APT install -y \
                    ca-certificates \
                    software-properties-common \
                    # TODO: (see GIT_WITH_OPENSSL) git depends on git-man (<< 1:2.17.1-.); however: Package git-man is not installed.
                    #git \
                    wget \
                    locales \
  && \
  update-ca-certificates --fresh \
  && \
  ldconfig \
  && \
  $APT install -y \
                    make \
                    autoconf automake autotools-dev \
                    curl \
  && \
  if [ ! -z "$GIT_WITH_OPENSSL" ]; then \
    echo 'building git from source, see ARG GIT_WITH_OPENSSL' \
    && \
    # Ubuntu's default git package is built with broken gnutls. Rebuild git with openssl.
    $APT update \
    #&& \
    #add-apt-repository ppa:git-core/ppa  \
    #apt-add-repository "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu $(lsb_release -sc) main" \
    #&& \
    #apt-key add 1E9377A2BA9EF27F \
    #&& \
    #printf "deb-src http://ppa.launchpad.net/git-core/ppa/ubuntu ${CODE_NAME} main\n" >> /etc/apt/sources.list.d/git-core-ubuntu-ppa-bionic.list \
    && \
    $APT install -y --no-install-recommends \
       software-properties-common \
       fakeroot ca-certificates tar gzip zip \
       autoconf automake bzip2 file g++ gcc \
       #imagemagick libbz2-dev libc6-dev libcurl4-openssl-dev \
       #libglib2.0-dev libevent-dev \
       #libdb-dev  libffi-dev libgeoip-dev libjpeg-dev libkrb5-dev \
       #liblzma-dev libncurses-dev \
       #libmagickcore-dev libmagickwand-dev libmysqlclient-dev libpng-dev \
       libssl-dev libtool libxslt-dev \
       #libpq-dev libreadline-dev libsqlite3-dev libwebp-dev libxml2-dev \
       #libyaml-dev zlib1g-dev \
       make patch xz-utils unzip curl  \
    && \
    sed -i -- 's/#deb-src/deb-src/g' /etc/apt/sources.list \
    && \
    sed -i -- 's/# deb-src/deb-src/g' /etc/apt/sources.list \
    && \
    $APT update \
    && \
    $APT install -y gnutls-bin openssl \
    && \
    $APT install -y build-essential fakeroot dpkg-dev -y \
    #&& \
    #($APT remove -y git || true ) \
    && \
    $APT build-dep git -y \
    && \
    # git build deps
    $APT install -y libcurl4-openssl-dev liberror-perl git-man -y \
    && \
    mkdir source-git \
    && \
    cd source-git/ \
    && \
    $APT source git \
    && \
    cd git-2.*.*/ \
    && \
    sed -i -- 's/libcurl4-gnutls-dev/libcurl4-openssl-dev/' ./debian/control \
    && \
    sed -i -- '/TEST\s*=\s*test/d' ./debian/rules \
    && \
    dpkg-buildpackage -rfakeroot -b -uc -us \
    && \
    dpkg -i ../git_*ubuntu*.deb \
    ; \
  fi \
  && \
  if [ "$NO_SSL" = "True" ]; then \
    echo 'WARNING: GIT SSL CHECKS DISABLED! SEE NO_SSL FLAG IN DOCKERFILE' \
    && \
    ($GIT config --global http.sslVerify false || true) \
    && \
    ($GIT config --global https.sslVerify false || true) \
    && \
    ($GIT config --global http.postBuffer 1048576000 || true) \
    && \
    # solves 'Connection time out' on server in company domain. \
    ($GIT config --global url."https://github.com".insteadOf git://github.com || true) \
    && \
    export GIT_SSL_NO_VERIFY=true \
    ; \
  fi \
  && \
  if [ "$GIT_CA_INFO" != "" ]; then \
    echo 'WARNING: GIT_CA_INFO CHANGED! SEE GIT_CA_INFO FLAG IN DOCKERFILE' \
    && \
    ($GIT config --global http.sslCAInfo $GIT_CA_INFO || true) \
    && \
    ($GIT config --global http.sslCAPath $GIT_CA_INFO || true) \
    ; \
  fi \
  && \
  $APT install -y build-essential \
  && \
  if [ "$VIM_FROM_APT" = "True" ]; then \
    $APT install -y vim \
    ; \
  fi \
  && \
  if [ "$BOOST_FROM_APT" = "True" ]; then \
    $APT install -y libboost-dev \
                      libboost-all-dev \
    ; \
  fi \
  && \
  if [ "$OPENMPI_FROM_APT" = "True" ]; then \
    $APT install -y openmpi-bin \
                    openmpi-common \
                    libopenmpi-dev \
    ; \
  fi \
  && \
  if [ "$GLU_FROM_APT" = "True" ]; then \
    $APT install -y mesa-utils \
                    libglu1-mesa-dev \
    ; \
  fi \
  && \
  if [ "$LIBEVENT_FROM_APT" = "True" ]; then \
    $APT install -y libevent-dev \
    ; \
  fi \
  && \
  if [ "$HTOP_FROM_APT" = "True" ]; then \
    $APT install -y htop \
    ; \
  fi \
  && \
  if [ "$NETTOOLS_FROM_APT" = "True" ]; then \
    $APT install -y iproute2 net-tools \
    ; \
  fi \
  && \
  if [ "$LIBDCOV_FROM_APT" = "True" ]; then \
    $APT install -y libdouble-conversion-dev \
    ; \
  fi \
  && \
  if [ "$BISON_FROM_APT" = "True" ]; then \
    $APT install -y bison \
    ; \
  fi \
  && \
  if [ "$FLEX_FROM_APT" = "True" ]; then \
    $APT install -y flex \
    ; \
  fi \
  && \
  if [ "$LIBX11_FROM_APT" = "True" ]; then \
    $APT install -y dbus-x11 \
                    libx11-dev \
                    xorg-dev \
    ; \
  fi \
  && \
  if [ "$GLOG_FROM_APT" = "True" ]; then \
    $APT install -y libgoogle-glog-dev \
    ; \
  fi \
  && \
  if [ "$GFLAGS_FROM_APT" = "True" ]; then \
    $APT install -y libgflags-dev \
    ; \
  fi \
  && \
  if [ "$IBERTY_FROM_APT" = "True" ]; then \
    $APT install -y libiberty-dev \
    ; \
  fi \
  && \
  if [ "$LZ4_FROM_APT" = "True" ]; then \
    $APT install -y liblz4-dev \
    ; \
  fi \
  && \
  if [ "$LZMA_FROM_APT" = "True" ]; then \
    $APT install -y liblzma-dev \
    ; \
  fi \
  && \
  if [ "$SNAPPY_FROM_APT" = "True" ]; then \
    $APT install -y libsnappy-dev \
    ; \
  fi \
  && \
  if [ "$ZLIB_FROM_APT" = "True" ]; then \
    $APT install -y zlib1g-dev \
    ; \
  fi \
  && \
  if [ "$CMAKE_FROM_APT" = "True" ]; then \
    $APT install -y cmake \
    ; \
  fi \
  && \
  if [ "$BINUTILS_FROM_APT" = "True" ]; then \
    $APT install -y binutils-dev \
    ; \
  fi \
  && \
  if [ "$JEMALLOC_FROM_APT" = "True" ]; then \
    $APT install -y libjemalloc-dev \
    ; \
  fi \
  && \
  if [ "$JOE_FROM_APT" = "True" ]; then \
    $APT install -y joe \
    ; \
  fi \
  && \
  if [ "$GPERF_FROM_APT" = "True" ]; then \
    $APT install -y gperf \
    ; \
  fi \
  && \
  if [ "$NUMA_FROM_APT" = "True" ]; then \
    $APT install -y libnuma-dev \
    ; \
  fi \
  && \
  if [ "$GTEST_FROM_APT" = "True" ]; then \
    $APT install -y libgtest-dev \
    ; \
  fi \
  && \
  if [ "$ZSTD_FROM_APT" = "True" ]; then \
    $APT install -y libzstd-dev \
    ; \
  fi \
  && \
  if [ "$FAKEROOT_FROM_APT" = "True" ]; then \
    $APT install -y fakeroot \
    ; \
  fi \
  && \
  if [ "$LIBSQLITE3_FROM_APT" = "True" ]; then \
    $APT install -y libsqlite3-dev \
    ; \
  fi \
  && \
  if [ "$LIBSASL2_FROM_APT" = "True" ]; then \
    $APT install -y libsasl2-dev \
    ; \
  fi \
  && \
  if [ "$LIBCAP_FROM_APT" = "True" ]; then \
    $APT install -y libcap-dev \
    ; \
  fi \
  && \
  if [ "$LIBKRB5_FROM_APT" = "True" ]; then \
    $APT install -y libkrb5-dev \
    ; \
  fi \
  && \
  if [ "$PCRE3_FROM_APT" = "True" ]; then \
    $APT install -y libpcre3-dev \
    ; \
  fi \
  && \
  if [ "$NETCAT_FROM_APT" = "True" ]; then \
    $APT install -y netcat-openbsd \
    ; \
  fi \
  && \
  if [ "$DPKG_FROM_APT" = "True" ]; then \
    $APT install -y dpkg-dev \
    ; \
  fi \
  && \
  if [ "$LIBTOOL_FROM_APT" = "True" ]; then \
    $APT install -y libtool \
    ; \
  fi \
  && \
  if [ "$NANO_FROM_APT" = "True" ]; then \
    $APT install -y nano \
    ; \
  fi \
  && \
  if [ "$MC_FROM_APT" = "True" ]; then \
    $APT install -y mc \
    ; \
  fi \
  && \
  $APT install -y bash \
                  libssl-dev \
                  gnutls-bin \
                  openssl \
                  libcurl4-openssl-dev \
                  pkg-config \
                  #autoconf-archive \
                  libpthread-stubs0-dev \
                  unzip \
                  gcc \
                  g++ \
                  # libcap2 for setcap
                  libcap2-bin \
  && \
  $APT install -y python3 \
                  python3-pip \
  && \
  if [ "$PY3_DEV_FROM_APT" = "True" ]; then \
    $APT install -y python3-dev \
    ; \
  fi \
  && \
  if [ "$PY3_SETUPTOOLS_FROM_APT" = "True" ]; then \
    $APT install -y python3-setuptools \
    ; \
  fi \
  && \
  # For convenience, alias (but don't sym-link) python & pip to python3 & pip3 as recommended in: \
  # http://askubuntu.com/questions/351318/changing-symlink-python-to-python3-causes-problems \
  echo "alias python='python3'" >> /root/.bash_aliases \
  && \
  echo "alias pip='pip3'" >> /root/.bash_aliases \
  && \
  ldconfig \
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
  if [ "$NO_SSL" = "True" ]; then \
    echo 'WARNING: PIP SSL CHECKS DISABLED! SEE NO_SSL FLAG IN DOCKERFILE' \
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
    ; \
  fi \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  ldconfig \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: GIT sslverify DISABLED! SEE http_proxy IN DOCKERFILE' \
    && \
    ($GIT config --global http.proxyAuthMethod 'basic' || true) \
    && \
    ($GIT config --global http.sslverify false  || true) \
    && \
    ($GIT config --global https.sslverify false || true) \
    && \
    ($GIT config --global http.proxy $http_proxy || true) \
    && \
    ($GIT config --global https.proxy $https_proxy || true) \
    ; \
  fi \
  && \
  $PIP_INSTALL wheel \
  && \
  $PIP_INSTALL virtualenv \
  && \
  $PIP_INSTALL conan \
  && \
  $PIP_INSTALL conan_package_tools \
  # TODO: use conan profile new https://github.com/conan-io/conan/issues/1541#issuecomment-321235829 \
  && \
  if [ "$INSTALL_CONAN" = "True" ]; then \
    # must exist
    $CONAN --version \
    && \
    $CONAN profile new default --detect \
    && \
    $CONAN profile update settings.compiler.libcxx=libstdc++11 default \
    && \
    if [ ! -z "$CONAN_EXTRA_REPOS" ]; then \
      $CONAN remote add $CONAN_EXTRA_REPOS \
      ; \
    fi \
    && \
    if [ ! -z "$CONAN_EXTRA_REPOS_USER" ]; then \
      $CONAN $CONAN_EXTRA_REPOS_USER \
      ; \
    fi \
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
    echo "CXX=/usr/bin/g++" >> ~/.conan/profiles/gcc \
    ; \
  fi \
  && \
  if [ "$INSTALL_GO" = "True" ]; then \
    echo "Installing go into GOPATH=$GOPATH" \
    && \
    # NOTE: Add $GOPATH/bin in PATH
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH" \
    && \
    cd /tmp \
    && \
    wget --no-check-certificate -O go.tgz "https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz" \
    && \
    # NOTE: Add /usr/local/go/bin in PATH
    tar -C /usr/local -xzf go.tgz \
    && \
    rm go.tgz \
    && \
    $GO version \
    ; \
  fi \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config \
  && \
  ($GIT config --global --unset http.proxyAuthMethod || true) \
  && \
  ($GIT config --global --unset http.proxy || true) \
  && \
  ($GIT config --global --unset https.proxy || true) \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/*
