//! WebIDL typedef: RouterSource
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const dictionaries = @import("dictionaries");
const enums = @import("enums");

pub const RouterSource = union(enum) {
    router_source_dict: dictionaries.RouterSourceDict,
    router_source_enum: enums.RouterSourceEnum,
};
