#!/bin/bash
# Build V8 15.7.112.43 - the newest 15.7.112.x on build day, the V8 Chrome 157 stable ships (the user,
# 2026-11-10: "the same V8 that Chrome 157 uses"; ruling R1: the newest 15.7.112.x tag) - as Crane's
# static monolith for THIS host: macOS arm64 (the SDK's libc++, as out/static) or Linux x86-64 (Zig's
# libc++, as scripts/build-v8-linux.sh). It installs BESIDE the 13.1.203 archives and touches nothing
# of theirs: $CRANE_V8/15.7.112.43/ holds include/ (+ the build's own v8-gn.h), out/static/obj/ (the
# three archives), args.gn, PROVENANCE, SHA256SUMS, ninja-tail.txt and smoke.txt. The plan:
# tmp/plans/v8-update-plan.md (lane v8up). V8's sources are never patched.
#
#   scripts/build-v8-15.7.sh <step>...   (in this order the first time; `all` runs them all)
#     deps       the commands needed, the pinned Zig, free disk (needs ~25 GB: checkout ~10, out ~10)
#     checkout   V8 at the pinned commit in a gclient root of its own ($V8_ROOT, default
#                ~/v8-15.7.112.43), at that tag's DEPS: V8's clang (llvmorg-24-init-7747), gn, ninja,
#                its Rust toolchain (Temporal), cpython3 - with --nohooks (no hook is needed: no
#                sysroot, no Xcode download, LASTCHANGE written here)
#     toolchain  (Linux) a copy of V8's clang directory whose clang++ compiles with Zig's libc++
#     build      gn gen + ninja v8_monolith v8_libplatform v8_libbase and the generated v8-gn.h, then
#                regular ("fat") archives of GN's thin ones
#     verify     one C++ library only (std::__1; never Chromium's std::__Cr or libstdc++); whether
#                the monolith carries Temporal's Rust code and Rust's std (rust.txt)
#     smoke      Zig compiles and links a 60-line program against the archives as Crane would
#                (-DV8_GN_HEADER, the archive's v8-gn.h): `1+1`, a Temporal call, a cppgc
#                allocation that survives a full collection
#     install    copy everything to $CRANE_V8/$V8_TAG/ and write SHA256SUMS
#     clean      delete the build directory (intermediates) after install; the checkout stays
#
# GN ARGUMENTS (each a choice; the plan's section 3): out/static's 13.1.203 arguments (the same list
# as scripts/build-v8-official.sh control_args and scripts/build-v8-linux.sh linux_args), plus:
#  - use_siso = false: V8 15.7's .gn makes Siso the default; this script runs ninja, as before.
#  - v8_enable_partition_alloc = false: 15.7 defaults it ON for a standalone V8 (BUILD.gn:719), but
#    Chrome's own V8 never uses it (BUILD.gn:964 asserts !build_with_chromium || !partition_alloc),
#    nor does Node. V8 keeps allocating through malloc and the platform, as at 13.1.
#  - v8_enable_temporal_support = true: Temporal ships in 15.7 (feature-flags.h, the shipped list) and
#    in Chrome 157; ruling R2 (the user, 2026-11-10): ship it, with V8's own Rust toolchain (DEPS
#    third_party/rust-toolchain) in this build only - no Rust in Crane's tools. Without ICU, V8 bakes
#    a zoneinfo64 table into the archive (BUILD.gn:7336).
#  - v8_generate_external_defines_header = true: the build writes gen/include/v8-gn.h with every
#    define V8's public headers depend on (BUILD.gn:3937, tools/gen-v8-gn.py), installed with
#    include/; Crane compiles with -DV8_GN_HEADER instead of a hand-kept list (lesson
#    architecture-a-headers-abi-defines-come-from-the-archive-not-the-gn-branch-you-read).
#  - cppgc_enable_object_names = false: 15.7 turns it on for macOS and Linux (13.1: Chrome for Testing
#    only). It makes cppgc::Persistent keep a source location (KeepLocationPolicy,
#    cppgc/internal/pointer-policies.h:245): bigger handles, for heap-snapshot names only, nothing a
#    page can see. 13.1's behaviour kept.
#  - cppgc_enable_object_section_gcinfo = false: 15.7 turns it on for macOS and Linux. GCInfo records
#    then live in a linker section found through section$start$__DATA$gc_info_section /
#    __start_gc_info_section, which the FINAL link (Zig's, for Crane) must define for V8's objects and
#    v8_wrapper.cpp's together - unproven for Zig's Mach-O and ELF linkers. Off: GCInfo indices are
#    registered at run time, as at 13.1.
#
# Environment: V8_ROOT (gclient root), CRANE_V8 (install root, default ~/projects/crane/jsengines/v8),
# ZIG (the pinned Zig), JOBS (ninja -j; default the CPU count), STOP (a file whose existence stops the
# script between steps; default $V8_ROOT/STOP; `stop.sh`-style TERM also stops ninja), OUT (the build
# directory under $V8, default out/static-15.7), DEVELOPER_DIR (macOS: an Xcode; Chromium's build/
# asks xcodebuild for the SDK, which the Command Line Tools cannot answer).
set -euo pipefail

