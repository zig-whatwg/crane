//! What an indexed property interceptor converts or receives is freed on
//! every path (lane bindfix1, Codex row 128 Q74):
//!
//! - the getter's result is the binding's, as an operation's is
//!   (docs/lessons/architecture-a-getter-s-result-is-the-binding-s-like-an-
//!   operation-s.md): a union result frees its active arm - a USVString arm
//!   the impl made for it included - and releases the handle converting it
//!   made, decided by that arm (a String is fresh, a wrapper is the cache's);
//! - the setter's value is borrowed for the call, as an argument is: what its
//!   conversion made is freed whether the setter returned or threw.
//!
//! No interface on main has an implemented indexed getter or setter of a
//! union with a string arm (CSSUnparsedValue's are not implemented yet), so
//! the probe is a test-only interface with the generated CSSUnparsedSegment
//! typedef - (USVString or CSSVariableReferenceValue) - as its getter's result
//! and its setter's value. Its items live inline in its State, and its getter
//! hands out a fresh copy made with the realm's allocator, as an impl does.
//! The realm's allocator and Browser are std.testing.allocator's, so a string
//! the binding leaves behind fails the test.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const Segment = v8.conversions.generated_typedefs.CSSUnparsedSegment;

const capacity = 4;
const text_capacity = 32;

const SegmentList = struct {
    pub const Meta = struct {
        pub const name = "BindfixSegmentList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        pub const exposed_in_all_contexts = true;
        pub const properties = .{.{ "length", "get_length", null }};
        pub const methods = .{};
        pub const own_methods = .{};
        pub const inherited_methods = .{};
        pub const eager_properties = .{.{ "length", "get_length", null }};
        pub const lazy_properties = .{};
        pub const has_constructor = true;
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = true },
            .indexed_setter = .{ .function = "call_setter", .implemented = true },
        };
    };

    const Items = struct {
        count: u32 = 0,
        lengths: [capacity]u8 = @splat(0),
        texts: [capacity][text_capacity]u8 = undefined,
    };

    pub const State = runtime.FlattenedState(Meta.BaseType, Meta.MixinTypes, Items);

    const delegates = .{
        .get_length = &get_length,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    fn stateOf(instance: *runtime.Instance) *Items {
        return &instance.stateAs(State).?.own;
    }

    pub const constructor_required_arguments: usize = 0;

    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        return runtime.Instance.init(ctx.allocator, State, &vtable, ctx);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return stateOf(instance).count;
    }

    /// `getter CSSUnparsedSegment (unsigned long index)`: a copy of the
    /// item, made for the result.
    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!Segment {
        const state = stateOf(instance);
        if (index >= state.count) return error.IndexSizeError;
        const text = state.texts[index][0..state.lengths[index]];
        return .{ .usvstring = try instance.ctx.allocator.dupe(u8, text) };
    }

    /// `setter undefined (unsigned long index, CSSUnparsedSegment value)`:
    /// a RangeError past the end (CSSUnparsedValue's "set the value of a new
    /// indexed property" for an index greater than length); the value is
    /// copied, never kept.
    pub fn call_setter(instance: *runtime.Instance, index: u32, value: Segment) anyerror!void {
        const state = stateOf(instance);
        if (index > state.count or index >= capacity) return error.RangeError;
        const text = switch (value) {
            .usvstring => |t| t,
            .cssvariable_reference_value => return error.NotSupportedError,
        };
        if (text.len > text_capacity) return error.RangeError;
        @memcpy(state.texts[index][0..text.len], text);
        state.lengths[index] = @intCast(text.len);
        if (index == state.count) state.count += 1;
    }
};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(testing.allocator, r) catch null;
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

/// A Window realm whose allocator and Browser are std.testing.allocator's,
/// with the probe on its global.
const Page = struct {
    scope: *runtime.BrowserScope,
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try protocol.initializeEngine(.{});
        if (runtime.BrowserScope.standalone() == null) {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(std.heap.page_allocator);
        }
        const scope = try testing.allocator.create(runtime.BrowserScope);
        errdefer testing.allocator.destroy(scope);
        scope.* = runtime.BrowserScope.init(testing.allocator);
        errdefer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null, .allocator = testing.allocator });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://bindfix1.test",
            .browser_scope = scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        errdefer protocol.destroyWindowRealm(realm, .global_detached);
        const Install = struct {
            fn steps(data: ?*anyopaque) void {
                const r: runtime.Context = @ptrCast(@alignCast(data.?));
                const context: *ffi.Context = @ptrCast(@alignCast(r.engine_ctx.?));
                const current = ffi.v8_Isolate_GetCurrent() orelse return;
                v8.V8Interface(SegmentList).registerGlobal(current, context, SegmentList.Meta.name);
            }
        };
        try protocol.runInRealm(realm, Install.steps, realm);
        return .{ .scope = scope, .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        self.scope.deinit();
        testing.allocator.destroy(self.scope);
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

    fn expectOk(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const got = try protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
        try testing.expectEqualStrings("ok", got);
    }

    /// The global handle bytes 64 runs of `statement` leave, once a first
    /// round has made what later ones reuse (per_call_handle_test.zig's
    /// measure). `list` is a BindfixSegmentList holding "abc".
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  var list = globalThis.list ||= (() => { const l = new BindfixSegmentList(); l[0] = "abc"; return l; })();
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
            \\  }
            \\  return "ok";
            \\})()
        ;
        try self.expectOk(loop);
        try self.collect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        try self.expectOk(loop);
        try self.collect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        return after - before;
    }
};

