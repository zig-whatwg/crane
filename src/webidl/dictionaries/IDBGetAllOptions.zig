//! WebIDL dictionary: IDBGetAllOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const IDBGetAllOptions = struct {
    query: ?v8.JSValue = null,
    count: ?u32 = null,
    direction: ?enums.IDBCursorDirection = null,
};
