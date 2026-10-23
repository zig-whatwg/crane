//! WOFF 1.0, unwrapped to the sfnt it carries - with OTS's checks (ots.cc
//! ProcessWOFF and ProcessGeneric's WOFF rules), which is what Blink and
//! Gecko apply (OTS unwraps WOFF itself; Blink hands it WOFF data
//! directly):
//!
//! - the length field is the file's length; numTables at least 1; the
//!   reserved field 0; the flavor an sfnt version;
//! - totalSfntSize is exactly the header, directory and 4-byte padded
//!   tables the directory declares;
//! - the table data starts right after the directory, each table 4-byte
//!   aligned, inside the file and not overlapping another;
//! - the metadata and private blocks, when present, follow the last table
//!   and each other with at most 3 bytes of padding, and nothing follows
//!   them ("File length mismatch (trailing junk?)");
//! - a compressed table inflates, as zlib's uncompress(), to exactly its
//!   origLength (kit/inflate's zlibWhole).
//!
//! The extended metadata itself is not read: WOFF 1.0 7 lets a user agent
//! ignore it, and OTS does.

const std = @import("std");
const bytes = @import("bytes.zig");
const sfnt = @import("sfnt.zig");
const inflate = @import("kit_inflate");

pub const Error = error{ Corrupt, OutOfMemory, TooLarge };

/// The sfnt `data` carries, OWNED by `allocator`. `max_sfnt` bounds the
/// sfnt's declared size, checked before anything is allocated.
pub fn decode(allocator: std.mem.Allocator, data: []const u8, max_sfnt: u64) Error![]u8 {
    if (data.len > sfnt.max_file) return error.TooLarge;
    var r = bytes.Reader.init(data);
    if (try r.u32_() != bytes.tag("wOFF")) return error.Corrupt;
    const flavor = try r.u32_();
    if (!sfnt.isSfntVersion(flavor)) return error.Corrupt;
    if (try r.u32_() != data.len) return error.Corrupt;
    const num_tables = try r.u16_();
    if (num_tables == 0) return error.Corrupt;
    if (try r.u16_() != 0) return error.Corrupt;
    const total_sfnt_size = try r.u32_();
    try r.skip(4); // majorVersion, minorVersion
    const meta_offset = try r.u32_();
    const meta_length = try r.u32_();
    _ = try r.u32_(); // metaOrigLength
    if (meta_offset != 0 and (meta_offset >= data.len or data.len - meta_offset < meta_length)) return error.Corrupt;
    const private_offset = try r.u32_();
    const private_length = try r.u32_();
    if (private_offset != 0 and (private_offset >= data.len or data.len - private_offset < private_length)) return error.Corrupt;

    if (r.remaining() / 20 < num_tables) return error.Corrupt;
    const records = try allocator.alloc(sfnt.Record, num_tables);
    defer allocator.free(records);
    var computed_size: u64 = 12 + 16 * @as(u64, num_tables);
    var first: usize = 0;
    var last: usize = 0;
    for (records, 0..) |*record, i| {
        record.tag = try r.u32_();
        record.offset = try r.u32_();
        record.length = try r.u32_();
        record.uncompressed_length = try r.u32_();
        _ = try r.u32_(); // origChecksum: not verified, as OTS does not
        computed_size += bytes.round4(record.uncompressed_length);
        if (computed_size > std.math.maxInt(u32)) return error.Corrupt;
        if (i == 0 or records[first].offset > record.offset) first = i;
        if (i == 0 or records[last].offset < record.offset) last = i;
    }
    if (total_sfnt_size != computed_size) return error.Corrupt;
    // The table data follows the directory, padded to 4 bytes.
    if (records[first].offset != bytes.round4(r.pos)) return error.Corrupt;
    if (records[last].offset >= data.len or data.len - records[last].offset < records[last].length) return error.Corrupt;
    // The blocks follow each other, and nothing follows the last.
    var block_end = bytes.round4(@as(u64, records[last].offset) + records[last].length);
    if (block_end > std.math.maxInt(u32)) return error.Corrupt;
    if (meta_offset != 0) {
        if (block_end != meta_offset) return error.Corrupt;
        block_end = bytes.round4(@as(u64, meta_offset) + meta_length);
        if (block_end > std.math.maxInt(u32)) return error.Corrupt;
    }
    if (private_offset != 0) {
        if (block_end != private_offset) return error.Corrupt;
        block_end = bytes.round4(@as(u64, private_offset) + private_length);
        if (block_end > std.math.maxInt(u32)) return error.Corrupt;
    }
    if (block_end != bytes.round4(data.len)) return error.Corrupt;
    try sfnt.checkRecords(allocator, records, r.pos, data.len, .woff);

    if (total_sfnt_size > max_sfnt) return error.TooLarge;
    const out = try allocator.alloc(u8, total_sfnt_size);
    errdefer allocator.free(out);
    @memset(out, 0);
    // The sfnt: the flavor's header, then the tables in the WOFF's order.
    var power: u32 = 1;
    var log2: u16 = 0;
    while (power * 2 <= num_tables) : (log2 += 1) power *= 2;
    std.mem.writeInt(u32, out[0..4], flavor, .big);
    std.mem.writeInt(u16, out[4..6], num_tables, .big);
    std.mem.writeInt(u16, out[6..8], @intCast(power * 16), .big);
    std.mem.writeInt(u16, out[8..10], log2, .big);
    std.mem.writeInt(u16, out[10..12], @intCast(num_tables * 16 - power * 16), .big);
    var at: usize = 12 + 16 * @as(usize, num_tables);
    for (records, 0..) |record, i| {
        const entry = out[12 + 16 * i ..][0..16];
        const table = out[at..][0..record.uncompressed_length];
        const stored = data[record.offset..][0..record.length];
        if (record.length == record.uncompressed_length) {
            @memcpy(table, stored);
        } else if (!inflate.zlibWhole(table, stored)) {
            return error.Corrupt;
        }
        std.mem.writeInt(u32, entry[0..4], record.tag, .big);
        std.mem.writeInt(u32, entry[4..8], sfnt.checksum(table), .big);
        std.mem.writeInt(u32, entry[8..12], @intCast(at), .big);
        std.mem.writeInt(u32, entry[12..16], record.uncompressed_length, .big);
        at += @intCast(bytes.round4(record.uncompressed_length));
    }
    return out;
}
