# allows individual sections to be run by doing: docker build --target ...
FROM gaeus:grpc_build_env as test_webui_target

ARG APT="apt-get -qq --no-install-recommends"
ENV LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    #TERM=screen \
    PATH=/usr/bin/:/usr/local/bin/:/usr/local/include/:/usr/local/lib/:/usr/lib/clang/6.0/include:/usr/lib/llvm-6.0/include/:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH \
    WDIR=/web-ui \
    OS_ARCH=x64 \
    NODE_V=v10.18.1

RUN set -ex \
  && \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && \
  mkdir -p $WDIR

# NOTE: destination must end with a /
COPY "proto/" $WDIR/proto/
COPY "web-ui/" $WDIR/web-ui/

RUN set -ex \
  && \
  # requires python
  python3 --version \
  && \
  $APT update \
  && \
  # must exist
  protoc --version \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y node || true \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y npm || true \
  && \
  # Uninstall the default version provided by Ubuntu package manager, so we can install custom one
  $APT remove -y npx || true \
  && \
  $APT install wget tar \
  && \
  mkdir -p /tmp \
  && \
  cd /tmp \
  && \
  # install node
  wget https://nodejs.org/dist/$NODE_V/node-$NODE_V-linux-$OS_ARCH.tar.gz \
  && \
  tar -xvf node-$NODE_V-linux-$OS_ARCH.tar.gz \
  && \
  cd node-$NODE_V-linux-$OS_ARCH \
  && \
  cp -R * /usr/local/ \
  #&& \
  #chown -R $USER /usr/local/lib/node_modules \
  && \
  cd $WDIR \
  && \
  ls -artl \
  && \
  # npm install npm -g # optional
  node -v \
  && \
  npm -v \
  && \
  npx -v \
  && \
  # install app deps
  npm install \
  && \
  protoc -I ../proto/ ../proto/emoji/emoji.proto --js_out=import_style=commonjs:emoji \
         --grpc-web_out=import_style=commonjs,mode=grpcwebtext:emoji \
  && \
  npx webpack app.js \
  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /build/* \
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

WORKDIR $WDIR
ENTRYPOINT [ "python3" ]
CMD [ "-m", "http.server", "9001" ]
EXPOSE 9001
