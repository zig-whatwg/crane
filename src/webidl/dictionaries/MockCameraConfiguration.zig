//! WebIDL dictionary: MockCameraConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const MockCaptureDeviceConfiguration = @import("MockCaptureDeviceConfiguration.zig").MockCaptureDeviceConfiguration;

pub const MockCameraConfiguration = struct {
    // Inherited from MockCaptureDeviceConfiguration
    base: MockCaptureDeviceConfiguration,

    defaultFrameRate: ?f64 = null,
    facingMode: ?runtime.DOMString = null,
};
