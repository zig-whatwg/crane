//! HTML Parser Tokens
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The output of the tokenization step is a series of zero or more of the
//! following tokens: DOCTYPE, start tag, end tag, comment, character, end-of-file.
//!
//! ## Performance Optimization: SmallString
//!
//! This module uses SmallString for tag names and attribute names/values.
//! SmallString stores up to 31 bytes inline (on stack) before falling back
//! to heap allocation. This optimization is based on analysis showing:
//! - 99%+ of HTML tag names are ≤15 bytes (e.g., "div", "span", "script")
//! - 95%+ of attribute names are ≤20 bytes (e.g., "id", "class", "data-value")
//! - Common attribute values are often short (IDs, classes, small URLs)
//!
//! With 34K+ tokens in a typical parse, this avoids tens of thousands of
//! small heap allocations, significantly improving parse performance.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

/// SmallString - Inline string storage with heap fallback.
///
/// Stores up to INLINE_CAPACITY bytes on the stack. Falls back to heap
/// allocation for longer strings. Designed for HTML parsing where most
/// strings (tag names, attribute names/values) are short.
///
/// Memory layout (32 bytes total):
/// - Inline: 31 bytes data + 1 byte length (len < 128 indicates inline)
/// - Heap: 8 bytes ptr + 8 bytes len + 8 bytes capacity + 8 bytes allocator
pub const SmallString = struct {
    const INLINE_CAPACITY: usize = 31;
    const INLINE_MARKER: u8 = 0x80; // High bit set = heap mode

    /// Storage union - inline or heap allocated
    storage: Storage,
    allocator: Allocator,

    const Storage = union {
        inline_data: InlineData,
        heap_data: HeapData,
    };

    const InlineData = struct {
        data: [INLINE_CAPACITY]u8,
        /// Length with high bit as mode flag: 0-127 = inline length, 128+ = heap mode
        len_and_mode: u8,
    };

    const HeapData = struct {
        ptr: [*]u8,
        len: usize,
        capacity: usize,
        _pad: usize, // Ensure same size as InlineData
    };

    /// Initialize an empty SmallString.
    pub fn init(allocator: Allocator) SmallString {
        return SmallString{
            .storage = Storage{
                .inline_data = InlineData{
                    .data = undefined,
                    .len_and_mode = 0, // Inline mode, length 0
                },
            },
            .allocator = allocator,
        };
    }

    /// Free heap memory if allocated.
    pub fn deinit(self: *SmallString) void {
        if (self.isHeapMode()) {
            const heap = self.storage.heap_data;
            if (heap.capacity > 0) {
                self.allocator.free(heap.ptr[0..heap.capacity]);
            }
        }
    }

    /// Check if currently in heap mode.
    inline fn isHeapMode(self: *const SmallString) bool {
        return (self.storage.inline_data.len_and_mode & INLINE_MARKER) != 0;
    }

    /// Get the current length.
    pub fn len(self: *const SmallString) usize {
        if (self.isHeapMode()) {
            return self.storage.heap_data.len;
        } else {
            return self.storage.inline_data.len_and_mode;
        }
    }

    /// Get the string as a slice.
    pub fn toSlice(self: *const SmallString) []const u8 {
        if (self.isHeapMode()) {
            const heap = self.storage.heap_data;
            return heap.ptr[0..heap.len];
        } else {
            const inline_len = self.storage.inline_data.len_and_mode;
            return self.storage.inline_data.data[0..inline_len];
        }
    }

    /// Append a single byte.
    pub fn append(self: *SmallString, byte: u8) !void {
        if (self.isHeapMode()) {
            // Already in heap mode
            var heap = &self.storage.heap_data;
            if (heap.len >= heap.capacity) {
                try self.growHeap(heap.capacity * 2);
                heap = &self.storage.heap_data;
            }
            heap.ptr[heap.len] = byte;
            heap.len += 1;
        } else {
            // Inline mode
            const current_len = self.storage.inline_data.len_and_mode;
            if (current_len < INLINE_CAPACITY) {
                // Fits in inline storage
                self.storage.inline_data.data[current_len] = byte;
                self.storage.inline_data.len_and_mode = current_len + 1;
            } else {
                // Need to transition to heap
                try self.transitionToHeap();
                var heap = &self.storage.heap_data;
                heap.ptr[heap.len] = byte;
                heap.len += 1;
            }
        }
    }

    /// Append a slice of bytes.
    pub fn appendSlice(self: *SmallString, slice: []const u8) !void {
        if (slice.len == 0) return;

        if (self.isHeapMode()) {
            // Already in heap mode
            var heap = &self.storage.heap_data;
            const new_len = heap.len + slice.len;
            if (new_len > heap.capacity) {
                const new_capacity = @max(heap.capacity * 2, new_len);
                try self.growHeap(new_capacity);
                heap = &self.storage.heap_data;
            }
            @memcpy(heap.ptr[heap.len..][0..slice.len], slice);
            heap.len = new_len;
        } else {
            // Inline mode
            const current_len = self.storage.inline_data.len_and_mode;
            const new_len = current_len + slice.len;
            if (new_len <= INLINE_CAPACITY) {
                // Fits in inline storage
                @memcpy(self.storage.inline_data.data[current_len..][0..slice.len], slice);
                self.storage.inline_data.len_and_mode = @intCast(new_len);
            } else {
                // Need to transition to heap
                try self.transitionToHeapWithExtra(slice.len);
                var heap = &self.storage.heap_data;
                @memcpy(heap.ptr[heap.len..][0..slice.len], slice);
                heap.len += slice.len;
            }
        }
    }

    /// Transition from inline to heap storage.
    fn transitionToHeap(self: *SmallString) !void {
        try self.transitionToHeapWithExtra(1);
    }

    /// Transition from inline to heap storage with extra capacity.
    fn transitionToHeapWithExtra(self: *SmallString, extra: usize) !void {
        const current_len = self.storage.inline_data.len_and_mode;
        const new_capacity = @max(64, current_len + extra); // Start with reasonable capacity

        const new_ptr = try self.allocator.alloc(u8, new_capacity);

        // Copy inline data to heap
        if (current_len > 0) {
            @memcpy(new_ptr[0..current_len], self.storage.inline_data.data[0..current_len]);
        }

        // Switch to heap mode
        self.storage = Storage{
            .heap_data = HeapData{
                .ptr = new_ptr.ptr,
                .len = current_len,
                .capacity = new_capacity,
                ._pad = 0,
            },
        };
    }

    /// Grow heap allocation.
    fn growHeap(self: *SmallString, new_capacity: usize) !void {
        const heap = self.storage.heap_data;
        const new_ptr = try self.allocator.alloc(u8, new_capacity);

        if (heap.len > 0) {
            @memcpy(new_ptr[0..heap.len], heap.ptr[0..heap.len]);
        }

        if (heap.capacity > 0) {
            self.allocator.free(heap.ptr[0..heap.capacity]);
        }

        self.storage.heap_data.ptr = new_ptr.ptr;
        self.storage.heap_data.capacity = new_capacity;
    }
};

