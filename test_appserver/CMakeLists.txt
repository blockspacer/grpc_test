cmake_minimum_required(VERSION 3.10.0 FATAL_ERROR)

set(PROJECT_NAME test_appserver_core)
set(PROJECT_VERSION 1.0.1)

# Building as separate project.
project(${PROJECT_NAME} VERSION ${PROJECT_VERSION} LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/build/") # for conan

# --------------------------- conan configuration ------------------------------

# Conan package manager List of packages used by the project is container in
# conanfile.py
option(CONAN_AUTO_INSTALL "Let CMake call conan install automatically" OFF)
if (CONAN_AUTO_INSTALL)
  set(CONAN_PROFILE
      "default"
      CACHE STRING "Conan profile to use during installation")
  include(cmake/conan-auto-install.cmake)
  conan_auto_install(${CONAN_PROFILE})
endif()

if(EXISTS "${CMAKE_BINARY_DIR}/conanbuildinfo.cmake")
  list(APPEND CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR}/)
  include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
  include(${CMAKE_BINARY_DIR}/conan_paths.cmake OPTIONAL)
  conan_basic_setup(
    # prevent conan_basic_setup from resetting cmake variables
    TARGETS
    KEEP_RPATHS
    # see https://github.com/conan-io/conan/issues/6012
    NO_OUTPUT_DIRS)
else()
  message (FATAL_ERROR "must use conan")
endif()

set(BUILD_SHARED_LIBS
  FALSE CACHE BOOL
  "Use .so/.dll")

set(BUILD_EXAMPLES
  FALSE CACHE BOOL
  "Use built-in examples")

set(ENABLE_TESTS
  FALSE CACHE BOOL
  "Use unit tests")

list(APPEND COMMON_FILES
  ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
)

set(PROTOBUF_IMPORT_DIRS "${CMAKE_SOURCE_DIR}/")

# add_definitions(-DNDEBUG)

find_package(Protobuf REQUIRED)
find_package(GRPC REQUIRED)
find_package( Threads REQUIRED )

message(STATUS "CMAKE_THREAD_LIBS_INIT = ${CMAKE_THREAD_LIBS_INIT}")
#find_package(Protobuf_gRPC REQUIRED)
message(STATUS "Using protobuf ${protobuf_VERSION}")
message( STATUS "gRPC_LIBRARIES      : " ${gRPC_LIBRARIES} )
message( STATUS "_PROTOBUF_LIBPROTOBUF      : " ${_PROTOBUF_LIBPROTOBUF} )
message( STATUS "Protobuf_LIBRARIES      : " ${Protobuf_LIBRARIES} )
message( STATUS "Protobuf_INCLUDE_DIRS   : " ${Protobuf_INCLUDE_DIRS} )

function(generate_proto FILENAMES)
    PROTOBUF_GENERATE_CPP(PROTO_SRCS PROTO_HDRS ${FILENAMES})
    PROTOBUF_GENERATE_GRPC_CPP(GRPC_SRCS GRPC_HDRS ${FILENAMES})
endfunction()

set(Protobuf_IMPORT_DIRS ${CMAKE_CURRENT_SOURCE_DIR})

#generate_proto(emoji.proto)
set(RPCS emoji.proto)
set(PROTOS ${RPCS})
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${PROTOS})
protobuf_generate_grpc_cpp(GRPC_SRCS GRPC_HDRS ${RPCS})

#set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/src/ctp_registry.cpp PROPERTIES
#                            GENERATED 1)

