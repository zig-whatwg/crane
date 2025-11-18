//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutFragmentImpl = @import("impls").LayoutFragment;
const ChildBreakToken = @import("interfaces").ChildBreakToken;

pub const LayoutFragment = struct {
    pub const Meta = struct {
        pub const name = "LayoutFragment";
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
            inlineSize: f64 = undefined,
            blockSize: f64 = undefined,
            inlineOffset: f64 = undefined,
            blockOffset: f64 = undefined,
            data: anyopaque = undefined,
            breakToken: ?ChildBreakToken = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutFragment, .{
        .deinit_fn = &deinit_wrapper,

        .get_blockOffset = &get_blockOffset,
        .get_blockSize = &get_blockSize,
        .get_breakToken = &get_breakToken,
        .get_data = &get_data,
        .get_inlineOffset = &get_inlineOffset,
        .get_inlineSize = &get_inlineSize,

        .set_blockOffset = &set_blockOffset,
        .set_inlineOffset = &set_inlineOffset,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LayoutFragmentImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutFragmentImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineSize(instance);
    }

    pub fn get_blockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockSize(instance);
    }

    pub fn get_inlineOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_inlineOffset(instance);
    }

    pub fn set_inlineOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_inlineOffset(instance, value);
    }

    pub fn get_blockOffset(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutFragmentImpl.get_blockOffset(instance);
    }

    pub fn set_blockOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try LayoutFragmentImpl.set_blockOffset(instance, value);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutFragmentImpl.get_data(instance);
    }

    pub fn get_breakToken(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutFragmentImpl.get_breakToken(instance);
    }

};
