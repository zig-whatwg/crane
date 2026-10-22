//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothDeviceImpl = @import("impls").BluetoothDevice;
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
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BluetoothRemoteGATTServer = @import("interfaces").BluetoothRemoteGATTServer;
const WatchAdvertisementsOptions = @import("dictionaries").WatchAdvertisementsOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const BluetoothDevice = struct {
    pub const Meta = struct {
        pub const name = "BluetoothDevice";
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
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "gatt", "get_gatt", null },
            .{ "watchingAdvertisements", "get_watchingAdvertisements", null },
            .{ "onadvertisementreceived", "get_onadvertisementreceived", "set_onadvertisementreceived" },
            .{ "ongattserverdisconnected", "get_ongattserverdisconnected", "set_ongattserverdisconnected" },
            .{ "oncharacteristicvaluechanged", "get_oncharacteristicvaluechanged", "set_oncharacteristicvaluechanged" },
            .{ "onserviceadded", "get_onserviceadded", "set_onserviceadded" },
            .{ "onservicechanged", "get_onservicechanged", "set_onservicechanged" },
            .{ "onserviceremoved", "get_onserviceremoved", "set_onserviceremoved" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "forget", "call_forget", 0 },
            .{ "watchAdvertisements", "call_watchAdvertisements", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "forget",
            "watchAdvertisements",
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
            .{ "id", "get_id", null },
            .{ "name", "get_name", null },
            .{ "gatt", "get_gatt", null },
            .{ "watchingAdvertisements", "get_watchingAdvertisements", null },
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
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            name: ?runtime.DOMString = null,
            gatt: ?*runtime.Instance = null,
            watchingAdvertisements: bool = undefined,
            onadvertisementreceived: typedefs.EventHandler = undefined,
            ongattserverdisconnected: typedefs.EventHandler = undefined,
            oncharacteristicvaluechanged: typedefs.EventHandler = undefined,
            onserviceadded: typedefs.EventHandler = undefined,
            onservicechanged: typedefs.EventHandler = undefined,
            onserviceremoved: typedefs.EventHandler = undefined,
            _internal: ?*BluetoothDeviceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_gatt = &get_gatt,
        .get_id = &get_id,
        .get_name = &get_name,
        .get_onadvertisementreceived = &get_onadvertisementreceived,
        .get_oncharacteristicvaluechanged = &get_oncharacteristicvaluechanged,
        .get_ongattserverdisconnected = &get_ongattserverdisconnected,
        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,
        .get_watchingAdvertisements = &get_watchingAdvertisements,

        .set_onadvertisementreceived = &set_onadvertisementreceived,
        .set_oncharacteristicvaluechanged = &set_oncharacteristicvaluechanged,
        .set_ongattserverdisconnected = &set_ongattserverdisconnected,
        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,

        .call_forget = &call_forget,
        .call_watchAdvertisements = &call_watchAdvertisements,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("BluetoothDevice has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(BluetoothDeviceImpl, "init") and @hasDecl(BluetoothDeviceImpl, "initOwn")) @compileError("BluetoothDeviceImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothDeviceImpl, "init")) return BluetoothDeviceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BluetoothDeviceImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothDeviceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothDeviceImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothDeviceImpl, "construction_args")) {
            inline for (BluetoothDeviceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothDeviceImpl, "deinit") and @hasDecl(BluetoothDeviceImpl, "deinitOwn")) @compileError("BluetoothDeviceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(BluetoothDeviceImpl, "deinit")) return BluetoothDeviceImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothDeviceImpl, "deinitOwn")) BluetoothDeviceImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothDevice")) {
            if (comptime @hasDecl(impls.BluetoothDevice, "installHooks")) impls.BluetoothDevice.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try BluetoothDeviceImpl.get_id(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try BluetoothDeviceImpl.get_name(instance);
    }

    pub fn get_gatt(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try BluetoothDeviceImpl.get_gatt(instance);
    }

    pub fn get_watchingAdvertisements(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothDeviceImpl.get_watchingAdvertisements(instance);
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

    pub fn call_forget(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothDeviceImpl.call_forget(instance);
    }

    pub fn call_watchAdvertisements(instance: *runtime.Instance, options: webidl.Opt(WatchAdvertisementsOptions)) anyerror!runtime.JSValue {
        return try BluetoothDeviceImpl.call_watchAdvertisements(instance, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onadvertisementreceived", "set_ongattserverdisconnected", "set_oncharacteristicvaluechanged", "set_onserviceadded", "set_onservicechanged", "set_onserviceremoved" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_forget",
        "call_watchAdvertisements",
    };
};