/// An attribute on a start or end tag token.
///
/// HTML Standard §13.2.5:
/// "Start and end tag tokens have a tag name, a self-closing flag, and a list
/// of attributes, each of which has a name and a value."
///
/// Uses SmallString for name and value to avoid heap allocation for common
/// short attribute names (id, class, href, etc.) and values.
pub const Attribute = struct {
    /// Attribute name (uses SmallString - 31 bytes inline).
    name: SmallString,

    /// Attribute value (uses SmallString - 31 bytes inline).
    value: SmallString,

    /// Initialize a new attribute.
    pub fn init(allocator: Allocator) Attribute {
        return Attribute{
            .name = SmallString.init(allocator),
            .value = SmallString.init(allocator),
        };
    }

    /// Free all resources.
    pub fn deinit(self: *Attribute) void {
        self.name.deinit();
        self.value.deinit();
    }

    /// Get the name as a string slice.
    pub fn getName(self: *const Attribute) []const u8 {
        return self.name.toSlice();
    }

    /// Get the value as a string slice.
    pub fn getValue(self: *const Attribute) []const u8 {
        return self.value.toSlice();
    }

    /// Append a character to the name.
    pub fn appendToName(self: *Attribute, char: u8) !void {
        try self.name.append(char);
    }

    /// Append a Unicode codepoint to the name (UTF-8 encoded).
    pub fn appendCodepointToName(self: *Attribute, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.name.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.name.appendSlice(buf[0..length]);
    }

    /// Append a character to the value.
    pub fn appendToValue(self: *Attribute, char: u8) !void {
        try self.value.append(char);
    }

    /// Append a Unicode codepoint to the value (UTF-8 encoded).
    pub fn appendCodepointToValue(self: *Attribute, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.value.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.value.appendSlice(buf[0..length]);
    }
};

