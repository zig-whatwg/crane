//! WebAssembly memory and table descriptors name their address type
//! `address` (WebAssembly JS API, the Memory and Table constructors:
//! `descriptor["address"]`, an AddressType of "i32" or "i64", with `initial`
//! and `maximum` as AddressValues - BigInts for "i64").
//!
//! The V8 Crane links (13.1.203) predates that name: its wasm-js.cc
//! (GetIndexType) reads the memory64 proposal's earlier `index` member, so
//! `{address: "i64", initial: 10n}` was an i32 descriptor and ToNumber(10n)
//! threw "Cannot convert a BigInt value to a number". The wasm/core harness
//! (async_index.js, reinitializeRegistry) builds such a table before every
//! file, so every wasm/core file failed its first step and everything after
//! it. The adapter replaces WebAssembly.Memory and WebAssembly.Table in
//! every realm it makes (v8_WebAssembly_InstallAddressDescriptors) with
//! constructors that read `address` and hand V8 the `index` it knows.
//! DELETE these tests' shim-specific cases with the shim, at V8 >= 13.3.
//!
//! What must not change with the replacement: the interface objects' own
//! properties and attributes, the prototype objects (one per realm, the one
//! V8's exported memories and tables use), new.target for subclasses, and
//! every other argument.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered. The i64 MODULE case needs
//! --experimental-wasm-memory64 (RUNTIME_V8_FLAGS), which V8 honours only
//! when the process started it with those flags - as a host does, and as
//! this file does when it is the first to start V8 (-Dtest-file=,
//! -Dtest-isolation=file). The snapshot case runs only then too
//! (pattern_attribute_snapshot_test.zig says why).

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");

const loader = v8.snapshot_loader;
const snapshot_path = "zig-out/bin/whatwg_snapshot.bin";

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const no_hooks: protocol.HostHooks = .{};

/// Whether V8 was not yet started in this process when this file first
/// asked: decided once, by the first test here.
var first_in_process: ?bool = null;
var pools_ready = false;

fn noteFirst() void {
    if (first_in_process == null) first_in_process = !ffi.v8_Platform_IsInitialized();
}

fn setup() !void {
    noteFirst();
    try protocol.initializeEngine(.{});
    preparePools();
}

fn preparePools() void {
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

fn windowRealm(agent: *protocol.Agent, from_snapshot: bool) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// `source`'s completion value in `realm`, as a string; nothing reported.
fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
    defer std.testing.allocator.free(got);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqualStrings(expected, got);
}

/// The script every realm runs: "ok", or the checks that failed.
const prelude =
    \\const fails = [];
    \\const check = (cond, what) => { if (!cond) fails.push(what); };
    \\const throwsType = (f) => { try { f(); return false; } catch (e) { return e instanceof TypeError; } };
    \\const verdict = () => fails.length ? fails.join("; ") : "ok";
;

/// What the wasm/core harness needs, in any realm: an i64 table and memory
/// built from `address` and BigInt limits.
const address_i64_checks = prelude ++
    \\(() => {
    \\  let table;
    \\  try {
    \\    table = new WebAssembly.Table({ initial: 10n, maximum: 20n, element: "anyfunc", address: "i64" });
    \\  } catch (e) { fails.push("i64 table: " + e); }
    \\  check(table instanceof WebAssembly.Table, "i64 table is a Table");
    \\  let memory;
    \\  try {
    \\    memory = new WebAssembly.Memory({ initial: 1n, maximum: 2n, address: "i64" });
    \\  } catch (e) { fails.push("i64 memory: " + e); }
    \\  check(memory instanceof WebAssembly.Memory, "i64 memory is a Memory");
    \\  check(memory && memory.buffer.byteLength === 65536, "i64 memory has one page");
    \\  check(memory && memory.grow(1n) === 1n, "i64 memory grows by a BigInt and answers one");
    \\  return verdict();
    \\})()
;

