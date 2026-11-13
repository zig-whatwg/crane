#!/bin/bash
# Build V8 15.7.112.43 - the newest 15.7.112.x on build day, the V8 Chrome 157 stable ships (the user,
# 2026-11-10: "the same V8 that Chrome 157 uses"; ruling R1: the newest 15.7.112.x tag) - as Crane's
# static monolith for THIS host (macOS arm64 or Linux x86-64), the way Chrome builds it: against
# Chromium's own libc++ (see "THE C++ LIBRARY"). It installs BESIDE the 13.1.203 archives and touches
# nothing of theirs: $CRANE_V8/15.7.112.43/ holds include/ (+ the build's own v8-gn.h),
# out/static/obj/ (the three V8 archives and libc++_chromium.a), libcxx/ (that libc++'s headers and
# the compile flags a consumer needs, read from the build), args.gn, PROVENANCE, SHA256SUMS,
# ninja-tail.txt, rust.txt and smoke.txt. The plan: tmp/plans/v8-update-plan.md (lane v8up). V8's
# sources are never patched.
#
#   scripts/build-v8-15.7.sh <step>...   (in this order the first time; `all` runs them all)
#     deps       the commands needed, the pinned Zig, free disk (needs ~25 GB: checkout ~10, out ~10)
#     checkout   V8 at the pinned commit in a gclient root of its own ($V8_ROOT, default
#                ~/v8-15.7.112.43), at that tag's DEPS: V8's clang (llvmorg-24-init-7747), gn, ninja,
#                its Rust toolchain (Temporal), cpython3, Chromium's libc++ - with --nohooks (no hook
#                is needed: no sysroot, no Xcode download, LASTCHANGE written here)
#     build      gn gen + ninja v8_monolith v8_libplatform v8_libbase, Chromium's libc++ and libc++abi,
#                and the generated v8-gn.h; then regular ("fat") archives of GN's thin ones
#     verify     one C++ library only (Chromium's std::__Cr; never std::__1 or libstdc++); whether the
#                monolith carries Temporal's Rust code and Rust's std (rust.txt)
#     rust       link d8 (V8's shell) as Chrome would, read its recipe: Temporal's rlibs and Rust's std,
#                repacked as librust_v8.a, and the system libraries (system-libs.txt); d8 runs a smoke
#     smoke      Zig compiles and links a 70-line program against the archives as Crane would (the
#                archive's v8-gn.h, Chromium's libc++ headers and objects, no Zig libc++): `1+1`, a
#                Temporal call, a cppgc allocation that survives a full collection - twice: linked by
#                `zig cc` (LLD on Linux), and as a Debug Zig executable linked by Zig's own linker
#                (-fno-lld: the self-hosted ELF linker Crane's Debug x86_64 builds use), which must run
#                past main (ELF RELOCATIONS)
#     install    copy everything to $CRANE_V8/$V8_TAG.new/, write and check SHA256SUMS, then swap it in;
#                a replaced install's SHA256SUMS is kept as $CRANE_V8/$V8_TAG.SHA256SUMS.replaced-<UTC>
#                (a pinned artifact is never rewritten in place)
#     clean      delete the build directory (intermediates) after install; the checkout stays
#
# THE C++ LIBRARY. V8 15.7 refuses to build its sandbox without libc++ hardening: BUILD.gn:896
# `assert(!v8_enable_sandbox || use_safe_libcxx, "The sandbox requires libc++ hardening")` (5958585ab32,
# 2026-02-20), and build/config/c++/c++.gni:119 sets `use_safe_libcxx = use_custom_libcxx &&
# enable_safe_libcxx` - not an argument. So with the sandbox (Chrome's configuration, and Crane's at
# 13.1) V8 is compiled against Chromium's own libc++ (third_party/libc++, namespace std::__Cr, ABI v2,
# hardened), as Chrome is. 13.1.203's archives were compiled against the SDK's libc++ (macOS) or Zig's
# (Linux), std::__1, because Crane's v8_wrapper.cpp, compiled by Zig, passes std types across V8's API
# (std::unique_ptr<v8::BackingStore>, std::shared_ptr, NewDefaultPlatform's std::unique_ptr, the
# platform's std::unique_ptr<Task>). At 15.7 the wrapper must therefore be compiled against the SAME
# Chromium libc++ (its headers and the defines GN gives every consumer: libcxx/flags.txt, read from a
# real compile command, never written by hand) and the binary must hold that one C++ runtime: Crane's
# V8-linking artifacts link libc++_chromium.a (libc++ + libc++abi from this build) instead of Zig's
# libc++. This is how Chrome links V8, and how rusty_v8 (Deno) does - V8, its glue and Chromium's
# libc++ in one library. The other way, v8_enable_sandbox = false, departs from Chrome 157.
#
# ELF RELOCATIONS (Linux; lane v8up b3d, 2026-11-11). Chromium compiles every object with
# `-Wa,--crel,--allow-experimental-crel` when it targets Linux with lld (build/config/compiler/BUILD.gn:673-679
# at this tag; crbug.com/357878242): relocations in SHT_CREL sections (.crel.text, .crel.data, ...), which lld
# reads since LLVM 19 and Chrome's own link consumes. Zig 0.17's self-hosted ELF linker - the one it uses for a
# Debug x86_64 executable (the snapshot generator, every test binary) - does not read SHT_CREL: it copied the
# .crel.* sections into the output as unknown sections and applied none of their relocations, so the snapshot
# generator called address 0 from __libc_start_main (a null .init_array entry) before main. No GN argument turns
# CREL off but use_lld = false, and `ld.lld -r` keeps an input's CREL. So on Linux this script runs every
# compile with CCC_OVERRIDE_OPTIONS deleting that one argument (clang's driver edits its own command line by
# this variable: clang/tools/driver/driver.cpp, "x" = remove the argument; "#" = silently): the objects carry
# RELA relocations, which every ELF linker reads - the same code, sections and symbols. V8's sources and GN
# files are not changed. Step `verify` fails on any .crel section left.
#
# GN ARGUMENTS (each a choice; the plan's section 3): out/static's 13.1.203 arguments (the same list as
# scripts/build-v8-official.sh control_args) EXCEPT use_custom_libcxx (above), plus:
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
#  - Linux: use_sysroot = false (the host's glibc, which Crane's link uses) and use_glib = false (V8
#    uses no glib, and without the sysroot pkg-config would ask the host for one), as at 13.1.
#
# Environment: V8_ROOT (gclient root), CRANE_V8 (install root, default ~/projects/crane/jsengines/v8),
# ZIG (the pinned Zig), JOBS (ninja -j; default the CPU count), STOP (a file whose existence stops the
# script between steps; default $V8_ROOT/STOP; a TERM to the pid in $V8_ROOT/build.pid stops ninja
# too), OUT (the build directory under $V8, default out/static-15.7), DEVELOPER_DIR (macOS: an Xcode;
# Chromium's build/ asks xcodebuild for the SDK, which the Command Line Tools cannot answer).
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
case "$(uname -s)" in
  Darwin) HOST_OS=mac; GN_DIR=mac; TARGET_CPU=arm64; NCPU=$(sysctl -n hw.ncpu)
          export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" ;;
  Linux) HOST_OS=linux; GN_DIR=linux64; TARGET_CPU=x64; NCPU=$(nproc) ;;
  *) echo "build-v8-15.7: unsupported host $(uname -s)" >&2; exit 1 ;;
