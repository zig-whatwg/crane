//! WebIDL dictionary: RTCOfferOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const RTCOfferAnswerOptions = @import("RTCOfferAnswerOptions.zig").RTCOfferAnswerOptions;

pub const RTCOfferOptions = struct {
    // Inherited from RTCOfferAnswerOptions
    base: RTCOfferAnswerOptions,

    iceRestart: ?bool = null,
    offerToReceiveAudio: ?bool = null,
    offerToReceiveVideo: ?bool = null,
};
