//! Per-realm exposure is known before interfaces are installed.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const ffi = v8.ffi;
const Scope = @import("webidl").helpers.GlobalScope;

const Probe = struct {
    pub const Meta = struct {
        pub const name = "Xw1ExposureProbe";
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{.{ "secret", "get_secret", null }};
        pub const unforgeable_members = .{"secret"};
        pub const methods = .{};
        pub const has_constructor = false;
        pub const constants = .{ .{ "WINDOW", "get_WINDOW" }, .{ "ALL", "get_ALL" } };
        pub const exposed_members = .{ .{ "WINDOW", .{"Window"} }, .{ "secret", .{"Window"} } };
        pub const exposed_static_members = exposed_members;
    };
    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, struct {});
    pub fn get_secret(_: *runtime.Instance) anyerror!u32 {
        return 3;
    }
    pub fn get_WINDOW() u32 {
        return 1;
    }
    pub fn get_ALL() u32 {
        return 2;
    }
};

const Host = struct {
    fn window(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, r) catch null;
    }
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("xw1 script error: {s}\n", .{info.message});
    }
    fn install(data: ?*anyopaque) void {
        const r: runtime.Context = @ptrCast(@alignCast(data.?));
        const c: *ffi.Context = @ptrCast(@alignCast(r.engine_ctx.?));
        const B = v8.V8Interface(Probe);
        const isolate = ffi.v8_Isolate_GetCurrent().?;
        B.registerGlobal(isolate, c, Probe.Meta.name);
        const template = B.createTemplate(isolate);
        const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(template);
        defer ffi.v8_ObjectTemplate_Dispose(instance_template);
        const object = ffi.v8_ObjectTemplate_NewInstance(instance_template, c) orelse return;
        defer ffi.v8_Object_Dispose(object);
        if (comptime @hasDecl(B, "installConditionalUnforgeables")) B.installConditionalUnforgeables(isolate, c, object);
        const global = ffi.v8_Context_Global(c) orelse return;
        defer ffi.v8_Object_Dispose(global);
        const name = ffi.v8_String_NewFromUtf8(isolate, "xw1Probe", 8) orelse return;
        defer ffi.v8_String_Dispose(name);
        _ = ffi.v8_Object_Set(global, c, @ptrCast(name), @ptrCast(object));
    }
};

fn expect(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const value = try engine.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Host.report, .host = null });
    defer testing.allocator.free(value);
    testing.expectEqualStrings(expected, value) catch |err| {
        std.debug.print("Exposure expression: {s}\n", .{source});
        return err;
    };
}

fn verify(r: runtime.Context, scope: Scope, secure: bool) !void {
    const c: *ffi.Context = @ptrCast(@alignCast(r.engine_ctx.?));
    try testing.expectEqual(scope, v8.interface_mod.realmExposureScope(c));
    try expect(r, "['Document', 'Node', 'Window', 'HTMLDocument', 'webkitURL', 'Image', 'Audio', 'Option'].map(n => typeof globalThis[n]).join()", if (scope == .Window) "function,function,function,function,function,function,function,function" else "undefined,undefined,undefined,undefined,undefined,undefined,undefined,undefined");
    if (scope == .Window) {
        try expect(r, "[HTMLDocument === Document, webkitURL === URL].join()", "true,true");
        try expect(r,
            \\(() => {
            \\  const shape = d => 'value' in d && d.writable && d.configurable &&
            \\    !d.enumerable && !('get' in d) && !('set' in d);
            \\  const beforePoint = Object.getOwnPropertyDescriptor(globalThis, 'SVGPoint');
            \\  const pointAliasFirst = SVGPoint;
            \\  const pointTarget = DOMPoint;
            \\  const rectTargetFirst = DOMRect;
            \\  const beforeRect = Object.getOwnPropertyDescriptor(globalThis, 'SVGRect');
            \\  const rectAlias = SVGRect;
            \\  return [shape(beforePoint), pointAliasFirst === pointTarget,
            \\    pointAliasFirst.prototype === pointTarget.prototype,
            \\    shape(Object.getOwnPropertyDescriptor(globalThis, 'SVGPoint')),
            \\    shape(beforeRect), rectTargetFirst === rectAlias,
            \\    rectTargetFirst.prototype === rectAlias.prototype,
            \\    shape(Object.getOwnPropertyDescriptor(globalThis, 'SVGRect'))].join();
            \\})()
        , "true,true,true,true,true,true,true,true");
    } else try expect(r, "[typeof SVGPoint, typeof SVGRect].join()", "undefined,undefined");
    try expect(r, "[typeof console, typeof WebAssembly].join()", "object,object");
    try expect(r, "typeof CSS", if (scope == .Window) "object" else "undefined");
    try expect(r, "[typeof GPUBufferUsage, typeof GPUMapMode, typeof GPUTextureUsage, typeof GPUShaderStage, typeof GPUColorWrite].join()", if (scope == .PaintWorklet or !secure) "undefined,undefined,undefined,undefined,undefined" else "object,object,object,object,object");
    try expect(r, "typeof TestUtils", if (scope == .PaintWorklet) "undefined" else "object");
    try engine.runInRealm(r, Host.install, r);
    try expect(r, "['WINDOW' in Xw1ExposureProbe, 'WINDOW' in Xw1ExposureProbe.prototype].join()", if (scope == .Window) "true,true" else "false,false");
    try expect(r, "[Xw1ExposureProbe.ALL, Object.getOwnPropertyDescriptor(Xw1ExposureProbe.prototype, 'ALL').configurable].join()", "2,false");
    try expect(r, "'secret' in xw1Probe", if (scope == .Window) "true" else "false");
    if (scope == .Window) try expect(r, "Object.getOwnPropertyDescriptor(xw1Probe, 'secret').configurable", "false");
}