esac
JOBS="${JOBS:-$NCPU}"
# Linux: no CREL relocations in any object (see "ELF RELOCATIONS").
[ "$HOST_OS" != linux ] || export CCC_OVERRIDE_OPTIONS='#x-Wa,--crel,--allow-experimental-crel'

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
# except use_custom_libcxx (Chromium's libc++: the sandbox requires its hardening, BUILD.gn:896)
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
use_custom_libcxx = true
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
use_sysroot = false
use_glib = false
ARGS
  fi
}

step_deps() {
  check_stop deps
  local cmd
  for cmd in git python3 curl tar; do command -v "$cmd" > /dev/null || die "missing command: $cmd"; done
  # gclient unpacks the .tar.xz GCS packages (clang, Rust) with Python's tarfile: lzma is what it
  # needs, not an xz binary (macOS hosts have none).
  python3 -c 'import lzma' 2> /dev/null || die "python3 has no lzma module (gclient cannot unpack .tar.xz)"
  [ -x "$ZIG" ] || die "no Zig at $ZIG"
  [ "$("$ZIG" version)" = "$ZIG_VERSION" ] || die "$ZIG is $("$ZIG" version), not the pinned $ZIG_VERSION"
  if [ "$HOST_OS" = mac ]; then
    [ -d "$DEVELOPER_DIR" ] || die "no Xcode at DEVELOPER_DIR=$DEVELOPER_DIR"
    log "Xcode: $(xcodebuild -version 2>/dev/null | tr '\n' ' '); macOS SDK $(xcrun --sdk macosx --show-sdk-version)"
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
  if [ -x "$LLVM/bin/clang" ] && [ -x "$V8/buildtools/$GN_DIR/gn" ] && [ -x "$V8/third_party/rust-toolchain/bin/rustc" ]; then
    log "DEPS already synced (clang, gn, rustc present)"
  else
    log "gclient sync at $V8_COMMIT, no hooks, no history"
    run_long gclient sync --nohooks --no-history --shallow -D --revision "v8@$V8_COMMIT" --jobs 8
  fi
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "gclient moved v8 off $V8_TAG"
  ( cd v8 && python3 build/util/lastchange.py -o build/util/LASTCHANGE )
  local t
  for t in "$LLVM/bin/clang" "$V8/buildtools/$GN_DIR/gn" "$V8/third_party/ninja/ninja" \
    "$V8/third_party/rust-toolchain/bin/rustc" "$V8/third_party/cpython3/host/bin/python3"; do
    [ -x "$t" ] || die "the checkout has no $t"
  done
  [ -d "$V8/third_party/libc++/src/include" ] || die "the checkout has no Chromium libc++ (third_party/libc++/src)"
  grep -q "V8_PATCH_LEVEL 43" v8/include/v8-version.h || die "include/v8-version.h is not $V8_TAG"
  log "checkout: $("$LLVM/bin/clang" --version | head -1); $("$V8/third_party/rust-toolchain/bin/rustc" --version); $(du -sh "$V8_ROOT" | cut -f1)"
}

