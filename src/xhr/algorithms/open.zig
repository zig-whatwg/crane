//! XMLHttpRequest open() Algorithm
//!
//! WHATWG XHR Standard: https://xhr.spec.whatwg.org/#the-open()-method

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr = @import("../root.zig");
const XMLHttpRequestState = xhr.XMLHttpRequestState;
const ReadyState = xhr.ReadyState;

// URL Standard. `url_mod`'s root re-exports neither the serializer nor a plain
// `parse`, so these are the same three modules `src/webidl/impls/` takes.
const url_record = @import("url_record");
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");

/// Error types for open()
pub const OpenError = error{
    InvalidMethod,
    InvalidURL,
    InvalidState,
    SecurityError,
    OutOfMemory,
};

/// Forbidden methods.
///
/// Spec: https://fetch.spec.whatwg.org/#forbidden-method - "a method that is a
/// byte-case-insensitive match for CONNECT, TRACE, or TRACK".
const forbidden_methods = [_][]const u8{
    "CONNECT",
    "TRACE",
    "TRACK",
};

/// Methods normalized to uppercase.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-method-normalize - DELETE, GET,
/// HEAD, OPTIONS, POST and PUT, byte-case-insensitively.
const methods_to_normalize = [_][]const u8{
    "delete",
    "get",
    "head",
    "options",
    "post",
    "put",
};

/// Is `c` an HTTP token code point?
///
/// Spec: https://fetch.spec.whatwg.org/#concept-method - "a method is a byte
/// sequence that matches the method token production", and RFC 9110 defines
/// `token` from `tchar`.
fn isTokenChar(c: u8) bool {
    return switch (c) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        '0'...'9', 'a'...'z', 'A'...'Z' => true,
        else => false,
    };
}

/// Spec step 2: "If method is not a method, then throw a SyntaxError."
///
/// This check was missing entirely, so `open("GET HTTP/1.1", url)` and
/// `open("", url)` were accepted and turned into a request line with a space in
/// the method. `xhr/open-method-*.htm` tests exactly these.
pub fn isValidMethod(method: []const u8) bool {
    if (method.len == 0) return false;
    for (method) |c| {
        if (!isTokenChar(c)) return false;
    }
    return true;
}

/// Validate and normalize the HTTP method
///
/// Spec steps 2-4.
fn validateAndNormalizeMethod(allocator: Allocator, method: []const u8) ![]const u8 {
    // Step 2: If method is not a method, throw a "SyntaxError".
    if (!isValidMethod(method)) {
        return OpenError.InvalidMethod;
    }

    // Step 3: If method is a forbidden method, throw a "SecurityError".
    for (forbidden_methods) |forbidden| {
        if (std.ascii.eqlIgnoreCase(method, forbidden)) {
            return OpenError.SecurityError;
        }
    }

    // Step 4: Normalize method.
    for (methods_to_normalize) |standard| {
        if (std.ascii.eqlIgnoreCase(method, standard)) {
            return try std.ascii.allocUpperString(allocator, method);
        }
    }

    // Otherwise, use method as-is.
    return try allocator.dupe(u8, method);
}

/// Parse `url` relative to `base`, and return its serialization.
///
/// Spec steps 5-6: "Let parsedURL be the result of encoding-parsing a URL url,
/// relative to this's relevant settings object. If parsedURL is failure, then
/// throw a SyntaxError."
///
/// ## Why this is the whole ballgame
///
/// This used to be `_ = base; // TODO` followed by a `startsWith` check against
/// `http://`, `https://`, `data:` and `file://`. Every WPT XHR test opens a
/// RELATIVE url - `resources/content.py`, `folder.txt`, `?pipe=trickle` - so
/// every one of them threw SyntaxError out of `open()` and never reached
/// `send()`. The network path was not the thing that was broken.
///
/// Returns an owned, serialized absolute URL.
pub fn parseURL(allocator: Allocator, url: []const u8, base: ?[]const u8) ![]const u8 {
    // A base URL is itself parsed first; a base that does not parse is simply
    // no base, which then makes a relative input fail - the same outcome the
    // spec reaches through "encoding-parsing a URL" returning failure.
    var base_record: ?url_record.URLRecord = null;
    defer if (base_record) |*b| b.deinit();

    if (base) |base_str| {
        if (base_str.len > 0) {
            base_record = basic_parser.parse(allocator, base_str, null) catch null;
        }
    }

    var parsed = basic_parser.parse(
        allocator,
        url,
        if (base_record) |*b| b else null,
    ) catch {
        return OpenError.InvalidURL;
    };
    defer parsed.deinit();

    // Step 11: "Set this's request URL to parsedURL." The state stores the
    // serialization, which is what the fetch layer takes.
    return url_serializer.serialize(allocator, &parsed, false) catch OpenError.OutOfMemory;
}

