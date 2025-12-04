cmake_minimum_required(VERSION 3.22.1)

project("whatwg-jni")

# C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find the pre-built whatwg library
# The library should be placed in src/main/jniLibs/{abi}/libwhatwg.so
find_library(
    whatwg-lib
    whatwg
    PATHS ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}
)

# JNI bridge source files
set(JNI_SOURCES
    jni_bridge.cpp
    callback_bridge.cpp
)

# JNI bridge library
add_library(
    whatwg-jni
    SHARED
    ${JNI_SOURCES}
)

# Include directories
target_include_directories(
    whatwg-jni
    PRIVATE
    ${CMAKE_SOURCE_DIR}                          # For jni_bridge.h
    ${CMAKE_SOURCE_DIR}/../../../../../../include # For whatwg.h
)

# Link against the whatwg library and Android log library
target_link_libraries(
    whatwg-jni
    ${whatwg-lib}
    log
)

# Compiler warnings
target_compile_options(
    whatwg-jni
    PRIVATE
    -Wall
    -Wextra
    -Werror=return-type
)