# The ninja names of Chromium's libc++ and libc++abi targets (source sets GN reaches through
# //build/config:common_deps, so a static library such as the monolith does not carry them).
libcxx_targets() {
  "$V8/third_party/ninja/ninja" -C "$V8/$OUT" -t targets all \
    | sed -n 's#^\(buildtools/third_party/libc++\(abi\)\{0,1\}:libc++\(abi\)\{0,1\}\): phony$#\1#p' | LC_ALL=C sort -u
}

archives() { echo libv8_monolith.a libv8_libplatform_fat.a libv8_libbase_fat.a libc++_chromium.a librust_v8.a; }

step_build() {
  check_stop build
  cd "$V8"
  mkdir -p "$OUT"
  static_args > "$OUT/args.gn"
  log "gn gen $OUT"
  "buildtools/$GN_DIR/gn" gen "$OUT" > "$OUT/gn-gen.txt" 2>&1 || { cat "$OUT/gn-gen.txt"; die "gn gen failed"; }
  local cxx
  cxx=$(libcxx_targets | tr '\n' ' ')
  [ "$(echo "$cxx" | wc -w)" -eq 2 ] || die "expected the libc++ and libc++abi targets, found: '$cxx'"
  check_stop "ninja"
  log "ninja -C $OUT -j $JOBS v8_monolith v8_libplatform v8_libbase $cxx gen/include/v8-gn.h (log: $V8/$OUT/ninja.log.txt)"
  local start; start=$(date +%s)
  # shellcheck disable=SC2086
  run_long third_party/ninja/ninja -C "$OUT" -j "$JOBS" v8_monolith v8_libplatform v8_libbase $cxx gen/include/v8-gn.h \
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
  # Chromium's libc++ and libc++abi objects, one archive.
  rm -f libc++_chromium.a
  "$LLVM/bin/llvm-ar" rcs libc++_chromium.a $(find buildtools/third_party/libc++ buildtools/third_party/libc++abi -name '*.o' | LC_ALL=C sort)
  ls -la libv8_monolith.a libv8_libplatform_fat.a libv8_libbase_fat.a libc++_chromium.a
}

# The flags GN gives a C++ consumer of Chromium's libc++, read from the compile command of one of
# V8's own objects (cwd = the build directory, so relative paths are made absolute): -nostdinc++,
# the libc++/libc++abi -isystem directories, buildtools/third_party/libc++ (its __config_site),
# and every -D_LIBCPP_*, -D_LIBCXXABI_*, -DCR_LIBCXX_REVISION.
libcxx_consumer_flags() {
  local cmd all
  # Into a file first: `ninja ... | grep -m1` would SIGPIPE ninja, and pipefail turns that into failure.
  all=$(mktemp)
  "$V8/third_party/ninja/ninja" -C "$V8/$OUT" -t commands v8_libbase > "$all"
  cmd=$(grep -m1 -- '-nostdinc++' "$all" || true)
  rm -f "$all"
  [ -n "$cmd" ] || die "no v8_libbase compile command with -nostdinc++"
  python3 -I - "$V8/$OUT" "$cmd" <<'PY'
import os, shlex, sys
cwd, cmd = sys.argv[1], sys.argv[2]
args = shlex.split(cmd)
out, i = [], 0
def absolute(p):
    return os.path.realpath(os.path.join(cwd, p))
while i < len(args):
    a = args[i]
    if a == "-nostdinc++":
        out.append(a)
    elif a.startswith("-isystem") and ("libc++" in a or (a == "-isystem" and i + 1 < len(args) and "libc++" in args[i + 1])):
        p = a[len("-isystem"):] or args[i + 1]
        if a == "-isystem":
            i += 1
        out += ["-isystem", absolute(p)]
    elif a.startswith("-I") and a.rstrip("/").endswith("buildtools/third_party/libc++"):
        out += ["-I", absolute(a[2:])]
    elif a.startswith(("-D_LIBCPP_", "-D_LIBCXXABI_", "-DCR_LIBCXX_REVISION")):
        out.append(a)
    i += 1
print("\n".join(out))
PY
}

