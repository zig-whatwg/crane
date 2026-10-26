//! CSS Shadow 1 §5: part names and the exportparts attribute microsyntax.
//! Names borrow their input text. These helpers are synchronous transforms,
//! with no DOM state, selector matching, or retained element pointers.
const std = @import("std");
const Allocator = std.mem.Allocator;

// HTML space characters, not all ASCII whitespace: U+000B is part of a name.
const spaces = " \t\n\r\x0c";
const token_delimiters = spaces ++ ":";

pub const Mapping = struct {
    inner: union(enum) {
        part: []const u8,
        /// §5.3's pseudo candidate. The matching layer decides whether it
        /// names a fully styleable pseudo-element; it is never a part name.
        pseudo: []const u8,
    },
    outer: []const u8,
};

/// §5.6.2 steps 2–4: split on commas, parse each mapping, and ignore errors.
/// Every returned string borrows the input, with its original case/escapes.
pub const MappingIterator = struct {
    remaining: ?[]const u8,

    pub fn init(text: []const u8) MappingIterator {
        return .{ .remaining = text };
    }

    pub fn next(self: *MappingIterator) ?Mapping {
        while (self.remaining) |text| {
            const end = std.mem.indexOfScalar(u8, text, ',') orelse text.len;
            self.remaining = if (end < text.len) text[end + 1 ..] else null;
            if (parseMapping(text[0..end])) |mapping| return mapping;
        }
        return null;
    }
};

fn parseMapping(text: []const u8) ?Mapping {
    // §5.6.1 steps 3–7, extended by §5.3's `::ident : outerIdent` form.
    var rest = std.mem.trim(u8, text, spaces);
    const pseudo = std.mem.startsWith(u8, rest, "::");
    if (pseudo) rest = rest[2..];
    const first_end = std.mem.indexOfAny(u8, rest, token_delimiters) orelse rest.len;
    if (first_end == 0) return null;
    const first = rest[0..first_end];
    const inner: @FieldType(Mapping, "inner") = if (pseudo) .{ .pseudo = first } else .{ .part = first };
    rest = std.mem.trimStart(u8, rest[first_end..], spaces);
    if (rest.len == 0) return if (pseudo) null else .{ .inner = inner, .outer = first };

    // Steps 8–15: exactly one separator, a nonempty second token, and EOF.
    if (rest[0] != ':') return null;
    rest = std.mem.trimStart(u8, rest[1..], spaces);
    const second_end = std.mem.indexOfAny(u8, rest, token_delimiters) orelse rest.len;
    if (second_end == 0 or std.mem.trim(u8, rest[second_end..], spaces).len != 0) return null;
    return .{ .inner = inner, .outer = rest[0..second_end] };
}

/// The list owns its allocations; strings borrow the input attributes.
/// A NameBuffer's allocator can supply the common small set on the stack.
pub const Names = std.ArrayList([]const u8);
pub const NameBuffer = std.heap.StackFallbackAllocator(4 * @sizeOf([]const u8));

/// Keep this buffer in the caller's scope. Call get() exactly once and do
/// not move the buffer while its allocator or any returned list is in use.
pub fn nameBuffer(allocator: Allocator) NameBuffer {
    return std.heap.stackFallback(4 * @sizeOf([]const u8), allocator);
}

/// §5.2: an ordered set of case-sensitive tokens separated by HTML spaces.
pub fn fromAttribute(allocator: Allocator, text: []const u8) Allocator.Error!Names {
    var names: Names = .empty;
    errdefer names.deinit(allocator);
    var tokens = std.mem.tokenizeAny(u8, text, spaces);
    while (tokens.next()) |name| try appendUnique(allocator, &names, name);
    return names;
}

/// §5.1's forwarded part-name mapping, for one shadow boundary. All matching
/// entries contribute to the union, and unmatched names disappear. Repeat
/// this transform at successive boundaries (Blink's PartNames design).
/// Result strings borrow `mappings`, not the incoming set's container.
pub fn forward(allocator: Allocator, names: []const []const u8, mappings: []const u8) Allocator.Error!Names {
    var result: Names = .empty;
    errdefer result.deinit(allocator);
    if (names.len == 0) return result;
    var iterator = MappingIterator.init(mappings);
    while (iterator.next()) |mapping| {
        switch (mapping.inner) {
            .part => |inner| if (contains(names, inner)) try appendUnique(allocator, &result, mapping.outer),
            .pseudo => {}, // A different source, consumed by the pseudo matcher.
        }
    }
    return result;
}

fn contains(names: []const []const u8, name: []const u8) bool {
    for (names) |existing| if (std.mem.eql(u8, existing, name)) return true;
    return false;
}

fn appendUnique(allocator: Allocator, names: *Names, name: []const u8) Allocator.Error!void {
    if (contains(names.items, name)) return;
    // ArrayList's default growth exceeds the caller's four-name buffer.
    // Reserve exactly that initial capacity; later growth uses std's policy.
    if (names.capacity == 0) try names.ensureTotalCapacityPrecise(allocator, 4);
    try names.append(allocator, name);
}
