//! Generated from: EXT_disjoint_timer_query.idl
//! Generated at: 2025-11-18T18:28:12Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(EXT_disjoint_timer_query, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_disjoint_timer_queryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_disjoint_timer_queryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_queryCounterEXT(instance: *runtime.Instance, query: WebGLTimerQueryEXT, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_queryCounterEXT(instance, query, target);
    }

    pub fn call_createQueryEXT(instance: *runtime.Instance) anyerror!WebGLTimerQueryEXT {
        return try EXT_disjoint_timer_queryImpl.call_createQueryEXT(instance);
    }

    pub fn call_endQueryEXT(instance: *runtime.Instance, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_endQueryEXT(instance, target);
    }

    /// Extended attributes: [WebGLHandlesContextLoss]
    pub fn call_isQueryEXT(instance: *runtime.Instance, query: anyopaque) anyerror!bool {
        
        return try EXT_disjoint_timer_queryImpl.call_isQueryEXT(instance, query);
    }

    pub fn call_beginQueryEXT(instance: *runtime.Instance, target: GLenum, query: WebGLTimerQueryEXT) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_beginQueryEXT(instance, target, query);
    }

    pub fn call_getQueryObjectEXT(instance: *runtime.Instance, query: WebGLTimerQueryEXT, pname: GLenum) anyerror!anyopaque {
        
        return try EXT_disjoint_timer_queryImpl.call_getQueryObjectEXT(instance, query, pname);
    }

    pub fn call_getQueryEXT(instance: *runtime.Instance, target: GLenum, pname: GLenum) anyerror!anyopaque {
        
        return try EXT_disjoint_timer_queryImpl.call_getQueryEXT(instance, target, pname);
    }

    pub fn call_deleteQueryEXT(instance: *runtime.Instance, query: anyopaque) anyerror!void {
        
        return try EXT_disjoint_timer_queryImpl.call_deleteQueryEXT(instance, query);
    }

};
