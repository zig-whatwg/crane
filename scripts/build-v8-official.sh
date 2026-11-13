#!/bin/bash
# Build V8 13.1.203 - the V8 Crane links (jsengines/v8/include/v8-version.h) - the way Chrome's
# official build compiles it: ThinLTO and clang PGO with Chrome's own mac-arm64 profile, plus V8's
# builtins PGO. Output: jsengines/v8/out/official, linked with `zig build ... -Dv8-build=official`
# (src/runtime/engines/v8/build/archives.zig). The default build (out/static) is untouched. The output exists on
# chat.local only (the integrator, 2026-11-04): a build with -Dv8-build=official runs there.
#
# Measured 2026-11-04 (lane v8opt1, the same Crane tree, the default runner): WPT identical over
# 4,011 files; gc_bench DOM -1.7% CPU (noise), gc_bench JS loop +3.2% CPU (slower), a wasm/ +
# streams/ WPT subset -0.2% CPU; max RSS +8 to +10 MB. The user kept static as the default
# (2026-11-04); official stays opt-in. Training Crane's own PGO profile is roadmap item v8-pgo.
#
#   scripts/build-v8-official.sh <step>... (in this order the first time)
#     checkout  V8 13.1.203 in a gclient root of its own ($V8_ROOT, default ~/v8-13.1.203), at that
#               tag's DEPS (its clang, gn, ninja) - never the checkouts beside it, which are other
#               versions (14.6 on the Mac, 15.7 on chat.local)
#     control   out/control: the prebuilt out/static's GN arguments (below), no LTO, no PGO - the
#               baseline the official build is measured against, so that only LTO and PGO differ.
#               It reproduces out/static byte for byte (2026-11-04: equal SHA-256s for all three
#               archives), so out/static is that baseline and needs no install
#     profile   Chrome 131's mac-arm64 PGO profile (V8 13.1 shipped in Chrome 131), its names
#               rewritten for a standalone V8 checkout, indexed by this clang's llvm-profdata
#     official  out/official: the control's arguments + is_official_build (Chrome's ThinLTO and
#               PGO flags) + V8's builtins PGO, compiled to bitcode; then Chrome's own link-time
#               ThinLTO step over V8's objects (ld64.lld, -object_path_lto) turns them into native
#               arm64 Mach-O objects, archived as out/official/obj/*.a
#     verify    every member of every archive is arm64 Mach-O, no symbol of the control is missing,
#               cross-module inlining happened
#     pgomatch  the share of the functions compiled that Chrome's profile matched
#     install   copy an output's three archives to $CRANE_V8/out/<name>/obj with args.gn,
#               provenance and SHA256SUMS (name: control or official)
#
# Why the ThinLTO step is here and not in Crane's link: ThinLTO objects are LLVM bitcode, and Zig's
# Mach-O linker reads none (Zig 0.17.1-dev+77c319a0f0: a bitcode object fails with "failed to parse
# TBD file", the same object in an archive with "unknown cpu architecture: 0"). Chrome links V8
# with ld64.lld, whose ThinLTO backends run inside the link; this script runs that same link over
# V8's objects alone and keeps the native objects the backends write (-object_path_lto, as Chrome's
# mac link passes it for dsymutil: build/config/compiler/BUILD.gn, `-Wcrl,object_path_lto`).
# Embedders that link a static V8 with a linker of their own build it without LTO (rusty_v8's .gn
# default_args set no is_official_build, use_thin_lto or chrome_pgo_phase; Deno's `lto = true` is
# Rust's, over prebuilt native V8 archives); Node runs LTO and PGO itself (configure --enable-lto,
# --enable-pgo-generate/--enable-pgo-use) because it compiles V8 and links it with one toolchain.
#
# Two things Chrome's link may assume and Crane's may not:
# - Every V8 symbol stays defined and external: Crane's v8_wrapper.cpp, compiled and linked later by
#   Zig, calls V8's API, but an LTO link keeps only what it sees used or exported, and a symbol
#   with hidden visibility is never exported. Each external symbol of the bitcode (72,206 at
#   13.1.203) is named with -u, which ld64.lld treats as a reference from a regular object
#   (lld/MachO/SymbolTable.cpp: isUsedInRegularObj |= !file), so ThinLTO neither internalizes nor
#   drops it.
# - No whole-program devirtualization: with use_thin_lto Chrome compiles -fwhole-program-vtables,
#   which puts llvm.type.test at virtual call sites and lets the LTO link bind a call through a
#   class of hidden LTO visibility to the only subclass the link sees. Crane subclasses
#   v8::Platform, v8::TaskRunner, v8::Task, the serializer delegates and V8InspectorClient outside
#   that link. V8's monolith compiles -fvisibility=default, so its classes are public to LTO
#   anyway; scripts/v8-official-cc.sh (GN's cc_wrapper) appends -fno-whole-program-vtables to every
#   compile so that soundness does not rest on that (0 llvm.type.test in api.o). V8's sources are
#   not patched.
# - OFFICIAL_BUILD is defined, as in Chrome: a failed V8 CHECK is an immediate trap with no message
#   or stack trace (control: "Check failed: ..." and a C stack trace), and unwind tables are left
#   out (-fno-unwind-tables; arm64 keeps frame pointers).
#
# Environment: V8_ROOT (gclient root), CRANE_V8 (install target, default
# ~/projects/crane/jsengines/v8), JOBS (ninja -j and --thinlto-jobs, default 6), STOP (a file
# whose existence stops the script between steps and chunks), DEVELOPER_DIR (an Xcode, default
# /Applications/Xcode.app: Chromium's build/ asks xcodebuild for the SDK, which the Command Line
# Tools cannot answer; Xcode 26.2's SDK 26.2 is the one out/static's objects name).
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

