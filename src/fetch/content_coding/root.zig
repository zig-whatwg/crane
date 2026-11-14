//! Content codings (RFC 9110 8.4.1) as Fetch undoes them: HTTP-network
//! fetch's body steps (18.1.1.1.2-11) - "handle content codings" given the
//! response's `Content-Encoding` values - and the `Accept-Encoding` value
//! HTTP-network-or-cache fetch step 8.20 sends "per HTTP".
//!
//! ONE table names every coding Crane decodes: what it advertises, what it
//! reports as a response's filtered coding (Resource Timing's
//! contentEncoding) and the decoder it runs are all read from it, so none
//! can claim a coding another does not have (docs/lessons/architecture-a-
//! content-coding-fetch-reports-is-not-one-curl-decodes.md: curl decoded
//! bodies and was built without zstd while Fetch's list named it).
//!
//! The design is Chromium's network service: a chain of filter streams made
//! from the response's codings when its body starts (net/url_request/
//! url_request_http_job.cc SetUpSourceStream; net/filter/
//! filter_source_stream.cc GetContentEncodingTypes and
//! CreateDecodingSourceStream), each decoding a chunk as it arrives -
//! GzipSourceStream (gzip, deflate), BrotliSourceStream, ZstdSourceStream.
//! Bytes go in and decoded bytes come out piece by piece (`Sink`); no body
//! is ever buffered whole to decode it. Where the browsers are more lenient
//! than the formats, each decoder says which, with its Chromium and Gecko
//! (netwerk/streamconv/converters/nsHTTPCompressConv.cpp) evidence.
const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const flate = @import("flate.zig");
const zstd = @import("zstd.zig");
const brotli = @import("brotli.zig");

/// A content coding Crane can undo.
pub const Coding = enum { gzip, deflate, br, zstd };

/// One row of the table.
pub const Entry = struct {
    coding: Coding,
    /// Its names in the HTTP Content Coding Registry, matched
    /// case-insensitively (RFC 9110 8.4.1); the first is the one
    /// `Accept-Encoding` advertises. "x-gzip": RFC 9110 8.4.1.3 ("A
    /// recipient SHOULD consider "x-gzip" to be equivalent to "gzip"");
    /// Chromium's ParseEncodingType maps it to kGzip.
    names: []const []const u8,
    /// Advertised only to a potentially trustworthy URL. Chromium
    /// (net/http/http_request_headers.cc SetAcceptEncodingIfMissing) offers
    /// "br" and "zstd" only when the URL's scheme is cryptographic or its
    /// host is localhost ("only if transferred data is opaque to proxy");
    /// Firefox the same (network.http.accept-encoding "gzip, deflate" against
    /// network.http.accept-encoding.secure "gzip, deflate, br, zstd"). Both
    /// still decode what arrives.
    trustworthy_only: bool,
};

/// Whether the platform Crane is built for decodes Brotli (a platform
/// capability: kit/brotli's pinned codec).
pub const brotli_supported = platform.capabilities.brotli != .unsupported;

/// Whether gzip and deflate decode with zlib (the platform's zlib_inflate
/// capability) - otherwise with Zig's std.compress.flate (flate.zig).
pub const zlib_inflate_supported = flate.zlib_supported;

/// The DEFLATE decoder gzip and deflate run (flate.zig).
pub const Inflater = flate.Inflater;

/// Every coding, in Chromium's and Firefox's `Accept-Encoding` order
/// ("gzip, deflate, br, zstd").
const every = [_]Entry{
    .{ .coding = .gzip, .names = &.{ "gzip", "x-gzip" }, .trustworthy_only = false },
    .{ .coding = .deflate, .names = &.{"deflate"}, .trustworthy_only = false },
    .{ .coding = .br, .names = &.{"br"}, .trustworthy_only = true },
    .{ .coding = .zstd, .names = &.{"zstd"}, .trustworthy_only = true },
};

fn available(coding: Coding) bool {
    return switch (coding) {
        .br => brotli_supported,
        .gzip, .deflate, .zstd => true,
    };
}

fn availableCount() usize {
    var n: usize = 0;
    for (every) |entry| {
        if (available(entry.coding)) n += 1;
    }
    return n;
}

