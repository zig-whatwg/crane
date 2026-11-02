//! A constructor that fails releases the receiver V8 made for it.
//!
//! The binding's constructorCallback takes `info.getThis()` - a Global<Object>
//! the caller owns - and hands it to the wrapper cache once the instance is
//! bound to it (`WrapperCache.set` keeps that exact handle as the entry's
//! wrapper). Every exit that never reached the cache kept it instead: both
//! returns of `callConstructorWithArgs(...) catch` - an argument conversion
//! that threw (ExceptionPending) and an impl that failed (the WebIDL error
//! the binding throws) - so each failing `new X(...)`, of any interface, left
//! one 16-byte Global<Object> and the object it holds alive for the agent's
//! life (Codex row 14 Q16: `leaks --atExit` named
//! constructorCallback -> v8_FunctionCallbackInfo_This; gc_bench read 1.00
//! live_object_globals per failed `new Event(...)`).
//!
//! Each test runs one failing construction 64 times and reads the live
//! Global<Object> count (v8_Debug_LiveObjectGlobals) before and after.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

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

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
}

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    /// `source`'s completion value as a string; nothing reported.
    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }

    /// Runs `source` - which answers "64" when each of its 64 constructions
    /// failed as it should - once to warm up (the first call makes what
    /// later ones reuse), then again, and fails when the second run left
    /// live Global<Object> handles behind, or platform objects in the slab
    /// the realm's objects come from (the standalone runtime's: the page has
    /// no Browser). A construction that failed returned no object to the
    /// binding, so nothing else can ever free the one it made: its failure
    /// path frees it whole (docs/lessons/architecture-an-interfaces-deinit-
    /// is-a-destructor-not-a-free.md).
    fn expectNoReceiverLeft(self: Page, source: []const u8) !void {
        try self.expect(source, "64");
        const before = ffi.v8_Debug_LiveObjectGlobals();
        const objects_before = liveObjects();
        try self.expect(source, "64");
        const after = ffi.v8_Debug_LiveObjectGlobals();
        const objects_after = liveObjects();
        if (after != before) {
            std.debug.print("live_object_globals {d} -> {d} over 64 failed constructions\n", .{ before, after });
            return error.ReceiverLeaked;
        }
        if (objects_after != objects_before) {
            std.debug.print("platform objects {d} -> {d} over 64 failed constructions\n", .{ objects_before, objects_after });
            return error.InstanceLeaked;
        }
    }
};

/// The platform objects live in the standalone runtime's slab, which the
/// test's realm (no Browser) makes its objects in.
fn liveObjects() usize {
    const scope = runtime.BrowserScope.standalone() orelse return 0;
    return scope.slab.stats().currently_allocated;
}

test "a constructor whose argument conversion throws releases its receiver" {
    const page = try Page.open();
    defer page.close();
    // The dictionary member's getter throws while the binding converts the
    // arguments: ExceptionPending, and that exception is what script sees.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new Event('x', { get bubbles() { throw 7; } }); } catch (e) { if (e === 7) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a constructor whose impl fails releases its receiver" {
    const page = try Page.open();
    defer page.close();
    // The arguments convert; URL's constructor steps fail to parse and the
    // binding throws the TypeError.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new URL('not a url'); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

// Constructor steps that fail after the impl made its object: the object
// never reached the binding, so the failure path is its only owner. Each of
// these used to run the impl's own deinit - a destructor, not a free - and
// leave the object's slot and state block in the slab until the Browser
// ended (tests-v8's state survey, lane v8state1: 128 objects a run of the
// URL test above).

test "a URL constructor whose base fails to parse frees what it made" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new URL('a', 'not a base'); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "an ImageData constructor that throws an IndexSizeError frees what it made" {
    const page = try Page.open();
    defer page.close();
    // Zero width (constructor 1, step 1), and a data length that is no
    // multiple of the width (constructor 2, step 5).
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new ImageData(0, 1); } catch (e) { if (e.name === 'IndexSizeError') n++; }
        \\    try { new ImageData(new Uint8ClampedArray(8), 3); } catch (e) { if (e.name === 'IndexSizeError') n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a URLPattern constructor whose pattern does not compile frees what it made" {
    const page = try Page.open();
    defer page.close();
    // An unbalanced group is a TypeError of the constructor string's parse;
    // a dictionary with a separate base, one of the create steps.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new URLPattern('(', 'https://example.test'); } catch (e) { if (e instanceof TypeError) n++; }
        \\    try { new URLPattern({}, 'https://example.test'); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a Blob constructor whose parts are no sequence frees what it made" {
    const page = try Page.open();
    defer page.close();
    // The sequence<BlobPart> conversion runs in the constructor steps (FileAPI
    // "process blob parts" takes the converted value): not an Object is a
    // TypeError (WebIDL 3.2.21 step 1), and so is no @@iterator (step 3).
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new Blob('abc'); } catch (e) { if (e instanceof TypeError) n++; }
        \\    try { new Blob({ length: 1, 0: 'a' }); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a Worker or SharedWorker constructor whose script URL does not parse frees what it made" {
    const page = try Page.open();
    defer page.close();
    // HTML's Worker constructor step 4 and SharedWorker's step 5: a URL that
    // fails to encoding-parse is a "SyntaxError" DOMException.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new Worker('https://['); } catch (e) { if (e.name === 'SyntaxError') n++; }
        \\    try { new SharedWorker('https://['); } catch (e) { if (e.name === 'SyntaxError') n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a Response constructor that rejects its init frees what it made" {
    const page = try Page.open();
    defer page.close();
    // Fetch "initialize a response": a status outside 200-599 is a
    // RangeError (step 1), a body for a null body status a TypeError (step 6).
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 32; i++) {
        \\    try { new Response('', { status: 99 }); } catch (e) { if (e instanceof RangeError) n++; }
        \\    try { new Response('body', { status: 204 }); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "Response.json() whose init is rejected frees the response it made" {
    const page = try Page.open();
    defer page.close();
    // Response.json's step 4 is "initialize a response", after step 3 made
    // the response object.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { Response.json({ a: 1 }, { status: 99 }); } catch (e) { if (e instanceof RangeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a constructor that succeeds still hands its receiver to the wrapper cache" {
    const page = try Page.open();
    defer page.close();
    // The successful path keeps its handoff: the receiver is the result, its
    // instance bound, its identity and expandos kept across a collection.
    try page.expect(
        \\globalThis.kept = new Event('ok');
        \\kept.expando = 5;
        \\try { new Event('x', { get bubbles() { throw 7; } }); } catch (e) {}
        \\try { new URL('not a url'); } catch (e) {}
        \\String(kept.type === 'ok' && kept.expando === 5 && kept instanceof Event)
    , "true");
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    try protocol.runInRealm(page.realm, Collect.steps, page.agent);
    try page.expect("String(kept.type === 'ok' && kept.expando === 5)", "true");
}
