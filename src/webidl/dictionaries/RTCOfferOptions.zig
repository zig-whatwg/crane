//! WebIDL dictionary: RTCOfferOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const RTCOfferAnswerOptions = @import("RTCOfferAnswerOptions.zig").RTCOfferAnswerOptions;

pub const RTCOfferOptions = struct {
    // Inherited from RTCOfferAnswerOptions
    base: RTCOfferAnswerOptions,

    iceRestart: ?bool = null,
    offerToReceiveAudio: ?bool = null,
    offerToReceiveVideo: ?bool = null,

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "iceRestart", .{ .boolean = false } },
    };
};
