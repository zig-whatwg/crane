//! WebIDL dictionary: TableDescriptor
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const TableDescriptor = struct {
    element: enums.TableKind,
    initial: typedefs.AddressValue,
    maximum: ?typedefs.AddressValue = null,
    address: ?enums.AddressType = null,
};
