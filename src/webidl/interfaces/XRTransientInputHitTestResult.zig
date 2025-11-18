//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRTransientInputHitTestResultImpl = @import("impls").XRTransientInputHitTestResult;
const XRInputSource = @import("interfaces").XRInputSource;
const FrozenArray<XRHitTestResult> = @import("interfaces").FrozenArray<XRHitTestResult>;

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
        
        // Initialize the instance (Impl receives full instance)
        XRTransientInputHitTestResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRTransientInputHitTestResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inputSource(instance: *runtime.Instance) anyerror!XRInputSource {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_inputSource) |cached| {
            return cached;
        }
        const value = try XRTransientInputHitTestResultImpl.get_inputSource(instance);
        state.cached_inputSource = value;
        return value;
    }

    pub fn get_results(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRTransientInputHitTestResultImpl.get_results(instance);
    }

};
