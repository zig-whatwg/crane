//! WebIDL dictionary: DetectedFace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const Landmark = @import("Landmark.zig").Landmark;

pub const DetectedFace = struct {
    boundingBox: *runtime.Instance,
    landmarks: []const Landmark,
};
