//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCIceTransportImpl = @import("impls").RTCIceTransport;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RTCIceGatherOptions = @import("dictionaries").RTCIceGatherOptions;
const RTCIceRole = @import("enums").RTCIceRole;
const RTCIceCandidatePair = @import("interfaces").RTCIceCandidatePair;
const RTCIceTransportState = @import("enums").RTCIceTransportState;
const RTCIceCandidateInit = @import("dictionaries").RTCIceCandidateInit;
const RTCIceGathererState = @import("enums").RTCIceGathererState;
const RTCIceComponent = @import("enums").RTCIceComponent;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RTCIceParameters = @import("dictionaries").RTCIceParameters;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const RTCIceCandidate = @import("interfaces").RTCIceCandidate;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const RTCIceTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCIceTransport";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "role", "get_role", null },
            .{ "component", "get_component", null },
            .{ "state", "get_state", null },
            .{ "gatheringState", "get_gatheringState", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "ongatheringstatechange", "get_ongatheringstatechange", "set_ongatheringstatechange" },
            .{ "onselectedcandidatepairchange", "get_onselectedcandidatepairchange", "set_onselectedcandidatepairchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getLocalCandidates", "call_getLocalCandidates", 0 },
            .{ "getRemoteCandidates", "call_getRemoteCandidates", 0 },
            .{ "getSelectedCandidatePair", "call_getSelectedCandidatePair", 0 },
            .{ "getLocalParameters", "call_getLocalParameters", 0 },
            .{ "getRemoteParameters", "call_getRemoteParameters", 0 },
            .{ "gather", "call_gather", 0 },
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "addRemoteCandidate", "call_addRemoteCandidate", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getLocalCandidates",
            "getRemoteCandidates",
            "getSelectedCandidatePair",
            "getLocalParameters",
            "getRemoteParameters",
            "gather",
            "start",
            "stop",
            "addRemoteCandidate",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "role", "get_role", null },
            .{ "component", "get_component", null },
            .{ "state", "get_state", null },
            .{ "gatheringState", "get_gatheringState", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "ongatheringstatechange", "get_ongatheringstatechange", "set_ongatheringstatechange" },
            .{ "onselectedcandidatepairchange", "get_onselectedcandidatepairchange", "set_onselectedcandidatepairchange" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onicecandidate", "get_onicecandidate", "set_onicecandidate" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            role: enums.RTCIceRole = undefined,
            component: enums.RTCIceComponent = undefined,
            state: enums.RTCIceTransportState = undefined,
            gatheringState: enums.RTCIceGathererState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            ongatheringstatechange: typedefs.EventHandler = undefined,
            onselectedcandidatepairchange: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onicecandidate: typedefs.EventHandler = undefined,
            _internal: ?*RTCIceTransportImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_component = &get_component,
        .get_gatheringState = &get_gatheringState,
        .get_onerror = &get_onerror,
        .get_ongatheringstatechange = &get_ongatheringstatechange,
        .get_onicecandidate = &get_onicecandidate,
        .get_onselectedcandidatepairchange = &get_onselectedcandidatepairchange,
        .get_onstatechange = &get_onstatechange,
        .get_role = &get_role,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_ongatheringstatechange = &set_ongatheringstatechange,
        .set_onicecandidate = &set_onicecandidate,
        .set_onselectedcandidatepairchange = &set_onselectedcandidatepairchange,
        .set_onstatechange = &set_onstatechange,

        .call_addRemoteCandidate = &call_addRemoteCandidate,
        .call_gather = &call_gather,
        .call_getLocalCandidates = &call_getLocalCandidates,
        .call_getLocalParameters = &call_getLocalParameters,
        .call_getRemoteCandidates = &call_getRemoteCandidates,
        .call_getRemoteParameters = &call_getRemoteParameters,
        .call_getSelectedCandidatePair = &call_getSelectedCandidatePair,
        .call_start = &call_start,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCIceTransport has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCIceTransportImpl, "init") and @hasDecl(RTCIceTransportImpl, "initOwn")) @compileError("RTCIceTransportImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCIceTransportImpl, "init")) return RTCIceTransportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RTCIceTransportImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RTCIceTransportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCIceTransportImpl, "init")) return false;
        if (comptime @hasDecl(RTCIceTransportImpl, "construction_args")) {
            inline for (RTCIceTransportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCIceTransportImpl, "deinit") and @hasDecl(RTCIceTransportImpl, "deinitOwn")) @compileError("RTCIceTransportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCIceTransportImpl, "deinit")) return RTCIceTransportImpl.deinit(instance);
        if (comptime @hasDecl(RTCIceTransportImpl, "deinitOwn")) RTCIceTransportImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCIceTransport")) {
            if (comptime @hasDecl(impls.RTCIceTransport, "installHooks")) impls.RTCIceTransport.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCIceTransportImpl.call_constructor(ctx);
    }

    pub fn get_role(instance: *runtime.Instance) anyerror!RTCIceRole {
        return try RTCIceTransportImpl.get_role(instance);
    }

    pub fn get_component(instance: *runtime.Instance) anyerror!RTCIceComponent {
        return try RTCIceTransportImpl.get_component(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RTCIceTransportState {
        return try RTCIceTransportImpl.get_state(instance);
    }

    pub fn get_gatheringState(instance: *runtime.Instance) anyerror!RTCIceGathererState {
        return try RTCIceTransportImpl.get_gatheringState(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCIceTransportImpl, "get_onstatechange")) return try RTCIceTransportImpl.get_onstatechange(instance);
        return event_handlers.value(EventHandler, instance, "onstatechange");
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCIceTransportImpl, "set_onstatechange")) return try RTCIceTransportImpl.set_onstatechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstatechange", value);
    }

    pub fn get_ongatheringstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCIceTransportImpl, "get_ongatheringstatechange")) return try RTCIceTransportImpl.get_ongatheringstatechange(instance);
        return event_handlers.value(EventHandler, instance, "ongatheringstatechange");
    }

    pub fn set_ongatheringstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCIceTransportImpl, "set_ongatheringstatechange")) return try RTCIceTransportImpl.set_ongatheringstatechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ongatheringstatechange", value);
    }

    pub fn get_onselectedcandidatepairchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCIceTransportImpl, "get_onselectedcandidatepairchange")) return try RTCIceTransportImpl.get_onselectedcandidatepairchange(instance);
        return event_handlers.value(EventHandler, instance, "onselectedcandidatepairchange");
    }

    pub fn set_onselectedcandidatepairchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCIceTransportImpl, "set_onselectedcandidatepairchange")) return try RTCIceTransportImpl.set_onselectedcandidatepairchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onselectedcandidatepairchange", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCIceTransportImpl, "get_onerror")) return try RTCIceTransportImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCIceTransportImpl, "set_onerror")) return try RTCIceTransportImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onicecandidate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCIceTransportImpl, "get_onicecandidate")) return try RTCIceTransportImpl.get_onicecandidate(instance);
        return event_handlers.value(EventHandler, instance, "onicecandidate");
    }

    pub fn set_onicecandidate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCIceTransportImpl, "set_onicecandidate")) return try RTCIceTransportImpl.set_onicecandidate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onicecandidate", value);
    }

    pub fn call_addRemoteCandidate(instance: *runtime.Instance, remoteCandidate: webidl.Opt(RTCIceCandidateInit)) anyerror!void {
        return try RTCIceTransportImpl.call_addRemoteCandidate(instance, remoteCandidate);
    }

    pub fn call_getLocalParameters(instance: *runtime.Instance) anyerror!?RTCIceParameters {
        return try RTCIceTransportImpl.call_getLocalParameters(instance);
    }

    pub fn call_getRemoteCandidates(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCIceTransportImpl.call_getRemoteCandidates(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try RTCIceTransportImpl.call_stop(instance);
    }

    pub fn call_getRemoteParameters(instance: *runtime.Instance) anyerror!?RTCIceParameters {
        return try RTCIceTransportImpl.call_getRemoteParameters(instance);
    }

    pub fn call_start(instance: *runtime.Instance, remoteParameters: webidl.Opt(RTCIceParameters), role: webidl.Opt(RTCIceRole)) anyerror!void {
        return try RTCIceTransportImpl.call_start(instance, remoteParameters, role);
    }

    pub fn call_gather(instance: *runtime.Instance, options: webidl.Opt(RTCIceGatherOptions)) anyerror!void {
        return try RTCIceTransportImpl.call_gather(instance, options);
    }

    pub fn call_getSelectedCandidatePair(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try RTCIceTransportImpl.call_getSelectedCandidatePair(instance);
    }

    pub fn call_getLocalCandidates(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCIceTransportImpl.call_getLocalCandidates(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onstatechange", "set_ongatheringstatechange", "set_onselectedcandidatepairchange", "set_onerror", "set_onicecandidate" };
};
