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
  #conan_basic_setup(
  #  # prevent conan_basic_setup from resetting cmake variables
  #  TARGETS
  #  KEEP_RPATHS
  #  # see https://github.com/conan-io/conan/issues/6012
  #  NO_OUTPUT_DIRS)
  conan_basic_setup()
  list(APPEND CMAKE_PROGRAM_PATH ${CONAN_BIN_DIRS})
else()
  message (FATAL_ERROR "must use conan")
endif()
# TODO: make better: link lib dirs
link_directories(${CONAN_LIB_DIRS})

message(STATUS "Conan setup done!")
message(STATUS "CONAN_INCLUDE_DIRS_PROTOBUF: ${CONAN_INCLUDE_DIRS_PROTOBUF}")
message(STATUS "CONAN_LIBS: ${CONAN_LIBS}")
message(STATUS "_gRPC_PROTOBUF_LIBRARIES: ${_gRPC_PROTOBUF_LIBRARIES}")
message(STATUS "CONAN_LIBS_GRPC_CONAN: ${CONAN_LIBS_GRPC_CONAN}")
message(STATUS "CONAN_LIBS_PROTOBUF: ${CONAN_LIBS_PROTOBUF}")
message(STATUS "CMAKE_LIBRARY_PATH: ${CMAKE_LIBRARY_PATH}")
message(STATUS "CMAKE_PROGRAM_PATH: ${CMAKE_PROGRAM_PATH}")
message(STATUS "CMAKE_EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")
message(STATUS "CMAKE_SHARED_LINKER_FLAGS: ${CMAKE_SHARED_LINKER_FLAGS}")
find_program(_gRPC_PROTOBUF_PROTOC_EXECUTABLE protoc NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH)
message(STATUS "_gRPC_PROTOBUF_PROTOC_EXECUTABLE: ${_gRPC_PROTOBUF_PROTOC_EXECUTABLE}")
find_program(PROTOBUF_PROTOC_EXECUTABLE protoc NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH)
message(STATUS "PROTOBUF_PROTOC_EXECUTABLE: ${PROTOBUF_PROTOC_EXECUTABLE}")
find_program(Protobuf_PROTOC_EXECUTABLE protoc NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH)
message(STATUS "Protobuf_PROTOC_EXECUTABLE: ${Protobuf_PROTOC_EXECUTABLE}")

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

set(PROTOBUF_IMPORT_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/../proto)
set(Protobuf_IMPORT_DIRS ${PROTOBUF_IMPORT_DIRS})

# add_definitions(-DNDEBUG)

find_package(gRPC REQUIRED)
find_package(protobuf REQUIRED)
#find_package(Protobuf REQUIRED)
#find_package(GRPC REQUIRED)
find_package( Threads REQUIRED )

message(STATUS "CMAKE_THREAD_LIBS_INIT = ${CMAKE_THREAD_LIBS_INIT}")
#find_package(Protobuf_gRPC REQUIRED)
message(STATUS "Using protobuf ${protobuf_VERSION}")
message( STATUS "gRPC_LIBRARIES      : " ${gRPC_LIBRARIES} )
message( STATUS "_PROTOBUF_LIBPROTOBUF      : " ${_PROTOBUF_LIBPROTOBUF} )
message( STATUS "Protobuf_LIBRARIES      : " ${Protobuf_LIBRARIES} )
message( STATUS "Protobuf_INCLUDE_DIRS   : " ${Protobuf_INCLUDE_DIRS} )

find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin PATHS ${CONAN_BIN_DIRS_GRPC} NO_SYSTEM_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH )

MACRO(PARSE_ARGUMENTS prefix arg_names option_names)
    SET(DEFAULT_ARGS)
    FOREACH(arg_name ${arg_names})
        SET(${prefix}_${arg_name})
    ENDFOREACH(arg_name)
    FOREACH(option ${option_names})
        SET(${prefix}_${option} FALSE)
    ENDFOREACH(option)

    SET(current_arg_name DEFAULT_ARGS)
    SET(current_arg_list)
    FOREACH(arg ${ARGN})
        SET(larg_names ${arg_names})
        LIST(FIND larg_names "${arg}" is_arg_name)
        IF (is_arg_name GREATER -1)
            SET(${prefix}_${current_arg_name} ${current_arg_list})
            SET(current_arg_name ${arg})
            SET(current_arg_list)
        ELSE (is_arg_name GREATER -1)
            SET(loption_names ${option_names})
            LIST(FIND loption_names "${arg}" is_option)
            IF (is_option GREATER -1)
                SET(${prefix}_${arg} TRUE)
            ELSE (is_option GREATER -1)
                SET(current_arg_list ${current_arg_list} ${arg})
            ENDIF (is_option GREATER -1)
        ENDIF (is_arg_name GREATER -1)
    ENDFOREACH(arg)
    SET(${prefix}_${current_arg_name} ${current_arg_list})
