//! WebIDL dictionary: NDEFRecordInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NDEFRecordInit = struct {
    recordType: runtime.USVString,
    mediaType: ?runtime.USVString = null,
    id: ?runtime.USVString = null,
    encoding: ?runtime.USVString = null,
    lang: ?runtime.USVString = null,
    data: ?runtime.JSValue = null,
};
