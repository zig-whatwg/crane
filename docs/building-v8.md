# Building V8 for Crane

Crane 0.1 links **V8 `15.7.112.43`** (commit `307108153d1e35e6e74528ee55f97b0cd59bf182`, the V8 shipped in Chrome 157) built with **ICU 78** (`v8_enable_i18n_support = true`), **Temporal** (`v8_enable_temporal_support = true`), and **Chromium's hardened `libc++`** (`use_custom_libcxx = true`).

System or Homebrew V8 packages cannot be linked: V8's public C++ headers inline pointer-compression, sandbox, and `cppgc` ABI details and pass `std::unique_ptr` / `std::shared_ptr` across the boundary, so Crane's C++ adapter (`src/runtime/engines/v8/v8_wrapper.cpp`) must compile against the exact `v8-gn.h`, Chromium `libc++` headers, and ICU defines produced by the V8 build it links.

Three paths are supported:

1. **[Option A: Prebuilt V8 Tarballs](#option-a--prebuilt-v8-tarballs-fastest)** (recommended for almost everyone)
2. **[Option B: Statically Compiling V8 from Source](#option-b--statically-compiling-v8-from-source-default)** (default for `crane-release`, single self-contained binary)
3. **[Option C: Dynamically Compiling V8 from Source](#option-c--dynamically-compiling-v8-from-source)** (component build for faster iterative relinks)

---

## Prerequisites

- **Pinned Zig:** `0.17.1-dev+77c319a0f0` (0.17.x branch at `77c319a0f00a`), or `0.17.1+` once released. Zig `0.17.0` is refused by `build.zig` ([`tools/zig_toolchain.zig`](../tools/zig_toolchain.zig)).
- **Targets:** `macos-arm64`, `macos-x86_64`, `linux-x86_64`, and `linux-arm64` (cross-compiled from Linux `x86_64` with Chromium's Debian Bullseye `arm64` sysroot because V8's `DEPS` ships Linux prebuilt clang/rustc/gn for `x64` hosts only).
- **When compiling V8 from source (Options B & C):**
  - `git`, `python3` (with the `lzma` module for unpacking `.tar.xz` GCS packages), `curl`, `tar`
  - **~25 GB free disk** at `$V8_ROOT` (checkout ~10 GB, Ninja build output ~10 GB)
  - **macOS:** full Xcode installation at `/Applications/Xcode.app/Contents/Developer` (or `DEVELOPER_DIR` set). Chromium's GN scripts query `xcodebuild` for the SDK, which Command Line Tools alone cannot answer.

---

## Option A — Prebuilt V8 Tarballs (Fastest)

Download the tarball matching your target (`macos-arm64`, `macos-x86_64`, `linux-x86_64`, or `linux-arm64`) and link mode (`static` or `dynamic`) from the [`v8-prebuilt-15.7.112.43`](https://github.com/zig-whatwg/crane/releases/tag/v8-prebuilt-15.7.112.43) GitHub pre-release, unpack it, verify its checksums, and pass `-Dv8-dir` when building Crane:

```bash
# Static example (unpack anywhere or into jsengines/v8/15.7.112.43-icu)
tar -xzf v8-15.7.112.43-<target>-static.tar.gz -C /path/to/

# Verify archive integrity
# Linux:
(cd /path/to/v8-15.7.112.43-<target>-static && sha256sum -c SHA256SUMS)
# macOS:
(cd /path/to/v8-15.7.112.43-<target>-static && shasum -a 256 -c SHA256SUMS)

# Build Crane (omit -Dv8-dir if installed at jsengines/v8/15.7.112.43-icu)
zig build crane-release -j2 -Dv8-dir=/path/to/v8-15.7.112.43-<target>-static
```

For prebuilt dynamic tarballs (`v8-15.7.112.43-<target>-dynamic.tar.gz`), verify `out/dynamic/SHA256SUMS` and pass `-Dv8-link=dynamic -Dv8-dir=/path/to/v8-15.7.112.43-<target>-dynamic`.

---

## Option B — Statically Compiling V8 from Source (Default)

[`scripts/build-v8-15.7.sh`](../scripts/build-v8-15.7.sh) checks out V8 `15.7.112.43` cleanly (no source patches, `--nohooks`, telemetry disabled), compiles the static monolith with V8's own pinned clang and Rust toolchains, extracts Temporal's Rust objects and system library flags from `d8`'s link recipe, smoke-tests linking with Zig's own linker, and installs atomically with `SHA256SUMS`.

### Running the Build Script

```bash
# Run every step in order: deps -> checkout -> build -> rust -> verify -> smoke -> install
scripts/build-v8-15.7.sh all

# Optional: remove Ninja build intermediates (~10 GB) after install succeeds
scripts/build-v8-15.7.sh clean
```

Steps can also be run individually (`deps`, `checkout`, `build`, `rust`, `verify`, `smoke`, `install`, `clean`). Useful environment overrides:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `V8_ROOT` | `~/v8-15.7.112.43` | gclient checkout and build root |
| `CRANE_V8` | `~/projects/crane/jsengines/v8` | Install parent directory (installs into `$CRANE_V8/15.7.112.43-icu/`) |
| `ZIG` | `~/crane-toolchains/zig-0.17.1-dev+77c319a0f0/bin/zig` | Pinned Zig used for the `smoke` step |
| `JOBS` | host CPU count | Parallelism passed to `ninja -j` |
| `DEVELOPER_DIR` | `/Applications/Xcode.app/Contents/Developer` | macOS Xcode developer directory |

### Building Crane Against Static V8

```bash
zig build crane-release -j2 -Dv8-link=static -Dv8-dir=jsengines/v8/15.7.112.43-icu
```

### Static GN Arguments

```gn
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
v8_enable_i18n_support = true
icu_use_data_file = false
clang_use_chrome_plugins = false
treat_warnings_as_errors = false
use_custom_libcxx = true
use_siso = false
v8_enable_partition_alloc = false
v8_enable_temporal_support = true
v8_generate_external_defines_header = true
cppgc_enable_object_names = false
cppgc_enable_object_section_gcinfo = false
target_cpu = "arm64"   # macOS Apple Silicon; "x64" on Linux x86_64

# Linux only:
use_sysroot = false
use_glib = false
```

---

## Option C — Dynamically Compiling V8 from Source

Component builds link V8 as shared libraries instead of a monolithic static archive, reducing link times during local Crane development.

### Running the Build Script

```bash
scripts/build-v8-15.7.sh --dynamic all
```

### Dynamic GN Arguments

Identical to the static GN arguments above, except:

```gn
is_component_build = true
v8_monolithic = false
```

All ABI-critical flags (`use_custom_libcxx = true`, `v8_enable_sandbox = true`, `v8_enable_pointer_compression = true`, `v8_enable_i18n_support = true`, `icu_use_data_file = false`, `v8_enable_temporal_support = true`, `v8_generate_external_defines_header = true`) stay the same.

### Building and Running Crane Against Dynamic V8

`scripts/build-v8-15.7.sh --dynamic` installs into `jsengines/v8/15.7.112.43-icu/out/dynamic/` without touching `out/static/`:

```bash
zig build crane -j2 -Dv8-link=dynamic -Dv8-dir=jsengines/v8/15.7.112.43-icu
```

Because V8's shared libraries are loaded at runtime:

- **macOS:** Set `DYLD_LIBRARY_PATH` to the installed dynamic output directory (or embed an rpath):
  ```bash
  DYLD_LIBRARY_PATH=jsengines/v8/15.7.112.43-icu/out/dynamic ./zig-out/bin/crane
  ```
- **Linux:** Set `LD_LIBRARY_PATH` to the installed dynamic output directory (or embed an rpath):
  ```bash
  LD_LIBRARY_PATH=jsengines/v8/15.7.112.43-icu/out/dynamic ./zig-out/bin/crane
  ```

---

## Why Each Build Choice Matters

### 1. Chromium's Hardened `libc++` (`use_custom_libcxx = true`)

V8 15.7's sandbox requires `libc++` hardening (`BUILD.gn`: `assert(!v8_enable_sandbox || use_safe_libcxx)`), and Chromium's `use_safe_libcxx` requires `use_custom_libcxx = true`. That compiles V8 against Chromium's `third_party/libc++` (inline namespace `std::__Cr`, ABI v2).

Because `v8_wrapper.cpp` passes `std::unique_ptr` and `std::shared_ptr` across V8's C++ API, Crane compiles `v8_wrapper.cpp` with `-nostdinc++` against the installed `libcxx/` headers and consumer flags (`libcxx/flags.txt`, extracted directly from Ninja's compile commands) and links `libc++_chromium.a` instead of Zig's `libc++`. The `verify` step fails if any `std::__1`, `std::__cxx11`, or `__gnu_cxx` symbol appears in any archive.

### 2. Linked-in ICU (`v8_enable_i18n_support = true`, `icu_use_data_file = false`)

V8's `Intl`, Unicode property escapes (`\p{...}`), `String.prototype.normalize`, and locale-sensitive collation require ICU. Setting `icu_use_data_file = false` assembles Chromium's `icudtl.dat` (~10.8 MB) directly into the archive (`icudt<N>_dat`), so `crane` stays a single self-contained binary without a sidecar `icudtl.dat` file. Public ICU headers (`icu/include/unicode/*.h`) and consumer defines (`icu/flags.txt`) are installed beside V8 so the adapter can configure ICU's default locale through `uloc_setDefault`.

### 3. Temporal's Rust Objects (`v8_enable_temporal_support = true`)

V8 15.7 implements Temporal via Rust (`temporal_capi`, `temporal_rs`, and ICU4X crates), compiled with V8's own `third_party/rust-toolchain` (no Rust toolchain is required to build Crane itself). GN's `v8_monolith` does not bundle `.rlib` objects, so `step_rust` links `d8` with `-d keeprsp`, reads Chromium's exact link recipe, repacks all Rust `.rlib` and shim objects into `librust_v8.a`, and records the required system libraries and frameworks in `system-libs.txt`.

### 4. External ABI Defines (`v8_generate_external_defines_header = true`)

Generates `gen/include/v8-gn.h`, installed into `include/v8-gn.h`. Crane compiles `v8_wrapper.cpp` with `-DV8_GN_HEADER` so V8 and `cppgc` public headers always agree with the linked build's ABI instead of duplicating fragile `#define` flags by hand.

### 5. Linux ELF `SHT_CREL` Relocation Stripping

On Linux, Chromium's compiler config adds `-Wa,--crel,--allow-experimental-crel` when targeting `lld`. Zig 0.17's self-hosted ELF linker (used for Debug `x86_64` executables such as the snapshot generator and test binaries) does not apply `SHT_CREL` relocations. On Linux, `scripts/build-v8-15.7.sh` sets:

```bash
export CCC_OVERRIDE_OPTIONS='#x-Wa,--crel,--allow-experimental-crel'
```

so clang emits standard `RELA` relocations that both `lld` and Zig's self-hosted ELF linker apply identically. Both `step_verify` (checking `llvm-readelf -S` for `.crel.*` sections) and `step_smoke` (linking and running a Zig executable with `-fno-lld`) enforce this.

### 6. Thin Archives Repacked as Regular ("Fat") Archives

GN creates thin archives for `libv8_libplatform.a` and `libv8_libbase.a` whose members are relative paths into the build directory. `step_build` repacks them into regular archives (`libv8_libplatform_fat.a`, `libv8_libbase_fat.a`) so the install directory is fully relocatable and readable by Zig's linker.

---

## Installed Directory Layout (Static)

```text
jsengines/v8/15.7.112.43-icu/
├── include/                      # V8 & cppgc headers + generated v8-gn.h
├── out/static/obj/
│   ├── libv8_monolith.a          # V8 + embedded ICU code & data
│   ├── libv8_libplatform_fat.a   # Regular archive of v8_libplatform
│   ├── libv8_libbase_fat.a       # Regular archive of v8_libbase
│   ├── libc++_chromium.a         # Chromium hardened libc++ & libc++abi
│   └── librust_v8.a              # Temporal Rust + std objects
├── libcxx/
│   ├── config/                   # __config_site, __assertion_handler
│   ├── include/                  # Chromium libc++ headers
│   ├── abi-include/              # Chromium libc++abi headers
│   └── flags.txt                 # Consumer -D defines and -nostdinc++
├── icu/
│   ├── include/unicode/          # Public ICU headers (uloc.h, urename.h, ...)
│   └── flags.txt                 # Consumer ICU -D defines
├── system-libs.txt               # -framework / -l flags read from d8's link
├── args.gn                       # Exact GN arguments used
├── PROVENANCE                    # Commit, clang/rustc/ICU/SDK versions
└── SHA256SUMS                    # Checksums for every installed file
```

---

## Troubleshooting

- **`build.zig` refuses Zig version:** Install the pinned Zig `0.17.1-dev+77c319a0f0` (or `0.17.1+`). Zig `0.16.x` and `0.17.0` are explicitly rejected.
- **`no Xcode at DEVELOPER_DIR` on macOS:** Install full Xcode and run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (or export `DEVELOPER_DIR`).
- **`python3 has no lzma module`:** Install a Python 3 built with `liblzma` / `xz` support so `gclient` can unpack Chromium's `.tar.xz` toolchains.
- **V8 archive missing at configure time:** Verify the path passed to `-Dv8-dir` contains `libcxx/flags.txt`, `icu/flags.txt`, `system-libs.txt`, and `include/v8-gn.h`, and check `SHA256SUMS`.
- **Dynamic build fails to launch (`dyld: Library not loaded` / `cannot open shared object file`):** Ensure `DYLD_LIBRARY_PATH` (macOS) or `LD_LIBRARY_PATH` (Linux) includes the dynamic V8 output directory.
