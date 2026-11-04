#!/bin/bash
# GN's cc_wrapper for scripts/build-v8-official.sh's out/official: runs the compile GN asks for
# with -fno-whole-program-vtables last (clang takes the last of a -f/-fno- pair).
#
# use_thin_lto compiles -fwhole-program-vtables (build/config/compiler/BUILD.gn), which lets a
# ThinLTO link devirtualize a call through a class of hidden visibility to the only subclass it
# sees - and V8 is compiled -fvisibility=hidden, with V8_EXPORT empty in a static build. Crane
# subclasses v8::Platform, v8::TaskRunner, v8::Task, the serializer delegates and
# V8InspectorClient in v8_wrapper.cpp, which Zig compiles and links outside that link, so a call
# V8 makes through v8::Platform could be bound to DefaultPlatform's method. Chrome can allow it:
# its own subclasses are in its one LTO link.
exec "$@" -fno-whole-program-vtables
