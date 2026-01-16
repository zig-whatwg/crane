//! Worker Script Fetching - HTML Standard §10.2.5
//!
//! This module implements script fetching for Web Workers:
//! - Fetch worker scripts using the Fetch module
//! - Implement importScripts() for classic workers
//! - Handle script execution in worker context
//!
//! Spec: https://html.spec.whatwg.org/#run-a-worker
//!
//! ## Key Algorithms
//!
//! - **fetchWorkerScript**: Fetch a single worker script
//! - **fetchImportScripts**: Fetch multiple scripts for importScripts()
//! - **executeWorkerScript**: Execute fetched script in worker context
//!
//! ## Integration Points
//!
//! - Uses Fetch module from src/fetch/
//! - Integrates with WorkerAgent for script execution
//! - Works with DedicatedWorker and SharedWorker

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const WorkerType = types.WorkerType;
const WorkerOptions = types.WorkerOptions;

// Fetch module for HTTP(S) requests - now available via html_core_mod.addImport("fetch")
const fetch = @import("fetch");

// ============================================================================
// Thread-Local Origin for URL Resolution
// ============================================================================

/// Thread-local storage for document origin (needed for resolving relative URLs)
/// Set by the test runner or browser context before Worker construction.
threadlocal var current_document_origin: ?[]const u8 = null;

/// Set the document origin for resolving relative worker script URLs.
/// This should be called by the browser context before executing scripts
/// that might construct Workers.
pub fn setDocumentOrigin(origin: []const u8) void {
    current_document_origin = origin;
}

/// Get the current document origin.
pub fn getDocumentOrigin() ?[]const u8 {
    return current_document_origin;
}

/// Clear the document origin (for cleanup after test runs).
pub fn clearDocumentOrigin() void {
    current_document_origin = null;
}

// ============================================================================
// Blob URL Resolution Callback
// ============================================================================

/// Result of resolving a blob URL
pub const BlobResolveResult = struct {
    /// The blob's bytes
    bytes: []const u8,
    /// The blob's MIME type
    content_type: []const u8,
    /// Whether we own the bytes (caller should free)
    owns_bytes: bool,
};

/// Callback function type for resolving blob URLs.
/// This allows external code (with access to the file module) to register
/// a resolver that can access the BlobURLStore.
///
/// Parameters:
///   - allocator: Allocator for any needed allocations
///   - url: The full blob URL (e.g., "blob:http://localhost:8000/uuid")
///   - origin: The requesting origin for same-origin validation
///
/// Returns: BlobResolveResult with blob bytes and content type, or null if not found
pub const BlobResolverFn = *const fn (
    allocator: Allocator,
    url: []const u8,
    origin: []const u8,
) ?BlobResolveResult;

/// Thread-local storage for the blob resolver callback.
/// Set by browser context initialization when it has access to the file module.
threadlocal var blob_resolver_callback: ?BlobResolverFn = null;

/// Register a blob resolver callback.
/// This should be called by the browser context during initialization,
/// when it has access to the file module's BlobURLStore.
pub fn setBlobResolver(resolver: BlobResolverFn) void {
    blob_resolver_callback = resolver;
}

/// Get the currently registered blob resolver.
pub fn getBlobResolver() ?BlobResolverFn {
    return blob_resolver_callback;
}

/// Clear the blob resolver (for cleanup).
pub fn clearBlobResolver() void {
    blob_resolver_callback = null;
}

// ============================================================================
// Worker Script Fetch Errors
// ============================================================================

pub const WorkerScriptError = error{
    /// Network error during fetch
    NetworkError,
    /// Failed to fetch script
    FetchFailed,
    /// Invalid script URL
    InvalidUrl,
    /// Cross-origin script not allowed
    CrossOriginNotAllowed,
    /// Script parse error
    ParseError,
    /// Script execution error
    ExecutionError,
    /// Module script not allowed (for importScripts)
    ModuleNotAllowed,
    /// Out of memory
    OutOfMemory,
    /// Worker is closing or terminated
    WorkerClosing,
};

// ============================================================================
// Fetch Options
// ============================================================================

