//! Direct Zig callers of `interfaces.ImageData.get_data` release the owned
//! handle it returns.
//!
//! `ImageData.get_data` returns `typedefs.ImageDataArray`, a union whose active
//! member (`uint8clamped_array` / `float16array`) is a fresh `engine.retainValue`
//! hold for the V8 binding (`conv.unionReturnIsOwned` disposes it once copied
//! to the return slot). Three direct Zig callers read `ImageData.get_data`
//! without going through the binding:
//! - `CanvasImageData.call_getImageData`
//! - `CanvasImageData.putPixels` (`putImageData`)
//! - `WindowOrWorkerGlobalScope.createImageBitmap` (`.image_data` arm)
//!
//! Without releasing the returned handle, every call leaked one 16-byte
//! `Global<Value>` (`v8_Global_Clone`, caught by macOS `leaks --atExit`:
//! 17 leaks / 272 bytes in `CanvasImageData.call_getImageData`).
//!
//! Each test warms up 64 calls, collects, reads `v8_Isolate_GetGlobalHandleBytes`,
//! runs 64 more calls, collects, and asserts 0 bytes left.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
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
            .agent_cluster_cross_origin_isolated = true,
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

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        try testing.expectEqualStrings("ok", got);
    }

    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  var p = globalThis.probe ||= (() => {
            \\    var doc = new Document().implementation.createHTMLDocument("");
            \\    var canvas = doc.createElement("canvas");
            \\    canvas.width = 4;
            \\    canvas.height = 4;
            \\    var ctx = canvas.getContext("2d");
            \\    var img = new ImageData(2, 2);
            \\    var detached = new ImageData(2, 2);
            \\    structuredClone(detached.data.buffer, { transfer: [detached.data.buffer] });
            \\    return { ctx, img, detached };
            \\  })();
            \\  var ctx = p.ctx, img = p.img, detached = p.detached;
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
            \\  }
            \\  return "ok";
            \\})()
        ;
        try self.run(loop);
        try self.collect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        try self.run(loop);
        try self.collect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        return after - before;
    }

    fn expectNoHandleLeftBy(self: Page, comptime statement: []const u8) !void {
        const left = try self.handleBytesLeftBy(statement);
        if (left > 0) {
            std.debug.print("{s}: {d} global handle bytes left over 64 calls\n", .{ statement, left });
            return error.HandleLeftPerCall;
        }
    }
};

test "ImageData.data from script releases its handle" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("void img.data");
}

test "CanvasRenderingContext2D.getImageData releases ImageData.data's handle" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("ctx.getImageData(0, 0, 2, 2)");
}

test "CanvasRenderingContext2D.putImageData releases ImageData.data's handle" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("ctx.putImageData(img, 0, 0)");
    try page.expectNoHandleLeftBy("try { ctx.putImageData(detached, 0, 0); } catch (e) {}");
}

test "createImageBitmap(ImageData) releases ImageData.data's handle" {
    const page = try Page.open();
    defer page.close();
    try page.expectNoHandleLeftBy("createImageBitmap(img)");
    try page.expectNoHandleLeftBy("createImageBitmap(detached).catch(() => {})");
}
