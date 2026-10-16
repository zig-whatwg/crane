//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothImpl = @import("impls").Bluetooth;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const BluetoothDeviceEventHandlers = @import("mixins").BluetoothDeviceEventHandlers;
const CharacteristicEventHandlers = @import("mixins").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("mixins").ServiceEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const BluetoothLEScan = @import("interfaces").BluetoothLEScan;
const RequestDeviceOptions = @import("dictionaries").RequestDeviceOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const BluetoothLEScanOptions = @import("dictionaries").BluetoothLEScanOptions;

pub const Bluetooth = struct {
    pub const Meta = struct {
        pub const name = "Bluetooth";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            BluetoothDeviceEventHandlers,
            CharacteristicEventHandlers,
            ServiceEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onavailabilitychanged", "get_onavailabilitychanged", "set_onavailabilitychanged" },
            .{ "referringDevice", "get_referringDevice", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAvailability", "call_getAvailability", 0 },
            .{ "getDevices", "call_getDevices", 0 },
            .{ "requestDevice", "call_requestDevice", 0 },
            .{ "requestLEScan", "call_requestLEScan", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAvailability",
            "getDevices",
            "requestDevice",
            "requestLEScan",
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
            .{ "onavailabilitychanged", "get_onavailabilitychanged", "set_onavailabilitychanged" },
            .{ "referringDevice", "get_referringDevice", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// [SecureContext] members - their own, their partial interface's or
        /// their mixin's: hidden in a realm that is not a secure context
        /// (WebIDL 3.3.13).
        pub const secure_context_members = .{
            "onadvertisementreceived",
            "ongattserverdisconnected",
            "oncharacteristicvaluechanged",
            "onserviceadded",
            "onservicechanged",
            "onserviceremoved",
            "requestLEScan",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onavailabilitychanged: typedefs.EventHandler = undefined,
            referringDevice: ?*runtime.Instance = null,
            onadvertisementreceived: typedefs.EventHandler = undefined,
            ongattserverdisconnected: typedefs.EventHandler = undefined,
            oncharacteristicvaluechanged: typedefs.EventHandler = undefined,
            onserviceadded: typedefs.EventHandler = undefined,
            onservicechanged: typedefs.EventHandler = undefined,
            onserviceremoved: typedefs.EventHandler = undefined,
            cached_referringDevice: ?*runtime.Instance = null,
            _internal: ?*BluetoothImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_onavailabilitychanged = &get_onavailabilitychanged,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_referringDevice = &get_referringDevice,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_onavailabilitychanged = &set_onavailabilitychanged,
        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_getAvailability = &call_getAvailability,
        .call_getDevices = &call_getDevices,
        .call_requestDevice = &call_requestDevice,
        .call_requestLEScan = &call_requestLEScan,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Bluetooth has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothImpl, "init") and @hasDecl(BluetoothImpl, "initOwn")) @compileError("BluetoothImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothImpl, "init")) return BluetoothImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BluetoothImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothImpl, "construction_args")) {
            inline for (BluetoothImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothImpl, "deinit") and @hasDecl(BluetoothImpl, "deinitOwn")) @compileError("BluetoothImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(BluetoothImpl, "deinit")) return BluetoothImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothImpl, "deinitOwn")) BluetoothImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Bluetooth")) {
            if (comptime @hasDecl(impls.Bluetooth, "installHooks")) impls.Bluetooth.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onavailabilitychanged(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(BluetoothImpl, "get_onavailabilitychanged")) return try BluetoothImpl.get_onavailabilitychanged(instance);
        return event_handlers.value(EventHandler, instance, "onavailabilitychanged");
    }

    pub fn set_onavailabilitychanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(BluetoothImpl, "set_onavailabilitychanged")) return try BluetoothImpl.set_onavailabilitychanged(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onavailabilitychanged", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_referringDevice(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_referringDevice) |cached| {
            return cached;
        }
        const value = try BluetoothImpl.get_referringDevice(instance);
        state.own.cached_referringDevice = value;
        if (value) |child| @import("dom").same_object_cache.made(instance, child, "referringDevice");
        return value;
    }

    /// Extended attributes: [SecureContext]
    pub const get_onadvertisementreceived = mixins.BluetoothDeviceEventHandlers.get_onadvertisementreceived;
    pub const set_onadvertisementreceived = mixins.BluetoothDeviceEventHandlers.set_onadvertisementreceived;

    /// Extended attributes: [SecureContext]
    pub const get_ongattserverdisconnected = mixins.BluetoothDeviceEventHandlers.get_ongattserverdisconnected;
    pub const set_ongattserverdisconnected = mixins.BluetoothDeviceEventHandlers.set_ongattserverdisconnected;

    /// Extended attributes: [SecureContext]
    pub const get_oncharacteristicvaluechanged = mixins.CharacteristicEventHandlers.get_oncharacteristicvaluechanged;
    pub const set_oncharacteristicvaluechanged = mixins.CharacteristicEventHandlers.set_oncharacteristicvaluechanged;

    /// Extended attributes: [SecureContext]
    pub const get_onserviceadded = mixins.ServiceEventHandlers.get_onserviceadded;
    pub const set_onserviceadded = mixins.ServiceEventHandlers.set_onserviceadded;

    /// Extended attributes: [SecureContext]
    pub const get_onservicechanged = mixins.ServiceEventHandlers.get_onservicechanged;
    pub const set_onservicechanged = mixins.ServiceEventHandlers.set_onservicechanged;

    /// Extended attributes: [SecureContext]
    pub const get_onserviceremoved = mixins.ServiceEventHandlers.get_onserviceremoved;
    pub const set_onserviceremoved = mixins.ServiceEventHandlers.set_onserviceremoved;

    /// Extended attributes: [SecureContext]
    pub fn call_requestLEScan(instance: *runtime.Instance, options: webidl.Opt(BluetoothLEScanOptions)) anyerror!runtime.JSValue {
        return try BluetoothImpl.call_requestLEScan(instance, options);
    }

    pub fn call_getAvailability(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothImpl.call_getAvailability(instance);
    }

    pub fn call_getDevices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothImpl.call_getDevices(instance);
    }

    pub fn call_requestDevice(instance: *runtime.Instance, options: webidl.Opt(RequestDeviceOptions)) anyerror!runtime.JSValue {
        return try BluetoothImpl.call_requestDevice(instance, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestLEScan",
        "call_getAvailability",
        "call_getDevices",
        "call_requestDevice",
    };
};
