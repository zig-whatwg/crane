//! WebIDL dictionary: RewriterRewriteOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const RewriterRewriteOptions = struct {
    context: ?runtime.DOMString = null,
    signal: ?*runtime.Instance = null,
};
