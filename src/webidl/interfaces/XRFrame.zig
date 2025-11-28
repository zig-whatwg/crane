//! Generated from: webxr.idl
//! Generated at: 2025-11-28T18:02:25Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRFrameImpl = @import("impls").XRFrame;
const XRTransientInputHitTestSource = @import("interfaces").XRTransientInputHitTestSource;
const XRHitTestSource = @import("interfaces").XRHitTestSource;
const XRReferenceSpace = @import("interfaces").XRReferenceSpace;
const XRView = @import("interfaces").XRView;
const XRMetadata = @import("dictionaries").XRMetadata;
const XRTransientInputHitTestResult = @import("interfaces").XRTransientInputHitTestResult;
const XRSession = @import("interfaces").XRSession;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const XRPose = @import("interfaces").XRPose;
const XRCPUDepthInformation = @import("interfaces").XRCPUDepthInformation;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRJointPose = @import("interfaces").XRJointPose;
const XRBody = @import("interfaces").XRBody;
const XRHitTestResult = @import("interfaces").XRHitTestResult;
const XRAnchorSet = @import("interfaces").XRAnchorSet;
const XRSpace = @import("interfaces").XRSpace;
const XRViewerPose = @import("interfaces").XRViewerPose;
const XRLightProbe = @import("interfaces").XRLightProbe;
const XRAnchor = @import("interfaces").XRAnchor;
const XRMeshSet = @import("interfaces").XRMeshSet;
const XRJointSpace = @import("interfaces").XRJointSpace;
const XRLightEstimate = @import("interfaces").XRLightEstimate;
const XRPlaneSet = @import("interfaces").XRPlaneSet;

pub const XRFrame = struct {
    pub const Meta = struct {
        pub const name = "XRFrame";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "session", "get_session", null },
            .{ "predictedDisplayTime", "get_predictedDisplayTime", null },
            .{ "body", "get_body", null },
            .{ "trackedAnchors", "get_trackedAnchors", null },
            .{ "detectedPlanes", "get_detectedPlanes", null },
            .{ "detectedMeshes", "get_detectedMeshes", null },
            .{ "metaData", "get_metaData", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getViewerPose", "call_getViewerPose", 1 },
            .{ "getPose", "call_getPose", 2 },
            .{ "getHitTestResults", "call_getHitTestResults", 1 },
            .{ "getHitTestResultsForTransientInput", "call_getHitTestResultsForTransientInput", 1 },
            .{ "getDepthInformation", "call_getDepthInformation", 1 },
            .{ "createAnchor", "call_createAnchor", 2 },
            .{ "getLightEstimate", "call_getLightEstimate", 1 },
            .{ "getJointPose", "call_getJointPose", 2 },
            .{ "fillJointRadii", "call_fillJointRadii", 2 },
            .{ "fillPoses", "call_fillPoses", 3 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getViewerPose",
            "getPose",
            "getHitTestResults",
            "getHitTestResultsForTransientInput",
            "getDepthInformation",
            "createAnchor",
            "getLightEstimate",
            "getJointPose",
            "fillJointRadii",
            "fillPoses",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "session", "get_session", null },
            .{ "predictedDisplayTime", "get_predictedDisplayTime", null },
            .{ "body", "get_body", null },
            .{ "trackedAnchors", "get_trackedAnchors", null },
            .{ "detectedPlanes", "get_detectedPlanes", null },
            .{ "detectedMeshes", "get_detectedMeshes", null },
            .{ "metaData", "get_metaData", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            session: *runtime.Instance = undefined,
            predictedDisplayTime: DOMHighResTimeStamp = undefined,
            body: ?*runtime.Instance = null,
            trackedAnchors: *runtime.Instance = undefined,
            detectedPlanes: *runtime.Instance = undefined,
            detectedMeshes: *runtime.Instance = undefined,
            metaData: XRMetadata = undefined,
            cached_session: ?*runtime.Instance = null,
            cached_body: ?*runtime.Instance = null,
            cached_trackedAnchors: ?*runtime.Instance = null,
            _internal: ?*XRFrameImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRFrameImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRFrameImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_session(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_session) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_session(instance);
        state.own.cached_session = value;
        return value;
    }

    pub fn get_predictedDisplayTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try XRFrameImpl.get_predictedDisplayTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_body) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_body(instance);
        state.own.cached_body = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_trackedAnchors(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_trackedAnchors) |cached| {
            return cached;
        }
        const value = try XRFrameImpl.get_trackedAnchors(instance);
        state.own.cached_trackedAnchors = value;
        return value;
    }

    pub fn get_detectedPlanes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRFrameImpl.get_detectedPlanes(instance);
    }

    pub fn get_detectedMeshes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try XRFrameImpl.get_detectedMeshes(instance);
    }

    pub fn get_metaData(instance: *runtime.Instance) anyerror!XRMetadata {
        return try XRFrameImpl.get_metaData(instance);
    }

    pub fn call_createAnchor(instance: *runtime.Instance, pose: *runtime.Instance, space: *runtime.Instance) anyerror!*const anyopaque {
        
        return try XRFrameImpl.call_createAnchor(instance, pose, space);
    }

    pub fn call_getViewerPose(instance: *runtime.Instance, referenceSpace: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRFrameImpl.call_getViewerPose(instance, referenceSpace);
    }

    pub fn call_getHitTestResults(instance: *runtime.Instance, hitTestSource: *runtime.Instance) anyerror!*const anyopaque {
        
        return try XRFrameImpl.call_getHitTestResults(instance, hitTestSource);
    }

    pub fn call_getLightEstimate(instance: *runtime.Instance, lightProbe: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRFrameImpl.call_getLightEstimate(instance, lightProbe);
    }

    pub fn call_getPose(instance: *runtime.Instance, space: *runtime.Instance, baseSpace: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRFrameImpl.call_getPose(instance, space, baseSpace);
    }

    pub fn call_getHitTestResultsForTransientInput(instance: *runtime.Instance, hitTestSource: *runtime.Instance) anyerror!*const anyopaque {
        
        return try XRFrameImpl.call_getHitTestResultsForTransientInput(instance, hitTestSource);
    }

    pub fn call_fillPoses(instance: *runtime.Instance, spaces: *const anyopaque, baseSpace: *runtime.Instance, transforms: *const anyopaque) anyerror!bool {
        
        return try XRFrameImpl.call_fillPoses(instance, spaces, baseSpace, transforms);
    }

    pub fn call_getJointPose(instance: *runtime.Instance, joint: *runtime.Instance, baseSpace: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRFrameImpl.call_getJointPose(instance, joint, baseSpace);
    }

    pub fn call_fillJointRadii(instance: *runtime.Instance, jointSpaces: *const anyopaque, radii: *const anyopaque) anyerror!bool {
        
        return try XRFrameImpl.call_fillJointRadii(instance, jointSpaces, radii);
    }

    pub fn call_getDepthInformation(instance: *runtime.Instance, view: *runtime.Instance) anyerror!?*runtime.Instance {
        
        return try XRFrameImpl.call_getDepthInformation(instance, view);
    }

};