test "flags: the i64 address type's modules are enabled where V8 runs and where the snapshot is made" {
    // V8 13.1 has memory64 behind --experimental-wasm-memory64 (it ships in
    // 13.3); without it a module declaring an i64 memory or table is a
    // CompileError. The snapshot generator gets every runtime flag.
    try std.testing.expect(std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--experimental-wasm-memory64") != null);
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--experimental-wasm-memory64") != null);
}

test "flags: WebAssembly's exnref exception handling is enabled where V8 runs and where the snapshot is made" {
    // try_table, throw_ref and the exnref type (Wasm 3.0) are behind
    // --experimental-wasm-exnref in V8 13.1; without it those modules are
    // CompileErrors ("invalid value type 'exn'") - wasm/core/exceptions/.
    try std.testing.expect(std.mem.indexOf(u8, loader.RUNTIME_V8_FLAGS, "--experimental-wasm-exnref") != null);
    try std.testing.expect(std.mem.indexOf(u8, loader.SNAPSHOT_V8_FLAGS, "--experimental-wasm-exnref") != null);
}

test "snapshot realm: a Window realm restored from Crane's snapshot takes address i64" {
    noteFirst();
    if (!first_in_process.?) {
        std.log.warn("skipping: V8 was started in this process before this file; run it with -Dtest-file= or -Dtest-isolation=file", .{});
        return error.SkipZigTest;
    }
    const io = std.testing.io;
    const file = std.Io.Dir.cwd().openFile(io, snapshot_path, .{}) catch |err| {
        std.log.warn("skipping: no snapshot at {s} ({s}); `zig build snapshot` makes it", .{ snapshot_path, @errorName(err) });
        return error.SkipZigTest;
    };
    defer file.close(io);
    const size = (try file.stat(io)).size;
    const bytes = try std.heap.c_allocator.alloc(u8, size);
    defer std.heap.c_allocator.free(bytes);
    _ = try file.readPositionalAll(io, bytes, 0);

    try protocol.initializeEngine(.{ .snapshot = bytes });
    defer protocol.deinitializeEngine();
    preparePools();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    // Restored, not made afresh (createAgent falls back to a fresh isolate,
    // with a warning, when the snapshot does not restore).
    if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
    const realm = try windowRealm(agent, true);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectEval(realm, "typeof Window === 'function' && globalThis instanceof Window", "true");
    try expectEval(realm, address_i64_checks, "ok");
}

test "window realm: Table and Memory take address i64 with BigInt limits" {
    try setup();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, false);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectEval(realm, address_i64_checks, "ok");
}

