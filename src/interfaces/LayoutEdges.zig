//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutEdgesImpl = @import("../impls/LayoutEdges.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        LayoutEdgesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LayoutEdgesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inlineStart(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_inlineStart(state);
    }

    pub fn get_inlineEnd(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_inlineEnd(state);
    }

    pub fn get_blockStart(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_blockStart(state);
    }

    pub fn get_blockEnd(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_blockEnd(state);
    }

    pub fn get_inline(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_inline(state);
    }

    pub fn get_block(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return LayoutEdgesImpl.get_block(state);
    }

};