step_verify() {
  check_stop verify
  cd "$V8/$OUT/obj"
  local nm="$LLVM/bin/llvm-nm" a std1 cr cxx11 gnu crel bad=0 crel_bad=0
  for a in $(archives); do
    [ -f "$a" ] || { echo "   $a: not built yet (step rust)"; continue; }
    std1=$("$nm" "$a" 2>/dev/null | grep -c 'St3__1' || true)
    cr=$("$nm" "$a" 2>/dev/null | grep -c 'St4__Cr' || true)
    cxx11=$("$nm" "$a" 2>/dev/null | grep -c '_ZNSt7__cxx11\|_ZNKSt7__cxx11' || true)
    gnu=$("$nm" "$a" 2>/dev/null | grep -c '__gnu_cxx' || true)
    echo "   $a: std::__Cr $cr | std::__1 $std1 | std::__cxx11 $cxx11 | __gnu_cxx $gnu"
    [ "$std1" = 0 ] && [ "$cxx11" = 0 ] && [ "$gnu" = 0 ] || bad=1
    if [ "$HOST_OS" = linux ]; then
      crel=$("$LLVM/bin/llvm-readelf" -S -W "$a" 2> /dev/null | grep -c -E '\] \.crel\.' || true)
      echo "   $a: CREL relocation sections $crel"
      [ "$crel" = 0 ] || crel_bad=1
    fi
  done
  [ "$crel_bad" = 0 ] || die "an archive member carries CREL relocations, which Zig's ELF linker does not apply (ELF RELOCATIONS)"
  [ "$bad" = 0 ] || die "an archive names another C++ library than Chromium's std::__Cr"
  libcxx_consumer_flags > "$V8/$OUT/libcxx-flags.txt"
  log "libc++ consumer flags ($(wc -l < "$V8/$OUT/libcxx-flags.txt" | tr -d ' ') lines):"
  sed 's/^/   /' "$V8/$OUT/libcxx-flags.txt"
  grep -q -x -- '-nostdinc++' "$V8/$OUT/libcxx-flags.txt" || die "no -nostdinc++ in the consumer flags"
  # Temporal's Rust code (temporal_capi, temporal_rs) and Rust's std: defined in the monolith, or
  # only referenced (then Crane's link must add them)?
  {
    echo "monolith members: $("$LLVM/bin/llvm-ar" t libv8_monolith.a | wc -l | tr -d ' ')"
    echo "members whose name looks Rust (rcgu/rlib/temporal): $("$LLVM/bin/llvm-ar" t libv8_monolith.a | grep -c -E 'rcgu|rlib|temporal' || true)"
    echo "defined temporal_rs C symbols: $("$nm" --defined-only libv8_monolith.a 2>/dev/null | grep -c -E ' [TDBRS] _?temporal_rs_' || true)"
    echo "undefined temporal_rs C symbols: $("$nm" --undefined-only libv8_monolith.a 2>/dev/null | grep -E 'temporal_rs_' | sort -u | wc -l | tr -d ' ')"
    echo "defined Rust-mangled symbols (_R / _ZN..17h): $("$nm" --defined-only libv8_monolith.a 2>/dev/null | grep -c -E ' [TDBRS] _?(_R[A-Za-z]|_ZN.*17h[0-9a-f]{16}E)' || true)"
    echo "undefined Rust core/alloc/std symbols: $("$nm" --undefined-only libv8_monolith.a 2>/dev/null | grep -E '_R[A-Za-z].*(4core|5alloc|3std)|_ZN(4core|5alloc|3std)' | sort -u | wc -l | tr -d ' ')"
    echo "rlibs the build made: $(find "$V8/$OUT" -name '*.rlib' | wc -l | tr -d ' ')"
  } | tee "$V8/$OUT/rust.txt"
  log "verify: one C++ library (Chromium's std::__Cr); Rust facts in $V8/$OUT/rust.txt"
}

