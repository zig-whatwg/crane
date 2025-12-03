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

    // Step 3: For HTTP(S) URLs, need actual fetch
    if (std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://")) {
        // In a full implementation, this would:
        // 1. Create InternalRequest with destination = .worker
        // 2. Set credentials mode based on options
        // 3. Execute fetch
        // 4. Return script source from response body

        // For now, return a stub indicating fetch is needed
        // The actual fetch integration happens when wiring to the full fetch module
        return WorkerScriptError.FetchFailed;
    }

    // Step 4: Check for import scripts mode (stricter)
    if (options.is_import_scripts) {
        // importScripts() only works with classic scripts
        if (options.worker_type == .module) {
            return WorkerScriptError.ModuleNotAllowed;
        }
    }

    // Step 5: For other URLs (file:, etc.), return error
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
fn handleBlobUrl(allocator: Allocator, url: []const u8) WorkerScriptError!FetchedScript {
    _ = allocator;
    _ = url;
    // Blob URLs require access to the blob store
    // For now, return an error
    return WorkerScriptError.FetchFailed;
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
    _ = base_url; // For URL resolution

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
        scripts[i] = try fetchWorkerScript(allocator, url, .{
            .is_import_scripts = true,
            .origin = origin,
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
