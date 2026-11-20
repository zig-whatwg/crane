//! A Window realm's interface objects (WebIDL 3.7, "exposed"; 3.3.13
//! [SecureContext]) and what an isolate makes for them (lane tmpl1).
//!
//! WebIDL 3.7: "For every interface that is exposed in a given realm ... a
//! corresponding property exists on the realm's global object" - and for one
//! that is not, none does. "Exposed" step 1: an interface whose exposure set
//! is not * and names no interface the global implements is not exposed: a
//! Window has no WorkerGlobalScope, FileReaderSync or FetchEvent (Chrome 157,
//! Firefox 160 and Safari 27.2 expose none: wpt.fyi 2358bd4835,
//! html/dom/idlharness.https.html, service-workers/idlharness.https.any.html,
//! FileAPI/idlharness.html). Step 2: a [SecureContext] construct is exposed
//! only in a realm whose settings object is a secure context.
//!
//! Each property is the interface object - a function with a `prototype`
//! object, the inherited interface's interface object its [[Prototype]] and
//! the inherited prototype its prototype's (3.7.1, 3.7.3) - writable,
//! configurable and not enumerable (3.7). Checked for EVERY Window-exposed
//! interface in every kind of Window realm - a page's, a frame's, a
//! navigated frame's, a popup's, one that is not a secure context - restored
//! from the build's snapshot and made without it. Every name is read, so
//! every lazily built interface object is built: lane maj3's first [Exposed]
//! change lost ~7,700 WPT subtests in iframe and window files (html/dom/
//! idlharness ERROR "Cannot read properties of undefined (reading
//! 'prototype')") while its native test, run without the snapshot, passed.
//!
//! And what the isolate makes: one template per interface, made when a realm
//! first needs it (Blink's V8PerIsolateData::FindV8Template, from
//! WrapperTypeInfo::GetV8ClassTemplate, Chromium
//! platform/bindings/wrapper_type_info.cc) - never all of them for a realm
//! that reads none.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const v8 = @import("v8");
const ffi = v8.ffi;
const helpers = @import("webidl").helpers;
/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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

fn evaluate(r: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    errdefer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expectEval(r: runtime.Context, source: []const u8, want: []const u8) !void {
    const got = try evaluate(r, source);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, want)) std.debug.print("{s}\n  -> {s}\n", .{ source[0..@min(source.len, 200)], got });
    try testing.expectEqualStrings(want, got);
}

/// [SecureContext] on `T` or on an interface it inherits from (WebIDL
/// 3.3.13 forbids the one without the other; six WebXR IDL interfaces
/// break the rule - interface_bindings.isSecureContextOnly).
fn isSecureContextOnly(comptime T: type) bool {
    comptime {
        var Cur = T;
        var depth: usize = 0;
        while (depth < 32) : (depth += 1) {
            if (hasExtendedAttribute(Cur, "SecureContext")) return true;
            if (!@hasDecl(Cur.Meta, "ParentInterface")) return false;
            const Parent = Cur.Meta.ParentInterface;
            if (@TypeOf(Parent) != type or @typeInfo(Parent) != .@"struct" or !@hasDecl(Parent, "Meta")) return false;
            Cur = Parent;
        }
        return false;
    }
}

fn hasExtendedAttribute(comptime T: type, comptime attribute: []const u8) bool {
    comptime {
        if (!@hasDecl(T.Meta, "extended_attributes")) return false;
        for (T.Meta.extended_attributes) |attr| {
            if (std.mem.eql(u8, attr.name, attribute)) return true;
        }
        return false;
    }
}

