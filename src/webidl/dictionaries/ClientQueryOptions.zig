//! WebIDL dictionary: ClientQueryOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const ClientQueryOptions = struct {
    includeUncontrolled: ?bool = null,
    @"type": ?enums.ClientType = null,
};
