//! WebIDL dictionary: MockCameraConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const MockCaptureDeviceConfiguration = @import("MockCaptureDeviceConfiguration.zig").MockCaptureDeviceConfiguration;

pub const MockCameraConfiguration = struct {
    // Inherited from MockCaptureDeviceConfiguration
    base: MockCaptureDeviceConfiguration,

    defaultFrameRate: ?f64 = null,
    facingMode: ?runtime.DOMString = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"defaultFrameRate"};
};
