//! Trusted Types Core Types
//!
//! W3C Trusted Types Spec: https://w3c.github.io/trusted-types/dist/spec/
//!
//! This module defines the core trusted type wrappers:
//! - TrustedHTML: Represents trusted HTML content
//! - TrustedScript: Represents trusted script content
//! - TrustedScriptURL: Represents trusted script URLs
//!
//! These types are opaque wrappers around strings that indicate the content
//! has been sanitized/approved by a TrustedTypePolicy.

const std = @import("std");

/// TrustedHTML represents a string that is safe to use in HTML contexts.
///
/// Per spec: "The TrustedHTML interface represents a string that a developer
/// can confidently insert into an injection sink that will render it as HTML."
///
/// WebIDL:
/// ```webidl
/// [Exposed=(Window,Worker)]
/// interface TrustedHTML {
///   stringifier;
///   DOMString toJSON();
/// };
/// ```
pub const TrustedHTML = struct {
    /// The underlying trusted HTML string.
    /// This is the internal slot [[Data]] per spec.
    data: []const u8,

    /// Allocator used for the data (null if data is externally managed)
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a new TrustedHTML from a string.
    /// This should only be called by TrustedTypePolicy.createHTML().
    ///
    /// Note: This copies the input string.
    pub fn create(allocator: std.mem.Allocator, value: []const u8) !Self {
        const data = try allocator.dupe(u8, value);
        return Self{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Create a TrustedHTML with externally-managed memory (no copy).
    /// Use this when the caller manages the lifetime of the string.
    pub fn createUnmanaged(value: []const u8) Self {
        return Self{
            .data = value,
            .allocator = null,
        };
    }

    /// Free the underlying data if we own it.
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
            self.data = "";
            self.allocator = null;
        }
    }

    /// Stringifier - returns the string representation.
    /// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
    pub fn toString(self: Self) []const u8 {
        return self.data;
    }

    /// toJSON() - returns the string for JSON serialization.
    /// Per spec: "The toJSON() method steps are to return the value of the object's [[Data]] internal slot."
    pub fn toJSON(self: Self) []const u8 {
        return self.data;
    }
};

/// TrustedScript represents a string that is safe to use as script content.
///
/// Per spec: "The TrustedScript interface represents a string that a developer
/// can confidently pass to an injection sink that might execute it as a script."
///
/// WebIDL:
/// ```webidl
/// [Exposed=(Window,Worker)]
/// interface TrustedScript {
///   stringifier;
///   DOMString toJSON();
/// };
/// ```
pub const TrustedScript = struct {
    /// The underlying trusted script string.
    /// This is the internal slot [[Data]] per spec.
    data: []const u8,

    /// Allocator used for the data (null if data is externally managed)
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a new TrustedScript from a string.
    /// This should only be called by TrustedTypePolicy.createScript().
    ///
    /// Note: This copies the input string.
    pub fn create(allocator: std.mem.Allocator, value: []const u8) !Self {
        const data = try allocator.dupe(u8, value);
        return Self{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Create a TrustedScript with externally-managed memory (no copy).
    /// Use this when the caller manages the lifetime of the string.
    pub fn createUnmanaged(value: []const u8) Self {
        return Self{
            .data = value,
            .allocator = null,
        };
    }

    /// Free the underlying data if we own it.
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
            self.data = "";
            self.allocator = null;
        }
    }

    /// Stringifier - returns the string representation.
    /// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
    pub fn toString(self: Self) []const u8 {
        return self.data;
    }

    /// toJSON() - returns the string for JSON serialization.
    /// Per spec: "The toJSON() method steps are to return the value of the object's [[Data]] internal slot."
    pub fn toJSON(self: Self) []const u8 {
        return self.data;
    }
};

