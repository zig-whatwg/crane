//! WebIDL dictionary: LoadDocumentOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const LoadDocumentOptions = struct {
    extractAllScripts: ?bool = null,
    profile: ?runtime.USVString = null,
    requestProfile: ?*const anyopaque = null,
};
