//! Mock Fetch for XHR Week 4 Implementation
//!
//! Temporary mock until real Fetch integration is complete.
//! TODO: Replace with real Fetch from src/fetch/

const std = @import("std");
const xhr_root = @import("../root.zig");
const state_machine = xhr_root.state_machine;
const XMLHttpRequestState = state_machine.XMLHttpRequestState;
const ReadyState = state_machine.ReadyState;

/// Mock fetch - simulates successful request
pub fn fetch(
    state: *XMLHttpRequestState,
    body: ?[]const u8,
) !void {
    _ = body;

    // Simulate headers received
    state.changeState(.HEADERS_RECEIVED);

    // Simulate loading
    state.changeState(.LOADING);

    // Mock response body
    const mock_response = "Mock response data";
    try state.received_bytes.appendSlice(state.allocator, mock_response);

    // Simulate completion
    state.changeState(.DONE);
    state.send_flag = false;
}
