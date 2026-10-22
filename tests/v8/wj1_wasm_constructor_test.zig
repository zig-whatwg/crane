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

    fn realm(isolate: *ffi.Isolate) !*ffi.Context {
        const context = ffi.v8_Context_New(isolate) orelse return error.NoContext;
        ffi.v8_WebAssembly_InstallAddressDescriptors(isolate, context);
        return context;
    }

    fn measure(_: *LifetimeRun) !void {
        const isolate = ffi.v8_Isolate_New() orelse return error.NoIsolate;
        defer ffi.v8_Isolate_Dispose(isolate);
        ffi.v8_Isolate_Enter(isolate);
        defer ffi.v8_Isolate_Exit(isolate);
        // Warm V8's API symbols and prove that the counters see a live realm.
        const warm = try realm(isolate);
        ffi.v8_Context_Dispose(warm);
        collect(isolate);
        var baseline: usize = 0;
        ffi.v8_Isolate_GetContextCounts(isolate, &baseline, null);
        const handles = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        const held = try realm(isolate);
        var with_held: usize = 0;
        ffi.v8_Isolate_GetContextCounts(isolate, &with_held, null);
        ffi.v8_Context_Dispose(held);
        try std.testing.expect(with_held > baseline);
        for (0..64) |_| {
            const context = try realm(isolate);
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