fn availableEntries() [availableCount()]Entry {
    var list: [availableCount()]Entry = undefined;
    var n: usize = 0;
    for (every) |entry| {
        if (!available(entry.coding)) continue;
        list[n] = entry;
        n += 1;
    }
    return list;
}

const available_entries = availableEntries();

/// THE table: the codings this build decodes - and so advertises and
/// reports.
pub const table: []const Entry = &available_entries;

fn joinNames(comptime trustworthy: bool) []const u8 {
    comptime {
        var out: []const u8 = "";
        for (table) |entry| {
            if (entry.trustworthy_only and !trustworthy) continue;
            if (out.len > 0) out = out ++ ", ";
            out = out ++ entry.names[0];
        }
        return out;
    }
}

const accept_trustworthy = joinNames(true);
const accept_other = joinNames(false);

/// The `Accept-Encoding` value for a request to a URL that is potentially
/// trustworthy or not (see `Entry.trustworthy_only`). Static.
pub fn acceptEncoding(trustworthy: bool) []const u8 {
    return if (trustworthy) accept_trustworthy else accept_other;
}

/// The coding a `Content-Encoding` value names, if this build decodes it.
pub fn byName(name: []const u8) ?Coding {
    for (table) |entry| {
        for (entry.names) |known| {
            if (std.ascii.eqlIgnoreCase(name, known)) return entry.coding;
        }
    }
    return null;
}

/// The registered name `name` matches, lowercased (static), if this build
/// decodes it.
fn lowercasedName(name: []const u8) ?[]const u8 {
    for (table) |entry| {
        for (entry.names) |known| {
            if (std.ascii.eqlIgnoreCase(name, known)) return known;
        }
    }
    return null;
}

// ============================================================================
// Content-Encoding's values
// ============================================================================

/// The longest value whose bytes `Value` keeps: longer than every name in
/// the table, so a longer value names no coding.
pub const max_value_len = 16;

/// One value of a header's "get, decode, and split", as far as naming a
/// coding needs: its bytes when short, its length always.
pub const Value = struct {
    buffer: [max_value_len]u8 = undefined,
    /// Its length, HTTP tab or space trimmed (it may exceed the buffer).
    len: usize = 0,

    /// The value, when it is short enough to name a coding.
    pub fn bytes(self: *const Value) ?[]const u8 {
        return if (self.len <= max_value_len) self.buffer[0..self.len] else null;
    }
};

