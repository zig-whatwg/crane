#!/bin/bash
# Build V8 13.1.203 - the V8 Crane links (jsengines/v8/include/v8-version.h) - for x86_64 Linux, so its
# static archives link with the C++ library Zig gives Crane. Output: jsengines/v8/out/static/obj (the
# path src/runtime/engines/v8/build/archives.zig names on every OS) with args.gn, PROVENANCE and SHA256SUMS. No sudo.
#
#   scripts/build-v8-linux.sh <step>...   (in this order the first time; `all` runs them all)
#     deps       the commands the build needs (git, python3, curl, tar, xz) and the pinned Zig; prints
#                the apt (Ubuntu 26.04) or pacman (Arch) line for what is missing - run it with sudo
#     checkout   V8 13.1.203 in a gclient root of its own ($V8_ROOT, default ~/v8-13.1.203) at that
#                tag's DEPS - V8's clang (llvm-project 6ee7e90a5d21, clang 20), gn and ninja - with
#                --nohooks (13.1.203's vpython hook asks for wheels Chromium's index no longer serves;
#                nothing this build uses comes from a hook, and use_sysroot = false needs no sysroot)
#     toolchain  Zig's libc++ configuration, read from `zig c++ -###` (never copied by hand), and a
#                copy of V8's clang directory whose clang++ compiles with it (below)
#     build      gn gen + ninja v8_monolith v8_libplatform v8_libbase in $V8/out/static-linux, then
#                regular ("fat") archives of the thin ones
#     verify     which C++ library the archives name: std::__1 many times, std::__Cr (Chromium's
#                libc++), std::__cxx11 and __gnu_cxx (libstdc++) never
#     linktest   Zig links a program against the archives: an isolate, a script, a BackingStore
#                through std::unique_ptr and std::shared_ptr (must print 28)
#     compare    the archives' SHA-256s against the installed ones ($CRANE_V8/out/static/obj/SHA256SUMS):
#                a rebuild must reproduce them byte for byte
#     install    copy the archives, args.gn, include/, PROVENANCE and SHA256SUMS to $CRANE_V8
#
# THE C++ LIBRARY (the decision, 2026-11-07, the integrator on server1; this script, lane linux1).
# Crane's v8_wrapper.cpp is compiled by Zig against Zig's libc++ (LLVM 22.1.8's, ABI v1, namespace
# std::__1), and V8's API passes std types across that boundary: std::unique_ptr<v8::BackingStore>,
# std::shared_ptr<v8::BackingStore>, NewDefaultPlatform's std::unique_ptr<v8::Platform>, the
# platform's virtual functions taking std::unique_ptr<Task>. So V8 must be compiled against the same
# library, in the same namespace and ABI, and the binary must hold one C++ runtime, not two.
#  - use_custom_libcxx = true, Linux's default, compiles V8 against Chromium's libc++
#    (buildtools/third_party/libc++, namespace std::__Cr, ABI v2): other mangled names, other layouts.
#    That is right for an embedder whose glue is compiled INSIDE V8's GN build: rusty_v8 (Deno) keeps
#    the default and compiles its src/binding.cc in the same build, as static_library("rusty_v8")
#    with complete_static_lib = true (rusty_v8 BUILD.gn; its .gn default_args leave
#    use_custom_libcxx alone and set use_sysroot = false) - V8, the glue and Chromium's libc++ are
#    one library there. Crane's glue is compiled by Zig, outside GN.
#  - use_custom_libcxx = false compiles V8 against the system's C++ library, libstdc++ on Linux
#    (std::, std::__cxx11): right for Node, whose gyp build compiles V8 and node with one host
#    compiler and one library (tools/v8_gypfiles), wrong beside Zig's libc++ - two runtimes.
#  - macOS's out/static was built with use_custom_libcxx = false against the SDK's libc++ (std::__1,
#    ABI v1: scripts/build-v8-official.sh, control_args), which is why it links with Zig's libc++.
# So here: use_custom_libcxx = false, use_sysroot = false (the host's glibc, which Crane's native
# link uses), use_glib = false (V8 uses no glib, and without the sysroot Chromium's build/config/linux
# asks pkg-config for the HOST's glib-2.0: Ubuntu Server 26.04 has none, and gn gen failed "Package
# 'glib-2.0' not found" - the integrator, 2026-11-08), and clang_base_path at a copy of V8's clang directory whose clang++ is a wrapper that
# compiles every C++ file against ZIG's libc++ headers with Zig's exact _LIBCPP_* configuration (GN
# has no argument for extra C++ flags; V8's own clang still compiles). The build's own executables
# (torque, mksnapshot, ...) link Zig's libc++.a and libc++abi.a, built by Zig. V8's sources are not
# patched. Measured 2026-11-07 (the integrator, server1, 235 s at -j32): the archives name std::__1
# 18,162 times (macOS out/static: 18,151) and std::__Cr, std::__cxx11 and __gnu_cxx 0 times; the
# link test printed 28; include/ is the Mac's, 119 files.
#
# Environment: V8_ROOT (gclient root), CRANE_V8 (install target, default
# ~/projects/crane/jsengines/v8), ZIG (the pinned Zig, default ~/crane-toolchains/zig-0.17.1-dev+77c319a0f0/bin/zig),
# JOBS (ninja -j, default the number of CPUs), STOP (a file whose existence stops the script between steps),
# OUT (the build directory under $V8, default out/static-linux), WRAP and ZIG_RT (the clang wrapper
# directory and Zig's libc++ runtime, default under $V8_ROOT) - a second build beside another's sets
# all three, and compares with `compare`.
set -euo pipefail

