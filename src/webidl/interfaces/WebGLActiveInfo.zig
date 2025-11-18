//! Generated from: webgl1.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLActiveInfoImpl = @import("impls").WebGLActiveInfo;
const GLint = @import("typedefs").GLint;
const GLenum = @import("typedefs").GLenum;

pub const WebGLActiveInfo = struct {
    pub const Meta = struct {
        pub const name = "WebGLActiveInfo";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: GLint = undefined,
            type: GLenum = undefined,
            name: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebGLActiveInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_name = &get_name,
        .get_size = &get_size,
        .get_type = &get_type,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebGLActiveInfoImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLActiveInfoImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!GLint {
        return try WebGLActiveInfoImpl.get_size(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GLenum {
        return try WebGLActiveInfoImpl.get_type(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try WebGLActiveInfoImpl.get_name(instance);
    }

};
