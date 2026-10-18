//! WebAssembly Web API 2, "compile a potential WebAssembly response", in a
//! page: the engine's WebAssembly.compileStreaming and instantiateStreaming
//! reach html/webassembly_streaming.zig (HostHooks
//! .compilePotentialWebAssemblyResponse), which checks the Response, consumes
//! its body and hands the bytes back to the engine to compile.
//!
//! Each Browser runs on a thread of its own (the file shares tests/html's
//! process, and a Browser's engine state is its thread's). The two-Browser
//! test gives each Browser its own DebugAllocator without stack traces, which
//! still fails the test on a leak: std.testing.allocator is one allocator
//! behind one lock, and would keep the two Browsers taking turns.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn startBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://wasm.test/page.html" });
    return browser;
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        const page = browser.current_context orelse return error.NoPage;
        const answer = try page.evaluateScriptToString("String(globalThis.result)", testing.allocator);
        defer testing.allocator.free(answer);
        std.debug.print("false: {s} (result: {s})\n", .{ source, answer });
        return error.ScriptAnsweredFalse;
    }
}

/// The page's script: `bytes` for (module (func (export "inc") (param i32)
/// (result i32) local.get 0 i32.const 1 i32.add)), and `settle(promise)`,
/// which records how a promise settled in `result`.
const prelude =
    \\globalThis.bytes = new Uint8Array([
    \\  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60,
    \\  0x01, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 0x03,
    \\  0x69, 0x6e, 0x63, 0x00, 0x00, 0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00,
    \\  0x41, 0x01, 0x6a, 0x0b]);
    \\globalThis.wasm = (body, type = 'application/wasm') => new Response(body, { headers: { 'Content-Type': type } });
    \\globalThis.settle = (promise) => {
    \\  globalThis.result = 'pending';
    \\  promise.then((value) => { result = value; }, (error) => { result = { error }; });
    \\};
    \\true
;

fn compileAResponse() !void {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try expectScript(browser, prelude);

    // A Response with the bytes compiles; one in a promise too.
    try expectScript(browser, "settle(WebAssembly.compileStreaming(wasm(bytes))); true");
    try waitFor(browser, "result !== 'pending'");
    try expectScript(browser, "result instanceof WebAssembly.Module");
    try expectScript(browser, "settle(WebAssembly.instantiateStreaming(Promise.resolve(wasm(bytes)))); true");
    try waitFor(browser, "result !== 'pending'");
    try expectScript(browser, "result.instance.exports.inc(1) === 2 && result.module instanceof WebAssembly.Module");
    // A stream of Uint8Array chunks is a body like any other.
    try expectScript(browser,
        \\settle(WebAssembly.compileStreaming(wasm(new ReadableStream({ start(c) {
        \\  c.enqueue(bytes.slice(0, 20)); c.enqueue(bytes.slice(20)); c.close(); } }))));
        \\true
    );
    try waitFor(browser, "result !== 'pending'");
    try expectScript(browser, "result instanceof WebAssembly.Module");
}

test "webassembly streaming: a page compiles and instantiates a module from a Response" {
    try onFreshThread(compileAResponse);
}