ENDMACRO(PARSE_ARGUMENTS)

FUNCTION(PROTOBUF_GENERATE_CPP SRCS HDRS)

    # argument parsing
    PARSE_ARGUMENTS(ARG "PROTOROOT;PROTOFILES;OUTPATH;EXPORT_MACRO" "DEBUG" ${ARGN})

    IF(NOT ARG_PROTOFILES)
        MESSAGE(SEND_ERROR "Error: PROTOBUF_GENERATE_CPP() called without any proto files")
        RETURN()
    ENDIF(NOT ARG_PROTOFILES)
    LIST(LENGTH ARG_PROTOROOT PROTOROOT_LENGTH)
    IF(PROTOROOT_LENGTH GREATER 1)
        MESSAGE(SEND_ERROR "Error: PROTOBUF_GENERATE_CPP() called with too many protoroots, only one is allowed")
        RETURN()
    ENDIF()
    LIST(LENGTH ARG_OUTPATH OUTPATH_LENGTH)
    IF(OUTPATH_LENGTH GREATER 1)
        MESSAGE(SEND_ERROR "Error: PROTOBUF_GENERATE_CPP() called with too many outpaths, only one is allowed")
        RETURN()
    ENDIF()
    LIST(LENGTH ARG_EXPORT_MACRO EXPORT_MACRO_LENGTH)
    IF(EXPORT_MACRO_LENGTH GREATER 1)
        MESSAGE(SEND_ERROR "Error: PROTOBUF_GENERATE_CPP() called with too many export macro names, only one is allowed")
        RETURN()
    ENDIF()

    SET(OUTPATH ${CMAKE_CURRENT_BINARY_DIR})
    IF(OUTPATH_LENGTH EQUAL 1)
        SET(OUTPATH ${ARG_OUTPATH})
    ENDIF()
    SET(PROTOROOT ${CMAKE_CURRENT_SOURCE_DIR})
    IF(PROTOROOT_LENGTH EQUAL 1)
        SET(PROTOROOT ${ARG_PROTOROOT})
    ENDIF()

    SET(ARG_EXPORT "")
    IF(EXPORT_MACRO_LENGTH EQUAL 1)
        SET(ARG_EXPORT "dllexport_decl=${ARG_EXPORT_MACRO}:")
    ENDIF()

    IF(ARG_DEBUG)
        MESSAGE("OUTPATH: ${OUTPATH}")
        MESSAGE("PROTOROOT: ${PROTOROOT}")
    ENDIF()

    # the real logic
    SET(${SRCS})
    SET(${HDRS})
    FOREACH(PROTOFILE ${ARG_PROTOFILES})

        # ensure that the file ends with .proto
        STRING(REGEX MATCH "\\.proto$$" PROTOEND ${PROTOFILE})
        IF(NOT PROTOEND)
            MESSAGE(SEND_ERROR "Proto file '${PROTOFILE}' does not end with .proto")
        ENDIF()

        GET_FILENAME_COMPONENT(PROTO_PATH ${PROTOFILE} PATH)
        GET_FILENAME_COMPONENT(ABS_FILE ${PROTOFILE} ABSOLUTE)
        GET_FILENAME_COMPONENT(FILE_WE ${PROTOFILE} NAME_WE)

        IF(ARG_DEBUG)
            MESSAGE("file ${PROTOFILE}:")
            MESSAGE("  PATH=${PROTO_PATH}")
            MESSAGE("  ABS_FILE=${ABS_FILE}")
            MESSAGE("  FILE_WE=${FILE_WE}")
            MESSAGE("  PROTOROOT=${PROTOROOT}")
        ENDIF()

        # find out of the file is in the specified proto root
        # TODO clean the PROTOROOT so that it does not form a regex itself?
        STRING(REGEX MATCH "^${PROTOROOT}" IN_ROOT_PATH ${PROTOFILE})
        STRING(REGEX MATCH "^${PROTOROOT}" IN_ROOT_ABS_FILE ${ABS_FILE})

        IF(IN_ROOT_PATH)
            SET(MATCH_PATH ${PROTOFILE})
        ELSEIF(IN_ROOT_ABS_FILE)
            SET(MATCH_PATH ${ABS_FILE})
        ELSE()
            MESSAGE(SEND_ERROR "Proto file '${PROTOFILE}' is not in protoroot '${PROTOROOT}'")
        ENDIF()

        # build the result file name
        STRING(REGEX REPLACE "^${PROTOROOT}(/?)" "" ROOT_CLEANED_FILE ${MATCH_PATH})
        IF(ARG_DEBUG)
            MESSAGE("  ROOT_CLEANED_FILE=${ROOT_CLEANED_FILE}")
        ENDIF()
        STRING(REGEX REPLACE "\\.proto$$" "" EXT_CLEANED_FILE ${ROOT_CLEANED_FILE})
        IF(ARG_DEBUG)
            MESSAGE("  EXT_CLEANED_FILE=${EXT_CLEANED_FILE}")
        ENDIF()

        SET(CPP_FILE "${OUTPATH}/${EXT_CLEANED_FILE}.pb.cc")
        SET(H_FILE "${OUTPATH}/${EXT_CLEANED_FILE}.pb.h")

        IF(ARG_DEBUG)
            MESSAGE("  CPP_FILE=${CPP_FILE}")
            MESSAGE("  H_FILE=${H_FILE}")
        ENDIF()

        LIST(APPEND ${SRCS} "${CPP_FILE}")
        LIST(APPEND ${HDRS} "${H_FILE}")

        ADD_CUSTOM_COMMAND(
            OUTPUT "${CPP_FILE}"
                   "${H_FILE}"
            COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPATH}
            COMMAND ${PROTOBUF_PROTOC_EXECUTABLE}
            ARGS "--cpp_out=${ARG_EXPORT}${OUTPATH}" --proto_path "${PROTOROOT}" "${MATCH_PATH}"
            DEPENDS ${ABS_FIL}
            COMMENT "Running C++ protocol buffer compiler on ${MATCH_PATH} with root ${PROTOROOT}, generating: ${CPP_FILE}"
            VERBATIM)

    ENDFOREACH()

    SET_SOURCE_FILES_PROPERTIES(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
    SET(${SRCS} ${${SRCS}} PARENT_SCOPE)
    SET(${HDRS} ${${HDRS}} PARENT_SCOPE)

ENDFUNCTION()

function(PROTOBUF_GENERATE_GRPC_CPP SRCS HDRS)
  if(NOT ARGN)
    message(SEND_ERROR "Error: PROTOBUF_GENERATE_GRPC_CPP() called without any proto files")
    return()
  endif()

  if(PROTOBUF_GENERATE_CPP_APPEND_PATH) # This variable is common for all types of output.
    # Create an include path for each file specified
    foreach(FIL ${ARGN})
      get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
      get_filename_component(ABS_PATH ${ABS_FIL} PATH)
      list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
      if(${_contains_already} EQUAL -1)
        list(APPEND _protobuf_include_path -I ${ABS_PATH})
      endif()
    endforeach()
  else()
    set(_protobuf_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  if(DEFINED PROTOBUF_IMPORT_DIRS)
    foreach(DIR ${PROTOBUF_IMPORT_DIRS})
      get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
      list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
      if(${_contains_already} EQUAL -1)
        list(APPEND _protobuf_include_path -I ${ABS_PATH})
      endif()
    endforeach()
  endif()

  set(${SRCS})
  set(${HDRS})
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)

    list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc")
    list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h")

    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc"
      "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h"
      COMMAND  ${PROTOBUF_PROTOC_EXECUTABLE}
      ARGS --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
      --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
      ${_protobuf_include_path} ${ABS_FIL}
      DEPENDS ${ABS_FIL} ${PROTOBUF_PROTOC_EXECUTABLE}
      COMMENT "Running gRPC C++ protocol buffer compiler on ${FIL}!"
      VERBATIM)
  endforeach()

  set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
  set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