/// Fetch "extract header list values" given `Content-Encoding`: "get,
/// decode, and split" (Fetch 2.2.2) over the header's values - `fields`
/// yields each `Content-Encoding` field value in order (`next() ?[]const
/// u8`), and "get" joins them with ", " - without allocating.
pub fn Split(comptime Fields: type) type {
    return struct {
        const Self = @This();

        fields: Fields,
        /// The field being read, and the position in it.
        current: []const u8 = "",
        position: usize = 0,
        /// Bytes of the ", " "get" puts between two fields still to read.
        separator: u2 = 0,
        /// A field has been read: "get" found the header.
        found: bool = false,
        /// The combined value has been read to its end.
        done: bool = false,

        pub fn init(fields: Fields) Self {
            return .{ .fields = fields };
        }

        /// Whether the header list contains `Content-Encoding` at all
        /// (otherwise "get" returns null, and so do the extracted values).
        /// Valid once `next` has been called.
        pub fn present(self: *const Self) bool {
            return self.found;
        }

        fn peek(self: *Self) ?u8 {
            while (true) {
                if (self.separator == 2) return ',';
                if (self.separator == 1) return ' ';
                if (self.position < self.current.len) return self.current[self.position];
                const next_field = self.fields.next() orelse return null;
                if (self.found) self.separator = 2;
                self.found = true;
                self.current = next_field;
                self.position = 0;
            }
        }

        fn advance(self: *Self) void {
            if (self.separator > 0) {
                self.separator -= 1;
                return;
            }
            self.position += 1;
        }

        /// The next value, or null after the last.
        pub fn next(self: *Self) ?Value {
            if (self.done) return null;
            // "get" of a header list without the header: null, no values.
            if (self.peek() == null and !self.found) {
                self.done = true;
                return null;
            }
            var value: Value = .{};
            // Bytes appended so far, and the length up to the last byte that
            // is not HTTP tab or space (5.3 trims both ends).
            var appended: usize = 0;
            const append = struct {
                fn f(v: *Value, count: *usize, c: u8) void {
                    // Leading HTTP tab or space is trimmed (5.3).
                    if (count.* == 0 and (c == ' ' or c == '\t')) return;
                    if (count.* < max_value_len) v.buffer[count.*] = c;
                    count.* += 1;
                    if (c != ' ' and c != '\t') v.len = count.*;
                }
            }.f;
            // 5. While true:
            while (true) {
                // 5.1. Collect code points that are not U+0022 (") or U+002C (,).
                while (self.peek()) |c| {
                    if (c == '"' or c == ',') break;
                    append(&value, &appended, c);
                    self.advance();
                }
                // 5.2. A U+0022 ("): an HTTP quoted string, its quotes and
                // escapes kept (extract-value false); then on, if not at the end.
                if (self.peek()) |c| if (c == '"') {
                    append(&value, &appended, c);
                    self.advance();
                    while (self.peek()) |q| {
                        append(&value, &appended, q);
                        self.advance();
                        if (q == '"') break;
                        if (q == '\\') {
                            const escaped = self.peek() orelse break;
                            append(&value, &appended, escaped);
                            self.advance();
                        }
                    }
                    if (self.peek() != null) continue;
                };
                break;
            }
            // 5.3-5.4: the value, trimmed, is appended (value.len is its
            // trimmed length). 5.6: past the end, the values are complete;
            // 5.7-5.8: otherwise the code point is "," - past it.
            if (self.peek() == null) {
                self.done = true;
            } else {
                self.advance();
            }
            return value;
        }
    };
}

pub fn split(fields: anytype) Split(@TypeOf(fields)) {
    return .init(fields);
}

/// `fields` for a slice of headers with `name` and `value` (a header list's
/// entries, a stored response's headers, the network's headers): their
/// `Content-Encoding` values.
pub fn HeaderFields(comptime Header: type) type {
    return struct {
        headers: []const Header,
        index: usize = 0,

        pub fn next(self: *@This()) ?[]const u8 {
            while (self.index < self.headers.len) {
                const header = self.headers[self.index];
                self.index += 1;
                if (std.ascii.eqlIgnoreCase(header.name, "Content-Encoding")) return header.value;
            }
            return null;
        }
    };
}

pub fn headerFields(headers: anytype) HeaderFields(std.meta.Elem(@TypeOf(headers))) {
    return .{ .headers = headers };
}

/// HTTP-network fetch 18.1.1.1.2-6: `filteredCoding` for `fields` (each
/// `Content-Encoding` field value in order). Static.
pub fn filteredCoding(fields: anytype) []const u8 {
    // 2. Let codings be the result of extracting header list values given
    //    `Content-Encoding` and response's header list.
    var values = split(fields);
    const first = values.next();
    // 4. If codings is null or failure, then set filteredCoding to the
    //    empty string. (3's "@unknown" is the default below.)
    const first_value = first orelse return "";
    if (!values.present()) return "";
    // 5. Otherwise, if codings's size is greater than 1, then set
    //    filteredCoding to "multiple".
    if (values.next() != null) return "multiple";
    // 6. Otherwise, if codings[0] is the empty string, or it is supported by
    //    the user agent, and is a byte-case-insensitive match for an entry
    //    listed in the HTTP Content Coding Registry, then set filteredCoding
    //    to the result of byte-lowercasing codings[0]. Every name in the
    //    table is registered. "identity" is registered (reserved, RFC 9110
    //    8.4) but is not a coding a response may carry: it is "@unknown", as
    //    WPT resource-timing/content-encoding.https.html asserts.
    const name = first_value.bytes() orelse return "@unknown";
    if (name.len == 0) return "";
    return lowercasedName(name) orelse "@unknown";
}