/// Options for fetching worker scripts
pub const WorkerScriptFetchOptions = struct {
    /// Worker type (classic or module)
    worker_type: WorkerType = .classic,
    /// Origin of the request
    origin: ?[]const u8 = null,
    /// Credentials mode
    credentials: CredentialsMode = .same_origin,
    /// Whether this is for importScripts (stricter rules apply)
    is_import_scripts: bool = false,

    pub const CredentialsMode = enum {
        omit,
        same_origin,
        include,
    };
};

// ============================================================================
// Fetched Script Result
// ============================================================================

/// Result of fetching a worker script
pub const FetchedScript = struct {
    allocator: Allocator,

    /// The script source code
    source: []const u8,

    /// The final URL (after redirects)
    final_url: []const u8,

    /// Content type of the response
    content_type: []const u8,

    /// Whether the script is from same origin
    same_origin: bool,

    pub fn init(
        allocator: Allocator,
        source: []const u8,
        final_url: []const u8,
        content_type: []const u8,
        same_origin: bool,
    ) !FetchedScript {
        return .{
            .allocator = allocator,
            .source = try allocator.dupe(u8, source),
            .final_url = try allocator.dupe(u8, final_url),
            .content_type = try allocator.dupe(u8, content_type),
            .same_origin = same_origin,
        };
    }

    pub fn deinit(self: *FetchedScript) void {
        self.allocator.free(self.source);
        self.allocator.free(self.final_url);
        self.allocator.free(self.content_type);
    }
};

// ============================================================================
// Fetch Worker Script
// ============================================================================

/// Fetch a worker script
///
/// HTML Standard §10.2.5 "Run a worker" step 9:
/// "Let script be the result of fetching a classic worker script given url,
/// outside settings, destination, and inside settings."
///
/// For now, this returns a stub result since the Fetch module isn't directly
/// accessible from html_core. In a full implementation, this would use:
/// - fetch.internal.InternalRequest with destination = .worker
/// - response.body.getBytes() for script source
pub fn fetchWorkerScript(
    allocator: Allocator,
    url: []const u8,
    options: WorkerScriptFetchOptions,
) WorkerScriptError!FetchedScript {
    // Step 1: Validate URL
    if (url.len == 0) {
        return WorkerScriptError.InvalidUrl;
    }

    // Step 2: Check for special URLs
    if (std.mem.startsWith(u8, url, "data:")) {
        return handleDataUrl(allocator, url);
    }

    if (std.mem.startsWith(u8, url, "blob:")) {
        return handleBlobUrl(allocator, url);
    }

    // Step 3: For HTTP(S) URLs, use the fetch module
    if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
        return fetchHttpWorkerScript(allocator, url, options);
    }

    // Step 4: Handle relative URLs - resolve against base URL or origin
    // This handles: "/path", "./relative", "../parent", "bare-name.js"
    const resolved_url = resolveRelativeUrl(allocator, url, options.origin) catch {
        return WorkerScriptError.OutOfMemory;
    };
    if (resolved_url) |full_url| {
        defer allocator.free(full_url);
        return fetchHttpWorkerScript(allocator, full_url, options);
    }

    // Step 5: Check for import scripts mode (stricter)
    if (options.is_import_scripts) {
        // importScripts() only works with classic scripts
        if (options.worker_type == .module) {
            return WorkerScriptError.ModuleNotAllowed;
        }
    }

    // Step 6: For other URLs (file:, etc.), return error
    return WorkerScriptError.InvalidUrl;
}