V8_TAG=13.1.203
V8_COMMIT=e85c59cee0e2714a720fa759384c19023f8fa8a3 # refs/tags/13.1.203, "Version 13.1.203", 2024-10-14
V8_ROOT="${V8_ROOT:-$HOME/v8-$V8_TAG}"
V8="$V8_ROOT/v8"
CRANE_V8="${CRANE_V8:-$HOME/projects/crane/jsengines/v8}"
ZIG="${ZIG:-$HOME/crane-toolchains/zig-0.17.1-dev+77c319a0f0/bin/zig}"
ZIG_VERSION=0.17.1-dev+77c319a0f0
JOBS="${JOBS:-$(nproc)}"
STOP="${STOP:-$V8_ROOT/STOP}"
OUT="${OUT:-out/static-linux}"
LLVM="$V8/third_party/llvm-build/Release+Asserts"
WRAP="${WRAP:-$V8_ROOT/zigcxx-clang}"
ZIG_RT="${ZIG_RT:-$V8_ROOT/zigcxx-lib}"

log() { echo "[build-v8-linux $(date -u +%H:%M:%SZ)] $*"; }
die() { echo "build-v8-linux: $*" >&2; exit 1; }
check_stop() { [ ! -e "$STOP" ] || die "STOP file $STOP exists; stopping before: $*"; }

# The arguments of macOS's out/static (scripts/build-v8-official.sh control_args) with target_cpu
# x64, and the C++ library choice above.
linux_args() {
  cat <<ARGS
# V8 $V8_TAG for Crane on x86_64 Linux (scripts/build-v8-linux.sh): out/static's arguments
# (scripts/build-v8-official.sh control_args) with target_cpu x64, compiled against Zig's libc++.
is_component_build = false
v8_monolithic = true
v8_use_external_startup_data = false
is_debug = false
symbol_level = 0
v8_enable_sandbox = true
v8_enable_pointer_compression = true
v8_enable_gdbjit = false
v8_enable_disassembler = false
v8_enable_object_print = false
v8_enable_verify_heap = false
v8_enable_trace_maps = false
v8_enable_test_features = false
v8_enable_v8_checks = false
v8_enable_i18n_support = false
clang_use_chrome_plugins = false
treat_warnings_as_errors = false
use_custom_libcxx = false
target_cpu = "x64"
use_sysroot = false
use_glib = false
clang_base_path = "$WRAP"
ARGS
}

step_deps() {
  check_stop deps
  local missing=() apt=() pacman=()
  for cmd in git python3 curl tar xz; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
  done
  for cmd in "${missing[@]}"; do
    case "$cmd" in
      python3) apt+=(python3); pacman+=(python) ;;
      xz) apt+=(xz-utils); pacman+=(xz) ;;
      *) apt+=("$cmd"); pacman+=("$cmd") ;;
    esac
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "missing: ${missing[*]}"
    echo "  Ubuntu: sudo apt-get install -y ${apt[*]}"
    echo "  Arch:   sudo pacman -S --needed ${pacman[*]}"
    exit 1
  fi
  [ -x "$ZIG" ] || die "no Zig at $ZIG (tmp/server1/05-zig.sh builds the pinned one)"
  [ "$("$ZIG" version)" = "$ZIG_VERSION" ] || die "$ZIG is $("$ZIG" version), not the pinned $ZIG_VERSION"
  log "deps: git $(git --version | cut -d' ' -f3), $(python3 --version), zig $("$ZIG" version), glibc $(ldd --version | head -1 | awk '{print $NF}')"
}

