//! WebIDL enum: RTCStatsType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCStatsType = enum {
    _codec_,
    _inbound_rtp_,
    _outbound_rtp_,
    _remote_inbound_rtp_,
    _remote_outbound_rtp_,
    _media_source_,
    _media_playout_,
    _peer_connection_,
    _data_channel_,
    _transport_,
    _candidate_pair_,
    _local_candidate_,
    _remote_candidate_,
    _certificate_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "codec", "inbound-rtp", "outbound-rtp", "remote-inbound-rtp", "remote-outbound-rtp", "media-source", "media-playout", "peer-connection", "data-channel", "transport", "candidate-pair", "local-candidate", "remote-candidate", "certificate" };
};
