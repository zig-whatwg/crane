//! DOMTokenList interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-domtokenlist

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

const Allocator = std.mem.Allocator;
const Element = @import("element").Element;

/// DOMTokenList represents a set of space-separated tokens.
/// Commonly used for Element.classList.
///
/// WebIDL Definition:
/// ```
/// interface DOMTokenList {
///   readonly attribute unsigned long length;
///   getter DOMString? item(unsigned long index);
///   boolean contains(DOMString token);
///   [CEReactions] undefined add(DOMString... tokens);
///   [CEReactions] undefined remove(DOMString... tokens);
///   [CEReactions] boolean toggle(DOMString token, optional boolean force);
///   [CEReactions] boolean replace(DOMString token, DOMString newToken);
///   [CEReactions] stringifier attribute DOMString value;
/// };
/// ```
pub const DOMTokenList = webidl.interface(struct {
    allocator: Allocator,

    /// The token set (ordered set of unique tokens)
    tokens: infra.List([]const u8),

    /// Associated element (for updating attribute)
    element: ?*Element,

    /// Associated attribute's local name (e.g., "class")
    attribute_name: []const u8,

    pub fn init(allocator: Allocator, element: ?*Element, attribute_name: []const u8) !DOMTokenList {
        return .{
            .allocator = allocator,
            .tokens = infra.List([]const u8).init(allocator),
            .element = element,
            .attribute_name = attribute_name,
        };
    }

    pub fn deinit(self: *DOMTokenList) void {
        // Free duplicated token strings
        for (self.tokens.items) |token| {
            self.allocator.free(token);
        }
        self.tokens.deinit();
    }

    /// DOM §4.7 - DOMTokenList.length
    /// Returns the number of tokens.
    pub fn get_length(self: *const DOMTokenList) u32 {
        return @intCast(self.tokens.items.len);
    }

    /// DOM §4.7 - DOMTokenList.item(index)
    /// Returns the token at the given index, or null if out of bounds.
    pub fn call_item(self: *const DOMTokenList, index: u32) ?[]const u8 {
        if (index >= self.tokens.items.len) {
            return null;
        }
        return self.tokens.items[index];
    }

    /// DOM §4.7 - DOMTokenList.contains(token)
    /// Returns true if token is present; otherwise false.
    pub fn call_contains(self: *const DOMTokenList, token: []const u8) bool {
        for (self.tokens.items) |t| {
            if (std.mem.eql(u8, t, token)) {
                return true;
            }
        }
        return false;
    }

    /// DOM §4.7 - DOMTokenList.add(tokens...)
    /// Adds all arguments passed, except those already present.
    pub fn call_add(self: *DOMTokenList, tokens: []const []const u8) !void {
        // Step 1: Validate all tokens first
        for (tokens) |token| {
            try DOMTokenList.validateToken(token);
        }

        // Step 2: Add tokens to set (skip duplicates)
        for (tokens) |token| {
            // Skip if already present
            if (self.call_contains(token)) {
                continue;
            }

            // Add token (duplicate the string for ownership)
            const token_copy = try self.allocator.dupe(u8, token);
            try self.tokens.append(token_copy);
        }

        // Step 3: Run update steps
        try self.runUpdateSteps();
    }

    /// DOM §4.7 - DOMTokenList.remove(tokens...)
    /// Removes all arguments passed, if they are present.
    pub fn call_remove(self: *DOMTokenList, tokens: []const []const u8) !void {
        // Step 1: Validate all tokens first
        for (tokens) |token| {
            try DOMTokenList.validateToken(token);
        }

        // Step 2: Remove tokens from set
        for (tokens) |token| {
            // Find and remove token
            for (self.tokens.items, 0..) |t, i| {
                if (std.mem.eql(u8, t, token)) {
                    const removed = self.tokens.orderedRemove(i);
                    self.allocator.free(removed);
                    break;
                }
            }
        }

        // Step 3: Run update steps
        try self.runUpdateSteps();
    }

    /// DOM §4.7 - DOMTokenList.toggle(token, force)
    /// If force is not given, toggles token, returning true if token is now present,
    /// and false otherwise. If force is true, adds token (same as add()). If force
    /// is false, removes token (same as remove()). Returns true if token is now
    /// present, and false otherwise.
    pub fn call_toggle(self: *DOMTokenList, token: []const u8, force: ?bool) !bool {
        // Step 1-2: Validate token
        try DOMTokenList.validateToken(token);

        // Step 3: If token exists in set
        if (self.call_contains(token)) {
            // Step 3.1: If force is false or not given, remove and return false
            if (force == null or force.? == false) {
                // Remove token
                for (self.tokens.items, 0..) |t, i| {
                    if (std.mem.eql(u8, t, token)) {
                        const removed = self.tokens.orderedRemove(i);
                        self.allocator.free(removed);
                        break;
                    }
                }
                try self.runUpdateSteps();
                return false;
            }
            // Step 3.2: Return true (force is true, token stays)
            return true;
        }

        // Step 4: Otherwise, if force is not given or is true, add token
        if (force == null or force.? == true) {
            const token_copy = try self.allocator.dupe(u8, token);
            try self.tokens.append(token_copy);
            try self.runUpdateSteps();
            return true;
        }

        // Step 5: Return false (force is false, token not in set)
        return false;
    }

    /// DOM §4.7 - DOMTokenList.replace(token, newToken)
    /// Replaces token with newToken. Returns true if token was replaced;
    /// otherwise false.
    pub fn call_replace(self: *DOMTokenList, token: []const u8, new_token: []const u8) !bool {
        // Step 1-2: Validate both tokens
        try DOMTokenList.validateToken(token);
        try DOMTokenList.validateToken(new_token);

        // Step 3: If token set does not contain token, return false
        var found = false;
        var found_index: usize = 0;
        for (self.tokens.items, 0..) |t, i| {
            if (std.mem.eql(u8, t, token)) {
                found = true;
                found_index = i;
                break;
            }
        }
        if (!found) {
            return false;
        }

        // Step 4: Replace token with newToken
        const old = self.tokens.items[found_index];
        self.allocator.free(old);
        const new_copy = try self.allocator.dupe(u8, new_token);
        self.tokens.items[found_index] = new_copy;

        // Step 5: Run update steps
        try self.runUpdateSteps();

        // Step 6: Return true
        return true;
    }

    /// DOM §4.7 - DOMTokenList.value (getter)
    /// Returns the associated set as string (space-separated tokens).
    pub fn get_value(self: *const DOMTokenList) ![]const u8 {
        if (self.tokens.items.len == 0) {
            return "";
        }

        // Calculate total length needed
        var total_len: usize = 0;
        for (self.tokens.items) |token| {
            total_len += token.len;
        }
        total_len += self.tokens.items.len - 1; // spaces between tokens

        // Allocate and build string
        const result = try self.allocator.alloc(u8, total_len);
        var pos: usize = 0;
        for (self.tokens.items, 0..) |token, i| {
            @memcpy(result[pos..][0..token.len], token);
            pos += token.len;
            if (i < self.tokens.items.len - 1) {
                result[pos] = ' ';
                pos += 1;
            }
        }

        return result;
    }

    /// DOM §4.7 - DOMTokenList.value (setter)
    /// Sets the associated attribute to the given value.
    pub fn set_value(self: *DOMTokenList, value: []const u8) !void {
        // Set an attribute value for the associated element using associated
        // attribute's local name and the given value
        if (self.element) |elem| {
            // Use Element's setAttribute which handles the full algorithm
            try elem.call_setAttribute(self.attribute_name, value);

            // Re-parse tokens from the new attribute value
            for (self.tokens.items) |token| {
                self.allocator.free(token);
            }
            self.tokens.clearRetainingCapacity();

            var iter = std.mem.tokenizeScalar(u8, value, ' ');
            while (iter.next()) |token| {
                const token_copy = try self.allocator.dupe(u8, token);
                try self.tokens.append(token_copy);
            }
        }
    }

    // ========================================================================
    // Helper Functions - DOM Spec Algorithms
    // ========================================================================

    /// Validate token - DOM Spec validation
    /// Throws SyntaxError if empty, InvalidCharacterError if contains whitespace
    fn validateToken(token: []const u8) !void {
        // If token is empty string, throw SyntaxError
        if (token.len == 0) {
            return error.SyntaxError;
        }

        // If token contains ASCII whitespace, throw InvalidCharacterError
        for (token) |c| {
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == '\x0C') {
                return error.InvalidCharacterError;
            }
        }
    }

    /// Update steps - DOM Spec algorithm
    /// Syncs token set with element's attribute
    fn runUpdateSteps(self: *DOMTokenList) !void {
        // Step 1: If element is null and token set is empty, return
        if (self.element == null and self.tokens.items.len == 0) {
            return;
        }

        // Step 2: Set an attribute value for the associated element
        if (self.element) |elem| {
            // Serialize token set (space-separated)
            const serialized = try self.serializeTokenSet();
            defer self.allocator.free(serialized);

            // Set attribute value
            try elem.call_setAttribute(self.attribute_name, serialized);
        }
    }

    /// Serialize token set as space-separated string
    fn serializeTokenSet(self: *const DOMTokenList) ![]const u8 {
        if (self.tokens.items.len == 0) {
            return "";
        }

        // Calculate total length
        var total_len: usize = 0;
        for (self.tokens.items) |token| {
            total_len += token.len;
        }
        total_len += self.tokens.items.len - 1; // spaces

        // Build string
        const result = try self.allocator.alloc(u8, total_len);
        var pos: usize = 0;
        for (self.tokens.items, 0..) |token, i| {
            @memcpy(result[pos..][0..token.len], token);
            pos += token.len;
            if (i < self.tokens.items.len - 1) {
                result[pos] = ' ';
                pos += 1;
            }
        }

        return result;
    }
}, .{
    .exposed = &.{.Window},
});
