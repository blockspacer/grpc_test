# allows individual sections to be run by doing: docker build --target ...
FROM gaeus:cxx_build_env as build_target

ARG APT="apt-get -qq --no-install-recommends"
ARG GIT="git"
ARG NPM="npm"
ARG NPX="npx"
ARG NODE="node"
ARG NODE_GYP="node-gyp"
ARG NPM_INSTALL="npm install --loglevel verbose"
# NOTE: under proxy change to:
# NODE_TLS_REJECT_UNAUTHORIZED=0 HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy npm install --unsafe-perm binding --loglevel verbose
ARG NPM_INSTALL_UNSAFE="npm install --unsafe-perm binding --loglevel verbose"
#ARG PROTOC="protoc"
ARG LS_VERBOSE="ls -artl"
ARG PIP="pip3"
ARG CMAKE="cmake"
ARG CONAN="conan"
# NOTE: if not BUILD_GRPC_FROM_SOURCES, then script uses conan protobuf package
ARG BUILD_TYPE=Release
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
    PATH=/usr/bin/:/usr/local/bin/:/go/bin:/usr/local/go/bin:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    ROOT_DIR=/web-ui-copy \
    PROJ_DIR=/web-ui-copy/web-ui \
    PROTO_DIR=/web-ui-copy/proto \
    OS_ARCH=x64 \
    NODE_V=v10.18.1 \
    # see https://github.com/grpc/grpc-web#import-style
    PROTO_IMPORT_STYLE=commonjs \
    # see https://github.com/grpc/grpc-web#wire-format-mode
    GRPC_WEB_MODE=grpcwebtext \
    # see https://github.com/grpc/grpc-web#import-style
    GRPC_WEB_IMPORT_STYLE=commonjs+dts \
    #PROTO_OUT_DIR=/web-ui-copy/web-ui/.generated \
    PROTO_FILE_PATH=/web-ui-copy/proto/emoji.proto \
    # NOTE: PROJ_DIR must be within WDIR
    CA_PROJ_DIR=/opt/project_copy/.ca-certificates \
    NPM_CA_FILE= \
    NODE_GYP_CA_FILE= \
    GOPATH=/go \
    START_APP="python3" \
    START_APP_OPTIONS="-m http.server 9001" \
    CONAN_REVISIONS_ENABLED=1 \
    CONAN_PRINT_RUN_COMMANDS=1 \
    CONAN_LOGGING_LEVEL=10 \
    CONAN_VERBOSE_TRACEBACK=1

# docker build --build-arg NO_SSL="False" APT="apt-get -qq --no-install-recommends" .
ARG NO_SSL="True"

RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $ROOT_DIR

# NOTE: destination must end with a /
COPY "proto/" $PROTO_DIR/
COPY "web-ui/" $PROJ_DIR/
COPY ".ca-certificates/"  $CA_PROJ_DIR/

