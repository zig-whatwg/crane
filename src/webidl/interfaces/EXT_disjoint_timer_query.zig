//! Generated from: EXT_disjoint_timer_query.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_disjoint_timer_queryImpl = @import("impls").EXT_disjoint_timer_query;
const GLenum = @import("typedefs").GLenum;
const WebGLTimerQueryEXT = @import("interfaces").WebGLTimerQueryEXT;

pub const EXT_disjoint_timer_query = struct {
    pub const Meta = struct {
        pub const name = "EXT_disjoint_timer_query";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createQueryEXT", "call_createQueryEXT", 0 },
            .{ "deleteQueryEXT", "call_deleteQueryEXT", 1 },
            .{ "isQueryEXT", "call_isQueryEXT", 1 },
            .{ "beginQueryEXT", "call_beginQueryEXT", 2 },
            .{ "endQueryEXT", "call_endQueryEXT", 1 },
            .{ "queryCounterEXT", "call_queryCounterEXT", 2 },
            .{ "getQueryEXT", "call_getQueryEXT", 2 },
            .{ "getQueryObjectEXT", "call_getQueryObjectEXT", 2 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "QUERY_COUNTER_BITS_EXT", "get_QUERY_COUNTER_BITS_EXT" },
            .{ "CURRENT_QUERY_EXT", "get_CURRENT_QUERY_EXT" },
            .{ "QUERY_RESULT_EXT", "get_QUERY_RESULT_EXT" },
            .{ "QUERY_RESULT_AVAILABLE_EXT", "get_QUERY_RESULT_AVAILABLE_EXT" },
            .{ "TIME_ELAPSED_EXT", "get_TIME_ELAPSED_EXT" },
            .{ "TIMESTAMP_EXT", "get_TIMESTAMP_EXT" },
            .{ "GPU_DISJOINT_EXT", "get_GPU_DISJOINT_EXT" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createQueryEXT",
            "deleteQueryEXT",
            "isQueryEXT",
            "beginQueryEXT",
            "endQueryEXT",
            "queryCounterEXT",
            "getQueryEXT",
            "getQueryObjectEXT",
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
        struct {
            _internal: ?*EXT_disjoint_timer_queryImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum QUERY_COUNTER_BITS_EXT = 34916;
    pub fn get_QUERY_COUNTER_BITS_EXT() GLenum {
        return 34916;
    }

    /// WebIDL constant: const GLenum CURRENT_QUERY_EXT = 34917;
    pub fn get_CURRENT_QUERY_EXT() GLenum {
        return 34917;
    }

    /// WebIDL constant: const GLenum QUERY_RESULT_EXT = 34918;
    pub fn get_QUERY_RESULT_EXT() GLenum {
        return 34918;
    }

    /// WebIDL constant: const GLenum QUERY_RESULT_AVAILABLE_EXT = 34919;
    pub fn get_QUERY_RESULT_AVAILABLE_EXT() GLenum {
        return 34919;
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

        .get_CURRENT_QUERY_EXT = &get_CURRENT_QUERY_EXT,
        .get_GPU_DISJOINT_EXT = &get_GPU_DISJOINT_EXT,
        .get_QUERY_COUNTER_BITS_EXT = &get_QUERY_COUNTER_BITS_EXT,
        .get_QUERY_RESULT_AVAILABLE_EXT = &get_QUERY_RESULT_AVAILABLE_EXT,
        .get_QUERY_RESULT_EXT = &get_QUERY_RESULT_EXT,
        .get_TIMESTAMP_EXT = &get_TIMESTAMP_EXT,
        .get_TIME_ELAPSED_EXT = &get_TIME_ELAPSED_EXT,

        .call_beginQueryEXT = &call_beginQueryEXT,
        .call_createQueryEXT = &call_createQueryEXT,
        .call_deleteQueryEXT = &call_deleteQueryEXT,
        .call_endQueryEXT = &call_endQueryEXT,
        .call_getQueryEXT = &call_getQueryEXT,
        .call_getQueryObjectEXT = &call_getQueryObjectEXT,
        .call_isQueryEXT = &call_isQueryEXT,
        .call_queryCounterEXT = &call_queryCounterEXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_disjoint_timer_queryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_disjoint_timer_queryImpl.deinit(instance);
    }

    pub fn call_queryCounterEXT(instance: *runtime.Instance, query: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_queryCounterEXT(instance, query, target);
    }

    pub fn call_createQueryEXT(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try EXT_disjoint_timer_queryImpl.call_createQueryEXT(instance);
    }

    pub fn call_endQueryEXT(instance: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_endQueryEXT(instance, target);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isQueryEXT(instance: *runtime.Instance, query: *runtime.Instance) anyerror!bool {
        
        return try EXT_disjoint_timer_queryImpl.call_isQueryEXT(instance, query);
    }

    pub fn call_beginQueryEXT(instance: *runtime.Instance, target: GLenum, query: *runtime.Instance) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_beginQueryEXT(instance, target, query);
    }

    pub fn call_getQueryObjectEXT(instance: *runtime.Instance, query: *runtime.Instance, pname: GLenum) anyerror!*const anyopaque {
        
        return try EXT_disjoint_timer_queryImpl.call_getQueryObjectEXT(instance, query, pname);
    }

    pub fn call_getQueryEXT(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!*const anyopaque {
        
        return try EXT_disjoint_timer_queryImpl.call_getQueryEXT(instance, target, pname);
    }

    pub fn call_deleteQueryEXT(instance: *runtime.Instance, query: *runtime.Instance) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_deleteQueryEXT(instance, query);
    }

};
