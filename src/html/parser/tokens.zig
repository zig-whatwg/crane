//! HTML Parser Tokens
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The output of the tokenization step is a series of zero or more of the
//! following tokens: DOCTYPE, start tag, end tag, comment, processing
//! instruction, character, end-of-file.
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

    /// Storage union - inline or heap allocated
    storage: Storage,
    allocator: Allocator,
    /// Explicit flag to track storage mode (avoids unsafe union field access)
    is_heap: bool,

    const Storage = union {
        inline_data: InlineData,
        heap_data: HeapData,
    };

    const InlineData = struct {
        data: [INLINE_CAPACITY]u8,
        len: u8,
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
                    .len = 0,
                },
            },
            .allocator = allocator,
            .is_heap = false,
        };
    }

    /// Free heap memory if allocated.
    pub fn deinit(self: *SmallString) void {
        if (self.is_heap) {
            const heap = self.storage.heap_data;
            if (heap.capacity > 0) {
                self.allocator.free(heap.ptr[0..heap.capacity]);
            }
        }
    }

    /// Check if currently in heap mode.
    inline fn isHeapMode(self: *const SmallString) bool {
        return self.is_heap;
    }

    /// Get the current length.
    pub fn len(self: *const SmallString) usize {
        if (self.is_heap) {
            return self.storage.heap_data.len;
        } else {
            return self.storage.inline_data.len;
        }
    }

    /// Get the string as a slice.
    pub fn toSlice(self: *const SmallString) []const u8 {
        if (self.is_heap) {
            const heap = self.storage.heap_data;
            return heap.ptr[0..heap.len];
        } else {
            const inline_len = self.storage.inline_data.len;
            return self.storage.inline_data.data[0..inline_len];
        }
    }

    /// Append a single byte.
    pub fn append(self: *SmallString, byte: u8) !void {
        if (self.is_heap) {
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
            const current_len = self.storage.inline_data.len;
            if (current_len < INLINE_CAPACITY) {
                // Fits in inline storage
                self.storage.inline_data.data[current_len] = byte;
                self.storage.inline_data.len = current_len + 1;
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

        if (self.is_heap) {
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
            const current_len = self.storage.inline_data.len;
            const new_len = current_len + slice.len;
            if (new_len <= INLINE_CAPACITY) {
                // Fits in inline storage
                @memcpy(self.storage.inline_data.data[current_len..][0..slice.len], slice);
                self.storage.inline_data.len = @intCast(new_len);
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
        const current_len = self.storage.inline_data.len;
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
        self.is_heap = true;
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

    /// Whether an attribute was dropped from this token as a duplicate - a
    /// duplicate-attribute parse error during tokenization - which the
    /// element made for it keeps: CSP 6.7.3.1 "Is element nonceable?" step 3
    /// asks it (whatwg/html#3257 is the hook HTML has yet to name; Blink's
    /// Element::HasDuplicateAttribute, set by the parser, answers it).
    had_duplicate_attribute: bool = false,

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
            .had_duplicate_attribute = false,
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
            // The keys are copies this token made - see rememberAttributeName.
            var keys = names.keyIterator();
            while (keys.next()) |key| {
                self.allocator.free(key.*);
            }
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
                // Use hash set for larger attribute counts.
                //
                // The keys are OWNED copies, not slices into an Attribute. A
                // `SmallString` keeps up to 31 bytes INLINE, so `toSlice()`
                // returns a pointer into the struct it was called on - and
                // every Attribute reachable here is a temporary: `attr` above
                // is the `if (self.current_attribute) |attr|` payload copy,
                // and a `for (slice) |existing|` binding is a stack slot the
                // next iteration reuses. Seeding the set from those handed it
                // N keys all aliasing ONE address, so the next rehash found
                // them all equal and `grow`'s `putAssumeCapacityNoClobber`
                // asserted - `panic: reached unreachable code`, taking the
                // process with it on any tag with seven or more attributes.
                // `infra.List.append` reallocates, so a pointer into
                // `self.attributes` is no more stable. Duping is the only
                // answer that survives both.
                if (self.attribute_names == null) {
                    // Initialize hash set and populate with existing attributes
                    self.attribute_names = std.StringHashMapUnmanaged(void){};
                    const slice = self.attributes.toSlice();
                    for (slice) |*existing| {
                        try self.rememberAttributeName(existing.name.toSlice());
                    }
                }

                // Check hash set for duplicate
                if (self.attribute_names.?.contains(name)) {
                    is_duplicate = true;
                } else {
                    // Add to hash set
                    try self.rememberAttributeName(name);
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
                // Discard duplicate attribute ("the new attribute must be
                // removed from the token"), and remember the parse error.
                self.had_duplicate_attribute = true;
                var mutable_attr = attr;
                mutable_attr.deinit();
            }
            self.current_attribute = null;
        }
    }

    /// Record `name` in the duplicate-detection set, taking a copy of it.
    ///
    /// The copy is what makes the key outlive the Attribute it came from; see
    /// the note in `finishCurrentAttribute`. `deinit` frees every key.
    fn rememberAttributeName(self: *TagToken, name: []const u8) !void {
        const gop = try self.attribute_names.?.getOrPut(self.allocator, name);
        if (gop.found_existing) return;

        // getOrPut stored the BORROWED slice as the key. Replace it with a copy
        // before anything can observe it, and take the entry back out if the
        // copy fails - leaving the borrowed key in place would reintroduce the
        // dangling key this function exists to prevent.
        gop.key_ptr.* = self.allocator.dupe(u8, name) catch |err| {
            _ = self.attribute_names.?.remove(name);
            return err;
        };
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

/// Processing instruction token.
///
/// HTML Standard §13.2.5.73, processing instruction target state: "Create a
/// processing instruction token whose target is target and data is the empty
/// string." (13.2.5's list of token kinds does not name this one yet; the
/// states that make and fill it are its definition.)
pub const ProcessingInstructionToken = struct {
    /// The target: ASCII alphanumerics, "-" and "_", as the input had them.
    target: SmallString,
    /// The data (uses SmallString - 31 bytes inline, heap for longer).
    data: SmallString,

    /// A token whose target is `target` and whose data is the empty string.
    pub fn init(allocator: Allocator, target: []const u8) !ProcessingInstructionToken {
        var token = ProcessingInstructionToken{
            .target = SmallString.init(allocator),
            .data = SmallString.init(allocator),
        };
        errdefer token.deinit();
        try token.target.appendSlice(target);
        return token;
    }

    /// Free all resources.
    pub fn deinit(self: *ProcessingInstructionToken) void {
        self.target.deinit();
        self.data.deinit();
    }

    /// Append a Unicode codepoint to the data (UTF-8 encoded).
    pub fn appendCodepointToData(self: *ProcessingInstructionToken, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const length = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.data.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.data.appendSlice(buf[0..length]);
    }

    pub fn getTarget(self: *const ProcessingInstructionToken) []const u8 {
        return self.target.toSlice();
    }

    pub fn getData(self: *const ProcessingInstructionToken) []const u8 {
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

    /// Processing instruction token.
    processing_instruction: ProcessingInstructionToken,

    /// Character token.
    character: u21,

    /// Text run token - batch of consecutive text characters.
    /// Performance optimization: instead of emitting individual character tokens,
    /// the tokenizer batches runs of text into a single token with a slice.
    /// The slice points directly into the input buffer (zero-copy).
    text_run: TextRun,

    /// End-of-file token.
    eof,

    /// Free resources associated with this token.
    pub fn deinit(self: *Token) void {
        switch (self.*) {
            .doctype => |*d| d.deinit(),
            .start_tag, .end_tag => |*t| t.deinit(),
            .comment => |*c| c.deinit(),
            .processing_instruction => |*p| p.deinit(),
            .character, .eof, .text_run => {},
        }
    }
};

/// A batch of text characters, stored as a slice into the input.
/// This is a zero-copy optimization - the slice points directly to the input buffer.
///
/// Its first character is never whitespace (the tokenizer emits whitespace
/// that would begin a run as a character token), so an insertion mode that
/// sends "anything else" elsewhere may take the run for one of those; what
/// follows it is processed in the mode it lands in. Characters after the
/// first can be whitespace.
pub const TextRun = struct {
    /// Slice of UTF-8 bytes from the input buffer.
    /// Valid for the lifetime of the tokenizer's input.
    data: []const u8,
};

// =============================================================================
// SmallString Tests
// =============================================================================

// =============================================================================
// Attribute Tests
// =============================================================================

test "TagToken - the duplicate-attribute flag is set by a duplicate only, past the hash-set threshold too" {
    const allocator = std.testing.allocator;
    var tag = TagToken.init(allocator, false);
    defer tag.deinit();
    // Six distinct names, then a seventh repeating the first: the hash set
    // path (more than four attributes).
    for ("abcdefa", 0..) |name, index| {
        try tag.startNewAttribute();
        try tag.appendToAttributeName(name);
        if (index < 6) try std.testing.expect(!tag.had_duplicate_attribute);
    }
    try tag.finishCurrentAttribute();
    try std.testing.expectEqual(@as(usize, 6), tag.attributes.len);
    try std.testing.expect(tag.had_duplicate_attribute);

    var clean = TagToken.init(allocator, false);
    defer clean.deinit();
    for ("xy") |name| {
        try clean.startNewAttribute();
        try clean.appendToAttributeName(name);
    }
    try clean.finishCurrentAttribute();
    try std.testing.expect(!clean.had_duplicate_attribute);
}