/// Every interface the generated bindings define, as the JS array literal
/// `[[name, parent name or null, is a callback interface, is [SecureContext],
/// is exposed on Window, is exposed in a dedicated worker], ...]`.
const interface_table = blk: {
    @setEvalBranchQuota(50_000_000);
    var out: []const u8 = "[";
    for (@typeInfo(interfaces).@"struct".decl_names) |name| {
        const T = @field(interfaces, name);
        if (@TypeOf(T) != type or @typeInfo(T) != .@"struct" or !@hasDecl(T, "Meta")) continue;
        if (@hasDecl(T.Meta, "is_mixin") and T.Meta.is_mixin) continue;
        if (hasExtendedAttribute(T, "LegacyNamespace")) continue;
        if (v8.interface_bindings.shouldSkipInterface(name)) continue;
        const callback = @hasDecl(T.Meta, "is_callback_interface") and T.Meta.is_callback_interface;
        // A callback interface has an interface object only if it has
        // constants (WebIDL 3.7: "legacy callback interface object").
        if (callback and !@hasDecl(T.Meta, "constants")) continue;
        const parent: []const u8 = if (@hasDecl(T.Meta, "ParentInterface") and @TypeOf(T.Meta.ParentInterface) == type and
            @typeInfo(T.Meta.ParentInterface) == .@"struct" and @hasDecl(T.Meta.ParentInterface, "Meta"))
            "'" ++ T.Meta.ParentInterface.Meta.name ++ "'"
        else
            "null";
        out = out ++ "['" ++ name ++ "'," ++ parent ++ "," ++ (if (callback) "1" else "0") ++ "," ++
            (if (isSecureContextOnly(T)) "1" else "0") ++ "," ++
            (if (helpers.isExposedIn(T, .Window)) "1" else "0") ++ "," ++
            (if (helpers.isExposedIn(T, .DedicatedWorker)) "1" else "0") ++ "],";
    }
    break :blk out ++ "]";
};

/// The check, in a Window realm that is (`secure`) or is not a secure
/// context: "ok", or the first failures.
fn interfaceCheck(comptime secure: bool) []const u8 {
    return "const table = " ++ interface_table ++ ";\nconst SECURE = " ++ (if (secure) "true" else "false") ++ ";\n" ++
        \\(() => {
        \\  const bad = [];
        \\  let exposed = 0;
        \\  for (const [n, p, cb, sec, win, dw] of table) {
        \\    const has = Object.prototype.hasOwnProperty.call(globalThis, n);
        \\    if (!win || (sec && !SECURE)) { if (has) bad.push('present, not exposed: ' + n); continue; }
        \\    if (!has) { bad.push('missing ' + n); continue; }
        \\    exposed++;
        \\    const d = Object.getOwnPropertyDescriptor(globalThis, n);
        \\    if (!('value' in d) || !d.writable || d.enumerable || !d.configurable) bad.push('descriptor ' + n);
        \\    const f = globalThis[n];
        \\    if (typeof f !== 'function') { bad.push('no interface object ' + n); continue; }
        \\    if (cb) continue;
        \\    if (typeof f.prototype !== 'object' || f.prototype === null) { bad.push('no prototype ' + n); continue; }
        \\    // Window's prototype inherits from the named properties object.
        \\    if (p !== null && n !== 'Window') {
        \\      const parent = globalThis[p];
        \\      if (typeof parent !== 'function') { bad.push('no parent ' + p + ' of ' + n); continue; }
        \\      if (Object.getPrototypeOf(f) !== parent) bad.push('interface object [[Prototype]] ' + n);
        \\      if (Object.getPrototypeOf(f.prototype) !== parent.prototype) bad.push('prototype [[Prototype]] ' + n);
        \\    }
        \\  }
        \\  if (Object.getPrototypeOf(globalThis) !== Window.prototype) bad.push('the global is no Window');
        \\  if (!(globalThis instanceof EventTarget)) bad.push('the global is no EventTarget');
        \\  if (Object.getPrototypeOf(Window) !== EventTarget) bad.push('Window [[Prototype]]');
        \\  if (HTMLDocument !== Document) bad.push('HTMLDocument');
        \\  if (webkitURL !== URL) bad.push('webkitURL');
        \\  // [LegacyFactoryFunction]s: their prototype is the interface's (WebIDL 3.7.2).
        \\  if (Image.prototype !== HTMLImageElement.prototype || Image.name !== 'Image') bad.push('Image');
        \\  if (Option.prototype !== HTMLOptionElement.prototype || Audio.prototype !== HTMLAudioElement.prototype) bad.push('Option/Audio');
        \\  const made = new Document().implementation.createHTMLDocument('t');
        \\  if (Object.getPrototypeOf(made.body) !== HTMLBodyElement.prototype) bad.push('a wrapper of a new document');
        \\  if (exposed < 700) bad.push('only ' + exposed + ' exposed');
        \\  return bad.slice(0, 12).join('; ') || 'ok';
        \\})()
    ;
}

