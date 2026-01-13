//! Generated from: web-bluetooth-scanning.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothLEScanImpl = @import("impls").BluetoothLEScan;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const BluetoothLEScanFilter = @import("interfaces").BluetoothLEScanFilter;

pub const BluetoothLEScan = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScan";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "filters", "get_filters", null },
            .{ "keepRepeatedDevices", "get_keepRepeatedDevices", null },
            .{ "acceptAllAdvertisements", "get_acceptAllAdvertisements", null },
            .{ "active", "get_active", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "stop", "call_stop", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "stop",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "filters", "get_filters", null },
            .{ "keepRepeatedDevices", "get_keepRepeatedDevices", null },
            .{ "acceptAllAdvertisements", "get_acceptAllAdvertisements", null },
            .{ "active", "get_active", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            filters: runtime.JSValue = undefined,
            keepRepeatedDevices: bool = undefined,
            acceptAllAdvertisements: bool = undefined,
            active: bool = undefined,
            _internal: ?*BluetoothLEScanImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_acceptAllAdvertisements = &get_acceptAllAdvertisements,
        .get_active = &get_active,
        .get_filters = &get_filters,
        .get_keepRepeatedDevices = &get_keepRepeatedDevices,

        .call_stop = &call_stop,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothLEScanImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BluetoothLEScanImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothLEScanImpl.deinit(instance);
    }

    pub fn get_filters(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try BluetoothLEScanImpl.get_filters(instance);
    }

    pub fn get_keepRepeatedDevices(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_keepRepeatedDevices(instance);
    }

    pub fn get_acceptAllAdvertisements(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_acceptAllAdvertisements(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try BluetoothLEScanImpl.get_active(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try BluetoothLEScanImpl.call_stop(instance);
    }

};