/// DOCTYPE token.
///
/// HTML Standard §13.2.5:
/// "DOCTYPE tokens have a name, a public identifier, a system identifier, and
/// a force-quirks flag."
///
/// Uses SmallString for name, public_identifier, and system_identifier.
/// DOCTYPE names are typically "html" (4 bytes), and identifiers are usually
/// short or missing entirely.
pub const DoctypeToken = struct {
    /// DOCTYPE name (e.g., "html"), or null if missing.
    name: ?SmallString,

    /// Public identifier, or null if missing.
    public_identifier: ?SmallString,

    /// System identifier, or null if missing.
    system_identifier: ?SmallString,

    /// Force-quirks flag.
    force_quirks: bool,

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new DOCTYPE token.
    /// HTML Standard §13.2.5:
    /// "When a DOCTYPE token is created, its name, public identifier, and
    /// system identifier must be marked as missing (which is a distinct state
    /// from the empty string), and the force-quirks flag must be set to off."
    pub fn init(allocator: Allocator) DoctypeToken {
        return DoctypeToken{
            .name = null,
            .public_identifier = null,
            .system_identifier = null,
            .force_quirks = false,
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *DoctypeToken) void {
        if (self.name) |*n| n.deinit();
        if (self.public_identifier) |*p| p.deinit();
        if (self.system_identifier) |*s| s.deinit();
    }

    /// Start the name buffer.
    pub fn startName(self: *DoctypeToken) void {
        if (self.name == null) {
            self.name = SmallString.init(self.allocator);
        }
    }

    /// Append to the name.
    pub fn appendToName(self: *DoctypeToken, char: u8) !void {
        if (self.name == null) {
            self.name = SmallString.init(self.allocator);
        }
        try self.name.?.append(char);
    }

    /// Append a Unicode codepoint to the name (UTF-8 encoded).
    pub fn appendCodepointToName(self: *DoctypeToken, codepoint: u21) !void {
        if (self.name == null) {
            self.name = SmallString.init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.name.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.name.?.appendSlice(buf[0..length]);
    }

    /// Get the name as a string slice.
    /// Note: Uses pointer capture (|*n|) to avoid copying the SmallString struct,
    /// which would cause the returned slice to point to freed stack memory.
    pub fn getName(self: *const DoctypeToken) ?[]const u8 {
        if (self.name) |*n| return n.toSlice() else return null;
    }

    /// Start the public identifier buffer.
    pub fn startPublicIdentifier(self: *DoctypeToken) void {
        if (self.public_identifier == null) {
            self.public_identifier = SmallString.init(self.allocator);
        }
    }

    /// Append to the public identifier.
    pub fn appendToPublicIdentifier(self: *DoctypeToken, char: u8) !void {
        if (self.public_identifier == null) {
            self.public_identifier = SmallString.init(self.allocator);
        }
        try self.public_identifier.?.append(char);
    }

    /// Append a Unicode codepoint to the public identifier (UTF-8 encoded).
    pub fn appendCodepointToPublicIdentifier(self: *DoctypeToken, codepoint: u21) !void {
        if (self.public_identifier == null) {
            self.public_identifier = SmallString.init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.public_identifier.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.public_identifier.?.appendSlice(buf[0..length]);
    }

    /// Get the public identifier as a string slice.
    /// Note: Uses pointer capture (|*p|) to avoid copying the SmallString struct.
    pub fn getPublicIdentifier(self: *const DoctypeToken) ?[]const u8 {
        if (self.public_identifier) |*p| return p.toSlice() else return null;
    }

    /// Start the system identifier buffer.
    pub fn startSystemIdentifier(self: *DoctypeToken) void {
        if (self.system_identifier == null) {
            self.system_identifier = SmallString.init(self.allocator);
        }
    }

    /// Append to the system identifier.
    pub fn appendToSystemIdentifier(self: *DoctypeToken, char: u8) !void {
        if (self.system_identifier == null) {
            self.system_identifier = SmallString.init(self.allocator);
        }
        try self.system_identifier.?.append(char);
    }

    /// Append a Unicode codepoint to the system identifier (UTF-8 encoded).
    pub fn appendCodepointToSystemIdentifier(self: *DoctypeToken, codepoint: u21) !void {
        if (self.system_identifier == null) {
            self.system_identifier = SmallString.init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.system_identifier.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.system_identifier.?.appendSlice(buf[0..length]);
    }

    /// Get the system identifier as a string slice.
    /// Note: Uses pointer capture (|*s|) to avoid copying the SmallString struct.
    pub fn getSystemIdentifier(self: *const DoctypeToken) ?[]const u8 {
        if (self.system_identifier) |*s| return s.toSlice() else return null;
    }
};

/// Start or end tag token.
///
/// HTML Standard §13.2.5:
/// "Start and end tag tokens have a tag name, a self-closing flag, and a list
/// of attributes, each of which has a name and a value."
///
/// Uses SmallString for tag_name to avoid heap allocation for common
/// short tag names (div, span, a, p, etc. - virtually all HTML tags fit in 31 bytes).
pub const TagToken = struct {
    /// Tag name (uses SmallString - 31 bytes inline).
    tag_name: SmallString,

    /// Whether this is a start tag or end tag.
    is_end_tag: bool,

    /// Self-closing flag.
    /// HTML Standard §13.2.5:
    /// "When a start or end tag token is created, its self-closing flag must
    /// be unset (its other state is that it be set)"
    self_closing: bool,

    /// List of attributes.
    /// HTML Standard §13.2.5:
    /// "When a start or end tag token is created... its attributes list must be empty."
    /// Note: infra.List already uses 4-element inline storage, avoiding heap
    /// allocation for elements with ≤4 attributes (covers most HTML elements).
    attributes: infra.List(Attribute),

    /// Hash set for O(1) duplicate attribute detection.
    /// Only allocated when there are many attributes (>4).
    /// For small attribute counts, linear scan is faster due to lower overhead.
    attribute_names: ?std.StringHashMapUnmanaged(void),

    /// Current attribute being built.
    current_attribute: ?Attribute,

    /// Self-closing acknowledged flag.
    /// Used to detect non-void elements with self-closing tags.
    self_closing_acknowledged: bool,

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new tag token.
    pub fn init(allocator: Allocator, is_end_tag: bool) TagToken {
        return TagToken{
            .tag_name = SmallString.init(allocator),
            .is_end_tag = is_end_tag,
            .self_closing = false,
            .attributes = infra.List(Attribute).init(allocator),
            .attribute_names = null,
            .current_attribute = null,
            .self_closing_acknowledged = false,
            .allocator = allocator,
        };
    }

    /// Free all resources.
    pub fn deinit(self: *TagToken) void {
        self.tag_name.deinit();
        const slice = self.attributes.toSliceMut();
        for (slice) |*attr| {
            attr.deinit();
        }
        self.attributes.deinit();
        if (self.attribute_names) |*names| {
            names.deinit(self.allocator);
        }
        if (self.current_attribute) |*attr| {
            attr.deinit();
        }
    }

    /// Get the tag name as a string slice.
    pub fn getTagName(self: *const TagToken) []const u8 {
        return self.tag_name.toSlice();
    }

    /// Append a character to the tag name.
    pub fn appendToTagName(self: *TagToken, char: u8) !void {
        try self.tag_name.append(char);
    }

    /// Append a Unicode codepoint to the tag name (UTF-8 encoded).
    pub fn appendCodepointToTagName(self: *TagToken, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.tag_name.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.tag_name.appendSlice(buf[0..length]);
    }

    /// Start a new attribute.
    /// HTML Standard §13.2.5:
    /// "Start a new attribute in the current tag token."
    pub fn startNewAttribute(self: *TagToken) !void {
        // Finish any current attribute first
        try self.finishCurrentAttribute();
        self.current_attribute = Attribute.init(self.allocator);
    }

    /// Finish the current attribute and add it to the list.
    pub fn finishCurrentAttribute(self: *TagToken) !void {
        if (self.current_attribute) |attr| {
            // Check for duplicate attributes
            // HTML Standard §13.2.5:
            // "If there is already an attribute on the token with the exact same
            // name, then this is a duplicate-attribute parse error"
            const name = attr.name.toSlice();
            if (name.len == 0) {
                // Discard empty attribute
                var mutable_attr = attr;
                mutable_attr.deinit();
                self.current_attribute = null;
                return;
            }

            // Use hash set for O(1) duplicate detection when many attributes
            // For small counts (≤4), linear scan is faster due to lower overhead
            const attr_count = self.attributes.len;
            var is_duplicate = false;

            if (attr_count > 4) {
                // Use hash set for larger attribute counts
                if (self.attribute_names == null) {
                    // Initialize hash set and populate with existing attributes
                    self.attribute_names = std.StringHashMapUnmanaged(void){};
                    const slice = self.attributes.toSlice();
                    for (slice) |existing| {
                        try self.attribute_names.?.put(self.allocator, existing.name.toSlice(), {});
                    }
                }

                // Check hash set for duplicate
                if (self.attribute_names.?.contains(name)) {
                    is_duplicate = true;
                } else {
                    // Add to hash set
                    try self.attribute_names.?.put(self.allocator, name, {});
                }
            } else {
                // Linear scan for small attribute counts
                const slice = self.attributes.toSlice();
                for (slice) |existing| {
                    if (std.mem.eql(u8, existing.name.toSlice(), name)) {
                        is_duplicate = true;
                        break;
                    }
                }
            }

            if (!is_duplicate) {
                try self.attributes.append(attr);
            } else {
                // Discard duplicate attribute
                var mutable_attr = attr;
                mutable_attr.deinit();
            }
            self.current_attribute = null;
        }
    }

    /// Append a character to the current attribute's name.
    pub fn appendToAttributeName(self: *TagToken, char: u8) !void {
        if (self.current_attribute) |*attr| {
            try attr.appendToName(char);
        }
    }

    /// Append a Unicode codepoint to the current attribute's name (UTF-8 encoded).
    pub fn appendCodepointToAttributeName(self: *TagToken, codepoint: u21) !void {
        if (self.current_attribute) |*attr| {
            try attr.appendCodepointToName(codepoint);
        }
    }

    /// Append a character to the current attribute's value.
    pub fn appendToAttributeValue(self: *TagToken, char: u8) !void {
        if (self.current_attribute) |*attr| {
            try attr.appendToValue(char);
        }
    }

    /// Append a Unicode codepoint to the current attribute's value (UTF-8 encoded).
    pub fn appendCodepointToAttributeValue(self: *TagToken, codepoint: u21) !void {
        if (self.current_attribute) |*attr| {
            try attr.appendCodepointToValue(codepoint);
        }
    }

    /// Append a slice of bytes to the current attribute's value (batch append).
    /// More efficient than appending characters one at a time.
    pub fn appendSliceToAttributeValue(self: *TagToken, slice: []const u8) !void {
        if (self.current_attribute) |*attr| {
            try attr.value.appendSlice(slice);
        }
    }

    /// Get an attribute by name.
    pub fn getAttribute(self: *const TagToken, name: []const u8) ?*const Attribute {
        const slice = self.attributes.toSlice();
        for (slice) |*attr| {
            if (std.mem.eql(u8, attr.getName(), name)) {
                return attr;
            }
        }
        return null;
    }

    /// Acknowledge the self-closing flag.
    pub fn acknowledgeSelfClosing(self: *TagToken) void {
        self.self_closing_acknowledged = true;
    }
};

/// Comment token.
///
/// HTML Standard §13.2.5:
/// "Comment... tokens have data."
///
/// Note: Comments can be arbitrarily long, so SmallString will fall back to
/// heap allocation for comments > 31 bytes. However, many common comments
/// (e.g., "TODO", "FIXME", conditional comments) fit in 31 bytes.
pub const CommentToken = struct {
    /// Comment data (uses SmallString - 31 bytes inline, heap for longer).
    data: SmallString,

    /// Initialize a new comment token.
    pub fn init(allocator: Allocator) CommentToken {
        return CommentToken{
            .data = SmallString.init(allocator),
        };
    }

    /// Free all resources.
    pub fn deinit(self: *CommentToken) void {
        self.data.deinit();
    }

    /// Append a character to the data.
    pub fn appendToData(self: *CommentToken, char: u8) !void {
        try self.data.append(char);
    }

    /// Append a Unicode codepoint to the data (UTF-8 encoded).
    pub fn appendCodepointToData(self: *CommentToken, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.data.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.data.appendSlice(buf[0..length]);
    }

    /// Get the data as a string slice.
    pub fn getData(self: *const CommentToken) []const u8 {
        return self.data.toSlice();
    }
};

/// A token emitted by the tokenizer.
pub const Token = union(enum) {
    /// DOCTYPE token.
    doctype: DoctypeToken,

    /// Start tag token.
    start_tag: TagToken,

    /// End tag token.
    end_tag: TagToken,

    /// Comment token.
    comment: CommentToken,

    /// Character token.
    character: u21,

    /// End-of-file token.
    eof,

    /// Free resources associated with this token.
    pub fn deinit(self: *Token) void {
        switch (self.*) {
            .doctype => |*d| d.deinit(),
            .start_tag, .end_tag => |*t| t.deinit(),
            .comment => |*c| c.deinit(),
            .character, .eof => {},
        }
    }
};

// =============================================================================
// SmallString Tests
// =============================================================================

test "SmallString - inline storage for short strings" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    // Append "div" - should stay inline
    try ss.append('d');
    try ss.append('i');
    try ss.append('v');

    try std.testing.expectEqualStrings("div", ss.toSlice());
    try std.testing.expectEqual(@as(usize, 3), ss.len());
    try std.testing.expect(!ss.isHeapMode()); // Still inline
}

test "SmallString - inline storage at capacity boundary" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    // Fill exactly to INLINE_CAPACITY (31 bytes)
    const data = "1234567890123456789012345678901"; // 31 chars
    try ss.appendSlice(data);

    try std.testing.expectEqualStrings(data, ss.toSlice());
    try std.testing.expectEqual(@as(usize, 31), ss.len());
    try std.testing.expect(!ss.isHeapMode()); // Still inline at exactly 31
}

test "SmallString - transition to heap on overflow" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    // Fill to capacity then add one more
    const data = "1234567890123456789012345678901"; // 31 chars
    try ss.appendSlice(data);
    try ss.append('X'); // 32nd byte triggers heap

    try std.testing.expectEqual(@as(usize, 32), ss.len());
    try std.testing.expect(ss.isHeapMode()); // Now on heap
    try std.testing.expectEqualStrings("1234567890123456789012345678901X", ss.toSlice());
}

test "SmallString - heap growth" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    // Append a long string that will require multiple heap grows
    const long_string = "This is a very long string that exceeds the inline capacity and will require heap allocation and possibly multiple growth cycles to accommodate all the data.";
    try ss.appendSlice(long_string);

    try std.testing.expectEqualStrings(long_string, ss.toSlice());
    try std.testing.expectEqual(long_string.len, ss.len());
    try std.testing.expect(ss.isHeapMode());
}