function(GRPC_GENERATE_CPP SRCS HDRS)
  if(NOT ARGN)
    message(SEND_ERROR "Error: GRPC_GENERATE_CPP() called without any proto files")
    return()
  endif()

  if(PROTOBUF_GENERATE_CPP_APPEND_PATH)
    # Create an include path for each file specified
    foreach(FIL ${ARGN})
      get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
      get_filename_component(ABS_PATH ${ABS_FIL} PATH)
      list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
      if(${_contains_already} EQUAL -1)
          list(APPEND _protobuf_include_path -I ${ABS_PATH})
      endif()
    endforeach()
  else()
    set(_protobuf_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  if(DEFINED Protobuf_IMPORT_DIRS)
    foreach(DIR ${Protobuf_IMPORT_DIRS})
      get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
      list(FIND _protobuf_include_path ${ABS_PATH} _contains_already)
      if(${_contains_already} EQUAL -1)
          list(APPEND _protobuf_include_path -I ${ABS_PATH})
      endif()
    endforeach()
  endif()

  set(${SRCS})
  set(${HDRS})
  foreach(FIL ${ARGN})
    get_filename_component(ABS_FIL ${FIL} ABSOLUTE)
    get_filename_component(FIL_WE ${FIL} NAME_WE)

    list(APPEND ${SRCS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc")
    list(APPEND ${HDRS} "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h")

    add_custom_command(
      OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.cc"
             "${CMAKE_CURRENT_BINARY_DIR}/${FIL_WE}.grpc.pb.h"
      COMMAND  ${Protobuf_PROTOC_EXECUTABLE}
          --plugin=protoc-gen-grpc=${GRPC_CPP_PLUGIN}
          --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
          ${_protobuf_include_path}
          ${ABS_FIL}
      DEPENDS ${ABS_FIL} ${Protobuf_PROTOC_EXECUTABLE} ${GRPC_CPP_PLUGIN}
      COMMENT "Running C++ protocol buffer compiler with the GRPC plugin on ${FIL}"
      VERBATIM )
  endforeach()

  set_source_files_properties(${${SRCS}} ${${HDRS}} PROPERTIES GENERATED TRUE)
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
  set(${HDRS} ${${HDRS}} PARENT_SCOPE)
endfunction()

function(generate_proto PROTO_FILENAMES GRPC_FILENAMES)
    #PROTOBUF_GENERATE_CPP(PROTO_SRCS PROTO_HDRS ${PROTO_FILENAMES})
    #PROTOBUF_GENERATE_GRPC_CPP(GRPC_SRCS GRPC_HDRS ${GRPC_FILENAMES})
    # CMake Error: Attempt to add a custom rule to output "/opt/project_copy/test_appserver/build/emoji.grpc.pb.cc.rule" which already has a custom rule.
    #GRPC_GENERATE_CPP(GRPC_SRCS GRPC_HDRS ${GRPC_FILENAMES})
endfunction()

set(PROTO_OUTPATH ${CMAKE_CURRENT_BINARY_DIR_DIR})
set(PROTOROOT ${CMAKE_CURRENT_SOURCE_DIR}/../proto)
set(RPCS ${CMAKE_CURRENT_SOURCE_DIR}/../proto/emoji.proto)
set(PROTOS ${RPCS})
#protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${PROTOS})
#protobuf_generate_grpc_cpp(GRPC_SRCS GRPC_HDRS ${RPCS})
#generate_proto(${PROTOS} ${RPCS})
PROTOBUF_GENERATE_CPP(PROTO_SRCS PROTO_HDRS PROTOFILES ${PROTOS} PROTOROOT ${PROTOROOT} OUTPATH ${PROTO_OUTPATH})
GRPC_GENERATE_CPP(GRPC_SRCS GRPC_HDRS ${RPCS})

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
    ${CONAN_LIBS}
    #CONAN_PKG::protobuf
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
    # #CONAN_PKG::catch2
  )

target_include_directories(${PROJECT_NAME}
  PRIVATE
    ${PROTOBUF_INCLUDE_DIR}
    ${Protobuf_INCLUDE_DIRS}
    ${GRPC_INCLUDE_DIR}
    ${gRPC_INCLUDE_DIRS}
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
