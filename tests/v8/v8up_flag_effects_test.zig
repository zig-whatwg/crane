//! What each V8 flag Crane ever set was FOR, checked by its effect in a
//! running agent rather than by the flag's text: V8::SetFlagsFromString
//! ignores every flag after the first one it does not know (flags.cc:771 at
//! 15.7.112.43), so a flag string can look right and do nothing.
//!
//! --harmony-shadow-realm is still a flag in 15.7 (feature-flags.h, the
//! experimental list); Float16Array, Wasm memory64, Wasm exnref and JSPI
//! shipped and lost theirs (lane v8up, tmp/plans/v8-update-plan.md 2.2 S5).

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const no_hooks: protocol.HostHooks = .{};

/// A script error fails the test through the answer it leaves (the empty string), not here.
fn reportNothing(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
    _ = host;
    std.debug.print("reported: {s}\n", .{info.message});
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
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

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = reportNothing });
        defer std.testing.allocator.free(got);
        try std.testing.expectEqualStrings(expected, got);
    }
};

test "ShadowRealm (--harmony-shadow-realm) is installed" {
    const page = try Page.open();
    defer page.close();
    try page.expect("typeof ShadowRealm", "function");
}

test "Float16Array, Math.f16round and DataView float16 are installed (shipped in V8 13.5)" {
    const page = try Page.open();
    defer page.close();
    try page.expect("[typeof Float16Array, typeof Math.f16round, typeof DataView.prototype.getFloat16].join()", "function,function,function");
}

test "WebAssembly validates an i64 memory (memory64, shipped in V8 13.3)" {
    const page = try Page.open();
    defer page.close();
    // A memory section with one memory whose limits flags are 0x04 (i64 index, no maximum), minimum 1.
    try page.expect("String(WebAssembly.validate(new Uint8Array([0,97,115,109,1,0,0,0,5,3,1,4,1])))", "true");
}

test "WebAssembly validates an exnref global (exception handling with exnref, shipped in V8 13.7)" {
    const page = try Page.open();
    defer page.close();
    // A global section with one immutable global of type exnref (0x69) set to ref.null exn.
    try page.expect("String(WebAssembly.validate(new Uint8Array([0,97,115,109,1,0,0,0,6,6,1,0x69,0,0xd0,0x69,0x0b])))", "true");
}

test "JSPI's WebAssembly.Suspending and WebAssembly.promising are installed (shipped in V8 13.7)" {
    const page = try Page.open();
    defer page.close();
    try page.expect("[typeof WebAssembly.Suspending, typeof WebAssembly.promising].join()", "function,function");
}
