//! CLDR Binary Encoder
//!
//! Encodes extracted CLDR data into a compact binary format for
//! efficient runtime loading of Tier 2 locales.
//!
//! Usage:
//!   zig build cldr-encode -- --input src/intl/cldr/ --output data/cldr/bin/
//!
//! Binary Format:
//!   Header (32 bytes):
//!     [0-3]   Magic: "CLDR"
//!     [4-5]   Version: u16
//!     [6-7]   Flags: u16
//!     [8-11]  Tag offset: u32
//!     [12-15] Tag length: u32
//!     [16-19] String table offset: u32
//!     [20-23] String table length: u32
//!     [24-27] Data section offset: u32
//!     [28-31] Data section length: u32
//!
//!   String Table:
//!     Deduplicated strings with length prefix
//!
//!   Data Section:
//!     Indexed references to string table

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Binary file header
pub const BinaryHeader = extern struct {
    /// Magic number "CLDR"
    magic: [4]u8 = .{ 'C', 'L', 'D', 'R' },
    /// Format version
    version: u16 = 1,
    /// Flags (reserved)
    flags: u16 = 0,
    /// Offset to locale tag
    tag_offset: u32 = 0,
    /// Length of locale tag
    tag_length: u32 = 0,
    /// Offset to string table
    string_table_offset: u32 = 0,
    /// Length of string table in bytes
    string_table_length: u32 = 0,
    /// Offset to data section
    data_offset: u32 = 0,
    /// Length of data section in bytes
    data_length: u32 = 0,
};

/// String table for deduplication
pub const StringTable = struct {
    allocator: Allocator,
    strings: std.StringHashMap(u32),
    buffer: std.ArrayList(u8),
    next_offset: u32,

    pub fn init(allocator: Allocator) StringTable {
        return .{
            .allocator = allocator,
            .strings = std.StringHashMap(u32).init(allocator),
            .buffer = std.ArrayList(u8).init(allocator),
            .next_offset = 0,
        };
    }

    pub fn deinit(self: *StringTable) void {
        self.strings.deinit();
        self.buffer.deinit();
    }

    /// Add a string and return its offset
    pub fn add(self: *StringTable, string: []const u8) !u32 {
        // Check if already in table
        if (self.strings.get(string)) |offset| {
            return offset;
        }

        // Add to buffer with length prefix
        const offset = self.next_offset;
        const len: u32 = @intCast(string.len);

        // Write length (varint-style)
        if (len < 128) {
            try self.buffer.append(@intCast(len));
            self.next_offset += 1;
        } else {
            try self.buffer.append(@as(u8, @intCast(len & 0x7F)) | 0x80);
            try self.buffer.append(@as(u8, @intCast(len >> 7)));
            self.next_offset += 2;
        }

        // Write string content
        try self.buffer.appendSlice(string);
        self.next_offset += len;

        // Record in map (need to dupe the key)
        const key = try self.allocator.dupe(u8, string);
        try self.strings.put(key, offset);

        return offset;
    }

    /// Get the serialized buffer
    pub fn getBuffer(self: *const StringTable) []const u8 {
        return self.buffer.items;
    }
};