here="$(cd "$(dirname "$0")" && pwd)"
V8_TAG=13.1.203
V8_COMMIT=e85c59cee0e2714a720fa759384c19023f8fa8a3 # refs/tags/13.1.203, "Version 13.1.203", 2024-10-14
V8_ROOT="${V8_ROOT:-$HOME/v8-$V8_TAG}"
V8="$V8_ROOT/v8"
CRANE_V8="${CRANE_V8:-$HOME/projects/crane/jsengines/v8}"
JOBS="${JOBS:-6}"
STOP="${STOP:-$HOME/crane-work/v8opt1-bins/STOP}"
LLVM="$V8/third_party/llvm-build/Release+Asserts/bin"
# Chrome 131 (branch 6778) shipped V8 13.1; this is the branch's first mac-arm64 profile
# (chrome/build/mac-arm.pgo.txt, 2024-10-15), the one closest to 13.1.203 (main, 2024-10-14).
PGO_PROFILE="${PGO_PROFILE:-chrome-mac-arm-6778-1729014018-5b68540d1c3d4011ed2068853f64570bee4e4f55-2a946adfe3db0e6d092d7db7b84fb08aec62917a.profdata}"
PGO_URL="https://storage.googleapis.com/chromium-optimization-profiles/pgo_profiles/$PGO_PROFILE"

# 13.1.203's DEPS put a Linux x86-64 llvm-nm in the Mac package (beside arm64 clang, lld,
# llvm-ar and llvm-profdata); Xcode's llvm-nm reads this clang's bitcode.
NM="$LLVM/llvm-nm"
"$NM" --version > /dev/null 2>&1 || NM="$(xcrun -f llvm-nm)"

log() { echo "[build-v8-official $(date -u +%H:%M:%SZ)] $*"; }
die() { echo "build-v8-official: $*" >&2; exit 1; }
check_stop() { [ ! -e "$STOP" ] || die "STOP file $STOP exists; stopping before: $*"; }

