//! WebIDL enum: ClientType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ClientType = enum {
    _window_,
    _worker_,
    _sharedworker_,
    _all_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "window", "worker", "sharedworker", "all" };
};
