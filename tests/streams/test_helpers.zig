//! Test helpers for streams tests
//! Provides access to internal infrastructure needed for testing

const message_port = @import("../../src/streams/internal/message_port.zig");

// Re-export message port utilities
pub const MessagePort = message_port.MessagePort;
pub const Message = message_port.Message;
pub const createMessagePortPair = message_port.createMessagePortPair;
pub const packAndPostMessage = message_port.packAndPostMessage;
pub const packAndPostMessageHandlingError = message_port.packAndPostMessageHandlingError;
