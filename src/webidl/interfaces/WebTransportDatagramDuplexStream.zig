//! Generated from: webtransport.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebTransportDatagramDuplexStreamImpl = @import("impls").WebTransportDatagramDuplexStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WebTransportSendOptions = @import("dictionaries").WebTransportSendOptions;
const WebTransportDatagramsWritable = @import("interfaces").WebTransportDatagramsWritable;
const ReadableStream = @import("interfaces").ReadableStream;

pub const WebTransportDatagramDuplexStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportDatagramDuplexStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
            .{ "maxDatagramSize", "get_maxDatagramSize", null },
            .{ "incomingMaxAge", "get_incomingMaxAge", "set_incomingMaxAge" },
            .{ "outgoingMaxAge", "get_outgoingMaxAge", "set_outgoingMaxAge" },
            .{ "incomingHighWaterMark", "get_incomingHighWaterMark", "set_incomingHighWaterMark" },
            .{ "outgoingHighWaterMark", "get_outgoingHighWaterMark", "set_outgoingHighWaterMark" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createWritable", "call_createWritable", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createWritable",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "readable", "get_readable", null },
            .{ "maxDatagramSize", "get_maxDatagramSize", null },
            .{ "incomingMaxAge", "get_incomingMaxAge", "set_incomingMaxAge" },
            .{ "outgoingMaxAge", "get_outgoingMaxAge", "set_outgoingMaxAge" },
            .{ "incomingHighWaterMark", "get_incomingHighWaterMark", "set_incomingHighWaterMark" },
            .{ "outgoingHighWaterMark", "get_outgoingHighWaterMark", "set_outgoingHighWaterMark" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            readable: *runtime.Instance = undefined,
            maxDatagramSize: u32 = undefined,
            incomingMaxAge: ?f64 = null,
            outgoingMaxAge: ?f64 = null,
            incomingHighWaterMark: f64 = undefined,
            outgoingHighWaterMark: f64 = undefined,
            _internal: ?*WebTransportDatagramDuplexStreamImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_incomingHighWaterMark = &get_incomingHighWaterMark,
        .get_incomingMaxAge = &get_incomingMaxAge,
        .get_maxDatagramSize = &get_maxDatagramSize,
        .get_outgoingHighWaterMark = &get_outgoingHighWaterMark,
        .get_outgoingMaxAge = &get_outgoingMaxAge,
        .get_readable = &get_readable,

        .set_incomingHighWaterMark = &set_incomingHighWaterMark,
        .set_incomingMaxAge = &set_incomingMaxAge,
        .set_outgoingHighWaterMark = &set_outgoingHighWaterMark,
        .set_outgoingMaxAge = &set_outgoingMaxAge,

        .call_createWritable = &call_createWritable,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WebTransportDatagramDuplexStream has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "init") and @hasDecl(WebTransportDatagramDuplexStreamImpl, "initOwn")) @compileError("WebTransportDatagramDuplexStreamImpl defines both init and initOwn");
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "init")) return WebTransportDatagramDuplexStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WebTransportDatagramDuplexStreamImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "init")) return false;
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "construction_args")) {
            inline for (WebTransportDatagramDuplexStreamImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "deinit") and @hasDecl(WebTransportDatagramDuplexStreamImpl, "deinitOwn")) @compileError("WebTransportDatagramDuplexStreamImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "deinit")) return WebTransportDatagramDuplexStreamImpl.deinit(instance);
        if (comptime @hasDecl(WebTransportDatagramDuplexStreamImpl, "deinitOwn")) WebTransportDatagramDuplexStreamImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WebTransportDatagramDuplexStream")) {
            if (comptime @hasDecl(impls.WebTransportDatagramDuplexStream, "installHooks")) impls.WebTransportDatagramDuplexStream.installHooks();
        }
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportDatagramDuplexStreamImpl.get_readable(instance);
    }

    pub fn get_maxDatagramSize(instance: *runtime.Instance) anyerror!u32 {
        return try WebTransportDatagramDuplexStreamImpl.get_maxDatagramSize(instance);
    }

    pub fn get_incomingMaxAge(instance: *runtime.Instance) anyerror!?f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_incomingMaxAge(instance);
    }

    pub fn set_incomingMaxAge(instance: *runtime.Instance, value: ?f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_incomingMaxAge(instance, value);
    }

    pub fn get_outgoingMaxAge(instance: *runtime.Instance) anyerror!?f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_outgoingMaxAge(instance);
    }

    pub fn set_outgoingMaxAge(instance: *runtime.Instance, value: ?f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_outgoingMaxAge(instance, value);
    }

    pub fn get_incomingHighWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_incomingHighWaterMark(instance);
    }

    pub fn set_incomingHighWaterMark(instance: *runtime.Instance, value: f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_incomingHighWaterMark(instance, value);
    }

    pub fn get_outgoingHighWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_outgoingHighWaterMark(instance);
    }

    pub fn set_outgoingHighWaterMark(instance: *runtime.Instance, value: f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_outgoingHighWaterMark(instance, value);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: webidl.Opt(WebTransportSendOptions)) anyerror!*runtime.Instance {
        return try WebTransportDatagramDuplexStreamImpl.call_createWritable(instance, options);
    }
};