V8_TAG=15.7.112.43
# refs/tags/15.7.112.43, "Version 15.7.112.43", 2026-11-10 17:33 UTC - resolved 2026-11-10 20:47 UTC as
# the newest 15.7.112.x (git ls-remote); Chromium's branch-heads/8103 DEPS v8_revision is the same
# commit. Chrome 157.0.8103.51 (stable, 2026-11-10) ships 15.7.112.23 (440c1c463e2e); .24-.43 are
# [M157] merges with an identical include/ (v8-version.h aside).
V8_COMMIT=307108153d1e35e6e74528ee55f97b0cd59bf182
V8_ROOT="${V8_ROOT:-$HOME/v8-$V8_TAG}"
V8="$V8_ROOT/v8"
CRANE_V8="${CRANE_V8:-$HOME/projects/crane/jsengines/v8}"
DEST="$CRANE_V8/$V8_TAG"
ZIG="${ZIG:-$HOME/crane-toolchains/zig-0.17.1-dev+77c319a0f0/bin/zig}"
ZIG_VERSION=0.17.1-dev+77c319a0f0
OUT="${OUT:-out/static-15.7}"
STOP="${STOP:-$V8_ROOT/STOP}"
LLVM="$V8/third_party/llvm-build/Release+Asserts"
WRAP="${WRAP:-$V8_ROOT/zigcxx-clang}"
ZIG_RT="${ZIG_RT:-$V8_ROOT/zigcxx-lib}"
case "$(uname -s)" in
  Darwin) HOST_OS=mac; GN_DIR=mac; TARGET_CPU=arm64; NCPU=$(sysctl -n hw.ncpu)
          export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" ;;
  Linux) HOST_OS=linux; GN_DIR=linux64; TARGET_CPU=x64; NCPU=$(nproc) ;;
  *) echo "build-v8-15.7: unsupported host $(uname -s)" >&2; exit 1 ;;
esac
JOBS="${JOBS:-$NCPU}"
if command -v sha256sum > /dev/null; then SHA256=sha256sum; else SHA256="shasum -a 256"; fi
PIDFILE="$V8_ROOT/build.pid"

log() { echo "[build-v8-15.7 $(date -u +%H:%M:%SZ)] $*"; }
die() { echo "build-v8-15.7: $*" >&2; exit 1; }
check_stop() { [ ! -e "$STOP" ] || die "STOP file $STOP exists; stopping before: $*"; }

