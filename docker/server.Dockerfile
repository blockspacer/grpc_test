# allows individual sections to be run by doing: docker build --target ...
FROM gaeus:cxx_build_env as test_appserver_target
# NOTE: if not BUILD_GRPC_FROM_SOURCES, then script uses conan protobuf package
ARG BUILD_TYPE=Release
# NOTE: cmake from apt may be outdated
ARG CMAKE_FROM_APT="True"
ARG CMAKE="cmake"
ARG GIT="git"
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ARG APT="apt-get -qq --no-install-recommends"
ARG PROTOC="protoc"
ARG LS_VERBOSE="ls -artl"
ARG PIP="pip3"
ARG CONAN="conan"
# Example: conan install --build=missing --profile gcc
ARG CONAN_INSTALL="conan install --profile gcc"
ARG INSTALL_GRPC_FROM_CONAN="True"
# Example: --build-arg CONAN_EXTRA_REPOS="conan-local http://localhost:8081/artifactory/api/conan/conan False"
ARG CONAN_EXTRA_REPOS=""
# Example: --build-arg CONAN_EXTRA_REPOS_USER="user -p password -r conan-local admin"
ARG CONAN_EXTRA_REPOS_USER=""
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
    # NOTE: PROJ_DIR must be within WDIR
    PROJ_DIR=/opt/project_copy \
    # NOTE: PROJ_DIR must be within WDIR
    SUB_PROJ_DIR=/opt/project_copy/test_appserver \
    # NOTE: PROJ_DIR must be within WDIR
    CA_PROJ_DIR=/opt/project_copy/.ca-certificates \
    # NOTE: PROJ_DIR must be within WDIR
    SCRIPTS_PROJ_DIR=/opt/project_copy/scripts \
    GOPATH=/go \
    CONAN_REVISIONS_ENABLED=1 \
    CONAN_PRINT_RUN_COMMANDS=1 \
    CONAN_LOGGING_LEVEL=10 \
    CONAN_VERBOSE_TRACEBACK=1

# create all folders parent to $PROJ_DIR
RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $WDIR
# NOTE: ADD invalidates the cache, COPY does not
COPY "proto/" $PROJ_DIR/proto/
COPY "test_appserver/"  $SUB_PROJ_DIR/
COPY ".ca-certificates/"  $CA_PROJ_DIR/
COPY "scripts/" $SCRIPTS_PROJ_DIR/
WORKDIR $PROJ_DIR

