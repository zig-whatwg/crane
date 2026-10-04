//! WebIDL enum: ServiceWorkerState
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ServiceWorkerState = enum {
    _parsed_,
    _installing_,
    _installed_,
    _activating_,
    _activated_,
    _redundant_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "parsed", "installing", "installed", "activating", "activated", "redundant" };
};
