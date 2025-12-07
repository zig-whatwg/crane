//! WebIDL dictionary: NDEFRecordInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const NDEFRecordInit = struct {
    recordType: runtime.USVString,
    mediaType: ?runtime.USVString = null,
    id: ?runtime.USVString = null,
    encoding: ?runtime.USVString = null,
    lang: ?runtime.USVString = null,
    data: ?v8.JSValue = null,
};
