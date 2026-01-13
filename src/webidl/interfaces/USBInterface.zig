//! Generated from: webusb.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBInterfaceImpl = @import("impls").USBInterface;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USBConfiguration = @import("interfaces").USBConfiguration;
const USBAlternateInterface = @import("interfaces").USBAlternateInterface;

pub const USBInterface = struct {
    pub const Meta = struct {
        pub const name = "USBInterface";
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
            .{ "interfaceNumber", "get_interfaceNumber", null },
            .{ "alternate", "get_alternate", null },
            .{ "alternates", "get_alternates", null },
            .{ "claimed", "get_claimed", null },
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
            .{ "interfaceNumber", "get_interfaceNumber", null },
            .{ "alternate", "get_alternate", null },
            .{ "alternates", "get_alternates", null },
            .{ "claimed", "get_claimed", null },
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
            interfaceNumber: u8 = undefined,
            alternate: *runtime.Instance = undefined,
            alternates: runtime.JSValue = undefined,
            claimed: bool = undefined,
            _internal: ?*USBInterfaceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_alternate = &get_alternate,
        .get_alternates = &get_alternates,
        .get_claimed = &get_claimed,
        .get_interfaceNumber = &get_interfaceNumber,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBInterfaceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return USBInterfaceImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBInterfaceImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, configuration: *runtime.Instance, interfaceNumber: u8) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBInterfaceImpl.call_constructor(ctx, configuration, interfaceNumber);
    }

    pub fn get_interfaceNumber(instance: *runtime.Instance) anyerror!u8 {
        return try USBInterfaceImpl.get_interfaceNumber(instance);
    }

    pub fn get_alternate(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try USBInterfaceImpl.get_alternate(instance);
    }

    pub fn get_alternates(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try USBInterfaceImpl.get_alternates(instance);
    }

    pub fn get_claimed(instance: *runtime.Instance) anyerror!bool {
        return try USBInterfaceImpl.get_claimed(instance);
    }

};
