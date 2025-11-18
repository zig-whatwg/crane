//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRHitTestResultImpl = @import("../impls/XRHitTestResult.zig");

pub const XRHitTestResult = struct {
    pub const Meta = struct {
        pub const name = "XRHitTestResult";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRHitTestResult, .{
        .deinit_fn = &deinit_wrapper,

        .call_createAnchor = &call_createAnchor,
        .call_getPose = &call_getPose,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRHitTestResultImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRHitTestResultImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_createAnchor(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRHitTestResultImpl.call_createAnchor(state);
    }

    pub fn call_getPose(instance: *runtime.Instance, baseSpace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRHitTestResultImpl.call_getPose(state, baseSpace);
    }

};
