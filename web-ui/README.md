# About

## Docker build

prefer docker build

## Local build

based on commands from Dockerfile

You can use local conan remotes, see `conan remote add`

```bash
export VERBOSE=1
export CONAN_REVISIONS_ENABLED=1
export CONAN_VERBOSE_TRACEBACK=1
export CONAN_PRINT_RUN_COMMANDS=1
export CONAN_LOGGING_LEVEL=10

export NPM_INSTALL="npm install --unsafe-perm binding --loglevel verbose"
export CMAKE=cmake
sudo -E $NPM_INSTALL -g node-gyp
# Note: node-gyp configure can give an error gyp: binding.gyp not found, but it's ok.
(node-gyp configure || true)
$NPM_INSTALL
# create build dir
($CMAKE -E remove_directory build || true)
# create build dir
$CMAKE -E make_directory build
$CMAKE -E chdir build $CMAKE -E time conan install -s build_type=Debug --profile=gcc ..
$CMAKE -E chdir build $CMAKE -E time $CMAKE -DBUILD_EXAMPLES=FALSE -DENABLE_CLING=FALSE -DCMAKE_BUILD_TYPE=$BUILD_TYPE ..
npx webpack app.js
```

## Run local server

```bash
python3 -m http.server 9001
```
