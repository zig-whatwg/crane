//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LayoutConstraintsImpl = @import("impls").LayoutConstraints;
const BlockFragmentationType = @import("enums").BlockFragmentationType;
const double = @import("interfaces").double;

pub const LayoutConstraints = struct {
    pub const Meta = struct {
        pub const name = "LayoutConstraints";
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
            availableInlineSize: f64 = undefined,
            availableBlockSize: f64 = undefined,
            fixedInlineSize: ?f64 = null,
            fixedBlockSize: ?f64 = null,
            percentageInlineSize: f64 = undefined,
            percentageBlockSize: f64 = undefined,
            blockFragmentationOffset: ?f64 = null,
            blockFragmentationType: BlockFragmentationType = undefined,
            data: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LayoutConstraints, .{
        .deinit_fn = &deinit_wrapper,

        .get_availableBlockSize = &get_availableBlockSize,
        .get_availableInlineSize = &get_availableInlineSize,
        .get_blockFragmentationOffset = &get_blockFragmentationOffset,
        .get_blockFragmentationType = &get_blockFragmentationType,
        .get_data = &get_data,
        .get_fixedBlockSize = &get_fixedBlockSize,
        .get_fixedInlineSize = &get_fixedInlineSize,
        .get_percentageBlockSize = &get_percentageBlockSize,
        .get_percentageInlineSize = &get_percentageInlineSize,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        LayoutConstraintsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LayoutConstraintsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_availableInlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_availableInlineSize(instance);
    }

    pub fn get_availableBlockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_availableBlockSize(instance);
    }

    pub fn get_fixedInlineSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutConstraintsImpl.get_fixedInlineSize(instance);
    }

    pub fn get_fixedBlockSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutConstraintsImpl.get_fixedBlockSize(instance);
    }

    pub fn get_percentageInlineSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_percentageInlineSize(instance);
    }

    pub fn get_percentageBlockSize(instance: *runtime.Instance) anyerror!f64 {
        return try LayoutConstraintsImpl.get_percentageBlockSize(instance);
    }

    pub fn get_blockFragmentationOffset(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutConstraintsImpl.get_blockFragmentationOffset(instance);
    }

    pub fn get_blockFragmentationType(instance: *runtime.Instance) anyerror!BlockFragmentationType {
        return try LayoutConstraintsImpl.get_blockFragmentationType(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!anyopaque {
        return try LayoutConstraintsImpl.get_data(instance);
    }

};