# A long child runs in the background so a TERM reaches it (bash runs traps only between
# foreground commands); the trap kills it, and ninja stops the compiles it started.
child=""
on_term() { [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || true; die "terminated"; }
trap on_term TERM INT
run_long() {
  "$@" &
  child=$!
  local rc=0
  wait "$child" || rc=$?
  child=""
  return $rc
}

# The arguments the prebuilt out/static (13.1.203, built 2026-01-15) was built with: the V8 13.1.x
# recipe in build.zig's setup step (commit 829d1ab0128, 2025-12-23) - the same list as
# scripts/build-v8-static.sh's except four arguments that do nothing at 13.1.203
# (v8_function_arguments_caller_are_own_props and v8_enable_temporal_support do not exist there;
# use_custom_libcxx_for_host and is_clang = true are the defaults; use_xcode_clang was removed
# from Chromium's build/ in 2021). The prebuilt bears them out: libc++ is the system's (18,151
# std::__1 symbols, no std::__Cr), no Intl, no heap verifier, no debug info, minos 11.0.
control_args() {
  cat <<'ARGS'
# V8 13.1.203 for Crane: the prebuilt out/static's arguments (scripts/build-v8-official.sh).
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
target_cpu = "arm64"
ARGS
}

# What Chrome's official mac-arm64 build adds (build/ at 13.1.203's DEPS, 61966507f3):
# - is_official_build = true. In build/config/compiler: use_thin_lto (-flto=thin
#   -fsplit-lto-unit -fwhole-program-vtables, -inlinehint-threshold=360, and at the link
#   --lto-O2 for the browser binary [thinlto_optimize_max], -import-instr-limit=30),
#   chrome_pgo_phase = 2 on mac (pgo.gni), exclude_unwind_tables (-fno-unwind-tables
#   -fno-asynchronous-unwind-tables). In V8's BUILD.gn: v8_wasm_random_fuzzers off.
# - chrome_pgo_phase = 2 with pgo_data_path: -fprofile-use=<profile>, and at a ThinLTO link
#   -enable-ext-tsp-block-placement=1 (pgo/BUILD.gn). A standalone V8 has no
#   //tools/update_pgo_profiles.py, so the path is given.
# - v8_enable_builtins_optimization = true: Chrome's default when chrome_pgo_phase == 2
#   (gni/v8.gni, build_with_chromium && chrome_pgo_phase == 2). mksnapshot then reads
#   tools/builtins-pgo/profiles/x64.profile (for arm64 too: "x64 profile can be applied to
#   arm64") with --turbo-profiling-input, --abort-on-bad-builtin-profile-data and
#   --reorder-builtins. The profile is 13.1.203.0's (gs://chromium-v8-builtins-pgo/by-version/),
#   fetched by the checkout_v8_builtins_pgo_profiles hook.
official_args() {
  control_args
  cat <<ARGS
# + Chrome's official build (ThinLTO, PGO) and V8's builtins PGO.
is_official_build = true
chrome_pgo_phase = 2
pgo_data_path = "$V8_ROOT/pgo/v8-standalone.profdata"
v8_enable_builtins_optimization = true
ARGS
  # The builtins profile less the builtins whose graphs differ in this configuration (see
  # builtins_profile); until it exists, V8's default (x64.profile), to build mksnapshot.
  [ ! -s "$V8_ROOT/pgo/builtins-x64.profile" ] || echo "v8_builtins_profiling_log_file = \"$V8_ROOT/pgo/builtins-x64.profile\""
  cat <<ARGS
# -fno-whole-program-vtables after GN's flags: see scripts/build-v8-official.sh.
cc_wrapper = "$V8_ROOT/v8-official-cc.sh"
ARGS
}

# Chrome's link-time ThinLTO options for the browser binary (build/config/compiler/BUILD.gn and
# pgo/BUILD.gn at 61966507f3): thinlto_optimize_max's --lto-O2 (thin_lto_enable_optimizations is
# on for official mac), import_instr_limit 30, inlinehint-threshold 360, the PGO build's ext-tsp
# block placement, and no debug-info upgrade.
LTO_LINK_FLAGS=(--lto-O2 -mllvm -import-instr-limit=30 -mllvm -inlinehint-threshold=360
  -mllvm -enable-ext-tsp-block-placement=1 -mllvm -disable-auto-upgrade-debug-info)

gn_bin() { echo "$V8/buildtools/mac/gn"; }
ninja_bin() { echo "$V8/third_party/ninja/ninja"; }

step_checkout() {
  check_stop checkout
  mkdir -p "$V8_ROOT"
  cd "$V8_ROOT"
  if [ ! -d depot_tools ]; then
    log "depot_tools (shallow)"
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
  fi
  export PATH="$V8_ROOT/depot_tools:$PATH" DEPOT_TOOLS_UPDATE=0
  cat > .gclient <<'GCLIENT'
solutions = [
  {
    "name": "v8",
    "url": "https://chromium.googlesource.com/v8/v8.git",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {
      # llvm-profdata (Chrome's profile -> this clang's profile format).
      "checkout_clang_coverage_tools": True,
      # tools/builtins-pgo/profiles for 13.1.203.0 (v8_enable_builtins_optimization).
      "checkout_v8_builtins_pgo_profiles": True,
    },
  },
]
GCLIENT
  if [ ! -d v8/.git ]; then
    log "V8 $V8_TAG (one commit, no history)"
    git init -q v8
    git -C v8 remote add origin https://chromium.googlesource.com/v8/v8.git
    git -C v8 fetch -q --depth 1 origin "refs/tags/$V8_TAG:refs/tags/$V8_TAG"
    git -C v8 checkout -q "refs/tags/$V8_TAG"
  fi
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "v8 is not at $V8_TAG ($V8_COMMIT)"
  if [ -x "$LLVM/clang" ] && [ -x "$(gn_bin)" ] && [ -x "$(ninja_bin)" ]; then
    log "DEPS already synced (clang, gn, ninja present)"
  else
    # --nohooks: 13.1.203's vpython3_common hook asks for numpy 1.21.1 wheels for Python 3.8,
    # which Chromium's package index no longer serves, and the build needs none of it. The two
    # hooks the build needs run below.
    log "gclient sync at $V8_COMMIT, no hooks (DEPS: build, buildtools, clang, gn, ninja)"
    run_long gclient sync --nohooks --no-history --shallow -D --revision "v8@$V8_COMMIT" --jobs 4
  fi
  [ "$(git -C v8 rev-parse HEAD)" = "$V8_COMMIT" ] || die "gclient moved v8 off $V8_TAG"
  (cd v8 && python3 build/util/lastchange.py -o build/util/LASTCHANGE)
  # The checkout_v8_builtins_pgo_profiles hook (tools/builtins-pgo/download_profiles.py), by
  # plain HTTPS: the profiles of version 13.1.203.0 from the public bucket.
  local pd=v8/tools/builtins-pgo/profiles u=https://storage.googleapis.com/chromium-v8-builtins-pgo/by-version/13.1.203.0 f
  for f in meta.json x64.profile x64-rl.profile x86.profile x86-rl.profile; do
    [ -s "$pd/$f" ] || curl -fsS -o "$pd/$f" "$u/$f"
  done
  grep -q '"revision": "'"$V8_COMMIT"'"' "$pd/meta.json" || die "builtins PGO profiles are not 13.1.203's"
  grep -q 'V8_BUILD_NUMBER 203' v8/include/v8-version.h || die "include/v8-version.h is not 13.1.203"
  log "toolchain: $("$LLVM/clang" --version | sed -n 1p)"
  ls "$LLVM"
  ls -la v8/tools/builtins-pgo/profiles/ || true
  diff -rq v8/include "$CRANE_V8/include" && log "include/ is identical to $CRANE_V8/include"
}

# gn gen + ninja for one output directory, then GN's thin archives -> regular ("fat") archives.
gen_and_build() {
  local name=$1 out="$V8/out/$1"
  mkdir -p "$out"
  if [ "$name" = control ]; then control_args > "$out/args.gn"; else official_args > "$out/args.gn"; fi
  cd "$V8"
  log "gn gen out/$name"
  "$(gn_bin)" gen "out/$name"
  check_stop "ninja out/$name"
  log "ninja -C out/$name -j $JOBS (log: out/$name/ninja.log.txt)"
  run_long "$(ninja_bin)" -C "out/$name" -j "$JOBS" v8_monolith v8_libplatform v8_libbase > "$out/ninja.log.txt" 2>&1 \
    || { tail -40 "$out/ninja.log.txt"; die "ninja failed for out/$name"; }
  tail -2 "$out/ninja.log.txt"
}

fat_archives() {
  local out=$1
  cd "$out"
  for lib in libplatform libbase; do
    rm -f "obj/libv8_${lib}_fat.a"
    "$LLVM/llvm-ar" t "obj/libv8_${lib}.a" > "obj/libv8_${lib}.members"
    # shellcheck disable=SC2046
    "$LLVM/llvm-ar" rcs "obj/libv8_${lib}_fat.a" $(cat "obj/libv8_${lib}.members")
  done
}

step_control() {
  check_stop control
  gen_and_build control
  # GN writes the monolith as a regular archive (complete_static_lib) already.
  fat_archives "$V8/out/control"
  log "out/control: $(ls -la "$V8/out/control/obj/"libv8_monolith.a "$V8/out/control/obj/"*_fat.a | awk '{print $5, $NF}' | tr '\n' ' ')"
}

step_profile() {
  check_stop profile
  local d="$V8_ROOT/pgo"
  mkdir -p "$d"
  cd "$d"
  [ -f "$PGO_PROFILE" ] || { log "fetching $PGO_URL"; curl -fsS -o "$PGO_PROFILE.part" "$PGO_URL"; mv "$PGO_PROFILE.part" "$PGO_PROFILE"; }
  shasum -a 256 "$PGO_PROFILE" | tee chrome-profile.sha256
  [ -x "$LLVM/llvm-profdata" ] || die "no llvm-profdata in $LLVM (checkout_clang_coverage_tools)"
  "$LLVM/llvm-profdata" show "$PGO_PROFILE" | tee chrome-profile.show.txt
  # Chrome compiles V8 at ../../v8/ (its gen files at gen/v8/) against Chromium's libc++
  # (inline namespace std::__Cr); a standalone V8 at ../../ against the system libc++ (std::__1).
  # A local function's profile name is "<source path>;<name>" and every mangled name carries the
  # namespace, so both are rewritten or those functions never match.
  log "profile -> text -> names rewritten for a standalone V8 -> indexed"
  "$LLVM/llvm-profdata" merge --text "$PGO_PROFILE" -o chrome.proftext
  LC_ALL=C sed -e 's#^\.\./\.\./v8/#../../#' -e 's#^gen/v8/#gen/#' -e 's#St4__Cr#St3__1#g' \
    chrome.proftext > v8-standalone.proftext
  "$LLVM/llvm-profdata" merge -o v8-standalone.profdata v8-standalone.proftext
  # The name of each record (the line before "# Func Hash:"), for pgomatch.
  awk '/^# Func Hash:/ {print prev} {prev = $0}' v8-standalone.proftext | LC_ALL=C sort -u > v8-standalone.names
  "$LLVM/llvm-profdata" show v8-standalone.profdata | tee v8-standalone.show.txt
  printf 'chrome profile: %s\nsha256: %s\nrewrites: ^../../v8/ -> ../../ ; ^gen/v8/ -> gen/ ; St4__Cr -> St3__1\n' \
    "$PGO_URL" "$(cut -d' ' -f1 chrome-profile.sha256)" > provenance.txt
  rm -f chrome.proftext v8-standalone.proftext
}

step_official() {
  check_stop official
  [ -f "$V8_ROOT/pgo/v8-standalone.profdata" ] || die "run the profile step first"
  # pgo/BUILD.gn makes //chrome/build/mac-arm.pgo.txt - in Chromium, the name of the profile
  # tools/update_pgo_profiles.py fetched - an input of every compile. A standalone V8 has no
  # chrome/, so ninja would stop on a missing input: write it, with the profile's name in it, as
  # Chromium's is. It is a new file of Chromium's tree, not a change to V8's sources.
  # Written only when it differs: every compile depends on it, so a fresh mtime recompiles V8.
  mkdir -p "$V8/chrome/build"
  [ "$(cat "$V8/chrome/build/mac-arm.pgo.txt" 2>/dev/null)" = "$PGO_PROFILE" ] \
    || echo "$PGO_PROFILE" > "$V8/chrome/build/mac-arm.pgo.txt"
  # The cc_wrapper lives beside the checkout, so out/official rebuilds without this script's copy.
  cp "$here/v8-official-cc.sh" "$V8_ROOT/v8-official-cc.sh"
  chmod +x "$V8_ROOT/v8-official-cc.sh"
  builtins_profile
  gen_and_build official
  lto_native "$V8/out/official"
}

# V8's builtins PGO profile for 13.1.203.0 (x64.profile, which V8 applies to arm64) was recorded
# in Chrome's configuration, where V8_INTL_SUPPORT is on and with it static roots (BUILD.gn:
# v8_enable_static_roots needs v8_enable_i18n_support). Crane's V8 has neither, so the CSA graphs
# of the builtins that compare against a root differ, and mksnapshot's
# --abort-on-bad-builtin-profile-data stops on the first ("Rejected profile data for CallProxy
# due to function change"). As BUILD.gn says, the full list comes from running mksnapshot with
# --warn-about-builtin-profile-data instead. The profile less those builtins - and less the three
# Intl builtins this build does not have (StringFastLocaleCompare, StringPrototypeToLowerCaseIntl,
# StringToLowerCaseIntl), whose names BuiltinsSorter would map to builtin 0 - becomes
# v8_builtins_profiling_log_file (a GN argument). Every builtin whose graph is Chrome's keeps
# Chrome's profile, the rest are compiled without one, and with every remaining hash matched
# mksnapshot also reorders the builtins (--reorder-builtins, which embedded-data.cc skips unless
# all_hash_matched()), as Chrome's official build does.
builtins_profile() {
  local out="$V8/out/official" d="$V8_ROOT/pgo" w cmd
  [ ! -s "$d/builtins-x64.profile" ] && [ -s "$V8/tools/builtins-pgo/profiles/x64.profile" ] || return 0
  w="$d/mksnapshot-warn"
  rm -rf "$w"
  mkdir -p "$out" "$w"
  official_args > "$out/args.gn"
  cd "$V8"
  "$(gn_bin)" gen out/official
  log "ninja -C out/official mksnapshot (to list the builtins whose graphs differ from the profile's)"
  run_long "$(ninja_bin)" -C out/official -j "$JOBS" mksnapshot > "$w/ninja.log.txt" 2>&1 \
    || { tail -20 "$w/ninja.log.txt"; die "mksnapshot did not build"; }
  cd "$out"
  cmd=$("$(ninja_bin)" -t commands obj/libv8_monolith.a | grep -m1 -- '--turbo-profiling-input')
  [ -n "$cmd" ] || die "no mksnapshot command with --turbo-profiling-input"
  cmd=$(echo "$cmd" | sed -e 's#--abort-on-bad-builtin-profile-data#--warn-about-builtin-profile-data#' \
    -e "s#gen/embedded.S#$w/embedded.S#" -e "s#gen/snapshot.cc#$w/snapshot.cc#")
  echo "$cmd" > "$w/cmd.txt"
  eval "$cmd" > "$w/out.txt" 2>&1 || { tail -20 "$w/out.txt"; die "mksnapshot --warn-about-builtin-profile-data failed"; }
  sed -n 's/^Rejected profile data for \([^ ]*\) due to function change.*/\1/p' "$w/out.txt" | LC_ALL=C sort -u > "$d/builtins-rejected.txt"
  # This build's builtins: the labels of the embedded blob mksnapshot just wrote.
  grep -o '^_Builtins_[A-Za-z0-9_]*:' "$w/embedded.S" | sed -e 's/^_Builtins_//' -e 's/:$//' | LC_ALL=C sort -u > "$d/builtins-in-build.txt"
  [ -s "$d/builtins-in-build.txt" ] || die "no builtin labels in $w/embedded.S"
  cut -d, -f2 "$V8/tools/builtins-pgo/profiles/x64.profile" | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$d/builtins-in-build.txt" > "$d/builtins-absent.txt"
  awk -F, 'FILENAME == ARGV[1] {ok[$1] = 1; next} FILENAME == ARGV[2] {bad[$1] = 1; next} ($2 in ok) && !($2 in bad)' \
    "$d/builtins-in-build.txt" "$d/builtins-rejected.txt" "$V8/tools/builtins-pgo/profiles/x64.profile" > "$d/builtins-x64.profile"
  log "builtins PGO: $(grep -c '^builtin_hash,' "$V8/tools/builtins-pgo/profiles/x64.profile") builtins profiled, $(wc -l < "$d/builtins-rejected.txt" | tr -d ' ') rejected (graph differs here), $(wc -l < "$d/builtins-absent.txt" | tr -d ' ') absent here ($(tr '\n' ' ' < "$d/builtins-absent.txt")), $(grep -c '^builtin_hash,' "$d/builtins-x64.profile") kept"
}

# out/official/obj/*.a hold bitcode (and a few native objects: assembly, the embedded blob).
# Link them all with ld64.lld as Chrome's link would, keep the native objects its ThinLTO
# backends write, and archive those.
lto_native() {
  local out=$1 w="$1/lto"
  check_stop "thinlto link"
  rm -rf "$w"
  mkdir -p "$w"
  cd "$out"
  # The monolith is a complete archive in which 19 basenames repeat (factory.o, heap.o, ...), so
  # its objects are read from the ninja edge that archived them, thin archives expanded.
  archived_objects obj/libv8_monolith.a > "$w/monolith.members"
  ! grep -q '^!not-thin ' "$w/monolith.members" || die "the monolith archives a regular archive: $(grep '^!not-thin ' "$w/monolith.members" | sed -n 1,3p)"
  [ -s "$w/monolith.members" ] || die "ninja -t query named no objects for obj/libv8_monolith.a"
  for lib in libplatform libbase; do "$LLVM/llvm-ar" t "obj/libv8_${lib}.a" > "$w/$lib.members"; done
  [ "$(LC_ALL=C sort "$w/monolith.members" | uniq -d | wc -l)" -eq 0 ] || die "an object is archived twice"
  # Every libbase/libplatform member is in the monolith (one object, one set of symbols).
  for lib in libplatform libbase; do
    if [ -n "$(sort "$w/$lib.members" | comm -23 - <(sort "$w/monolith.members"))" ]; then
      die "a $lib member is not in the monolith"
    fi
  done
  : > "$w/bitcode.members"
  : > "$w/native.members"
  while IFS= read -r m; do
    case "$(head -c 4 "$m" | od -An -tx1 | tr -d ' \n')" in
      dec0170b | 4243c0de) echo "$m" >> "$w/bitcode.members" ;;
      cffaedfe) echo "$m" >> "$w/native.members" ;;
      *) die "$m is neither LLVM bitcode nor arm64 Mach-O" ;;
    esac
  done < "$w/monolith.members"
  log "monolith: $(wc -l < "$w/bitcode.members") bitcode, $(wc -l < "$w/native.members") native members"
  # Every external symbol the V8 objects define stays defined and external (see the header).
  # shellcheck disable=SC2046
  # (With several inputs llvm-nm also prints a blank line and an "<object>:" header per object.)
  "$NM" --extern-only --defined-only --format=just-symbols $(cat "$w/bitcode.members") 2> "$w/nm.stderr" \
    | grep -v ':$' | grep . | LC_ALL=C sort -u > "$w/external.symbols"
  sed 's/^/-u /' "$w/external.symbols" > "$w/undefined.rsp"
  log "$(wc -l < "$w/external.symbols") external symbols kept"
  local sdk sdkv
  sdk="$(xcrun --sdk macosx --show-sdk-path)"
  sdkv="$(xcrun --sdk macosx --show-sdk-version)"
  # The order of the inputs is the order of ThinLTO's tasks: native object i (1-based) of
  # -object_path_lto is bitcode member i; 0 is the (empty) regular-LTO partition.
  check_stop "ld64.lld"
  log "ld64.lld ThinLTO over $(wc -l < "$w/bitcode.members") modules, --thinlto-jobs=$JOBS"
  run_long "$LLVM/ld64.lld" -arch arm64 -platform_version macos 11.0 "$sdkv" -syslibroot "$sdk" \
    -dylib -undefined dynamic_lookup -o "$w/lto-link.dylib" \
    "${LTO_LINK_FLAGS[@]}" --thinlto-jobs="$JOBS" -object_path_lto "$w/objs" \
    @"$w/undefined.rsp" $(cat "$w/bitcode.members" "$w/native.members") -lc++ -lSystem \
    > "$w/ld64.lld.log" 2>&1 || { tail -40 "$w/ld64.lld.log"; die "the ThinLTO link failed"; }
  rm -f "$w/lto-link.dylib"
  log "ThinLTO link done: $(ls "$w/objs" | wc -l | tr -d ' ') objects"
  # Name each native object after the bitcode member it was compiled from, found by symbol: an
  # external symbol exactly one module defines is defined by that module's backend object and no
  # other (ThinLTO imports as available_externally, which emits nothing, and renames what it
  # promotes to ".llvm.<hash>"). Not by position: task 0 is the regular-LTO partition - the
  # split-LTO-unit parts (vtables and what they reference) of every module - and a module that
  # is all regular-LTO has no ThinLTO task of its own.
  "$NM" --extern-only --defined-only --print-file-name --format=posix $(cat "$w/bitcode.members") 2>/dev/null \
    | awk '{f = $1; sub(/:$/, "", f); print $2, f}' | LC_ALL=C sort -u \
    | awk '{n[$1]++; m[$1] = $2} END {for (s in n) if (n[s] == 1) print s, m[s]}' > "$w/unique.map"
  "$NM" --extern-only --defined-only --print-file-name --format=posix "$w"/objs/*.arm64.lto.o 2>/dev/null \
    | awk '{f = $1; sub(/:$/, "", f); print f, $2}' > "$w/objs.symbols"
  # object -> the modules its uniquely defined symbols name (one, or the pairing is wrong)
  awk 'NR == FNR {mod[$1] = $2; next} ($2 in mod) {k = $1 SUBSEP mod[$2]; if (!(k in seen)) {seen[k] = 1; print $1, mod[$2]}}' \
    "$w/unique.map" "$w/objs.symbols" > "$w/obj.modules"
  local dup
  dup=$(awk '$1 !~ /\/0\.arm64\.lto\.o$/ {c[$1]++} END {for (o in c) if (c[o] > 1) print o}' "$w/obj.modules")
  [ -z "$dup" ] || die "objects whose symbols name more than one module: $(echo "$dup" | sed -n 1,3p | tr '\n' ' ')"
  mkdir -p "$w/stage"
  : > "$w/pairs"
  local o m base
  for o in "$w"/objs/*.arm64.lto.o; do
    if [ "$(basename "$o")" = 0.arm64.lto.o ]; then
      base=lto-regular-partition.o
      m=REGULAR
    else
      m=$(awk -v o="$o" '$1 == o {print $2}' "$w/obj.modules")
      if [ -n "$m" ]; then
        base="$(echo "$m" | sed -e 's#^obj/##' -e 's#/#__#g')"
      else
        m="UNPAIRED-$(basename "$o")"
        base="lto-$(basename "$o" .arm64.lto.o).o"
      fi
    fi
    mv "$o" "$w/stage/$base"
    echo "$m $base" >> "$w/pairs"
  done
  log "ThinLTO wrote $(grep -vc '^REGULAR \|^UNPAIRED-' "$w/pairs") objects named after their modules, $(grep -c '^UNPAIRED-' "$w/pairs") with no uniquely defined symbol, and the regular-LTO partition ($(wc -c < "$w/stage/lto-regular-partition.o" | tr -d ' ') bytes), for $(wc -l < "$w/bitcode.members" | tr -d ' ') bitcode modules"
  [ "$(cut -d' ' -f1 "$w/pairs" | LC_ALL=C sort | uniq -d | wc -l)" -eq 0 ] || die "two objects claim one module"
  while IFS= read -r m; do
    base="$(echo "$m" | sed -e 's#^obj/##' -e 's#/#__#g')"
    cp "$m" "$w/stage/$base"
    echo "$m $base" >> "$w/pairs"
  done < "$w/native.members"
  check_pairing "$w"
  # Every libplatform and libbase module has its object (or is wholly in the regular partition,
  # which both archives also hold).
  for lib in libplatform libbase; do
    while IFS= read -r m; do
      grep -q "^$m " "$w/pairs" || grep -qxF "$m" "$w/native.members" \
        || log "note: $lib module $m has no object of its own (all of it is in the regular partition)"
    done < "$w/$lib.members"
  done
  rm -f obj/libv8_monolith.a.bitcode
  mv obj/libv8_monolith.a obj/libv8_monolith.a.bitcode
  (cd "$w/stage" && awk '{print $2}' "$w/pairs" | xargs "$LLVM/llvm-ar" rcs "$out/obj/libv8_monolith.a")
  for lib in libplatform libbase; do
    rm -f "obj/libv8_${lib}_fat.a"
    (cd "$w/stage" && { echo lto-regular-partition.o; awk 'NR==FNR {want[$1]=1; next} ($1 in want) {print $2}' "$w/$lib.members" "$w/pairs"; } \
      | xargs "$LLVM/llvm-ar" rcs "$out/obj/libv8_${lib}_fat.a")
  done
  log "out/official: $(ls -la obj/libv8_monolith.a obj/*_fat.a | awk '{print $5, $NF}' | tr '\n' ' ')"
}

# The object files the ninja edge for archive $1 (relative to the cwd, an out dir) archives, in
# order, with each thin archive among its inputs expanded into its members.
archived_objects() {
  local f
  "$(ninja_bin)" -C . -t query "$1" | awk '/^  input:/ {f = 1; next} /^  outputs:/ {f = 0} f && $1 != "|" && $1 != "||" {print $1}' \
    | while IFS= read -r f; do
      case "$f" in
        *.a) if [ "$(head -c 7 "$f")" = '!<thin>' ]; then "$LLVM/llvm-ar" t "$f"; else echo "!not-thin $f"; fi ;;
        *.o) echo "$f" ;;
        *) ;;
      esac
    done | awk '!seen[$0]++'
}

# Each native object defines what its bitcode module defined: ThinLTO adds promoted locals
# (".llvm.<hash>"), may drop a non-prevailing linkonce copy, and moves a split LTO unit's
# vtables and what they reference into the regular-LTO partition, but never moves a strong
# definition to another module. So the first strong (T/D/B/S) external symbols of each module
# must be defined by its object or by the regular partition; any miss means a wrong pairing.
check_pairing() {
  local w=$1 bad=0 m base want
  "$NM" --extern-only --defined-only --format=just-symbols "$w/stage/lto-regular-partition.o" | LC_ALL=C sort -u > "$w/regular.symbols"
  while read -r m base; do
    grep -qxF "$m" "$w/bitcode.members" || continue
    want=$("$NM" --extern-only --defined-only "$m" 2>/dev/null | awk '$(NF-1) ~ /^[TDBS]$/ && n++ < 5 {print $NF}')
    [ -n "$want" ] || continue
    if [ -n "$(LC_ALL=C comm -23 <(echo "$want" | LC_ALL=C sort -u) \
      <("$NM" --extern-only --defined-only --format=just-symbols "$w/stage/$base" | LC_ALL=C sort -u | LC_ALL=C sort -mu - "$w/regular.symbols"))" ]; then
      bad=$((bad + 1))
      [ "$bad" -gt 3 ] || echo "pairing: $m -> $base does not define: $(echo "$want" | head -2 | tr '\n' ' ')"
    fi
  done < "$w/pairs"
  [ "$bad" -eq 0 ] || die "pairing: $bad native objects do not define their module's strong symbols"
  log "pairing: every native object defines its module's strong symbols (or the regular partition does)"
}

step_verify() {
  local off="$V8/out/official" ctl="$V8/out/control" w="$V8/out/official/lto"
  cd "$V8"
  log "every archive member is arm64 Mach-O"
  local a n bad
  for a in "$off"/obj/libv8_monolith.a "$off"/obj/libv8_libplatform_fat.a "$off"/obj/libv8_libbase_fat.a; do
    rm -rf "$w/x"
    mkdir -p "$w/x"
    (cd "$w/x" && "$LLVM/llvm-ar" x "$a")
    n=$(ls "$w/x" | wc -l | tr -d ' ')
    bad=$(cd "$w/x" && file * | grep -vc 'Mach-O 64-bit object arm64' || true)
    echo "  $(basename "$a"): $n members, $bad not arm64 Mach-O"
    [ "$bad" -eq 0 ] || die "$(basename "$a") holds non-native members"
  done
  rm -rf "$w/x"
  log "external symbols: control vs official (defined, external)"
  "$NM" --extern-only --defined-only --format=just-symbols "$ctl/obj/libv8_monolith.a" 2>/dev/null | grep -v ':$' | grep . | LC_ALL=C sort -u > "$w/control.ext"
  "$NM" --extern-only --defined-only --format=just-symbols "$off/obj/libv8_monolith.a" 2>/dev/null | grep -v ':$' | grep . | LC_ALL=C sort -u > "$w/official.ext"
  echo "  control $(wc -l < "$w/control.ext"), official $(wc -l < "$w/official.ext"), promoted (.llvm.) $(grep -c '\.llvm\.' "$w/official.ext" || true)"
  LC_ALL=C comm -23 "$w/control.ext" "$w/official.ext" > "$w/missing.ext"
  echo "  in control, not in official: $(wc -l < "$w/missing.ext")"
  head -20 "$w/missing.ext"
  # Cross-module inlining: for each module, the calls it makes to functions another V8 module
  # defines (undefined references to V8's own strong symbols) in out/control's object and in
  # out/official's. A reference the control has and the official object lacks is a call ThinLTO
  # imported and inlined (or a callee it removed); .llvm.<hash> symbols are locals ThinLTO
  # promoted because another module imported a function that uses them.
  log "cross-module calls: per module, control object vs official object"
  LC_ALL=C sort -mu "$w/control.ext" "$w/official.ext" | awk '$1 !~ /\.llvm\./' > "$w/v8.defined"
  local m base gone=0 kept=0 added=0 mods=0
  while read -r m base; do
    [ -f "$ctl/$m" ] && [ -f "$w/stage/$base" ] || continue
    # (grep finding nothing is not a failure here.)
    { "$NM" --undefined-only --format=just-symbols "$ctl/$m" | LC_ALL=C sort -u | LC_ALL=C join - "$w/v8.defined" > "$w/c.refs"; } || true
    { "$NM" --undefined-only --format=just-symbols "$w/stage/$base" | grep -v '\.llvm\.' | LC_ALL=C sort -u | LC_ALL=C join - "$w/v8.defined" > "$w/o.refs"; } || true
    gone=$((gone + $(LC_ALL=C comm -23 "$w/c.refs" "$w/o.refs" | wc -l)))
    kept=$((kept + $(LC_ALL=C comm -12 "$w/c.refs" "$w/o.refs" | wc -l)))
    added=$((added + $(LC_ALL=C comm -13 "$w/c.refs" "$w/o.refs" | wc -l)))
    mods=$((mods + 1))
  done < "$w/pairs"
  echo "  over $mods modules: $gone cross-module call targets gone (inlined), $kept kept, $added new (callees of inlined code)"
  echo "  .llvm. promoted symbols (locals of imported functions): $(grep -c '\.llvm\.' "$w/official.ext" || true)"
  rm -f "$w/c.refs" "$w/o.refs"
  log "__TEXT sizes"
  for o in control official; do
    echo "  $o: $(size "$V8/out/$o/obj/libv8_monolith.a" 2>/dev/null | awk 'NR>1 {t+=$1} END {print t}') bytes of __TEXT"
  done
}

# Clang's profile match rate over every function the official build compiled. A function whose
# profile record matched carries a function_entry_count (!prof on its define); one without has
# either no record (missing) or a record whose CFG hash differs (mismatch: Chrome compiled a
# different body - V8_INTL_SUPPORT, Chromium's libc++, a later or earlier V8 commit). Read from the
# bitcode objects themselves (clang -x ir -S -emit-llvm, no passes), so nothing is recompiled.
# A function is counted once (linkonce copies across objects are one function); a local one is
# keyed "<source_filename>;<name>", as IR PGO names it.
step_pgomatch() {
  local off="$V8/out/official" w="$V8/out/official/pgomatch"
  rm -rf "$w"
  mkdir -p "$w"
  cd "$off"
  cp "$off/lto/bitcode.members" "$w/bitcode"
  log "pgomatch: $(wc -l < "$w/bitcode") bitcode objects"
  # One row per define: key, matched (0/1), its !prof metadata id, object; and one #count row per
  # function_entry_count metadata node.
  cat > "$w/defines.awk" <<'AWK'
/^source_filename = / { src = $3; gsub(/"/, "", src) }
/^define / {
  local = ($0 ~ /^define (dso_local )?(internal|private) /)
  # The name is the @identifier the parameter list follows (return attributes such as
  # dereferenceable(16) come before it).
  if (!match($0, /@("[^"]*"|[-a-zA-Z$._0-9]+)\(/)) next
  name = substr($0, RSTART + 1, RLENGTH - 2); gsub(/"/, "", name)
  key = local ? src ";" name : name
  id = ""
  if ($0 ~ / !prof ![0-9]+/) { id = $0; sub(/.* !prof !/, "", id); sub(/[^0-9].*/, "", id) }
  print key "\t" (id != "" ? 1 : 0) "\t" id "\t" obj
}
/^![0-9]+ = !\{!"function_entry_count", i64 [0-9]+\}/ {
  n = $1; sub(/!/, "", n); c = $0; sub(/.*i64 /, "", c); sub(/\}.*/, "", c)
  print "#count\t" n "\t" c "\t" obj
}
AWK
  cat > "$w/one.sh" <<'SH'
