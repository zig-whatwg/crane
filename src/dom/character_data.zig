//! A CharacterData node's data, read in place by the tree's own algorithms.
//!
//! The IDL `data` getter answers a new DOMString that its caller frees: right
//! for script, which gets a copy of the string anyway. DOM's own reads only
//! look at the bytes - Node's textContent and nodeValue getters and the
//! "descendant text content" they concatenate (DOM 4.4), isEqualNode's data
//! comparison, an option's text and a textarea's child text content (HTML) -
//! and a copy per Text node would put an allocation on each of those paths.
//! They may not reach into CharacterData's impl (AGENTS.md "The impls
//! boundary"), so CharacterData installs the read here, the shape of
//! `blob_bytes.zig`. WebKit's `CharacterData::data()` returns its String by
//! reference for the same reason (Source/WebCore/dom/CharacterData.h).
//!
//! The bytes are BORROWED: valid until the node's data next changes ("replace
//! data", DOM 4.10) or the node is freed. A caller copies what it keeps.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//!
//! lint-impls: hook for CharacterData, ProcessingInstruction

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

pub const Steps = struct {
    /// `node`'s data, borrowed (see above), or null when `node` has no
    /// CharacterData part.
    data_of: *const fn (node: *runtime.Instance) ?[]const u8,
};

pub const ProcessingInstructionSteps = struct {
    /// Replace-data step 12: update the PI's attribute map from its new data.
    data_changed: *const fn (*runtime.Instance) void,
};

const Hooks = struct {
    character_data: ?Steps = null,
    processing_instruction: ?ProcessingInstructionSteps = null,
};
// process-wide: immutable algorithms set by install (CharacterData) and installProcessingInstruction at process start; each reads only the supplied node, with no instance state
var steps: Hook(Hooks) = .init(.{});

/// Called by CharacterData's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    steps.installField("character_data", s);
}

/// `node`'s data, borrowed until it next changes: copy what you keep. Null
/// when `node` is no CharacterData node (or CharacterData installed nothing).
pub fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const s = steps.read().character_data orelse return null;
    return s.data_of(node);
}

/// Called by ProcessingInstruction's installHooks, once at process start.
pub fn installProcessingInstruction(s: ProcessingInstructionSteps) void {
    steps.installField("processing_instruction", s);
}

/// Only CharacterData's PI branch calls this; ordinary Text mutations never
/// enter the PI owner or parse any attributes.
pub fn processingInstructionDataChanged(node: *runtime.Instance) void {
    const s = steps.read().processing_instruction orelse return;
    s.data_changed(node);
}

