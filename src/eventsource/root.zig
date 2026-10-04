//! HTML 9.2 server-sent event parsing and connection state, without an engine.
pub const Parser = @import("parser.zig").Parser;
pub const Message = @import("parser.zig").Message;
pub const Connection = @import("connection.zig").Connection;
pub const Registry = @import("registry.zig").Registry;