RUN set -ex \
  && \
  $APT update \
  && \
  $APT install -y \
                    git \
  && \
  ($LS_VERBOSE /usr/local/lib/libprotobuf* || true) \
  && \
  ($LS_VERBOSE /usr/local/lib/libgrpc* || true) \
  && \
  ($PROTOC --version || true) \
  && \
  cd $PROJ_DIR \
  && \
  $LS_VERBOSE $PROJ_DIR \
  && \
  (cp $CA_PROJ_DIR/* /usr/local/share/ca-certificates/ || true) \
  && \
  (rm -rf $CA_PROJ_DIR || true) \
  && \
  chmod +x $SCRIPTS_PROJ_DIR/start_test_appserver.sh \
  && \
  cp $SCRIPTS_PROJ_DIR/start_test_appserver.sh /usr/local/bin \
  && \
  if [ "$CMAKE_FROM_APT" != "True" ]; then \
    # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
    ($APT purge -y cmake || true) \
    && \
    chmod +x $SCRIPTS_PROJ_DIR/install_cmake.sh \
    && \
    bash $SCRIPTS_PROJ_DIR/install_cmake.sh \
    ; \
  fi \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: CONAN SSL CHECKS DISABLED! SEE http_proxy IN DOCKERFILE' \
    && \
    $CONAN remote update conan-center https://conan.bintray.com False \
    && \
    $CONAN config install $SUB_PROJ_DIR/conan/remotes_disabled_ssl/ \
    ; \
  else \
    $CONAN remote update conan-center https://conan.bintray.com True \
    && \
    $CONAN config install $SUB_PROJ_DIR/conan/remotes/ \
    ; \
  fi \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  ldconfig \
  && \
  update-ca-certificates --fresh \
  && \
  # need some git config to apply git patch
  ($GIT config --global user.email "$GIT_EMAIL" || true) \
  && \
  ($GIT config --global user.name "$GIT_USERNAME" || true) \
  && \
  ($GIT submodule update --init --recursive --depth 50 || true) \
  && \
  export CC=gcc \
  && \
  export CXX=g++ \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: GIT sslverify DISABLED! SEE http_proxy IN DOCKERFILE' \
    && \
    ($GIT config --global http.proxyAuthMethod 'basic' || true) \
    && \
    ($GIT config --global http.sslverify false || true) \
    && \
    ($GIT config --global https.sslverify false || true) \
    && \
    ($GIT config --global http.proxy $http_proxy || true) \
    && \
    ($GIT config --global https.proxy $https_proxy || true) \
    ; \
  fi \
  && \
  cd $SUB_PROJ_DIR \
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
  # create build dir \
  ($CMAKE -E remove_directory build || true) \
  && \
  # create build dir \
  $CMAKE -E make_directory build \
  && \
  if [ "$INSTALL_GRPC_FROM_CONAN" = "True" ]; then \
    # configure \
    $CMAKE -E chdir build $CONAN_INSTALL -s build_type=$BUILD_TYPE -o enable_protoc_autoinstall=True .. \
    ; \
  else \
    # TODO: INSTALL without CONAN requires grpc_build_env
    # configure \
    $CMAKE -E chdir build $CONAN_INSTALL -s build_type=$BUILD_TYPE -o enable_protoc_autoinstall=False .. \
    ; \
  fi \
  && \
  # NOTE: Release build (!!!)
  $CMAKE -E chdir build $CMAKE -E time $CMAKE -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DCMAKE_BUILD_TYPE=$BUILD_TYPE .. \
  && \
  # build \
  $CMAKE -E chdir build $CMAKE -E time $CMAKE --build . -- -j6 \
  && \
  $CMAKE -E chdir build make install \
  && \
  # CAP_NET_BIND_SERVICE to grant low-numbered port access to a process
  setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/test_appserver_core \
  && \
  chmod +x /usr/local/bin/test_appserver_core \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  # remove unused project copy after install
  # NOTE: must remove copied files
  cd $WDIR && rm -rf $PROJ_DIR \
  && \
  ($GIT config --global --unset http.proxyAuthMethod || true) \
  && \
  ($GIT config --global --unset http.proxy || true) \
  && \
  ($GIT config --global --unset https.proxy || true) \
  && \
  ($PIP uninstall conan || true) \
  && \
  ($PIP uninstall conan_package_tools || true) \
  && \
  # remove unused apps after install
  ($APT remove -y build-essential || true) \
  && \
  ($APT remove -y libcap-dev || true) \
  && \
  ($APT remove -y netcat-openbsd || true) \
  && \
  ($APT remove -y nano || true) \
  && \
  ($APT remove -y libcap2-bin || true) \
  && \
  ($APT remove -y unzip || true) \
  && \
  ($APT remove -y mc || true) \
  && \
  ($APT remove -y python3-dev || true) \
  && \
  ($APT remove -y python3-setuptools || true) \
  && \
  ($APT remove -y zlib1g-dev || true) \
  && \
  ($APT remove -y libtool || true) \
  && \
  ($APT remove -y cmake || true) \
  && \
  ($APT remove -y libboost-all-dev || true) \
  && \
  ($APT remove -y libboost-dev || true) \
  && \
  ($APT remove -y vim || true) \
  && \
  ($APT remove -y curl || true) \
  && \
  ($APT remove -y autotools-dev || true) \
  && \
  ($APT remove -y autoconf || true) \
  && \
  ($APT remove -y make || true) \
  && \
  ($APT remove -y git || true) \
  && \
  ($APT remove -y wget || true) \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  # NOTE: make sure all libs linked statically
  rm -rf ~/.conan/ \
  && \
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/*
  #&& \
  # remove unused build artifacts
  #rm -rf $PROJ_DIR/build/**.a $PROJ_DIR/build/**.o $PROJ_DIR/build/**.obj $PROJ_DIR/build/**.lib

#RUN service ssh restart

#ENV DEBIAN_FRONTEND teletype

# default
FROM        test_appserver_target as test_appserver_run
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    PATH=/usr/bin/:/usr/local/bin/:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    WDIR=/opt \
    START_APP=/usr/local/bin/test_appserver_core \
    START_APP_OPTIONS=
# see https://github.com/grpc/grpc/blob/master/doc/environment_variables.md
# GRPC_VERBOSITY DEBUG - log all gRPC messages
# GRPC_VERBOSITY INFO - log INFO and ERROR message
# GRPC_VERBOSITY ERROR - log only errors
ARG GRPC_VERBOSITY=INFO
ARG GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=
# 'all' can additionally be used to turn all traces on. Individual traces can be disabled by prefixing them with '-'. Example: all,-timer_check,-timer
ARG GRPC_TRACE=
ARG GRPC_ABORT_ON_LEAKS=0
ARG GRPC_POLL_STRATEGY=poll
ARG GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS=5000
ENV GRPC_VERBOSITY=$GRPC_VERBOSITY \
    GRPC_TRACE=$GRPC_TRACE \
    GRPC_ABORT_ON_LEAKS=$GRPC_ABORT_ON_LEAKS \
    GRPC_POLL_STRATEGY=$GRPC_POLL_STRATEGY \
    GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS=$GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS \
    GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=$GRPC_DEFAULT_SSL_ROOTS_FILE_PATH
WORKDIR $WDIR
ENTRYPOINT ["/bin/bash", "-c", "echo 'starting $START_APP...' && $START_APP $START_APP_OPTIONS"]
#ENTRYPOINT [ "/usr/local/bin/test_appserver_core" ]
EXPOSE 50051
