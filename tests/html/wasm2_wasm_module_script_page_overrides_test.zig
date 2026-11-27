//! Lane wasm2: a page cannot crash the engine, or be called, through an
//! `application/wasm` module script.
//!
//! Lane net-nav1's module_script.zig `createWasmModuleScript` (3aa9141a9)
//! evaluated a classic script in the page's realm that called the page's
//! `WebAssembly.Module`, `Uint8Array.fromBase64` and `JSON.stringify`, and
//! read the string that came back with unchecked unwraps (`.object`,
//! `.get("i").?`, `pair[0]`, `.string`). A page that replaced
//! `JSON.stringify` with `() => '[]'` panicked the ReleaseSafe production
//! build at its next wasm import (audit report D, finding C1). Step 1 made
//! those reads checked; step 3 removed the path (user ruling 2026-11-27,
//! option (b)): an application/wasm module script is a fetch failure, as in
//! every shipping browser, and nothing of the page's runs.
//!
//! Every case here tampers with one of the globals that path read - with a
//! function that counts its calls - imports a wasm module, and requires the
//! answer of a page that tampered with nothing: the import rejects with a
//! TypeError, none of the page's functions was called, and the page runs
//! script after it. A panic ends the test process, which the launcher
//! reports as a failure.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const loop_settle = @import("loop_settle.zig");

// (module (func (export "add") (param i32 i32) (result i32)
//   (i32.add (local.get 0) (local.get 1))))
const wasm_add = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01,
    0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01,
    0x03, 'a',  'd',  'd',  0x00, 0x00, 0x0a, 0x09,
    0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a,
    0x0b,
};

/// Serves /page.html and /add.wasm (any query) over loopback HTTP.
const WasmSite = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    fn start(allocator: std.mem.Allocator) !*WasmSite {
        const self = try allocator.create(WasmSite);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{self});
        return self;
    }

    fn stop(self: *WasmSite) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn url(self: *const WasmSite, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn acceptLoop(self: *WasmSite) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const t = std.Thread.spawn(.{}, serve, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            t.detach();
        }
    }

    fn serve(self: *WasmSite, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        var in_buf: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &in_buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            reader.interface.fillMore() catch return;
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const target = parts.next() orelse return;
        const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];

        var status: []const u8 = "200 OK";
        var content_type: []const u8 = "text/plain";
        var body: []const u8 = "";
        if (std.mem.eql(u8, path, "/page.html")) {
            content_type = "text/html";
            body =
                \\<!doctype html>
                \\<script>
                \\  window.calls = 0;
                \\  // The page's own copies, to put back after each case.
                \\  window.saved = {
                \\    stringify: JSON.stringify,
                \\    Module: WebAssembly.Module,
                \\    imports: WebAssembly.Module.imports,
                \\    exports: WebAssembly.Module.exports,
                \\    Instance: WebAssembly.Instance,
                \\    fromBase64: Uint8Array.fromBase64,
                \\    create: Object.create,
                \\  };
                \\  window.restore = () => {
                \\    JSON.stringify = saved.stringify;
                \\    WebAssembly.Module = saved.Module;
                \\    saved.Module.imports = saved.imports;
                \\    saved.Module.exports = saved.exports;
                \\    WebAssembly.Instance = saved.Instance;
                \\    Uint8Array.fromBase64 = saved.fromBase64;
                \\    Object.create = saved.create;
                \\  };
                \\  window.attempt = (n) => {
                \\    window.outcome = undefined;
                \\    import('/add.wasm?case=' + n).then(
                \\      () => { window.outcome = 'fulfilled'; },
                \\      (e) => { window.outcome = 'rejected:' + e.name; });
                \\  };
                \\</script>
            ;
        } else if (std.mem.eql(u8, path, "/add.wasm")) {
            content_type = "application/wasm";
            body = &wasm_add;
        } else {
            status = "404 Not Found";
        }

        var out_buf: [2048]u8 = undefined;
        var writer = stream.writer(std.testing.io, &out_buf);
        writer.interface.print("HTTP/1.1 {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ status, content_type, body.len }) catch return;
        writer.interface.writeAll(body) catch return;
        writer.interface.flush() catch return;
    }
};

/// Evaluate `script` in the page, discarding its completion value.
fn run(page: *browser_mod.Context, script: []const u8) !void {
    const value = try page.evaluateScriptToString(script, testing.allocator);
    testing.allocator.free(value);
}

