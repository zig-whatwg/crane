//! The Chrome DevTools Protocol remote end (CDP part 1; the design is
//! tmp/plans/cdp-part1-design.md, the handler interface README.md).
//!
//! Compiled only with `-Dcdp=true` (the default); `-Dcdp=false` makes this
//! module's root unavailable.zig instead. It is a client of the host API
//! (BrowserHost, the Browser's tabs and host events) and of the platform's
//! devtools_transport capability; it names no impl and holds no engine
//! types - V8's inspector is reached through the engine protocol.

const std = @import("std");

/// Whether this build has the Chrome DevTools Protocol remote end.
pub const enabled = true;

/// What a request for CDP answers in a build without it (unavailable.zig).
pub const unavailable_message = "this Crane was built without CDP support (-Dcdp=false)";

/// The generated protocol types (tools/devtools_protocol_gen.zig).
pub const protocol = @import("protocol/root.zig");

pub const ids = @import("ids.zig");
pub const json_rpc = @import("json_rpc.zig");
pub const outbound = @import("outbound.zig");
pub const dispatch = @import("dispatch.zig");
pub const host_bridge = @import("host_bridge.zig");
pub const page_domains = @import("domains/page_domains.zig");

/// A command's answer, kept or given at once (dispatch.zig).
pub const Reply = dispatch.Reply;
pub const PageSession = @import("page_session.zig").PageSession;
pub const BrowserSide = @import("browser_side.zig").BrowserSide;

test {
    std.testing.refAllDecls(@This());
}
