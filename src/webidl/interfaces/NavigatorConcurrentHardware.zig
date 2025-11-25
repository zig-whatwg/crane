//! Generated from: html.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorConcurrentHardwareImpl = @import("impls").NavigatorConcurrentHardware;

pub const NavigatorConcurrentHardware = struct {
    pub const Meta = struct {
        pub const name = "NavigatorConcurrentHardware";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
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
            .{ "hardwareConcurrency", "get_hardwareConcurrency", null },
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
            hardwareConcurrency: u64 = undefined,
            _internal: ?*NavigatorConcurrentHardwareImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_hardwareConcurrency = &get_hardwareConcurrency,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NavigatorConcurrentHardwareImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorConcurrentHardwareImpl.deinit(instance);
    }

    pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
        return try NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(instance);
    }

};
