//! HTML Parser Tokens
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The output of the tokenization step is a series of zero or more of the
//! following tokens: DOCTYPE, start tag, end tag, comment, character, end-of-file.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

/// An attribute on a start or end tag token.
///
/// HTML Standard §13.2.5:
/// "Start and end tag tokens have a tag name, a self-closing flag, and a list
/// of attributes, each of which has a name and a value."
pub const Attribute = struct {
    /// Attribute name.
    name: infra.List(u8),

    /// Attribute value.
    value: infra.List(u8),

    /// Allocator for memory management.
    allocator: Allocator,

    /// Initialize a new attribute.
    pub fn init(allocator: Allocator) Attribute {
        return Attribute{
            .name = infra.List(u8).init(allocator),
            .value = infra.List(u8).init(allocator),
            .allocator = allocator,
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
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.name.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.name.appendSlice(buf[0..len]);
    }

    /// Append a character to the value.
    pub fn appendToValue(self: *Attribute, char: u8) !void {
        try self.value.append(char);
    }

    /// Append a Unicode codepoint to the value (UTF-8 encoded).
    pub fn appendCodepointToValue(self: *Attribute, codepoint: u21) !void {
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.value.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.value.appendSlice(buf[0..len]);
    }
};

/// DOCTYPE token.
///
/// HTML Standard §13.2.5:
/// "DOCTYPE tokens have a name, a public identifier, a system identifier, and
/// a force-quirks flag."
pub const DoctypeToken = struct {
    /// DOCTYPE name (e.g., "html"), or null if missing.
    name: ?infra.List(u8),

    /// Public identifier, or null if missing.
    public_identifier: ?infra.List(u8),

    /// System identifier, or null if missing.
    system_identifier: ?infra.List(u8),

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
            self.name = infra.List(u8).init(self.allocator);
        }
    }

    /// Append to the name.
    pub fn appendToName(self: *DoctypeToken, char: u8) !void {
        if (self.name == null) {
            self.name = infra.List(u8).init(self.allocator);
        }
        try self.name.?.append(char);
    }

    /// Append a Unicode codepoint to the name (UTF-8 encoded).
    pub fn appendCodepointToName(self: *DoctypeToken, codepoint: u21) !void {
        if (self.name == null) {
            self.name = infra.List(u8).init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.name.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.name.?.appendSlice(buf[0..len]);
    }

    /// Get the name as a string slice.
    pub fn getName(self: *const DoctypeToken) ?[]const u8 {
        if (self.name) |n| return n.toSlice() else return null;
    }

    /// Start the public identifier buffer.
    pub fn startPublicIdentifier(self: *DoctypeToken) void {
        if (self.public_identifier == null) {
            self.public_identifier = infra.List(u8).init(self.allocator);
        }
    }

    /// Append to the public identifier.
    pub fn appendToPublicIdentifier(self: *DoctypeToken, char: u8) !void {
        if (self.public_identifier == null) {
            self.public_identifier = infra.List(u8).init(self.allocator);
        }
        try self.public_identifier.?.append(char);
    }

    /// Append a Unicode codepoint to the public identifier (UTF-8 encoded).
    pub fn appendCodepointToPublicIdentifier(self: *DoctypeToken, codepoint: u21) !void {
        if (self.public_identifier == null) {
            self.public_identifier = infra.List(u8).init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.public_identifier.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.public_identifier.?.appendSlice(buf[0..len]);
    }

    /// Get the public identifier as a string slice.
    pub fn getPublicIdentifier(self: *const DoctypeToken) ?[]const u8 {
        if (self.public_identifier) |p| return p.toSlice() else return null;
    }

    /// Start the system identifier buffer.
    pub fn startSystemIdentifier(self: *DoctypeToken) void {
        if (self.system_identifier == null) {
            self.system_identifier = infra.List(u8).init(self.allocator);
        }
    }

    /// Append to the system identifier.
    pub fn appendToSystemIdentifier(self: *DoctypeToken, char: u8) !void {
        if (self.system_identifier == null) {
            self.system_identifier = infra.List(u8).init(self.allocator);
        }
        try self.system_identifier.?.append(char);
    }

    /// Append a Unicode codepoint to the system identifier (UTF-8 encoded).
    pub fn appendCodepointToSystemIdentifier(self: *DoctypeToken, codepoint: u21) !void {
        if (self.system_identifier == null) {
            self.system_identifier = infra.List(u8).init(self.allocator);
        }
        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            // Invalid codepoint, use replacement character (already UTF-8 encoded)
            try self.system_identifier.?.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.system_identifier.?.appendSlice(buf[0..len]);
    }

    /// Get the system identifier as a string slice.
    pub fn getSystemIdentifier(self: *const DoctypeToken) ?[]const u8 {
        if (self.system_identifier) |s| return s.toSlice() else return null;
    }
};

/// Start or end tag token.
///
/// HTML Standard §13.2.5:
/// "Start and end tag tokens have a tag name, a self-closing flag, and a list
/// of attributes, each of which has a name and a value."
pub const TagToken = struct {
    /// Tag name.
    tag_name: infra.List(u8),

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
    attributes: infra.List(Attribute),

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
            .tag_name = infra.List(u8).init(allocator),
            .is_end_tag = is_end_tag,
            .self_closing = false,
            .attributes = infra.List(Attribute).init(allocator),
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
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.tag_name.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.tag_name.appendSlice(buf[0..len]);
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
            var is_duplicate = false;
            const slice = self.attributes.toSlice();
            for (slice) |existing| {
                if (std.mem.eql(u8, existing.name.toSlice(), name)) {
                    is_duplicate = true;
                    break;
                }
            }

            if (!is_duplicate and name.len > 0) {
                try self.attributes.append(attr);
            } else {
                // Discard duplicate or empty attribute
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
pub const CommentToken = struct {
    /// Comment data.
    data: infra.List(u8),

    /// Allocator.
    allocator: Allocator,

    /// Initialize a new comment token.
    pub fn init(allocator: Allocator) CommentToken {
        return CommentToken{
            .data = infra.List(u8).init(allocator),
            .allocator = allocator,
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
        const len = std.unicode.utf8Encode(codepoint, &buf) catch {
            try self.data.appendSlice(&[_]u8{ 0xEF, 0xBF, 0xBD });
            return;
        };
        try self.data.appendSlice(buf[0..len]);
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
