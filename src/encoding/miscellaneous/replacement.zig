//! replacement Encoding
//!
//! WHATWG Encoding Standard - §14.1 replacement
//! https://encoding.spec.whatwg.org/#replacement
//!
//! The replacement encoding exists to prevent certain attacks that abuse
//! a mismatch between encodings supported on the server and the client.
//!
//! It has NO encoder (decode-only).
//!
//! Decoder behavior:
//! - First byte (or end-of-queue): Returns error once, then finished
//! - All subsequent bytes: Returns finished
//!
//! This causes the entire input to be replaced with a single U+FFFD (�).

const std = @import("std");

pub const Decoder = struct {
    replacement_error_returned: bool = false,

    pub fn decode(self: *Decoder, byte: ?u8) !?u21 {
        // 1. If byte is end-of-queue, then return finished.
        if (byte == null) {
            return null;
        }

        // 2. If replacement error returned is false, then set
        //    replacement error returned to true and return error.
        if (!self.replacement_error_returned) {
            self.replacement_error_returned = true;
            return error.InvalidSequence;
        }

        // 3. Return finished.
        return null;
    }
};
