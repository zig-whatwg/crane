//! Generated from: EXT_disjoint_timer_query_webgl2.idl
//! Generated at: 2025-11-18T18:28:11Z
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

    pub const vtable = runtime.buildVTable(EXT_disjoint_timer_query_webgl2, .{
        .deinit_fn = &deinit_wrapper,

        .get_GPU_DISJOINT_EXT = &get_GPU_DISJOINT_EXT,
        .get_QUERY_COUNTER_BITS_EXT = &get_QUERY_COUNTER_BITS_EXT,
        .get_TIMESTAMP_EXT = &get_TIMESTAMP_EXT,
        .get_TIME_ELAPSED_EXT = &get_TIME_ELAPSED_EXT,

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
        EXT_disjoint_timer_query_webgl2Impl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_disjoint_timer_query_webgl2Impl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_queryCounterEXT(instance: *runtime.Instance, query: WebGLQuery, target: GLenum) anyerror!void {
        
        return try EXT_disjoint_timer_query_webgl2Impl.call_queryCounterEXT(instance, query, target);
    }

};
