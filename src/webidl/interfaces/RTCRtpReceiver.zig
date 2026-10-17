//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCRtpReceiverImpl = @import("impls").RTCRtpReceiver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RTCRtpCapabilities = @import("dictionaries").RTCRtpCapabilities;
const RTCRtpReceiveParameters = @import("dictionaries").RTCRtpReceiveParameters;
const RTCRtpReceiverTransform = @import("typedefs").RTCRtpReceiverTransform;
const RTCRtpSynchronizationSource = @import("dictionaries").RTCRtpSynchronizationSource;
const RTCStatsReport = @import("interfaces").RTCStatsReport;
const RTCDtlsTransport = @import("interfaces").RTCDtlsTransport;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const RTCRtpContributingSource = @import("dictionaries").RTCRtpContributingSource;
const DOMString = @import("typedefs").DOMString;

pub const RTCRtpReceiver = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpReceiver";
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
            .{ "track", "get_track", null },
            .{ "transport", "get_transport", null },
            .{ "jitterBufferTarget", "get_jitterBufferTarget", "set_jitterBufferTarget" },
            .{ "transform", "get_transform", "set_transform" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getParameters", "call_getParameters", 0 },
            .{ "getContributingSources", "call_getContributingSources", 0 },
            .{ "getSynchronizationSources", "call_getSynchronizationSources", 0 },
            .{ "getStats", "call_getStats", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "getCapabilities", "call_static_getCapabilities", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCapabilities",
            "getParameters",
            "getContributingSources",
            "getSynchronizationSources",
            "getStats",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
            .{ "transport", "get_transport", null },
            .{ "jitterBufferTarget", "get_jitterBufferTarget", "set_jitterBufferTarget" },
            .{ "transform", "get_transform", "set_transform" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            track: *runtime.Instance = undefined,
            transport: ?*runtime.Instance = null,
            jitterBufferTarget: ?typedefs.DOMHighResTimeStamp = null,
            transform: ?typedefs.RTCRtpReceiverTransform = null,
            _internal: ?*RTCRtpReceiverImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_jitterBufferTarget = &get_jitterBufferTarget,
        .get_track = &get_track,
        .get_transform = &get_transform,
        .get_transport = &get_transport,

        .set_jitterBufferTarget = &set_jitterBufferTarget,
        .set_transform = &set_transform,

        .call_getContributingSources = &call_getContributingSources,
        .call_getParameters = &call_getParameters,
        .call_getStats = &call_getStats,
        .call_getSynchronizationSources = &call_getSynchronizationSources,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCRtpReceiver has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCRtpReceiverImpl, "init") and @hasDecl(RTCRtpReceiverImpl, "initOwn")) @compileError("RTCRtpReceiverImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCRtpReceiverImpl, "init")) return RTCRtpReceiverImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCRtpReceiverImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCRtpReceiverImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCRtpReceiverImpl, "init")) return false;
        if (comptime @hasDecl(RTCRtpReceiverImpl, "construction_args")) {
            inline for (RTCRtpReceiverImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCRtpReceiverImpl, "deinit") and @hasDecl(RTCRtpReceiverImpl, "deinitOwn")) @compileError("RTCRtpReceiverImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCRtpReceiverImpl, "deinit")) return RTCRtpReceiverImpl.deinit(instance);
        if (comptime @hasDecl(RTCRtpReceiverImpl, "deinitOwn")) RTCRtpReceiverImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCRtpReceiver")) {
            if (comptime @hasDecl(impls.RTCRtpReceiver, "installHooks")) impls.RTCRtpReceiver.installHooks();
        }
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try RTCRtpReceiverImpl.get_track(instance);
    }

    pub fn get_transport(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCRtpReceiverImpl.get_transport(instance);
    }

    pub fn get_jitterBufferTarget(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
        return try RTCRtpReceiverImpl.get_jitterBufferTarget(instance);
    }

    pub fn set_jitterBufferTarget(instance: *runtime.Instance, value: ?DOMHighResTimeStamp) anyerror!void {
        try RTCRtpReceiverImpl.set_jitterBufferTarget(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!?RTCRtpReceiverTransform {
        return try RTCRtpReceiverImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: ?RTCRtpReceiverTransform) anyerror!void {
        try RTCRtpReceiverImpl.set_transform(instance, value);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!RTCRtpReceiveParameters {
        return try RTCRtpReceiverImpl.call_getParameters(instance);
    }

    pub fn call_getStats(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCRtpReceiverImpl.call_getStats(instance);
    }

    pub fn call_static_getCapabilities(instance: *runtime.Instance, kind: runtime.DOMString) anyerror!?RTCRtpCapabilities {
        return try RTCRtpReceiverImpl.call_static_getCapabilities(instance, kind);
    }

    pub fn call_getSynchronizationSources(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCRtpReceiverImpl.call_getSynchronizationSources(instance);
    }

    pub fn call_getContributingSources(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCRtpReceiverImpl.call_getContributingSources(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_jitterBufferTarget", 0b1 },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getStats",
    };
};