/// A CharacterData node's data, as CharacterData keeps it in its state: the
/// type is here so that what it is - the small-string storage and the
/// code-unit splice of "replace data" - is shared, while the state stays
/// CharacterData's, with its lifetime (lesson
/// architecture-move-the-states-type-out-of-the-impl-not-the-state).
///
/// DOM measures and indexes data in UTF-16 code units (DOM 4.10, Infra §4.6);
/// Crane holds it as WTF-8 (a lone surrogate as its three bytes, a pair as one
/// four-byte sequence; infra/wtf8.zig). So the state keeps both lengths: the
/// bytes, and the code units - the node's length - counted when data is set
/// and kept current by every splice. When the two are equal every byte is
/// ASCII and an offset is its own byte offset; otherwise offsets are mapped
/// onto the bytes by infra.wtf8.
///
/// 16 bytes on every Text, Comment, CDATASection and ProcessingInstruction
/// (lane nd1 batch 1, N8 of tmp/redesign/nodedata-design.md; it was 48: a
/// heap pointer, the two lengths and a 31-byte inline buffer that every node
/// paid for, while 32-99.8% of a page's texts are 1-8 code units and 11-76%
/// whitespace only - tmp/redesign/nodedata/crane-layout.md P8). The bytes
/// live in one of three places (`Storage`):
/// - up to `inline_capacity` (8) bytes in the Data's own `word` - the shape of
///   Lightpanda's 16-byte German string (src/string.zig at c6d54d8f7c10: a
///   length, then an 8-byte extern union of inline bytes and a pointer);
/// - whitespace of the shape Gecko shares (`sharedWhitespace`) as a slice of
///   ONE static blob - Gecko's CharacterDataBuffer points such text into its
///   static sSpaceSharedString/sTabSharedString and tells it from the heap by
///   its state word's `mInHeap` bit (dom/base/CharacterDataBuffer.{h,cpp} at
///   7d1680b9a0d4, SetTo and ReleaseBuffer); Blink's parser shares the same
///   texts as atoms (core/html/parser/html_construction_site.cc
///   CheckWhitespaceAndConvertToString at 3ad43ecbc857);
/// - anything else one exact-size block of the node's allocator, as long
///   text was before.
/// Which is told by the length and the `shared` bit, never by an address
/// range (lesson
/// debugging-a-heuristic-over-pointer-ranges-breaks-when-the-allocators-layout-moves),
/// and every free goes through `freeBytes`, which frees a block only.
///
/// The bytes are never written in place: every change builds the new data
/// in new storage and then lets the old go, so a node never writes into the
/// blob or into bytes a reader borrowed (Gecko's Append copies a shared
/// buffer out before it grows it; CharacterDataBuffer.cpp, `!mInHeap`).
pub const Data = struct {
    /// Kept by value in CharacterData's own State (runtime.OwnState, the
    /// State's `_embedded`; lane perf2 batch 5, Z7): a node is one block.
    pub const embedded_in_state = true;

    // No allocator copy (lane perf2 batch 6): a block is allocated and freed
    // with the allocator the caller passes - the node's Browser's,
    // runtime.allocatorOf, the one the node was made with.

    /// The data's length in bytes, and whether its bytes are the shared blob's.
    size: Size,

    /// The data's length in UTF-16 code units: the node's length (DOM 4.2).
    units: u32,

    /// The bytes themselves (`in_word`), or where they are.
    word: Word,

    /// Bytes kept in the word itself.
    pub const inline_capacity = 8;

    /// The longest data the 31 bits of `Size.bytes` hold: 2 GiB less one.
    /// V8's longest string, 2^29 - 24 code units, is at most 3 bytes a code
    /// unit in WTF-8 (1.5 GiB); only a splice past it fails, as Gecko's
    /// Append fails past NS_MAX_CHARACTER_DATA_BUFFER_LENGTH.
    pub const max_bytes: usize = std.math.maxInt(u31);

    /// Gecko's CharacterDataBuffer::FragmentBits keeps the same word: its
    /// `mInHeap` bit beside a 29-bit `mLength`.
    pub const Size = packed struct(u32) {
        bytes: u31,
        /// The bytes are a slice of the shared whitespace blob: never freed.
        /// Set only when `bytes` is over `inline_capacity`.
        shared: bool,
    };

    /// `extern`, so it has no hidden safety tag in safe builds (lesson
    /// testing-a-std-safety-field-moves-size-pins-in-safe-builds): 8 bytes
    /// in every mode.
    pub const Word = extern union {
        bytes: [inline_capacity]u8,
        ptr: [*]const u8,
    };

    pub const Storage = enum {
        /// In `word.bytes`: up to `inline_capacity` bytes.
        in_word,
        /// A slice of the static whitespace blob (`sharedWhitespace`).
        shared,
        /// A block of the node's allocator, `size.bytes` long.
        heap,
    };

    /// Empty data. Every call below that can allocate or free takes the
    /// allocator the data's block lives in: the same one, every time.
    pub const empty: Data = .{
        .size = .{ .bytes = 0, .shared = false },
        .units = 0,
        .word = .{ .bytes = @splat(0) },
    };

    pub fn deinit(self: *Data, allocator: std.mem.Allocator) void {
        self.freeBytes(allocator);
        self.* = .empty;
    }

    /// Where the bytes are.
    pub fn storage(self: *const Data) Storage {
        if (self.size.bytes <= inline_capacity) return .in_word;
        return if (self.size.shared) .shared else .heap;
    }

    /// Let the storage of `self` - a copy of what the node held - go: the
    /// one free path, so neither the blob nor the word is ever freed.
    fn freeBytes(self: *const Data, allocator: std.mem.Allocator) void {
        switch (self.storage()) {
            .in_word, .shared => {},
            .heap => allocator.free(self.word.ptr[0..self.size.bytes]),
        }
    }

    /// The data's bytes (WTF-8), borrowed until the next change.
    pub fn getData(self: *const Data) []const u8 {
        const len = self.size.bytes;
        if (len <= inline_capacity) return self.word.bytes[0..len];
        return self.word.ptr[0..len];
    }

    /// The node's length: the data's length in UTF-16 code units.
    pub fn getLength(self: *const Data) u32 {
        return self.units;
    }

    /// The data's length in bytes.
    pub fn byteLength(self: *const Data) u32 {
        return self.size.bytes;
    }

    /// Where code unit `unit` (at most the length) falls in the bytes.
    pub fn position(self: *const Data, unit: u32) infra.wtf8.Position {
        const byte_len = self.size.bytes;
        // ASCII: every code unit is one byte.
        if (self.units == byte_len) return .{ .byte = unit };
        if (unit == 0) return .{ .byte = 0 };
        if (unit >= self.units) return .{ .byte = byte_len };
        return infra.wtf8.positionOfCodeUnit(self.getData(), unit);
    }

    /// Set data: in the word for small text, the shared blob for its
    /// whitespace, a block for the rest.
    pub fn setData(self: *Data, allocator: std.mem.Allocator, data: []const u8) !void {
        if (data.len > max_bytes) return error.OutOfMemory;
        const units: u32 = @intCast(infra.wtf8.codeUnitLength(data));
        // The storage given up, let go once the new data is in place: `data`
        // may be this node's own bytes.
        const old = self.*;
        if (data.len <= inline_capacity) {
            var bytes: [inline_capacity]u8 = @splat(0);
            @memcpy(bytes[0..data.len], data);
            self.word = .{ .bytes = bytes };
            self.size = .{ .bytes = @intCast(data.len), .shared = false };
        } else if (sharedWhitespace(data)) |shared| {
            self.word = .{ .ptr = shared };
            self.size = .{ .bytes = @intCast(data.len), .shared = true };
        } else {
            const block = try allocator.dupe(u8, data);
            self.word = .{ .ptr = block.ptr };
            self.size = .{ .bytes = @intCast(data.len), .shared = false };
        }
        self.units = units;
        old.freeBytes(allocator);
    }

    /// Replace `count_param` code units at `offset` with `data` (DOM replace
    /// data steps 2-3 and 5-7) - the core of replaceData, insertData,
    /// deleteData and appendData. Offsets are code units.
    pub fn replaceData(self: *Data, allocator: std.mem.Allocator, offset: u32, count_param: u32, data: []const u8) !void {
        try self.replaceDataUnits(allocator, offset, count_param, data, @intCast(infra.wtf8.codeUnitLength(data)));
    }

    /// replaceData with `data`'s length in code units already counted.
    pub fn replaceDataUnits(self: *Data, allocator: std.mem.Allocator, offset: u32, count_param: u32, data: []const u8, data_units: u32) !void {
        const length = self.units;
        if (offset > length) return error.IndexSizeError;

        // Clamp count to available length. Compared as a difference: offset
        // plus a count near 2^32 - `deleteData(1, 0xFFFFFFFF)` - wraps.
        const count = @min(count_param, length - offset);

        // Steps 5-7 as one splice: a pair cut at either end splits into its
        // surrogates, and halves that meet join (infra.wtf8.Pieces).
        const start = self.position(offset);
        const end = if (count == 0) start else self.position(offset + count);
        var pieces: infra.wtf8.Pieces = .{};
        pieces.splice(self.getData(), start, end, data);
        const new_len = pieces.joinedLength();
        if (new_len > max_bytes) return error.OutOfMemory;

        // The pieces read the current bytes, wherever they are: the new data
        // is written to new storage before the old is let go.
        const old = self.*;
        if (new_len <= inline_capacity) {
            var bytes: [inline_capacity]u8 = @splat(0);
            pieces.writeJoined(bytes[0..new_len]);
            self.word = .{ .bytes = bytes };
            self.size = .{ .bytes = @intCast(new_len), .shared = false };
        } else if (new_len <= shared_max_bytes) {
            // Short enough to have the shared shape: joined on the stack
            // first, so whitespace takes no block.
            var joined: [shared_max_bytes]u8 = undefined;
            pieces.writeJoined(joined[0..new_len]);
            if (sharedWhitespace(joined[0..new_len])) |shared| {
                self.word = .{ .ptr = shared };
                self.size = .{ .bytes = @intCast(new_len), .shared = true };
            } else {
                const block = try allocator.dupe(u8, joined[0..new_len]);
                self.word = .{ .ptr = block.ptr };
                self.size = .{ .bytes = @intCast(new_len), .shared = false };
            }
        } else {
            const block = try allocator.alloc(u8, new_len);
            pieces.writeJoined(block);
            self.word = .{ .ptr = block.ptr };
            self.size = .{ .bytes = @intCast(new_len), .shared = false };
        }
        self.units = length - count + data_units;
        old.freeBytes(allocator);
    }

    /// The code units from `offset` to `offset + count` (count already
    /// clamped to the length), in a new allocation. OWNED.
    pub fn substring(self: *const Data, allocator: std.mem.Allocator, offset: u32, count: u32) ![]u8 {
        const start = self.position(offset);
        const end = if (count == 0) start else self.position(offset + count);
        var pieces: infra.wtf8.Pieces = .{};
        pieces.substring(self.getData(), start, end);
        return pieces.toOwned(allocator);
    }
};

