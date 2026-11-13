# Workflow: A target that names the build machine's own triple is not native to the compiler - decide by what the target names, not by comparing it with the host

**Date**: 2026-11-13
**Lesson**: Zig searches the build machine's own library directories only for a target that names neither an OS nor an ABI; `-Dtarget=x86_64-linux-gnu` on an x86-64 Linux host names both and gets none, so a build rule written as "the host is another OS or architecture" is wrong on exactly the host it never ran on.

**Why**: A compile that names a system library (`linkSystemLibrary("sqlite3")`) resolves it when the compiler starts - before any Zig is analysed, and even when no binary is asked for (`-fno-emit-bin`). Where it looks depends on the target's QUERY, the way the target was asked for, not on the resolved target: with no OS and no ABI named, the compiler detects the build machine's library directories; with either named it has no sysroot and searches nothing. Two targets that resolve to the same machine can therefore differ in whether a system library is found.

**What Happened**: `zig build check-linux` runs check-target twice, for aarch64-linux-gnu and x86_64-linux-gnu, each as a sub-build with `-Dtarget=<triple>`. Its three compile-only checks (crane, both WPT runners: all the Zig analysed, the engine's wrapper compiled, nothing linked) name sqlite3 and leveldb through the storage module, so build.zig gives them empty shared libraries of those names (`addCrossLibraryStubs`). The function returned early "when the host is Linux of the target's architecture" - written on a Mac, where every Linux target is foreign. On server1, the first x86-64 Linux host to run it, the second sub-build failed and had failed since the host joined the pool, at main and at every lane's tip alike:

```
error: unable to find dynamic system library "sqlite3" using strategy paths_first. searched paths: none
Build Summary: 218/222 steps succeeded (3 failed)
```

The same host builds and links the real libraries in every native build, which is what made "no stub needed here" look right. Measured on server1 with one empty program that names sqlite3 and asks for no binary:

| how the target is named | sqlite3 |
|---|---|
| no `-target`; `-target native`; `-target x86_64-native` (the architecture alone) | found |
| `-target native-native-gnu` (the ABI named) | not found: searched paths: none |
| `-target native-linux` (the OS named) | not found |
| `-target x86_64-linux`; `-target x86_64-linux-gnu` (the host's own triple) | not found |

**Fix**:
1. The rule asks what the compiler asks: `target.query.os_tag != null or target.query.abi != null` (a `std.Build.ResolvedTarget` keeps its query beside its result). A compile-only check of such a Linux target gets the stubs; a native build names neither and gets none, as before; a cross-compile names both and gets them, as before. After: `check-linux` 3/3 steps, each sub-build 231/231.
2. Do not compare `b.graph.host.result` with `target.result` to decide whether the compiler will find something on the machine: equal results do not mean a native query. Ask the query.
3. A check that only one kind of host can fail must run on that kind of host before the rule is called done: this one had only ever passed where it could not fail.

**Takeaway**: **"Native" is a property of how a target was asked for, not of what it resolves to: the compiler searches the host's library directories only when the target names no OS and no ABI. A build rule about what the compiler will find on the machine reads `target.query`, never a host-against-target comparison - and a rule written on one OS is unproven until it has run on the other.**
