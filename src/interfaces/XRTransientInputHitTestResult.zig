//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRTransientInputHitTestResultImpl = @import("../impls/XRTransientInputHitTestResult.zig");

pub const XRTransientInputHitTestResult = struct {
    pub const Meta = struct {
        pub const name = "XRTransientInputHitTestResult";
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
        struct {
            inputSource: XRInputSource = undefined,
            results: FrozenArray<XRHitTestResult> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRTransientInputHitTestResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_inputSource = &get_inputSource,
        .get_results = &get_results,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRTransientInputHitTestResultImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRTransientInputHitTestResultImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSource(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inputSource) |cached| {
            return cached;
        }
        const value = XRTransientInputHitTestResultImpl.get_inputSource(state);
        state.cached_inputSource = value;
        return value;
    }

    pub fn get_results(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRTransientInputHitTestResultImpl.get_results(state);
    }

};