/// Handle data: URL for worker scripts
fn handleDataUrl(allocator: Allocator, url: []const u8) WorkerScriptError!FetchedScript {
    // data:[<mediatype>][;base64],<data>
    const data_start = std.mem.indexOf(u8, url, ",") orelse return WorkerScriptError.InvalidUrl;
    const meta = url[5..data_start]; // After "data:"
    const data = url[data_start + 1 ..];

    // Check for base64 encoding
    const is_base64 = std.mem.indexOf(u8, meta, ";base64") != null;

    // Get content type (default to text/javascript for workers)
    const content_type = blk: {
        const semicolon_pos = std.mem.indexOf(u8, meta, ";");
        if (semicolon_pos) |pos| {
            if (pos > 0) {
                break :blk meta[0..pos];
            }
        } else if (meta.len > 0) {
            break :blk meta;
        }
        break :blk "text/javascript";
    };

    // Decode the data
    var source: []const u8 = undefined;
    if (is_base64) {
        // Base64 decode
        const decoded_size = std.base64.standard.Decoder.calcSizeForSlice(data) catch {
            return WorkerScriptError.InvalidUrl;
        };
        const decoded = allocator.alloc(u8, decoded_size) catch {
            return WorkerScriptError.OutOfMemory;
        };
        _ = std.base64.standard.Decoder.decode(decoded, data) catch {
            allocator.free(decoded);
            return WorkerScriptError.InvalidUrl;
        };
        source = decoded;
    } else {
        // Percent-decode
        source = percentDecode(allocator, data) catch {
            return WorkerScriptError.OutOfMemory;
        };
    }

    // FetchedScript.init duplicates source, so free our allocation after
    const result = FetchedScript.init(allocator, source, url, content_type, true) catch {
        allocator.free(source);
        return WorkerScriptError.OutOfMemory;
    };

    // Free original allocation since init() duplicated it
    allocator.free(source);

    return result;
}

/// Handle blob: URL for worker scripts
///
/// Per HTML Standard § 10.2.5 and Fetch Standard § 4.3:
/// - Blob URLs must be same-origin with the requesting context
/// - The blob URL entry is used to obtain the blob object
/// - Returns the blob's bytes as the script source
///
/// This uses a callback-based approach to access the BlobURLStore,
/// which is registered by the browser context during initialization.
/// This design avoids circular module dependencies (html_core cannot import file).
fn handleBlobUrl(allocator: Allocator, url: []const u8) WorkerScriptError!FetchedScript {
    // Get the blob resolver callback
    const resolver = blob_resolver_callback orelse {
        // No resolver registered - blob URL resolution not available
        std.log.warn("handleBlobUrl: No blob resolver registered", .{});
        return WorkerScriptError.FetchFailed;
    };

    // Get the requesting origin for same-origin validation
    // Per spec, the origin comes from the creating context (document or worker)
    const origin = current_document_origin orelse {
        std.log.warn("handleBlobUrl: No document origin set for blob URL resolution", .{});
        return WorkerScriptError.FetchFailed;
    };

    // Call the resolver to get the blob data
    // The resolver handles:
    // 1. Looking up the blob URL in the BlobURLStore
    // 2. Validating same-origin policy
    // 3. Returning the blob's bytes and content type
    const result = resolver(allocator, url, origin) orelse {
        // Blob URL not found or cross-origin access denied
        std.log.warn("handleBlobUrl: Blob URL not found or access denied: {s}", .{url});
        return WorkerScriptError.FetchFailed;
    };

    // Validate content type is JavaScript
    // Per HTML spec, worker scripts must be JavaScript MIME type
    if (!isJavaScriptMimeType(result.content_type)) {
        std.log.warn("handleBlobUrl: Blob has non-JavaScript MIME type: {s}", .{result.content_type});
        if (result.owns_bytes) {
            allocator.free(@constCast(result.bytes));
        }
        return WorkerScriptError.ParseError;
    }

    // Create FetchedScript from blob data
    // Note: FetchedScript.init duplicates the source, so we free our copy after if owned
    const fetched = FetchedScript.init(
        allocator,
        result.bytes,
        url, // Blob URL is the final URL
        result.content_type,
        true, // Blob URLs are always same-origin (enforced by resolver)
    ) catch {
        if (result.owns_bytes) {
            allocator.free(@constCast(result.bytes));
        }
        return WorkerScriptError.OutOfMemory;
    };

    // Free the original bytes if we own them (FetchedScript made a copy)
    if (result.owns_bytes) {
        allocator.free(@constCast(result.bytes));
    }

    return fetched;
}

