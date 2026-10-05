//! WebIDL enum: RouterSourceEnum
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RouterSourceEnum = enum {
    _cache_,
    _fetch_event_,
    _network_,
    _race_network_and_fetch_handler_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "cache", "fetch-event", "network", "race-network-and-fetch-handler" };
};