# A long child runs in the background so a TERM reaches it between bash's foreground commands; the
# trap kills it, and ninja stops the compiles it started. The pid file names this script for a stop.
child=""
on_term() { [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true; rm -f "$PIDFILE"; die "terminated"; }
trap on_term TERM INT
run_long() {
  "$@" &
  child=$!
  local rc=0
  wait "$child" || rc=$?
  child=""
  return $rc
}

static_args() {
  cat <<ARGS
# V8 $V8_TAG for Crane ($HOST_OS $TARGET_CPU, scripts/build-v8-15.7.sh): out/static's 13.1.203 arguments
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
target_cpu = "$TARGET_CPU"
# + V8 15.7 (the header of scripts/build-v8-15.7.sh says why, one by one)
use_siso = false
v8_enable_partition_alloc = false
v8_enable_temporal_support = true
v8_generate_external_defines_header = true
cppgc_enable_object_names = false
cppgc_enable_object_section_gcinfo = false
ARGS
  if [ "$HOST_OS" = linux ]; then
    cat <<ARGS
# Linux: the host's glibc, no glib, V8's clang compiling against Zig's libc++ (scripts/build-v8-linux.sh)
use_sysroot = false
use_glib = false
clang_base_path = "$WRAP"
ARGS
  fi
}

step_deps() {
  check_stop deps
  local cmd
  for cmd in git python3 curl tar xz; do command -v "$cmd" > /dev/null || die "missing command: $cmd"; done
  [ -x "$ZIG" ] || die "no Zig at $ZIG"
  [ "$("$ZIG" version)" = "$ZIG_VERSION" ] || die "$ZIG is $("$ZIG" version), not the pinned $ZIG_VERSION"
  if [ "$HOST_OS" = mac ]; then
    [ -d "$DEVELOPER_DIR" ] || die "no Xcode at DEVELOPER_DIR=$DEVELOPER_DIR"
    log "Xcode: $(DEVELOPER_DIR=$DEVELOPER_DIR xcodebuild -version 2>/dev/null | tr '\n' ' '); macOS SDK $(xcrun --sdk macosx --show-sdk-version)"
  fi
  mkdir -p "$V8_ROOT"
  local free_kb
  free_kb=$(df -Pk "$V8_ROOT" | awk 'NR == 2 {print $4}')
  log "deps: host $HOST_OS/$TARGET_CPU, $NCPU CPUs, -j $JOBS, zig $("$ZIG" version), free $((free_kb / 1048576)) GB at $V8_ROOT"
  [ "$free_kb" -gt $((25 * 1048576)) ] || die "less than 25 GB free at $V8_ROOT"
}

step_checkout() {
  check_stop checkout
  mkdir -p "$V8_ROOT"
  cd "$V8_ROOT"
  if [ ! -d depot_tools ]; then
    log "depot_tools (shallow)"
    git clone -q --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
  fi
  # No telemetry (the user): DEPOT_TOOLS_METRICS=0 and gclient's opt-out.
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
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "v8 is not at $V8_TAG ($V8_COMMIT)"
  log "gclient sync at $V8_COMMIT, no hooks, no history"
  run_long gclient sync --nohooks --no-history --shallow -D --revision "v8@$V8_COMMIT" --jobs 8
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "gclient moved v8 off $V8_TAG"
  ( cd v8 && python3 build/util/lastchange.py -o build/util/LASTCHANGE )
  local t
  for t in "$LLVM/bin/clang" "$V8/buildtools/$GN_DIR/gn" "$V8/third_party/ninja/ninja" \
    "$V8/third_party/rust-toolchain/bin/rustc" "$V8/third_party/cpython3/host/bin/python3"; do
    [ -x "$t" ] || die "the checkout has no $t"
  done
  grep -q "V8_PATCH_LEVEL 43" v8/include/v8-version.h || die "include/v8-version.h is not $V8_TAG"
  log "checkout: $("$LLVM/bin/clang" --version | head -1); $("$V8/third_party/rust-toolchain/bin/rustc" --version); $(du -sh "$V8_ROOT" | cut -f1)"
}

# Zig's libc++ configuration as `zig c++` compiles a C++ file (scripts/build-v8-linux.sh, verbatim).
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

# Linux only: V8's clang directory with a clang++ that compiles against Zig's libc++ (the decision
# and its reasons: scripts/build-v8-linux.sh, "THE C++ LIBRARY").
step_toolchain() {
  check_stop toolchain
  [ "$HOST_OS" = linux ] || { log "toolchain: macOS uses the SDK's libc++ (use_custom_libcxx = false), nothing to do"; return 0; }
  [ -x "$LLVM/bin/clang++" ] || die "no V8 clang at $LLVM (run checkout)"
  mkdir -p "$ZIG_RT"
  local t; t=$(mktemp -d)
  printf '#include <string>\nint main(){ std::string s("x"); return (int)s.size() - 1; }\n' > "$t/m.cpp"
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" c++ "$t/m.cpp" -o "$t/m"
  "$t/m"
  cp "$(find "$t/gc" -name 'libc++.a' | head -1)" "$ZIG_RT/libc++.a"
  cp "$(find "$t/gc" -name 'libc++abi.a' | head -1)" "$ZIG_RT/libc++abi.a"
  rm -rf "$t"
  local flags; flags=$(zig_cxx_flags)
  echo "$flags" | grep -q -x -- '-nostdinc++' || die "zig c++ -### named no -nostdinc++"
  echo "$flags" | grep -q -x -- '-D_LIBCPP_ABI_NAMESPACE=__1' || die "Zig's libc++ is not std::__1"
  rm -rf "$WRAP"; mkdir -p "$WRAP/bin"
  local f
  for f in "$LLVM"/bin/*; do ln -s "$f" "$WRAP/bin/$(basename "$f")"; done
  rm "$WRAP/bin/clang++"
  ln -s "$LLVM/lib" "$WRAP/lib"
  for f in cr_build_revision llvmobjdump_build_revision; do [ ! -e "$LLVM/$f" ] || ln -s "$LLVM/$f" "$WRAP/$f"; done
  {
    echo '#!/bin/bash'
    echo "# V8's clang++ with Zig's libc++ headers and configuration (scripts/build-v8-15.7.sh)."
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
  log "toolchain: $WRAP (Zig libc++ $(echo "$flags" | grep -c . ) flags)"
}

archives() { echo libv8_monolith.a libv8_libplatform_fat.a libv8_libbase_fat.a; }

step_build() {
  check_stop build
  [ "$HOST_OS" = mac ] || [ -x "$WRAP/bin/clang++" ] || die "no clang wrapper at $WRAP (run toolchain)"
  cd "$V8"
  mkdir -p "$OUT"
  static_args > "$OUT/args.gn"
  log "gn gen $OUT"
  "buildtools/$GN_DIR/gn" gen "$OUT" > "$OUT/gn-gen.txt" 2>&1 || { cat "$OUT/gn-gen.txt"; die "gn gen failed"; }
  check_stop "ninja"
  log "ninja -C $OUT -j $JOBS v8_monolith v8_libplatform v8_libbase gen/include/v8-gn.h (log: $V8/$OUT/ninja.log.txt)"
  local start; start=$(date +%s)
  run_long third_party/ninja/ninja -C "$OUT" -j "$JOBS" v8_monolith v8_libplatform v8_libbase gen/include/v8-gn.h \
    > "$OUT/ninja.log.txt" 2>&1 || { tail -60 "$OUT/ninja.log.txt"; die "ninja failed"; }
  log "ninja took $(( $(date +%s) - start )) s"
  tail -3 "$OUT/ninja.log.txt"
  [ -s "$OUT/gen/include/v8-gn.h" ] || die "the build wrote no gen/include/v8-gn.h"
  # Regular archives: GN makes thin ones (members by path), which a link elsewhere cannot read.
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

step_verify() {
  check_stop verify
  cd "$V8/$OUT/obj"
  local nm="$LLVM/bin/llvm-nm" a std1 cr cxx11 gnu bad=0
  for a in $(archives); do
    std1=$("$nm" "$a" 2>/dev/null | grep -c 'St3__1' || true)
    cr=$("$nm" "$a" 2>/dev/null | grep -c 'St3__Cr' || true)
    cxx11=$("$nm" "$a" 2>/dev/null | grep -c '_ZNSt7__cxx11\|_ZNKSt7__cxx11' || true)
    gnu=$("$nm" "$a" 2>/dev/null | grep -c '__gnu_cxx' || true)
    echo "   $a: std::__1 $std1 | std::__Cr $cr | std::__cxx11 $cxx11 | __gnu_cxx $gnu"
    [ "$cr" = 0 ] && [ "$cxx11" = 0 ] && [ "$gnu" = 0 ] || bad=1
  done
  [ "$bad" = 0 ] || die "an archive names another C++ library than std::__1"
  # Temporal's Rust code (temporal_capi, temporal_rs) and Rust's std: defined in the monolith, or
  # only referenced (then Crane's link must add them)?
  {
    echo "monolith members: $("$LLVM/bin/llvm-ar" t libv8_monolith.a | wc -l | tr -d ' ')"
    echo "members whose name looks Rust (.rlib/.rcgu/temporal): $("$LLVM/bin/llvm-ar" t libv8_monolith.a | grep -c -E 'rcgu|rlib|temporal' || true)"
    echo "defined temporal_rs/temporal_capi C symbols: $("$nm" --defined-only libv8_monolith.a 2>/dev/null | grep -c -i -E ' [TDBRS] _?temporal_rs_' || true)"
    echo "undefined temporal_rs/temporal_capi C symbols: $("$nm" --undefined-only libv8_monolith.a 2>/dev/null | grep -i -E 'temporal_rs_' | sort -u | wc -l | tr -d ' ')"
    echo "defined Rust-mangled symbols (_R / _ZN..17h): $("$nm" --defined-only libv8_monolith.a 2>/dev/null | grep -c -E ' [TDBRS] _?(_R[A-Za-z]|_ZN.*17h[0-9a-f]{16}E)' || true)"
    echo "undefined Rust std symbols (core/alloc/std): $("$nm" --undefined-only libv8_monolith.a 2>/dev/null | grep -E '_R[A-Za-z].*(4core|5alloc|3std)|_ZN(4core|5alloc|3std)' | sort -u | wc -l | tr -d ' ')"
    echo "rlibs the build made: $(find "$V8/$OUT" -name '*.rlib' | wc -l | tr -d ' '); Rust static libs (.a outside obj/v8*): $(find "$V8/$OUT" -name '*.a' -path '*rust*' | wc -l | tr -d ' ')"
  } | tee "$V8/$OUT/rust.txt"
  log "verify: one C++ library (std::__1); Rust facts in $V8/$OUT/rust.txt"
}

smoke_source() {
  cat <<'CC'
// scripts/build-v8-15.7.sh smoke: the archives as Crane links them (Zig, -DV8_GN_HEADER).
#include <cstdio>
#include <memory>
#include <string>
#include "cppgc/allocation.h"
#include "cppgc/garbage-collected.h"
#include "cppgc/persistent.h"
#include "cppgc/visitor.h"
#include "libplatform/libplatform.h"
#include "v8-cppgc.h"
#include "v8.h"
struct Leaf final : cppgc::GarbageCollected<Leaf> {
  int value = 41;
  void Trace(cppgc::Visitor*) const {}
};
int main() {
  v8::V8::SetFlagsFromString("--expose-gc");
  std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
  v8::V8::InitializePlatform(platform.get());
  v8::V8::Initialize();
  v8::Isolate::CreateParams params;
  params.array_buffer_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
  // V8 >= 13.4 owns and deletes a CppHeap given here (heap.cc Heap::TearDown).
  params.cpp_heap = v8::CppHeap::Create(platform.get(), v8::CppHeapCreateParams({})).release();
  v8::Isolate* isolate = v8::Isolate::New(params);
  int sum = -1, cpp = -1;
  std::string temporal = "?";
  {
    v8::Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    v8::Context::Scope context_scope(context);
    auto run = [&](const char* code) {
      v8::Local<v8::String> source = v8::String::NewFromUtf8(isolate, code).ToLocalChecked();
      return v8::Script::Compile(context, source).ToLocalChecked()->Run(context).ToLocalChecked();
    };
    sum = run("1 + 1")->Int32Value(context).FromJust();
    v8::String::Utf8Value date(isolate, run("Temporal.PlainDate.from('2026-11-10').add({ days: 1 }).toString()"));
    temporal = *date;
    cppgc::Persistent<Leaf> leaf(cppgc::MakeGarbageCollected<Leaf>(isolate->GetCppHeap()->GetAllocationHandle()));
    isolate->RequestGarbageCollectionForTesting(v8::Isolate::kFullGarbageCollection);
    cpp = leaf->value + 1;
  }
  isolate->Dispose();
  v8::V8::Dispose();
  v8::V8::DisposePlatform();
  delete params.array_buffer_allocator;
  std::printf("smoke: 1+1 = %d; Temporal 2026-11-10 + 1 day = %s; cppgc value after a full GC = %d\n", sum, temporal.c_str(), cpp);
  return sum == 2 && temporal == "2026-11-11" && cpp == 42 ? 0 : 1;
}
CC
}

step_smoke() {
  check_stop smoke
  local o="$V8/$OUT/obj" t inc
  t=$(mktemp -d)
  inc="$t/include"
  cp -R "$V8/include" "$inc"
  cp "$V8/$OUT/gen/include/v8-gn.h" "$inc/v8-gn.h"
  smoke_source > "$t/smoke.cc"
  local extra=()
  [ "$HOST_OS" = linux ] && extra=(-lpthread -ldl)
  local rc=0
  # The flags Crane's v8_wrapper.cpp compile would take, with the archive's own defines.
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" c++ -std=c++20 -fno-exceptions -fno-rtti -DV8_GN_HEADER -I "$inc" \
    "$t/smoke.cc" "$o/libv8_monolith.a" "$o/libv8_libplatform_fat.a" "$o/libv8_libbase_fat.a" "${extra[@]}" \
    -o "$t/smoke" > "$t/link.txt" 2>&1 || rc=$?
  if [ "$rc" != 0 ]; then
    {
      echo "LINK FAILED (rc $rc). Undefined symbols, first 40 (Rust std/temporal ones mean Crane's link must add Rust):"
      grep -E 'undefined|Undefined' "$t/link.txt" | head -40
      echo "distinct undefined: $(grep -c -E 'undefined symbol|Undefined symbols' "$t/link.txt" || true)"
    } | tee "$V8/$OUT/smoke.txt"
    cp "$t/link.txt" "$V8/$OUT/smoke-link.txt"
    rm -rf "$t"
    die "the smoke link failed; see $V8/$OUT/smoke.txt"
  fi
  rc=0
  "$t/smoke" > "$V8/$OUT/smoke.txt" 2>&1 || rc=$?
  cat "$V8/$OUT/smoke.txt"
  rm -rf "$t"
  [ "$rc" = 0 ] || die "the smoke test failed (rc $rc)"
  log "smoke: passed"
}

step_install() {
  check_stop install
  [ ! -e "$DEST" ] || die "$DEST exists (remove it first, by hand)"
  mkdir -p "$DEST/out/static/obj"
  cd "$V8"
  cp $(for a in $(archives); do echo "$OUT/obj/$a"; done) "$DEST/out/static/obj/"
  cp -R include "$DEST/include"
  cp "$OUT/gen/include/v8-gn.h" "$DEST/include/v8-gn.h"
  cp "$OUT/args.gn" "$DEST/args.gn"
  tail -40 "$OUT/ninja.log.txt" > "$DEST/ninja-tail.txt"
  cp "$OUT/rust.txt" "$OUT/smoke.txt" "$DEST/"
  {
    echo "V8 $V8_TAG ($(git rev-parse HEAD)) for $HOST_OS $TARGET_CPU, built $(date -u +%FT%TZ) on $(hostname) by scripts/build-v8-15.7.sh"
    echo "clang: $("$LLVM/bin/clang" --version | head -1)"
    echo "rustc: $("$V8/third_party/rust-toolchain/bin/rustc" --version)"
    if [ "$HOST_OS" = mac ]; then echo "libc++: the macOS SDK's (std::__1); SDK $(xcrun --sdk macosx --show-sdk-version)";
    else echo "libc++: Zig $("$ZIG" version) (std::__1, ABI v1)"; fi
  } > "$DEST/PROVENANCE"
  ( cd "$DEST" && find . -type f ! -name SHA256SUMS | LC_ALL=C sort | xargs $SHA256 > SHA256SUMS && $SHA256 -c SHA256SUMS > /dev/null )
  log "installed to $DEST ($(du -sh "$DEST" | cut -f1)); archives: $(cd "$DEST/out/static/obj" && ls -la $(archives) | awk '{printf "%s %s; ", $NF, $5}')"
}

step_clean() {
  check_stop clean
  [ -s "$DEST/SHA256SUMS" ] || die "not installed yet; refusing to delete the build directory"
  log "clean: $V8/$OUT ($(du -sh "$V8/$OUT" | cut -f1)); the checkout stays ($(du -sh "$V8_ROOT" | cut -f1) before)"
  rm -rf "${V8:?}/${OUT:?}"
  log "clean: checkout now $(du -sh "$V8_ROOT" | cut -f1); free $(df -Ph "$V8_ROOT" | awk 'NR == 2 {print $4}')"
}

[ "$#" -gt 0 ] || { sed -n '2,25p' "$0"; exit 2; }
mkdir -p "$V8_ROOT"
echo "$$ $0 $*" > "$PIDFILE"
for step in "$@"; do
  case "$step" in
    all) for s in deps checkout toolchain build verify smoke install; do "step_$s"; done ;;
    deps|checkout|toolchain|build|verify|smoke|install|clean) "step_$step" ;;
    *) die "unknown step: $step" ;;
  esac
done
rm -f "$PIDFILE"
log "done: $*"
