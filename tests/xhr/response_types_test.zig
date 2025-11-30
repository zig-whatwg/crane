//! Comprehensive response type tests
//!
//! Tests all response types and their edge cases.

const std = @import("std");
const xhr = @import("xhr");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;
const ResponseType = xhr.state_machine.ResponseType;
const response = xhr.response;
const ResponseValue = response.ResponseValue;
const getResponse = response.getResponse;
const getResponseText = response.getResponseText;
const getResponseXML = response.getResponseXML;

// =============================================================================
// Text Response Type
// =============================================================================

test "Text response - empty body" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;

    const result = try getResponse(&state);
    try std.testing.expectEqualStrings("", result.text);
}

test "Text response - ASCII content" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "Hello, World!");

    const result = try getResponse(&state);
    try std.testing.expectEqualStrings("Hello, World!", result.text);
}

test "Text response - UTF-8 content" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "Hello, 世界! 🌍");

    const result = try getResponse(&state);
    try std.testing.expectEqualStrings("Hello, 世界! 🌍", result.text);
}

test "Text response - available during LOADING" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "partial");

    const result = try getResponse(&state);
    try std.testing.expectEqualStrings("partial", result.text);
}

// =============================================================================
// ArrayBuffer Response Type
// =============================================================================

test "ArrayBuffer response - binary data" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;
    try state.received_bytes.appendSlice(allocator, &[_]u8{ 0x00, 0xFF, 0x10, 0x20 });

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0xFF, 0x10, 0x20 }, result.arraybuffer);
}

test "ArrayBuffer response - empty" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), result.arraybuffer.len);
}

test "ArrayBuffer response - not available during LOADING" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .LOADING;
    state.response_type = .arraybuffer;
    try state.received_bytes.appendSlice(allocator, "data");

    const result = try getResponse(&state);
    try std.testing.expect(result == .empty);
}

// =============================================================================
// Blob Response Type
// =============================================================================

test "Blob response - with data" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .blob;
    try state.received_bytes.appendSlice(allocator, "blob content");

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("blob content", result.blob.data);
    try std.testing.expectEqualStrings("application/octet-stream", result.blob.mime_type);
}

test "Blob response - empty" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .blob;

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), result.blob.data.len);
}

// =============================================================================
// JSON Response Type
// =============================================================================

test "JSON response - valid object" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;
    try state.received_bytes.appendSlice(allocator, "{\"name\":\"test\"}");

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("{\"name\":\"test\"}", result.json.?);
}

test "JSON response - valid array" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;
    try state.received_bytes.appendSlice(allocator, "[1,2,3]");

    var result = try getResponse(&state);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("[1,2,3]", result.json.?);
}

test "JSON response - primitives" {
    const allocator = std.testing.allocator;

    // Test true
    {
        var state = XMLHttpRequestState.init(allocator);
        defer state.deinit();

        state.ready_state = .DONE;
        state.response_type = .json;
        try state.received_bytes.appendSlice(allocator, "true");

        var result = try getResponse(&state);
        defer result.deinit(allocator);

        try std.testing.expectEqualStrings("true", result.json.?);
    }

    // Test false
    {
        var state = XMLHttpRequestState.init(allocator);
        defer state.deinit();

        state.ready_state = .DONE;
        state.response_type = .json;
        try state.received_bytes.appendSlice(allocator, "false");

        var result = try getResponse(&state);
        defer result.deinit(allocator);

        try std.testing.expectEqualStrings("false", result.json.?);
    }

    // Test null
    {
        var state = XMLHttpRequestState.init(allocator);
        defer state.deinit();

        state.ready_state = .DONE;
        state.response_type = .json;
        try state.received_bytes.appendSlice(allocator, "null");

        var result = try getResponse(&state);
        defer result.deinit(allocator);

        try std.testing.expectEqualStrings("null", result.json.?);
    }
}

test "JSON response - invalid returns null" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;
    try state.received_bytes.appendSlice(allocator, "not json");

    const result = try getResponse(&state);
    try std.testing.expect(result.json == null);
}

test "JSON response - empty returns null" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .json;

    const result = try getResponse(&state);
    try std.testing.expect(result.json == null);
}

// =============================================================================
// Document Response Type
// =============================================================================

test "Document response - stubbed returns void" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .document;

    const result = try getResponse(&state);
    try std.testing.expect(result == .document);
}

// =============================================================================
// Error States
// =============================================================================

test "Response - error flag returns error" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;
    state.error_flag = true;

    const result = try getResponse(&state);
    try std.testing.expect(result == .@"error");
}

// =============================================================================
// getResponseText Legacy Property
// =============================================================================

test "getResponseText - works with empty type" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .empty;
    try state.received_bytes.appendSlice(allocator, "text content");

    const text = try getResponseText(&state);
    try std.testing.expectEqualStrings("text content", text);
}

test "getResponseText - works with text type" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .text;
    try state.received_bytes.appendSlice(allocator, "text content");

    const text = try getResponseText(&state);
    try std.testing.expectEqualStrings("text content", text);
}

test "getResponseText - throws for other types" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;

    try std.testing.expectError(error.InvalidStateError, getResponseText(&state));
}

test "getResponseText - empty for UNSENT state" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.response_type = .text;

    const text = try getResponseText(&state);
    try std.testing.expectEqualStrings("", text);
}

// =============================================================================
// getResponseXML Legacy Property
// =============================================================================

test "getResponseXML - returns null (stubbed)" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .document;

    const xml = try getResponseXML(&state);
    try std.testing.expect(xml == null);
}

test "getResponseXML - throws for arraybuffer type" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.ready_state = .DONE;
    state.response_type = .arraybuffer;

    try std.testing.expectError(error.InvalidStateError, getResponseXML(&state));
}
