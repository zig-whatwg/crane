//! CSS Syntax 3 section 3.2: decode a stylesheet's bytes before tokenizing.
//! https://drafts.csswg.org/css-syntax-3/#input-byte-stream
//! The returned encoding is also the environment encoding of its imports.
const std = @import("std");
const encodings = @import("encoding");
const Allocator = std.mem.Allocator;

/// Immutable encoding identity retained by a stylesheet load.
pub const Encoding = encodings.Encoding;

/// Encoding Standard "get an encoding", for document/link metadata.
pub const encodingForLabel = encodings.getEncoding;

/// Hints supplied by the response and the referring document or stylesheet.
pub const Options = struct {
    protocol_label: ?[]const u8 = null,
    environment_label: ?[]const u8 = null,
};

/// Decoded text is owned; encoding names an immutable Encoding entry.
pub const Decoded = struct {
    text: []u8,
    encoding: *const encodings.Encoding,

    pub fn deinit(self: *Decoded, allocator: Allocator) void {
        allocator.free(self.text);
    }
};

/// CSS Syntax section 3.2, "determine the fallback encoding" steps 1–4.
pub fn fallback(bytes: []const u8, options: Options) *const encodings.Encoding {
    // 1. A recognized protocol label takes precedence over @charset.
    if (options.protocol_label) |label| if (encodings.getEncoding(label)) |encoding| return encoding;
    // 2. This is an exact byte signature, not an at-rule token grammar.
    const prefix = "@charset \"";
    const sniff = bytes[0..@min(bytes.len, 1024)];
    if (std.mem.startsWith(u8, sniff, prefix)) {
        var end: usize = prefix.len;
        while (end < sniff.len and sniff[end] < 0x80 and sniff[end] != '"') : (end += 1) {}
        if (end + 1 < sniff.len and sniff[end] == '"' and sniff[end + 1] == ';') {
            if (encodings.getEncoding(sniff[prefix.len..end])) |encoding| {
                if (encoding == &encodings.encoding.UTF_16BE or encoding == &encodings.encoding.UTF_16LE) return encodings.UTF_8;
                return encoding;
            }
        }
    }
    // 3. The referring document or sheet supplies the environment encoding.
    if (options.environment_label) |label| if (encodings.getEncoding(label)) |encoding| return encoding;
    // 4. With no usable hint, use UTF-8.
    return encodings.UTF_8;
}

/// CSS Syntax section 3.2 "decode bytes", with Encoding section 6.1 decode:
/// select fallback, then let a BOM override it, and decode in replacement mode.
/// The caller owns the returned text, including for empty input.
pub fn decode(allocator: Allocator, bytes: []const u8, options: Options) Allocator.Error!Decoded {
    // CSS steps 1–2 / Encoding steps 1–2: BOM overrides every hint.
    var encoding = fallback(bytes, options);
    var input = bytes;
    if (encodings.bom.sniff(bytes)) |bom| {
        encoding = switch (bom) {
            .utf8 => encodings.UTF_8,
            .utf16be => &encodings.encoding.UTF_16BE,
            .utf16le => &encodings.encoding.UTF_16LE,
        };
        input = input[encodings.bom.length(bom)..];
    }
    // 3. Each input byte can produce at most one three-byte replacement;
    // the extra space also covers a decoder's pending output at EOF.
    const capacity = std.math.add(usize, std.math.mul(usize, input.len, 3) catch return error.OutOfMemory, 3) catch return error.OutOfMemory;
    const output = try allocator.alloc(u8, capacity);
    errdefer allocator.free(output);
    var decoder = encoding.newDecoder();
    const result = decoder.decodeToUtf8Replacement(input, output, true);
    std.debug.assert(result.status == .input_empty and result.bytes_consumed == input.len);
    // 4. Return the scalar values as UTF-8 to the CSS tokenizer.
    return .{ .text = try allocator.realloc(output, result.bytes_written), .encoding = encoding };
}
