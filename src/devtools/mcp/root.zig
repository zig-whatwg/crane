//! Crane's own Model Context Protocol server (lane mcp1; design
//! tmp/plans/mcp1-design.md; roadmap cdp-mcp): the tools of the pinned
//! chrome-devtools-mcp (v1.13.0), compiled into Crane with the CDP feature
//! (`-Dcdp`) - no Node, no process of its own. Each tool is the sequence of
//! CDP commands chrome-devtools-mcp's tool sends through Puppeteer, sent to
//! this Crane's own devtools server over an in-process session link
//! (`Server.openLocal`): one implementation of each behaviour, in the CDP
//! domain handlers, reached by the browser's paths only.

pub const protocol = @import("protocol.zig");
pub const client = @import("client.zig");
pub const session = @import("session.zig");
pub const response = @import("response.zig");
pub const tools = @import("tools.zig");
pub const collectors = @import("collectors.zig");
pub const console = @import("console.zig");
pub const wait = @import("wait.zig");
pub const url_check = @import("url_check.zig");
pub const text = @import("text.zig");
pub const server = @import("server.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