/// Tamper with the page's globals by `tamper`, import a wasm module, wait
/// for the event loop to finish the fetch and the import, and require what a
/// page that tampered with nothing gets: a TypeError, none of the page's
/// replacements called, and a page that still runs script.
fn expectUntouched(browser: *browser_mod.Browser, page: *browser_mod.Context, n: usize, tamper: []const u8) !void {
    var buf: [1024]u8 = undefined;
    try run(page, try std.fmt.bufPrint(&buf, "window.calls = 0; {s}; attempt({d}); 'ok'", .{ tamper, n }));
    try loop_settle.settle(browser);
    try run(page, "restore(); 'ok'");

    const result = try page.evaluateScriptToString("`${window.outcome} calls=${window.calls} alive=${6 * 7}`", testing.allocator);
    defer testing.allocator.free(result);
    var expected_buf: [1100]u8 = undefined;
    var got_buf: [1100]u8 = undefined;
    // The case is in both strings, so a failure names it.
    try testing.expectEqualStrings(
        try std.fmt.bufPrint(&expected_buf, "{s}: rejected:TypeError calls=0 alive=42", .{tamper}),
        try std.fmt.bufPrint(&got_buf, "{s}: {s}", .{ tamper, result }),
    );
}

fn openPage(site: *WasmSite, browser: *browser_mod.Browser) !*browser_mod.Context {
    var url_buf: [96]u8 = undefined;
    try browser.navigate(try site.url(&url_buf, "/page.html"), .window);
    try loop_settle.settle(browser);
    return browser.current_context orelse error.NoContext;
}

test "a page that replaces JSON.stringify cannot crash the engine, or be called, through a wasm module import" {
    const site = try WasmSite.start(testing.allocator);
    defer site.stop();
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const page = try openPage(site, browser);

    // Each value is what the page's JSON.stringify returns: every shape the
    // unchecked reads of the string took for granted, broken one at a time.
    const answers = [_][]const u8{
        "'[]'",
        "'{}'",
        "'null'",
        "'\"x\"'",
        "'not json'",
        "undefined",
        "'{\"i\":{},\"e\":[]}'",
        "'{\"i\":[1],\"e\":[]}'",
        "'{\"i\":[[]],\"e\":[]}'",
        "'{\"i\":[[\"./m.js\"]],\"e\":[]}'",
        "'{\"i\":[[1,2]],\"e\":[]}'",
        "'{\"i\":[[\"./m.js\",2]],\"e\":[]}'",
        "'{\"i\":[],\"e\":{}}'",
        "'{\"i\":[],\"e\":[1]}'",
        "'{\"i\":[],\"e\":[[]]}'",
        "'{\"i\":[]}'",
        "'{\"e\":[]}'",
        "'{\"i\":[],\"e\":[],\"x\":1}'",
        "'{\"i\":[],\"i\":[],\"e\":[]}'",
        "'[' .repeat(100000)",
        "({ toString() { throw new Error('page'); } })",
        "Symbol('page')",
    };
    var buf: [256]u8 = undefined;
    for (answers, 0..) |answer, n| {
        try expectUntouched(browser, page, n, try std.fmt.bufPrint(&buf, "JSON.stringify = () => (calls++, {s})", .{answer}));
    }
    // A JSON.stringify that throws.
    try expectUntouched(browser, page, answers.len, "JSON.stringify = () => { calls++; throw new Error('page'); }");
}

test "a page that replaces WebAssembly.Module, WebAssembly.Instance, Uint8Array.fromBase64 or Object.create cannot crash the engine, or be called, through a wasm module import" {
    const site = try WasmSite.start(testing.allocator);
    defer site.stop();
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const page = try openPage(site, browser);

    const tampers = [_][]const u8{
        "WebAssembly.Module = function () { calls++; return {}; }",
        "WebAssembly.Module = undefined",
        "WebAssembly.Module = function () { calls++; throw new Error('page'); }",
        "WebAssembly.Module.imports = () => (calls++, [{ module: 1, name: {} }])",
        "WebAssembly.Module.exports = () => (calls++, [{ name: [] }])",
        "WebAssembly.Instance = function () { calls++; return { exports: null }; }",
        "Uint8Array.fromBase64 = () => (calls++, new Uint8Array(8))",
        "Uint8Array.fromBase64 = () => { calls++; throw new Error('page'); }",
        "Uint8Array.fromBase64 = undefined",
        "Object.create = () => { calls++; throw new Error('page'); }",
    };
    for (tampers, 0..) |tamper, n| {
        try expectUntouched(browser, page, 100 + n, tamper);
    }
}
