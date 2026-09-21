//! V8 flags: what belongs to snapshot generation and what belongs to running.
//!
//! Until now one flag string was used for both, and it was the generation one.
//! `--predictable` and `--hash-seed=0` exist to make snapshot BUILDING
//! deterministic; applying them to every running browser had three costs, and
//! M3 in the migration plan names all of them:
//!
//!   * `--predictable` implies `single_threaded_gc` and negates
//!     `concurrent_recompilation`, `lazy_compile_dispatcher`, the parallel compile
//!     tasks, background maglev, `concurrent_sparkplug` and `memory_reducer`
//!     (this V8 checkout, `flag-definitions.h:3866-3881`). V8's own parallelism
//!     was off, so every "single-threaded Crane" measurement was against a
//!     hobbled engine.
//!   * it pins `random_seed` to 12347, making `Math.random()` repeat across runs -
//!     observable to content, and not something a page can be expected to tolerate.
//!   * `--hash-seed=0` removes hash-flooding protection.
//!
//! Loading a snapshot does not need either. V8 reports this build's snapshot as
//! rehashable (`v8_Snapshot_CanBeRehashed` prints `true` during generation), which
//! is V8 saying the blob tolerates a different hash seed at load time. And if that
//! ever stopped being true, loading fails with V8's own rehashability assertion -
//! a named, immediate failure rather than a quiet misbehaviour.
//!
//! These are string-level tests. They cannot prove V8 honours a flag, but they can
//! prove the two sets have not been silently merged back together, which is the
//! regression that would undo this without anyone noticing.

const std = @import("std");
const v8 = @import("v8");
const loader = v8.snapshot_loader;

test "the runtime flag set does not carry generation-time determinism knobs" {
    // The whole point. If either of these reappears here, every browser this
    // library starts loses V8's parallelism and gets a deterministic Math.random().
    try std.testing.expect(std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--predictable") == null);
    try std.testing.expect(std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--hash-seed") == null);
}

test "snapshot generation still gets both determinism flags" {
    // Dropping them from generation would be the opposite error: snapshots would
    // stop being reproducible, and the rehashability contract this relies on is
    // only meaningful because the blob was built deterministically.
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--predictable") != null);
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--hash-seed=0") != null);
}

test "every runtime flag is also present at generation" {
    // Generation must be a superset. A flag that changes V8's behaviour at runtime
    // but not while building the snapshot produces a blob built against different
    // semantics than the one loading it - the exact mismatch class that makes
    // snapshot bugs so hard to localise.
    var it = std.mem.tokenizeScalar(u8, loader.RUNTIME_V8_FLAGS, ' ');
    while (it.next()) |flag| {
        if (std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, flag) == null) {
            std.log.err("runtime flag '{s}' is missing from SNAPSHOT_V8_FLAGS", .{flag});
            return error.RuntimeFlagMissingFromSnapshotFlags;
        }
    }
}

test "ShadowRealm stays on in both sets" {
    // It is a language feature the interfaces depend on, not a determinism knob,
    // so it belongs to the runtime set - and therefore to both.
    try std.testing.expect(std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--harmony-shadow-realm") != null);
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--harmony-shadow-realm") != null);
}

test "jitless, when built in, appears in both sets" {
    // It must be identical across generation and loading: a snapshot built by a
    // JIT-capable V8 and loaded by a jitless one is a different engine
    // configuration, and on iOS the jitless half is not optional - the platform
    // gives third-party apps no W^X exception, so a JIT-generating V8 gets the
    // process killed.
    const runtime_has = std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--jitless") != null;
    const snapshot_has = std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--jitless") != null;
    try std.testing.expectEqual(runtime_has, snapshot_has);
}

test "neither set is empty or ends in a stray separator" {
    // `SNAPSHOT_V8_FLAGS` is built by concatenating two strings with a space. A
    // trailing or doubled separator is the kind of thing V8 accepts silently while
    // a reader assumes it parsed something.
    try std.testing.expect(loader.RUNTIME_V8_FLAGS.len > 0);
    try std.testing.expect(loader.SNAPSHOT_V8_FLAGS.len > 0);
    try std.testing.expect(!std.mem.endsWith(u8, loader.SNAPSHOT_V8_FLAGS, " "));
    try std.testing.expect(!std.mem.startsWith(u8, loader.SNAPSHOT_V8_FLAGS, " "));
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "  ") == null);
}