test "window realm: the address member is converted first, as an AddressType" {
    try setup();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, false);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectEval(realm, prelude ++
        \\(() => {
        \\  check(throwsType(() => new WebAssembly.Table({ initial: 1, element: "anyfunc", address: "i65" })), "unknown address type: TypeError");
        \\  check(throwsType(() => new WebAssembly.Memory({ initial: 1, address: "I64" })), "address is case-sensitive");
        \\  check(throwsType(() => new WebAssembly.Table({ initial: 10, element: "anyfunc", address: "i64" })), "i64 initial must be a BigInt");
        \\  check(throwsType(() => new WebAssembly.Memory({ initial: -1n, address: "i64" })), "i64 initial below 0");
        \\  check(new WebAssembly.Table({ initial: 3, element: "anyfunc", address: "i32" }).length === 3, "address i32");
        \\  check(new WebAssembly.Table({ initial: 2, element: "anyfunc" }).length === 2, "no address is i32");
        \\  check(new WebAssembly.Memory({ initial: 1, address: { toString() { return "i32"; } } }).buffer.byteLength === 65536, "address is ToString'd");
        \\  check(throwsType(() => new WebAssembly.Memory({ initial: 1n, index: "i64" })), "the pre-rename `index` member is no member");
        \\
        \\  // WebIDL dictionary members convert in lexicographic order, each
        \\  // read then converted before the next.
        \\  const order = [];
        \\  const logged = (name, value) => ({
        \\    get() { order.push(name); return { toString() { order.push(name + " toString"); return value; }, valueOf() { order.push(name + " valueOf"); return value; } }; },
        \\  });
        \\  new WebAssembly.Table(Object.defineProperties({}, {
        \\    maximum: logged("maximum", 2), initial: logged("initial", 1),
        \\    element: logged("element", "anyfunc"), address: logged("address", "i32"),
        \\  }));
        \\  check(order.join() === "address,address toString,element,element toString,initial,initial valueOf,maximum,maximum valueOf", "Table order: " + order.join());
        \\  order.length = 0;
        \\  new WebAssembly.Memory(Object.defineProperties({}, {
        \\    maximum: logged("maximum", 2), initial: logged("initial", 1), address: logged("address", "i32"),
        \\  }));
        \\  check(order.join() === "address,address toString,initial,initial valueOf,maximum,maximum valueOf", "Memory order: " + order.join());
        \\  order.length = 0;
        \\  check(throwsType(() => new WebAssembly.Table(Object.defineProperties({}, {
        \\    element: logged("element", "anyfunc"), initial: logged("initial", 1), address: logged("address", "i65"),
        \\  }))), "a bad address throws");
        \\  check(order.join() === "address,address toString", "a bad address throws before element is read: " + order.join());
        \\
        \\  // Not a dictionary: a TypeError, as before.
        \\  check(throwsType(() => new WebAssembly.Memory()), "no descriptor");
        \\  check(throwsType(() => new WebAssembly.Table(1)), "a number descriptor");
        \\  return verdict();
        \\})()
    , "ok");
}

test "window realm: the interface objects keep their identity, attributes, prototypes and new.target" {
    try setup();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, false);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectEval(realm, prelude ++
        \\(() => {
        \\  for (const [name, args] of [["Memory", [{ initial: 1 }]], ["Table", [{ initial: 1, element: "anyfunc" }]]]) {
        \\    const C = WebAssembly[name];
        \\    const own = Object.getOwnPropertyDescriptor(WebAssembly, name);
        \\    check(own.value === C && own.writable && !own.enumerable && own.configurable, name + " on the namespace: writable, configurable, not enumerable");
        \\    const proto = Object.getOwnPropertyDescriptor(C, "prototype");
        \\    check(typeof proto.value === "object" && !proto.writable && !proto.enumerable && !proto.configurable, name + ".prototype: not writable, enumerable or configurable");
        \\    const ctor = Object.getOwnPropertyDescriptor(C.prototype, "constructor");
        \\    check(ctor.value === C && ctor.writable && !ctor.enumerable && ctor.configurable, name + ".prototype.constructor");
        \\    const length = Object.getOwnPropertyDescriptor(C, "length");
        \\    check(length.value === 1 && !length.writable && !length.enumerable && length.configurable, name + ".length");
        \\    const fname = Object.getOwnPropertyDescriptor(C, "name");
        \\    check(fname.value === name && !fname.writable && !fname.enumerable && fname.configurable, name + ".name");
        \\    check(Object.getPrototypeOf(C) === Function.prototype, name + "'s [[Prototype]]");
        \\    check(/^function \w*\(\) \{\s*\[native code\]\s*\}$/.test(Function.prototype.toString.call(C)), name + " is native code: " + Function.prototype.toString.call(C));
        \\    check(Object.getPrototypeOf(new C(...args)) === C.prototype, "new " + name + "'s prototype");
        \\    check(new C(...args) instanceof C, "new " + name + " instanceof");
        \\    check(throwsType(() => C(...args)), name + " without new");
        \\    check(Object.getPrototypeOf(C.prototype) === Object.prototype, name + ".prototype's [[Prototype]]");
        \\    check(typeof C.prototype.grow === "function", name + ".prototype keeps its members");
        \\
        \\    // new.target: a subclass's instances have the subclass's prototype.
        \\    class Sub extends C { extra() { return 42; } }
        \\    const sub = new Sub(...args);
        \\    check(Object.getPrototypeOf(sub) === Sub.prototype, "a subclass of " + name + " gets its prototype");
        \\    check(sub instanceof C && sub.extra() === 42, "a subclass of " + name + " is one");
        \\    function Other() {}
        \\    Other.prototype = Object.create(C.prototype);
        \\    check(Object.getPrototypeOf(Reflect.construct(C, args, Other)) === Other.prototype, "Reflect.construct with another new.target (" + name + ")");
        \\  }
        \\  const sub = new (class extends WebAssembly.Memory {})({ initial: 1 });
        \\  check(sub.buffer.byteLength === 65536 && sub.grow(1) === 1, "a Memory subclass's instance is a working memory");
        \\
        \\  // Every argument reaches V8: a Table's initial value.
        \\  const value = {};
        \\  const table = new WebAssembly.Table({ element: "externref", initial: 2 }, value);
        \\  check(table.get(0) === value && table.get(1) === value, "Table's value argument");
        \\
        \\  // Memories and tables V8 makes itself use the same prototypes:
        \\  // (module (memory (export "m") 1) (table (export "t") 1 funcref))
        \\  const bytes = new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0,
        \\    0x04, 0x04, 0x01, 0x70, 0x00, 0x01,
        \\    0x05, 0x03, 0x01, 0x00, 0x01,
        \\    0x07, 0x09, 0x02, 0x01, 0x6d, 0x02, 0x00, 0x01, 0x74, 0x01, 0x00]);
        \\  const { exports } = new WebAssembly.Instance(new WebAssembly.Module(bytes));
        \\  check(exports.m instanceof WebAssembly.Memory && exports.m.constructor === WebAssembly.Memory, "an exported memory is a Memory");
        \\  check(exports.t instanceof WebAssembly.Table && exports.t.constructor === WebAssembly.Table, "an exported table is a Table");
        \\  return verdict();
        \\})()
    , "ok");
}

