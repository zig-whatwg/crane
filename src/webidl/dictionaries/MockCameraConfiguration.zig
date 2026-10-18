//! WebIDL dictionary: MockCameraConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MockCaptureDeviceConfiguration = @import("MockCaptureDeviceConfiguration.zig").MockCaptureDeviceConfiguration;

pub const MockCameraConfiguration = struct {
    // Inherited from MockCaptureDeviceConfiguration
    base: MockCaptureDeviceConfiguration,

    defaultFrameRate: ?f64 = null,
    facingMode: ?runtime.DOMString = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"defaultFrameRate"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "defaultFrameRate", .{ .number = 30 } },
        .{ "facingMode", .{ .string = "user" } },
    };
};
