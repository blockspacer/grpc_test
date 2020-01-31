FROM gaeus:cxx_build_env as grpc_build_env
# NOTE: if not BUILD_GRPC_FROM_SOURCES, then script uses conan protobuf package
ARG BUILD_GRPC_FROM_SOURCES="False"
# GRPC from github.com/grpc/grpc
# NOTE: You can copy sources from local filesystem if you don't want to download a lot of files every time you rebuild Dockerfile
ARG GRPC_LOCAL_TO_PROJECT_PATH=""
ARG GRPC_RELEASE_TAG=v1.26.x
# GRPC_WEB is plugin from github.com/grpc/grpc-web
ARG BUILD_GRPC_WEB_FROM_SOURCES="False"
# NOTE: You can copy sources from local filesystem if you don't want to download a lot of files every time you rebuild Dockerfile
ARG GRPC_WEB_LOCAL_TO_PROJECT_PATH=""
ARG GRPC_WEB_RELEASE_TAG=tags/1.0.7
ARG GIT_EMAIL="you@example.com"
ARG GIT_USERNAME="Your Name"
ARG APT="apt-get -qq --no-install-recommends"
ARG PROTOC="protoc"
ARG LS_VERBOSE="ls -artl"
ARG GO="go"
ARG GO_GET="GIT_SSL_NO_VERIFY=1 $GO get -insecure"
ARG GIT="git"
ARG GIT_CLONE="GIT_SSL_NO_VERIFY=1 git clone"
ARG PIP="pip3"
ARG PIP_INSTALL="$PIP install --no-cache-dir --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org"
ARG INSTALL_GRPC_GO="False"
ARG INSTALL_GRPC_PIP="False"
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
# NOTE: destination must end with a /
COPY "grpc" $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH/
COPY "grpc-web" $PROJ_DIR/$GRPC_WEB_LOCAL_TO_PROJECT_PATH/
WORKDIR $PROJ_DIR

