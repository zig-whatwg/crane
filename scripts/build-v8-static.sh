#!/bin/bash
# Build V8 as a static monolith library for Crane browser
#
# Usage: ./scripts/build-v8-static.sh [output-dir]
#
# Requirements:
# - Xcode command line tools (xcode-select --install)
# - Python 3
# - ~15GB disk space
# - ~30-60 minutes build time
#
# Output: libv8_monolith.a in the specified output directory

set -e

OUTPUT_DIR="${1:-$(pwd)/deps/v8}"
V8_VERSION="${V8_VERSION:-13.5.212.10}"  # Match homebrew version
BUILD_DIR="${BUILD_DIR:-/tmp/v8-build}"

echo "=== V8 Static Build Script ==="
echo "Output directory: $OUTPUT_DIR"
echo "V8 version: $V8_VERSION"
echo "Build directory: $BUILD_DIR"
echo ""

# Check for required tools
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 required"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Error: git required"; exit 1; }

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Step 1: Install depot_tools if not present
DEPOT_TOOLS_DIR="$BUILD_DIR/depot_tools"
if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    echo "==> Installing depot_tools..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH="$DEPOT_TOOLS_DIR:$PATH"

# Step 2: Fetch V8 source
V8_DIR="$BUILD_DIR/v8"
if [ ! -d "$V8_DIR" ]; then
    echo "==> Fetching V8 source..."
    mkdir -p "$V8_DIR"
    cd "$BUILD_DIR"
    fetch v8
    cd v8
    git checkout "refs/tags/$V8_VERSION" || git checkout "origin/main"
    gclient sync
else
    echo "==> Using existing V8 source at $V8_DIR"
    cd "$V8_DIR"
fi

# Step 3: Generate build configuration
echo "==> Generating build configuration..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    V8_TARGET_CPU="arm64"
else
    V8_TARGET_CPU="x64"
fi

# Create args.gn for static monolith build
mkdir -p out/static
cat > out/static/args.gn << ARGS
# Static monolith build for Crane browser
is_component_build = false
v8_monolithic = true
v8_use_external_startup_data = false
is_debug = false
symbol_level = 0
v8_enable_sandbox = true
v8_enable_pointer_compression = true

# Target architecture
target_cpu = "$V8_TARGET_CPU"

# Disable features we don't need
v8_enable_gdbjit = false
v8_enable_disassembler = false
v8_enable_object_print = false
v8_enable_verify_heap = false
v8_enable_trace_maps = false
v8_enable_test_features = false
v8_enable_v8_checks = false

# WebIDL compliance: Don't expose legacy arguments/caller properties on functions
# Chrome uses this setting; without it, FunctionTemplate-created constructors
# have extra "arguments" and "caller" own properties that violate WebIDL spec.
# See: https://chromium.googlesource.com/v8/v8/+/main/BUILD.gn
v8_function_arguments_caller_are_own_props = false

# Disable ICU - we use our own pure Zig intl implementation
v8_enable_i18n_support = false

# Disable chrome plugins and allow warnings for SDK compatibility
clang_use_chrome_plugins = false
treat_warnings_as_errors = false

# Use system libc++ for ABI compatibility
use_custom_libcxx = false

# macOS specific
is_clang = true
ARGS

# Step 4: Build
echo "==> Building V8 monolith (this may take 30-60 minutes)..."
gn gen out/static
ninja -C out/static v8_monolith v8_libplatform v8_libbase

# Step 5: Convert thin archives to fat archives (for linker compatibility)
echo "==> Converting thin archives to fat archives..."
LLVM_AR="$(pwd)/third_party/llvm-build/Release+Asserts/bin/llvm-ar"
cd out/static
$LLVM_AR -t obj/libv8_libplatform.a > /tmp/platform_objs.txt
$LLVM_AR rcs obj/libv8_libplatform_fat.a $(cat /tmp/platform_objs.txt)
$LLVM_AR -t obj/libv8_libbase.a > /tmp/base_objs.txt
$LLVM_AR rcs obj/libv8_libbase_fat.a $(cat /tmp/base_objs.txt)
cd ../..

# Step 6: Copy output
echo "==> Copying output..."
cp out/static/obj/libv8_monolith.a "$OUTPUT_DIR/"
cp out/static/obj/libv8_libplatform_fat.a "$OUTPUT_DIR/"
cp out/static/obj/libv8_libbase_fat.a "$OUTPUT_DIR/"

# Note: ICU is disabled - we use our own pure Zig intl implementation
# No icudtl.dat file will be generated

echo ""
echo "=== Build Complete ==="
echo "Static V8 libraries:"
echo "  $OUTPUT_DIR/libv8_monolith.a"
echo "  $OUTPUT_DIR/libv8_libplatform_fat.a"
echo "  $OUTPUT_DIR/libv8_libbase_fat.a"
echo ""
echo "To use with Crane browser:"
echo "  zig build browser"
echo ""

# Show file sizes
ls -lh "$OUTPUT_DIR"/libv8_*.a