# NOTE: cling does not support static libs, so we use SHARED
# https://github.com/root-project/cling/issues/280
# https://gitlab.kitware.com/cmake/cmake/issues/16473
add_executable(${PROJECT_NAME}
  ${COMMON_FILES}
  #emoji.pb
  #emoji.grpc.pb.h
  #emoji.grpc.pb.cc
  ${PROTO_SRCS}
  ${GRPC_SRCS}
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.custom.cmake")
  include(${CMAKE_CURRENT_SOURCE_DIR}/.custom.cmake)
endif()

set(USED_SYSTEM_LIBS
    Threads::Threads # pthread, https://cmake.org/cmake/help/v3.13/module/FindThreads.html
    #${X11_LIBRARIES} # https://cmake.org/cmake/help/v3.13/module/FindX11.html
    #${CMAKE_DL_LIBS} # https://cmake.org/cmake/help/v3.13/variable/CMAKE_DL_LIBS.html
    #EXPAT::EXPAT # https://cmake.org/cmake/help/v3.13/module/FindEXPAT.html
    #ZLIB::ZLIB # https://cmake.org/cmake/help/v3.13/module/FindZLIB.html
               # Custom libs
    stdc++fs # C++17 std::filesystem
    CACHE INTERNAL "USED_SYSTEM_LIBS")

target_link_libraries(
  ${PROJECT_NAME}
  PUBLIC
    ${_PROTOBUF_LIBPROTOBUF}
    ${Protobuf_LIBRARIES}
    ${gRPC_LIBRARIES}
    ${GRPC_LIBRARY}
    ${GRPCPP_LIBRARY}
    ${GPR_LIBRARY}
    #${FOLLY_LIBRARIES}
    # system libs
    ${USED_SYSTEM_LIBS}
    # @note: Order matters https://stackoverflow.com/a/10269201/10904212
    # ${LIBIBERTY_LIBRARY} # used by folly
    # ${DOUBLE_CONVERSION_LIBRARY} # used by folly
    # ${LIBEVENT_LIB} # used by folly
    # ${LZ4_LIBRARY} # used by folly
    # ${LIBUNWIND_LIBRARIES} # used by folly
    # ${LIBLZMA_LIBRARIES} # used by folly
    # ${LIBGFLAGS_LIBRARY} # used by folly
    # ${G3LOG_LIBRARIES} # used by folly
    # glog
    # gflags
    # # boost libs
    # ${USED_BOOST_LIBS}
    # boost_outcome
    # microsoft_gsl
    # Cling::Cling
    # Cling::ClingInterpreter
    # Cling::clingUtils
    # Cling::clingMetaProcessor
    # ${CLING_LIBS}
    # #${CONAN_LIBS}
    # #CONAN_PKG::catch2
  )

target_include_directories(${PROJECT_NAME}
  PRIVATE
    ${PROTOBUF_INCLUDE_DIR}
    ${Protobuf_INCLUDE_DIRS}
    ${GRPC_INCLUDE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR} # PROTOBUF
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    # path to ctp_scripts/1_utils/test_appserver_STD/test_appserver_STD.hpp
    #${CMAKE_CURRENT_SOURCE_DIR}/examples/simple
)

target_include_directories(${PROJECT_NAME}
  PUBLIC
    #${CMAKE_CURRENT_SOURCE_DIR}/submodules/boost.outcome/include/outcome/quickcpplib/include/ # TODO
    # fatal error: folly/executors/CPUThreadPoolExecutor.h: No such file or directory
    #${CMAKE_CURRENT_SOURCE_DIR}/submodules/folly # TODO
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/ # path to ctp_scripts
    #${CMAKE_CURRENT_SOURCE_DIR}/examples/simple # path to ctp_scripts
    #${LIBIBERTY_INCLUDE_DIR} # used by folly
    #${G3LOG_INCLUDE_DIR} # used by folly
    #${LIBEVENT_INCLUDE_DIR} # used by folly
    #${LZ4_INCLUDE_DIR} # used by folly
    #${LIBGFLAGS_INCLUDE_DIR} # used by folly
    #${FOLLY_INCLUDE_DIR}
    ${CONAN_INCLUDE_DIRS}
)

# target_compile_options(${PROJECT_NAME} PRIVATE -fno-rtti) # protobuf requires rtti

# target_compile_definitions(${PROJECT_NAME}
#                             PUBLIC
#                             ${CLING_DEFINITIONS}
#                             )
#
# target_compile_definitions(${PROJECT_NAME} PRIVATE
#                             # https://stackoverflow.com/a/30877725
#                             BOOST_SYSTEM_NO_DEPRECATED BOOST_ERROR_CODE_HEADER_ONLY
#                             IS_test_appserver=1
#                             # https://github.com/facebook/folly/issues/976
#                             #FOLLY_ASSUME_NO_JEMALLOC=1
#                             #UFOLLY_USE_JEMALLOC
#                             )

#set_target_properties(${PROJECT_NAME} PROPERTIES ENABLE_EXPORTS 1)

# POSITION_INDEPENDENT_CODE for -fPIC
#set_property(TARGET ${PROJECT_NAME} PROPERTY POSITION_INDEPENDENT_CODE ON)

if(BUILD_EXAMPLES)
  add_subdirectory(examples)
endif(BUILD_EXAMPLES)

if(ENABLE_TESTS)
  # Now enable our tests.
  enable_testing()
  add_subdirectory(tests)
endif(ENABLE_TESTS)

install(TARGETS ${PROJECT_NAME} DESTINATION "${CMAKE_INSTALL_PREFIX}/bin")
