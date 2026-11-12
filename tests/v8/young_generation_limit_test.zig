//! The young generation's size is a V8 BUILD option,
//! `-Dv8-young-generation-mb=<n>` (src/runtime/engines/v8/
//! young_generation.zig): megabytes of the WHOLE young generation of every
//! isolate the build makes - 24 is 8 MB semispaces, 0 is V8's own sizing,
//! not given is the adapter's one default. Not an option of the engine
//! protocol: JavaScriptCore's public API has no heap sizing (the user,
//! 2026-11-12).
//!
//! A test binary is ONE build, so the values are pinned two ways:
//!   - through the adapter's one creation function with the limit given
//!     (protocol_agents.createAgentWithYoungGeneration, which createAgent
//!     calls with the build's): 24 MB, 6 MB, a value that rounds down, and
//!     none - at both isolate-creation sites, a fresh isolate and one
//!     restored from the snapshot;
//!   - an agent made through the protocol (engine.createAgent) has THIS
//!     build's limit, whatever the build was given. Run the file in a second
//!     build to see another value arrive from the command line:
//!     `zig build test -j2 -Dspec=v8 -Dv8-young-generation-mb=24
//!     -Dtest-filter='young_generation_limit_test*'`.
//!
//! On V8 the young generation is two semispaces and a new large object space
//! of a semispace's size, and it only grows while what it holds survives
//! (Heap::ShouldResizeNewSpace: survivors since the last expansion exceed its
//! capacity). So each test first keeps everything it allocates - strings and
//! closures, about 150 MB, which no allocation site pretenures into the old
//! generation as it does array and object literals that keep surviving -
//! which takes an unlimited young generation to V8's own 32 MB semispaces.
//!
//! What it reads is what the heap has committed to "new_space"
//! (Isolate::GetHeapSpaceStatistics: both semispaces), and WHEN it reads
//! matters: V8 lets the young generation take pages ABOVE its ceiling while
//! a full collection is marking, so as not to end that collection early, and
//! gives them back when it is over (15.7.112.43 src/heap/heap.cc:5552-5580,
//! Heap::ShouldExpandYoungGenerationOnSlowAllocation and
//! IsNewSpaceAllowedToGrowAboveTargetCapacity) - and 150 MB of survivors
//! promoted into the old generation keeps full collections marking (a 24 MB
//! limit read 24.5 MB committed at one such moment, a 6 MB limit 18.9 MB).
//! So after the survivors each test runs pieces of script that make garbage
//! alone - the old generation stops growing, the marking under way finishes,
//! and the young generation, still allocating fast, keeps its size - and
//! takes the LEAST it read after those: the young generation at rest. That
//! it reached the ceiling is the MOST it read at any time.
//! Values are made the way a page makes them: script in a Window realm.
const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const ffi = v8.ffi;
const young_generation = v8.young_generation;

/// The snapshot this build generated (build.zig passes its path and makes
/// the tests depend on the step that writes it).
const snapshot_path = @import("test_snapshot").path;

const mb = 1024 * 1024;

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}
/// The global of a realm restored from the snapshot, as
/// pattern_attribute_snapshot_test.zig makes its own.
fn createSnapshotGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(std.heap.c_allocator, realm) catch null;
}
fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
const reporter: engine.Reporter = .{ .report = report, .host = null };
const hooks: engine.HostHooks = .{};

/// Run `body` on a thread of its own: its agents are that thread's host
/// agents, and nothing it makes is left on the test's thread.
fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

/// One piece of survivors: 100,000 strings and 100,000 closures, each with
/// its own context, every one kept. Twenty pieces are about 150 MB that all
/// survives its young collections, so the young generation grows as far as
/// it is allowed. (Not array or object literals: once those keep surviving,
/// V8's allocation-site pretenuring makes them in the old generation and the
/// young one stops growing - the first form of this test read 8 MB of
/// semispaces with no limit at all.)
const survivors = "globalThis.kept ??= []; for (let i = 0; i < 100000; i++) { const n = kept.length; kept.push('k' + n, () => n); } String(kept.length)";
const survivor_pieces = 20;

/// One piece of garbage: 1,000,000 strings, each dead 64 strings later -
/// about 24 MB the young generation collects by itself, and nothing for the
/// old one.
const garbage = "globalThis.ring ??= new Array(64).fill(''); for (let i = 0; i < 1000000; i++) { ring[i & 63] = 'g' + i; } String(ring.length)";
const garbage_pieces = 8;

const Semispaces = struct {
    /// The most the heap had committed to its two semispaces after any
    /// piece: how far the young generation got.
    most: usize,
    /// The least it had committed after a piece of garbage: the young
    /// generation at rest, no full collection marking.
    at_rest: usize,
};

/// How an agent's young generation is limited.
const Limit = union(enum) {
    /// Given to the adapter's creation function: bytes of the whole young
    /// generation, null for V8's own sizing.
    given: ?usize,
    /// The build's (-Dv8-young-generation-mb, or the adapter's default):
    /// an agent as the protocol makes one, engine.createAgent.
    the_builds,
};