// The data is 16 bytes in every build mode: two u32 lengths and one word.
comptime {
    std.debug.assert(@sizeOf(Data) == 16);
    std.debug.assert(@alignOf(Data) == 8);
}

// ============================================================================
// The shared whitespace
// ============================================================================

/// Gecko's shared shape (dom/base/CharacterDataBuffer.cpp at 7d1680b9a0d4,
/// TEXTFRAG_MAX_NEWLINES and TEXTFRAG_WHITE_AFTER_NEWLINE): an optional
/// space, up to 7 newlines, then up to 50 spaces or up to 50 tabs. It holds
/// Blink's NewlineThenWhitespaceStringsTable (a newline, then up to 30
/// spaces: platform/wtf/text/wtf_string.h, kTableSize 32, at 3ad43ecbc857).
pub const shared_max_newlines = 7;
pub const shared_max_white = 50;
/// The longest shared data: 58 bytes.
pub const shared_max_bytes = 1 + shared_max_newlines + shared_max_white;

/// Gecko's sSpaceSharedString and sTabSharedString as ONE `const` blob, made
/// at compile time: row [w][n] is a space, `n` newlines, then the white
/// character `w` (0 a space, 1 a tab) to the row's end - Gecko's row is
/// `1 + n + 50` long; the extra whites past 50 are never handed out. In
/// read-only memory: never written, never freed, the same for every Browser
/// on every thread, so it is no global state (AGENTS.md "Global state").
const shared_rows: [2][shared_max_newlines + 1][shared_max_bytes]u8 = blk: {
    @setEvalBranchQuota(10_000);
    var rows: [2][shared_max_newlines + 1][shared_max_bytes]u8 = undefined;
    for (&rows, [_]u8{ ' ', '\t' }) |*kind, white| {
        for (kind, 0..) |*row, n| {
            row[0] = ' ';
            for (row[1..][0..n]) |*c| c.* = '\n';
            for (row[1 + n ..]) |*c| c.* = white;
        }
    }
    break :blk rows;
};

