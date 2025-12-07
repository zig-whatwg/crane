//! WebIDL dictionary: BrowsingTopic
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const BrowsingTopic = struct {
    topic: ?u64 = null,
    version: ?runtime.DOMString = null,
    configVersion: ?runtime.DOMString = null,
    modelVersion: ?runtime.DOMString = null,
    taxonomyVersion: ?runtime.DOMString = null,
};
