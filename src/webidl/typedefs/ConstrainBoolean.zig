//! WebIDL typedef: ConstrainBoolean
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const dictionaries = @import("dictionaries");

pub const ConstrainBoolean = union(enum) {
    boolean: bool,
    constrain_boolean_parameters: dictionaries.ConstrainBooleanParameters,
};
