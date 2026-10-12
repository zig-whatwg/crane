//! Generated from: webtransport.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebTransportImpl = @import("impls").WebTransport;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;
const WebTransportConnectionStats = @import("dictionaries").WebTransportConnectionStats;
const WebTransportSendStream = @import("interfaces").WebTransportSendStream;
const WebTransportDatagramDuplexStream = @import("interfaces").WebTransportDatagramDuplexStream;
const WebTransportReliabilityMode = @import("enums").WebTransportReliabilityMode;
const USVString = @import("typedefs").USVString;
const WebTransportOptions = @import("dictionaries").WebTransportOptions;
const WebTransportBidirectionalStream = @import("interfaces").WebTransportBidirectionalStream;
const ReadableStream = @import("interfaces").ReadableStream;
const BufferSource = @import("typedefs").BufferSource;
const WebTransportSendStreamOptions = @import("dictionaries").WebTransportSendStreamOptions;
const WebTransportCloseInfo = @import("dictionaries").WebTransportCloseInfo;
const WebTransportSendGroup = @import("interfaces").WebTransportSendGroup;
const WebTransportCongestionControl = @import("enums").WebTransportCongestionControl;

pub const WebTransport = struct {
    pub const Meta = struct {
        pub const name = "WebTransport";
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
            .{ "ready", "get_ready", null },
            .{ "reliability", "get_reliability", null },
            .{ "congestionControl", "get_congestionControl", null },
            .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "get_anticipatedConcurrentIncomingUnidirectionalStreams", "set_anticipatedConcurrentIncomingUnidirectionalStreams" },
            .{ "anticipatedConcurrentIncomingBidirectionalStreams", "get_anticipatedConcurrentIncomingBidirectionalStreams", "set_anticipatedConcurrentIncomingBidirectionalStreams" },
            .{ "protocol", "get_protocol", null },
            .{ "closed", "get_closed", null },
            .{ "draining", "get_draining", null },
            .{ "datagrams", "get_datagrams", null },
            .{ "incomingBidirectionalStreams", "get_incomingBidirectionalStreams", null },
            .{ "incomingUnidirectionalStreams", "get_incomingUnidirectionalStreams", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getStats", "call_getStats", 0 },
            .{ "exportKeyingMaterial", "call_exportKeyingMaterial", 1 },
            .{ "close", "call_close", 0 },
            .{ "createBidirectionalStream", "call_createBidirectionalStream", 0 },
            .{ "createUnidirectionalStream", "call_createUnidirectionalStream", 0 },
            .{ "createSendGroup", "call_createSendGroup", 0 },
        };

        /// Static attribute binding hints for V8Interface (JS name, getter fn name, setter fn name or null)
        pub const static_properties = .{
            .{ "supportsReliableOnly", "get_static_supportsReliableOnly", null },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStats",
            "exportKeyingMaterial",
            "close",
            "createBidirectionalStream",
            "createUnidirectionalStream",
            "createSendGroup",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ready", "get_ready", null },
            .{ "reliability", "get_reliability", null },
            .{ "congestionControl", "get_congestionControl", null },
            .{ "anticipatedConcurrentIncomingUnidirectionalStreams", "get_anticipatedConcurrentIncomingUnidirectionalStreams", "set_anticipatedConcurrentIncomingUnidirectionalStreams" },
            .{ "anticipatedConcurrentIncomingBidirectionalStreams", "get_anticipatedConcurrentIncomingBidirectionalStreams", "set_anticipatedConcurrentIncomingBidirectionalStreams" },
            .{ "protocol", "get_protocol", null },
            .{ "closed", "get_closed", null },
            .{ "draining", "get_draining", null },
            .{ "datagrams", "get_datagrams", null },
            .{ "incomingBidirectionalStreams", "get_incomingBidirectionalStreams", null },
            .{ "incomingUnidirectionalStreams", "get_incomingUnidirectionalStreams", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ready: runtime.JSValue = undefined,
            reliability: enums.WebTransportReliabilityMode = undefined,
            congestionControl: enums.WebTransportCongestionControl = undefined,
            anticipatedConcurrentIncomingUnidirectionalStreams: ?u16 = null,
            anticipatedConcurrentIncomingBidirectionalStreams: ?u16 = null,
            protocol: typedefs.DOMString = undefined,
            closed: runtime.JSValue = undefined,
            draining: runtime.JSValue = undefined,
            datagrams: *runtime.Instance = undefined,
            incomingBidirectionalStreams: *runtime.Instance = undefined,
            incomingUnidirectionalStreams: *runtime.Instance = undefined,
            _internal: ?*WebTransportImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_anticipatedConcurrentIncomingBidirectionalStreams = &get_anticipatedConcurrentIncomingBidirectionalStreams,
        .get_anticipatedConcurrentIncomingUnidirectionalStreams = &get_anticipatedConcurrentIncomingUnidirectionalStreams,
        .get_closed = &get_closed,
        .get_congestionControl = &get_congestionControl,
        .get_datagrams = &get_datagrams,
        .get_draining = &get_draining,
        .get_incomingBidirectionalStreams = &get_incomingBidirectionalStreams,
        .get_incomingUnidirectionalStreams = &get_incomingUnidirectionalStreams,
        .get_protocol = &get_protocol,
        .get_ready = &get_ready,
        .get_reliability = &get_reliability,

        .set_anticipatedConcurrentIncomingBidirectionalStreams = &set_anticipatedConcurrentIncomingBidirectionalStreams,
        .set_anticipatedConcurrentIncomingUnidirectionalStreams = &set_anticipatedConcurrentIncomingUnidirectionalStreams,

        .call_close = &call_close,
        .call_createBidirectionalStream = &call_createBidirectionalStream,
        .call_createSendGroup = &call_createSendGroup,
        .call_createUnidirectionalStream = &call_createUnidirectionalStream,
        .call_exportKeyingMaterial = &call_exportKeyingMaterial,
        .call_getStats = &call_getStats,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WebTransport has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WebTransportImpl, "init") and @hasDecl(WebTransportImpl, "initOwn")) @compileError("WebTransportImpl defines both init and initOwn");
        if (comptime @hasDecl(WebTransportImpl, "init")) return WebTransportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(WebTransportImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try WebTransportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WebTransportImpl, "init")) return false;
        if (comptime @hasDecl(WebTransportImpl, "construction_args")) {
            inline for (WebTransportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WebTransportImpl, "deinit") and @hasDecl(WebTransportImpl, "deinitOwn")) @compileError("WebTransportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WebTransportImpl, "deinit")) return WebTransportImpl.deinit(instance);
        if (comptime @hasDecl(WebTransportImpl, "deinitOwn")) WebTransportImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WebTransport")) {
            if (comptime @hasDecl(impls.WebTransport, "installHooks")) impls.WebTransport.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, options: webidl.Opt(WebTransportOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WebTransportImpl.call_constructor(ctx, url, options);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WebTransportImpl.get_ready(instance);
    }

    pub fn get_reliability(instance: *runtime.Instance) anyerror!WebTransportReliabilityMode {
        return try WebTransportImpl.get_reliability(instance);
    }

    pub fn get_congestionControl(instance: *runtime.Instance) anyerror!WebTransportCongestionControl {
        return try WebTransportImpl.get_congestionControl(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!?u16 {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingUnidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingUnidirectionalStreams(instance: *runtime.Instance, value: ?u16) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingUnidirectionalStreams(instance, value);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance) anyerror!?u16 {
        return try WebTransportImpl.get_anticipatedConcurrentIncomingBidirectionalStreams(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_anticipatedConcurrentIncomingBidirectionalStreams(instance: *runtime.Instance, value: ?u16) anyerror!void {
        try WebTransportImpl.set_anticipatedConcurrentIncomingBidirectionalStreams(instance, value);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try WebTransportImpl.get_protocol(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WebTransportImpl.get_closed(instance);
    }

    pub fn get_draining(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WebTransportImpl.get_draining(instance);
    }

    pub fn get_datagrams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_datagrams(instance);
    }

    pub fn get_incomingBidirectionalStreams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_incomingBidirectionalStreams(instance);
    }

    pub fn get_incomingUnidirectionalStreams(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.get_incomingUnidirectionalStreams(instance);
    }

    pub fn get_static_supportsReliableOnly(instance: *runtime.Instance) anyerror!bool {
        return try WebTransportImpl.get_static_supportsReliableOnly(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try WebTransportImpl.call_getStats(instance);
    }

    pub fn call_createUnidirectionalStream(instance: *runtime.Instance, options: webidl.Opt(WebTransportSendStreamOptions)) anyerror!runtime.JSValue {
        return try WebTransportImpl.call_createUnidirectionalStream(instance, options);
    }

    pub fn call_close(instance: *runtime.Instance, closeInfo: webidl.Opt(WebTransportCloseInfo)) anyerror!void {
        return try WebTransportImpl.call_close(instance, closeInfo);
    }

    /// Extended attributes: [NewObject]
    pub fn call_exportKeyingMaterial(instance: *runtime.Instance, label: BufferSource, context: webidl.Opt(BufferSource)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try WebTransportImpl.call_exportKeyingMaterial(instance, label, context);
    }

    pub fn call_createSendGroup(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try WebTransportImpl.call_createSendGroup(instance);
    }

    pub fn call_createBidirectionalStream(instance: *runtime.Instance, options: webidl.Opt(WebTransportSendStreamOptions)) anyerror!runtime.JSValue {
        return try WebTransportImpl.call_createBidirectionalStream(instance, options);
    }

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "set_anticipatedConcurrentIncomingUnidirectionalStreams", 0b1 },
        .{ "set_anticipatedConcurrentIncomingBidirectionalStreams", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getStats",
        "call_createUnidirectionalStream",
        "call_exportKeyingMaterial",
        "call_createBidirectionalStream",
    };
};