#!/bin/bash
# one.sh <clang> <defines.awk> <object>...: the defines.awk rows of each bitcode object.
clang=$1 prog=$2
shift 2
for m in "$@"; do
  "$clang" -target arm64-apple-macos11.0 -x ir -S -emit-llvm -Xclang -disable-llvm-passes "$m" -o - 2>/dev/null \
    | awk -v obj="$m" -f "$prog"
done
SH
  xargs -P "$JOBS" -n 20 bash "$w/one.sh" "$LLVM/clang" "$w/defines.awk" < "$w/bitcode" > "$w/defines.tsv"
  # Resolve each matched define's entry count; then one row per function, matched if any copy was.
  awk -F'\t' '
    $1 == "#count" { cnt[$4 SUBSEP $2] = $3; next }
    { rows[++n] = $0 }
    END {
      for (i = 1; i <= n; i++) {
        split(rows[i], f, "\t")
        c = (f[2] == "1") ? cnt[f[4] SUBSEP f[3]] : ""
        if (!(f[1] in seen) || (f[2] == "1" && seen[f[1]] == "0")) { seen[f[1]] = f[2]; entry[f[1]] = c }
      }
      for (k in seen) print k "\t" seen[k] "\t" entry[k]
    }' "$w/defines.tsv" | LC_ALL=C sort > "$w/functions.tsv"
  awk -F'\t' '$2 == "0" {print $1}' "$w/functions.tsv" | LC_ALL=C sort > "$w/unmatched"
  LC_ALL=C comm -12 "$w/unmatched" "$V8_ROOT/pgo/v8-standalone.names" > "$w/mismatched"
  local total matched hot mism
  total=$(wc -l < "$w/functions.tsv" | tr -d ' ')
  matched=$(awk -F'\t' '$2 == "1"' "$w/functions.tsv" | wc -l | tr -d ' ')
  hot=$(awk -F'\t' '$2 == "1" && $3 > 0' "$w/functions.tsv" | wc -l | tr -d ' ')
  mism=$(wc -l < "$w/mismatched" | tr -d ' ')
  pct() { awk -v a="$1" -v b="$2" 'BEGIN {printf "%.1f%%", 100 * a / b}'; }
  {
    echo "functions compiled (unique): $total"
    echo "with profile data (matched): $matched ($(pct "$matched" "$total")), of which entry count > 0: $hot"
    echo "record present, CFG hash differs (mismatch): $mism ($(pct "$mism" "$total"))"
    echo "no record (missing): $((total - matched - mism)) ($(pct $((total - matched - mism)) "$total"))"
    awk -F'\t' '$1 ~ /^_?_ZN?K?2v8|^_?_ZN?K?5cppgc|^\.\.\/\.\.\/src\// {t++; if ($2 == "1") m++; if ($2 == "1" && $3 > 0) h++}
      END {printf "V8 functions (v8::, cppgc::, locals of ../../src/): %d, matched %d (%.1f%%), entry count > 0: %d\n", t, m, 100 * m / t, h}' "$w/functions.tsv"
  } | tee "$w/summary.txt"
  rm -f "$w/defines.tsv"
}

