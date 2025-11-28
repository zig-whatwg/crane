//! Simplified Fetch for XHR Week 4
//!
//! Temporary simplified fetch implementation for development.
//! TODO: Replace with real Fetch integration from src/fetch/

const std = @import("std");
const xhr_root = @import("../root.zig");
const XMLHttpRequestState = xhr_root.state_machine.XMLHttpRequestState;
const ResponseProcessor = @import("response.zig").ResponseProcessor;
const UploadTracker = @import("upload.zig").UploadTracker;

/// Simplified fetch - simulates async request
pub fn fetch(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
    processor: *ResponseProcessor,
    upload_tracker: ?*UploadTracker,
) !void {
    // Simulate upload progress if body exists
    if (body) |b| {
        if (upload_tracker) |tracker| {
            // Simulate uploading in chunks
            const chunk_size = 1024;
            var uploaded: usize = 0;
            while (uploaded < b.len) {
                const remaining = b.len - uploaded;
                const size = @min(chunk_size, remaining);

                _ = tracker.onChunk(size);
                uploaded += size;
            }

            // Mark upload complete
            state.upload_complete_flag = true;
        }
    } else {
        state.upload_complete_flag = true;
    }

    // Process response headers
    processor.processResponse();

    // Simulate response body in chunks
    const mock_response = "Mock response data from simplified fetch";
    const chunk_size = 10;
    var offset: usize = 0;

    while (offset < mock_response.len) {
        const remaining = mock_response.len - offset;
        const size = @min(chunk_size, remaining);
        const chunk = mock_response[offset .. offset + size];

        try processor.processResponseBodyChunk(chunk);
        offset += size;
    }

    // Process end of body
    processor.processResponseEndOfBody();
}