fn makeAgent(limit: Limit, options: engine.AgentOptions) !*engine.Agent {
    return switch (limit) {
        .given => |bytes| v8.protocol_agents.createAgentWithYoungGeneration(options, bytes),
        .the_builds => engine.createAgent(options),
    };
}

/// `realm` run through the survivors and then the garbage.
fn runThrough(realm: runtime.Context, isolate: *ffi.Isolate) !Semispaces {
    var result: Semispaces = .{ .most = 0, .at_rest = std.math.maxInt(usize) };
    for (0..survivor_pieces) |_| {
        const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = survivors }, "survivors.js", null, std.testing.allocator, reporter);
        std.testing.allocator.free(text);
        result.most = @max(result.most, ffi.v8_Debug_HeapSpaceCommittedBytes(isolate, "new_space"));
    }
    const kept = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = "String(kept.length)" }, "survivors.js", null, std.testing.allocator, reporter);
    defer std.testing.allocator.free(kept);
    try std.testing.expectEqualStrings("4000000", kept);
    for (0..garbage_pieces) |_| {
        const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = garbage }, "garbage.js", null, std.testing.allocator, reporter);
        std.testing.allocator.free(text);
        const committed = ffi.v8_Debug_HeapSpaceCommittedBytes(isolate, "new_space");
        result.most = @max(result.most, committed);
        result.at_rest = @min(result.at_rest, committed);
    }
    return result;
}