/// Fetch an HTTP(S) worker script using the fetch module.
///
/// HTML Standard §10.2.5 "Run a worker" step 9:
/// Creates an internal request with destination=worker and executes fetch.
fn fetchHttpWorkerScript(
    allocator: Allocator,
    url: []const u8,
    options: WorkerScriptFetchOptions,
) WorkerScriptError!FetchedScript {
    // Step 1: Create an internal request
    const internal_request = fetch.internal.InternalRequest.init(allocator, url) catch {
        return WorkerScriptError.OutOfMemory;
    };
    defer internal_request.deinit();

    // Step 2: Set request properties per HTML Standard §10.2.5
    // Set destination based on worker type
    internal_request.destination = if (options.is_import_scripts)
        .script // importScripts uses script destination
    else switch (options.worker_type) {
        .classic => .worker,
        .module => .worker,
    };

    // Set credentials mode
    internal_request.credentials_mode = switch (options.credentials) {
        .omit => .omit,
        .same_origin => .same_origin,
        .include => .include,
    };

    // Set mode - workers use same-origin by default
    internal_request.mode = .same_origin;

    // Set origin if provided
    if (options.origin) |org| {
        internal_request.origin = .{ .origin = org };
    }

    // Step 3: Execute fetch
    var fetch_result = fetch.algorithms.fetch(allocator, internal_request, .{}) catch |err| {
        return switch (err) {
            fetch.FetchError.OutOfMemory => WorkerScriptError.OutOfMemory,
            fetch.FetchError.NetworkError => WorkerScriptError.NetworkError,
            fetch.FetchError.AbortError => WorkerScriptError.NetworkError,
        };
    };
    defer fetch_result.timing_info.deinit();

    const response = fetch_result.response;
    defer response.deinit();

    // Step 4: Check for network error
    if (response.response_type == .@"error") {
        return WorkerScriptError.NetworkError;
    }

    // Step 5: Check status code
    if (response.status < 200 or response.status >= 300) {
        return WorkerScriptError.FetchFailed;
    }

    // Step 6: Validate Content-Type for JavaScript
    const content_type = response.header_list.get(allocator, "content-type") catch {
        return WorkerScriptError.OutOfMemory;
    } orelse "text/javascript";
    defer if (content_type.ptr != "text/javascript".ptr) allocator.free(content_type);
    if (!isValidWorkerScriptType(content_type, options.worker_type)) {
        return WorkerScriptError.ParseError;
    }

    // Step 7: Get response body
    const body_bytes = if (response.body) |body|
        body.getBytes()
    else
        return WorkerScriptError.FetchFailed;

    // Step 8: Get final URL (after redirects)
    const final_url = response.url() orelse url;

    // Step 9: Determine same-origin status
    const same_origin = if (options.origin) |org|
        isSameOrigin(org, final_url)
    else
        true;

    // Step 10: Create FetchedScript result
    return FetchedScript.init(
        allocator,
        body_bytes,
        final_url,
        content_type,
        same_origin,
    ) catch {
        return WorkerScriptError.OutOfMemory;
    };
}

/// Check if two URLs have the same origin
fn isSameOrigin(origin: []const u8, url: []const u8) bool {
    // Extract origin from URL
    const url_origin = extractOrigin(url) orelse return false;
    return std.mem.eql(u8, origin, url_origin);
}

/// Extract origin (scheme://host:port) from URL
fn extractOrigin(url: []const u8) ?[]const u8 {
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/");
    if (path_start) |ps| {
        return url[0 .. scheme_end + 3 + ps];
    }
    return url;
}

