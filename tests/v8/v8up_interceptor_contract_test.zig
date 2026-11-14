//! Every interceptor callback returns V8's own `v8::Intercepted` (lane v8up,
//! the V8 15.7 port).
//!
//! The Zig callbacks return the enum BY VALUE across the C ABI, so its width
//! and both constants must be V8's, and no header compile checks a Zig enum.
//! V8 8f35dec9947 (2026-01-30, "[ic] Introduce CallNamedInterceptorGetter
//! builtin", in 15.7.112.43) redefined it from 13.1's
//! `enum class Intercepted : uint8_t { kNo = 0, kYes = 1 }` to
//! `enum class Intercepted : uint32_t { kNo = 1, kYes = 0 }` (kNo is the IC's
//! kNotInterceptedSentinel, which must look like a HeapObject). With 13.1's
//! values every "not mine" read as "intercepted, value undefined" and every
//! answer as "not mine": on 15.7 `new Document().implementation` and
//! `.createElement` were undefined - Document's masking named interceptor
//! ([LegacyOverrideBuiltIns]) runs before the prototype chain - and about 280
//! tests/v8 cases failed behind it (design 2.11).
//!
//! The behaviour cases go through each interceptor shape the binding installs
//! (interface.zig): a masking named one (Document), a non-masking named one
//! (HTMLCollection), an indexed one (HTMLSelectElement), each with a hit and
//! a miss. WebIDL 3.9.1 LegacyPlatformObjectGetOwnProperty; 3.9.7 the named
//! property visibility algorithm.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

test "the Zig side's Intercepted is V8's: width and both constants" {
    try testing.expectEqual(@sizeOf(ffi.Intercepted), ffi.v8_Intercepted_Size());
    try testing.expectEqual(@as(u32, @backingInt(ffi.Intercepted.kYes)), ffi.v8_Intercepted_Value(true));
    try testing.expectEqual(@as(u32, @backingInt(ffi.Intercepted.kNo)), ffi.v8_Intercepted_Value(false));
}

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
            .origin = "https://v8up.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn expectOk(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
        try testing.expectEqualStrings("ok", got);
    }
};

const prelude =
    \\const failures = [];
    \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
    \\
;

test "a masking named interceptor passes a name it does not support on to the prototype chain" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\const d = new Document();
        \\check("new Document().implementation is a DOMImplementation", d.implementation instanceof DOMImplementation, true);
        \\check("typeof new Document().createElement", typeof d.createElement, "function");
        \\check("'implementation' in new Document()", "implementation" in d, true);
        \\check("an unknown name reads undefined", d.noSuchName, undefined);
        \\check("an unknown name is no own property", Object.getOwnPropertyDescriptor(d, "noSuchName"), undefined);
        \\failures.join("; ") || "ok"
    );
}

test "a masking named interceptor answers a supported name" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\const doc = new Document().implementation.createHTMLDocument("");
        \\const form = doc.createElement("form");
        \\form.setAttribute("name", "x");
        \\doc.body.appendChild(form);
        \\check("doc.x is the form named x", doc.x, form);
        \\check("'x' in doc", "x" in doc, true);
        \\const desc = Object.getOwnPropertyDescriptor(doc, "x");
        \\check("doc's own x descriptor's value", desc && desc.value, form);
        \\failures.join("; ") || "ok"
    );
}

test "a non-masking named interceptor and an indexed interceptor answer hits and pass misses on" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(prelude ++
        \\const doc = new Document().implementation.createHTMLDocument("");
        \\const div = doc.createElement("div");
        \\div.id = "y";
        \\doc.body.appendChild(div);
        \\const children = doc.body.children;
        \\check("children.y (HTMLCollection's named getter)", children.y, div);
        \\check("children.length (a prototype accessor)", children.length, 1);
        \\check("children.noSuchName", children.noSuchName, undefined);
        \\const select = doc.createElement("select");
        \\const option = doc.createElement("option");
        \\select.appendChild(option);
        \\check("select[0] (the indexed getter)", select[0], option);
        \\check("select[5] (an index past the end)", select[5], undefined);
        \\check("'5' in select", "5" in select, false);
        \\check("select.length", select.length, 1);
        \\failures.join("; ") || "ok"
    );
}