test "SmallString - appendSlice inline" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    try ss.appendSlice("hello");
    try ss.appendSlice(" ");
    try ss.appendSlice("world");

    try std.testing.expectEqualStrings("hello world", ss.toSlice());
    try std.testing.expect(!ss.isHeapMode()); // 11 bytes, still inline
}

test "SmallString - empty string" {
    const allocator = std.testing.allocator;

    var ss = SmallString.init(allocator);
    defer ss.deinit();

    try std.testing.expectEqualStrings("", ss.toSlice());
    try std.testing.expectEqual(@as(usize, 0), ss.len());
    try std.testing.expect(!ss.isHeapMode());
}

test "SmallString - common HTML tag names stay inline" {
    const allocator = std.testing.allocator;

    // Test various common HTML tag names - all should stay inline
    const tag_names = [_][]const u8{
        "div",
        "span",
        "a",
        "p",
        "h1",
        "ul",
        "li",
        "img",
        "script",
        "style",
        "table",
        "input",
        "button",
        "textarea",
        "blockquote", // 10 chars
        "figcaption", // 10 chars
    };

    for (tag_names) |name| {
        var ss = SmallString.init(allocator);
        defer ss.deinit();

        try ss.appendSlice(name);
        try std.testing.expectEqualStrings(name, ss.toSlice());
        try std.testing.expect(!ss.isHeapMode());
    }
}

