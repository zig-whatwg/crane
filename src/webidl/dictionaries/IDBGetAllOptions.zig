//! WebIDL dictionary: IDBGetAllOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const IDBGetAllOptions = struct {
    query: ?runtime.JSValue = null,
    count: ?u32 = null,
    direction: ?enums.IDBCursorDirection = null,

    /// `any` members: one present with the value null converts to `.null`,
    /// not to "not present".
    pub const any_members = .{"query"};

    /// [EnforceRange] members: converted with that branch of ConvertToInt.
    pub const enforce_range_members = .{"count"};
};
