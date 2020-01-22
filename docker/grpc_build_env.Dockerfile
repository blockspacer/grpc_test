FROM gaeus:cxx_build_env as grpc_build_env
# NOTE: if not BUILD_GRPC_FROM_SOURCES, then script uses conan protobuf package
ARG BUILD_GRPC_FROM_SOURCES="False"
ARG GRPC_LOCAL_TO_PROJECT_PATH=""
ARG GRPC_RELEASE_TAG=v1.26.x
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ARG APT="apt-get -qq --no-install-recommends"
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
    PROJ_DIR=/opt/project_copy

# create all folders parent to $PROJ_DIR
RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $WDIR
# NOTE: ADD invalidates the cache, COPY does not
# NOTE: destination must end with a /
COPY "grpc" $PROJ_DIR/grpc/
WORKDIR $PROJ_DIR

RUN set -ex \
  && \
  $APT update \
  && \
  cd $PROJ_DIR \
  #RUN ["chmod", "+x", "$PROJ_DIR/scripts/install_libunwind.sh"] \
  #RUN ["bash", "-c", "bash $PROJ_DIR/scripts/install_cmake.sh \
  #                    && \
  #                    bash $PROJ_DIR/scripts/install_libunwind.sh"] \
  # https://askubuntu.com/a/1013396
  # https://github.com/phusion/baseimage-docker/issues/319
  # RUN export DEBIAN_FRONTEND=noninteractive \
  # Set it via ARG as this only is available during build:
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  ldconfig \
  # need some git config to apply git patch
  && \
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
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y libprotobuf-dev || true \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y libprotobuf9v5 || true \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y libprotobuf8 || true \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  find /usr/lib -name "*protobuf*" -delete \
  && \
  if [ "$BUILD_GRPC_FROM_SOURCES" = "True" ]; then \
    if [ ! -z "$GRPC_LOCAL_TO_PROJECT_PATH" ]; then \
      echo "-- installing protobuf (from local filesystem)" \
      && \
      cd $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH/third_party/protobuf \
      && \
      ./autogen.sh && ./configure --enable-shared \
      && \
      # needs extra clean only if copyed from local filesystem
      make clean || true \
      && \
      make -j$(nproc) && make install && make clean && ldconfig \
      && \
      echo "-- installing grpc (requires protobuf) (from local filesystem)" \
      && \
      cd $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH \
      && \
      # needs extra clean only if copyed from local filesystem
      make clean || true \
      && \
      make -j$(nproc) && make install && make clean && ldconfig \
      && \
      # NOTE: must remove only copy
      rm -rf $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH \
      ; \
    else \
      git clone -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /var/local/git/grpc \
      && \
      cd /var/local/git/grpc \
      && \
      git submodule update --init --recursive \
      && \
      echo "-- installing protobuf (from remote repo)" \
      && \
      cd /var/local/git/grpc/third_party/protobuf \
      && \
      git submodule update --init --recursive \
      && \
      ./autogen.sh && ./configure --enable-shared \
      && \
      make -j$(nproc) && make install && ldconfig \
      && \
      echo "-- installing grpc (requires protobuf) (from remote repo)" \
      && \
      cd /var/local/git/grpc \
      && \
      make -j$(nproc) && make install && ldconfig \
      && \
      rm -rf /var/local/git/grpc \
      ; \
    fi \
    ; \
  fi \
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
  $APT remove -y \
                    git \
                    wget \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  # must exist
  ls -artl /usr/local/lib/libprotobuf* \
  && \
  # must exist
  ls -artl /usr/local/lib/libgrpc* \
  && \
  # must exist
  protoc --version
