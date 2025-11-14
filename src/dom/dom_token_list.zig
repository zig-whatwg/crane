//! DOMTokenList Implementation (WHATWG DOM Standard §6.1)
//!
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist
//!
//! A DOMTokenList represents a set of space-separated tokens from an attribute value.
//! Most commonly used for element.classList but also supports rel, sandbox, etc.

const std = @import("std");
const infra = @import("infra");
const ElementWithBase = @import("element_with_base.zig").ElementWithBase;
const attribute_algorithms = @import("attribute_algorithms.zig");

/// DOMTokenList manages a set of space-separated tokens
/// Spec: https://dom.spec.whatwg.org/#domtokenlist
pub const DOMTokenList = struct {
    /// Associated element (weak reference)
    element: *ElementWithBase,

    /// Associated attribute's local name
    attribute_local_name: []const u8,

    /// Token set (ordered set with no duplicates)
    /// Spec: "A DOMTokenList object has an associated token set (a set),
    /// which is initially empty."
    token_set: infra.OrderedSet(infra.String),

    allocator: std.mem.Allocator,

    /// Initialize a new DOMTokenList
    /// Spec §6.1: "When a DOMTokenList object is created..."
    pub fn init(
        allocator: std.mem.Allocator,
        element: *ElementWithBase,
        attribute_local_name: []const u8,
    ) !DOMTokenList {
        var self = DOMTokenList{
            .element = element,
            .attribute_local_name = attribute_local_name,
            .token_set = infra.OrderedSet(infra.String).init(allocator),
            .allocator = allocator,
        };

        // Step 3: Let value be the result of getting an attribute value
        // given element and localName
        const attr_value = getAttributeValue(element, attribute_local_name);

        // Step 4: Run the attribute change steps for element, localName,
        // value, value, and null
        if (attr_value.len > 0) {
            try self.parseAndSetTokens(attr_value);
        }

        return self;
    }

    pub fn deinit(self: *DOMTokenList) void {
        // Free all token strings in the set
        var it = self.token_set.iterator();
        while (it.next()) |token| {
            self.allocator.free(token);
        }
        self.token_set.deinit();
    }

    /// Get the number of tokens
    /// Spec §6.1: "The length attribute' getter must return this's token set's size."
    pub fn length(self: *const DOMTokenList) usize {
        return self.token_set.size();
    }

    /// Get token at index
    /// Spec §6.1 lines 6505-6509
    pub fn item(self: *const DOMTokenList, index: usize) ?[]const u8 {
        // Step 1: If index is equal to or greater than this's token set's size,
        // then return null
        if (index >= self.token_set.size()) {
            return null;
        }

        // Step 2: Return this's token set[index]
        // TODO(FIXME): This requires UTF-16 to UTF-8 conversion with allocation
        // Current design has mismatch: internal storage is UTF-16, API expects UTF-8
        // Returning empty string temporarily to allow compilation
        return "";
    }

    /// Check if token is present
    /// Spec §6.1 line 6511
    pub fn contains(self: *const DOMTokenList, token: []const u8) bool {
        // Convert to u16 string for comparison
        const token_u16 = infra.string.utf8ToUtf16(self.allocator, token) catch return false;
        defer self.allocator.free(token_u16);
        return self.token_set.contains(token_u16);
    }

    /// Add tokens to the set
    /// Spec §6.1 lines 6513-6523
    pub fn add(self: *DOMTokenList, tokens: []const []const u8) !void {
        // Step 1: For each token of tokens:
        for (tokens) |token| {
            // Step 1.1: If token is the empty string, throw SyntaxError
            if (token.len == 0) {
                return error.SyntaxError;
            }

            // Step 1.2: If token contains any ASCII whitespace,
            // throw InvalidCharacterError
            if (containsAsciiWhitespace(token)) {
                return error.InvalidCharacterError;
            }
        }

        // Step 2: For each token of tokens, append token to this's token set
        for (tokens) |token| {
            const token_u16 = try infra.string.utf8ToUtf16(self.allocator, token);
            errdefer self.allocator.free(token_u16);

            // append only adds if not already present (ordered set semantics)
            try self.token_set.append(token_u16);
        }

        // Step 3: Run the update steps
        try self.runUpdateSteps();
    }

    /// Remove tokens from the set
    /// Spec §6.1 lines 6525-6535
    pub fn remove(self: *DOMTokenList, tokens: []const []const u8) !void {
        // Step 1: For each token of tokens:
        for (tokens) |token| {
            // Step 1.1: If token is the empty string, throw SyntaxError
            if (token.len == 0) {
                return error.SyntaxError;
            }

            // Step 1.2: If token contains any ASCII whitespace,
            // throw InvalidCharacterError
            if (containsAsciiWhitespace(token)) {
                return error.InvalidCharacterError;
            }
        }

        // Step 2: For each token in tokens, remove token from this's token set
        for (tokens) |token| {
            const token_u16 = try infra.string.utf8ToUtf16(self.allocator, token);
            defer self.allocator.free(token_u16);

            _ = self.token_set.remove(token_u16);
        }

        // Step 3: Run the update steps
        try self.runUpdateSteps();
    }

    /// Toggle a token
    /// Spec §6.1 lines 6537-6551
    pub fn toggle(self: *DOMTokenList, token: []const u8, force: ?bool) !bool {
        // Step 1: If token is the empty string, throw SyntaxError
        if (token.len == 0) {
            return error.SyntaxError;
        }

        // Step 2: If token contains any ASCII whitespace, throw InvalidCharacterError
        if (containsAsciiWhitespace(token)) {
            return error.InvalidCharacterError;
        }

        const token_u16 = try infra.string.utf8ToUtf16(self.allocator, token);
        defer self.allocator.free(token_u16);

        // Step 3: If this's token set[token] exists:
        if (self.token_set.contains(token_u16)) {
            // Step 3.1: If force is either not given or is false,
            // then remove token from this's token set, run the update steps
            // and return false
            if (force == null or force.? == false) {
                _ = self.token_set.remove(token_u16);
                try self.runUpdateSteps();
                return false;
            }

            // Step 3.2: Return true
            return true;
        }

        // Step 4: Otherwise, if force not given or is true,
        // append token to this's token set, run the update steps, and return true
        if (force == null or force.? == true) {
            const token_copy = try self.allocator.dupe(u16, token_u16);
            try self.token_set.append(token_copy);
            try self.runUpdateSteps();
            return true;
        }

        // Step 5: Return false
        return false;
    }

    /// Replace a token with a new token
    /// Spec §6.1 lines 6555-6568
    pub fn replace(self: *DOMTokenList, token: []const u8, new_token: []const u8) !bool {
        // Step 1: If either token or newToken is the empty string, throw SyntaxError
        if (token.len == 0 or new_token.len == 0) {
            return error.SyntaxError;
        }

        // Step 2: If either token or newToken contains any ASCII whitespace,
        // throw InvalidCharacterError
        if (containsAsciiWhitespace(token) or containsAsciiWhitespace(new_token)) {
            return error.InvalidCharacterError;
        }

        const token_u16 = try infra.string.utf8ToUtf16(self.allocator, token);
        defer self.allocator.free(token_u16);

        // Step 3: If this's token set does not contain token, then return false
        if (!self.token_set.contains(token_u16)) {
            return false;
        }

        // Step 4: Replace token in this's token set with newToken
        const new_token_u16 = try infra.string.utf8ToUtf16(self.allocator, new_token);
        errdefer self.allocator.free(new_token_u16);

        // Find and replace in place to maintain order
        const items = self.token_set.items_list.toSlice();
        for (items, 0..) |existing_token, i| {
            if (std.mem.eql(u16, existing_token, token_u16)) {
                self.allocator.free(existing_token);
                // Access the underlying List's mutable slice
                self.token_set.items_list.toSliceMut()[i] = new_token_u16;
                break;
            }
        }

        // Step 5: Run the update steps
        try self.runUpdateSteps();

        // Step 6: Return true
        return true;
    }

    /// Get the value as a string
    /// Spec §6.1 line 6577: "The value attribute must return
    /// the result of running this's serialize steps"
    pub fn getValue(self: *const DOMTokenList) []const u8 {
        return self.serialize();
    }

    /// Set the value from a string
    /// Spec §6.1 lines 6579-6580: "Setting the value attribute must
    /// set an attribute value for the associated element using
    /// associated attribute's local name and the given value"
    pub fn setValue(self: *DOMTokenList, new_value: []const u8) !void {
        try attribute_algorithms.setAttributeValue(
            self.element,
            self.attribute_local_name,
            new_value,
            null,
            null,
        );
    }

    /// Serialize steps
    /// Spec §6.1 line 6420: "A DOMTokenList object's serialize steps are
    /// to return the result of running get an attribute value given
    /// the associated element and the associated attribute's local name"
    fn serialize(self: *const DOMTokenList) []const u8 {
        return self.element.getAttribute(self.attribute_local_name) orelse "";
    }

    /// Update steps
    /// Spec §6.1 lines 6414-6419
    fn runUpdateSteps(self: *DOMTokenList) !void {
        // Step 1: If the associated element does not have an associated attribute
        // and token set is empty, then return
        const current_value_opt = self.element.getAttribute(self.attribute_local_name);
        const has_attribute = current_value_opt != null;

        if (!has_attribute and self.token_set.isEmpty()) {
            return;
        }

        // Step 2: Set an attribute value for the associated element
        // using associated attribute's local name and the result of running
        // the ordered set serializer for token set
        const serialized = try self.serializeTokenSet();
        defer self.allocator.free(serialized);

        try self.element.setAttribute(self.attribute_local_name, serialized);
    }

    /// Serialize the token set to a space-separated string
    /// Uses WHATWG Infra ordered set serializer (§4.6 line 813)
    fn serializeTokenSet(self: *const DOMTokenList) ![]const u8 {
        if (self.token_set.isEmpty()) {
            return try self.allocator.dupe(u8, "");
        }

        // Use Infra's serializeStringSet from set.zig
        const serialized_u16 = try infra.set.serializeStringSet(self.allocator, &self.token_set);
        defer self.allocator.free(serialized_u16);

        // Convert back to UTF-8
        return try infra.string.utf16ToUtf8(self.allocator, serialized_u16);
    }

    /// Parse a value string into tokens and set the token set
    /// Spec §6.1 lines 6426-6428: "set token set to value, parsed"
    fn parseAndSetTokens(self: *DOMTokenList, value_str: []const u8) !void {
        // Clear existing tokens
        var it = self.token_set.iterator();
        while (it.next()) |token| {
            self.allocator.free(token);
        }
        self.token_set.clear();

        // Convert to u16 for Infra string operations
        const value_u16 = try infra.string.utf8ToUtf16(self.allocator, value_str);
        defer self.allocator.free(value_u16);

        // Split on ASCII whitespace
        const tokens = try infra.string.splitOnAsciiWhitespace(self.allocator, value_u16);
        defer {
            for (tokens) |token| {
                self.allocator.free(token);
            }
            self.allocator.free(tokens);
        }

        // Add each token to the set (ordered set semantics = no duplicates)
        for (tokens) |token| {
            if (token.len > 0) { // Skip empty tokens
                const token_copy = try self.allocator.dupe(u16, token);
                try self.token_set.append(token_copy);
            }
        }
    }

    /// Handle attribute changes (called when the attribute value changes)
    /// Spec §6.1 lines 6424-6428
    pub fn handleAttributeChange(
        self: *DOMTokenList,
        local_name: []const u8,
        namespace: ?[]const u8,
        new_value: ?[]const u8,
    ) !void {
        // Step 1: If localName is associated attribute's local name,
        // namespace is null, and value is null, then empty token set
        if (std.mem.eql(u8, local_name, self.attribute_local_name) and
            namespace == null and new_value == null)
        {
            var it = self.token_set.iterator();
            while (it.next()) |token| {
                self.allocator.free(token);
            }
            self.token_set.clear();
            return;
        }

        // Step 2: Otherwise, if localName is associated attribute's local name,
        // namespace is null, then set token set to value, parsed
        if (std.mem.eql(u8, local_name, self.attribute_local_name) and
            namespace == null and new_value != null)
        {
            try self.parseAndSetTokens(new_value.?);
        }
    }
};

/// Helper: Check if character is ASCII whitespace
/// Spec: https://infra.spec.whatwg.org/#ascii-whitespace
fn isAsciiWhitespace(c: u8) bool {
    return c == 0x09 or c == 0x0A or c == 0x0C or c == 0x0D or c == 0x20;
}

/// Helper: Check if a byte string contains ASCII whitespace
fn containsAsciiWhitespace(s: []const u8) bool {
    for (s) |c| {
        if (isAsciiWhitespace(c)) {
            return true;
        }
    }
    return false;
}

/// Helper: Get an attribute value (wrapper for easier access)
/// This would normally go in attribute_algorithms but we inline it here
fn getAttributeValue(element: *const ElementWithBase, local_name: []const u8) []const u8 {
    for (0..element.attributes.size()) |i| {
        if (element.attributes.get(i)) |attr| {
            if (std.mem.eql(u8, attr.local_name, local_name)) {
                return attr.value;
            }
        }
    }
    return "";
}
