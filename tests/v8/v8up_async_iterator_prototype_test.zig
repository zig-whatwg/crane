//! An asynchronous iterator's prototype chain reaches the realm's ONE
//! %AsyncIteratorPrototype%, in every kind of realm an iterator can be made
//! in (WebIDL 3.7.10.2, "Asynchronous iterator prototype object": "The
//! [[Prototype]] internal slot of an asynchronous iterator prototype object
//! must be %AsyncIteratorPrototype%").
//!
//! Lane v8up b8 (2026-11-13). The engine protocol's createAsyncIterator
//! (src/runtime/engines/v8/protocol_async_iterator.zig) reached the intrinsic
//! by compiling and running "(async function* () {}).prototype" on EVERY
//! call, beside the copy the realm already recorded when it was made
//! (realm_v8.populateIntrinsics, runtime.Realm's intrinsics). V8 15.7 runs
//! without its compilation cache (build.zig says why), so each call was a
//! real compile: 21% of `new ReadableStream(...).values()` on the main
//! thread, and the reason gc_bench's stream-values row ran 1.128 of main's
//! time after the port. A browser never evaluates script for it: V8 names
//! the intrinsic (v8::Intrinsic::kAsyncIteratorPrototype, include/
//! v8-template.h) and Blink asks for it by that name (Chromium
//! 157.0.8103.50 third_party/blink/renderer/bindings/core/v8/
//! generated_code_helper.cc:166-206, SetupIDLIteratorTemplate).
//!
//! These tests pin the BEHAVIOUR on both sides of that fix: the object an
//! iterator's prototype inherits from is the realm's own intrinsic - the one
//! an async generator's prototype chain ends at - whichever realm made it
//! (a Window's, a worker's, and a ShadowRealm's, whose context has no realm
//! record), for every iterator, and whatever script did to the realm's
//! globals first.
//! The fix's own red test is the source check in
//! tests/infra/v8up_adapter_script_compiles_test.zig.

const std = @import("std");
const test_process = @import("test_process.zig");
const rounds_lib = @import("handle_rounds.zig");
const inline_task_loop = @import("inline_task_loop.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// "true" when an iterator of a new stream inherits, two steps up, from the
/// object an async generator's prototype chain ends at: the realm's
/// %AsyncIteratorPrototype% (ECMA-262 27.1.3).
const reaches_the_intrinsic =
    \\(() => {
    \\  const intrinsic = Object.getPrototypeOf(Object.getPrototypeOf((async function* () {}).prototype));
    \\  const iterator = new ReadableStream({ start(c) { c.close(); } }).values();
    \\  const prototype = Object.getPrototypeOf(iterator);
    \\  return String(Object.getPrototypeOf(prototype) === intrinsic && typeof prototype.next === 'function' &&
    \\    typeof iterator[Symbol.asyncIterator] === 'function' && iterator[Symbol.asyncIterator]() === iterator);
    \\})()
;

test "a Window realm: an async iterator's prototype inherits from the realm's %AsyncIteratorPrototype%, every time" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://iterators.test");
    defer page.end();
    // The first, and one made after a hundred others: the same intrinsic.
    try rounds_lib.expectEval(page.realm, reaches_the_intrinsic, "true");
    try rounds_lib.expectEval(page.realm,
        \\for (let i = 0; i < 100; i++) new ReadableStream({ start(c) { c.close(); } }).values();
        \\'ok'
    , "ok");
    try rounds_lib.expectEval(page.realm, reaches_the_intrinsic, "true");
}

test "a Window realm: two realms of one agent each give their iterators their own intrinsic" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://first.test");
    defer page.end();
    const second = try page.newRealm("https://second.test");
    defer protocol.destroyWindowRealm(second, .global_detached);

    try rounds_lib.expectEval(page.realm, reaches_the_intrinsic, "true");
    try rounds_lib.expectEval(second, reaches_the_intrinsic, "true");
    // And not each other's: the first realm's iterator, handed to the
    // second realm's script, does not inherit from the second's intrinsic.
    try rounds_lib.expectEval(page.realm,
        \\globalThis.grandparent = Object.getPrototypeOf(Object.getPrototypeOf(new ReadableStream({ start(c) { c.close(); } }).values()));
        \\'ok'
    , "ok");
    try rounds_lib.expectEval(second,
        \\String(Object.getPrototypeOf(Object.getPrototypeOf(new ReadableStream({ start(c) { c.close(); } }).values())) ===
        \\  Object.getPrototypeOf(Object.getPrototypeOf((async function* () {}).prototype)))
    , "true");
}