pub fn checkWithSnapshot(snapshot: ?[]const u8) !void {
    try engine.initializeEngine(.{ .snapshot = snapshot });
    defer if (snapshot != null) engine.deinitializeEngine();
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var browser = runtime.BrowserScope.init(testing.allocator);
    defer browser.deinit();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = snapshot != null, .hooks = &hooks, .allocator = testing.allocator });
    defer engine.destroyAgent(agent);
    if (snapshot != null) try testing.expect(ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent))));
    const page = try engine.createWindowRealm(&.{ .agent = agent, .allocator = testing.allocator, .from_snapshot = snapshot != null, .timer = null, .origin = "https://example.test", .browser_scope = &browser, .create_global_object = Host.window });
    defer engine.destroyWindowRealm(page, .global_detached);
    try verify(page, .Window, true);
    try expect(page, "['responseXML' in XMLHttpRequest.prototype, 'timing' in Performance.prototype, typeof URL.createObjectURL].join()", "true,true,function");
    const child = try engine.createWindowRealm(&.{ .agent = agent, .allocator = testing.allocator, .from_snapshot = snapshot != null, .timer = null, .origin = "https://example.test", .browser_scope = &browser, .create_global_object = Host.window, .parent = page });
    defer engine.destroyWindowRealm(child, .global_detached);
    try verify(child, .Window, true);
    const replaced = try engine.createWindowRealm(&.{ .agent = agent, .allocator = testing.allocator, .from_snapshot = snapshot != null, .timer = null, .origin = "https://example.test", .browser_scope = &browser, .create_global_object = Host.window, .parent = page });
    defer engine.destroyWindowRealm(replaced, .global_detached);
    try expect(replaced,
        \\(() => {
        \\  const point = DOMPoint;
        \\  const rect = DOMRect;
        \\  delete globalThis.DOMPoint;
        \\  globalThis.DOMRect = function replacement() {};
        \\  return [SVGPoint === point, SVGPoint.prototype === point.prototype,
        \\    SVGRect === rect, SVGRect.prototype === rect.prototype].join();
        \\})()
    , "true,true,true,true");
    inline for (.{ .{ .dedicated, Scope.DedicatedWorker }, .{ .shared, Scope.SharedWorker }, .{ .service, Scope.ServiceWorker } }) |case| {
        const made = try engine.createWorkerRealm(agent, &.{ .global = case[0], .url = "https://example.test/worker.js", .allocator = testing.allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
        defer engine.destroyWorkerRealm(made.realm, null, null);
        try verify(made.realm, case[1], true);
        try expect(made.realm, "[typeof XMLHttpRequest !== 'undefined' && 'responseXML' in XMLHttpRequest.prototype, 'timing' in Performance.prototype, typeof URL.createObjectURL, typeof Worker].join()", if (case[1] == .ServiceWorker) "false,false,undefined,undefined" else "false,false,function,function");
        const insecure = try engine.createWorkerRealm(agent, &.{ .global = case[0], .url = "http://example.test/worker.js", .secure_context = false, .allocator = testing.allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
        defer engine.destroyWorkerRealm(insecure.realm, null, null);
        try verify(insecure.realm, case[1], false);
    }
    const worklet = try engine.createWorkletRealm(agent, &.{ .global = .paint, .owner = page, .api_base_url = "https://example.test", .allocator = testing.allocator });
    defer engine.destroyWorkletRealm(worklet.realm);
    try verify(worklet.realm, .PaintWorklet, true);
    try expect(worklet.realm, "[typeof Worker, typeof XMLHttpRequest, typeof PaintWorkletGlobalScope].join()", "undefined,undefined,function");
    // The worker/worklet instantiations must not narrow the shared templates.
    try expect(page, "['WINDOW' in Xw1ExposureProbe, 'responseXML' in XMLHttpRequest.prototype].join()", "true,true");
}

test "xw1 worker and worklet scopes filter their first interfaces without changing a Window in the same isolate" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            out.* = checkWithSnapshot(null);
        }
    }.run, .{&result});
    thread.join();
    try result;
}

test "xw1 an unannotated member inherits interface exposure and a mixin cannot broaden it" {
    const WindowOnly = struct {
        pub const Meta = struct {
            pub const extended_attributes = .{.{ .name = "Exposed", .value = .{ .identifier = "Window" } }};
            pub const exposed_members = .{.{ "wide", .{"*"} }};
        };
    };
    try testing.expect(v8.interface_mod.memberIsExposed(WindowOnly, "ordinary", false, .Window));
    try testing.expect(!v8.interface_mod.memberIsExposed(WindowOnly, "ordinary", false, .DedicatedWorker));
    try testing.expect(!v8.interface_mod.memberIsExposed(WindowOnly, "wide", false, .DedicatedWorker));
    try testing.expect(!v8.interface_mod.hasConditionalUnforgeables(WindowOnly));
    try testing.expect(v8.interface_mod.hasConditionalUnforgeables(Probe));
}

test "xw1 a newly registered context defaults to Window exposure" {
    const entry: v8.context_manager.ContextEntry = .{
        .v8_ctx = undefined,
        .runtime_ctx = undefined,
        .owns_context = false,
        .event_loop = null,
        .realm = null,
        .parent_entry = null,
        .children = .empty,
        .allocator = testing.allocator,
    };
    try testing.expectEqual(Scope.Window, entry.exposure_scope);
}