/// The same check in a dedicated worker's realm (`secure` or not).
fn workerInterfaceCheck(comptime secure: bool) []const u8 {
    return "const table = " ++ interface_table ++ ";\nconst SECURE = " ++ (if (secure) "true" else "false") ++ ";\n" ++
        \\(() => {
        \\  const bad = [];
        \\  let exposed = 0;
        \\  for (const [n, p, cb, sec, win, dw] of table) {
        \\    const has = Object.prototype.hasOwnProperty.call(globalThis, n);
        \\    if (!dw || (sec && !SECURE)) { if (has) bad.push('present, not exposed: ' + n); continue; }
        \\    if (!has) { bad.push('missing ' + n); continue; }
        \\    exposed++;
        \\    const d = Object.getOwnPropertyDescriptor(globalThis, n);
        \\    if (!('value' in d) || !d.writable || d.enumerable || !d.configurable) bad.push('descriptor ' + n);
        \\    const f = globalThis[n];
        \\    if (typeof f !== 'function') { bad.push('no interface object ' + n); continue; }
        \\    if (cb) continue;
        \\    if (typeof f.prototype !== 'object' || f.prototype === null) { bad.push('no prototype ' + n); continue; }
        \\    if (p !== null) {
        \\      const parent = globalThis[p];
        \\      if (typeof parent !== 'function') { bad.push('no parent ' + p + ' of ' + n); continue; }
        \\      if (Object.getPrototypeOf(f) !== parent) bad.push('interface object [[Prototype]] ' + n);
        \\      if (Object.getPrototypeOf(f.prototype) !== parent.prototype) bad.push('prototype [[Prototype]] ' + n);
        \\    }
        \\  }
        \\  if (!(globalThis instanceof DedicatedWorkerGlobalScope)) bad.push('the global is no DedicatedWorkerGlobalScope');
        \\  if (!(globalThis instanceof WorkerGlobalScope)) bad.push('the global is no WorkerGlobalScope');
        \\  for (const n of ['Window', 'Document', 'HTMLDocument', 'Image', 'webkitURL']) if (n in globalThis) bad.push('present on a worker: ' + n);
        \\  if (exposed < 200) bad.push('only ' + exposed + ' exposed');
        \\  return bad.slice(0, 12).join('; ') || 'ok';
        \\})()
    ;
}

/// The checks in every kind of Window realm of `agent`.
fn checkEveryRealmKind(agent: *protocol.Agent, from_snapshot: bool) !void {
    const page = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = "https://tmpl1.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(page, .global_detached);
    try expectEval(page, interfaceCheck(true), "ok");

    // A frame's realm, made inside its parent's script as HTML makes a
    // navigable's.
    var frame_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot };
    const frame = try frame_maker.make();
    try expectEval(frame, interfaceCheck(true), "ok");

    // The frame navigated: a new realm behind its WindowProxy.
    var navigated_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot, .global_this = .{ .window_proxy_of = frame } };
    const navigated = try navigated_maker.make();
    defer protocol.destroyWindowRealm(navigated, .global_detached);
    protocol.destroyWindowRealm(frame, .global_detached);
    try expectEval(navigated, interfaceCheck(true), "ok");

    // A sandboxed frame's document has an opaque origin.
    var sandboxed_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot, .origin = "null" };
    const sandboxed = try sandboxed_maker.make();
    defer protocol.destroyWindowRealm(sandboxed, .global_detached);
    try expectEval(sandboxed, interfaceCheck(true), "ok");

    // A popup (an auxiliary realm: its creator as parent, no child of it).
    var popup_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot, .auxiliary = true };
    const popup = try popup_maker.make();
    defer protocol.destroyWindowRealm(popup, .global_detached);
    try expectEval(popup, interfaceCheck(true), "ok");

    // A frame that is not a secure context (an http: document).
    var insecure_maker: Frame = .{ .agent = agent, .parent = page, .from_snapshot = from_snapshot, .origin = "http://tmpl1.test", .secure_context = false };
    const insecure = try insecure_maker.make();
    defer protocol.destroyWindowRealm(insecure, .global_detached);
    try expectEval(insecure, interfaceCheck(false), "ok");
}

