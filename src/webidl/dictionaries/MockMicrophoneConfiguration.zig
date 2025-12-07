//! WebIDL dictionary: MockMicrophoneConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MockCaptureDeviceConfiguration = @import("MockCaptureDeviceConfiguration.zig").MockCaptureDeviceConfiguration;

pub const MockMicrophoneConfiguration = struct {
    // Inherited from MockCaptureDeviceConfiguration
    base: MockCaptureDeviceConfiguration,

    defaultSampleRate: ?u32 = null,
};
