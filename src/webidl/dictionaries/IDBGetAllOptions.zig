//! WebIDL dictionary: IDBGetAllOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const IDBGetAllOptions = struct {
    query: ?runtime.JSValue = null,
    count: ?u32 = null,
    direction: ?enums.IDBCursorDirection = null,
};
