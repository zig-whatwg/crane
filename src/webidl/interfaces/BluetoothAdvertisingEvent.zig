//! Generated from: web-bluetooth.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothAdvertisingEventImpl = @import("impls").BluetoothAdvertisingEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const BluetoothDevice = @import("interfaces").BluetoothDevice;
const BluetoothManufacturerDataMap = @import("interfaces").BluetoothManufacturerDataMap;
const UUID = @import("typedefs").UUID;
const EventTarget = @import("interfaces").EventTarget;
const BluetoothAdvertisingEventInit = @import("dictionaries").BluetoothAdvertisingEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;
const BluetoothServiceDataMap = @import("interfaces").BluetoothServiceDataMap;

pub const BluetoothAdvertisingEvent = struct {
    pub const Meta = struct {
        pub const name = "BluetoothAdvertisingEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "device", "get_device", null },
            .{ "uuids", "get_uuids", null },
            .{ "name", "get_name", null },
            .{ "appearance", "get_appearance", null },
            .{ "txPower", "get_txPower", null },
            .{ "rssi", "get_rssi", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "device", "get_device", null },
            .{ "uuids", "get_uuids", null },
            .{ "name", "get_name", null },
            .{ "appearance", "get_appearance", null },
            .{ "txPower", "get_txPower", null },
            .{ "rssi", "get_rssi", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            uuids: runtime.JSValue = undefined,
            name: ?runtime.DOMString = null,
            appearance: ?u16 = null,
            txPower: ?i8 = null,
            rssi: ?i8 = null,
            manufacturerData: *runtime.Instance = undefined,
            serviceData: *runtime.Instance = undefined,
            cached_device: ?*runtime.Instance = null,
            cached_manufacturerData: ?*runtime.Instance = null,
            cached_serviceData: ?*runtime.Instance = null,
            _internal: ?*BluetoothAdvertisingEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_appearance = &get_appearance,
        .get_device = &get_device,
        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_rssi = &get_rssi,
        .get_serviceData = &get_serviceData,
        .get_txPower = &get_txPower,
        .get_uuids = &get_uuids,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("BluetoothAdvertisingEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "init") and @hasDecl(BluetoothAdvertisingEventImpl, "initOwn")) @compileError("BluetoothAdvertisingEventImpl defines both init and initOwn");
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "init")) return BluetoothAdvertisingEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try BluetoothAdvertisingEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "init")) return false;
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "construction_args")) {
            inline for (BluetoothAdvertisingEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "deinit") and @hasDecl(BluetoothAdvertisingEventImpl, "deinitOwn")) @compileError("BluetoothAdvertisingEventImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "deinit")) return BluetoothAdvertisingEventImpl.deinit(instance);
        if (comptime @hasDecl(BluetoothAdvertisingEventImpl, "deinitOwn")) BluetoothAdvertisingEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "BluetoothAdvertisingEvent")) {
            if (comptime @hasDecl(impls.BluetoothAdvertisingEvent, "installHooks")) impls.BluetoothAdvertisingEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, init_data: BluetoothAdvertisingEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BluetoothAdvertisingEventImpl.call_constructor(ctx, @"type", init_data);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_device(instance);
        state.own.cached_device = value;
        @import("dom").same_object_cache.made(instance, value, "device");
        return value;
    }

    pub fn get_uuids(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothAdvertisingEventImpl.get_uuids(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try BluetoothAdvertisingEventImpl.get_name(instance);
    }

    pub fn get_appearance(instance: *runtime.Instance) anyerror!?u16 {
        return try BluetoothAdvertisingEventImpl.get_appearance(instance);
    }

    pub fn get_txPower(instance: *runtime.Instance) anyerror!?i8 {
        return try BluetoothAdvertisingEventImpl.get_txPower(instance);
    }

    pub fn get_rssi(instance: *runtime.Instance) anyerror!?i8 {
        return try BluetoothAdvertisingEventImpl.get_rssi(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_manufacturerData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_manufacturerData(instance);
        state.own.cached_manufacturerData = value;
        @import("dom").same_object_cache.made(instance, value, "manufacturerData");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_serviceData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_serviceData) |cached| {
            return cached;
        }
        const value = try BluetoothAdvertisingEventImpl.get_serviceData(instance);
        state.own.cached_serviceData = value;
        @import("dom").same_object_cache.made(instance, value, "serviceData");
        return value;
    }
};
