//! Generated from: web-bluetooth-scanning.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothLEScanFilterImpl = @import("impls").BluetoothLEScanFilter;
const BluetoothManufacturerDataFilter = @import("interfaces").BluetoothManufacturerDataFilter;
const BluetoothLEScanFilterInit = @import("dictionaries").BluetoothLEScanFilterInit;
const UUID = @import("typedefs").UUID;
const DOMString = @import("typedefs").DOMString;
const BluetoothServiceDataFilter = @import("interfaces").BluetoothServiceDataFilter;

pub const BluetoothLEScanFilter = struct {
    pub const Meta = struct {
        pub const name = "BluetoothLEScanFilter";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "namePrefix", "get_namePrefix", null },
            .{ "services", "get_services", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "namePrefix", "get_namePrefix", null },
            .{ "services", "get_services", null },
            .{ "manufacturerData", "get_manufacturerData", null },
            .{ "serviceData", "get_serviceData", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: ?runtime.DOMString = null,
            namePrefix: ?runtime.DOMString = null,
            services: runtime.FrozenArray(UUID) = undefined,
            manufacturerData: *runtime.Instance = undefined,
            serviceData: *runtime.Instance = undefined,
            _internal: ?*BluetoothLEScanFilterImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_manufacturerData = &get_manufacturerData,
        .get_name = &get_name,
        .get_namePrefix = &get_namePrefix,
        .get_serviceData = &get_serviceData,
        .get_services = &get_services,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BluetoothLEScanFilterImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BluetoothLEScanFilterImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: BluetoothLEScanFilterInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BluetoothLEScanFilterImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothLEScanFilterImpl.get_name(instance);
    }

    pub fn get_namePrefix(instance: *runtime.Instance) anyerror!DOMString {
        return try BluetoothLEScanFilterImpl.get_namePrefix(instance);
    }

    pub fn get_services(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BluetoothLEScanFilterImpl.get_services(instance);
    }

    pub fn get_manufacturerData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothLEScanFilterImpl.get_manufacturerData(instance);
    }

    pub fn get_serviceData(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BluetoothLEScanFilterImpl.get_serviceData(instance);
    }

};