RUN set -ex \
  && \
  $APT update \
  && \
  cd $PROJ_DIR \
  && \
  $LS_VERBOSE $PROJ_DIR \
  && \
  $LS_VERBOSE $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH/ \
  && \
  $LS_VERBOSE $PROJ_DIR/$GRPC_WEB_LOCAL_TO_PROJECT_PATH/ \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  ldconfig \
  # need some git config to apply git patch
  && \
  if [ "$INSTALL_GRPC_GO" = "True" ]; then \
    # must exist
    $GO version \
    && \
    # must exist
    $GO env \
    ; \
  fi \
  && \
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
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  ($APT remove -y libprotobuf-dev || true) \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  ($APT remove -y libprotobuf9v5 || true) \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  ($APT remove -y libprotobuf8 || true) \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  find /usr/lib -name "*protobuf*" -delete \
  && \
  if [ "$BUILD_GRPC_FROM_SOURCES" = "True" ]; then \
    grpc_plugins="grpc_python_plugin"\ "grpc_ruby_plugin"\ "grpc_csharp_plugin"\ "grpc_node_plugin"\ "grpc_objective_c_plugin"\ "grpc_php_plugin"\ "grpc_cpp_plugin" \
    && \
    if [ ! -z "$GRPC_LOCAL_TO_PROJECT_PATH" ]; then \
      echo "-- installing protobuf (from local filesystem)" \
      && \
      cd $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH/third_party/protobuf \
      && \
      ./autogen.sh && ./configure --enable-shared \
      && \
      # needs extra clean before build only if copyed from local filesystem
      (make clean || true) \
      && \
      make -j$(nproc) && make install \
      && \
      echo "-- installing grpc (requires protobuf) (from local filesystem)" \
      && \
      cd $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH \
      && \
      # needs extra clean before build only if copyed from local filesystem
      (make clean || true) \
      && \
      # TODO: try `make HAS_SYSTEM_PROTOBUF=false`
      make -j$(nproc) && make install \
      && \
      echo "Building grpc plugins..." \
      && \
      for plugin in $grpc_plugins; do \
        echo "Building grpc plugin ${plugin}" \
        && \
        chmod +x $PROJ_DIR/grpc/bins/opt/${plugin} \
        && \
        cp $PROJ_DIR/grpc/bins/opt/${plugin} /usr/local/bin/${plugin} \
        && \
        make ${plugin} && make install && ldconfig \
        && \
        # must exist
        file /usr/local/bin/${plugin} \
      ; done \
      && \
      make clean && ldconfig \
      && \
      # NOTE: must remove copied files
      rm -rf $PROJ_DIR/$GRPC_LOCAL_TO_PROJECT_PATH \
      ; \
    else \
      $GIT_CLONE -b ${GRPC_RELEASE_TAG} https://github.com/grpc/grpc /var/local/git/grpc \
      && \
      cd /var/local/git/grpc \
      && \
      $GIT submodule update --init --recursive \
      && \
      echo "-- installing protobuf (from remote repo)" \
      && \
      cd /var/local/git/grpc/third_party/protobuf \
      && \
      $GIT submodule update --init --recursive \
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
      echo "Building grpc plugins..." \
      && \
      for plugin in $grpc_plugins; do \
        echo "Building grpc plugin ${plugin}" \
        && \
        chmod +x /var/local/git/grpc/bins/opt/${plugin} \
        && \
        cp /var/local/git/grpc/bins/opt/${plugin} /usr/local/bin/${plugin} \
        && \
        make ${plugin} && make install && ldconfig \
        && \
        # must exist
        file /usr/local/bin/${plugin} \
      ; done \
      && \
      make clean && ldconfig \
      && \
      rm -rf /var/local/git/grpc \
      ; \
    fi \
    ; \
  fi \
  && \
  # see https://grpc.io/docs/tutorials/basic/web/
  if [ "$BUILD_GRPC_WEB_FROM_SOURCES" = "True" ]; then \
    if [ ! -z "$GRPC_WEB_LOCAL_TO_PROJECT_PATH" ]; then \
      echo "-- installing grpc-web (from local filesystem)" \
      && \
      cd $PROJ_DIR/$GRPC_WEB_LOCAL_TO_PROJECT_PATH \
      && \
      make install-plugin && ldconfig \
      && \
      # NOTE: must remove copied files
      rm -rf $PROJ_DIR/$GRPC_WEB_LOCAL_TO_PROJECT_PATH \
      ; \
    else \
      echo "-- installing grpc-web (from remote repo)" \
      && \
      $GIT_CLONE -b ${GRPC_WEB_RELEASE_TAG} https://github.com/grpc/grpc-web /var/local/git/grpc_web \
      && \
      cd /var/local/git/grpc_web \
      && \
      ./scripts/init_submodules.sh \
      && \
      make install-plugin && ldconfig \
      && \
      rm -rf /var/local/git/grpc_web \
      ; \
    fi \
    ; \
  fi \
  && \
  # must exist
  cd $PROJ_DIR && which protoc-gen-grpc-web \
  && \
  # Install grpc-go and grpc-gateway and companions
  if [ "$INSTALL_GRPC_GO" = "True" ]; then \
    echo "Installing grpc for go into GOPATH=$GOPATH..." \
    && \
    cd $GOPATH \
    && \
    $GO_GET -u google.golang.org/grpc \
    && \
    $GO_GET -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway \
    && \
    $GO_GET -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger \
    && \
    # Install go grpc protobuf plugin
    $GO_GET -u github.com/golang/protobuf/protoc-gen-go \
    ; \
  fi \
  && \
  if [ "$INSTALL_GRPC_PIP" = "True" ]; then \
    echo "Installing grpc for python..." \
    && \
    $PIP_INSTALL "protobuf>=3.0.0a2" \
    && \
    $PIP_INSTALL grpcio \
    ; \
  fi \
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
  $PROTOC --version
