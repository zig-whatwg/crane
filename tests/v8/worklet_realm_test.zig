//! The worklet realm operations: `createWorkletRealm` and
//! `destroyWorkletRealm`, the engine halves of HTML 11.3.1.2 "create a
//! worklet global scope" (step 3: a new realm whose global object is a new
//! object of the worklet's global scope type) and "terminate a worklet global
//! scope" (step 5).
//!
//! Crane runs a worklet's realm in its owner Window's agent - Blink's
//! main-thread worklet (WorkletGlobalScope(LocalFrame*) uses
//! ToIsolate(frame)) - so the realm is made in the page's isolate, and its end
//! must leave the page's isolate, templates and realm working, with no handle
//! of the worklet realm left. Values are made the way the binding makes them:
//! by script in the realm.

const std = @import("std");
const testing = std.testing;
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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
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

    fn worklet(self: Page, global: runtime.WorkletRealmOptions.WorkletGlobal) !runtime.WorkletRealm {
        return protocol.createWorkletRealm(self.agent, &.{
            .global = global,
            .owner = self.realm,
            .api_base_url = "https://example.test/page.html",
            .allocator = std.heap.c_allocator,
        });
    }
};

fn answer(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try answer(realm, source);
    defer testing.allocator.free(got);
    testing.expectEqualStrings(expected, got) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

/// The engine's counter `name`, now.
fn counter(name: []const u8) !i64 {
    const counters = try protocol.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |c| {
        if (std.mem.eql(u8, c.name, name)) return c.value;
    }
    return error.NoSuchCounter;
}

test "each worklet realm's global object is a new object of its worklet global scope type" {
    const page = try Page.open();
    defer page.close();
    const cases = [_]struct { global: runtime.WorkletRealmOptions.WorkletGlobal, name: []const u8 }{
        .{ .global = .paint, .name = "PaintWorkletGlobalScope" },
        .{ .global = .layout, .name = "LayoutWorkletGlobalScope" },
        .{ .global = .animation, .name = "AnimationWorkletGlobalScope" },
        .{ .global = .audio, .name = "AudioWorkletGlobalScope" },
    };
    for (cases) |case| {
        const made = try page.worklet(case.global);
        defer protocol.destroyWorkletRealm(made.realm);
        try testing.expectEqualStrings(case.name, made.global_scope.vtable.name);

        const source = try std.fmt.allocPrint(testing.allocator,
            \\[
            \\  Object.getPrototypeOf(globalThis) === {s}.prototype,
            \\  Object.getPrototypeOf({s}.prototype) === WorkletGlobalScope.prototype,
            \\  globalThis instanceof WorkletGlobalScope,
            \\].join()
        , .{ case.name, case.name });
        defer testing.allocator.free(source);
        try expect(made.realm, source, "true,true,true");
    }
}

test "a worklet realm exposes what is [Exposed] to its worklet and no self" {
    const page = try Page.open();
    defer page.close();
    const paint = try page.worklet(.paint);
    defer protocol.destroyWorkletRealm(paint.realm);
    // HTML 11.1.2: no counterpart to self. [Exposed=PaintWorklet] members and
    // interfaces are there, [Exposed=*] ones too, Window-only ones are not.
    try expect(paint.realm,
        \\[typeof self, typeof registerPaint, typeof registerLayout, typeof registerProcessor,
        \\ typeof document, typeof Window, typeof EventTarget, typeof console].join()
    , "undefined,function,undefined,undefined,undefined,undefined,function,object");

    const audio = try page.worklet(.audio);
    defer protocol.destroyWorkletRealm(audio.realm);
    try expect(audio.realm,
        \\[typeof registerProcessor, typeof AudioWorkletProcessor, typeof registerPaint].join()
    , "function,function,undefined");
}

test "a worklet realm records its owner's agent and Browser, and its own settings" {
    const page = try Page.open();
    defer page.close();
    const made = try page.worklet(.layout);
    defer protocol.destroyWorkletRealm(made.realm);
    try testing.expectEqual(page.realm.agent, made.realm.agent);
    try testing.expectEqual(page.realm.browser_scope, made.realm.browser_scope);
    // HTML 8.1.3.5: a WorkletGlobalScope's settings object is a secure context.
    try testing.expect(made.realm.secure_context);
    // HTML 11.3.1.3 step 2: the API base URL is the outside settings'.
    try testing.expectEqualStrings("https://example.test/page.html", made.realm.documentUrl().?);
    const record = made.realm.getRealm() orelse return error.NoRealmRecord;
    try testing.expectEqual(runtime.realm.ContextType.worklet, record.info.context_type);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(made.global_scope)), record.global_object);
}

