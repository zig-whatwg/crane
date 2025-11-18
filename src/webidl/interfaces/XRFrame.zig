//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRFrameImpl = @import("impls").XRFrame;
const XRTransientInputHitTestSource = @import("interfaces").XRTransientInputHitTestSource;
const Float32Array = @import("interfaces").Float32Array;
const XRHitTestSource = @import("interfaces").XRHitTestSource;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const XRView = @import("interfaces").XRView;
const XRMetadata = @import("dictionaries").XRMetadata;
const XRJointPose = @import("interfaces").XRJointPose;
const XRSession = @import("interfaces").XRSession;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const XRPose = @import("interfaces").XRPose;
const XRCPUDepthInformation = @import("interfaces").XRCPUDepthInformation;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const Promise<XRAnchor> = @import("interfaces").Promise<XRAnchor>;
const XRBody = @import("interfaces").XRBody;
const XRAnchorSet = @import("interfaces").XRAnchorSet;
const XRMeshSet = @import("interfaces").XRMeshSet;
const XRSpace = @import("interfaces").XRSpace;
const XRViewerPose = @import("interfaces").XRViewerPose;
const XRLightProbe = @import("interfaces").XRLightProbe;
const XRJointSpace = @import("interfaces").XRJointSpace;
const XRLightEstimate = @import("interfaces").XRLightEstimate;
const XRPlaneSet = @import("interfaces").XRPlaneSet;

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
        
        // Initialize the instance (Impl receives full instance)
        XRFrameImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRFrameImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!XRSession {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_session) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_session(instance);
        state.cached_session = value;
        return value;
    }

    pub fn get_predictedDisplayTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRFrameImpl.get_predictedDisplayTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_body(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_body) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_body(instance);
        state.cached_body = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedAnchors(instance: *runtime.Instance) anyerror!XRAnchorSet {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_trackedAnchors) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_trackedAnchors(instance);
        state.cached_trackedAnchors = value;
        return value;
    }

    pub fn get_detectedPlanes(instance: *runtime.Instance) anyerror!XRPlaneSet {
        return try XRFrameImpl.get_detectedPlanes(instance);
    }

    pub fn get_detectedMeshes(instance: *runtime.Instance) anyerror!XRMeshSet {
        return try XRFrameImpl.get_detectedMeshes(instance);
    }

    pub fn get_metaData(instance: *runtime.Instance) anyerror!XRMetadata {
        return try XRFrameImpl.get_metaData(instance);
    }

    pub fn call_createAnchor(instance: *runtime.Instance, pose: XRRigidTransform, space: XRSpace) anyerror!anyopaque {
        
        return try XRFrameImpl.call_createAnchor(instance, pose, space);
    }

    pub fn call_getViewerPose(instance: *runtime.Instance, referenceSpace: XRReferenceSpace) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getViewerPose(instance, referenceSpace);
    }

    pub fn call_getHitTestResults(instance: *runtime.Instance, hitTestSource: XRHitTestSource) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getHitTestResults(instance, hitTestSource);
    }

    pub fn call_getLightEstimate(instance: *runtime.Instance, lightProbe: XRLightProbe) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getLightEstimate(instance, lightProbe);
    }

    pub fn call_getPose(instance: *runtime.Instance, space: XRSpace, baseSpace: XRSpace) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getPose(instance, space, baseSpace);
    }

    pub fn call_getHitTestResultsForTransientInput(instance: *runtime.Instance, hitTestSource: XRTransientInputHitTestSource) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getHitTestResultsForTransientInput(instance, hitTestSource);
    }

    pub fn call_fillPoses(instance: *runtime.Instance, spaces: anyopaque, baseSpace: XRSpace, transforms: anyopaque) anyerror!bool {
        
        return try XRFrameImpl.call_fillPoses(instance, spaces, baseSpace, transforms);
    }

    pub fn call_getJointPose(instance: *runtime.Instance, joint: XRJointSpace, baseSpace: XRSpace) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getJointPose(instance, joint, baseSpace);
    }

    pub fn call_fillJointRadii(instance: *runtime.Instance, jointSpaces: anyopaque, radii: anyopaque) anyerror!bool {
        
        return try XRFrameImpl.call_fillJointRadii(instance, jointSpaces, radii);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: XRView) anyerror!anyopaque {
        
        return try XRFrameImpl.call_getDepthInformation(instance, view);
    }

};