fn rejectTheWrongResponses() !void {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try expectScript(browser, prelude);

    const type_errors = [_][]const u8{
        // Not a Response.
        "WebAssembly.compileStreaming({})",
        "WebAssembly.instantiateStreaming(Promise.resolve(Response.prototype))",
        // No Content-Type; parameters; another type.
        "WebAssembly.compileStreaming(new Response(bytes))",
        "WebAssembly.compileStreaming(wasm(bytes, 'application/wasm;'))",
        "WebAssembly.compileStreaming(wasm(bytes, 'application/wasm;charset=UTF-8'))",
        "WebAssembly.compileStreaming(wasm(bytes, 'application/octet-stream'))",
        // Not an ok status.
        "WebAssembly.compileStreaming(new Response(bytes, { status: 404, headers: { 'Content-Type': 'application/wasm' } }))",
        // A body already read.
        "(() => { const r = wasm(bytes); r.arrayBuffer(); return WebAssembly.compileStreaming(r); })()",
        // A chunk that is not a Uint8Array.
        "WebAssembly.compileStreaming(wasm(new ReadableStream({ start(c) { c.enqueue(bytes.buffer); c.close(); } })))",
    };
    var buffer: [512]u8 = undefined;
    for (type_errors) |call| {
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "settle({s}); true", .{call}));
        try waitFor(browser, "result !== 'pending'");
        try expectScript(browser, "result.error instanceof TypeError");
    }
    // Case and surrounding tab or space do not matter.
    try expectScript(browser, "settle(WebAssembly.compileStreaming(wasm(bytes, ' APPLICATION/Wasm\\t'))); true");
    try waitFor(browser, "result !== 'pending'");
    try expectScript(browser, "result instanceof WebAssembly.Module");
    // A null body and an empty one are no module: CompileError.
    for ([_][]const u8{ "wasm(null)", "wasm('')" }) |response| {
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "settle(WebAssembly.compileStreaming({s})); true", .{response}));
        try waitFor(browser, "result !== 'pending'");
        try expectScript(browser, "result.error instanceof WebAssembly.CompileError");
    }
    // A body that errors rejects with its error.
    try expectScript(browser,
        \\globalThis.reason = new RangeError('stream');
        \\settle(WebAssembly.compileStreaming(wasm(new ReadableStream({ start(c) { c.error(reason); } }))));
        \\true
    );
    try waitFor(browser, "result !== 'pending'");
    try expectScript(browser, "result.error === reason");
}

test "webassembly streaming: a response that is not a Response, not application/wasm, not ok or already read rejects with a TypeError" {
    try onFreshThread(rejectTheWrongResponses);
}

fn leaveABodyUnsettled() !void {
    const browser = try startBrowser(testing.allocator);
    defer browser.deinit();
    try expectScript(browser, prelude);
    // The body never ends: the compilation is still waiting for it when the
    // page goes. std.testing.allocator fails the test on anything left.
    try expectScript(browser,
        \\globalThis.never = WebAssembly.compileStreaming(wasm(new ReadableStream({ start(c) { c.enqueue(bytes.slice(0, 8)); } })));
        \\globalThis.never2 = WebAssembly.instantiateStreaming(wasm(new ReadableStream({})));
        \\true
    );
    _ = try browser.runEventLoopBlocking(10);
    _ = try browser.runEventLoopBlocking(10);
}

test "webassembly streaming: a compilation whose body never ends leaves nothing behind when the Browser ends" {
    try onFreshThread(leaveABodyUnsettled);
}

const rounds = 8;
const per_round = 40;

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    /// Wait until both threads have arrived at meeting point `point` (1, 2..).
    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 50_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    shared: *Shared,
    failure: ?anyerror = null,
    /// This Browser's alone (the file's comment says why).
    debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            // Whatever happened, never leave the other side waiting.
            _ = self.shared.arrived.fetchAdd(1000, .acq_rel);
        };
        if (self.debug_allocator.deinit() == .leak and self.failure == null) self.failure = error.Leaked;
    }

    fn steps(self: *Side) !void {
        const browser = try startBrowser(self.debug_allocator.allocator());
        defer browser.deinit();
        try expectScript(browser, prelude);
        var buffer: [1024]u8 = undefined;
        for (0..rounds) |round| {
            // Both Browsers start their round's compilations together.
            try self.shared.meet(@intCast(round + 1));
            try expectScript(browser, try std.fmt.bufPrint(&buffer,
                \\globalThis.done = -1;
                \\Promise.all(Array.from({{ length: {d} }}, (_, i) => i % 2
                \\  ? WebAssembly.compileStreaming(wasm(bytes))
                \\  : WebAssembly.instantiateStreaming(wasm(new ReadableStream({{ start(c) {{
                \\      c.enqueue(bytes.slice(0, 9)); c.enqueue(bytes.slice(9)); c.close(); }} }}))))).then(
                \\  (results) => {{ done = results.filter((r) => r instanceof WebAssembly.Module || r.instance.exports.inc(1) === 2).length; }},
                \\  (e) => {{ done = -2; globalThis.failure = String(e); }});
                \\true
            , .{per_round}));
            try waitFor(browser, "done !== -1");
            try expectScript(browser, try std.fmt.bufPrint(&buffer, "done === {d}", .{per_round}));
        }
    }
};

test "webassembly streaming: two Browsers on two threads compile streamed modules at once" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .shared = &shared }, .{ .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