step_install() {
  local name=${1:?install control|official}
  local out="$V8/out/$name" dest="$CRANE_V8/out/$name"
  [ "$name" = control ] || [ "$name" = official ] || die "install control|official"
  [ ! -e "$dest" ] || die "$dest exists (remove it first, by hand)"
  mkdir -p "$dest/obj"
  cp "$out/obj/libv8_monolith.a" "$out/obj/libv8_libplatform_fat.a" "$out/obj/libv8_libbase_fat.a" "$dest/obj/"
  cp "$out/args.gn" "$dest/args.gn"
  {
    echo "V8 $V8_TAG ($V8_COMMIT), built by scripts/build-v8-official.sh on $(hostname) $(date -u +%FT%TZ)"
    echo "clang: $("$LLVM/clang" --version | sed -n 1p)"
    echo "sdk: $(xcrun --sdk macosx --show-sdk-version)"
    [ "$name" = control ] || cat "$V8_ROOT/pgo/provenance.txt"
    [ "$name" = control ] || {
      echo "ThinLTO link flags: ${LTO_LINK_FLAGS[*]}"
      echo "builtins PGO: 13.1.203.0 x64.profile less $(wc -l < "$V8_ROOT/pgo/builtins-rejected.txt" | tr -d ' ') builtins whose graphs differ here and $(wc -l < "$V8_ROOT/pgo/builtins-absent.txt" | tr -d ' ') absent here: $(grep -c '^builtin_hash,' "$V8_ROOT/pgo/builtins-x64.profile") builtins, sha256 $(shasum -a 256 "$V8_ROOT/pgo/builtins-x64.profile" | cut -d' ' -f1)"
    }
  } > "$dest/PROVENANCE"
  (cd "$dest" && shasum -a 256 obj/*.a args.gn PROVENANCE > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
}

[ $# -gt 0 ] || { sed -n '2,40p' "$0"; exit 2; }
while [ $# -gt 0 ]; do
  s=$1
  shift
  case "$s" in
    checkout) step_checkout ;;
    control) step_control ;;
    profile) step_profile ;;
    official) step_official ;;
    verify) step_verify ;;
    pgomatch) step_pgomatch ;;
    install) step_install "${1:?install control|official}"; shift ;;
    *) die "unknown step $s" ;;
  esac
done
log "done"