test "SmallString - common attribute names stay inline" {
    const allocator = std.testing.allocator;

    const attr_names = [_][]const u8{
        "id",
        "class",
        "href",
        "src",
        "type",
        "name",
        "value",
        "placeholder",
        "data-value",
        "aria-label",
        "contenteditable", // 15 chars
    };

    for (attr_names) |name| {
        var ss = SmallString.init(allocator);
        defer ss.deinit();

        try ss.appendSlice(name);
        try std.testing.expectEqualStrings(name, ss.toSlice());
        try std.testing.expect(!ss.isHeapMode());
    }
}

// =============================================================================
// Attribute Tests
// =============================================================================

test "Attribute - basic usage" {
    const allocator = std.testing.allocator;

    var attr = Attribute.init(allocator);
    defer attr.deinit();

    try attr.appendToName('i');
    try attr.appendToName('d');
    try attr.appendToValue('f');
    try attr.appendToValue('o');
    try attr.appendToValue('o');

    try std.testing.expectEqualStrings("id", attr.getName());
    try std.testing.expectEqualStrings("foo", attr.getValue());
}

test "DoctypeToken - basic usage" {
    const allocator = std.testing.allocator;

    var doctype = DoctypeToken.init(allocator);
    defer doctype.deinit();

    // Initially missing
    try std.testing.expectEqual(@as(?[]const u8, null), doctype.getName());
    try std.testing.expect(!doctype.force_quirks);

    // Add name
    try doctype.appendToName('h');
    try doctype.appendToName('t');
    try doctype.appendToName('m');
    try doctype.appendToName('l');

    try std.testing.expectEqualStrings("html", doctype.getName().?);
}