test "a worklet realm's end leaves its owner working and no handle of its own" {
    const page = try Page.open();
    defer page.close();
    // Warm the page's templates for the worklet's interfaces, so the
    // measurement below sees only what one realm's life leaves.
    {
        const warm = try page.worklet(.paint);
        try expect(warm.realm, "typeof registerPaint", "function");
        protocol.destroyWorkletRealm(warm.realm);
    }
    // V8's own count of global handles in use (used_global_handles_size) is
    // the measure. The adapter's ledger counters drift downwards on main
    // already (they read negative before this test makes anything): a
    // v8_Object_New handle - the console namespace object a realm gets - is
    // not counted when made but is when disposed (v8_wrapper.cpp). So they
    // may only not grow.
    const bytes_before = try counter("global_handle_bytes");
    const contexts_before = try counter("live_context_globals");
    const objects_before = try counter("live_object_globals");
    const strings_before = try counter("live_string_globals");
    const cache_before = try counter("wrapper_cache_entries");

    const made = try page.worklet(.paint);
    // Values made the way the binding makes them: script in the realm.
    try expect(made.realm,
        \\globalThis.kept = { list: [1, 2, 3].map(x => x * 2), text: 'worklet' };
        \\[kept.list.join(' '), kept.text, Object.keys(globalThis).includes('kept')].join()
    , "2 4 6,worklet,true");
    protocol.destroyWorkletRealm(made.realm);

    try testing.expectEqual(bytes_before, try counter("global_handle_bytes"));
    try testing.expectEqual(contexts_before, try counter("live_context_globals"));
    try testing.expectEqual(cache_before, try counter("wrapper_cache_entries"));
    try testing.expect(try counter("live_object_globals") <= objects_before);
    try testing.expect(try counter("live_string_globals") <= strings_before);

    // The page's realm and its templates go on.
    try expect(page.realm, "[typeof Window, 1 + 1].join()", "function,2");
}

test "two worklet realms of one owner are separate realms" {
    const page = try Page.open();
    defer page.close();
    const first = try page.worklet(.paint);
    defer protocol.destroyWorkletRealm(first.realm);
    const second = try page.worklet(.paint);
    defer protocol.destroyWorkletRealm(second.realm);
    try testing.expect(first.realm != second.realm);
    try expect(first.realm, "globalThis.mark = 'first'; mark", "first");
    try expect(second.realm, "typeof mark", "undefined");
}

test "the generated interfaces are exposed in the worklets their IDL names" {
    const isExposedIn = @import("webidl").helpers.isExposedIn;
    try testing.expect(isExposedIn(interfaces.WorkletGlobalScope, .PaintWorklet));
    try testing.expect(isExposedIn(interfaces.WorkletGlobalScope, .AudioWorklet));
    try testing.expect(isExposedIn(interfaces.PaintWorkletGlobalScope, .PaintWorklet));
    try testing.expect(!isExposedIn(interfaces.PaintWorkletGlobalScope, .LayoutWorklet));
    try testing.expect(isExposedIn(interfaces.AudioWorkletProcessor, .AudioWorklet));
    try testing.expect(!isExposedIn(interfaces.AudioWorkletProcessor, .PaintWorklet));
    // [Exposed=*] reaches worklets; [Exposed=Window] and [Exposed=Worker] do not.
    try testing.expect(isExposedIn(interfaces.EventTarget, .PaintWorklet));
    try testing.expect(!isExposedIn(interfaces.Window, .PaintWorklet));
    try testing.expect(!isExposedIn(interfaces.Worklet, .PaintWorklet));
}
