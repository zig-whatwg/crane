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
const process_start = @import("process_start.zig");

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");

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
var steps: Hooks = .{};

/// Called by CharacterData's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    process_start.assertInstalling();
    steps.character_data = s;
}

/// `node`'s data, borrowed until it next changes: copy what you keep. Null
/// when `node` is no CharacterData node (or CharacterData installed nothing).
pub fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const s = steps.character_data orelse return null;
    return s.data_of(node);
}

/// Called by ProcessingInstruction's installHooks, once at process start.
pub fn installProcessingInstruction(s: ProcessingInstructionSteps) void {
    process_start.assertInstalling();
    steps.processing_instruction = s;
}

/// Only CharacterData's PI branch calls this; ordinary Text mutations never
/// enter the PI owner or parse any attributes.
pub fn processingInstructionDataChanged(node: *runtime.Instance) void {
    const s = steps.processing_instruction orelse return;
    s.data_changed(node);
}

/// Maximum bytes that can be stored inline (without heap allocation).
/// Most text nodes in typical HTML are short (whitespace, small words); 31
/// keeps the whole state at 64 bytes beside its lengths and heap pointer.
pub const INLINE_TEXT_CAPACITY: usize = 31;

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
/// Small text (up to INLINE_TEXT_CAPACITY bytes) is stored inline.
pub const Data = struct {
    allocator: std.mem.Allocator,

    /// The data's bytes on the heap, or null while they are inline.
    heap: ?[*]u8,

    /// The data's length in bytes (the heap block's size when on the heap).
    byte_len: u32,

    /// The data's length in UTF-16 code units: the node's length (DOM 4.2).
    units: u32,

    /// Inline storage for small text.
    inline_text: [INLINE_TEXT_CAPACITY]u8,

    pub fn init(allocator: std.mem.Allocator) !Data {
        return .{
            .allocator = allocator,
            .heap = null,
            .byte_len = 0,
            .units = 0,
            .inline_text = undefined,
        };
    }

    pub fn deinit(self: *Data) void {
        if (self.heap) |heap| {
            self.allocator.free(heap[0..self.byte_len]);
            self.heap = null;
        }
        self.byte_len = 0;
        self.units = 0;
    }

    /// Check if currently using inline storage
    pub fn isInline(self: *const Data) bool {
        return self.heap == null;
    }

    /// The data's bytes (WTF-8), borrowed until the next change.
    pub fn getData(self: *const Data) []const u8 {
        if (self.heap) |heap| return heap[0..self.byte_len];
        return self.inline_text[0..self.byte_len];
    }

    /// The node's length: the data's length in UTF-16 code units.
    pub fn getLength(self: *const Data) u32 {
        return self.units;
    }

    /// The data's length in bytes.
    pub fn byteLength(self: *const Data) u32 {
        return self.byte_len;
    }

    /// Where code unit `unit` (at most the length) falls in the bytes.
    pub fn position(self: *const Data, unit: u32) infra.wtf8.Position {
        // ASCII: every code unit is one byte.
        if (self.units == self.byte_len) return .{ .byte = unit };
        if (unit == 0) return .{ .byte = 0 };
        if (unit >= self.units) return .{ .byte = self.byte_len };
        return infra.wtf8.positionOfCodeUnit(self.getData(), unit);
    }

    /// Set data - uses inline storage for small text, heap for larger
    pub fn setData(self: *Data, data: []const u8) !void {
        if (data.len > std.math.maxInt(u32)) return error.OutOfMemory;
        const units: u32 = @intCast(infra.wtf8.codeUnitLength(data));
        if (data.len <= INLINE_TEXT_CAPACITY) {
            // Copied before the heap block is freed, and forwards: `data`
            // may be this state's own bytes.
            std.mem.copyForwards(u8, self.inline_text[0..data.len], data);
            if (self.heap) |heap| self.allocator.free(heap[0..self.byte_len]);
            self.heap = null;
        } else {
            const heap = try self.allocator.dupe(u8, data);
            self.deinit();
            self.heap = heap.ptr;
        }
        self.byte_len = @intCast(data.len);
        self.units = units;
    }

    /// Replace `count_param` code units at `offset` with `data` (DOM replace
    /// data steps 2-3 and 5-7) - the core of replaceData, insertData,
    /// deleteData and appendData. Offsets are code units.
    pub fn replaceData(self: *Data, offset: u32, count_param: u32, data: []const u8) !void {
        try self.replaceDataUnits(offset, count_param, data, @intCast(infra.wtf8.codeUnitLength(data)));
    }

    /// replaceData with `data`'s length in code units already counted.
    pub fn replaceDataUnits(self: *Data, offset: u32, count_param: u32, data: []const u8, data_units: u32) !void {
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
        if (new_len > std.math.maxInt(u32)) return error.OutOfMemory;

        if (new_len <= INLINE_TEXT_CAPACITY) {
            // The pieces read the current data, which may be inline.
            var new_inline: [INLINE_TEXT_CAPACITY]u8 = undefined;
            pieces.writeJoined(new_inline[0..new_len]);
            self.deinit();
            @memcpy(self.inline_text[0..new_len], new_inline[0..new_len]);
        } else {
            const new_data = try self.allocator.alloc(u8, new_len);
            pieces.writeJoined(new_data);
            self.deinit();
            self.heap = new_data.ptr;
        }
        self.byte_len = @intCast(new_len);
        self.units = length - count + data_units;
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

// One per CharacterData node: the code-unit count was fitted in beside the
// byte length without growing the state past 64 bytes.
comptime {
    std.debug.assert(@sizeOf(Data) <= 64);
}