/// The open() method
///
/// Spec: https://xhr.spec.whatwg.org/#the-open()-method
///
/// `base` is this's relevant settings object's API base URL - the document URL
/// for a Window, supplied by the impl. Null means "no base", under which a
/// relative URL legitimately fails to parse.
pub fn open(
    state: *XMLHttpRequestState,
    method: []const u8,
    url: []const u8,
    async_mode: bool,
    username: ?[]const u8,
    password: ?[]const u8,
    base: ?[]const u8,
) OpenError!void {
    const allocator = state.allocator;

    // Steps 2-4: Validate and normalize method.
    const normalized_method = try validateAndNormalizeMethod(allocator, method);
    errdefer allocator.free(normalized_method);

    // Steps 5-6: Parse the URL, relative to the base URL.
    const parsed_url = try parseURL(allocator, url, base orelse state.base_url);
    errdefer allocator.free(parsed_url);

    // Step 8: username/password on the parsed URL.
    //
    // TODO: `set the username`/`set the password` need the URLRecord to survive
    // past `parseURL`, which currently serializes and discards it. Until the
    // state holds a URLRecord rather than a string, credentials passed to
    // open() are dropped rather than mis-applied.
    _ = username;
    _ = password;

    // Step 9: If async is false, the current global object is a Window, and
    // either this's timeout is not 0 or this's response type is not the empty
    // string, throw an "InvalidAccessError".
    //
    // TODO: needs "is the current global object a Window", which the impl has
    // and this module does not.

    // Step 10: Terminate this's fetch controller.
    //
    // TODO: FetchController.abort(). A fetch can be ongoing here.

    // Step 11: Set variables associated with the object.
    state.reset();

    state.request_method = normalized_method;
    state.request_url = parsed_url;
    state.synchronous_flag = !async_mode;

    // Step 12: If this's state is not opened, then set it to opened and fire
    // readystatechange. The event is the impl's - this module has no way to
    // fire it, and firing it from `changeState` would fire it on every
    // transition. See `XMLHttpRequest.call_open`.
    state.changeState(.OPENED);
}

test "open - GET request" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com", true, null, null, null);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("GET", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com/", state.request_url.?);
    try std.testing.expect(!state.synchronous_flag);
}

test "open - POST request" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "POST", "https://example.com/api", true, null, null, null);

    try std.testing.expectEqual(ReadyState.OPENED, state.ready_state);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open - method normalization" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Lowercase methods should be normalized to uppercase
    try open(&state, "get", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("GET", state.request_method.?);

    state.reset();

    try open(&state, "post", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
}

test "open - a non-normalized method keeps its case" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // Spec: normalization covers only DELETE, GET, HEAD, OPTIONS, POST and
    // PUT. "patch" is a method, and stays lowercase.
    try open(&state, "patch", "http://example.com", true, null, null, null);
    try std.testing.expectEqualStrings("patch", state.request_method.?);
}

test "open - forbidden methods" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // CONNECT should be forbidden
    const result1 = open(&state, "CONNECT", "http://example.com", true, null, null, null);
    try std.testing.expectError(OpenError.SecurityError, result1);

    // TRACE should be forbidden
    const result2 = open(&state, "TRACE", "http://example.com", true, null, null, null);
    try std.testing.expectError(OpenError.SecurityError, result2);

    // TRACK should be forbidden
    const result3 = open(&state, "TRACK", "http://example.com", true, null, null, null);
    try std.testing.expectError(OpenError.SecurityError, result3);

    // Case-insensitively, per "byte-case-insensitive match"
    const result4 = open(&state, "connect", "http://example.com", true, null, null, null);
    try std.testing.expectError(OpenError.SecurityError, result4);
}

