//! WebIDL dictionary: WebTransportDatagramStats
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const WebTransportDatagramStats = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    droppedIncoming: ?u64 = null,
    expiredIncoming: ?u64 = null,
    expiredOutgoing: ?u64 = null,
    lostOutgoing: ?u64 = null,
};