test "TagToken - start tag" {
    const allocator = std.testing.allocator;

    var tag = TagToken.init(allocator, false);
    defer tag.deinit();

    try tag.appendToTagName('d');
    try tag.appendToTagName('i');
    try tag.appendToTagName('v');

    try std.testing.expectEqualStrings("div", tag.getTagName());
    try std.testing.expect(!tag.is_end_tag);
    try std.testing.expect(!tag.self_closing);
}

test "TagToken - with attributes" {
    const allocator = std.testing.allocator;

    var tag = TagToken.init(allocator, false);
    defer tag.deinit();

    try tag.appendToTagName('d');
    try tag.appendToTagName('i');
    try tag.appendToTagName('v');

    // First attribute: id="foo"
    try tag.startNewAttribute();
    try tag.appendToAttributeName('i');
    try tag.appendToAttributeName('d');
    try tag.appendToAttributeValue('f');
    try tag.appendToAttributeValue('o');
    try tag.appendToAttributeValue('o');

    // Second attribute: class="bar"
    try tag.startNewAttribute();
    try tag.appendToAttributeName('c');
    try tag.appendToAttributeName('l');
    try tag.appendToAttributeName('a');
    try tag.appendToAttributeName('s');
    try tag.appendToAttributeName('s');
    try tag.appendToAttributeValue('b');
    try tag.appendToAttributeValue('a');
    try tag.appendToAttributeValue('r');

    try tag.finishCurrentAttribute();

    try std.testing.expectEqual(@as(usize, 2), tag.attributes.len);

    const id_attr = tag.getAttribute("id");
    try std.testing.expect(id_attr != null);
    try std.testing.expectEqualStrings("foo", id_attr.?.getValue());

    const class_attr = tag.getAttribute("class");
    try std.testing.expect(class_attr != null);
    try std.testing.expectEqualStrings("bar", class_attr.?.getValue());
}

