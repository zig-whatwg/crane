//! Body Mixin - WHATWG Fetch Specification
//!
//! This module implements the Body mixin that is included by Request and Response.
//!
//! Spec: https://fetch.spec.whatwg.org/#body-mixin
//!
//! The Body mixin provides:
//! - body attribute (ReadableStream)
//! - bodyUsed attribute
//! - arrayBuffer(), blob(), bytes(), formData(), json(), text() methods

const std = @import("std");
const Allocator = std.mem.Allocator;
const body_mod = @import("../internal/body.zig");
const Body = body_mod.Body;

/// Body mixin implementation.
///
/// This provides the interface that Request and Response both implement.
/// In WebIDL terms, this is an interface mixin.
pub const BodyMixin = struct {
    /// The underlying Body object.
    body: ?*Body,
    /// Whether the body has been read.
    body_used: bool,
    /// Allocator for operations.
    allocator: Allocator,

    const Self = @This();

    /// Initialize a new BodyMixin.
    pub fn init(allocator: Allocator, body: ?*Body) Self {
        return .{
            .body = body,
            .allocator = allocator,
            .body_used = false,
        };
    }

    // === Attributes ===

    /// Check if body has been used.
    ///
    /// Spec: readonly attribute boolean bodyUsed
    pub fn isBodyUsed(self: *const Self) bool {
        return self.body_used;
    }

    /// Check if body is null.
    pub fn hasBody(self: *const Self) bool {
        return self.body != null;
    }

    // === Methods ===

    /// Consume body as bytes (ArrayBuffer).
    ///
    /// Spec: Promise<ArrayBuffer> arrayBuffer()
    pub fn arrayBuffer(self: *Self) ![]u8 {
        if (self.body_used) {
            return error.TypeError; // Body already used
        }

        if (self.body) |body| {
            self.body_used = true;
            body.markUsed();
            // Get bytes from body
            const body_bytes = body.getBytes();
            return try self.allocator.dupe(u8, body_bytes);
        }

        return try self.allocator.dupe(u8, "");
    }

    /// Consume body as bytes (Uint8Array).
    ///
    /// Spec: Promise<Uint8Array> bytes()
    pub fn bytes(self: *Self) ![]u8 {
        return self.arrayBuffer();
    }

    /// Consume body as text (UTF-8 decoded).
    ///
    /// Spec: Promise<USVString> text()
    pub fn text(self: *Self) ![]u8 {
        if (self.body_used) {
            return error.TypeError;
        }

        if (self.body) |body| {
            self.body_used = true;
            body.markUsed();
            const body_bytes = body.getBytes();
            return try self.allocator.dupe(u8, body_bytes);
        }

        return try self.allocator.dupe(u8, "");
    }

    /// Consume body as JSON.
    ///
    /// Spec: Promise<any> json()
    /// Note: Returns raw bytes. Actual JSON parsing would be done by caller.
    pub fn json(self: *Self) ![]u8 {
        return self.text();
    }

    /// Consume body as Blob.
    ///
    /// Spec: Promise<Blob> blob()
    /// Note: Returns bytes and MIME type. Actual Blob creation would be done by caller.
    pub fn blob(self: *Self) !BlobResult {
        if (self.body_used) {
            return error.TypeError;
        }

        if (self.body) |body| {
            self.body_used = true;
            body.markUsed();
            const body_bytes = body.getBytes();
            const data = try self.allocator.dupe(u8, body_bytes);
            return .{
                .data = data,
                .mime_type = "application/octet-stream", // TODO: Get from Content-Type header
            };
        }

        return .{
            .data = &[_]u8{},
            .mime_type = "",
        };
    }

    /// Consume body as FormData.
    ///
    /// Spec: Promise<FormData> formData()
    /// Note: This is a stub - FormData parsing is complex.
    pub fn formData(self: *Self) !FormDataResult {
        if (self.body_used) {
            return error.TypeError;
        }

        if (self.body) |body| {
            self.body_used = true;
            body.markUsed();
            const body_bytes = body.getBytes();
            const data = try self.allocator.dupe(u8, body_bytes);
            // TODO: Parse multipart/form-data or application/x-www-form-urlencoded
            return .{
                .raw_data = data,
                .entries = &[_]FormDataEntry{},
            };
        }

        return .{
            .raw_data = &[_]u8{},
            .entries = &[_]FormDataEntry{},
        };
    }

    /// Clone the body for use in another object.
    pub fn cloneBody(self: *Self) !?*Body {
        if (self.body_used) {
            return error.TypeError;
        }

        if (self.body) |body| {
            return try body.clone(self.allocator);
        }

        return null;
    }
};

/// Result of blob() call.
pub const BlobResult = struct {
    data: []const u8,
    mime_type: []const u8,
};

/// Single FormData entry.
pub const FormDataEntry = struct {
    name: []const u8,
    value: FormDataValue,
};

/// FormData value - either string or file.
pub const FormDataValue = union(enum) {
    string: []const u8,
    file: FileData,
};

/// File data for FormData.
pub const FileData = struct {
    data: []const u8,
    filename: []const u8,
    content_type: []const u8,
};

/// Result of formData() call.
pub const FormDataResult = struct {
    raw_data: []const u8,
    entries: []const FormDataEntry,
};

// =============================================================================
// Tests
// =============================================================================

test "BodyMixin - null body" {
    const allocator = std.testing.allocator;

    var mixin = BodyMixin.init(allocator, null);

    try std.testing.expect(!mixin.hasBody());
    try std.testing.expect(!mixin.isBodyUsed());

    const text_result = try mixin.text();
    defer allocator.free(text_result);
    try std.testing.expectEqualStrings("", text_result);
}

test "BodyMixin - with body" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "Hello, World!");
    defer body.deinit();

    var mixin = BodyMixin.init(allocator, body);

    try std.testing.expect(mixin.hasBody());
    try std.testing.expect(!mixin.isBodyUsed());

    const text_result = try mixin.text();
    defer allocator.free(text_result);
    try std.testing.expectEqualStrings("Hello, World!", text_result);

    try std.testing.expect(mixin.isBodyUsed());
}

test "BodyMixin - body used error" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "test");
    defer body.deinit();

    var mixin = BodyMixin.init(allocator, body);

    // First read succeeds
    const result1 = try mixin.text();
    defer allocator.free(result1);

    // Second read fails
    try std.testing.expectError(error.TypeError, mixin.text());
}

test "BodyMixin - arrayBuffer" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "binary data");
    defer body.deinit();

    var mixin = BodyMixin.init(allocator, body);

    const result = try mixin.arrayBuffer();
    defer allocator.free(result);
    try std.testing.expectEqualStrings("binary data", result);
}

test "BodyMixin - blob" {
    const allocator = std.testing.allocator;

    const body = try Body.fromBytes(allocator, "blob data");
    defer body.deinit();

    var mixin = BodyMixin.init(allocator, body);

    const result = try mixin.blob();
    defer allocator.free(result.data);
    try std.testing.expectEqualStrings("blob data", result.data);
}