RUN set -ex \
  && \
  # must exist
  $LS_VERBOSE $PROJ_DIR \
  && \
  (cp $CA_PROJ_DIR/* /usr/local/share/ca-certificates/ || true) \
  && \
  (rm -rf $CA_PROJ_DIR || true) \
  && \
  # requires python
  python3 --version \
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
  if [ "$NPM_CA_FILE" != "" ]; then \
    echo 'WARNING: NPM_CA_FILE CHANGED! SEE NPM_CA_FILE FLAG IN DOCKERFILE' \
    && \
    # must exist
    file $NPM_CA_FILE \
    && \
    # see https://github.com/nodejs/help/issues/979
    ($NPM_INSTALL_UNSAFE --cafile $NPM_CA_FILE custom_npm_ca_file || true) \
    ; \
  fi \
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
  #&& \
  # must exist
  #$PROTOC --version \
  #&& \
  # must exist
  #cd $PROJ_DIR && which protoc-gen-grpc-web  \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  ($APT remove -y node || true) \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  ($APT remove -y nodejs || true) \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  && \
  ($APT remove -y npm || true) \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  && \
  ($APT remove -y npx || true) \
  && \
  $APT install wget tar \
  && \
  mkdir -p /tmp \
  && \
  cd /tmp \
  # install node
  && \
  wget https://nodejs.org/dist/$NODE_V/node-$NODE_V-linux-$OS_ARCH.tar.gz \
  && \
  tar -xvf node-$NODE_V-linux-$OS_ARCH.tar.gz \
  && \
  cp -R node-$NODE_V-linux-$OS_ARCH/* /usr/local/ \
  && \
  cd $PROJ_DIR/ \
  && \
  $LS_VERBOSE \
  && \
  $NODE -v \
  && \
  $NPM -v \
  && \
  $NPX -v \
  && \
  # NOTE: run `npm config` in project directory
  if [ "$NO_SSL" = "True" ]; then \
    echo 'WARNING: SSL CHECKS DISABLED! SEE NO_SSL FLAG IN DOCKERFILE' \
    && \
    $NPM config set strict-ssl false \
    && \
    # NOTE: `http://`, not `https://`
    $NPM config set registry http://registry.npmjs.org/ --global \
    ; \
  fi \
  && \
  # remove old node_modules
  rm -rf node_modules package-lock.json \
  && \
  # remove generated files
  rm -rf build .generated *generated* \
  && \
  $NPM cache clean --force \
  && \
  # to install devDependencies
  $NPM config set -g production false \
  && \
  # https://medium.com/@mallim/how-to-use-node-sass-in-a-closed-environment-859880720f2a
  # OR sudo npm config set sass-binary-site=https://npm.taobao.org/mirrors/node-sass --global
  $NPM_INSTALL_UNSAFE --save-dev node-sass --sass-binary-site=https://npm.taobao.org/mirrors/node-sass \
  && \
  # install app deps
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: NODE_TLS_REJECT_UNAUTHORIZED CHANGED! SEE http_proxy IN DOCKERFILE' \
    && \
    NODE_TLS_REJECT_UNAUTHORIZED=0 HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy $NPM_INSTALL_UNSAFE -g --save-dev --save node-gyp webpack webpack-cli --unsafe-perm binding --loglevel verbose \
    && \
    # NOTE: run `node-gyp configure` in project directory
    # Note: node-gyp configure can give an error gyp: binding.gyp not found, but it's ok.
    ($NODE_GYP configure || true) \
    && \
    if [ "$NODE_GYP_CA_FILE" != "" ]; then \
        echo 'WARNING: NODE_GYP_CA_FILE CHANGED! SEE NODE_GYP_CA_FILE FLAG IN DOCKERFILE' \
        && \
        # must exist
        file $NODE_GYP_CA_FILE \
        && \
        # NOTE: run `node-gyp configure` in project directory
        # see https://github.com/nodejs/help/issues/979
        ($NODE_GYP configure --cafile=$NODE_GYP_CA_FILE || true) \
        ; \
    fi \
    && \
    NODE_TLS_REJECT_UNAUTHORIZED=0 HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy $NPM_INSTALL_UNSAFE \
    ; \
  else \
    $NPM_INSTALL_UNSAFE -g --save-dev --save node-gyp webpack webpack-cli \
    && \
    # NOTE: run `node-gyp configure` in project directory
    # Note: node-gyp configure can give an error gyp: binding.gyp not found, but it's ok.
    ($NODE_GYP configure || true) \
    && \
    if [ "$NODE_GYP_CA_FILE" != "" ]; then \
        echo 'WARNING: NODE_GYP_CA_FILE CHANGED! SEE NODE_GYP_CA_FILE FLAG IN DOCKERFILE' \
        && \
        # must exist
        file $NODE_GYP_CA_FILE \
        && \
        # see https://github.com/nodejs/help/issues/979
        ($NODE_GYP configure --cafile=$NODE_GYP_CA_FILE || true) \
        ; \
    fi \
    && \
    $NPM_INSTALL_UNSAFE \
    ; \
  fi \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo 'WARNING: CONAN SSL CHECKS DISABLED! SEE http_proxy IN DOCKERFILE' \
    && \
    ($CONAN remote update conan-center https://conan.bintray.com False || true) \
    && \
    ($CONAN config install $PROJ_DIR/conan/remotes_disabled_ssl/ || true) \
    ; \
  else \
    ($CONAN remote update conan-center https://conan.bintray.com True || true) \
    && \
    ($CONAN config install $PROJ_DIR/conan/remotes/ || true) \
    ; \
  fi \
  && \
  if [ ! -z "$CONAN_EXTRA_REPOS" ]; then \
    ($CONAN remote add $CONAN_EXTRA_REPOS || true) \
    ; \
  fi \
  && \
  if [ ! -z "$CONAN_EXTRA_REPOS_USER" ]; then \
    ($CONAN $CONAN_EXTRA_REPOS_USER || true) \
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
    $CMAKE -E chdir build $CONAN_INSTALL -s build_type=$BUILD_TYPE .. \
    ; \
  else \
    # TODO: INSTALL without CONAN requires grpc_build_env
    # configure \
    $CMAKE -E chdir build $CONAN_INSTALL -s build_type=$BUILD_TYPE .. \
    ; \
  fi \
  && \
  # NOTE: generates protobuf bindings
  $CMAKE -E chdir build $CMAKE -E time $CMAKE -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DCMAKE_BUILD_TYPE=$BUILD_TYPE .. \
  #&& \
  # build \
  #$CMAKE -E chdir build $CMAKE -E time $CMAKE --build . -- -j6 \
  #&& \
  #$CMAKE -E chdir build make install \
  #&& \
  #mkdir -p $PROTO_OUT_DIR \
  #&& \
  # see https://github.com/grpc/grpc-web
  #$PROTOC -I $PROTO_DIR/ $PROTO_FILE_PATH --js_out=import_style=$PROTO_IMPORT_STYLE:$PROTO_OUT_DIR \
  #       --grpc-web_out=import_style=$GRPC_WEB_IMPORT_STYLE,mode=$GRPC_WEB_MODE:$PROTO_OUT_DIR \
  #&& \
  #$LS_VERBOSE $PROTO_OUT_DIR \
  && \
  # install app deps
  if [ ! -z "$http_proxy" ]; then \
    NODE_TLS_REJECT_UNAUTHORIZED=0 HTTP_PROXY=$http_proxy HTTPS_PROXY=$https_proxy $NPM_INSTALL --save-dev \
    ; \
  else \
    $NPM_INSTALL --save-dev \
    ; \
  fi \
  && \
  $NPX webpack app.js \
  && \
  $LS_VERBOSE dist \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  $LS_VERBOSE \
  && \
  ($PIP uninstall conan || true) \
  && \
  ($PIP uninstall conan_package_tools || true) \
  && \
  # NOTE: make sure all libs linked statically
  rm -rf ~/.conan/ \
  && \
  ($GIT config --global --unset http.proxyAuthMethod || true) \
  && \
  ($GIT config --global --unset http.proxy || true) \
  && \
  ($GIT config --global --unset https.proxy || true) \
  && \
  cd $PROJ_DIR/ \
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
  mkdir -p /etc/ssh/ && echo ClientAliveInterval 60 >> /etc/ssh/sshd_config \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
  && \
  # remove unused build artifacts
  find $PROJ_DIR -type f \( -iname \*.a -o -iname \*.o -o -iname \*.obj -o -iname \*.lib \) -delete \
  && \
  ls \
  # Create a "nobody" non-root user for the next image by crafting an /etc/passwd
  # file that the next image can copy in. This is necessary since the next image
  # is based on scratch, which doesn't have adduser, cat, echo, or even sh.
  && \
  echo "nobody:x:65534:65534:Nobody:/:" > /etc_passwd

# ---- Release ----
# The multi-stage build allows using multiple FROM commands in the same Dockerfile.
# The last FROM command produces the final Docker image,
# all other images are intermediate images (no final Docker image is produced, but all layers are cached).
# NOTE: scratch doesn’t have programs like adduser nor even echo
# FROM scratch AS ...
FROM ubuntu:18.04 AS release_webui_target
ARG APT="apt-get -qq --no-install-recommends"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    PATH=/usr/bin/:/usr/local/bin/:/go/bin:/usr/local/go/bin:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    ROOT_DIR=/web-ui-copy \
    PROJ_DIR=/web-ui-copy/web-ui \
    PROTO_DIR=/web-ui-copy/proto \
    OS_ARCH=x64 \
    START_APP="python3" \
    START_APP_OPTIONS="-m http.server 9001"
RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $ROOT_DIR \
  && \
  if [ ! -z "$http_proxy" ]; then \
    echo "Acquire::http::Verify-Peer \"false\";" >> /etc/apt/apt.conf.d/00proxy \
    && \
    echo "Acquire::https::Verify-Peer \"false\";" >> /etc/apt/apt.conf.d/00proxy \
    ; \
  fi \
  && \
  $APT update \
  && \
  $APT install -y python3 \
  && \
  $APT clean \
  && \
  $APT autoremove \
  && \
  rm -rf /etc/apt/apt.conf.d/00proxy \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/*
COPY --from=build_target $PROJ_DIR $PROJ_DIR
# Copy the /etc_passwd file we created in the builder stage into /etc/passwd in
# the target stage. This creates a new non-root user as a security best
# practice.
COPY --from=build_target /etc_passwd /etc/passwd
# Note that to avoid errors we also had to copy in the SSL certs from the build environment, since we are contacting an https:// url
# COPY --from=build_target /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build_target /etc/ssl/certs/ /etc/ssl/certs
WORKDIR $PROJ_DIR
# Run as the new non-root by default
USER nobody
ENTRYPOINT ["/bin/bash", "-c", "echo 'starting ui server...' && $START_APP $START_APP_OPTIONS"]
EXPOSE 9001
