//! An `application/wasm` module script is a fetch failure, as in every
//! shipping browser (user ruling 2026-11-27 5:31 PM ET, option (b), lane
//! wasm2; the evidence is at module_script.zig createFromResponse, HTML
//! "fetch a single module script" step 6): a `<script type=module>` whose
//! source or static import is a .wasm response fires `error` and runs no
//! WebAssembly start function, and import() of one rejects with a
//! TypeError - whatever the bytes, and in a worker too.
//!
//! This file first tested lane net-nav1's JS-source shim (3aa9141a9), which
//! ran a script in the page's realm to make ES module records for Wasm and
//! could panic the engine (lane wasm2 step 1); the shim is gone.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const loop_settle = @import("loop_settle.zig");

// (module (func (export "add") (param i32 i32) (result i32) (i32.add (local.get 0) (local.get 1))))
const wasm_add = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01,
    0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01,
    0x03, 'a',  'd',  'd',  0x00, 0x00, 0x0a, 0x09,
    0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a,
    0x0b,
};

// (module
//   (import "./env.js" "mul" (func $mul (param i32 i32) (result i32)))
//   (func (export "double") (param i32) (result i32) (call $mul (local.get 0) (i32.const 2))))
const wasm_import_js = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x0c, 0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01,
    0x7f, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x02, 0x10,
    0x01, 0x08, '.',  '/',  'e',  'n',  'v',  '.',
    'j',  's',  0x03, 'm',  'u',  'l',  0x00, 0x00,
    0x03, 0x02, 0x01, 0x01, 0x07, 0x0a, 0x01, 0x06,
    'd',  'o',  'u',  'b',  'l',  'e',  0x00, 0x01,
    0x0a, 0x0a, 0x01, 0x08, 0x00, 0x20, 0x00, 0x41,
    0x02, 0x10, 0x00, 0x0b,
};

// (module
//   (import "./add.wasm" "add" (func $add (param i32 i32) (result i32)))
//   (func (export "inc") (param i32) (result i32) (call $add (local.get 0) (i32.const 1))))
const wasm_import_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x0c, 0x02, 0x60, 0x02, 0x7f, 0x7f, 0x01,
    0x7f, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x02, 0x12,
    0x01, 0x0a, '.',  '/',  'a',  'd',  'd',  '.',
    'w',  'a',  's',  'm',  0x03, 'a',  'd',  'd',
    0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x07, 0x07,
    0x01, 0x03, 'i',  'n',  'c',  0x00, 0x01, 0x0a,
    0x0a, 0x01, 0x08, 0x00, 0x20, 0x00, 0x41, 0x01,
    0x10, 0x00, 0x0b,
};

// (module
//   (import "./sink.js" "mark" (func $mark))
//   (start $mark))
const wasm_start = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x04, 0x01, 0x60, 0x00, 0x00, 0x02, 0x12,
    0x01, 0x09, '.',  '/',  's',  'i',  'n',  'k',
    '.',  'j',  's',  0x04, 'm',  'a',  'r',  'k',
    0x00, 0x00, 0x08, 0x01, 0x00,
};

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
        const path = parts.next() orelse return;

        var content_type: []const u8 = "text/plain";
        var body: []const u8 = "";

        if (std.mem.eql(u8, path, "/page.html")) {
            content_type = "text/html";
            body =
                \\<!doctype html>
                \\<script>window.events = [];</script>
                \\<script type="module" src="/start.wasm" onload="events.push('start:load')" onerror="events.push('start:error')"></script>
                \\<script type="module" onerror="events.push('static:error')">
                \\  import { add } from './add.wasm';
                \\  import { double as dbl } from './import_js.wasm';
                \\  import { inc } from './import_wasm.wasm';
                \\  window.staticResult = `${add(20, 22)}:${dbl(21)}:${inc(41)}`;
                \\</script>
                \\<script type="module">window.plainModuleRan = true;</script>
            ;
        } else if (std.mem.eql(u8, path, "/worker.js")) {
            content_type = "text/javascript";
            body = "import('/add.wasm').then(() => postMessage('fulfilled'), (e) => postMessage('rejected:' + e.name));";
        } else if (std.mem.eql(u8, path, "/add.wasm")) {
            content_type = "application/wasm";
            body = &wasm_add;
        } else if (std.mem.eql(u8, path, "/import_js.wasm")) {
            content_type = "application/wasm";
            body = &wasm_import_js;
        } else if (std.mem.eql(u8, path, "/import_wasm.wasm")) {
            content_type = "application/wasm";
            body = &wasm_import_wasm;
        } else if (std.mem.eql(u8, path, "/start.wasm")) {
            content_type = "application/wasm";
            body = &wasm_start;
        } else if (std.mem.eql(u8, path, "/env.js")) {
            content_type = "text/javascript";
            body = "export function mul(a, b) { return a * b; }";
        } else if (std.mem.eql(u8, path, "/sink.js")) {
            content_type = "text/javascript";
            body = "export function mark() { window.startRan = (window.startRan || 0) + 1; }";
        } else if (std.mem.eql(u8, path, "/invalid.wasm")) {
            content_type = "application/wasm";
            body = "not-valid-wasm";
        } else if (std.mem.eql(u8, path, "/wrong-mime.wasm")) {
            content_type = "application/octet-stream";
            body = &wasm_add;
        }

        var out_buf: [2048]u8 = undefined;
        var writer = stream.writer(std.testing.io, &out_buf);
        writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n", .{ content_type, body.len }) catch return;
        writer.interface.writeAll(body) catch return;
        writer.interface.flush() catch return;
    }
};

test "a wasm module script is a fetch failure: script src and static imports fire error, import() rejects with TypeError, in a worker too" {
    const site = try WasmSite.start(testing.allocator);
    defer site.stop();

    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();

    var url_buf: [96]u8 = undefined;
    try browser.navigate(try site.url(&url_buf, "/page.html"), .window);
    const page = browser.current_context orelse return error.NoContext;

    // The plain module after them runs; the two whose graph has a .wasm
    // response fire error, and nothing of theirs ran: no start function
    // (sink.js's mark), no body.
    try loop_settle.settle(browser);
    const static = try page.evaluateScriptToString("[...events].sort().join() + '|' + window.plainModuleRan + '|' + typeof window.staticResult + '|' + typeof window.startRan", testing.allocator);
    defer testing.allocator.free(static);
    try testing.expectEqualStrings("start:error,static:error|true|undefined|undefined", static);

    // import() of a valid module, of invalid bytes and of the wrong MIME
    // type all reject with a TypeError: none of them is compiled. The
    // worker is ended once it has answered: a live worker is pending work,
    // and the loop would not go idle until settle's bound.
    const kick = try page.evaluateScriptToString(
        \\(async () => {
        \\  const name = (p) => import(p).then(() => 'fulfilled', (e) => e.name);
        \\  window.dynResult = `${await name('/add.wasm')}:${await name('/invalid.wasm')}:${await name('/wrong-mime.wasm')}`;
        \\  const worker = new Worker('/worker.js');
        \\  worker.onmessage = (e) => { window.workerResult = e.data; worker.terminate(); };
        \\})(); 'ok'
    , testing.allocator);
    testing.allocator.free(kick);

    try loop_settle.settle(browser);
    const dyn = try page.evaluateScriptToString("window.dynResult + '|' + window.workerResult", testing.allocator);
    defer testing.allocator.free(dyn);
    try testing.expectEqualStrings("TypeError:TypeError:TypeError|rejected:TypeError", dyn);
}
