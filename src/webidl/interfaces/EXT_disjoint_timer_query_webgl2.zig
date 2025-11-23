//! Generated from: EXT_disjoint_timer_query_webgl2.idl
//! Generated at: 2025-11-23T20:06:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_disjoint_timer_query_webgl2Impl = @import("impls").EXT_disjoint_timer_query_webgl2;
const GLenum = @import("typedefs").GLenum;
const WebGLQuery = @import("interfaces").WebGLQuery;

pub const EXT_disjoint_timer_query_webgl2 = struct {
    pub const Meta = struct {
        pub const name = "EXT_disjoint_timer_query_webgl2";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "queryCounterEXT", "call_queryCounterEXT", 2 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "QUERY_COUNTER_BITS_EXT", "get_QUERY_COUNTER_BITS_EXT" },
            .{ "TIME_ELAPSED_EXT", "get_TIME_ELAPSED_EXT" },
            .{ "TIMESTAMP_EXT", "get_TIMESTAMP_EXT" },
            .{ "GPU_DISJOINT_EXT", "get_GPU_DISJOINT_EXT" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "queryCounterEXT",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum QUERY_COUNTER_BITS_EXT = 34916;
    pub fn get_QUERY_COUNTER_BITS_EXT() GLenum {
        return 34916;
    }

    /// WebIDL constant: const GLenum TIME_ELAPSED_EXT = 35007;
    pub fn get_TIME_ELAPSED_EXT() GLenum {
        return 35007;
    }

    /// WebIDL constant: const GLenum TIMESTAMP_EXT = 36392;
    pub fn get_TIMESTAMP_EXT() GLenum {
        return 36392;
    }

    /// WebIDL constant: const GLenum GPU_DISJOINT_EXT = 36795;
    pub fn get_GPU_DISJOINT_EXT() GLenum {
        return 36795;
    }

    const delegates = .{

        .get_GPU_DISJOINT_EXT = &get_GPU_DISJOINT_EXT,
        .get_QUERY_COUNTER_BITS_EXT = &get_QUERY_COUNTER_BITS_EXT,
        .get_TIMESTAMP_EXT = &get_TIMESTAMP_EXT,
        .get_TIME_ELAPSED_EXT = &get_TIME_ELAPSED_EXT,

        .call_queryCounterEXT = &call_queryCounterEXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_disjoint_timer_query_webgl2Impl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_disjoint_timer_query_webgl2Impl.deinit(instance);
    }

    pub fn call_queryCounterEXT(instance: *runtime.Instance, query: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_query_webgl2Impl.call_queryCounterEXT(instance, query, target);
    }

};
