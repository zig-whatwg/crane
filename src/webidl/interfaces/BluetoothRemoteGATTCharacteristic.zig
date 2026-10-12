//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothRemoteGATTCharacteristicImpl = @import("impls").BluetoothRemoteGATTCharacteristic;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const CharacteristicEventHandlers = @import("mixins").CharacteristicEventHandlers;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const UUID = @import("typedefs").UUID;
const BluetoothCharacteristicProperties = @import("interfaces").BluetoothCharacteristicProperties;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BluetoothRemoteGATTDescriptor = @import("interfaces").BluetoothRemoteGATTDescriptor;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const BluetoothDescriptorUUID = @import("typedefs").BluetoothDescriptorUUID;
const BluetoothRemoteGATTService = @import("interfaces").BluetoothRemoteGATTService;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BluetoothRemoteGATTCharacteristic = struct {
    pub const Meta = struct {
        pub const name = "BluetoothRemoteGATTCharacteristic";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            CharacteristicEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "service", "get_service", null },
            .{ "uuid", "get_uuid", null },
            .{ "properties", "get_properties", null },
            .{ "value", "get_value", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getDescriptor", "call_getDescriptor", 1 },
            .{ "getDescriptors", "call_getDescriptors", 0 },
            .{ "readValue", "call_readValue", 0 },
            .{ "writeValue", "call_writeValue", 1 },
            .{ "writeValueWithResponse", "call_writeValueWithResponse", 1 },
            .{ "writeValueWithoutResponse", "call_writeValueWithoutResponse", 1 },
            .{ "startNotifications", "call_startNotifications", 0 },
            .{ "stopNotifications", "call_stopNotifications", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getDescriptor",
            "getDescriptors",
            "readValue",
            "writeValue",
            "writeValueWithResponse",
            "writeValueWithoutResponse",
            "startNotifications",
            "stopNotifications",
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
            .{ "service", "get_service", null },
            .{ "uuid", "get_uuid", null },
            .{ "properties", "get_properties", null },
            .{ "value", "get_value", null },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            service: *runtime.Instance = undefined,
            uuid: typedefs.UUID = undefined,
            properties: *runtime.Instance = undefined,
            value: ?runtime.DataView = null,
            oncharacteristicvaluechanged: typedefs.EventHandler = undefined,
            cached_service: ?*runtime.Instance = null,
            _internal: ?*BluetoothRemoteGATTCharacteristicImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_properties = &get_properties,
        .get_service = &get_service,
        .get_uuid = &get_uuid,
        .get_value = &get_value,

        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,

        .call_getDescriptor = &call_getDescriptor,
        .call_getDescriptors = &call_getDescriptors,
        .call_readValue = &call_readValue,
        .call_startNotifications = &call_startNotifications,
        .call_stopNotifications = &call_stopNotifications,
        .call_writeValue = &call_writeValue,
        .call_writeValueWithResponse = &call_writeValueWithResponse,
        .call_writeValueWithoutResponse = &call_writeValueWithoutResponse,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BluetoothRemoteGATTCharacteristic has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "init") and @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "initOwn")) @compileError("BluetoothRemoteGATTCharacteristicImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "init")) return BluetoothRemoteGATTCharacteristicImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothRemoteGATTCharacteristicImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "construction_args")) {
            inline for (BluetoothRemoteGATTCharacteristicImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "deinit") and @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "deinitOwn")) @compileError("BluetoothRemoteGATTCharacteristicImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "deinit")) return BluetoothRemoteGATTCharacteristicImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothRemoteGATTCharacteristicImpl, "deinitOwn")) BluetoothRemoteGATTCharacteristicImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothRemoteGATTCharacteristic")) {
            if (comptime @hasDecl(impls.BluetoothRemoteGATTCharacteristic, "installHooks")) impls.BluetoothRemoteGATTCharacteristic.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_service(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_service) |cached| {
            return cached;
        }
        const value = try BluetoothRemoteGATTCharacteristicImpl.get_service(instance);
        state.own.cached_service = value;
        return value;
    }

    pub fn get_uuid(instance: *runtime.Instance) anyerror!UUID {
        return try BluetoothRemoteGATTCharacteristicImpl.get_uuid(instance);
    }

    pub fn get_properties(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothRemoteGATTCharacteristicImpl.get_properties(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.get_value(instance);
    }

    pub const get_oncharacteristicvaluechanged = mixins.CharacteristicEventHandlers.get_oncharacteristicvaluechanged;
    pub const set_oncharacteristicvaluechanged = mixins.CharacteristicEventHandlers.set_oncharacteristicvaluechanged;

    pub fn call_stopNotifications(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_stopNotifications(instance);
    }

    pub fn call_getDescriptors(instance: *runtime.Instance, descriptor: webidl.Opt(BluetoothDescriptorUUID)) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptors(instance, descriptor);
    }

    pub fn call_writeValueWithoutResponse(instance: *runtime.Instance, value: BufferSource) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithoutResponse(instance, value);
    }

    pub fn call_writeValue(instance: *runtime.Instance, value: BufferSource) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValue(instance, value);
    }

    pub fn call_getDescriptor(instance: *runtime.Instance, descriptor: BluetoothDescriptorUUID) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_getDescriptor(instance, descriptor);
    }

    pub fn call_readValue(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_readValue(instance);
    }

    pub fn call_writeValueWithResponse(instance: *runtime.Instance, value: BufferSource) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_writeValueWithResponse(instance, value);
    }

    pub fn call_startNotifications(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothRemoteGATTCharacteristicImpl.call_startNotifications(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_stopNotifications",
        "call_getDescriptors",
        "call_writeValueWithoutResponse",
        "call_writeValue",
        "call_getDescriptor",
        "call_readValue",
        "call_writeValueWithResponse",
        "call_startNotifications",
    };
};
