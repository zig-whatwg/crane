//! WebIDL dictionary: DetectedFace
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const Landmark = @import("Landmark.zig").Landmark;

pub const DetectedFace = struct {
    boundingBox: *runtime.Instance,
    landmarks: []const Landmark,
};
