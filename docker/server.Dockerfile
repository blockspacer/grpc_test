# allows individual sections to be run by doing: docker build --target ...
FROM gaeus:grpc_build_env as test_appserver_target
# NOTE: if not BUILD_GRPC_FROM_SOURCES, then script uses conan protobuf package
ARG BUILD_TYPE=Release
# NOTE: cmake from apt may be outdated
ARG CMAKE_FROM_APT="True"
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ARG APT="apt-get -qq --no-install-recommends"
ARG INSTALL_GRPC_FROM_CONAN="False"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    #TERM=screen \
    PATH=/usr/bin/:/usr/local/bin/:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    GIT_AUTHOR_NAME=$GIT_USERNAME \
    GIT_AUTHOR_EMAIL=$GIT_EMAIL \
    GIT_COMMITTER_NAME=$GIT_USERNAME \
    GIT_COMMITTER_EMAIL=$GIT_EMAIL \
    WDIR=/opt \
    # NOTE: PROJ_DIR must be within WDIR
    PROJ_DIR=/opt/project_copy \
    # NOTE: PROJ_DIR must be within WDIR
    SUB_PROJ_DIR=/opt/project_copy/test_appserver

# create all folders parent to $PROJ_DIR
RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $WDIR
# NOTE: ADD invalidates the cache, COPY does not
COPY "proto/" $PROJ_DIR/proto/
COPY "test_appserver/"  $PROJ_DIR/test_appserver/
COPY ".ca-certificates/"  $PROJ_DIR/.ca-certificates/
COPY "scripts/" $PROJ_DIR/scripts/
WORKDIR $PROJ_DIR

RUN set -ex \
  && \
  $APT update \
  && \
  # must exist
  protoc --version \
  && \
  cd $PROJ_DIR \
  && \
  ls -artl \
  && \
  cp $PROJ_DIR/.ca-certificates/* /usr/local/share/ca-certificates/ || true \
  && \
  rm -rf $PROJ_DIR/.ca-certificates || true \
  && \
  chmod +x $PROJ_DIR/scripts/start_test_appserver.sh \
  && \
  cp $PROJ_DIR/scripts/start_test_appserver.sh /usr/local/bin \
  && \
  if [ "$CMAKE_FROM_APT" != "True" ]; then \
    # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
    $APT purge -y cmake || true \
    && \
    chmod +x $PROJ_DIR/scripts/install_cmake.sh \
    && \
    bash $PROJ_DIR/scripts/install_cmake.sh \
    ; \
  fi \
  && \
  if [ ! -z "$http_proxy" ]; then \
    conan remote update conan-center https://conan.bintray.com False \
    && \
    conan config install $SUB_PROJ_DIR/conan/remotes_disabled_ssl/ \
    ; \
  else \
    conan remote update conan-center https://conan.bintray.com True \
    && \
    conan config install $SUB_PROJ_DIR/conan/remotes/ \
    ; \
  fi \
  && \
  #RUN ["chmod", "+x", "$PROJ_DIR/scripts/install_libunwind.sh"] \
  #RUN ["bash", "-c", "bash $PROJ_DIR/scripts/install_cmake.sh \
  #                    && \
  #                    bash $PROJ_DIR/scripts/install_libunwind.sh"] \
  # https://askubuntu.com/a/1013396
  # https://github.com/phusion/baseimage-docker/issues/319
  # RUN export DEBIAN_FRONTEND=noninteractive \
  # Set it via ARG as this only is available during build:
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  ldconfig \
  && \
  update-ca-certificates --fresh \
  && \
  # need some git config to apply git patch
  git config --global user.email "$GIT_EMAIL" || true \
  && \
  git config --global user.name "$GIT_USERNAME" || true \
  && \
  git submodule update --init --recursive --depth 50 || true \
  && \
  export CC=gcc \
  && \
  export CXX=g++ \
  #&& \
  #cmake -E remove_directory build \
  #&& \
  #cmake -E remove_directory *-build \
  && \
  if [ ! -z "$http_proxy" ]; then \
      git config --global http.proxyAuthMethod 'basic' || true \
      && \
      git config --global http.sslverify false || true \
      && \
      git config --global https.sslverify false || true \
      && \
      git config --global http.proxy $http_proxy || true \
      && \
      git config --global https.proxy $https_proxy || true \
      ; \
  fi \
  && \
  cd $SUB_PROJ_DIR \
  && \
  # create build dir \
  cmake -E make_directory build \
  && \
  if [ "$INSTALL_GRPC_FROM_CONAN" = "True" ]; then \
    # configure \
    cmake -E chdir build conan install --build=missing --profile gcc -o enable_protoc_autoinstall=True .. \
    ; \
  else \
    # configure \
    cmake -E chdir build conan install --build=missing --profile gcc -o enable_protoc_autoinstall=False .. \
    ; \
  fi \
  && \
  # NOTE: Release build (!!!)
  cmake -E chdir build cmake -E time cmake -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DCMAKE_BUILD_TYPE=$BUILD_TYPE .. \
  && \
  # build \
  cmake -E chdir build cmake -E time cmake --build . -- -j6 \
  && \
  cmake -E chdir build make install \
  #&& \
  #cmake -E remove_directory build \
  #&& \
  # \
  #cmake -E remove_directory *-build \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  # remove unused project copy after install
  # NOTE: must remove only copy
  cd $WDIR && rm -rf $PROJ_DIR \
  && \
  git config --global --unset http.proxyAuthMethod || true \
  && \
  git config --global --unset http.proxy || true \
  && \
  git config --global --unset https.proxy || true \
  && \
  # remove unused apps after install
  $APT remove -y git || true \
  && \
  $APT remove -y wget || true \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/*

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
ARG GRPC_POLL_STRATEGY=epoll
ARG GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS=5000
ENV GRPC_VERBOSITY=$GRPC_VERBOSITY \
    GRPC_TRACE=$GRPC_TRACE \
    GRPC_ABORT_ON_LEAKS=$GRPC_ABORT_ON_LEAKS \
    GRPC_POLL_STRATEGY=$GRPC_POLL_STRATEGY \
    GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS=$GRPC_CLIENT_CHANNEL_BACKUP_POLL_INTERVAL_MS \
    GRPC_DEFAULT_SSL_ROOTS_FILE_PATH=$GRPC_DEFAULT_SSL_ROOTS_FILE_PATH
WORKDIR $WDIR
RUN set -ex \
  && \
  # CAP_NET_BIND_SERVICE to grant low-numbered port access to a process
  setcap CAP_NET_BIND_SERVICE=+eip $START_APP \
  && \
  chmod +x $START_APP
ENTRYPOINT ["/bin/bash", "-c", "echo 'starting $START_APP...' && $START_APP $START_APP_OPTIONS"]
#ENTRYPOINT [ "/usr/local/bin/test_appserver_core" ]
EXPOSE 50051
