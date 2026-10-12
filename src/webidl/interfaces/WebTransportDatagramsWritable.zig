//! Generated from: webtransport.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebTransportDatagramsWritableImpl = @import("impls").WebTransportDatagramsWritable;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WritableStream = @import("interfaces").WritableStream;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const WebTransportDatagramsWritable = struct {
    pub const Meta = struct {
        pub const name = "WebTransportDatagramsWritable";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WritableStream.State;
        pub const ParentInterface = WritableStream;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sendGroup", "get_sendGroup", "set_sendGroup" },
            .{ "sendOrder", "get_sendOrder", "set_sendOrder" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "abort",
            "close",
            "getWriter",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sendGroup", "get_sendGroup", "set_sendGroup" },
            .{ "sendOrder", "get_sendOrder", "set_sendOrder" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sendGroup: ?*runtime.Instance = null,
            sendOrder: i64 = undefined,
            _internal: ?*WebTransportDatagramsWritableImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_sendGroup = &get_sendGroup,
        .get_sendOrder = &get_sendOrder,

        .set_sendGroup = &set_sendGroup,
        .set_sendOrder = &set_sendOrder,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WebTransportDatagramsWritable has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "init") and @hasDecl(WebTransportDatagramsWritableImpl, "initOwn")) @compileError("WebTransportDatagramsWritableImpl defines both init and initOwn");
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "init")) return WebTransportDatagramsWritableImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WebTransportDatagramsWritableImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "init")) return false;
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "construction_args")) {
            inline for (WebTransportDatagramsWritableImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "deinit") and @hasDecl(WebTransportDatagramsWritableImpl, "deinitOwn")) @compileError("WebTransportDatagramsWritableImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "deinit")) return WebTransportDatagramsWritableImpl.deinit(instance);
        if (comptime @hasDecl(WebTransportDatagramsWritableImpl, "deinitOwn")) WebTransportDatagramsWritableImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WebTransportDatagramsWritable")) {
            if (comptime @hasDecl(impls.WebTransportDatagramsWritable, "installHooks")) impls.WebTransportDatagramsWritable.installHooks();
        }
    }

    pub fn get_sendGroup(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try WebTransportDatagramsWritableImpl.get_sendGroup(instance);
    }

    pub fn set_sendGroup(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try WebTransportDatagramsWritableImpl.set_sendGroup(instance, value);
    }

    pub fn get_sendOrder(instance: *runtime.Instance) anyerror!i64 {
        return try WebTransportDatagramsWritableImpl.get_sendOrder(instance);
    }

    pub fn set_sendOrder(instance: *runtime.Instance, value: i64) anyerror!void {
        try WebTransportDatagramsWritableImpl.set_sendOrder(instance, value);
    }
};
