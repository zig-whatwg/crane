//! WebIDL dictionary: GPUCanvasConfiguration
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const GPUCanvasConfiguration = struct {
    device: *const anyopaque,
    format: *const anyopaque,
    usage: ?*const anyopaque = null,
    viewFormats: ?*const anyopaque = null,
    colorSpace: ?*const anyopaque = null,
    toneMapping: ?*const anyopaque = null,
    alphaMode: ?*const anyopaque = null,
};