/// Resolve a relative URL against a base URL
/// Handles: "/path", "./relative", "../parent", "bare-name.js"
/// Returns null if no base URL is available
fn resolveRelativeUrl(allocator: Allocator, url: []const u8, base_url: ?[]const u8) !?[]u8 {
    // Get base URL - try provided base, then thread-local document origin
    const base = base_url orelse current_document_origin orelse return null;

    // Base must be an absolute URL (http:// or https://)
    if (!std.mem.startsWith(u8, base, "http://") and !std.mem.startsWith(u8, base, "https://")) {
        return null;
    }

    // Handle absolute path (starts with /)
    if (url.len > 0 and url[0] == '/') {
        // Extract origin from base URL
        const origin = extractOrigin(base) orelse return null;
        return try std.mem.concat(allocator, u8, &.{ origin, url });
    }

    // Handle relative path (./foo, ../foo, or bare name)
    // We need to resolve against the base URL's directory

    // Find the last / in the base URL path to get the directory
    const scheme_end = std.mem.indexOf(u8, base, "://") orelse return null;
    const after_scheme = base[scheme_end + 3 ..];
    const host_end = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
    const origin_len = scheme_end + 3 + host_end;

    // Get the path portion of base URL
    const base_path = if (origin_len < base.len) base[origin_len..] else "/";

    // Find the directory (everything up to and including last /)
    const last_slash = std.mem.lastIndexOf(u8, base_path, "/") orelse 0;
    const base_dir = base_path[0 .. last_slash + 1];

    // Handle ./ prefix (current directory)
    var relative_path = url;
    if (std.mem.startsWith(u8, relative_path, "./")) {
        relative_path = relative_path[2..];
    }

    // Handle ../ prefix (parent directory) - may be repeated
    var dir_components: std.ArrayList([]const u8) = .{};
    defer dir_components.deinit(allocator);

    // Split base_dir into components
    var dir_iter = std.mem.splitScalar(u8, base_dir, '/');
    while (dir_iter.next()) |component| {
        if (component.len > 0) {
            try dir_components.append(allocator, component);
        }
    }

    // Process ../ in relative path
    while (std.mem.startsWith(u8, relative_path, "../")) {
        if (dir_components.items.len > 0) {
            _ = dir_components.pop();
        }
        relative_path = relative_path[3..];
    }

    // Build the resolved path
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    // Add origin
    try result.appendSlice(allocator, base[0..origin_len]);

    // Add directory components
    for (dir_components.items) |component| {
        try result.append(allocator, '/');
        try result.appendSlice(allocator, component);
    }

    // Add the relative path
    try result.append(allocator, '/');
    try result.appendSlice(allocator, relative_path);

    return try result.toOwnedSlice(allocator);
}

/// Simple percent-decoding for data URLs
fn percentDecode(allocator: Allocator, input: []const u8) ![]u8 {
    // Count output size first
    var output_len: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |_| {
                output_len += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        output_len += 1;
        i += 1;
    }

    const result = try allocator.alloc(u8, output_len);
    errdefer allocator.free(result);

    var out_idx: usize = 0;
    i = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            if (std.fmt.parseInt(u8, input[i + 1 .. i + 3], 16)) |value| {
                result[out_idx] = value;
                out_idx += 1;
                i += 3;
                continue;
            } else |_| {}
        }
        result[out_idx] = input[i];
        out_idx += 1;
        i += 1;
    }

    return result;
}

// ============================================================================
// Fetch Multiple Scripts (importScripts)
// ============================================================================

/// Fetch multiple scripts for importScripts()
///
/// HTML Standard §10.2.4.2 "importScripts(urls)"
/// "For each url of urls... Fetch a classic worker-imported script"
pub fn fetchImportScripts(
    allocator: Allocator,
    urls: []const []const u8,
    base_url: []const u8,
    origin: ?[]const u8,
) WorkerScriptError![]FetchedScript {
    var scripts = allocator.alloc(FetchedScript, urls.len) catch {
        return WorkerScriptError.OutOfMemory;
    };
    errdefer {
        for (scripts) |*script| {
            script.deinit();
        }
        allocator.free(scripts);
    }

    for (urls, 0..) |url, i| {
        // For importScripts(), resolve relative URLs against the worker's script URL (base_url)
        // This ensures ./helper.js resolves correctly when called from a worker
        scripts[i] = try fetchWorkerScript(allocator, url, .{
            .is_import_scripts = true,
            .origin = if (base_url.len > 0) base_url else origin,
        });
    }

    return scripts;
}

// ============================================================================
// Check if Script Content-Type is Valid
// ============================================================================

/// Check if content type is valid for worker scripts
pub fn isValidWorkerScriptType(content_type: []const u8, worker_type: WorkerType) bool {
    // For classic workers: JavaScript MIME types
    if (worker_type == .classic) {
        if (isJavaScriptMimeType(content_type)) {
            return true;
        }
    }

    // For module workers: JavaScript module MIME types
    if (worker_type == .module) {
        if (isJavaScriptMimeType(content_type)) {
            return true;
        }
    }

    return false;
}

