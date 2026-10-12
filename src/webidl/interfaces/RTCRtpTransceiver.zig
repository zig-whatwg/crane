//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCRtpTransceiverImpl = @import("impls").RTCRtpTransceiver;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RTCRtpCodec = @import("dictionaries").RTCRtpCodec;
const RTCRtpSender = @import("interfaces").RTCRtpSender;
const RTCRtpReceiver = @import("interfaces").RTCRtpReceiver;
const RTCRtpTransceiverDirection = @import("enums").RTCRtpTransceiverDirection;
const DOMString = @import("typedefs").DOMString;

pub const RTCRtpTransceiver = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpTransceiver";
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
            .{ "mid", "get_mid", null },
            .{ "sender", "get_sender", null },
            .{ "receiver", "get_receiver", null },
            .{ "direction", "get_direction", "set_direction" },
            .{ "currentDirection", "get_currentDirection", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "stop", "call_stop", 0 },
            .{ "setCodecPreferences", "call_setCodecPreferences", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "stop",
            "setCodecPreferences",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "mid", "get_mid", null },
            .{ "sender", "get_sender", null },
            .{ "receiver", "get_receiver", null },
            .{ "direction", "get_direction", "set_direction" },
            .{ "currentDirection", "get_currentDirection", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mid: ?typedefs.DOMString = null,
            sender: *runtime.Instance = undefined,
            receiver: *runtime.Instance = undefined,
            direction: enums.RTCRtpTransceiverDirection = undefined,
            currentDirection: ?enums.RTCRtpTransceiverDirection = null,
            cached_sender: ?*runtime.Instance = null,
            cached_receiver: ?*runtime.Instance = null,
            _internal: ?*RTCRtpTransceiverImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_currentDirection = &get_currentDirection,
        .get_direction = &get_direction,
        .get_mid = &get_mid,
        .get_receiver = &get_receiver,
        .get_sender = &get_sender,

        .set_direction = &set_direction,

        .call_setCodecPreferences = &call_setCodecPreferences,
        .call_stop = &call_stop,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCRtpTransceiver has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "init") and @hasDecl(RTCRtpTransceiverImpl, "initOwn")) @compileError("RTCRtpTransceiverImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "init")) return RTCRtpTransceiverImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCRtpTransceiverImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "init")) return false;
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "construction_args")) {
            inline for (RTCRtpTransceiverImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "deinit") and @hasDecl(RTCRtpTransceiverImpl, "deinitOwn")) @compileError("RTCRtpTransceiverImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "deinit")) return RTCRtpTransceiverImpl.deinit(instance);
        if (comptime @hasDecl(RTCRtpTransceiverImpl, "deinitOwn")) RTCRtpTransceiverImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCRtpTransceiver")) {
            if (comptime @hasDecl(impls.RTCRtpTransceiver, "installHooks")) impls.RTCRtpTransceiver.installHooks();
        }
    }

    pub fn get_mid(instance: *runtime.Instance) anyerror!?DOMString {
        return try RTCRtpTransceiverImpl.get_mid(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sender(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_sender) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_sender(instance);
        state.own.cached_sender = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_receiver(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_receiver) |cached| {
            return cached;
        }
        const value = try RTCRtpTransceiverImpl.get_receiver(instance);
        state.own.cached_receiver = value;
        return value;
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!RTCRtpTransceiverDirection {
        return try RTCRtpTransceiverImpl.get_direction(instance);
    }

    pub fn set_direction(instance: *runtime.Instance, value: RTCRtpTransceiverDirection) anyerror!void {
        try RTCRtpTransceiverImpl.set_direction(instance, value);
    }

    pub fn get_currentDirection(instance: *runtime.Instance) anyerror!?RTCRtpTransceiverDirection {
        return try RTCRtpTransceiverImpl.get_currentDirection(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RTCRtpTransceiverImpl.call_stop(instance);
    }

    pub fn call_setCodecPreferences(instance: *runtime.Instance, codecs: runtime.JSValue) anyerror!void {
        return try RTCRtpTransceiverImpl.call_setCodecPreferences(instance, codecs);
    }
};
