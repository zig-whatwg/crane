//! Generated from: ink-enhancement.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DelegatedInkTrailPresenterImpl = @import("../impls/DelegatedInkTrailPresenter.zig");

pub const DelegatedInkTrailPresenter = struct {
    pub const Meta = struct {
        pub const name = "DelegatedInkTrailPresenter";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            presentationArea: ?Element = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DelegatedInkTrailPresenter, .{
        .deinit_fn = &deinit_wrapper,

        .get_presentationArea = &get_presentationArea,

        .call_updateInkTrailStartPoint = &call_updateInkTrailStartPoint,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        DelegatedInkTrailPresenterImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DelegatedInkTrailPresenterImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_presentationArea(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DelegatedInkTrailPresenterImpl.get_presentationArea(state);
    }

    pub fn call_updateInkTrailStartPoint(instance: *runtime.Instance, event: anyopaque, style: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DelegatedInkTrailPresenterImpl.call_updateInkTrailStartPoint(state, event, style);
    }

};
