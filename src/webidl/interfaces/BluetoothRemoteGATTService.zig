//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothRemoteGATTServiceImpl = @import("impls").BluetoothRemoteGATTService;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("mixins").CharacteristicEventHandlers;
const ServiceEventHandlers = @import("mixins").ServiceEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const UUID = @import("typedefs").UUID;
const BluetoothServiceUUID = @import("typedefs").BluetoothServiceUUID;
const BluetoothCharacteristicUUID = @import("typedefs").BluetoothCharacteristicUUID;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BluetoothRemoteGATTCharacteristic = @import("interfaces").BluetoothRemoteGATTCharacteristic;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BluetoothRemoteGATTService = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTService";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
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
            .{ "device", "get_device", null },
            .{ "uuid", "get_uuid", null },
            .{ "isPrimary", "get_isPrimary", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getCharacteristic", "call_getCharacteristic", 1 },
            .{ "getCharacteristics", "call_getCharacteristics", 0 },
            .{ "getIncludedService", "call_getIncludedService", 1 },
            .{ "getIncludedServices", "call_getIncludedServices", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCharacteristic",
            "getCharacteristics",
            "getIncludedService",
            "getIncludedServices",
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
            .{ "device", "get_device", null },
            .{ "uuid", "get_uuid", null },
            .{ "isPrimary", "get_isPrimary", null },
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
            "oncharacteristicvaluechanged",
            "onserviceadded",
            "onservicechanged",
            "onserviceremoved",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            uuid: typedefs.UUID = undefined,
            isPrimary: bool = undefined,
            oncharacteristicvaluechanged: typedefs.EventHandler = undefined,
            onserviceadded: typedefs.EventHandler = undefined,
            onservicechanged: typedefs.EventHandler = undefined,
            onserviceremoved: typedefs.EventHandler = undefined,
            cached_device: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTServiceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_device = &get_device,
        .get_isPrimary = &get_isPrimary,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_uuid = &get_uuid,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_getCharacteristic = &call_getCharacteristic,
        .call_getCharacteristics = &call_getCharacteristics,
        .call_getIncludedService = &call_getIncludedService,
        .call_getIncludedServices = &call_getIncludedServices,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BluetoothRemoteGATTService has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "init") and @hasDecl(BluetoothRemoteGATTServiceImpl, "initOwn")) @compileError("BluetoothRemoteGATTServiceImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "init")) return BluetoothRemoteGATTServiceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothRemoteGATTServiceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "construction_args")) {
            inline for (BluetoothRemoteGATTServiceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "deinit") and @hasDecl(BluetoothRemoteGATTServiceImpl, "deinitOwn")) @compileError("BluetoothRemoteGATTServiceImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "deinit")) return BluetoothRemoteGATTServiceImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothRemoteGATTServiceImpl, "deinitOwn")) BluetoothRemoteGATTServiceImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothRemoteGATTService")) {
            if (comptime @hasDecl(impls.BluetoothRemoteGATTService, "installHooks")) impls.BluetoothRemoteGATTService.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTServiceImpl.get_device(instance);
        state.own.cached_device = value;
        @import("dom").same_object_cache.made(instance, value, "device");
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTServiceImpl.get_uuid(instance);
    }

    pub fn get_isPrimary(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothRemoteGATTServiceImpl.get_isPrimary(instance);
    }

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

    pub fn call_getCharacteristics(instance: *runtime.Instance, characteristic: webidl.Opt(BluetoothCharacteristicUUID)) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristics(instance, characteristic);
    }

    pub fn call_getIncludedServices(instance: *runtime.Instance, service: webidl.Opt(BluetoothServiceUUID)) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedServices(instance, service);
    }

    pub fn call_getCharacteristic(instance: *runtime.Instance, characteristic: BluetoothCharacteristicUUID) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTServiceImpl.call_getCharacteristic(instance, characteristic);
    }

    pub fn call_getIncludedService(instance: *runtime.Instance, service: BluetoothServiceUUID) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTServiceImpl.call_getIncludedService(instance, service);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getCharacteristics",
        "call_getIncludedServices",
        "call_getCharacteristic",
        "call_getIncludedService",
    };
};