/// A frame's (or popup's) Window realm, made inside its parent's script
/// (protocol.runInRealm).
const Frame = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    from_snapshot: bool,
    global_this: protocol.GlobalThis = .new_window_proxy,
    origin: []const u8 = "https://tmpl1.test",
    secure_context: bool = true,
    auxiliary: bool = false,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *Frame) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Frame = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = self.from_snapshot,
            .timer = null,
            .origin = self.origin,
            .secure_context = self.secure_context,
            .global_this = self.global_this,
            .parent = self.parent,
            .auxiliary = self.auxiliary,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

/// A window agent restored from the build's snapshot, in a process whose V8
/// started with it - or null (skipped, saying so) when V8 started before.
const SnapshotAgent = struct {
    bytes: []u8,
    agent: *protocol.Agent,

    fn open() !?SnapshotAgent {
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own (tests-v8 runs at batch 1; -Dlaunch-batch=1 or -Dtest-file=)", .{});
            return null;
        }
        const io = std.testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        dom.style.ua_sheet.build();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        return .{ .bytes = bytes, .agent = agent };
    }

    fn close(self: SnapshotAgent) void {
        protocol.destroyAgent(self.agent);
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }
};

test "every kind of Window realm restored from the snapshot has the interface objects Window exposes, and only those" {
    const restored = (try SnapshotAgent.open()) orelse return error.SkipZigTest;
    defer restored.close();
    try checkEveryRealmKind(restored.agent, true);
}

test "every kind of Window realm made without the snapshot has the interface objects Window exposes, and only those" {
    test_process.start();
    dom.style.ua_sheet.build();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    try checkEveryRealmKind(agent, false);
}

// A wrap asks its realm whether the interface's object is built yet
// (template_registry.ensureInterfaceObjectBuilt) on every wrapper it makes:
// the answer is one bit, at the index the isolate gave the interface when it
// registered it - its registration order, kept through a re-registration -
// read with the template the wrap looks up anyway. A hash of the template on
// every wrap cost dom.create-element 3.2% (the cost window of 2026-11-20).
test "an isolate gives each interface it registers its registration order as an index, kept through a re-registration" {
    test_process.start();
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    defer {
        v8.template_registry.forgetIsolateForTest(isolate);
        ffi.v8_Isolate_Dispose(isolate);
    }
    const registry = v8.template_registry;
    registry.register("Element", @ptrFromInt(0x1110), isolate);
    registry.register("Text", @ptrFromInt(0x2220), isolate);
    registry.register("Element", @ptrFromInt(0x3330), isolate);
    registry.register("Comment", @ptrFromInt(0x4440), isolate);
    const element = registry.getRegisteredForIsolate("Element", isolate).?;
    try testing.expectEqual(@as(u16, 0), element.index);
    try testing.expectEqual(@as(usize, 0x3330), @intFromPtr(element.template));
    try testing.expectEqual(@as(u16, 1), registry.getRegisteredForIsolate("Text", isolate).?.index);
    try testing.expectEqual(@as(u16, 2), registry.getRegisteredForIsolate("Comment", isolate).?.index);
    try testing.expect(registry.getRegisteredForIsolate("Attr", isolate) == null);
}

// A realm's record of the interface objects it has built: one bit per
// registered interface, grown to the highest index marked, from the realm's
// own allocator.
test "a realm's record of built interface objects is a bit per registered interface, grown on demand" {
    var objects: v8.context_manager.InterfaceObjects = .{};
    defer objects.deinit(testing.allocator);
    try testing.expect(!objects.isBuilt(0));
    try testing.expect(!objects.isBuilt(700));
    objects.markBuilt(testing.allocator, 5);
    try testing.expect(objects.isBuilt(5));
    try testing.expect(!objects.isBuilt(4));
    try testing.expect(!objects.isBuilt(6));
    objects.markBuilt(testing.allocator, 1300);
    try testing.expect(objects.isBuilt(1300));
    try testing.expect(objects.isBuilt(5));
    try testing.expect(!objects.isBuilt(1299));
    try testing.expect(!objects.isBuilt(1301));
}

/// How many interface templates `agent`'s isolate has made or taken.
fn templateCount(agent: *protocol.Agent) usize {
    return v8.template_registry.registeredCount(@ptrCast(@alignCast(agent)));
}

