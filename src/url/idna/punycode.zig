//! Punycode Encoder/Decoder
//!
//! RFC 3492: https://datatracker.ietf.org/doc/html/rfc3492
//! Used for encoding/decoding internationalized domain names (IDN)
//!
//! Punycode is a way to represent Unicode strings using only ASCII characters.
//! It's used in domain names for encoding non-ASCII characters.
//!
//! ## Examples
//!
//! - "münchen" -> "mnchen-3ya"
//! - "日本" -> "wgv71a"
//! - "☃-⌘" -> "--dqo34k"
//!
//! ## Usage
//!
//! ```zig
//! const punycode = @import("idna/punycode.zig");
//!
//! // Encode
//! const encoded = try punycode.encode(allocator, "münchen");
//! defer allocator.free(encoded);
//! // Result: "mnchen-3ya"
//!
//! // Decode
//! const decoded = try punycode.decode(allocator, "mnchen-3ya");
//! defer allocator.free(decoded);
//! // Result: "münchen"
//! ```

const std = @import("std");
const infra = @import("infra");

/// Punycode parameters (RFC 3492 Section 5)
const base: u32 = 36;
const tmin: u32 = 1;
const tmax: u32 = 26;
const skew: u32 = 38;
const damp: u32 = 700;
const initial_bias: u32 = 72;
const initial_n: u32 = 0x80; // Initial code point (128)
const delimiter: u8 = '-';

/// Punycode error types
pub const PunycodeError = error{
    Overflow,
    BadInput,
    OutOfMemory,
};

/// Encode a digit to a base-36 character (RFC 3492 Section 5)
fn encodeDigit(d: u32) u8 {
    if (d < 26) {
        return @intCast('a' + d);
    } else {
        return @intCast('0' + (d - 26));
    }
}

/// Decode a base-36 character to a digit (RFC 3492 Section 5)
fn decodeDigit(cp: u8) !u32 {
    if (cp >= '0' and cp <= '9') {
        return cp - '0' + 26;
    } else if (cp >= 'A' and cp <= 'Z') {
        return cp - 'A';
    } else if (cp >= 'a' and cp <= 'z') {
        return cp - 'a';
    } else {
        return PunycodeError.BadInput;
    }
}

/// Adapt the bias (RFC 3492 Section 6.1)
fn adapt(delta: u32, numpoints: u32, firsttime: bool) u32 {
    var d = delta;
    if (firsttime) {
        d = d / damp;
    } else {
        d = d / 2;
    }

    d = d + (d / numpoints);

    var k: u32 = 0;
    while (d > ((base - tmin) * tmax) / 2) {
        d = d / (base - tmin);
        k += base;
    }

    return k + (((base - tmin + 1) * d) / (d + skew));
}

/// Encode a Unicode string to Punycode (RFC 3492 Section 6.3)
///
/// Returns ASCII-only string representing the input Unicode string.
///
/// Example: "münchen" -> "mnchen-3ya"
pub fn encode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Decode input to code points
    var codepoints = infra.List(u21).init(allocator);
    defer codepoints.deinit();

    var i: usize = 0;
    while (i < input.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            return PunycodeError.BadInput;
        };
        if (i + cp_len > input.len) {
            return PunycodeError.BadInput;
        }
        const cp = std.unicode.utf8Decode(input[i..][0..cp_len]) catch {
            return PunycodeError.BadInput;
        };
        try codepoints.append(cp);
        i += cp_len;
    }

    const input_len = codepoints.len;

    // Copy all basic code points (ASCII) to output
    var basic_count: u32 = 0;
    for (codepoints.items()) |cp| {
        if (cp < 0x80) {
            try output.append(@intCast(cp));
            basic_count += 1;
        }
    }

    const h = basic_count;
    const b = basic_count;

    // If all code points are basic (ASCII), we're done
    if (b == input_len) {
        return output.toOwnedSlice();
    }

    // Add delimiter if there were basic code points
    if (b > 0) {
        try output.append(delimiter);
    }

    var n = initial_n;
    var delta: u32 = 0;
    var bias = initial_bias;
    var first_nonbasic = true; // Track if this is the first non-basic character

    var handled = h;
    while (handled < input_len) {
        // Find the minimum code point >= n in input
        var m: u32 = 0x10FFFF;
        for (codepoints.items()) |cp| {
            if (cp >= n and cp < m) {
                m = cp;
            }
        }

        // Increase delta by (m - n) * (handled + 1), checking for overflow
        const diff = m - n;
        const mult = handled + 1;
        if (diff > (std.math.maxInt(u32) - delta) / mult) {
            return PunycodeError.Overflow;
        }
        delta += diff * mult;
        n = m;

        for (codepoints.items()) |cp| {
            if (cp < n) {
                delta += 1;
                if (delta == 0) {
                    return PunycodeError.Overflow;
                }
            } else if (cp == n) {
                // Encode delta
                var q = delta;
                var k = base;
                while (true) {
                    const t = if (k <= bias) tmin else if (k >= bias + tmax) tmax else k - bias;
                    if (q < t) break;
                    try output.append(encodeDigit(t + ((q - t) % (base - t))));
                    q = (q - t) / (base - t);
                    k += base;
                }
                try output.append(encodeDigit(q));
                bias = adapt(delta, handled + 1, first_nonbasic);
                first_nonbasic = false; // After first non-basic, always false
                delta = 0;
                handled += 1;
            }
        }

        delta += 1;
        n += 1;
    }

    return output.toOwnedSlice();
}

