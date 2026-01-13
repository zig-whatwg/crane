//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBAlternateInterfaceImpl = @import("impls").USBAlternateInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBInterface = @import("USBInterface.zig").USBInterface;
const USBEndpoint = @import("USBEndpoint.zig").USBEndpoint;
const DOMString = @import("typedefs").DOMString;

pub const USBAlternateInterface = struct {
    pub const Meta = struct {
        pub const name = "USBAlternateInterface";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "alternateSetting", "get_alternateSetting", null },
            .{ "interfaceClass", "get_interfaceClass", null },
            .{ "interfaceSubclass", "get_interfaceSubclass", null },
            .{ "interfaceProtocol", "get_interfaceProtocol", null },
            .{ "interfaceName", "get_interfaceName", null },
            .{ "endpoints", "get_endpoints", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "alternateSetting", "get_alternateSetting", null },
            .{ "interfaceClass", "get_interfaceClass", null },
            .{ "interfaceSubclass", "get_interfaceSubclass", null },
            .{ "interfaceProtocol", "get_interfaceProtocol", null },
            .{ "interfaceName", "get_interfaceName", null },
            .{ "endpoints", "get_endpoints", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            alternateSetting: u8 = undefined,
            interfaceClass: u8 = undefined,
            interfaceSubclass: u8 = undefined,
            interfaceProtocol: u8 = undefined,
            interfaceName: ?typedefs.DOMString = null,
            endpoints: runtime.JSValue = undefined,
            _internal: ?*USBAlternateInterfaceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alternateSetting = &get_alternateSetting,
        .get_endpoints = &get_endpoints,
        .get_interfaceClass = &get_interfaceClass,
        .get_interfaceName = &get_interfaceName,
        .get_interfaceProtocol = &get_interfaceProtocol,
        .get_interfaceSubclass = &get_interfaceSubclass,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBAlternateInterfaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return USBAlternateInterfaceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBAlternateInterfaceImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, deviceInterface: *runtime.Instance, alternateSetting: u8) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBAlternateInterfaceImpl.call_constructor(ctx, deviceInterface, alternateSetting);
    }

    pub fn get_alternateSetting(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_alternateSetting(instance);
    }

    pub fn get_interfaceClass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceClass(instance);
    }

    pub fn get_interfaceSubclass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceSubclass(instance);
    }

    pub fn get_interfaceProtocol(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceProtocol(instance);
    }

    pub fn get_interfaceName(instance: *runtime.Instance) anyerror!?DOMString {
        return try USBAlternateInterfaceImpl.get_interfaceName(instance);
    }

    pub fn get_endpoints(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try USBAlternateInterfaceImpl.get_endpoints(instance);
    }

};