/// Check if a MIME type is a JavaScript MIME type
fn isJavaScriptMimeType(mime_type: []const u8) bool {
    // Get the essence (type/subtype without parameters)
    const essence = blk: {
        if (std.mem.indexOf(u8, mime_type, ";")) |pos| {
            break :blk mime_type[0..pos];
        }
        break :blk mime_type;
    };

    // Trim whitespace
    const trimmed = std.mem.trim(u8, essence, " \t");

    // Check against known JavaScript MIME types
    const js_types = [_][]const u8{
        "text/javascript",
        "application/javascript",
        "application/x-javascript",
        "text/ecmascript",
        "application/ecmascript",
        "text/jscript",
    };

    for (js_types) |js_type| {
        if (std.ascii.eqlIgnoreCase(trimmed, js_type)) {
            return true;
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "handleDataUrl - plain text JavaScript" {
    const allocator = std.testing.allocator;

    var script = try handleDataUrl(allocator, "data:text/javascript,console.log('hello')");
    defer script.deinit();

    try std.testing.expectEqualStrings("console.log('hello')", script.source);
    try std.testing.expectEqualStrings("text/javascript", script.content_type);
}

test "handleDataUrl - base64 encoded" {
    const allocator = std.testing.allocator;

    // "console.log('hi')" in base64
    var script = try handleDataUrl(allocator, "data:text/javascript;base64,Y29uc29sZS5sb2coJ2hpJyk=");
    defer script.deinit();

    try std.testing.expectEqualStrings("console.log('hi')", script.source);
}

test "handleDataUrl - default content type" {
    const allocator = std.testing.allocator;

    var script = try handleDataUrl(allocator, "data:,var x = 1");
    defer script.deinit();

    try std.testing.expectEqualStrings("text/javascript", script.content_type);
}

test "isJavaScriptMimeType" {
    try std.testing.expect(isJavaScriptMimeType("text/javascript"));
    try std.testing.expect(isJavaScriptMimeType("application/javascript"));
    try std.testing.expect(isJavaScriptMimeType("text/javascript; charset=utf-8"));
    try std.testing.expect(!isJavaScriptMimeType("text/plain"));
    try std.testing.expect(!isJavaScriptMimeType("application/json"));
}

test "isValidWorkerScriptType" {
    try std.testing.expect(isValidWorkerScriptType("text/javascript", .classic));
    try std.testing.expect(isValidWorkerScriptType("application/javascript", .module));
    try std.testing.expect(!isValidWorkerScriptType("text/plain", .classic));
}

test "percentDecode" {
    const allocator = std.testing.allocator;

    const result = try percentDecode(allocator, "hello%20world");
    defer allocator.free(result);

    try std.testing.expectEqualStrings("hello world", result);
}

test "resolveRelativeUrl - absolute path" {
    const allocator = std.testing.allocator;

    const base_url = "http://localhost:8080/workers/worker.js";
    const result = try resolveRelativeUrl(allocator, "/scripts/helper.js", base_url);
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("http://localhost:8080/scripts/helper.js", result.?);
}

test "resolveRelativeUrl - current directory" {
    const allocator = std.testing.allocator;

    const base_url = "http://localhost:8080/workers/worker.js";
    const result = try resolveRelativeUrl(allocator, "./helper.js", base_url);
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("http://localhost:8080/workers/helper.js", result.?);
}

test "resolveRelativeUrl - parent directory" {
    const allocator = std.testing.allocator;

    const base_url = "http://localhost:8080/workers/sub/worker.js";
    const result = try resolveRelativeUrl(allocator, "../helper.js", base_url);
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("http://localhost:8080/workers/helper.js", result.?);
}

test "resolveRelativeUrl - bare name" {
    const allocator = std.testing.allocator;

    const base_url = "http://localhost:8080/workers/worker.js";
    const result = try resolveRelativeUrl(allocator, "helper.js", base_url);
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("http://localhost:8080/workers/helper.js", result.?);
}

test "resolveRelativeUrl - multiple parent directories" {
    const allocator = std.testing.allocator;

    const base_url = "http://localhost:8080/a/b/c/worker.js";
    const result = try resolveRelativeUrl(allocator, "../../helper.js", base_url);
    defer if (result) |r| allocator.free(r);

    try std.testing.expectEqualStrings("http://localhost:8080/a/helper.js", result.?);
}

test "resolveRelativeUrl - no base URL returns null" {
    const allocator = std.testing.allocator;

    const result = try resolveRelativeUrl(allocator, "./helper.js", null);

    try std.testing.expect(result == null);
}
