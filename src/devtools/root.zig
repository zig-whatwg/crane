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
/// The Browser-side record's tasks (install, attach, message, detach): what
/// the devtools thread posts, and a test drives a page session with.
pub const browser_side = @import("browser_side.zig");

pub const http = @import("http.zig");
pub const websocket_server = @import("websocket_server.zig");
pub const targets = @import("targets.zig");
pub const browser_target = @import("browser_target.zig");
pub const fetch_observer = @import("fetch_observer.zig");
pub const fetch_interception = @import("fetch_interception.zig");
pub const network_resources = @import("network_resources.zig");
/// The DOM agents' sink: the DOM's probes to every DOM-enabled session
/// (dom_events.zig).
pub const dom_events = @import("dom_events.zig");

/// The remote end's server: the devtools thread, its listener, pipe and
/// connections (server.zig).
pub const Server = @import("server.zig").Server;
/// An in-process client's end of a connection (Crane's MCP server).
pub const LocalLink = @import("server.zig").LocalLink;
/// Crane's own MCP server (lane mcp1), built with the CDP feature.
pub const mcp = @import("mcp/root.zig");
/// The DevTools front end /json/list names (server.zig frontend_revision).
pub const server_frontend_revision = @import("server.zig").frontend_revision;
pub const ServerOptions = @import("server.zig").Options;

test {
    std.testing.refAllDecls(@This());
    // Every handler compiles: the two dispatchers, instantiated.
    _ = &PageSession.handleMessage;
    _ = &struct {
        fn devtoolsThread(s: *targets.Session, a: std.mem.Allocator, c: *const json_rpc.Command) void {
            dispatch.dispatch(browser_target.Handlers, s, a, c);
        }
    }.devtoolsThread;
    _ = &struct {
        fn fetchOnDevtoolsThread(s: *targets.Session, a: std.mem.Allocator, c: *const json_rpc.Command) void {
            dispatch.dispatch(@import("server.zig").FetchDevtoolsHandlers, s, a, c);
        }
    }.fetchOnDevtoolsThread;
    _ = &Server.start;
    _ = &Server.stop;
    _ = &Server.waitUntilClosed;
}
