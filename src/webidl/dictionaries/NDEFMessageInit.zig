//! WebIDL dictionary: NDEFMessageInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const NDEFRecordInit = @import("NDEFRecordInit.zig").NDEFRecordInit;

pub const NDEFMessageInit = struct {
    records: []const NDEFRecordInit,
};