test "frame and worker realms: Table and Memory take address i64" {
    try setup();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const parent = try windowRealm(agent, false);
    defer protocol.destroyWindowRealm(parent, .global_detached);
    var frame_realm: FrameRealm = .{ .agent = agent, .parent = parent };
    try protocol.runInRealm(parent, FrameRealm.steps, &frame_realm);
    if (frame_realm.failed) |err| return err;
    const frame = frame_realm.made.?;
    defer protocol.destroyWindowRealm(frame, .global_detached);
    try expectEval(frame, address_i64_checks, "ok");
    // Each realm has its own interface objects and prototypes.
    try expectEval(frame, "WebAssembly.Memory.prototype.constructor === WebAssembly.Memory", "true");

    const worker_agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(worker_agent);
    const worker = try protocol.createWorkerRealm(worker_agent, &.{
        .url = "https://example.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.page_allocator,
    });
    defer protocol.destroyWorkerRealm(worker.realm, null, null);
    try expectEval(worker.realm, address_i64_checks, "ok");
}

test "window realm: a module declaring an i64 memory or table compiles" {
    try setup();
    if (!first_in_process.?) {
        std.log.warn("skipping: V8 was started in this process before this file, with flags this file did not choose; run it with -Dtest-file= or -Dtest-isolation=file", .{});
        return error.SkipZigTest;
    }
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, false);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // (module (memory i64 1)) and (module (table i64 1 funcref)): limits
    // flag 0x04 is the i64 address type.
    try expectEval(realm,
        \\const memory64 = new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0, 0x05, 0x03, 0x01, 0x04, 0x01]);
        \\const table64 = new Uint8Array([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0, 0x04, 0x04, 0x01, 0x70, 0x04, 0x01]);
        \\[WebAssembly.validate(memory64), WebAssembly.validate(table64),
        \\ new WebAssembly.Module(memory64) instanceof WebAssembly.Module].join()
    , "true,true,true");
}

/// A frame's Window realm, made as a frame's is: inside its parent's script.
const FrameRealm = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn steps(data: ?*anyopaque) void {
        const self: *FrameRealm = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};
