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
    // Platform setup, including snapshot restoration, must leave Wasm pending.
    try expectWasmInstalled(global, false);
    try expectWasmInstalled(other_global, false);
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

test "snapshot Window worklet and ShadowRealm use their own wasm adapter intrinsics" {
    // Snapshot deserialization after another file starts V8 can crash in
    // StringTable::InsertForIsolateDeserialization, before adapter code runs
    // (pattern_attribute_snapshot_test.zig). Run this test first in its own
    // file and verify it with -Dtest-file=; the shared directory suite skips
    // when another file already owns process initialization.
    if (ffi.v8_Platform_IsInitialized()) {
        std.log.warn("skipping Wasm snapshot control: run wj1_wasm_constructor_test.zig with -Dtest-file=", .{});
        return error.SkipZigTest;
    }
    // An isolated native test can be built without a snapshot. The final
    // runner+snapshot gate supplies this build's blob and runs this case.
    const io = std.testing.io;
    const file = std.Io.Dir.cwd().openFile(io, "zig-out/bin/whatwg_snapshot.bin", .{}) catch |err| switch (err) {
        error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
    defer file.close(io);
    const stat = try file.stat(io);
    const bytes = try std.testing.allocator.alloc(u8, stat.size);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(bytes.len, try file.readPositionalAll(io, bytes, 0));
    try engine.initializeEngine(.{ .snapshot = bytes });
    defer engine.deinitializeEngine();
    const RunSnapshot = struct {
        fn thread(failure: *?anyerror) void {
            const source =
                \\(async () => {
                \\try {
                \\const g = new WebAssembly.Global({value:"i32", mutable:true});
                \\Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype,"value").set.call(g);
                \\const shadow = new ShadowRealm();
                \\const result = shadow.evaluate(`(() => {
                \\  const Module = WebAssembly.Module;
                \\  const prototype = Module.prototype;
                \\  function Target() {}
                \\  Target.prototype = null;
                \\  WebAssembly.Module = function() { throw Error("mutable Module"); };
                \\  const made = Reflect.construct(Module, [new Uint8Array([0,97,115,109,1,0,0,0])], Target);
                \\  if (Object.getPrototypeOf(made) !== prototype) return "shadow realm prototype";
                \\  WebAssembly.Module = Module;
                \\  const g = new WebAssembly.Global({value:"i32",mutable:true});
                \\  Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype,"value").set.call(g);
                \\  return "ok";
                \\})()`);
                \\if (result !== "ok") return result;
                \\shadow.evaluate(`globalThis.done = "pending"; void (async () => {
                \\  try {
                \\    const bytes = new Uint8Array([0,97,115,109,1,0,0,0,
                \\      1,7,1,96,2,127,127,1,127,2,7,1,1,109,1,102,0,0,
                \\      3,2,1,0,6,6,1,127,1,65,0,11,7,9,2,1,102,0,1,1,103,3,0,
                \\      10,14,1,12,0,32,0,32,1,16,0,36,0,35,0,11]);
                \\    const instance = new WebAssembly.Instance(new WebAssembly.Module(bytes),
                \\      {m:{f:new WebAssembly.Suspending((a,b) => a+b)}});
                \\    const pending = WebAssembly.promising(instance.exports.f)(2,3);
                \\    if (instance.exports.g.value !== 0) throw Error("not suspended");
                \\    globalThis.done = await pending === 5 ? "ok" : "result";
                \\  } catch(e) { globalThis.done = String(e); }
                \\})()`);
                \\for (let i=0; i<10 && shadow.evaluate("done") === "pending"; i++) await Promise.resolve();
                \\return shadow.evaluate("done");
                \\} catch(e) { return String(e); }
                \\})()
            ;
            for ([_]PlatformKind{ .window, .worklet }) |kind| {
                inPlatformRealm(source, kind, true) catch |err| {
                    failure.* = err;
                    return;
                };
            }
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, RunSnapshot.thread, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "wasm constructors fall back to bound and proxy NewTarget realm prototypes" {
    try check(prelude ++
        \\for (const [name, args] of cases) {
        \\  const target = new other.Function();
        \\  target.prototype = null;
        \\  for (const nt of [target, target.bind(null), new Proxy(target, {}),
        \\      new Proxy(target.bind(null), {}), new Proxy(target, {}).bind(null)]) {
        \\    const made = Reflect.construct(WebAssembly[name], args, nt);
        \\    if (Object.getPrototypeOf(made) !== other.WebAssembly[name].prototype)
        \\      return name + " wrong realm";
        \\  }
        \\}
    ++ ending);
}

test "wasm constructor reads NewTarget prototype once before argument getters" {
    try check(prelude ++
        \\for (const name of ["Memory", "Table"]) {
        \\  const order = [];
        \\  const prototype = {};
        \\  const target = new Proxy(function () {}, {
        \\    get(t, key, receiver) {
        \\      if (key === "prototype") { order.push("prototype"); return prototype; }
        \\      return Reflect.get(t, key, receiver);
        \\    }
        \\  });
        \\  const descriptor = {initial: 0, element: "anyfunc",
        \\    get address() { order.push("address"); return "i32"; }};
        \\  const made = Reflect.construct(WebAssembly[name], [descriptor], target);
        \\  if (Object.getPrototypeOf(made) !== prototype) return name + " explicit prototype";
        \\  if (order.join() !== "prototype,address") return name + ": " + order;
        \\}
    ++ ending);
}

test "wasm address adaptation preserves dictionary getter receiver" {
    try check(prelude ++
        \\for (const name of ["Memory", "Table"]) {
        \\  const descriptor = {address:"i32", element:"anyfunc"};
        \\  Object.defineProperty(descriptor, "initial", {get() {
        \\    if (this !== descriptor) throw Error("dictionary receiver changed");
        \\    return 0;
        \\  }});
        \\  Object.defineProperty(descriptor, "index", {value:"ignored"});
        \\  new WebAssembly[name](descriptor);
        \\}
    ++ ending);
}

test "wasm realm fallback keeps intrinsic prototypes after namespace replacement" {
    try check(prelude ++
        \\const prototypes = Object.fromEntries(cases.map(([name]) => [name, other.WebAssembly[name].prototype]));
        \\const target = new other.Function();
        \\target.prototype = undefined;
        \\other.WebAssembly = new Proxy({}, {get() { throw Error("read mutable namespace"); }});
        \\for (const [name, args] of cases) {
        \\  const made = Reflect.construct(WebAssembly[name], args, target);
        \\  if (Object.getPrototypeOf(made) !== prototypes[name]) return name + " intrinsic lost";
        \\}
    ++ ending);
}

test "wasm constructor adapters preserve the complete interface object shape" {
    try check(prelude ++
        \\for (const [name, args] of cases) {
        \\  const constructor = WebAssembly[name];
        \\  const namespace = Object.getOwnPropertyDescriptor(WebAssembly, name);
        \\  const prototype = Object.getOwnPropertyDescriptor(constructor, "prototype");
        \\  const back = Object.getOwnPropertyDescriptor(prototype.value, "constructor");
        \\  const length = Object.getOwnPropertyDescriptor(constructor, "length");
        \\  const label = Object.getOwnPropertyDescriptor(constructor, "name");
        \\  if (namespace.value !== constructor || !namespace.writable || namespace.enumerable || !namespace.configurable) return name + " namespace";
        \\  if (prototype.writable || prototype.enumerable || prototype.configurable) return name + " prototype";
        \\  if (back.value !== constructor || !back.writable || back.enumerable || !back.configurable) return name + " constructor";
        \\  if (length.value !== 1 || length.writable || length.enumerable || !length.configurable) return name + " length";
        \\  if (label.value !== name || label.writable || label.enumerable || !label.configurable) return name + " name";
        \\  if (Object.getPrototypeOf(constructor) !== Function.prototype) return name + " parent";
        \\  if (!Function.prototype.toString.call(constructor).includes("[native code]")) return name + " source";
        \\  try { constructor(...args); return name + " no new"; } catch(e) { if (!(e instanceof TypeError)) return name + " wrong error"; }
        \\  if (Object.getPrototypeOf(new constructor(...args)) !== prototype.value) return name + " instance";
        \\  class Sub extends constructor {}
        \\  if (Object.getPrototypeOf(new Sub(...args)) !== Sub.prototype) return name + " subclass";
        \\}
        \\for (const method of ["imports", "exports"]) {
        \\  if (typeof WebAssembly.Module[method] !== "function" || WebAssembly.Module[method](module).length !== 0) return method;
        \\}
        \\if (WebAssembly.Module.customSections(module, "missing").length !== 0) return "customSections";
    ++ ending);
}

test "wasm constructor prototype getter exceptions and revocation propagate" {
    try check(prelude ++
        \\for (const [name, args] of cases) {
        \\  const sentinel = {};
        \\  const throwing = new Proxy(function () {}, {get(t, key, r) {
        \\    if (key === "prototype") throw sentinel;
        \\    return Reflect.get(t, key, r);
        \\  }});
        \\  try { Reflect.construct(WebAssembly[name], args, throwing); return name + " no throw"; }
        \\  catch(e) { if (e !== sentinel) return name + " changed exception"; }
        \\  let revoke;
        \\  const target = Proxy.revocable(function () {}, {get(t, key, r) {
        \\    if (key === "prototype") { revoke(); return null; }
        \\    return Reflect.get(t, key, r);
        \\  }});
        \\  revoke = target.revoke;
        \\  try { Reflect.construct(WebAssembly[name], args, target.proxy); return name + " no revoked throw"; }
        \\  catch(e) { if (!(e instanceof TypeError)) return name + " wrong revoked error"; }
        \\}
    ++ ending);
}

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

const LifetimeRun = struct {
    failure: ?anyerror = null,

    fn thread(self: *LifetimeRun) void {
        self.measure() catch |err| {
            self.failure = err;
        };
    }

    fn collect(isolate: *ffi.Isolate) void {
        for (0..3) |_| ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }

    fn realm(isolate: *ffi.Isolate, touch_wasm: bool) !*ffi.Context {
        const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
        errdefer ffi.v8_Context_Dispose(context);
        ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
        if (touch_wasm) {
            ffi.v8_Context_Enter(context);
            defer ffi.v8_Context_Exit(context);
            try evaluate(isolate, context, "void WebAssembly; 'ok';");
        }
        return context;
    }

    fn measure(_: *LifetimeRun) !void {
        const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
        defer ffi.v8_Isolate_Dispose(isolate);
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        // Warm V8's API symbols and prove that the counters see a live realm.
        const warm = try realm(isolate, true);
        ffi.v8_Context_Dispose(warm);
        collect(isolate);
        var baseline: usize = 0;
        ffi.v8_Isolate_GetContextCounts(isolate, &baseline, null);
        const handles = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const held = try realm(isolate, false);
        var with_held: usize = 0;
        ffi.v8_Isolate_GetContextCounts(isolate, &with_held, null);
        ffi.v8_Context_Dispose(held);
        try std.testing.expect(with_held > baseline);
        // Both the pending lazy property and materialized adapters must die.
        for (0..64) |i| {
            const context = try realm(isolate, i % 2 == 0);
            ffi.v8_Context_Dispose(context);
        }
        collect(isolate);
        var after: usize = 0;
        ffi.v8_Isolate_GetContextCounts(isolate, &after, null);
        try std.testing.expectEqual(baseline, after);
        try std.testing.expect(ffi.v8_Isolate_GetGlobalHandleBytes(isolate) <= handles);
    }
};

test "wasm adapter private intrinsics die with their realm without handle growth" {
    try engine.initializeEngine(.{});
    var run: LifetimeRun = .{};
    const thread = try std.Thread.spawn(.{}, LifetimeRun.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

// (i32, i32) -> i32: import m.f, call it, write its result to exported g,
// then return it. g distinguishes a synchronous import from a suspension.
const jspi_prelude =
    \\(async () => {
    \\try {
    \\const bytes = new Uint8Array([0,97,115,109,1,0,0,0,
    \\ 1,7,1,96,2,127,127,1,127, 2,7,1,1,109,1,102,0,0,
    \\ 3,2,1,0, 6,6,1,127,1,65,0,11,
    \\ 7,9,2,1,102,0,1,1,103,3,0,
    \\ 10,14,1,12,0,32,0,32,1,16,0,36,0,35,0,11]);
    \\const module = new WebAssembly.Module(bytes);
    \\const make = f => new WebAssembly.Instance(module, {m:{f}});
;

test "wasm Suspending normal completion suspends and preserves this and arguments" {
    try check(jspi_prelude ++
        \\let calls = 0;
        \\const original = function(a,b) {
        \\  "use strict";
        \\  if (this !== undefined || arguments.length !== 2 || a !== 7 || b !== 8) throw Error("call changed");
        \\  calls++; return a + b;
        \\};
        \\const saved = original;
        \\const suspending = new WebAssembly.Suspending(original);
        \\const instance = make(suspending);
        \\const promise = WebAssembly.promising(instance.exports.f)(7,8);
        \\if (instance.exports.g.value !== 0) return "not suspended";
        \\if (await promise !== 15 || calls !== 1 || original !== saved) return "call result";
        \\const second = make(suspending);
        \\if (await WebAssembly.promising(second.exports.f)(7,8) !== 15 || calls !== 2) return "marker identity";
    ++ ending);
}

test "wasm Suspending preserves same-realm Promise identity and abrupt completion" {
    try check(jspi_prelude ++
        \\const original = Promise.resolve(23);
        \\Object.defineProperty(original, "then", {get() { throw Error("assimilated same promise"); }});
        \\const instance = make(new WebAssembly.Suspending(() => original));
        \\if (await WebAssembly.promising(instance.exports.f)(0,0) !== 23) return "promise changed";
        \\const sentinel = {};
        \\const throwing = make(new WebAssembly.Suspending(() => {throw sentinel;}));
        \\try { await WebAssembly.promising(throwing.exports.f)(0,0); return "did not throw"; }
        \\catch(e) { if(e !== sentinel) return "throw changed"; }
    ++ ending);
}

test "wasm Suspending resolves through the import realm intrinsics after tampering" {
    try check(jspi_prelude ++
        \\other.p = other.Promise.resolve(29);
        \\Object.defineProperty(other.p, "then", {get() { throw Error("wrong realm Promise"); }});
        \\const original = new other.Function("return globalThis.p");
        \\const suspending = new WebAssembly.Suspending(original);
        \\const instance = make(suspending);
        \\other.Promise.resolve = () => {throw Error("mutable resolve");};
        \\other.Promise = function() {throw Error("mutable Promise");};
        \\if (await WebAssembly.promising(instance.exports.f)(0,0) !== 29) return "realm result";
    ++ ending);
}

test "wasm Suspending preserves native export rejection and leaves native calls intact" {
    try check(jspi_prelude ++
        \\const direct = make((a,b) => a+b);
        \\if (direct.exports.f(11,12) !== 23) return "native result";
        \\const sentinel = {};
        \\const throwing = make(() => {throw sentinel;});
        \\try { throwing.exports.f(0,0); return "missing native throw"; }
        \\catch(e) { if (e !== sentinel) return "native throw changed"; }
        \\const trap = new WebAssembly.Instance(new WebAssembly.Module(new Uint8Array([
        \\ 0,97,115,109,1,0,0,0,1,7,1,96,2,127,127,1,127,3,2,1,0,
        \\ 7,5,1,1,102,0,0,10,5,1,3,0,0,11])));
        \\try { trap.exports.f(0,0); return "missing trap"; }
        \\catch(e) { if (!(e instanceof WebAssembly.RuntimeError)) return "trap changed"; }
        \\// Linked V8 13.1.203 rejects these before creating a marker. Do
        \\// not bypass that check by hiding a native export behind a Proxy.
        \\for (const f of [direct.exports.f, throwing.exports.f, trap.exports.f]) {
        \\  try { new WebAssembly.Suspending(f); return "native export accepted"; }
        \\  catch(e) { if (!(e instanceof TypeError)) return "native export error"; }
        \\}
    ++ ending);
}

test "wasm Suspending interface shape and revoked callable remain native" {
    try check(jspi_prelude ++
        \\const ctor = WebAssembly.Suspending;
        \\const descriptor = Object.getOwnPropertyDescriptor(WebAssembly, "Suspending");
        \\if (ctor.prototype.constructor !== ctor || ctor.name !== "Suspending" || ctor.length !== 1) return "constructor shape";
        \\if (!descriptor.writable || descriptor.enumerable || !descriptor.configurable) return "namespace shape";
        \\try { ctor(() => {}); return "no new"; } catch(e) { if (!(e instanceof TypeError)) return "no-new error"; }
        \\const revocable = Proxy.revocable(() => {}, {});
        \\revocable.revoke();
        \\const marker = new ctor(revocable.proxy);
        \\const instance = make(marker);
        \\try { await WebAssembly.promising(instance.exports.f)(0,0); return "revoked call succeeded"; }
        \\catch(e) { if (!(e instanceof TypeError)) return "revoked error"; }
    ++ ending);
}

test "wasm Exception stack is a branded prototype getter over captured state" {
    try check(
        \\(() => {
        \\try {
        \\const ctor = WebAssembly.Exception;
        \\const descriptor = Object.getOwnPropertyDescriptor(ctor.prototype, "stack");
        \\if (!descriptor || !descriptor.enumerable || !descriptor.configurable || descriptor.set !== undefined) return "stack descriptor";
        \\const get = descriptor.get;
        \\if (get.name !== "get stack" || get.length !== 0) return "getter shape";
        \\const tag = new WebAssembly.Tag({parameters:["i32"]});
        \\const untraced = new ctor(tag,[7]);
        \\if (get.call(untraced) !== undefined || Object.hasOwn(untraced,"stack")) return "untraced stack";
        \\let reads = 0;
        \\const exn = new ctor(tag,[8],{get traceStack() { reads++; return true; }});
        \\if (reads !== 1 || Object.hasOwn(exn,"stack")) return "traceStack order";
        \\const stack = get.call(exn);
        \\if (typeof stack !== "string") return "native trace lost";
        \\Object.defineProperty(exn,"stack",{value:"replacement",configurable:true});
        \\if (get.call(exn) !== stack) return "mutable stack read";
        \\for (const receiver of [{}, Object.create(ctor.prototype), undefined, new Error()]) {
        \\  try { get.call(receiver); return "unbranded receiver"; }
        \\  catch(e) { if (!(e instanceof TypeError)) return "brand error"; }
        \\}
        \\try { new get(); return "constructible getter"; }
        \\catch(e) { if (!(e instanceof TypeError)) return "constructor error"; }
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\})()
    );
}

test "wasm Exception keeps constructor shape prototype ordering and native throws" {
    try check(
        \\(() => {
        \\try {
        \\const ctor = WebAssembly.Exception;
        \\const tag = new WebAssembly.Tag({parameters:[]});
        \\if (ctor.length !== 1 || ctor.name !== "Exception" || ctor.prototype.constructor !== ctor) return "constructor shape";
        \\const namespace = Object.getOwnPropertyDescriptor(WebAssembly,"Exception");
        \\if (!namespace.writable || namespace.enumerable || !namespace.configurable) return "namespace shape";
        \\try { ctor(tag,[]); return "no new"; } catch(e) { if (!(e instanceof TypeError)) return "no-new error"; }
        \\const order = [];
        \\const prototype = {};
        \\const target = new Proxy(function(){}, {get(t,k,r) {
        \\  if(k === "prototype") { order.push("prototype"); return prototype; }
        \\  return Reflect.get(t,k,r);
        \\}});
        \\const made = Reflect.construct(ctor,[tag,[],{get traceStack() {order.push("traceStack"); return true;}}],target);
        \\if (Object.getPrototypeOf(made) !== prototype || order.join() !== "prototype,traceStack") return "prototype/order " + order;
        \\const foreign = new other.Function(); foreign.prototype = null;
        \\const intrinsic = other.WebAssembly.Exception.prototype;
        \\other.WebAssembly.Exception = function() {throw Error("mutable constructor");};
        \\if (Object.getPrototypeOf(Reflect.construct(ctor,[tag,[]],foreign)) !== intrinsic) return "foreign intrinsic";
        \\const sentinel = {};
        \\try { new ctor(tag,[],{get traceStack() {throw sentinel;}}); return "missing trace throw"; }
        \\catch(e) { if(e !== sentinel) return "changed trace throw"; }
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\})()
    );
}

test "wasm Exception trace capture never calls user stack formatting hooks" {
    try check(
        \\(() => {
        \\const old = Object.getOwnPropertyDescriptor(Error, "prepareStackTrace");
        \\const oldName = Object.getOwnPropertyDescriptor(Error.prototype, "name");
        \\const oldMessage = Object.getOwnPropertyDescriptor(Error.prototype, "message");
        \\try {
        \\let calls = 0;
        \\Object.defineProperty(Error,"prepareStackTrace",{configurable:true,get(){calls++;throw "formatter getter";}});
        \\for (const key of ["name","message"]) Object.defineProperty(Error.prototype,key,{configurable:true,get(){calls++;throw "Error prototype getter";}});
        \\const tag = new WebAssembly.Tag({parameters:[]});
        \\function wj1Capture() { return new WebAssembly.Exception(tag, [], {traceStack:true}); }
        \\const traced = wj1Capture();
        \\const get = Object.getOwnPropertyDescriptor(WebAssembly.Exception.prototype,"stack").get;
        \\const stack = get.call(traced);
        \\if (typeof stack !== "string" || !stack.includes("wj1Capture") || calls !== 0) return "formatter invoked or trace lost";
        \\if (get.call(traced) !== stack) return "trace changed";
        \\return "ok";
        \\} catch { return "unexpected throw"; }
        \\finally {
        \\  if(old) Object.defineProperty(Error,"prepareStackTrace",old); else delete Error.prepareStackTrace;
        \\  Object.defineProperty(Error.prototype,"name",oldName);
        \\  Object.defineProperty(Error.prototype,"message",oldMessage);
        \\}
        \\})()
    );
}

test "wasm ordinary constructors ignore replaced reflection and argument iterators" {
    try check(
        \\(() => {
        \\const reflect = Reflect.construct;
        \\const iterator = Array.prototype[Symbol.iterator];
        \\const moduleConstructor = WebAssembly.Module;
        \\const instanceConstructor = WebAssembly.Instance;
        \\const globalConstructor = WebAssembly.Global;
        \\const bytes = new Uint8Array([0,97,115,109,1,0,0,0]);
        \\try {
        \\Reflect.construct = () => {throw "mutable reflect";};
        \\Array.prototype[Symbol.iterator] = () => {throw "argument iterator";};
        \\const module = new moduleConstructor(bytes);
        \\const instance = new instanceConstructor(module);
        \\const global = new globalConstructor({value:"i32"},42);
        \\if (!(module instanceof moduleConstructor) || !(instance instanceof instanceConstructor) || global.value !== 42) return "ordinary construction";
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\finally { Reflect.construct = reflect; Array.prototype[Symbol.iterator] = iterator; }
        \\})()
    );
}

test "wasm constructor forwarding closures stay private in stack call sites" {
    try check(
        \\(() => {
        \\const old = Object.getOwnPropertyDescriptor(Error,"prepareStackTrace");
        \\try {
        \\let exposed = false;
        \\Error.prepareStackTrace = (_, frames) => {
        \\  for (const frame of frames) {
        \\    const fn = frame.getFunction();
        \\    if (fn && /cell\[0\]|newTarget !== (replacement|W)|currentDescriptor/.test(Function.prototype.toString.call(fn))) exposed = true;
        \\  }
        \\  return "formatted";
        \\};
        \\try { new WebAssembly.Module(new Uint8Array()); return "missing compile error"; }
        \\catch(e) { if (e.stack !== "formatted") return "stack formatter"; }
        \\return exposed ? "private closure exposed" : "ok";
        \\} catch(e) { return String(e); }
        \\finally { if(old) Object.defineProperty(Error,"prepareStackTrace",old); else delete Error.prepareStackTrace; }
        \\})()
    );
}

test "wasm descriptor forwarding ignores replaced Proxy and Reflect get" {
    try check(
        \\(() => {
        \\const proxy = globalThis.Proxy;
        \\const get = Reflect.get;
        \\try {
        \\globalThis.Proxy = function(){throw "mutable Proxy";};
        \\Reflect.get = function(){throw "mutable Reflect.get";};
        \\for (const C of [WebAssembly.Memory, WebAssembly.Table]) {
        \\  const descriptor = {address:"i32",element:"externref"};
        \\  Object.defineProperty(descriptor,"index",{value:"ignored"});
        \\  Object.defineProperty(descriptor,"initial",{get() {
        \\    if (this !== descriptor) throw "wrong receiver";
        \\    return 0;
        \\  }});
        \\  new C(descriptor);
        \\  const sentinel = {};
        \\  try { new C({element:"externref",get initial(){throw sentinel;}}); return "missing throw"; }
        \\  catch(e) { if (e !== sentinel) return "changed throw"; }
        \\}
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\finally { globalThis.Proxy = proxy; Reflect.get = get; }
        \\})()
    );
}

test "wasm descriptor forwarding restores outer state after nested construction and throws" {
    try check(
        \\(() => {
        \\try {
        \\for (const C of [WebAssembly.Memory, WebAssembly.Table]) {
        \\  for (const throws of [false,true]) {
        \\    let maximumRead = false;
        \\    const sentinel = {};
        \\    const outer = {element:"externref", address:"i64", get initial() {
        \\      if (this !== outer) throw "outer initial receiver";
        \\      try {
        \\        new WebAssembly.Memory({initial:0, get maximum() {
        \\          new WebAssembly.Table({element:"externref",initial:0});
        \\          if (throws) throw sentinel;
        \\          return 1;
        \\        }});
        \\        if (throws) throw "missing nested throw";
        \\      } catch(e) { if (!throws || e !== sentinel) throw e; }
        \\      return 0n;
        \\    }, get maximum() {
        \\      if (this !== outer) throw "outer maximum receiver";
        \\      maximumRead = true;
        \\      return 1n;
        \\    }};
        \\    new C(outer);
        \\    if (!maximumRead) return "outer descriptor lost";
        \\    new C({element:"externref",initial:0});
        \\  }
        \\}
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\})()
    );
}

test "wasm exposed constructors preserve instanceof and bound newTarget replacement" {
    try check(
        \\(() => {
        \\try {
        \\const bytes = new Uint8Array([0,97,115,109,1,0,0,0]);
        \\const module = new WebAssembly.Module(bytes);
        \\const tag = new WebAssembly.Tag({parameters:[]});
        \\for (const [name,args] of [["Module",[bytes]],["Instance",[module]],
        \\  ["Memory",[{initial:0}]],["Table",[{element:"externref",initial:0}]],
        \\  ["Global",[{value:"i32"},42]],["Exception",[tag,[]]]]) {
        \\  const C = WebAssembly[name];
        \\  const original = wj1OriginalWasm[name];
        \\  if (Object.getPrototypeOf(C) !== Object.getPrototypeOf(original)) return name + " constructor prototype";
        \\  if (Reflect.ownKeys(C).join() !== Reflect.ownKeys(original).join()) return name + " own keys";
        \\  for (const key of Reflect.ownKeys(original)) {
        \\    const actual = Object.getOwnPropertyDescriptor(C,key);
        \\    const expected = Object.getOwnPropertyDescriptor(original,key);
        \\    for (const field of Reflect.ownKeys(expected)) if (actual[field] !== expected[field]) return name + " descriptor " + key + "." + field;
        \\  }
        \\  const bound = C.bind(undefined);
        \\  const made = Reflect.construct(C,args);
        \\  const viaBound = Reflect.construct(bound,args);
        \\  if (!(made instanceof C) || !(made instanceof bound) || !(viaBound instanceof C)) return name + " instanceof";
        \\  if (!Function.prototype[Symbol.hasInstance].call(C,made)) return name + " OrdinaryHasInstance";
        \\  if (!Function.prototype[Symbol.hasInstance].call(C,Object.create(C.prototype))) return name + " prototype-only instanceof";
        \\  const foreign = Reflect.construct(other.WebAssembly[name],args);
        \\  for (const value of [made,foreign,Object.create(C.prototype),Object.create(other.WebAssembly[name].prototype),{},null,42]) {
        \\    if (Function.prototype[Symbol.hasInstance].call(C,value) !== Function.prototype[Symbol.hasInstance].call(original,value)) return name + " native hasInstance difference";
        \\  }
        \\  if (made instanceof other.WebAssembly[name] || foreign instanceof C || !(foreign instanceof other.WebAssembly[name])) return name + " cross-realm instanceof";
        \\  if (Object.getPrototypeOf(viaBound) !== C.prototype) return name + " bound newTarget";
        \\  if (Object.getPrototypeOf(Reflect.construct(C,args,bound)) !== C.prototype) return name + " bound realm fallback";
        \\  class X extends C { constructor() { super(...args); } }
        \\  const child = new X();
        \\  if (!(child instanceof X) || !(child instanceof C) || Object.getPrototypeOf(child) !== X.prototype) return name + " subclass";
        \\  Object.defineProperty(C,Symbol.hasInstance,{configurable:true,value:()=>false});
        \\  try { if (made instanceof C || made instanceof bound) return name + " custom hasInstance"; }
        \\  finally { delete C[Symbol.hasInstance]; }
        \\}
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\})()
    );
}

test "wasm constructor argument counts match native under poisoned argument helpers" {
    try check(
        \\(() => {
        \\const construct = Reflect.construct;
        \\const apply = Reflect.apply;
        \\const functionApply = Function.prototype.apply;
        \\const slice = Array.prototype.slice;
        \\const iterator = Array.prototype[Symbol.iterator];
        \\const species = Object.getOwnPropertyDescriptor(Array,Symbol.species);
        \\const bytes = new Uint8Array([0,97,115,109,1,0,0,0]);
        \\const module = new WebAssembly.Module(bytes);
        \\const tag = new WebAssembly.Tag({parameters:[]});
        \\const cases = [];
        \\for (const [name,first,second] of [["Module",bytes,undefined],["Instance",module,undefined],
        \\  ["Memory",{initial:0},undefined],["Table",{element:"externref",initial:0},undefined],
        \\  ["Global",{value:"i32"},42],["Exception",tag,[]]]) {
        \\  for (const count of [0,1,2,3,8]) {
        \\    const args = [first,second,undefined,Symbol(),{},null,7,8].slice(0,count);
        \\    let expectedError, expectedPrototype;
        \\    try { expectedPrototype = Object.getPrototypeOf(construct(wj1OriginalWasm[name],args)); }
        \\    catch(e) { expectedError = e.constructor; }
        \\    cases.push({name,args,expectedError,expectedPrototype});
        \\  }
        \\}
        \\try {
        \\const poison = () => {throw "mutable argument helper";};
        \\Reflect.construct = Reflect.apply = Function.prototype.apply = Array.prototype.slice = poison;
        \\Array.prototype[Symbol.iterator] = poison;
        \\Object.defineProperty(Array,Symbol.species,{configurable:true,get:poison});
        \\for (let i = 0; i < cases.length; i++) {
        \\  const c = cases[i], C = WebAssembly[c.name];
        \\  function Target() {}
        \\  Target.prototype = C.prototype;
        \\  for (let custom = 0; custom < 2; custom++) {
        \\    let error, made;
        \\    try { made = construct(C,c.args,custom ? Target : C); }
        \\    catch(e) { error = e.constructor; }
        \\    if (error !== c.expectedError) return c.name + " error at count " + c.args.length;
        \\    if (!error && Object.getPrototypeOf(made) !== c.expectedPrototype) return c.name + " prototype at count " + c.args.length;
        \\  }
        \\}
        \\const plain = new WebAssembly.Exception(tag,[]);
        \\if (plain.stack !== undefined) return "plain exception stack";
        \\const traced = new WebAssembly.Exception(tag,[],{traceStack:true});
        \\if (typeof traced.stack !== "string") return "traced exception arguments";
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\finally {
        \\  Reflect.construct = construct; Reflect.apply = apply; Function.prototype.apply = functionApply;
        \\  Array.prototype.slice = slice; Array.prototype[Symbol.iterator] = iterator;
        \\  Object.defineProperty(Array,Symbol.species,species);
        \\}
        \\})()
    );
}

fn expectWasmInstalled(global: *ffi.Object, expected: bool) !void {
    const key = "crane.wasm.intrinsicPrototypes";
    const value = ffi.v8_Object_GetPrivateRef(global, key.ptr, key.len);
    defer if (value) |held| ffi.v8_Value_Dispose(held);
    try std.testing.expectEqual(expected, value != null);
}

fn checkLazyWasm(source: []const u8, installed_after: bool) !void {
    try engine.initializeEngine(.{});
    const LazyRun = struct {
        source: []const u8,
        installed_after: bool,
        failure: ?anyerror = null,

        fn body(self: *@This()) !void {
            const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
            defer ffi.v8_Isolate_Dispose(isolate);
            ffi.v8_Isolate_Enter(isolate);
            defer ffi.v8_Isolate_Exit(isolate);
            const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
            defer ffi.v8_Context_Dispose(context);
            ffi.v8_Context_Enter(context);
            defer ffi.v8_Context_Exit(context);
            const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
            defer ffi.v8_Object_Dispose(global);
            try evaluate(isolate, context,
                \\globalThis.wj1NativeNamespace = WebAssembly;
                \\globalThis.wj1NativeModule = WebAssembly.Module;
                \\globalThis.wj1NativeDescriptor = Object.getOwnPropertyDescriptor(globalThis,"WebAssembly");
                \\"ok";
            );
            ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
            // Probe the existing traced slot, without reading the namespace
            // or adding a production counter/root just for the test.
            try expectWasmInstalled(global, false);
            try evaluate(isolate, context, self.source);
            try expectWasmInstalled(global, self.installed_after);
        }

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: LazyRun = .{ .source = source, .installed_after = installed_after };
    const thread = try std.Thread.spawn(.{}, LazyRun.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "untouched wasm namespace does not initialize its adapters" {
    try checkLazyWasm("const unused = 1 + 1; 'ok';", false);
}

test "wasm namespace deletion and overwrite before first read stay lazy" {
    try checkLazyWasm(
        \\(() => {
        \\if (!delete globalThis.WebAssembly) return "delete";
        \\if (Object.hasOwn(globalThis,"WebAssembly")) return "still present";
        \\return "ok";
        \\})()
    , false);
    try checkLazyWasm(
        \\(() => {
        \\const sentinel = {};
        \\globalThis.WebAssembly = sentinel;
        \\if (WebAssembly !== sentinel) return "overwrite";
        \\const d = Object.getOwnPropertyDescriptor(globalThis,"WebAssembly");
        \\if (d.value !== sentinel || !d.writable || d.enumerable || !d.configurable || "get" in d) return "descriptor";
        \\return "ok";
        \\})()
    , false);
}

test "wasm lazy first descriptor read preserves data attributes and installs once" {
    try checkLazyWasm(
        \\(() => {
        \\const d = Object.getOwnPropertyDescriptor(globalThis,"WebAssembly");
        \\for (const key of ["writable","enumerable","configurable"]) if (d[key] !== wj1NativeDescriptor[key]) return key;
        \\if ("get" in d || "set" in d || d.value !== wj1NativeNamespace) return "not native data";
        \\const first = d.value.Module;
        \\if (first === wj1NativeModule) return "not adapted";
        \\if (Object.getOwnPropertyDescriptor(globalThis,"WebAssembly").value.Module !== first || WebAssembly.Module !== first) return "installed twice";
        \\const g = new WebAssembly.Global({value:"i32",mutable:true},42);
        \\Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype,"value").set.call(g);
        \\return g.value === 0 ? "ok" : "setter";
        \\})()
    , true);
}

test "wasm lazy installation captures helpers before script can replace them" {
    try checkLazyWasm(
        \\(() => {
        \\const O=Object,R=Reflect,P=Proxy,T=TypeError,F=Function,A=Array,S=Symbol,Pr=Promise;
        \\const define=O.defineProperty,desc=O.getOwnPropertyDescriptor,setProto=O.setPrototypeOf,getProto=O.getPrototypeOf;
        \\const construct=R.construct,get=R.get,apply=R.apply,keys=R.ownKeys,bind=F.prototype.bind,slice=A.prototype.slice,resolve=Pr.resolve;
        \\const iterator=A.prototype[S.iterator];
        \\const bytes=new Uint8Array([0,97,115,109,1,0,0,0]);
        \\const poison=()=>{throw "mutable initialization helper";};
        \\try {
        \\O.defineProperty=O.getOwnPropertyDescriptor=O.setPrototypeOf=O.getPrototypeOf=poison;
        \\R.construct=R.get=R.apply=R.ownKeys=poison;
        \\F.prototype.bind=A.prototype.slice=Pr.resolve=poison;
        \\O.prototype.get=O.prototype.set=poison;
        \\A.prototype[S.iterator]=poison;
        \\globalThis.Object=globalThis.Reflect=globalThis.Proxy=globalThis.TypeError=globalThis.Function=globalThis.Array=globalThis.Symbol=globalThis.Promise=poison;
        \\const wasm=WebAssembly;
        \\const m=new wasm.Module(bytes);
        \\if (getProto(m)!==wasm.Module.prototype) return "module";
        \\new wasm.Memory({initial:0});
        \\return "ok";
        \\} catch(e) { return String(e); }
        \\finally {
        \\delete O.prototype.get;delete O.prototype.set;
        \\A.prototype[S.iterator]=iterator;
        \\globalThis.Object=O;globalThis.Reflect=R;globalThis.Proxy=P;globalThis.TypeError=T;globalThis.Function=F;globalThis.Array=A;globalThis.Symbol=S;globalThis.Promise=Pr;
        \\O.defineProperty=define;O.getOwnPropertyDescriptor=desc;O.setPrototypeOf=setProto;O.getPrototypeOf=getProto;
        \\R.construct=construct;R.get=get;R.apply=apply;R.ownKeys=keys;F.prototype.bind=bind;A.prototype.slice=slice;Pr.resolve=resolve;
        \\}
        \\})()
    , true);
}

test "wasm prototype fallback initializes an untouched realm after namespace deletion" {
    try check(
        \\(() => {
        \\const make = other.Function("return function Target() {}")();
        \\make.prototype = null;
        \\delete other.WebAssembly;
        \\const made = Reflect.construct(WebAssembly.Module,[new Uint8Array([0,97,115,109,1,0,0,0])],make);
        \\if (Object.getPrototypeOf(made) !== other.wj1OriginalWasm.Module.prototype) return "foreign prototype";
        \\return Object.hasOwn(other,"WebAssembly") ? "recreated deleted property" : "ok";
        \\})()
    );
}

test "wasm lazy first read from another realm creates adapters in the owning realm" {
    try check(
        \\(() => {
        \\const wasm = Reflect.get(other,"WebAssembly",{});
        \\const stack = Object.getOwnPropertyDescriptor(wasm.Exception.prototype,"stack").get;
        \\const setter = Object.getOwnPropertyDescriptor(wasm.Global.prototype,"value").set;
        \\if (Object.getPrototypeOf(stack) !== other.Function.prototype || Object.getPrototypeOf(setter) !== other.Function.prototype) return "wrong adapter realm";
        \\const made = new wasm.Module(new Uint8Array([0,97,115,109,1,0,0,0]));
        \\if (Object.getPrototypeOf(made) !== other.wj1OriginalWasm.Module.prototype) return "wrong module realm";
        \\const d = Object.getOwnPropertyDescriptor(other,"WebAssembly");
        \\return d.value === wasm && d.writable && d.configurable && !d.enumerable && !("get" in d) ? "ok" : "foreign descriptor";
        \\})()
    );
}

test "wasm module received before namespace access preserves constructor identity" {
    try engine.initializeEngine(.{});
    const ReceiveRun = struct {
        fn thread(failure: *?anyerror) void {
            inPlatformRealm(
                \\(() => {
                \\const foreign = new other.WebAssembly.Module(new Uint8Array([0,97,115,109,1,0,0,0]));
                \\const received = structuredClone(foreign);
                \\const constructor = received.constructor;
                \\return constructor === WebAssembly.Module ? "ok" : "received constructor changed on namespace access";
                \\})()
            , .window, false) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, ReceiveRun.thread, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// The serialization and deserialization operations used by worker postMessage,
/// with a fresh receiving agent whose script has never read WebAssembly.
const FirstWasmDelivery = struct {
    const Kind = enum { module, memory, plain, shared_buffer };

    fn cluster(_: ?*anyopaque, _: runtime.Context) u64 {
        return 116;
    }
    fn isolated(_: ?*anyopaque, _: runtime.Context) bool {
        return true;
    }
    const hooks: engine.HostHooks = .{
        .agentClusterOf = cluster,
        .crossOriginIsolatedCapability = isolated,
    };
    const reporter: engine.Reporter = .{ .report = report, .host = null };
    fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
    fn noTransfer(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
        return .not_transferable;
    }

    fn makeMessage(kind: Kind) !engine.SerializedWithTransfer {
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
        defer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://wj1.test",
            .create_global_object = WindowHost.create,
        });
        defer engine.destroyWindowRealm(realm, .global_detached);
        const source = switch (kind) {
            .module => "({payload:new WebAssembly.Module(new Uint8Array([0,97,115,109,1,0,0,0]))})",
            .memory => "({payload:new WebAssembly.Memory({initial:1,maximum:2,shared:true})})",
            .plain => "({payload:{answer:42}})",
            .shared_buffer => "({payload:new SharedArrayBuffer(8)})",
        };
        const subject = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "wj1-first-delivery.js", null, reporter);
        defer subject.release();
        const Serialize = struct {
            realm: runtime.Context,
            value: runtime.JSValue,
            result: ?engine.SerializedWithTransfer = null,
            fn steps(data: ?*anyopaque) engine.Error!void {
                const self: *@This() = @ptrCast(@alignCast(data.?));
                self.result = try engine.structuredSerializeWithTransfer(self.realm, self.value, &.{}, noTransfer, null, std.testing.allocator);
            }
        };
        var call: Serialize = .{ .realm = realm, .value = subject.value };
        if (try engine.completionOf(realm, Serialize.steps, &call)) |thrown| {
            thrown.release();
            return error.SerializationFailed;
        }
        return call.result orelse error.NoSerialization;
    }

    const Delivery = struct {
        realm: runtime.Context,
        message: *const engine.SerializedWithTransfer,
        fn read(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const result = engine.structuredDeserializeWithOptions(self.realm, self.message.serialized, .{
                .array_buffers = self.message.array_buffers,
                .shared_memory = self.message.shared_memory,
            }) catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                else => error.DataCloneError,
            };
            return result.take();
        }
    };

    fn body(kind: Kind) !void {
        runtime.initializeRuntime(std.heap.page_allocator);
        interfaces.process_hooks.startHooksForTest();
        try v8.context_manager.init(std.testing.allocator);
        defer v8.context_manager.deinit();
        var message = try makeMessage(kind);
        defer message.deinit(std.testing.allocator);
        // The sender is already destroyed. The message retains bytes/backing
        // stores only, exactly as a queued worker message does.
        const agent = try engine.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
        defer engine.destroyAgent(agent);
        const realm = (try engine.createWorkerRealm(agent, &.{
            .url = "https://wj1.test/receiver.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .allocator = std.testing.allocator,
        })).realm;
        defer engine.destroyWorkerRealm(realm, null, null);
        var delivery: Delivery = .{ .realm = realm, .message = &message };
        const builtin: engine.BuiltinFunction = .{ .steps = Delivery.read, .data = &delivery };
        try engine.defineBuiltinFunction(realm, "receive", 0, &builtin);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const context: *ffi.Context = @ptrCast(@alignCast(realm.engine_ctx.?));
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        ffi.v8_Context_Enter(context);
        defer ffi.v8_Context_Exit(context);
        const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
        defer ffi.v8_Object_Dispose(global);
        try expectWasmInstalled(global, false);
        const source = switch (kind) {
            .module => "const received=receive().payload; const ctor=received.constructor; ctor===WebAssembly.Module ? 'ok' : 'received Module constructor changed'",
            .memory => "const received=receive().payload; const ctor=received.constructor; ctor===WebAssembly.Memory ? 'ok' : 'received Memory constructor changed'",
            .plain => "receive().payload.answer===42 ? 'ok' : 'plain value'",
            .shared_buffer => "receive().payload.byteLength===8 ? 'ok' : 'shared buffer'",
        };
        try evaluate(isolate, context, source);
        try expectWasmInstalled(global, kind == .module or kind == .memory);
    }

    fn check(comptime kind: Kind) !void {
        try engine.initializeEngine(.{});
        const RunDelivery = struct {
            fn thread(failure: *?anyerror) void {
                body(kind) catch |err| {
                    failure.* = err;
                };
            }
        };
        var failure: ?anyerror = null;
        const thread = try std.Thread.spawn(.{}, RunDelivery.thread, .{&failure});
        thread.join();
        if (failure) |err| return err;
    }
};

test "worker receives a Module before namespace access with stable constructor" {
    try FirstWasmDelivery.check(.module);
}
test "worker receives shared Wasm Memory before namespace access with stable constructor" {
    try FirstWasmDelivery.check(.memory);
}
test "worker receives plain data without initializing Wasm" {
    try FirstWasmDelivery.check(.plain);
}
test "worker receives a SharedArrayBuffer without initializing Wasm" {
    try FirstWasmDelivery.check(.shared_buffer);
}

test "received Wasm prototype constructor overwrite and delete stay lazy" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "const sentinel={}; p.constructor=sentinel; const d=Object.getOwnPropertyDescriptor(p,'constructor');" ++
            "return d.value===sentinel && d.writable && d.configurable && !d.enumerable && !('get' in d) ? 'ok' : 'overwrite'; })()", false);
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "return delete p.constructor && !Object.hasOwn(p,'constructor') ? 'ok' : 'delete'; })()", false);
    }
}

test "received Wasm prototype constructor mutations survive namespace initialization" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "const sentinel={}; p.constructor=sentinel; void WebAssembly;" ++
            "return p.constructor===sentinel ? 'ok' : 'lost overwrite'; })()", true);
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "delete p.constructor; void WebAssembly;" ++
            "return !Object.hasOwn(p,'constructor') ? 'ok' : 'recreated constructor'; })()", true);
    }
}

test "received Wasm prototype constructor redefinitions survive namespace initialization" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "let calls=0; const getter=()=>{++calls; return 42;};" ++
            "Object.defineProperty(p,'constructor',{get:getter,configurable:true}); void WebAssembly;" ++
            "return calls===0 && Object.getOwnPropertyDescriptor(p,'constructor').get===getter ? 'ok' : 'lost accessor'; })()", true);
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype; const sentinel={};" ++
            "Object.defineProperty(p,'constructor',{value:sentinel,writable:false,enumerable:true,configurable:false});" ++
            "const ns=WebAssembly; const d=Object.getOwnPropertyDescriptor(p,'constructor');" ++
            "return typeof ns." ++ name ++ "==='function' && d.value===sentinel && !d.writable && d.enumerable && !d.configurable ? 'ok' : 'lost fixed descriptor'; })()", true);
    }
}

test "received Wasm prototype constructor descriptor first access is ordinary data" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype;" ++
            "const d=Object.getOwnPropertyDescriptor(p,'constructor'); const ns=WebAssembly;" ++
            "return d.value===ns." ++ name ++ " && d.writable && d.configurable && !d.enumerable && !('get' in d) && !('set' in d) ? 'ok' : 'constructor descriptor'; })()", true);
    }
}

test "namespace first access agrees with received Wasm prototype constructors" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const p=wj1NativeNamespace." ++ name ++ ".prototype; const ns=WebAssembly;" ++
            "return p.constructor===ns." ++ name ++ " && Object.getOwnPropertyDescriptor(p,'constructor').value===ns." ++ name ++ " ? 'ok' : 'namespace first'; })()", true);
    }
}