// The first realm of an isolate restored from the snapshot makes the
// templates of what it wraps and of what its script reads, and no other:
// ~1,120 were made at the first realm (interface_bindings'
// registerAllTemplatesOnly) while the snapshot's own copies stayed in the
// isolate (V8's startup object cache) - two of each.
test "an isolate restored from the snapshot makes an interface's template when a realm first needs it" {
    const restored = (try SnapshotAgent.open()) orelse return error.SkipZigTest;
    defer restored.close();
    const page = try protocol.createWindowRealm(&.{
        .agent = restored.agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = true,
        .timer = null,
        .origin = "https://tmpl1.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(page, .global_detached);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(restored.agent));
    try expectEval(page, "new Document().implementation.createHTMLDocument('t').body instanceof HTMLBodyElement", "true");
    const made = templateCount(restored.agent);
    if (made >= 100) std.debug.print("{d} templates after a realm that read a handful of interfaces\n", .{made});
    try testing.expect(made < 100);
    try testing.expect(v8.template_registry.getTemplateForIsolate("DOMParser", isolate) == null);
    try expectEval(page, "typeof new DOMParser().parseFromString", "function");
    try testing.expect(v8.template_registry.getTemplateForIsolate("DOMParser", isolate) != null);
    // A frame of the same isolate makes none again.
    var frame_maker: Frame = .{ .agent = restored.agent, .parent = page, .from_snapshot = true };
    const frame = try frame_maker.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);
    const before = templateCount(restored.agent);
    try expectEval(frame, "typeof new DOMParser().parseFromString", "function");
    try testing.expectEqual(before, templateCount(restored.agent));
}

// The same for an isolate made without the snapshot (a fresh realm built
// every interface object, eagerly).
test "an isolate made without the snapshot makes an interface's template when a realm first needs it" {
    test_process.start();
    dom.style.ua_sheet.build();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const page = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://tmpl1.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(page, .global_detached);
    try expectEval(page, "new Document().implementation.createHTMLDocument('t').body instanceof HTMLBodyElement", "true");
    const made = templateCount(agent);
    if (made >= 100) std.debug.print("{d} templates after a realm that read a handful of interfaces\n", .{made});
    try testing.expect(made < 100);
    try testing.expect(v8.template_registry.getTemplateForIsolate("DOMParser", @ptrCast(@alignCast(agent))) == null);
    try expectEval(page, "typeof new DOMParser().parseFromString", "function");
    try testing.expect(v8.template_registry.getTemplateForIsolate("DOMParser", @ptrCast(@alignCast(agent))) != null);
}

// A dedicated worker's agent (never restored from the snapshot: html/
// worker_host.zig) makes the templates of what its realm reads and wraps,
// not of every interface exposed to it: installForScope made all 369 and
// built every interface object (2.8 ms and 1.5 MB per worker,
// tmp/plans/tmpl1-measure.md). Its global has exactly the constructs a
// dedicated worker exposes, as lazy data properties of its global scope
// template; a secure realm has the [SecureContext] ones, an insecure one not.
test "a dedicated worker's realm has the interface objects a dedicated worker exposes, and its isolate makes a template when the realm first needs it" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    {
        const made = try protocol.createWorkerRealm(agent, &.{ .global = .dedicated, .url = "https://tmpl1.test/worker.js", .allocator = std.heap.c_allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
        defer protocol.destroyWorkerRealm(made.realm, null, null);
        const count = templateCount(agent);
        if (count >= 60) std.debug.print("{d} templates after a worker realm that read nothing\n", .{count});
        try testing.expect(count < 60);
        try testing.expect(v8.template_registry.getTemplateForIsolate("TextDecoder", @ptrCast(@alignCast(agent))) == null);
        try expectEval(made.realm, workerInterfaceCheck(true), "ok");
        try testing.expect(v8.template_registry.getTemplateForIsolate("TextDecoder", @ptrCast(@alignCast(agent))) != null);
    }
    const insecure = try protocol.createWorkerRealm(agent, &.{ .global = .dedicated, .url = "http://tmpl1.test/worker.js", .secure_context = false, .allocator = std.heap.c_allocator, .timer = null, .event_loop = @import("inline_task_loop.zig").eventLoop() });
    defer protocol.destroyWorkerRealm(insecure.realm, null, null);
    try expectEval(insecure.realm, workerInterfaceCheck(false), "ok");
}