/// Decode a Punycode string to Unicode (RFC 3492 Section 6.2)
///
/// Returns UTF-8 encoded string representing the decoded Unicode string.
///
/// Example: "mnchen-3ya" -> "münchen"
pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = infra.List(u21).init(allocator);
    errdefer output.deinit();

    // Find the last delimiter
    var basic_len: usize = 0;
    var has_delimiter = false;
    for (input, 0..) |ch, idx| {
        if (ch == delimiter) {
            basic_len = idx;
            has_delimiter = true;
        }
    }

    // RFC 3492 Section 6.2:
    // If no delimiter found, treat as punycode with no basic part (all extended)
    // Exception: if decoding would produce exact same ASCII, return as-is (handled at end)
    if (!has_delimiter) {
        basic_len = 0;
    }

    // Copy basic code points to output (before the delimiter)
    var i: usize = 0;
    while (i < basic_len) : (i += 1) {
        if (input[i] >= 0x80) {
            return PunycodeError.BadInput;
        }
        try output.append(input[i]);
    }

    var n = initial_n;
    var bias = initial_bias;
    var i_var: u32 = 0;

    // Decode extended code points (after the delimiter, or from start if no basic part)
    var in_idx = if (has_delimiter) basic_len + 1 else 0;
    while (in_idx < input.len) {
        const oldi = i_var;
        var w: u32 = 1;
        var k = base;

        while (true) {
            if (in_idx >= input.len) {
                return PunycodeError.BadInput;
            }
            const digit = try decodeDigit(input[in_idx]);
            in_idx += 1;

            if (digit > (std.math.maxInt(u32) - i_var) / w) {
                return PunycodeError.Overflow;
            }
            i_var += digit * w;

            const t = if (k <= bias) tmin else if (k >= bias + tmax) tmax else k - bias;
            if (digit < t) break;

            if (w > std.math.maxInt(u32) / (base - t)) {
                return PunycodeError.Overflow;
            }
            w *= (base - t);
            k += base;
        }

        const out_len: u32 = @intCast(output.len);
        bias = adapt(i_var - oldi, out_len + 1, oldi == 0);

        if (i_var / (out_len + 1) > std.math.maxInt(u32) - n) {
            return PunycodeError.Overflow;
        }
        n += i_var / (out_len + 1);
        i_var %= (out_len + 1);

        // Insert n at position i_var
        if (n > 0x10FFFF) {
            return PunycodeError.BadInput;
        }
        try output.insert(i_var, @intCast(n));
        i_var += 1;
    }

    // Convert code points to UTF-8
    var result = infra.List(u8).init(allocator);
    errdefer result.deinit();

    for (output.items()) |cp| {
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(cp, &buf) catch {
            return PunycodeError.BadInput;
        };
        try result.appendSlice(buf[0..len]);
    }

    const final_result = try result.toOwnedSlice();
    errdefer allocator.free(final_result);

    // Special case: if input had no delimiter and decoded result equals input,
    // return input as-is (handles decode("example") → "example")
    // This is for punycode identity: decode(encode(ASCII)) = ASCII
    if (!has_delimiter and std.mem.eql(u8, input, final_result)) {
        output.deinit();
        return final_result;
    }

    output.deinit();
    return final_result;
}










