# Workflow: A macOS executable is not byte-reproducible from a cold cache - its debug map names each object by its cache path and time

**Date**: 2026-11-13
**Lesson**: Two cold builds of one Crane tree give Mach-O executables that differ in their debug map, their LC_UUID and their code signature and in no byte of code or data; compare cold macOS builds section by section, compare warm ones by sha256, and keep each build's outputs when the point of a build is to compare it.

**Why**: On macOS the debug information stays in the object files, and the linker writes a debug map into the executable: one N_OSO symbol per object, whose name is the object's absolute path and whose value is its modification time. Zig keeps each output in the cache under `o/<digest>/`, so the map holds cache paths - and that digest is not the same from one cold build to the next for every output. The LC_UUID is derived from the file's contents, and the ad-hoc code signature hashes its pages, so both follow. ELF has no such map (the DWARF is in the executable), which is why the same builds are byte-identical on Linux.

**What Happened**: The build migration's proof standard (tmp/plans/build-protocol-design.md 5.1) compares the sha256 of the build's outputs before and after a commit, and asked for a control first: build the base tree twice from a wiped cache and see which outputs are stable. Lane build2 ran it on main b1c9ba6ae77.
- chat.local (macOS): of 7 artifacts, the snapshot blob and repl.modes were identical; wpt_runner, wpt_runner_bug_finding, gc_bench and the release console all differed. The design had expected the reverse.
- server1 (Linux): all 7 identical; of the four more built later, the default console and wpt_build_compare were identical, and crane and libwhatwg_full.a - the two Debug-mode outputs - differed (not attributed).
- The control script had hashed each build and wiped it for the next, so there were no two files to compare: the attribution needed two more cold builds, on chat2.local, with each wpt_runner copied aside. Of 89,196,856 bytes, 9,055 differed, and all of them were accounted for: LC_UUID 16; the debug map 8,559 (string table 8,555, symbol table 4); the code signature 480. Every one of the 17 sections of __TEXT, __DATA_CONST and __DATA was byte-identical, and `nm -ap` without the OSO entries was identical. Of the map's 313 entries, 286 had another name because the cache directory of five C libraries (libcurl.a, libmbedtls.a, libjpeg.a, libnghttp2.a, libbrotlienc.a) and of the Zig object had another digest in the second build, and the two loose objects (v8_wrapper.o and the Zig object) carried another modification time. Five smaller libraries kept their directories. Why those digests move is not attributed (a guess, unverified: the order in which parallel C compiles finish).

**Fix**:
1. A per-commit "no output change" proof compares against a cache WARMED AT THE BASE COMMIT, on each OS: every compile step a cache hit, then the outputs' sha256 equal to the warm base's - where equality follows from the hits. Never a cold build against a cold build by hash on macOS.
2. A cold comparison on macOS normalises the identity fields: sha256 of each section of __TEXT, __DATA_CONST and __DATA, and `nm -ap` with the OSO lines removed; LC_UUID, the debug map and the code signature are left out. (Lane build2's scratch `macho_diff.py` does it; the batch that makes the cold check a gate ports it to a Zig tool.)
3. A control build that is only hashed can say THAT two builds differ, never WHERE. Copy each build's outputs aside before the next wipe.
4. A frozen binary's sha256 pin (docs/performance.md, `~/crane-frozen`) names a file that was built once and kept: it is unaffected, and it is never recomputed by rebuilding.

**Open** (measured, not attributed):
- Why Zig's `o/<digest>` of five C libraries and of the Zig object is not a pure function of the tree: two cold builds at one cache path, minutes apart, gave them other names, and five smaller libraries the same ones.
- Why crane and libwhatwg_full.a, the two Debug-mode outputs of the eleven, differ between two cold builds on Linux, where the nine others are identical. No second copy was kept there to compare.

**Takeaway**: **On macOS a cold rebuild changes an executable's debug map (cache paths and object times), UUID and signature and nothing else: prove build changes against a warm cache, compare cold builds by section, and keep the files you mean to compare.**
