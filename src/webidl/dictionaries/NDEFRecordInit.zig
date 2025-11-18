//! WebIDL dictionary: NDEFRecordInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const NDEFRecordInit = struct {
    recordType: runtime.DOMString,
    mediaType: ?runtime.DOMString = null,
    id: ?runtime.DOMString = null,
    encoding: ?runtime.DOMString = null,
    lang: ?runtime.DOMString = null,
    data: ?anyopaque = null,
};