test "foreign first access to a received Wasm prototype constructor uses its owning realm" {
    inline for (.{ "Module", "Memory" }) |name| {
        try check("(() => { const p=other.wj1OriginalWasm." ++ name ++ ".prototype;" ++
            "const ctor=Reflect.get(p,'constructor',{});" ++
            "return Object.getPrototypeOf(ctor)===other.Function.prototype && ctor===other.WebAssembly." ++ name ++ " ? 'ok' : 'foreign constructor'; })()");
    }
}

test "received Wasm prototype constructors ignore later namespace replacements" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const ns=WebAssembly; const ctor=ns." ++ name ++ ";" ++
            "ns." ++ name ++ "=function sentinel(){};" ++
            "return ctor.prototype.constructor===ctor ? 'ok' : 'mutable namespace constructor'; })()", true);
    }
}

test "received Wasm prototype constructors initialize after namespace deletion" {
    inline for (.{ "Module", "Memory" }) |name| {
        try checkLazyWasm("(() => { const ns=wj1NativeNamespace; const p=ns." ++ name ++ ".prototype;" ++
            "delete globalThis.WebAssembly; const ctor=p.constructor;" ++
            "return ctor===ns." ++ name ++ " && !Object.hasOwn(globalThis,'WebAssembly') ? 'ok' : 'deleted namespace'; })()", true);
    }
}