test "an indexed getter's union result frees its string arm" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\const list = new BindfixSegmentList();
        \\list[0] = "owned getter string";
        \\let failed = "";
        \\for (let i = 0; i < 12; ++i) if (list[0] !== "owned getter string") failed = "getter " + list[0];
        \\// Iteration reads the same getter (WebIDL 3.7.9: %Array.prototype.values%).
        \\for (let i = 0; i < 6; ++i) if (Array.from(list).join("|") !== "owned getter string") failed = "iterator";
        \\// The descriptor path converts the result too.
        \\for (let i = 0; i < 6; ++i) if (Object.getOwnPropertyDescriptor(list, 0).value !== "owned getter string") failed = "descriptor";
        \\failed || "ok"
    );
}

test "an indexed setter frees the union value it converted" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\const list = new BindfixSegmentList();
        \\list[0] = "original";
        \\for (let i = 0; i < 12; ++i) list[0] = "replacement " + i;
        \\for (let i = 0; i < 6; ++i) Object.defineProperty(list, 0, { value: "defined " + i });
        \\list.length === 1 && list[0] === "defined 5" ? "ok" : "length " + list.length + ", [0] " + list[0]
    );
}

test "an indexed setter that throws frees its value, and the exception is the assignment's" {
    const page = try Page.open();
    defer page.close();
    try page.expectOk(
        \\const list = new BindfixSegmentList();
        \\list[0] = "original";
        \\const failures = [];
        \\for (let i = 0; i < 6; ++i) {
        \\  let thrown;
        \\  try { list[2] = "gap " + i; } catch (e) { thrown = e; }
        \\  if (!(thrown instanceof RangeError)) failures.push("[[Set]] threw " + thrown);
        \\  thrown = undefined;
        \\  try { Object.defineProperty(list, 3, { value: "gap " + i }); } catch (e) { thrown = e; }
        \\  if (!(thrown instanceof RangeError)) failures.push("[[DefineOwnProperty]] threw " + thrown);
        \\}
        \\if (Object.hasOwn(list, "2") || Object.hasOwn(list, "3") || list.length !== 1) failures.push("mutated after a throw");
        \\failures.join("; ") || "ok"
    );
}

test "an indexed getter's union string result leaves no handle per read" {
    const page = try Page.open();
    defer page.close();
    const control = try page.handleBytesLeftBy("list.length");
    const reads = try page.handleBytesLeftBy("list[0]");
    const descriptors = try page.handleBytesLeftBy("Object.getOwnPropertyDescriptor(list, 0)");
    // 64 reads that each keep a 16-byte Global leave 1 KB; allow noise below
    // one Global per eight reads.
    const slack: i64 = 64 * 16 / 8;
    if (reads - control >= slack or descriptors - control >= slack) {
        std.debug.print("64 reads left {d} bytes of global handles, 64 descriptors {d}; the control left {d}\n", .{ reads, descriptors, control });
        return error.HandleLeftPerRead;
    }
}

test "the special operation value allowlist names what it can free, and its default is no rule" {
    const understood = v8.interface_mod.specialOperationValueIsUnderstood;
    inline for (.{ runtime.DOMString, ?runtime.DOMString, []const u8, runtime.JSValue, ?runtime.JSValue, *runtime.Instance, ?*runtime.Instance, u32, f64, bool, Segment, ?Segment }) |T| {
        if (comptime !understood(T)) {
            std.debug.print("{s} should have an ownership rule\n", .{@typeName(T)});
            return error.TestUnexpectedResult;
        }
    }
    // The default: a type nobody named has no rule (the binding refuses to
    // compile a special operation of it) - a struct, a sequence, an opaque
    // pointer, an untagged union, a union with one such arm.
    inline for (.{ struct { a: u32 }, []const f64, []const []const u8, *anyopaque, union { a: u32, b: f64 }, union(enum) { text: []const u8, other: struct { a: u32 } } }) |T| {
        if (comptime understood(T)) {
            std.debug.print("{s} should have no ownership rule\n", .{@typeName(T)});
            return error.TestUnexpectedResult;
        }
    }
}

test "a special value frees its active arm, and a result's handle is owned as that arm is" {
    const free = v8.interface_mod.freeSpecialOperationValue;
    // A USVString arm made for the value: freed (std.testing.allocator
    // fails the test if it is not).
    free(Segment, testing.allocator, .{ .usvstring = try testing.allocator.dupe(u8, "made for the call") });
    free(?Segment, testing.allocator, .{ .usvstring = try testing.allocator.dupe(u8, "optional") });
    free(?Segment, testing.allocator, null);
    // An empty one is no allocation, and an interned DOMString is not ours.
    free(Segment, testing.allocator, .{ .usvstring = "" });
    free(runtime.DOMString, testing.allocator, runtime.DOMString.initInterned("kept"));
    free(runtime.DOMString, testing.allocator, runtime.DOMString.initOwned(try testing.allocator.dupe(u8, "owned")));

    const owned = v8.interface_mod.specialResultHandleIsOwned;
    try testing.expect(owned(Segment, .{ .usvstring = "a" }));
    // A wrapper is the wrapper cache's (never dereferenced here).
    const instance: *runtime.Instance = @ptrFromInt(0x10000);
    try testing.expect(!owned(Segment, .{ .cssvariable_reference_value = instance }));
    try testing.expect(!owned(runtime.JSValue, .{ .instance = instance }));
    try testing.expect(owned(runtime.JSValue, .undefined));
    try testing.expect(owned(runtime.DOMString, runtime.DOMString.initInterned("a")));
}
