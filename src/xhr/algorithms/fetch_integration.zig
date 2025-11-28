//! XHR Fetch Integration
//!
//! Integrates XMLHttpRequest with the WHATWG Fetch infrastructure.
//! Replaces simple_fetch.zig with real Fetch API usage.
//!
//! WHATWG XHR Spec: https://xhr.spec.whatwg.org/
//! WHATWG Fetch Spec: https://fetch.spec.whatwg.org/

const std = @import("std");
const Allocator = std.mem.Allocator;
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ResponseProcessor = @import("response.zig").ResponseProcessor;
const UploadTracker = @import("upload.zig").UploadTracker;

// Fetch infrastructure - use module import to avoid cross-module file conflicts
const fetch_mod = @import("fetch");
const InternalRequest = fetch_mod.internal.InternalRequest;
const InternalResponse = fetch_mod.internal.InternalResponse;
const FetchParams = fetch_mod.internal.FetchParams;
const FetchController = fetch_mod.internal.FetchController;
const FetchTimingInfo = fetch_mod.internal.FetchTimingInfo;

/// Fetch context - passed as user data to callbacks
const FetchContext = struct {
    allocator: Allocator,
    state: *XMLHttpRequestState,
    processor: *ResponseProcessor,
    upload_tracker: ?*UploadTracker,
};

/// Fetch using real Fetch infrastructure
///
/// This integrates XHR with the WHATWG Fetch API by:
/// 1. Creating an InternalRequest from XHR state
/// 2. Setting up FetchParams with streaming callbacks
/// 3. Running the fetch algorithm
/// 4. Handling response via ResponseProcessor
pub fn fetch(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
    processor: *ResponseProcessor,
    upload_tracker: ?*UploadTracker,
) !void {
    const allocator = state.allocator;

    // Create fetch context for callbacks
    const context = try allocator.create(FetchContext);
    errdefer allocator.destroy(context);

    context.* = .{
        .allocator = allocator,
        .state = state,
        .processor = processor,
        .upload_tracker = upload_tracker,
    };

    // Create InternalRequest from XHR state
    const request = try createRequest(allocator, state, body);
    errdefer request.deinit();

    // Create FetchController
    const controller = try FetchController.init(allocator);
    errdefer controller.deinit();

    // Create FetchTimingInfo
    var timing_info = FetchTimingInfo.init(allocator);
    errdefer timing_info.deinit();

    // Create FetchParams with streaming callbacks
    const params = try FetchParams.init(allocator, request, controller, &timing_info);
    errdefer params.deinit();

    // Set up streaming callbacks
    params.process_response = processResponseCallback;
    params.process_response_body_chunk = processResponseBodyChunkCallback;
    params.process_response_end_of_body = processResponseEndOfBodyCallback;

    // TODO: Implement real fetch call
    // For now, simulate with mock data like simple_fetch
    try simulateFetch(context);

    // Cleanup
    allocator.destroy(context);
}

/// Create InternalRequest from XHR state
fn createRequest(
    allocator: Allocator,
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !*InternalRequest {
    const request = try InternalRequest.init(allocator);
    errdefer request.deinit();

    // Set method
    if (state.request_method) |method| {
        try request.setMethod(method);
    }

    // Set URL
    if (state.request_url) |url| {
        try request.addUrl(url);
    }

    // Set headers from state.author_request_headers
    // TODO: Copy headers when header list implementation is available

    // Set body if provided
    if (body) |b| {
        // TODO: Set body when Body implementation is integrated
        _ = b;
    }

    // XHR always uses CORS mode
    request.mode = .cors;

    // Set credentials based on withCredentials
    request.credentials_mode = if (state.cross_origin_credentials) .include else .same_origin;

    // Set timeout
    if (state.timeout > 0) {
        request.timeout_ms = state.timeout;
    }

    return request;
}

// =============================================================================
// Callbacks
// =============================================================================

/// Process response callback - called when response headers received
fn processResponseCallback(response: *InternalResponse) void {
    // TODO: Extract context from response or use thread-local storage
    // For now, this is a placeholder
    _ = response;
    std.log.debug("XHR Fetch: processResponse called", .{});
}

/// Process response body chunk callback - called for each chunk during streaming
fn processResponseBodyChunkCallback(chunk: []const u8) void {
    // TODO: Extract context to call processor.processResponseBodyChunk(chunk)
    std.log.debug("XHR Fetch: received chunk of {} bytes", .{chunk.len});
}

/// Process response end of body callback - called when response complete
fn processResponseEndOfBodyCallback(response: *InternalResponse) void {
    _ = response;
    std.log.debug("XHR Fetch: processResponseEndOfBody called", .{});
}

// =============================================================================
// Temporary Simulation (until real Fetch is integrated)
// =============================================================================

/// Simulate fetch with mock data
///
/// This is a temporary implementation that mimics simple_fetch.zig behavior
/// until we have real HTTP networking integrated.
fn simulateFetch(context: *FetchContext) !void {
    // Simulate upload progress if body exists
    if (context.upload_tracker) |tracker| {
        // Simulate uploading in chunks
        const total_size = 1024; // Mock body size
        const chunk_size = 256;
        var uploaded: usize = 0;

        while (uploaded < total_size) {
            const remaining = total_size - uploaded;
            const size = @min(chunk_size, remaining);

            _ = tracker.onChunk(size);
            uploaded += size;
        }

        context.state.upload_complete_flag = true;
    } else {
        context.state.upload_complete_flag = true;
    }

    // Process response headers
    context.processor.processResponse();

    // Simulate response body in chunks
    const mock_response = "Mock response from Fetch integration (fetch_integration.zig)";
    const chunk_size = 15;
    var offset: usize = 0;

    while (offset < mock_response.len) {
        const remaining = mock_response.len - offset;
        const size = @min(chunk_size, remaining);
        const chunk = mock_response[offset .. offset + size];

        try context.processor.processResponseBodyChunk(chunk);
        offset += size;
    }

    // Process end of body
    context.processor.processResponseEndOfBody();
}