/// Where `data` is in the shared blob, when it is over `inline_capacity`
/// bytes and has Gecko's shared shape; null otherwise. The steps of Gecko's
/// CharacterDataBuffer::SetTo, "Check if we can use a shared string", over
/// WTF-8 bytes (every character of the shape is ASCII, one byte each).
fn sharedWhitespace(data: []const u8) ?[*]const u8 {
    if (data.len <= Data.inline_capacity or data.len > shared_max_bytes) return null;
    // "if (firstChar == ' ') ++ucp;"
    const lead = data[0] == ' ';
    var i: usize = @intFromBool(lead);
    // "while (ucp < uend && *ucp == '\n') ++ucp;"
    const newline_start = i;
    while (i < data.len and data[i] == '\n') i += 1;
    const newline_count = i - newline_start;
    // "char16_t space = ucp < uend && *ucp == '\t' ? '\t' : ' ';"
    const white: u8 = if (i < data.len and data[i] == '\t') '\t' else ' ';
    const white_start = i;
    while (i < data.len and data[i] == white) i += 1;
    // "if (ucp == uend && endNewLine - start <= TEXTFRAG_MAX_NEWLINES &&
    //  ucp - endNewLine <= TEXTFRAG_WHITE_AFTER_NEWLINE)"
    if (i != data.len or newline_count > shared_max_newlines or i - white_start > shared_max_white) return null;
    const row: [*]const u8 = &shared_rows[@intFromBool(white == '\t')][newline_count];
    // "If we didn't find a space in the beginning, skip it now."
    return if (lead) row else row + 1;
}