# Temporal is Rust (temporal_capi, temporal_rs and their ICU4X crates), and GN's complete static
# monolith carries none of it, nor Rust's std: its objects reference 258 temporal_rs_* symbols that it
# does not define. Chrome's own answer is its final link, which lists every target rlib and the
# system libraries; d8, V8's shell, is linked the same way. So this step links d8 with the response
# file kept, reads Chrome's recipe from it - the rlibs, Rust's allocator shims, the -framework / -l
# system libraries - repacks the rlibs' objects into ONE archive (librust_v8.a: objects only, no
# rmeta members) and writes system-libs.txt; Crane's link adds both. d8 also runs V8's own smoke test.
step_rust() {
  check_stop rust
  cd "$V8"
  log "ninja d8 (kept response file: Chrome's link recipe for V8 + Temporal's Rust)"
  run_long third_party/ninja/ninja -d keeprsp -C "$OUT" -j "$JOBS" d8 > "$OUT/ninja-d8.log.txt" 2>&1 \
    || { tail -40 "$OUT/ninja-d8.log.txt"; die "ninja d8 failed"; }
  third_party/ninja/ninja -C "$OUT" -t commands d8 > "$OUT/d8-commands.txt"
  local link rsp
  link=$(grep -F 'd8.rsp' "$OUT/d8-commands.txt" | tail -1 || true)
  rsp=$(ls "$OUT"/d8.rsp "$OUT"/./d8.rsp 2> /dev/null | head -1 || true)
  [ -n "$link" ] && [ -s "$rsp" ] || die "no d8 link command or response file (rsp: '$rsp')"
  python3 -I - "$V8/$OUT" "$rsp" "$link" > "$OUT/d8-link-inputs.txt" <<'PYIN'
import os, shlex, sys
cwd, rsp, link = sys.argv[1], sys.argv[2], sys.argv[3]
tokens = shlex.split(open(rsp).read()) + shlex.split(link)
seen = set()
def emit(kind, value):
    if (kind, value) not in seen:
        seen.add((kind, value))
        print(kind, value)
i = 0
while i < len(tokens):
    t = tokens[i]
    if t == "-framework" and i + 1 < len(tokens):
        emit("framework", tokens[i + 1]); i += 2; continue
    if t.startswith("-Wl,-framework,"):
        emit("framework", t.split(",")[2])
    elif t.startswith("-l") and len(t) > 2:
        emit("lib", t[2:])
    elif t.endswith(".rlib"):
        emit("rlib", os.path.realpath(os.path.join(cwd, t)))
    elif t.endswith((".a", ".o")) and "/rust/" in t:
        emit("rustobj", os.path.realpath(os.path.join(cwd, t)))
    elif t.endswith((".a", ".o")):
        emit("other", t)
    i += 1
PYIN
  log "d8's link: $(grep -c '^rlib ' "$OUT/d8-link-inputs.txt") rlibs, $(grep -c '^rustobj ' "$OUT/d8-link-inputs.txt" || true) Rust objects/archives, frameworks: $(grep '^framework ' "$OUT/d8-link-inputs.txt" | cut -d' ' -f2 | tr '\n' ' '), libs: $(grep '^lib ' "$OUT/d8-link-inputs.txt" | cut -d' ' -f2 | tr '\n' ' ')"
  # (Everything else d8 links is V8 itself as objects - the monolith's content - and d8's own files.)
  log "d8's other inputs (V8's and d8's own objects): $(grep -c '^other ' "$OUT/d8-link-inputs.txt" || true)"
  # One archive of the rlibs' and shims' objects (an rlib is an ar archive: its objects plus lib.rmeta).
  local w="$OUT/rust-objs" n=0 f
  rm -rf "$w"; mkdir -p "$w"
  while read -r kind f; do
    case "$kind" in
      rlib|rustobj)
        n=$((n + 1)); mkdir -p "$w/$n"
        case "$f" in
          *.o) cp "$f" "$w/$n/" ;;
          *)
            if [ "$(head -c 7 "$f")" = '!<thin>' ]; then
              # A thin archive names its members by path, relative to the archive's directory.
              local m d; d=$(dirname "$f")
              "$LLVM/bin/llvm-ar" t "$f" | while IFS= read -r m; do
                case "$m" in /*) cp "$m" "$w/$n/" ;; *) cp "$d/$m" "$w/$n/" ;; esac
              done
            else
              ( cd "$w/$n" && "$LLVM/bin/llvm-ar" x "$f" )
            fi ;;
        esac ;;
    esac
  done < "$OUT/d8-link-inputs.txt"
  find "$w" -type f ! -name '*.o' -delete
  rm -f "$OUT/obj/librust_v8.a"
  ( cd "$w" && find . -name '*.o' | LC_ALL=C sort | xargs "$LLVM/bin/llvm-ar" rcs "$V8/$OUT/obj/librust_v8.a" )
  rm -rf "$w"
  # The system libraries and frameworks, as link flags.
  # (grep finding nothing is no failure here: Linux names no framework, macOS no -l library.)
  { { grep '^framework ' "$OUT/d8-link-inputs.txt" || true; } | while read -r _ f; do echo "-framework $f"; done
    { grep '^lib ' "$OUT/d8-link-inputs.txt" || true; } | while read -r _ f; do echo "-l$f"; done
    # Linux: the unwinder. Chromium's libc++abi and Rust's std call _Unwind_*; d8's clang++ link
    # gets libgcc_s from the clang driver itself (Linux toolchain AddRunTimeLibs: -lgcc_s, which
    # -nostdlib++ leaves in; use_custom_libunwind is off on Linux), so the response file does not
    # name it. Zig's link adds no unwinder unless it links its own libc++, which this one must not.
    [ "$HOST_OS" != linux ] || echo "-lgcc_s"; } > "$OUT/system-libs.txt"
  log "librust_v8.a: $(ls -la "$OUT/obj/librust_v8.a" | awk '{print $5}') bytes, $("$LLVM/bin/llvm-ar" t "$OUT/obj/librust_v8.a" | wc -l | tr -d ' ') objects; system libs: $(tr '\n' ' ' < "$OUT/system-libs.txt")"
  local rc=0
  "$OUT/d8" -e "print(1 + 1, Temporal.PlainDate.from('2026-11-10').add({ days: 1 }).toString())" > "$OUT/d8-smoke.txt" 2>&1 || rc=$?
  log "d8: $(cat "$OUT/d8-smoke.txt") (rc $rc)"
  [ "$rc" = 0 ] && grep -q -x '2 2026-11-11' "$OUT/d8-smoke.txt" || die "d8's smoke test failed"
}

smoke_source() {
  cat <<'CC'
// scripts/build-v8-15.7.sh smoke: the archives as Crane links them (Zig, -DV8_GN_HEADER, Chromium's
// libc++ headers and objects, no Zig libc++).
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
// Linked from a Zig main (step smoke, Zig's own linker): main renamed, with C linkage.
#ifdef CRANE_V8_SMOKE_ZIG_MAIN
extern "C" int crane_v8_smoke_main();
#define main crane_v8_smoke_main
#endif
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
  # Zig's form of GN's consumer flags: Zig puts its own -isystem directories (clang's builtins, the
  # SDK's usr/include) BEFORE any the command line adds (`zig cc -###`), so libc++'s two directories
  # given as -isystem come after the C library's and <cstdio> finds the SDK's <stdio.h> instead of
  # libc++'s ("tried including <stdio.h> but didn't find libc++'s"). As -I they are searched before
  # every -isystem directory, which is the order GN's driver gets from -isystem + -isysroot.
  local flags=()
  while IFS= read -r f; do
    if [ "$f" = -isystem ]; then flags+=(-I); else flags+=("$f"); fi
  done < "$V8/$OUT/libcxx-flags.txt"
  local rc=0
  # Compile as Crane compiles v8_wrapper.cpp (C++20, no exceptions, no RTTI), but against Chromium's
  # libc++ (the consumer flags) and with the archive's own V8/cppgc defines (v8-gn.h).
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" cc -x c++ -std=c++20 -fno-exceptions -fno-rtti "${flags[@]}" -DV8_GN_HEADER \
    -I "$inc" -c "$t/smoke.cc" -o "$t/smoke.o" > "$t/compile.txt" 2>&1 || rc=$?
  if [ "$rc" != 0 ]; then
    head -60 "$t/compile.txt" | tee "$V8/$OUT/smoke.txt"
    cp "$t/compile.txt" "$V8/$OUT/smoke-compile.txt"
    rm -rf "$t"
    die "the smoke compile (Zig's clang against Chromium's libc++ headers) failed; see $V8/$OUT/smoke-compile.txt"
  fi
  # The system libraries d8's link names (step_rust: system-libs.txt), word-split on purpose.
  local extra=()
  # shellcheck disable=SC2207
  extra=($(cat "$V8/$OUT/system-libs.txt"))
  # `zig cc` links no C++ library of its own: Chromium's (libc++_chromium.a) is the only one.
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" cc "$t/smoke.o" "$o/libv8_monolith.a" "$o/libv8_libplatform_fat.a" \
    "$o/libv8_libbase_fat.a" "$o/libc++_chromium.a" "$o/librust_v8.a" ${extra[@]+"${extra[@]}"} -o "$t/smoke" > "$t/link.txt" 2>&1 || rc=$?
  if [ "$rc" != 0 ]; then
    {
      echo "LINK FAILED (rc $rc). Undefined symbols (Rust std/temporal ones mean Crane's link must add Rust):"
      grep -i -E 'undefined' "$t/link.txt" | head -60
      echo "lines naming 'undefined': $(grep -c -i 'undefined' "$t/link.txt" || true)"
    } | tee "$V8/$OUT/smoke.txt"
    cp "$t/link.txt" "$V8/$OUT/smoke-link.txt"
    rm -rf "$t"
    die "the smoke link failed; see $V8/$OUT/smoke-link.txt"
  fi
  # ONE C++ runtime: the linked program names Chromium's std::__Cr and no other C++ library's.
  local nm="$LLVM/bin/llvm-nm" cr other
  cr=$("$nm" "$t/smoke" 2>/dev/null | grep -c 'St4__Cr' || true)
  other=$("$nm" "$t/smoke" 2>/dev/null | grep -c -E 'St3__1|_ZNSt7__cxx11|__gnu_cxx' || true)
  rc=0
  "$t/smoke" > "$V8/$OUT/smoke.txt" 2>&1 || rc=$?
  echo "smoke binary: std::__Cr symbols $cr, std::__1/libstdc++ symbols $other" >> "$V8/$OUT/smoke.txt"
  cat "$V8/$OUT/smoke.txt"
  [ "$other" = 0 ] && [ "$cr" -gt 0 ] || die "the smoke binary holds another C++ library than Chromium's"
  [ "$rc" = 0 ] || { rm -rf "$t"; die "the smoke test failed (rc $rc)"; }
  # The same program as a Debug Zig executable linked by Zig's OWN linker (-fno-lld): on x86_64 Linux the
  # one Crane's Debug builds use (the snapshot generator, the test binaries), which applies only the
  # relocations it reads (ELF RELOCATIONS: an archive with CREL linked there called address 0 before main).
  # The C++ main is renamed (CRANE_V8_SMOKE_ZIG_MAIN); a Zig main calls it.
  ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" cc -x c++ -std=c++20 -fno-exceptions -fno-rtti "${flags[@]}" -DV8_GN_HEADER \
    -DCRANE_V8_SMOKE_ZIG_MAIN -I "$inc" -c "$t/smoke.cc" -o "$t/smoke-zig.o" > "$t/compile-zig.txt" 2>&1 \
    || { cat "$t/compile-zig.txt"; rm -rf "$t"; die "the Zig-linker smoke compile failed"; }
  printf '%s\n' 'extern fn crane_v8_smoke_main() c_int;' \
    'pub fn main() u8 {' '    return @intCast(crane_v8_smoke_main());' '}' > "$t/smoke_main.zig"
  rc=0
  ( cd "$t" && ZIG_GLOBAL_CACHE_DIR="$t/gc" "$ZIG" build-exe smoke_main.zig smoke-zig.o "$o/libv8_monolith.a" \
      "$o/libv8_libplatform_fat.a" "$o/libv8_libbase_fat.a" "$o/libc++_chromium.a" "$o/librust_v8.a" \
      ${extra[@]+"${extra[@]}"} -lc -O Debug -fno-lld --name smoke-zig ) > "$t/link-zig.txt" 2>&1 || rc=$?
  [ "$rc" = 0 ] || { head -40 "$t/link-zig.txt"; rm -rf "$t"; die "the Zig-linker smoke link failed (rc $rc)"; }
  rc=0
  "$t/smoke-zig" > "$V8/$OUT/smoke-zig.txt" 2>&1 || rc=$?
  echo "linked by Zig's own linker (-fno-lld, Debug): rc $rc" >> "$V8/$OUT/smoke-zig.txt"
  cat "$V8/$OUT/smoke-zig.txt"
  cat "$V8/$OUT/smoke-zig.txt" >> "$V8/$OUT/smoke.txt"
  rm -rf "$t"
  [ "$rc" = 0 ] || die "the smoke program linked by Zig's own linker did not run (rc $rc; a signal before main means relocations it did not apply: ELF RELOCATIONS)"
  log "smoke: passed (zig cc, and Zig's own linker)"
}

step_install() {
  check_stop install
  # Built beside the installed one, checked, then swapped in: a pinned artifact is never rewritten in place.
  local FINAL="$DEST" DEST="$DEST.new"
  rm -rf "$DEST"
  mkdir -p "$DEST/out/static/obj" "$DEST/libcxx"
  cd "$V8"
  cp $(for a in $(archives); do echo "$OUT/obj/$a"; done) "$DEST/out/static/obj/"
  cp -R include "$DEST/include"
  cp "$OUT/gen/include/v8-gn.h" "$DEST/include/v8-gn.h"
  # Chromium's libc++ for consumers: its headers and the flags, rewritten to the installed copies.
  cp -R third_party/libc++/src/include "$DEST/libcxx/include"
  cp -R third_party/libc++abi/src/include "$DEST/libcxx/abi-include"
  mkdir -p "$DEST/libcxx/config"
  cp buildtools/third_party/libc++/__config_site buildtools/third_party/libc++/__assertion_handler "$DEST/libcxx/config/"
  sed -e "s#^$V8/third_party/libc++/src/include\$#$DEST/libcxx/include#" \
      -e "s#^$V8/third_party/libc++abi/src/include\$#$DEST/libcxx/abi-include#" \
      -e "s#^$V8/buildtools/third_party/libc++\$#$DEST/libcxx/config#" \
      "$OUT/libcxx-flags.txt" > "$DEST/libcxx/flags.txt"
  ! grep -q "$V8_ROOT" "$DEST/libcxx/flags.txt" || die "libcxx/flags.txt still names the checkout"
  cp "$OUT/args.gn" "$DEST/args.gn"
  tail -40 "$OUT/ninja.log.txt" > "$DEST/ninja-tail.txt"
  cp "$OUT/rust.txt" "$OUT/smoke.txt" "$OUT/system-libs.txt" "$OUT/d8-link-inputs.txt" "$OUT/d8-smoke.txt" "$DEST/"
  {
    echo "V8 $V8_TAG ($(git rev-parse HEAD)) for $HOST_OS $TARGET_CPU, built $(date -u +%FT%TZ) on $(hostname) by scripts/build-v8-15.7.sh"
    echo "clang: $("$LLVM/bin/clang" --version | head -1)"
    echo "rustc: $("$V8/third_party/rust-toolchain/bin/rustc" --version)"
    echo "libc++: Chromium's (third_party/libc++ at this tag's DEPS, std::__Cr, hardened); libc++_chromium.a"
    [ "$HOST_OS" != mac ] || echo "SDK: macOS $(xcrun --sdk macosx --show-sdk-version)"
    if [ "$HOST_OS" = linux ]; then
      echo "relocations: RELA - every compile ran with CCC_OVERRIDE_OPTIONS='$CCC_OVERRIDE_OPTIONS', deleting the"
      echo "  -Wa,--crel,--allow-experimental-crel Chromium adds for Linux+lld (build/config/compiler/BUILD.gn:673-679):"
      echo "  Zig 0.17's self-hosted ELF linker does not apply SHT_CREL relocations (scripts/build-v8-15.7.sh ELF RELOCATIONS)"
    fi
    [ -z "${PROVENANCE_NOTE:-}" ] || echo "$PROVENANCE_NOTE"
    [ ! -e "$FINAL/PROVENANCE" ] || echo "replaces: $(head -1 "$FINAL/PROVENANCE") (its SHA256SUMS kept beside: $(basename "$FINAL").SHA256SUMS.replaced-<UTC>)"
  } > "$DEST/PROVENANCE"
  ( cd "$DEST" && find . -type f ! -name SHA256SUMS | LC_ALL=C sort | xargs $SHA256 > SHA256SUMS && $SHA256 -c SHA256SUMS > /dev/null ) \
    || die "the new install's SHA256SUMS does not check"
  if [ -e "$FINAL" ]; then
    local kept
    kept="$FINAL.SHA256SUMS.replaced-$(date -u +%Y%m%dT%H%M%SZ)"
    [ ! -s "$FINAL/SHA256SUMS" ] || cp -p "$FINAL/SHA256SUMS" "$kept"
    log "install: replacing $FINAL (its SHA256SUMS kept as $kept)"
    rm -rf "$FINAL"
  fi
  mv "$DEST" "$FINAL"
  DEST=$FINAL
  log "installed to $DEST ($(du -sh "$DEST" | cut -f1)); SHA256SUMS sha256 $($SHA256 "$DEST/SHA256SUMS" | cut -c1-64); archives: $(cd "$DEST/out/static/obj" && ls -la $(archives) | awk '{printf "%s %s; ", $NF, $5}')"
}

step_clean() {
  check_stop clean
  [ -s "$DEST/SHA256SUMS" ] || die "not installed yet; refusing to delete the build directory"
  log "clean: $V8/$OUT ($(du -sh "$V8/$OUT" | cut -f1)); the checkout stays ($(du -sh "$V8_ROOT" | cut -f1) before)"
  rm -rf "${V8:?}/${OUT:?}"
  log "clean: checkout now $(du -sh "$V8_ROOT" | cut -f1); free $(df -Ph "$V8_ROOT" | awk 'NR == 2 {print $4}')"
}

[ "$#" -gt 0 ] || { sed -n '2,30p' "$0"; exit 2; }
mkdir -p "$V8_ROOT"
echo "$$ $0 $*" > "$PIDFILE"
for step in "$@"; do
  case "$step" in
    all) for s in deps checkout build rust verify smoke install; do "step_$s"; done ;;
    deps|checkout|build|verify|rust|smoke|install|clean) "step_$step" ;;
    *) die "unknown step: $step" ;;
  esac
done
rm -f "$PIDFILE"
log "done: $*"
