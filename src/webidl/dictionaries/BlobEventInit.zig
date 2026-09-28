//! WebIDL dictionary: BlobEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const EventInit = @import("EventInit.zig").EventInit;

pub const BlobEventInit = struct {
    // Inherited from EventInit
    base: EventInit,

    data: *runtime.Instance,
    timecode: ?typedefs.DOMHighResTimeStamp = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{"timecode"};
};
