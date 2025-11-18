//! Generated from: css-layout-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IntrinsicSizesImpl = @import("../impls/IntrinsicSizes.zig");

pub const IntrinsicSizes = struct {
    pub const Meta = struct {
        pub const name = "IntrinsicSizes";
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
            minContentSize: f64 = undefined,
            maxContentSize: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IntrinsicSizes, .{
        .deinit_fn = &deinit_wrapper,

        .get_maxContentSize = &get_maxContentSize,
        .get_minContentSize = &get_minContentSize,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IntrinsicSizesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IntrinsicSizesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_minContentSize(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return IntrinsicSizesImpl.get_minContentSize(state);
    }

    pub fn get_maxContentSize(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return IntrinsicSizesImpl.get_maxContentSize(state);
    }

};
