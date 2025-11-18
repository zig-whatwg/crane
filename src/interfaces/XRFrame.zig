//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRFrameImpl = @import("../impls/XRFrame.zig");

pub const XRFrame = struct {
    pub const Meta = struct {
        pub const name = "XRFrame";
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
            session: XRSession = undefined,
            predictedDisplayTime: DOMHighResTimeStamp = undefined,
            body: ?XRBody = null,
            trackedAnchors: XRAnchorSet = undefined,
            detectedPlanes: XRPlaneSet = undefined,
            detectedMeshes: XRMeshSet = undefined,
            metaData: XRMetadata = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRFrame, .{
        .deinit_fn = &deinit_wrapper,

        .get_body = &get_body,
        .get_detectedMeshes = &get_detectedMeshes,
        .get_detectedPlanes = &get_detectedPlanes,
        .get_metaData = &get_metaData,
        .get_predictedDisplayTime = &get_predictedDisplayTime,
        .get_session = &get_session,
        .get_trackedAnchors = &get_trackedAnchors,

        .call_createAnchor = &call_createAnchor,
        .call_fillJointRadii = &call_fillJointRadii,
        .call_fillPoses = &call_fillPoses,
        .call_getDepthInformation = &call_getDepthInformation,
        .call_getHitTestResults = &call_getHitTestResults,
        .call_getHitTestResultsForTransientInput = &call_getHitTestResultsForTransientInput,
        .call_getJointPose = &call_getJointPose,
        .call_getLightEstimate = &call_getLightEstimate,
        .call_getPose = &call_getPose,
        .call_getViewerPose = &call_getViewerPose,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRFrameImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRFrameImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_session) |cached| {
            return cached;
        }
        const value = XRFrameImpl.get_session(state);
        state.cached_session = value;
        return value;
    }

    pub fn get_predictedDisplayTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRFrameImpl.get_predictedDisplayTime(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_body(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_body) |cached| {
            return cached;
        }
        const value = XRFrameImpl.get_body(state);
        state.cached_body = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedAnchors(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_trackedAnchors) |cached| {
            return cached;
        }
        const value = XRFrameImpl.get_trackedAnchors(state);
        state.cached_trackedAnchors = value;
        return value;
    }

    pub fn get_detectedPlanes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRFrameImpl.get_detectedPlanes(state);
    }

    pub fn get_detectedMeshes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRFrameImpl.get_detectedMeshes(state);
    }

    pub fn get_metaData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRFrameImpl.get_metaData(state);
    }

    pub fn call_createAnchor(instance: *runtime.Instance, pose: anyopaque, space: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_createAnchor(state, pose, space);
    }

    pub fn call_getViewerPose(instance: *runtime.Instance, referenceSpace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getViewerPose(state, referenceSpace);
    }

    pub fn call_getHitTestResults(instance: *runtime.Instance, hitTestSource: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getHitTestResults(state, hitTestSource);
    }

    pub fn call_getLightEstimate(instance: *runtime.Instance, lightProbe: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getLightEstimate(state, lightProbe);
    }

    pub fn call_getPose(instance: *runtime.Instance, space: anyopaque, baseSpace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getPose(state, space, baseSpace);
    }

    pub fn call_getHitTestResultsForTransientInput(instance: *runtime.Instance, hitTestSource: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getHitTestResultsForTransientInput(state, hitTestSource);
    }

    pub fn call_fillPoses(instance: *runtime.Instance, spaces: anyopaque, baseSpace: anyopaque, transforms: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_fillPoses(state, spaces, baseSpace, transforms);
    }

    pub fn call_getJointPose(instance: *runtime.Instance, joint: anyopaque, baseSpace: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getJointPose(state, joint, baseSpace);
    }

    pub fn call_fillJointRadii(instance: *runtime.Instance, jointSpaces: anyopaque, radii: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_fillJointRadii(state, jointSpaces, radii);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRFrameImpl.call_getDepthInformation(state, view);
    }

};