test "a Window realm: what script did to its globals does not change the intrinsic an iterator inherits from" {
    var page: rounds_lib.Page = undefined;
    try page.start("https://replaced.test");
    defer page.end();
    // The intrinsic, kept before script replaces what could name it.
    try rounds_lib.expectEval(page.realm,
        \\globalThis.kept = Object.getPrototypeOf(Object.getPrototypeOf((async function* () {}).prototype));
        \\globalThis.realGetPrototypeOf = Object.getPrototypeOf;
        \\Object.getPrototypeOf = () => null;
        \\Object.setPrototypeOf = () => { throw new Error('replaced'); };
        \\globalThis.Symbol = undefined;
        \\'ok'
    , "ok");
    try rounds_lib.expectEval(page.realm,
        \\String(realGetPrototypeOf(realGetPrototypeOf(new ReadableStream({ start(c) { c.close(); } }).values())) === kept)
    , "true");
}

test "a worker realm: an async iterator's prototype inherits from the worker realm's %AsyncIteratorPrototype%" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &test_process.no_hooks });
    defer protocol.destroyAgent(agent);
    const made = try v8.worker_realm.createWorkerRealm(agent, .{
        .url = "https://iterators.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.c_allocator,
    });
    defer v8.worker_realm.destroyWorkerRealm(made.realm, null, null);
    try rounds_lib.expectEval(made.realm, reaches_the_intrinsic, "true");
    try rounds_lib.expectEval(made.realm, reaches_the_intrinsic, "true");
}

/// The snapshot this build generated (build.zig passes its path): a
/// ShadowRealm's context is made from the snapshot's, so its agent must be
/// restored from it.
const snapshot_path = @import("test_snapshot").path;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

test "realms restored from the snapshot, and a ShadowRealm inside one: each iterator inherits from its own realm's %AsyncIteratorPrototype%" {
    // A ShadowRealm's global has ReadableStream ([Exposed=*]), so script in
    // it makes async iterators - and its context has NO realm record
    // (shadow_realm.zig registers it through context_manager.getOrCreate,
    // which makes none), so nothing was recorded for it when it was made.
    // The operation must still find the realm's intrinsic.
    //
    // Only the first test of a process may restore an agent from the
    // snapshot, which a ShadowRealm needs (agents_concurrent_engine_state_
    // test.zig says why): tests-v8 runs at batch 1.
    if (ffi.v8_Platform_IsInitialized()) {
        std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1)", .{});
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
    interfaces.process_hooks.startHooksForTest();

    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &test_process.no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = true,
        .timer = null,
        .origin = "https://shadow.test",
        .browser_scope = &scope,
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // A realm restored from the snapshot: the same contract. Its context
    // came out of the snapshot with nothing kept for it (the generator makes
    // no realm record and no iterator), so what it answers is its own.
    try rounds_lib.expectEval(realm, reaches_the_intrinsic, "true");
    // A second realm restored from the SAME snapshot context is another
    // realm: its iterators inherit from its intrinsic, not the first's.
    const second = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = true,
        .timer = null,
        .origin = "https://second.shadow.test",
        .browser_scope = &scope,
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(second, .global_detached);
    try rounds_lib.expectEval(second, reaches_the_intrinsic, "true");
    try rounds_lib.expectEval(realm, reaches_the_intrinsic, "true");
    // Inside a ShadowRealm, and inside a second one: each its own realm.
    const inside =
        \\String(new ShadowRealm().evaluate(`(() => {
        \\  const intrinsic = Object.getPrototypeOf(Object.getPrototypeOf((async function* () {}).prototype));
        \\  const first = new ReadableStream({ start(c) { c.close(); } }).values();
        \\  const second = new ReadableStream({ start(c) { c.close(); } }).values();
        \\  return Object.getPrototypeOf(Object.getPrototypeOf(first)) === intrinsic &&
        \\    Object.getPrototypeOf(Object.getPrototypeOf(second)) === intrinsic &&
        \\    typeof Object.getPrototypeOf(first).next === 'function';
        \\})()`))
    ;
    try rounds_lib.expectEval(realm, inside, "true");
    try rounds_lib.expectEval(realm, inside, "true");
    // And the initiator's iterators are unchanged by the ShadowRealms.
    try rounds_lib.expectEval(realm, reaches_the_intrinsic, "true");
}
