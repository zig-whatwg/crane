//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCDtlsTransportImpl = @import("impls").RTCDtlsTransport;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RTCIceTransport = @import("interfaces").RTCIceTransport;
const RTCDtlsTransportState = @import("enums").RTCDtlsTransportState;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const RTCDtlsTransport = struct {
    pub const Meta = struct {
        pub const name = "RTCDtlsTransport";
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
            .{ "iceTransport", "get_iceTransport", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRemoteCertificates", "call_getRemoteCertificates", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRemoteCertificates",
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
            .{ "iceTransport", "get_iceTransport", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            iceTransport: *runtime.Instance = undefined,
            state: enums.RTCDtlsTransportState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            cached_iceTransport: ?*runtime.Instance = null,
            _internal: ?*RTCDtlsTransportImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_iceTransport = &get_iceTransport,
        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_getRemoteCertificates = &call_getRemoteCertificates,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCDtlsTransport has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCDtlsTransportImpl, "init") and @hasDecl(RTCDtlsTransportImpl, "initOwn")) @compileError("RTCDtlsTransportImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCDtlsTransportImpl, "init")) return RTCDtlsTransportImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(RTCDtlsTransportImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try RTCDtlsTransportImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCDtlsTransportImpl, "init")) return false;
        if (comptime @hasDecl(RTCDtlsTransportImpl, "construction_args")) {
            inline for (RTCDtlsTransportImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCDtlsTransportImpl, "deinit") and @hasDecl(RTCDtlsTransportImpl, "deinitOwn")) @compileError("RTCDtlsTransportImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCDtlsTransportImpl, "deinit")) return RTCDtlsTransportImpl.deinit(instance);
        if (comptime @hasDecl(RTCDtlsTransportImpl, "deinitOwn")) RTCDtlsTransportImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCDtlsTransport")) {
            if (comptime @hasDecl(impls.RTCDtlsTransport, "installHooks")) impls.RTCDtlsTransport.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_iceTransport(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_iceTransport) |cached| {
            return cached;
        }
        const value = try RTCDtlsTransportImpl.get_iceTransport(instance);
        state.own.cached_iceTransport = value;
        return value;
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RTCDtlsTransportState {
        return try RTCDtlsTransportImpl.get_state(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCDtlsTransportImpl, "get_onstatechange")) return try RTCDtlsTransportImpl.get_onstatechange(instance);
        return event_handlers.value(EventHandler, instance, "onstatechange");
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCDtlsTransportImpl, "set_onstatechange")) return try RTCDtlsTransportImpl.set_onstatechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstatechange", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(RTCDtlsTransportImpl, "get_onerror")) return try RTCDtlsTransportImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(RTCDtlsTransportImpl, "set_onerror")) return try RTCDtlsTransportImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn call_getRemoteCertificates(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCDtlsTransportImpl.call_getRemoteCertificates(instance);
    }
};
