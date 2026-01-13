//! Generated from: navigation-timing.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PerformanceNavigationImpl = @import("impls").PerformanceNavigation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const PerformanceNavigation = struct {
    pub const Meta = struct {
        pub const name = "PerformanceNavigation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "redirectCount", "get_redirectCount", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"type": u16 = undefined,
            redirectCount: u16 = undefined,
            _internal: ?*PerformanceNavigationImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short TYPE_NAVIGATE = 0;
    pub fn get_TYPE_NAVIGATE() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short TYPE_RELOAD = 1;
    pub fn get_TYPE_RELOAD() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short TYPE_BACK_FORWARD = 2;
    pub fn get_TYPE_BACK_FORWARD() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TYPE_RESERVED = 255;
    pub fn get_TYPE_RESERVED() u16 {
        return 255;
    }

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for PerformanceNavigation
    /// Generated from [Default] toJSON extended attribute
    pub const PerformanceNavigationToJSON = struct {
        type: u16,
        redirectCount: u16,
    };

    const delegates = .{

        .get_TYPE_BACK_FORWARD = &get_TYPE_BACK_FORWARD,
        .get_TYPE_NAVIGATE = &get_TYPE_NAVIGATE,
        .get_TYPE_RELOAD = &get_TYPE_RELOAD,
        .get_TYPE_RESERVED = &get_TYPE_RESERVED,
        .get_redirectCount = &get_redirectCount,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PerformanceNavigationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PerformanceNavigationImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceNavigationImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_type(instance);
    }

    pub fn get_redirectCount(instance: *runtime.Instance) anyerror!u16 {
        return try PerformanceNavigationImpl.get_redirectCount(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PerformanceNavigationToJSON {
        return try PerformanceNavigationImpl.call_toJSON(instance);
    }

};