/// A new agent limited as `limit` says - a fresh isolate, the first of the
/// adapter's two isolate-creation sites - its Window realm run through the
/// survivors and then the garbage.
fn semispacesOf(limit: Limit) !Semispaces {
    const own_runtime = test_process.OwnRuntime.begin(std.testing.allocator);
    defer own_runtime.end();
    const agent = try makeAgent(limit, .{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm_options: engine.WindowRealmOptions = .{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://young-generation.test", .create_global_object = createGlobal };
    const realm = try engine.createWindowRealm(&realm_options);
    defer engine.destroyWindowRealm(realm, .global_detached);
    return runThrough(realm, @ptrCast(@alignCast(agent)));
}

/// V8 commits a space in pages, and a semispace pair read 512 KB over twice
/// its capacity at rest: a megabyte of slack, where the sizes a limit can
/// come to differ by a factor of two.
const slack = mb;

/// `semispaces` are those of a young generation held to `semispace` bytes
/// each: at rest never more than two of them, and it did reach them.
fn expectHeldTo(what: []const u8, semispaces: Semispaces, semispace: usize) !void {
    if (semispaces.at_rest > 2 * semispace + slack or semispaces.most + slack < 2 * semispace) {
        std.debug.print("{s}: {d} KB committed to the semispaces at rest, {d} KB at most (two semispaces of {d} MB allowed)\n", .{ what, semispaces.at_rest / 1024, semispaces.most / 1024, semispace / mb });
    }
    // At rest, never more than two semispaces of the size the limit allows...
    try std.testing.expect(semispaces.at_rest <= 2 * semispace + slack);
    // ...and it did reach that ceiling: the limit is what stopped it.
    try std.testing.expect(semispaces.most + slack >= 2 * semispace);
}

/// `semispaces` are those of a young generation V8 sized by itself: 15.7
/// grows its semispaces to 32 MB, so the same script leaves well over the
/// 16 MB that 8 MB semispaces come to.
fn expectV8sOwn(what: []const u8, semispaces: Semispaces) !void {
    if (semispaces.at_rest <= 16 * mb + slack) {
        std.debug.print("{s}: only {d} KB committed to the semispaces at rest ({d} KB at most)\n", .{ what, semispaces.at_rest / 1024, semispaces.most / 1024 });
    }
    try std.testing.expect(semispaces.at_rest > 16 * mb + slack);
}

fn twentyFourMegabytes() !void {
    // V8 13.1's ceiling: three 8 MB semispaces' worth.
    try expectHeldTo("24 MB", try semispacesOf(.{ .given = 24 * mb }), 8 * mb);
}

test "a young generation of 24 MB keeps the semispaces at 8 MB each" {
    try onThread(twentyFourMegabytes);
}

fn sixMegabytes() !void {
    try expectHeldTo("6 MB", try semispacesOf(.{ .given = 6 * mb }), 2 * mb);
}

test "a young generation of 6 MB keeps the semispaces at 2 MB each" {
    try onThread(sixMegabytes);
}

fn roundedDown() !void {
    // 20 MB holds three 4 MB semispaces, not three of 8: the adapter rounds
    // DOWN to a size V8 supports, never past what the build said.
    try expectHeldTo("20 MB", try semispacesOf(.{ .given = 20 * mb }), 4 * mb);
}

test "a value between two sizes rounds down, never up" {
    try onThread(roundedDown);
}

fn noLimit() !void {
    try expectV8sOwn("no limit", try semispacesOf(.{ .given = null }));
}

test "no limit leaves V8's own ceiling" {
    try onThread(noLimit);
}

fn theBuilds() !void {
    // What -Dv8-young-generation-mb (or, without it, the adapter's default)
    // came to for this build: every agent the protocol makes has it.
    const semispaces = try semispacesOf(.the_builds);
    const limit = young_generation.limit orelse return expectV8sOwn("this build (V8's own sizing)", semispaces);
    const semispace = young_generation.semispaceBytes(limit);
    // The script grows a young generation as far as V8's own 32 MB
    // semispaces: a build that allows that much, or more, is told from a
    // smaller one, not from a larger.
    if (semispace >= 32 * mb) return expectV8sOwn("this build (32 MB semispaces or more)", semispaces);
    try expectHeldTo("this build", semispaces, semispace);
}

test "an agent made through the protocol has this build's young generation" {
    try onThread(theBuilds);
}

test "an agent restored from the snapshot is held to its young generation too" {
    // The adapter's second isolate-creation site, and the one a Browser's
    // agents come from. A host gives the engine its snapshot when the process
    // starts, before anything else touches V8 (pattern_attribute_snapshot_test.zig
    // says what happens otherwise): where V8 was started earlier in this
    // process the test skips, saying so. tests-v8 runs a process per test.
    if (ffi.v8_Platform_IsInitialized()) {
        std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
        return error.SkipZigTest;
    }
    const io = std.testing.io;
    // Missing is a failure: the build made it for this test.
    const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
    defer file.close(io);
    const size = (try file.stat(io)).size;
    const bytes = try std.heap.c_allocator.alloc(u8, size);
    defer std.heap.c_allocator.free(bytes);
    _ = try file.readPositionalAll(io, bytes, 0);

    try test_process.startSnapshot(bytes);
    defer test_process.endSnapshot();
    const agent = try makeAgent(.{ .given = 24 * mb }, .{ .can_block = false, .from_snapshot = true, .hooks = &hooks, .host = null });
    defer engine.destroyAgent(agent);
    // Restored, not made afresh (createAgent falls back to a fresh isolate,
    // with a warning, when the snapshot does not restore - which would make
    // this test pass through the other site).
    if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.heap.c_allocator, .from_snapshot = true, .timer = null, .origin = "https://young-generation.test", .create_global_object = createSnapshotGlobal });
    defer engine.destroyWindowRealm(realm, .global_detached);
    try expectHeldTo("24 MB, an agent restored from the snapshot", try runThrough(realm, @ptrCast(@alignCast(agent))), 8 * mb);
}

test "the build's megabytes become the limit: not given is the default, 0 is V8's own" {
    const limitFor = young_generation.limitFor;
    // Not given: the adapter's default - which may itself be V8's own.
    try std.testing.expectEqual(@as(?usize, null), limitFor(null, null));
    try std.testing.expectEqual(@as(?usize, 24 * mb), limitFor(null, 24));
    // Given: the build's, whatever the default is.
    try std.testing.expectEqual(@as(?usize, 24 * mb), limitFor(24, null));
    try std.testing.expectEqual(@as(?usize, 48 * mb), limitFor(48, 24));
    try std.testing.expectEqual(@as(?usize, 96 * mb), limitFor(96, 24));
    // 0: V8's own sizing, expressible whatever the default is.
    try std.testing.expectEqual(@as(?usize, null), limitFor(0, 24));
    try std.testing.expectEqual(@as(?usize, null), limitFor(0, null));
    // And this build's limit is that of what it was given.
    try std.testing.expectEqual(limitFor(young_generation.requested_mb, young_generation.default_mb), young_generation.limit);
}

test "a limit becomes three power-of-two semispaces, rounded down, never under V8's smallest" {
    const convert = young_generation.maxYoungGenerationBytes;
    try std.testing.expectEqual(@as(usize, 0), convert(null));
    // V8 13.1's ceiling and Chrome's on a phone below its high-end threshold.
    try std.testing.expectEqual(@as(usize, 24 * mb), convert(24 * mb));
    // V8 15.7's own, which Chrome 157 ships on desktop.
    try std.testing.expectEqual(@as(usize, 96 * mb), convert(96 * mb));
    // Down, never up: 20 MB holds three 4 MB semispaces, not three of 8.
    try std.testing.expectEqual(@as(usize, 12 * mb), convert(20 * mb));
    try std.testing.expectEqual(@as(usize, 24 * mb), convert(47 * mb));
    try std.testing.expectEqual(@as(usize, 48 * mb), convert(48 * mb));
    // Never under the semispace V8 starts with.
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(1));
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(3 * mb));
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(5 * mb));
    try std.testing.expectEqual(@as(usize, 6 * mb), convert(6 * mb));
}
