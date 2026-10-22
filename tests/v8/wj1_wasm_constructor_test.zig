//! WebAssembly constructors use WebIDL's prototype-from-NewTarget algorithm.
//! These contexts run the same adapter installation as Window/worker realms.
//! Each test owns a fresh isolate on a fresh thread, makes actual Wasm values
//! through script, and releases every FFI handle before destroying its isolate.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const inline_task_loop = @import("inline_task_loop.zig");
const ffi = @import("v8").ffi;

fn evaluate(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) !void {
    const code = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.NoString;
    defer ffi.v8_String_Dispose(code);
    const script = ffi.v8_Script_Compile(context, code) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    var result = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(result);
    if (ffi.v8_Value_IsPromise(result)) {
        const promise: *ffi.Promise = @ptrCast(result);
        for (0..100) |_| {
            if (ffi.v8_Promise_State(promise) != 0) break;
            ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
        }
        try std.testing.expectEqual(@as(c_int, 1), ffi.v8_Promise_State(promise));
        const resolved = ffi.v8_Promise_Result(promise) orelse return error.NoPromiseResult;
        ffi.v8_Value_Dispose(result);
        result = resolved;
    }
    const string = ffi.v8_Value_ToString(result, context) orelse return error.NoResult;
    defer ffi.v8_String_Dispose(string);
    const length: usize = @intCast(ffi.v8_String_Utf8Length(string));
    const bytes = try std.testing.allocator.alloc(u8, length + 1);
    defer std.testing.allocator.free(bytes);
    const written: usize = @intCast(ffi.v8_String_WriteUtf8(string, bytes.ptr, @intCast(bytes.len)));
    try std.testing.expectEqualStrings("ok", std.mem.trimEnd(u8, bytes[0..written], "\x00"));
}

fn inFreshIsolate(source: []const u8) !void {
    const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
    defer ffi.v8_Isolate_Dispose(isolate);
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
    defer ffi.v8_Context_Dispose(context);
    const other = ffi.v8_Context_New(isolate) orelse return error.NoOtherContext;
    defer ffi.v8_Context_Dispose(other);
    const token = ffi.v8_String_NewFromUtf8(isolate, "wj1", 3) orelse return error.NoToken;
    defer ffi.v8_String_Dispose(token);
    ffi.v8_Context_SetSecurityToken(context, @ptrCast(token));
    ffi.v8_Context_SetSecurityToken(other, @ptrCast(token));
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    // Keep the unadapted interface objects only in these test contexts, so
    // shape/instanceof controls compare the adapter with the linked native
    // implementation instead of duplicating its property list in a test.
    const capture =
        \\globalThis.wj1OriginalWasm = {};
        \\for (const name of ["Module","Instance","Memory","Table","Global","Exception"])
        \\  wj1OriginalWasm[name] = WebAssembly[name];
        \\"ok";
    ;
    try evaluate(isolate, context, capture);
    try evaluate(isolate, other, capture);
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, other);
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const other_global = ffi.v8_Context_Global(other) orelse return error.NoOtherGlobal;
    defer ffi.v8_Object_Dispose(other_global);
    const key = ffi.v8_String_NewFromUtf8(isolate, "other", 5) orelse return error.NoKey;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(other_global))) return error.ShareFailed;
    try evaluate(isolate, context, source);
}

const PlatformKind = enum { window, worker, worklet };

const WindowHost = struct {
    fn create(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.testing.allocator, realm) catch null;
    }
};

