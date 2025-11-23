//! Generated from: webusb.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBConfigurationImpl = @import("impls").USBConfiguration;
const USBInterface = @import("interfaces").USBInterface;
const USBDevice = @import("interfaces").USBDevice;
const DOMString = @import("typedefs").DOMString;

pub const USBConfiguration = struct {
    pub const Meta = struct {
        pub const name = "USBConfiguration";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "configurationValue", "get_configurationValue", null },
            .{ "configurationName", "get_configurationName", null },
            .{ "interfaces", "get_interfaces", null },
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
            .{ "configurationValue", "get_configurationValue", null },
            .{ "configurationName", "get_configurationName", null },
            .{ "interfaces", "get_interfaces", null },
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
            configurationValue: u8 = undefined,
            configurationName: ?runtime.DOMString = null,
            interfaces: runtime.FrozenArray(USBInterface) = undefined,
            _internal: ?*USBConfigurationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_configurationName = &get_configurationName,
        .get_configurationValue = &get_configurationValue,
        .get_interfaces = &get_interfaces,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBConfigurationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBConfigurationImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, device: *runtime.Instance, configurationValue: u8) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBConfigurationImpl.call_constructor(allocator, ctx, device, configurationValue);
    }

    pub fn get_configurationValue(instance: *runtime.Instance) anyerror!u8 {
        return try USBConfigurationImpl.get_configurationValue(instance);
    }

    pub fn get_configurationName(instance: *runtime.Instance) anyerror!DOMString {
        return try USBConfigurationImpl.get_configurationName(instance);
    }

    pub fn get_interfaces(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try USBConfigurationImpl.get_interfaces(instance);
    }

};