test "open - a method that is not a token is a SyntaxError" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try std.testing.expect(!isValidMethod(""));
    try std.testing.expect(!isValidMethod("GET HTTP/1.1"));
    try std.testing.expect(!isValidMethod("G\tET"));
    try std.testing.expect(!isValidMethod("GE(T"));
    try std.testing.expect(isValidMethod("GET"));
    try std.testing.expect(isValidMethod("X-CUSTOM!"));

    try std.testing.expectError(
        OpenError.InvalidMethod,
        open(&state, "GET GET", "http://example.com", true, null, null, null),
    );
}

test "open - synchronous mode" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    try open(&state, "GET", "http://example.com", false, null, null, null);

    try std.testing.expect(state.synchronous_flag);
}

test "open - invalid URL" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // An empty URL with no base cannot be parsed.
    const result1 = open(&state, "GET", "", true, null, null, null);
    try std.testing.expectError(OpenError.InvalidURL, result1);

    // A relative URL with no base cannot be parsed either.
    const result2 = open(&state, "GET", "resources/content.py", true, null, null, null);
    try std.testing.expectError(OpenError.InvalidURL, result2);
}

test "open - an unusual scheme is still a URL" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // The old `parseURL` allow-listed http, https, data and file and rejected
    // everything else as InvalidURL. The spec's test is whether the URL PARSES,
    // not whether the UA can fetch it - an unfetchable scheme becomes a network
    // error at send() time, not a SyntaxError at open() time.
    try open(&state, "GET", "ftp://example.com/x", true, null, null, null);
    try std.testing.expectEqualStrings("ftp://example.com/x", state.request_url.?);
}

test "open - resolves a relative URL against the base URL" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    const base = "http://web-platform.test:8000/xhr/abort-after-send.htm";

    // The shape every WPT XHR test uses.
    try open(&state, "GET", "resources/content.py", true, null, null, base);
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000/xhr/resources/content.py",
        state.request_url.?,
    );
}

test "open - relative URL forms against a base" {
    const allocator = std.testing.allocator;

    const base = "http://web-platform.test:8000/xhr/resources/folder.txt";

    const cases = [_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "/xhr/x", .expected = "http://web-platform.test:8000/xhr/x" },
        .{ .input = "?pipe=trickle", .expected = "http://web-platform.test:8000/xhr/resources/folder.txt?pipe=trickle" },
        .{ .input = "../top.txt", .expected = "http://web-platform.test:8000/xhr/top.txt" },
        .{ .input = "//other.example/x", .expected = "http://other.example/x" },
        .{ .input = "", .expected = "http://web-platform.test:8000/xhr/resources/folder.txt" },
    };

    for (cases) |case| {
        const got = try parseURL(allocator, case.input, base);
        defer allocator.free(got);
        try std.testing.expectEqualStrings(case.expected, got);
    }
}

test "open - the state's base_url is used when no base is passed" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    state.base_url = "http://web-platform.test:8000/xhr/x.htm";

    try open(&state, "GET", "resources/content.py", true, null, null, null);
    try std.testing.expectEqualStrings(
        "http://web-platform.test:8000/xhr/resources/content.py",
        state.request_url.?,
    );
}

test "open - multiple calls (reset)" {
    const allocator = std.testing.allocator;

    var state = XMLHttpRequestState.init(allocator);
    defer state.deinit();

    // First open
    try open(&state, "GET", "http://example.com/1", true, null, null, null);
    try std.testing.expectEqualStrings("http://example.com/1", state.request_url.?);

    // Second open should reset and replace
    try open(&state, "POST", "http://example.com/2", true, null, null, null);
    try std.testing.expectEqualStrings("POST", state.request_method.?);
    try std.testing.expectEqualStrings("http://example.com/2", state.request_url.?);
}