fn inPlatformRealm(source: []const u8, kind: PlatformKind, from_snapshot: bool) !void {
    runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
    try v8.context_manager.init(std.testing.allocator);
    defer v8.context_manager.deinit();
    const no_hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{
        .can_block = kind == .worker,
        .from_snapshot = from_snapshot,
        .hooks = &no_hooks,
        .allocator = std.testing.allocator,
    });
    defer engine.destroyAgent(agent);
    // The snapshot control must not silently exercise the fresh-agent
    // fallback when a blob is rejected.
    if (from_snapshot) try std.testing.expect(ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent))));
    const window = if (kind != .worker) try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.testing.allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = "https://wj1.test",
        .create_global_object = WindowHost.create,
    }) else null;
    defer if (window) |realm| engine.destroyWindowRealm(realm, .global_detached);
    const realm = switch (kind) {
        .window => window.?,
        .worker => (try engine.createWorkerRealm(agent, &.{
            .url = "https://wj1.test/worker.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .allocator = std.testing.allocator,
        })).realm,
        .worklet => (try engine.createWorkletRealm(agent, &.{
            .global = .paint,
            .owner = window.?,
            .api_base_url = "https://wj1.test/",
            .allocator = std.testing.allocator,
        })).realm,
    };
    defer switch (kind) {
        .window => {},
        .worker => engine.destroyWorkerRealm(realm, null, null),
        .worklet => engine.destroyWorkletRealm(realm),
    };
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx.?));
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    ffi.v8_Context_Enter(context);
    defer ffi.v8_Context_Exit(context);
    const other = ffi.v8_Context_New(isolate) orelse return error.NoOtherContext;
    defer ffi.v8_Context_Dispose(other);
    ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, other);
    const token = ffi.v8_Context_GetSecurityToken(context) orelse return error.NoToken;
    defer ffi.v8_Value_Dispose(token);
    ffi.v8_Context_SetSecurityToken(other, token);
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const other_global = ffi.v8_Context_Global(other) orelse return error.NoOtherGlobal;
    defer ffi.v8_Object_Dispose(other_global);
    const key = ffi.v8_String_NewFromUtf8(isolate, "other", 5) orelse return error.NoKey;
    defer ffi.v8_String_Dispose(key);
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(other_global))) return error.ShareFailed;
    try evaluate(isolate, context, source);
}

const Run = struct {
    source: []const u8,
    failure: ?anyerror = null,

    fn thread(self: *Run) void {
        inFreshIsolate(self.source) catch |err| {
            self.failure = err;
            return;
        };
        if (std.mem.startsWith(u8, self.source, "(async")) {
            for ([_]PlatformKind{ .window, .worker, .worklet }) |kind| {
                inPlatformRealm(self.source, kind, false) catch |err| {
                    self.failure = err;
                    return;
                };
            }
        }
    }
};

fn check(source: []const u8) !void {
    try engine.initializeEngine(.{});
    var run: Run = .{ .source = source };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

const prelude =
    \\(() => {
    \\try {
    \\const bytes = new Uint8Array([0,97,115,109,1,0,0,0]);
    \\const module = new WebAssembly.Module(bytes);
    \\const cases = [["Module", [bytes]], ["Instance", [module]],
    \\ ["Memory", [{initial: 0}]], ["Table", [{element: "anyfunc", initial: 0}]],
    \\ ["Global", [{value: "i32"}]]];
;
const ending =
    \\return "ok";
    \\} catch (e) { return String(e); }
    \\})()
;

test "wasm Global value setter treats an absent argument as undefined" {
    try check(
        \\(() => {
        \\  const setter = Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype, "value").set;
        \\  for (const type of ["i32", "f32", "f64", "externref"]) {
        \\    const global = new WebAssembly.Global({value: type, mutable: true});
        \\    try { setter.call(global); } catch(e) { return type + ": " + e; }
        \\    const actual = global.value;
        \\    setter.call(global, undefined);
        \\    if (!Object.is(global.value, actual)) return type + " differs";
        \\  }
        \\  return "ok";
        \\})()
    );
}

test "wasm Global setter keeps branding immutability conversion and descriptors" {
    try check(
        \\(() => {
        \\  const desc = Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype, "value");
        \\  const setter = desc.set;
        \\  if (!desc.enumerable || !desc.configurable || setter.length !== 1 || setter.name !== "set value") return "descriptor";
        \\  const typeError = f => { try { f(); return false; } catch(e) { return e instanceof TypeError; } };
        \\  if (!typeError(() => setter.call({}))) return "brand";
        \\  if (!typeError(() => new setter())) return "constructible";
        \\  if (!typeError(() => setter.call(new WebAssembly.Global({value:"i32"})))) return "immutable";
        \\  if (!typeError(() => setter.call(new WebAssembly.Global({value:"i64", mutable:true})))) return "i64";
        \\  const sentinel = {};
        \\  const global = new WebAssembly.Global({value:"i32", mutable:true});
        \\  try { setter.call(global, {valueOf() { throw sentinel; }}); return "did not throw"; }
        \\  catch(e) { if (e !== sentinel) return "replaced exception"; }
        \\  return "ok";
        \\})()
    );
}