/// TrustedScriptURL represents a URL string that is safe to use as a script source.
///
/// Per spec: "The TrustedScriptURL interface represents a string that a developer
/// can confidently pass to an injection sink that will use it to load code."
///
/// WebIDL:
/// ```webidl
/// [Exposed=(Window,Worker)]
/// interface TrustedScriptURL {
///   stringifier;
///   USVString toJSON();
/// };
/// ```
pub const TrustedScriptURL = struct {
    /// The underlying trusted script URL string.
    /// This is the internal slot [[Data]] per spec.
    /// Note: This should be a USVString (valid Unicode scalar values).
    data: []const u8,

    /// Allocator used for the data (null if data is externally managed)
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a new TrustedScriptURL from a string.
    /// This should only be called by TrustedTypePolicy.createScriptURL().
    ///
    /// Note: This copies the input string.
    pub fn create(allocator: std.mem.Allocator, value: []const u8) !Self {
        const data = try allocator.dupe(u8, value);
        return Self{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Create a TrustedScriptURL with externally-managed memory (no copy).
    /// Use this when the caller manages the lifetime of the string.
    pub fn createUnmanaged(value: []const u8) Self {
        return Self{
            .data = value,
            .allocator = null,
        };
    }

    /// Free the underlying data if we own it.
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
            self.data = "";
            self.allocator = null;
        }
    }

    /// Stringifier - returns the string representation.
    /// Per spec: "The stringifier must return the value of the object's [[Data]] internal slot."
    pub fn toString(self: Self) []const u8 {
        return self.data;
    }

    /// toJSON() - returns the string for JSON serialization.
    /// Per spec: "The toJSON() method steps are to return the value of the object's [[Data]] internal slot."
    pub fn toJSON(self: Self) []const u8 {
        return self.data;
    }
};

/// Union type for any trusted type.
/// Per spec typedef: `typedef (TrustedHTML or TrustedScript or TrustedScriptURL) TrustedType;`
pub const TrustedType = union(enum) {
    html: TrustedHTML,
    script: TrustedScript,
    script_url: TrustedScriptURL,

    const Self = @This();

    /// Get the string value from any trusted type.
    pub fn toString(self: Self) []const u8 {
        return switch (self) {
            .html => |h| h.toString(),
            .script => |s| s.toString(),
            .script_url => |u| u.toString(),
        };
    }

    /// Free the underlying data if owned.
    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .html => |*h| h.deinit(),
            .script => |*s| s.deinit(),
            .script_url => |*u| u.deinit(),
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "TrustedHTML - create and access" {
    const allocator = std.testing.allocator;

    var html = try TrustedHTML.create(allocator, "<div>Hello</div>");
    defer html.deinit();

    try std.testing.expectEqualStrings("<div>Hello</div>", html.toString());
    try std.testing.expectEqualStrings("<div>Hello</div>", html.toJSON());
}

test "TrustedHTML - unmanaged" {
    const static_html = "<p>Static</p>";
    const html = TrustedHTML.createUnmanaged(static_html);

    try std.testing.expectEqualStrings("<p>Static</p>", html.toString());
    // No deinit needed for unmanaged
}

test "TrustedScript - create and access" {
    const allocator = std.testing.allocator;

    var script = try TrustedScript.create(allocator, "console.log('hello')");
    defer script.deinit();

    try std.testing.expectEqualStrings("console.log('hello')", script.toString());
    try std.testing.expectEqualStrings("console.log('hello')", script.toJSON());
}

test "TrustedScriptURL - create and access" {
    const allocator = std.testing.allocator;

    var url = try TrustedScriptURL.create(allocator, "https://example.com/script.js");
    defer url.deinit();

    try std.testing.expectEqualStrings("https://example.com/script.js", url.toString());
    try std.testing.expectEqualStrings("https://example.com/script.js", url.toJSON());
}

test "TrustedType union" {
    const allocator = std.testing.allocator;

    const html = try TrustedHTML.create(allocator, "<span>test</span>");
    var trusted: TrustedType = .{ .html = html };
    defer trusted.deinit();

    try std.testing.expectEqualStrings("<span>test</span>", trusted.toString());
}

test "TrustedHTML - empty string" {
    const allocator = std.testing.allocator;

    var html = try TrustedHTML.create(allocator, "");
    defer html.deinit();

    try std.testing.expectEqualStrings("", html.toString());
}
