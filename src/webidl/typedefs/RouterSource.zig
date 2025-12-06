//! WebIDL typedef: RouterSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const RouterSource = union(enum) {
    router_source_dict: dictionaries.RouterSourceDict,
    router_source_enum: enums.RouterSourceEnum,
};