step_checkout() {
  check_stop checkout
  mkdir -p "$V8_ROOT"
  cd "$V8_ROOT"
  if [ ! -d depot_tools ]; then
    log "depot_tools (shallow)"
    git clone -q --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
  fi
  # Telemetry off (DEPOT_TOOLS_METRICS=0; the user: no telemetry).
  export PATH="$V8_ROOT/depot_tools:$PATH" DEPOT_TOOLS_METRICS=0
  ( cd depot_tools && ./ensure_bootstrap ) > /dev/null
  export DEPOT_TOOLS_UPDATE=0
  gclient metrics --opt-out > /dev/null 2>&1 || true
  cat > .gclient <<'GCLIENT'
solutions = [
  {
    "name": "v8",
    "url": "https://chromium.googlesource.com/v8/v8.git",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
GCLIENT
  if [ ! -d v8/.git ]; then
    log "V8 $V8_TAG (one commit)"
    git init -q v8
    git -C v8 remote add origin https://chromium.googlesource.com/v8/v8.git
    git -C v8 fetch -q --depth 1 origin "refs/tags/$V8_TAG:refs/tags/$V8_TAG"
    git -C v8 checkout -q "refs/tags/$V8_TAG"
  fi
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "v8 is not at $V8_TAG"
  log "gclient sync, no hooks"
  gclient sync --nohooks --no-history --shallow -D --revision "v8@$V8_COMMIT" --jobs 8 2>&1 | tail -3
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "gclient moved v8 off $V8_TAG"
  ( cd v8 && python3 build/util/lastchange.py -o build/util/LASTCHANGE )
  for t in "$LLVM/bin/clang" "$V8/buildtools/linux64/gn" "$V8/third_party/ninja/ninja"; do
    [ -x "$t" ] || die "the checkout has no $t"
  done
  log "checkout: $("$LLVM/bin/clang" --version | head -1)"
}

# Zig's libc++ configuration, as `zig c++` compiles a C++ file: the -isystem of its libc++ and libc++abi
# headers and every -D_LIBCPP_* / -D_LIBCXXABI_* it defines, read from the compile it would run (the
# "-cc1" line of `zig c++ -###`; its paths are relative to the directory it ran in, its -D values
# separate arguments), so a Zig with another configuration gives V8 that one - plus -nostdinc++, which
# zig passes to the driver, not to cc1: the compile sees no other C++ library's headers.
zig_cxx_flags() {
  local t; t=$(mktemp -d)
  printf 'int main() { return 0; }\n' > "$t/probe.cpp"
  ( cd "$t" && ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" c++ -### -c probe.cpp -o probe.o ) > "$t/cmd" 2>&1
  python3 -I - "$t" "$t/cmd" <<'PY'
import os, shlex, sys
cwd, path = sys.argv[1], sys.argv[2]
line = next((l for l in open(path) if '"-cc1"' in l), None)
if line is None:
    sys.exit("zig c++ -### printed no -cc1 command")
args = shlex.split(line)
out = ["-nostdinc++"]
i = 0
while i < len(args):
    a = args[i]
    if a == "-isystem" and i + 1 < len(args):
        p = args[i + 1].rstrip("/")
        if p.endswith("libcxx/include") or p.endswith("libcxxabi/include"):
            out += ["-isystem", os.path.realpath(os.path.join(cwd, p))]
        i += 2
        continue
    if a == "-D" and i + 1 < len(args):
        if args[i + 1].startswith(("_LIBCPP_", "_LIBCXXABI_")):
            out.append("-D" + args[i + 1])
        i += 2
        continue
    if a.startswith(("-D_LIBCPP_", "-D_LIBCXXABI_")):
        out.append(a)
    i += 1
print("\n".join(out))
PY
  rm -rf "$t"
}

step_toolchain() {
  check_stop toolchain
  [ -x "$LLVM/bin/clang++" ] || die "no V8 clang at $LLVM (run checkout)"
  log "Zig's libc++ runtime (libc++.a, libc++abi.a) for the build's own executables"
  mkdir -p "$ZIG_RT"
  local t; t=$(mktemp -d)
  printf '#include <string>\nint main(){ std::string s("x"); return (int)s.size() - 1; }\n' > "$t/m.cpp"
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" c++ "$t/m.cpp" -o "$t/m"
  "$t/m"
  cp "$(find "$t/gc" -name 'libc++.a' | head -1)" "$ZIG_RT/libc++.a"
  cp "$(find "$t/gc" -name 'libc++abi.a' | head -1)" "$ZIG_RT/libc++abi.a"
  rm -rf "$t"

  log "Zig's libc++ configuration (zig c++ -###)"
  local flags; flags=$(zig_cxx_flags)
  echo "$flags" | grep -q -x -- '-nostdinc++' || die "zig c++ -### named no -nostdinc++"
  echo "$flags" | grep -q 'libcxx/include$' || die "zig c++ -### named no libc++ include directory"
  echo "$flags" | grep -q -x -- '-D_LIBCPP_ABI_NAMESPACE=__1' || die "Zig's libc++ is not std::__1"
  echo "$flags" | sed 's/^/   /'

  log "clang directory with the libc++ wrapper: $WRAP"
  rm -rf "$WRAP"; mkdir -p "$WRAP/bin"
  local f
  for f in "$LLVM"/bin/*; do ln -s "$f" "$WRAP/bin/$(basename "$f")"; done
  rm "$WRAP/bin/clang++"
  ln -s "$LLVM/lib" "$WRAP/lib"
  for f in cr_build_revision llvmobjdump_build_revision; do [ ! -e "$LLVM/$f" ] || ln -s "$LLVM/$f" "$WRAP/$f"; done
  {
    echo '#!/bin/bash'
    echo "# V8's clang++ with Zig's libc++ headers and configuration (scripts/build-v8-linux.sh)."
    echo "real=$(printf %q "$LLVM/bin/clang++")"
    printf 'cxx=('
    while IFS= read -r f; do printf ' %q' "$f"; done <<< "$flags"
    echo ' )'
    echo 'compile=0'
    echo 'for a in "$@"; do case "$a" in -c|-S|-E|-M|-MM) compile=1;; esac; done'
    echo 'if [ $compile = 1 ]; then exec "$real" "$@" "${cxx[@]}"; fi'
    echo "exec \"\$real\" \"\$@\" -nostdlib++ $(printf %q "$ZIG_RT/libc++.a") $(printf %q "$ZIG_RT/libc++abi.a") -lpthread"
  } > "$WRAP/bin/clang++"
  chmod 755 "$WRAP/bin/clang++"
}

step_build() {
  check_stop build
  [ -x "$WRAP/bin/clang++" ] || die "no wrapper at $WRAP (run toolchain)"
  cd "$V8"
  mkdir -p "$OUT"
  linux_args > "$OUT/args.gn"
  log "gn gen $OUT"
  buildtools/linux64/gn gen "$OUT" > /dev/null
  log "ninja -j $JOBS (log: $V8/$OUT/ninja.log.txt)"
  local start; start=$(date +%s)
  third_party/ninja/ninja -C "$OUT" -j "$JOBS" v8_monolith v8_libplatform v8_libbase > "$OUT/ninja.log.txt" 2>&1 \
    || { tail -40 "$OUT/ninja.log.txt"; die "ninja failed"; }
  log "ninja took $(( $(date +%s) - start )) s"
  # Regular archives: GN makes thin ones (members by path), which a link elsewhere cannot read.
  # llvm-ar writes deterministic archives (no timestamps, uid or gid), so a rebuild compares.
  cd "$OUT/obj"
  local lib
  for lib in libplatform libbase; do
    rm -f "libv8_${lib}_fat.a"
    "$LLVM/bin/llvm-ar" rcs "libv8_${lib}_fat.a" $("$LLVM/bin/llvm-ar" t "libv8_${lib}.a")
  done
  if head -c 8 libv8_monolith.a | grep -q thin; then
    mv libv8_monolith.a libv8_monolith_thin.a
    "$LLVM/bin/llvm-ar" rcs libv8_monolith.a $("$LLVM/bin/llvm-ar" t libv8_monolith_thin.a)
    rm libv8_monolith_thin.a
  fi
  ls -la libv8_monolith.a libv8_libplatform_fat.a libv8_libbase_fat.a
}

archives() { echo libv8_monolith.a libv8_libplatform_fat.a libv8_libbase_fat.a; }

step_verify() {
  check_stop verify
  cd "$V8/$OUT/obj"
  local a std1 cr cxx11 gnu bad=0
  for a in $(archives); do
    std1=$("$LLVM/bin/llvm-nm" "$a" 2>/dev/null | grep -c 'St3__1' || true)
    cr=$("$LLVM/bin/llvm-nm" "$a" 2>/dev/null | grep -c 'St3__Cr' || true)
    cxx11=$("$LLVM/bin/llvm-nm" "$a" 2>/dev/null | grep -c '_ZNSt7__cxx11\|_ZNKSt7__cxx11' || true)
    gnu=$("$LLVM/bin/llvm-nm" "$a" 2>/dev/null | grep -c '__gnu_cxx' || true)
    echo "   $a: std::__1 $std1 | std::__Cr $cr | std::__cxx11 $cxx11 | __gnu_cxx $gnu"
    [ "$cr" = 0 ] && [ "$cxx11" = 0 ] && [ "$gnu" = 0 ] || bad=1
  done
  [ "$bad" = 0 ] || die "an archive names another C++ library than Zig's libc++"
  log "verify: one C++ library, Zig's libc++ (std::__1)"
}

step_linktest() {
  check_stop linktest
  local o="$V8/$OUT/obj" t; t=$(mktemp -d)
  cat > "$t/linktest.cc" <<'CC'
#include <cstdio>
#include <memory>
#include "libplatform/libplatform.h"
#include "v8.h"
int main() {
  std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
  v8::V8::InitializePlatform(platform.get());
  v8::V8::Initialize();
  v8::Isolate::CreateParams params;
  params.array_buffer_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
  v8::Isolate* isolate = v8::Isolate::New(params);
  int result = -1;
  {
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    v8::Context::Scope context_scope(context);
    std::unique_ptr<v8::BackingStore> store = v8::ArrayBuffer::NewBackingStore(isolate, 16);
    std::shared_ptr<v8::BackingStore> shared(std::move(store));
    v8::Local<v8::ArrayBuffer> buffer = v8::ArrayBuffer::New(isolate, shared);
    context->Global()->Set(context, v8::String::NewFromUtf8Literal(isolate, "buf"), buffer).Check();
    v8::Local<v8::String> source = v8::String::NewFromUtf8Literal(isolate, "new Uint8Array(buf).length + [1,2,3].map(x => x * 2).reduce((a, b) => a + b)");
    v8::Local<v8::Script> script = v8::Script::Compile(context, source).ToLocalChecked();
    result = script->Run(context).ToLocalChecked()->Int32Value(context).FromJust();
  }
  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete params.array_buffer_allocator;
  std::printf("linktest: %d (expected 28)\n", result);
  return result == 28 ? 0 : 1;
}
CC
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" c++ -std=c++20 -fno-exceptions -fno-rtti -DV8_COMPRESS_POINTERS -DV8_ENABLE_SANDBOX \
    -I "$V8/include" "$t/linktest.cc" "$o/libv8_monolith.a" "$o/libv8_libplatform_fat.a" "$o/libv8_libbase_fat.a" \
    -lpthread -ldl -o "$t/linktest"
  local rc=0
  "$t/linktest" || rc=$?
  rm -rf "$t"
  [ "$rc" = 0 ] || die "the link test failed"
}

step_compare() {
  check_stop compare
  local sums="$CRANE_V8/out/static/obj/SHA256SUMS"
  [ -s "$sums" ] || die "no installed SHA256SUMS at $sums to compare with"
  cd "$V8/$OUT/obj"
  if sha256sum -c "$sums"; then
    log "compare: the rebuild reproduces the installed archives byte for byte"
  else
    sha256sum $(archives)
    die "the rebuild differs from the installed archives ($sums)"
  fi
}

step_install() {
  check_stop install
  local dest="$CRANE_V8/out/static"
  mkdir -p "$dest/obj"
  cd "$V8"
  cp $(for a in $(archives); do echo "$OUT/obj/$a"; done) "$dest/obj/"
  cp "$OUT/args.gn" "$dest/args.gn"
  rm -rf "$CRANE_V8/include"; cp -R include "$CRANE_V8/include"
  {
    echo "V8 $V8_TAG ($(git rev-parse HEAD)) for x86_64 Linux, built $(date -u +%FT%TZ) on $(hostname) by scripts/build-v8-linux.sh"
    echo "clang: $("$LLVM/bin/clang" --version | head -1)"
    echo "libc++: Zig $("$ZIG" version) (std::__1, ABI v1)"
  } > "$dest/PROVENANCE"
  ( cd "$dest/obj" && sha256sum $(archives) > SHA256SUMS && cat SHA256SUMS )
  log "installed to $dest"
}

[ "$#" -gt 0 ] || { sed -n '2,24p' "$0"; exit 2; }
for step in "$@"; do
  case "$step" in
    all) for s in deps checkout toolchain build verify linktest; do "step_$s"; done ;;
    deps|checkout|toolchain|build|verify|linktest|compare|install) "step_$step" ;;
    *) die "unknown step: $step" ;;
  esac
done
