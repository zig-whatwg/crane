cmake_minimum_required(VERSION 3.22.1)

project("whatwg-jni")

# Find the pre-built whatwg library
# The library should be placed in src/main/jniLibs/{abi}/libwhatwg.so
find_library(
    whatwg-lib
    whatwg
    PATHS ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}
)

# JNI bridge source
add_library(
    whatwg-jni
    SHARED
    jni_bridge.cpp
)

# Include the C headers from the main project
target_include_directories(
    whatwg-jni
    PRIVATE
    ${CMAKE_SOURCE_DIR}/../../../../../../include
)

# Link against the whatwg library and log library
target_link_libraries(
    whatwg-jni
    ${whatwg-lib}
    log
)