/// Encode locale data to binary format
pub fn encodeLocale(allocator: Allocator, tag: []const u8, data: anytype, writer: anytype) !void {
    var string_table = StringTable.init(allocator);
    defer string_table.deinit();

    // Build string table by adding all strings
    _ = try string_table.add(tag);

    // Add month names
    for (data.months.wide) |s| _ = try string_table.add(s);
    for (data.months.abbreviated) |s| _ = try string_table.add(s);
    for (data.months.narrow) |s| _ = try string_table.add(s);

    // Add weekday names
    for (data.weekdays.wide) |s| _ = try string_table.add(s);
    for (data.weekdays.abbreviated) |s| _ = try string_table.add(s);
    for (data.weekdays.narrow) |s| _ = try string_table.add(s);
    for (data.weekdays.short) |s| _ = try string_table.add(s);

    // Add day periods
    _ = try string_table.add(data.day_periods.am);
    _ = try string_table.add(data.day_periods.pm);

    // Add era names
    for (data.eras.wide) |s| _ = try string_table.add(s);
    for (data.eras.abbreviated) |s| _ = try string_table.add(s);
    for (data.eras.narrow) |s| _ = try string_table.add(s);

    // Add datetime patterns
    _ = try string_table.add(data.datetime_patterns.date_full);
    _ = try string_table.add(data.datetime_patterns.date_long);
    _ = try string_table.add(data.datetime_patterns.date_medium);
    _ = try string_table.add(data.datetime_patterns.date_short);
    _ = try string_table.add(data.datetime_patterns.time_full);
    _ = try string_table.add(data.datetime_patterns.time_long);
    _ = try string_table.add(data.datetime_patterns.time_medium);
    _ = try string_table.add(data.datetime_patterns.time_short);

    // Add number symbols
    _ = try string_table.add(data.number_symbols.decimal);
    _ = try string_table.add(data.number_symbols.group);
    _ = try string_table.add(data.number_symbols.percent);
    _ = try string_table.add(data.number_symbols.minus);
    _ = try string_table.add(data.number_symbols.plus);

    // Calculate offsets
    const header_size: u32 = @sizeOf(BinaryHeader);
    const tag_offset = header_size;
    const tag_length: u32 = @intCast(tag.len);
    const string_table_offset = tag_offset + tag_length;
    const string_table_length: u32 = @intCast(string_table.getBuffer().len);

    // Build header
    var header = BinaryHeader{
        .tag_offset = tag_offset,
        .tag_length = tag_length,
        .string_table_offset = string_table_offset,
        .string_table_length = string_table_length,
        .data_offset = string_table_offset + string_table_length,
        .data_length = 0, // TODO: calculate actual data section
    };

    // Write header
    try writer.writeAll(std.mem.asBytes(&header));

    // Write tag
    try writer.writeAll(tag);

    // Write string table
    try writer.writeAll(string_table.getBuffer());
}

/// Encoder state
pub const EncodeState = struct {
    allocator: Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
    verbose: bool,

    pub fn init(allocator: Allocator, input_dir: []const u8, output_dir: []const u8, verbose: bool) EncodeState {
        return .{
            .allocator = allocator,
            .input_dir = input_dir,
            .output_dir = output_dir,
            .verbose = verbose,
        };
    }
};

/// Command-line interface
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var input_dir: []const u8 = "src/intl/cldr";
    var output_dir: []const u8 = "data/cldr/bin";
    var verbose: bool = false;

    // Parse arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            input_dir = args.next() orelse {
                std.log.err("Missing input directory argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_dir = args.next() orelse {
                std.log.err("Missing output directory argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
    }

    // Create output directory
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    _ = EncodeState.init(allocator, input_dir, output_dir, verbose);

    std.log.info("CLDR Binary Encoder", .{});
    std.log.info("Input: {s}", .{input_dir});
    std.log.info("Output: {s}", .{output_dir});

    // TODO: Read extracted locale data and encode to binary
    // For now, this is a placeholder

    std.log.info("Encoding complete!", .{});
}

fn printHelp() void {
    const help =
        \\CLDR Binary Encoder
        \\
        \\Encodes extracted CLDR data into compact binary format for runtime loading.
        \\
        \\Usage:
        \\  cldr-encode [options]
        \\
        \\Options:
        \\  -i, --input <DIR>     Input directory with extracted data (default: src/intl/cldr/)
        \\  -o, --output <DIR>    Output directory for binary files (default: data/cldr/bin/)
        \\  --verbose             Show verbose output
        \\  -h, --help            Show this help
        \\
        \\The encoder reads Zig source files generated by cldr-extract and produces
        \\compact binary files for runtime loading of Tier 2 locales.
        \\
    ;
    std.io.getStdOut().writeAll(help) catch {};
}

// ============================================================================
// Tests
// ============================================================================

test "BinaryHeader has correct size" {
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(BinaryHeader));
}

test "StringTable deduplicates strings" {
    const allocator = std.testing.allocator;

    var table = StringTable.init(allocator);
    defer table.deinit();

    const offset1 = try table.add("hello");
    const offset2 = try table.add("world");
    const offset3 = try table.add("hello"); // Duplicate

    try std.testing.expectEqual(offset1, offset3); // Same string = same offset
    try std.testing.expect(offset1 != offset2); // Different strings = different offsets
}

test "StringTable encodes short strings" {
    const allocator = std.testing.allocator;

    var table = StringTable.init(allocator);
    defer table.deinit();

    _ = try table.add("hi");

    // Should be: length (1 byte: 2) + content (2 bytes: "hi")
    const buf = table.getBuffer();
    try std.testing.expectEqual(@as(usize, 3), buf.len);
    try std.testing.expectEqual(@as(u8, 2), buf[0]); // Length
    try std.testing.expectEqualStrings("hi", buf[1..3]); // Content
}
