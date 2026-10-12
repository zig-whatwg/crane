//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HistoryImpl = @import("impls").History;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ScrollRestoration = @import("enums").ScrollRestoration;
const DOMString = @import("typedefs").DOMString;
const USVString = @import("typedefs").USVString;

pub const History = struct {
    pub const Meta = struct {
        pub const name = "History";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "scrollRestoration", "get_scrollRestoration", "set_scrollRestoration" },
            .{ "state", "get_state", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "go", "call_go", 0 },
            .{ "back", "call_back", 0 },
            .{ "forward", "call_forward", 0 },
            .{ "pushState", "call_pushState", 2 },
            .{ "replaceState", "call_replaceState", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "go",
            "back",
            "forward",
            "pushState",
            "replaceState",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "scrollRestoration", "get_scrollRestoration", "set_scrollRestoration" },
            .{ "state", "get_state", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            scrollRestoration: enums.ScrollRestoration = undefined,
            state: runtime.JSValue = undefined,
            _internal: ?*HistoryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_scrollRestoration = &get_scrollRestoration,
        .get_state = &get_state,

        .set_scrollRestoration = &set_scrollRestoration,

        .call_back = &call_back,
        .call_forward = &call_forward,
        .call_go = &call_go,
        .call_pushState = &call_pushState,
        .call_replaceState = &call_replaceState,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("History has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(HistoryImpl, "init") and @hasDecl(HistoryImpl, "initOwn")) @compileError("HistoryImpl defines both init and initOwn");
        if (comptime @hasDecl(HistoryImpl, "init")) return HistoryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(HistoryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try HistoryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HistoryImpl, "init")) return false;
        if (comptime @hasDecl(HistoryImpl, "construction_args")) {
            inline for (HistoryImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(HistoryImpl, "deinit") and @hasDecl(HistoryImpl, "deinitOwn")) @compileError("HistoryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HistoryImpl, "deinit")) return HistoryImpl.deinit(instance);
        if (comptime @hasDecl(HistoryImpl, "deinitOwn")) HistoryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "History")) {
            if (comptime @hasDecl(impls.History, "installHooks")) impls.History.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HistoryImpl.get_length(instance);
    }

    pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!ScrollRestoration {
        return try HistoryImpl.get_scrollRestoration(instance);
    }

    pub fn set_scrollRestoration(instance: *runtime.Instance, value: ScrollRestoration) anyerror!void {
        try HistoryImpl.set_scrollRestoration(instance, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HistoryImpl.get_state(instance);
    }

    pub fn call_forward(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_forward(instance);
    }

    pub fn call_replaceState(instance: *runtime.Instance, data: runtime.JSValue, unused: DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
        return try HistoryImpl.call_replaceState(instance, data, unused, url);
    }

    pub fn call_pushState(instance: *runtime.Instance, data: runtime.JSValue, unused: DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
        return try HistoryImpl.call_pushState(instance, data, unused, url);
    }

    pub fn call_go(instance: *runtime.Instance, delta: webidl.Opt(i32)) anyerror!void {
        return try HistoryImpl.call_go(instance, delta);
    }

    pub fn call_back(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_back(instance);
    }
};