/// The most codings a chain undoes: Chromium's kMaxNestedSourceStreamDepth
/// (url_request_http_job.cc), past which SetUpSourceStream fails the request
/// (ERR_CONTENT_DECODING_INIT_FAILED). The spec sets no bound; a decoder per
/// coding is a resource each response holds.
pub const max_codings = 10;

/// What a response's codings ask of its body.
pub const Plan = union(enum) {
    /// Nothing to undo: no coding, or one this user agent does not support -
    /// "handle content codings" step 1: "If codings are not supported, then
    /// return bytes." Chromium the same: an unknown value anywhere
    /// (identity included) makes GetContentEncodingTypes pass the raw body
    /// through ("Request will not be canceled").
    identity,
    /// Undo these. `codings[0..len]` in header order: the coding applied
    /// first comes first (RFC 9110 8.4: "lists the content codings in the
    /// order in which they were applied"), so the LAST is undone first.
    decode: Codings,
    /// More than `max_codings`: failure.
    too_many,
};

pub const Codings = struct {
    list: [max_codings]Coding = undefined,
    len: u8 = 0,

    pub fn slice(self: *const Codings) []const Coding {
        return self.list[0..self.len];
    }
};

/// The plan for `fields` (each `Content-Encoding` field value in order).
pub fn plan(fields: anytype) Plan {
    var values = split(fields);
    var codings: Codings = .{};
    var count: usize = 0;
    while (values.next()) |value| {
        // An empty value names nothing: Chromium's header value iterator
        // (HttpUtil::ValuesIterator) and Firefox's strtok over the field
        // (nsHttpChannel::DoApplyContentConversions) both skip it, so
        // "gzip, " is gzip.
        if (value.len == 0) continue;
        const name = value.bytes() orelse return .identity;
        const coding = byName(name) orelse return .identity;
        if (count < max_codings) codings.list[count] = coding;
        count += 1;
    }
    if (count == 0) return .identity;
    if (count > max_codings) return .too_many;
    codings.len = @intCast(count);
    return .{ .decode = codings };
}

// ============================================================================
// The decoder chain
// ============================================================================

pub const Error = error{
    OutOfMemory,
    /// The bytes are not what the coding makes: "handle content codings"
    /// returns failure (Chromium's ERR_CONTENT_DECODING_FAILED).
    InvalidData,
    /// The sink wants no more (its reader has gone).
    Stopped,
};

/// Where decoded bytes go. `bytes` is BORROWED for the call.
pub const Sink = struct {
    context: *anyopaque,
    write: *const fn (context: *anyopaque, bytes: []const u8) Error!void,
};

/// One coding's decoder: bytes in as they arrive, decoded bytes out to a
/// sink as they are made. Each consumes all it is given, keeping what it
/// cannot decode yet; a body that ends inside a coding's stream ends there,
/// with no error - Chromium (GzipSourceStream, BrotliSourceStream and
/// ZstdSourceStream ignore their upstream's end) and Firefox
/// (nsHTTPCompressConv::OnStopRequest fails an unfinished gzip only under
/// the off-by-default network.http.enforce-framing.http) hand on a
/// truncated body as far as it decoded.
const Stage = union(Coding) {
    gzip: *flate.Decoder,
    deflate: *flate.Decoder,
    br: brotli.Decoder,
    zstd: *zstd.Decoder,

    fn create(allocator: Allocator, coding: Coding, options: Options) Error!Stage {
        return switch (coding) {
            .gzip => .{ .gzip = try flate.Decoder.createWith(allocator, .gzip, options.inflater) },
            .deflate => .{ .deflate = try flate.Decoder.createWith(allocator, .zlib, options.inflater) },
            .br => if (comptime brotli_supported) .{ .br = try brotli.Decoder.init(allocator) } else unreachable,
            .zstd => .{ .zstd = try zstd.Decoder.create(allocator) },
        };
    }

    fn destroy(self: *Stage) void {
        switch (self.*) {
            .gzip, .deflate => |decoder| decoder.destroy(),
            .br => |*decoder| if (comptime brotli_supported) decoder.deinit() else unreachable,
            .zstd => |decoder| decoder.destroy(),
        }
    }

    fn push(self: *Stage, bytes: []const u8, sink: Sink) Error!void {
        return switch (self.*) {
            .gzip, .deflate => |decoder| decoder.push(bytes, sink),
            .br => |*decoder| if (comptime brotli_supported) decoder.push(bytes, sink) else unreachable,
            .zstd => |decoder| decoder.push(bytes, sink),
        };
    }
};

