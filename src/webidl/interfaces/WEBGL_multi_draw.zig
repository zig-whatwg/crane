//! Generated from: WEBGL_multi_draw.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_drawImpl = @import("impls").WEBGL_multi_draw;
const GLenum = @import("typedefs").GLenum;
const (Int32Array or sequence) = @import("interfaces").(Int32Array or sequence);
const GLsizei = @import("typedefs").GLsizei;

pub const WEBGL_multi_draw = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw";
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

    pub const vtable = runtime.buildVTable(WEBGL_multi_draw, .{
        .deinit_fn = &deinit_wrapper,

        .call_multiDrawArraysInstancedWEBGL = &call_multiDrawArraysInstancedWEBGL,
        .call_multiDrawArraysWEBGL = &call_multiDrawArraysWEBGL,
        .call_multiDrawElementsInstancedWEBGL = &call_multiDrawElementsInstancedWEBGL,
        .call_multiDrawElementsWEBGL = &call_multiDrawElementsWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_multi_drawImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_multi_drawImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_multiDrawArraysWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawArraysWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, drawcount);
    }

    pub fn call_multiDrawElementsWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: anyopaque, countsOffset: u64, type_: GLenum, offsetsList: anyopaque, offsetsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawElementsWEBGL(instance, mode, countsList, countsOffset, type_, offsetsList, offsetsOffset, drawcount);
    }

    pub fn call_multiDrawArraysInstancedWEBGL(instance: *runtime.Instance, mode: GLenum, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawArraysInstancedWEBGL(instance, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedWEBGL(instance: *runtime.Instance, mode: GLenum, countsList: anyopaque, countsOffset: u64, type_: GLenum, offsetsList: anyopaque, offsetsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: GLsizei) anyerror!void {
        
        return try WEBGL_multi_drawImpl.call_multiDrawElementsInstancedWEBGL(instance, mode, countsList, countsOffset, type_, offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

};
