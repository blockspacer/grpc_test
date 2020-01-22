# Local build

NOTE: You can also want to see build commands in Dockerfile

```bash
# git submodule deinit --all -f
git submodule sync --recursive
git fetch --recurse-submodules
git submodule update --init --recursive --depth 100
# or
git submodule update --force --recursive --init --remote
```

Install grpc https://grpc.io/docs/quickstart/cpp/

Install protobuf from sources https://developers.google.com/protocol-buffers/docs/downloads and (if exists) remove old protobuf version `apt-get remove libprotobuf-dev`

Install cmake like so https://github.com/blockspacer/skia-opengl-emscripten/blob/master/docs/BUILD_ON_UNIX.md#build-and-install-cmake-manually-recommended

Install conan like so https://github.com/blockspacer/CXTPL#install-conan---a-crossplatform-dependency-manager-for-c

Add conan remotes like so https://github.com/blockspacer/skia-opengl-emscripten/blob/master/docs/BUILD_ON_UNIX.md#add-conan-remotes

```bash
# tested with gcc
export CC=gcc
export CXX=g++

export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all,-timer_check,-timer

# create build dir
cmake -E remove_directory build
cmake -E make_directory build

cmake -E chdir build conan install --build=missing --profile gcc -o enable_tests=False ..
# configure
cmake -E chdir build cmake -E time cmake -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DINSTALL_CLING=FALSE -DCMAKE_BUILD_TYPE=Debug ..
# build
cmake -E chdir build cmake -E time cmake --build . -- -j6
```

```bash
HTTP_PROXY= http_proxy= HTTPS_PROXY= https_proxy= no_proxy=localhost,127.0.0.1 ./build/test_appserver_core

# to run under gdb, compile with -DCMAKE_BUILD_TYPE=Debug
HTTP_PROXY= http_proxy= HTTPS_PROXY= https_proxy= no_proxy=localhost,127.0.0.1 gdb ./build/test_appserver_core -ex "run" -ex "set pagination off" -ex "bt" -ex "set confirm off" -ex "quit"
```

## NOTE

Build without debug for production
