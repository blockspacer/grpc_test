# gRPC-Web Istio Demo

![Deployment Diagram](deployment.png?raw=true "Deployment Diagram")

## Resources

You can learn more about this project from the following articles.

* https://venilnoronha.io/seamless-cloud-native-apps-with-grpc-web-and-istio
* https://blogs.vmware.com/opensource/2019/04/16/implementing-grpc-web-istio-envoy/

## License

gRPC-Web Istio Demo is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for the full license text.

## Guide

Install nodejs

```bash
# sudo apt remove node npm
# sudo rm /usr/local/bin/node # must be removed
# sudo rm /usr/local/bin/npm # must be removed
# sudo rm -rf /usr/local/lib/node_modules # must be removed
OS_ARCH=x64 # $(uname -m)
NODE_V=v10.18.1
wget https://nodejs.org/dist/$NODE_V/node-$NODE_V-linux-$OS_ARCH.tar.gz
tar -xvf node-$NODE_V-linux-$OS_ARCH.tar.gz
cd node-$NODE_V-linux-$OS_ARCH
sudo cp -rf * /usr/local/
sudo chown -R $USER /usr/local/lib/node_modules
cd -
# npm install npm -g # optional
node -v
npm -v
```

Download Protocol Buffers https://developers.google.com/protocol-buffers/docs/downloads

```bash
python -V # Python 2.7 or newer
sudo apt-get install autoconf automake libtool curl make g++ unzip
git clone https://github.com/protocolbuffers/protobuf.git
cd protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=/usr
make
make check
sudo make install
sudo ldconfig # refresh shared library cache.
protoc --version
```

Install Protocol Buffers for Go https://github.com/golang/protobuf#installation

Note that once we deploy this service over Istio, the grpc- prefix in the Service port name will allow Istio to recognize this as a gRPC service.

```bash
# NOTE: you may want to use NODE_TLS_REJECT_UNAUTHORIZED=0 under proxy during `npm install`
NODE_TLS_REJECT_UNAUTHORIZED=0 \
HTTP_PROXY=http://127.0.0.1:8088 \
HTTPS_PROXY=http://127.0.0.1:8088 \
  npm install \
    --unsafe-perm binding
```
