//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutEdgesImpl = @import("impls").LayoutEdges;

pub const LayoutEdges = struct {
    pub const Meta = struct {
        pub const name = "LayoutEdges";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "LayoutWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .LayoutWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            inlineStart: f64 = undefined,
            inlineEnd: f64 = undefined,
            blockStart: f64 = undefined,
            blockEnd: f64 = undefined,
            inline: f64 = undefined,
            block: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutEdges, .{
        .deinit_fn = &deinit_wrapper,

        .get_block = &get_block,
        .get_blockEnd = &get_blockEnd,
        .get_blockStart = &get_blockStart,
        .get_inline = &get_inline,
        .get_inlineEnd = &get_inlineEnd,
        .get_inlineStart = &get_inlineStart,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LayoutEdgesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutEdgesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inlineStart(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inlineStart(instance);
    }

    pub fn get_inlineEnd(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inlineEnd(instance);
    }

    pub fn get_blockStart(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_blockStart(instance);
    }

    pub fn get_blockEnd(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_blockEnd(instance);
    }

    pub fn get_inline(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_inline(instance);
    }

    pub fn get_block(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutEdgesImpl.get_block(instance);
    }

};