/// How a chain decodes.
pub const Options = struct {
    /// gzip's and deflate's DEFLATE decoder: zlib's where the platform has
    /// it (Fetch always takes this default; the other is for tests).
    inflater: Inflater = .preferred,
};

/// The decoders for one response's codings, chained: the body's bytes go
/// to the decoder of the coding applied last, its output to the one before
/// it, and the first coding's output to the sink - Chromium's
/// CreateDecodingSourceStream builds the same chain ("for (const auto& type
/// : std::views::reverse(types))"). OWNED by its creator (`destroy`).
pub const Decoder = struct {
    allocator: Allocator,
    /// stages[0] undoes the coding listed LAST.
    stages: [max_codings]Stage,
    len: usize,
    /// A push failed: every later one fails too.
    failed: bool = false,

    pub fn create(allocator: Allocator, codings: []const Coding) Error!*Decoder {
        return createWith(allocator, codings, .{});
    }

    pub fn createWith(allocator: Allocator, codings: []const Coding, options: Options) Error!*Decoder {
        std.debug.assert(codings.len > 0 and codings.len <= max_codings);
        const self = try allocator.create(Decoder);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .stages = undefined, .len = 0 };
        errdefer for (self.stages[0..self.len]) |*stage| stage.destroy();
        var i = codings.len;
        while (i > 0) {
            i -= 1;
            self.stages[self.len] = try Stage.create(allocator, codings[i], options);
            self.len += 1;
        }
        return self;
    }

    pub fn destroy(self: *Decoder) void {
        for (self.stages[0..self.len]) |*stage| stage.destroy();
        self.allocator.destroy(self);
    }

    /// Decode `bytes`, the body's next bytes, writing what they decode to
    /// to `sink`. `error.InvalidData` is "handle content codings" failure.
    pub fn push(self: *Decoder, bytes: []const u8, sink: Sink) Error!void {
        if (self.failed) return error.InvalidData;
        errdefer self.failed = true;
        return self.pushAt(0, bytes, sink);
    }

    fn pushAt(self: *Decoder, index: usize, bytes: []const u8, sink: Sink) Error!void {
        if (index == self.len) return sink.write(sink.context, bytes);
        var forward: Forward = .{ .decoder = self, .index = index + 1, .sink = sink };
        return self.stages[index].push(bytes, .{ .context = &forward, .write = Forward.write });
    }

    /// The sink of stage `index - 1`: stage `index`, or the chain's sink.
    const Forward = struct {
        decoder: *Decoder,
        index: usize,
        sink: Sink,

        fn write(context: *anyopaque, bytes: []const u8) Error!void {
            const self: *Forward = @ptrCast(@alignCast(context));
            if (bytes.len == 0) return;
            return self.decoder.pushAt(self.index, bytes, self.sink);
        }
    };
};

/// Decode a whole body `bytes` with `codings` into one allocation (OWNED by
/// the caller): for a body the network handed over at once.
pub fn decodeAll(allocator: Allocator, codings: []const Coding, bytes: []const u8) Error![]u8 {
    const decoder = try Decoder.create(allocator, codings);
    defer decoder.destroy();
    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(allocator);
    var collect: Collect = .{ .allocator = allocator, .out = &out };
    try decoder.push(bytes, collect.sink());
    return out.toOwnedSlice(allocator);
}

/// A sink that appends to a list.
pub const Collect = struct {
    allocator: Allocator,
    out: *std.ArrayListUnmanaged(u8),

    pub fn sink(self: *Collect) Sink {
        return .{ .context = self, .write = write };
    }

    fn write(context: *anyopaque, bytes: []const u8) Error!void {
        const self: *Collect = @ptrCast(@alignCast(context));
        try self.out.appendSlice(self.allocator, bytes);
    }
};

test {
    _ = flate;
    _ = zstd;
    _ = brotli;
}