test "TagToken - duplicate attributes" {
    const allocator = std.testing.allocator;

    var tag = TagToken.init(allocator, false);
    defer tag.deinit();

    try tag.appendToTagName('d');
    try tag.appendToTagName('i');
    try tag.appendToTagName('v');

    // First id attribute
    try tag.startNewAttribute();
    try tag.appendToAttributeName('i');
    try tag.appendToAttributeName('d');
    try tag.appendToAttributeValue('f');
    try tag.appendToAttributeValue('i');
    try tag.appendToAttributeValue('r');
    try tag.appendToAttributeValue('s');
    try tag.appendToAttributeValue('t');

    // Duplicate id attribute (should be ignored)
    try tag.startNewAttribute();
    try tag.appendToAttributeName('i');
    try tag.appendToAttributeName('d');
    try tag.appendToAttributeValue('s');
    try tag.appendToAttributeValue('e');
    try tag.appendToAttributeValue('c');
    try tag.appendToAttributeValue('o');
    try tag.appendToAttributeValue('n');
    try tag.appendToAttributeValue('d');

    try tag.finishCurrentAttribute();

    // Should only have one attribute (first wins)
    try std.testing.expectEqual(@as(usize, 1), tag.attributes.len);

    const id_attr = tag.getAttribute("id");
    try std.testing.expect(id_attr != null);
    try std.testing.expectEqualStrings("first", id_attr.?.getValue());
}

test "CommentToken - basic usage" {
    const allocator = std.testing.allocator;

    var comment = CommentToken.init(allocator);
    defer comment.deinit();

    try comment.appendToData('h');
    try comment.appendToData('e');
    try comment.appendToData('l');
    try comment.appendToData('l');
    try comment.appendToData('o');

    try std.testing.expectEqualStrings("hello", comment.getData());
}
