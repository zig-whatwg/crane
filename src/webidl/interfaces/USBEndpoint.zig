//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBEndpointImpl = @import("impls").USBEndpoint;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBEndpointType = @import("enums").USBEndpointType;
const USBDirection = @import("enums").USBDirection;
const USBAlternateInterface = @import("USBAlternateInterface.zig").USBAlternateInterface;

pub const USBEndpoint = struct {
    pub const Meta = struct {
        pub const name = "USBEndpoint";
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
            .{ "endpointNumber", "get_endpointNumber", null },
            .{ "direction", "get_direction", null },
            .{ "type", "get_type", null },
            .{ "packetSize", "get_packetSize", null },
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
            .{ "endpointNumber", "get_endpointNumber", null },
            .{ "direction", "get_direction", null },
            .{ "type", "get_type", null },
            .{ "packetSize", "get_packetSize", null },
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
            endpointNumber: u8 = undefined,
            direction: enums.USBDirection = undefined,
            @"type": enums.USBEndpointType = undefined,
            packetSize: u32 = undefined,
            _internal: ?*USBEndpointImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_direction = &get_direction,
        .get_endpointNumber = &get_endpointNumber,
        .get_packetSize = &get_packetSize,
        .get_type = &get_type,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBEndpointImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return USBEndpointImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBEndpointImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, alternate: *runtime.Instance, endpointNumber: u8, direction: USBDirection) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBEndpointImpl.call_constructor(ctx, alternate, endpointNumber, direction);
    }

    pub fn get_endpointNumber(instance: *runtime.Instance) anyerror!u8 {
        return try USBEndpointImpl.get_endpointNumber(instance);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!USBDirection {
        return try USBEndpointImpl.get_direction(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!USBEndpointType {
        return try USBEndpointImpl.get_type(instance);
    }

    pub fn get_packetSize(instance: *runtime.Instance) anyerror!u32 {
        return try USBEndpointImpl.get_packetSize(instance);
    }

};
