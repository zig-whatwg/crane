//! A WebSocket's 64 KiB receive scratch (the impl's `recv_buffer`) is the
//! pump's while the connection can still deliver messages, and goes back
//! once the connection reaches CLOSED - not when script lets go of the
//! socket and a collection ends it, which kept 64 KiB for every closed
//! socket awaiting a GC (lane net3: 260 closed sockets held 16.6 MB of
//! written memory, chat.local memdiag5, 2026-11-20).
const std = @import("std");
const Browser = @import("browser").Browser;
const engine = @import("engine");
const Server = @import("pv1_socket_server.zig").Server;

/// The scratch's size (src/webidl/impls/WebSocket.zig RECV_BUFFER_SIZE).
const scratch_len = 64 * 1024;

/// Counts the live allocations of exactly `scratch_len` bytes, forwarding
/// everything to `child`. Atomic: the Browser allocates on more than one
/// thread.
const Counting = struct {
    child: std.mem.Allocator,
    live: std.atomic.Value(usize) = .init(0),

    fn allocator(self: *Counting) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawAlloc(len, alignment, ret) orelse return null;
        if (len == scratch_len) _ = self.live.fetchAdd(1, .acq_rel);
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) bool {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        if (!self.child.rawResize(memory, alignment, new_len, ret)) return false;
        self.moved(memory.len, new_len);
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) ?[*]u8 {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        const ptr = self.child.rawRemap(memory, alignment, new_len, ret) orelse return null;
        self.moved(memory.len, new_len);
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Counting = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ret);
        if (memory.len == scratch_len) _ = self.live.fetchSub(1, .acq_rel);
    }

    fn moved(self: *Counting, old_len: usize, new_len: usize) void {
        if (old_len == scratch_len) _ = self.live.fetchSub(1, .acq_rel);
        if (new_len == scratch_len) _ = self.live.fetchAdd(1, .acq_rel);
    }
};

fn run(browser: *Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn waitFor(browser: *Browser, source: []const u8) !void {
    for (0..500) |_| {
        const held = try browser.evaluateScript(source);
        const yes = engine.toBoolean(browser.getRealm().?, held.borrow());
        held.release();
        if (yes) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.SocketTimedOut;
}

test "a WebSocket gives its receive scratch back when it reaches CLOSED, while script still holds the socket" {
    var counting: Counting = .{ .child = std.testing.allocator };
    var server: Server = undefined;
    try server.start();
    defer server.stop();
    const browser = try Browser.init(counting.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const page_url = "http://127.0.0.1/net3-scratch.html";
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    try browser.current_context.?.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });

    const before = counting.live.load(.acquire);
    var url: [128]u8 = undefined;
    var script: [512]u8 = undefined;
    try run(browser, try std.fmt.bufPrint(&script,
        \\globalThis.echoes=[]; globalThis.closed=false;
        \\globalThis.socket=new WebSocket('{s}');
        \\socket.onmessage=e=>echoes.push(e.data); socket.onclose=()=>closed=true;
    , .{try server.url(&url)}));
    try waitFor(browser, "socket.readyState===WebSocket.OPEN");
    try run(browser, "socket.send('net3')");
    try waitFor(browser, "echoes[0]==='net3'");
    // The pump received through its scratch: one more live 64 KiB block.
    try std.testing.expectEqual(before + 1, counting.live.load(.acquire));

    try run(browser, "socket.close(1000)");
    try waitFor(browser, "closed && socket.readyState===WebSocket.CLOSED");
    // `globalThis.socket` keeps the wrapper (and its state) alive: the scratch
    // must be gone all the same.
    try std.testing.expectEqual(before, counting.live.load(.acquire));
    try std.testing.expectEqual(@as(u16, 1000), server.close_code.load(.acquire));
}
