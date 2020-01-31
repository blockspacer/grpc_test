# About

example conan profiles

## Usage

```bash
conan create . conan/stable -s build_type=Debug --profile clang.profile
conan install conanfile.py --profile clang.profile
```

## How to diagnose errors in conanfile

```bash
# NOTE: about `--keep-source` see https://bincrafters.github.io/2018/02/27/Updated-Conan-Package-Flow-1.1/
CONAN_PRINT_RUN_COMMANDS=1 CONAN_LOGGING_LEVEL=10 CONAN_VERBOSE_TRACEBACK=1 conan create . conan/stable -s build_type=Debug --profile gcc --build missing --keep-source
```

