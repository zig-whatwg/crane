//! The Security domain on page sessions (tmp/plans/cdp-part1-design.md 3.2):
//! Security.setIgnoreCertificateErrors switches the Browser's network
//! context's certificate checks at run time - NetworkContext's TLS options,
//! the ones WebDriver's acceptInsecureCerts sets at the start (Chrome:
//! content/browser/devtools/protocol/security_handler.cc
//! SetIgnoreCertificateErrors, which sets the certificate error override of
//! the page's network context). The browser target's command reaches every
//! context through `InsecureCertsTask` (browser_target.zig).

const fetch = @import("fetch");
const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");
const host_bridge = @import("../host_bridge.zig");
const BrowserSide = @import("../browser_side.zig").BrowserSide;

const S = protocol.Security;

/// Per-session state of the domain.
pub const State = struct {};

pub fn enable(_: *PageSession, _: S.enable.Params) !S.enable.Result {
    return .{};
}

pub fn disable(_: *PageSession, _: S.disable.Params) !S.disable.Result {
    return .{};
}

pub fn setIgnoreCertificateErrors(session: *PageSession, params: S.setIgnoreCertificateErrors.Params) !S.setIgnoreCertificateErrors.Result {
    const b = session.browser orelse return session.fail("Target closed");
    try setIgnore(b, params.ignore);
    return .{};
}

/// Browser thread: certificates of this Browser's requests from now on are
/// not verified (neither the chain nor the host name), or are again.
fn setIgnore(b: *host_bridge.Browser, ignore: bool) !void {
    const network = try b.scope.of(fetch.network.NetworkContext);
    network.tls.verify_peer = !ignore;
    network.tls.verify_host = !ignore;
}

/// Post `setIgnore` to a Browser's thread.
pub const InsecureCertsTask = struct {
    side: *BrowserSide,
    ignore: bool,

    pub fn post(side: *BrowserSide, ignore: bool) void {
        const task = side.allocator.create(InsecureCertsTask) catch return;
        task.* = .{ .side = side, .ignore = ignore };
        _ = side.host.post(task, run, drop);
    }

    fn run(context: ?*anyopaque, b: *host_bridge.Browser) void {
        const task: *InsecureCertsTask = @ptrCast(@alignCast(context.?));
        defer task.side.allocator.destroy(task);
        setIgnore(b, task.ignore) catch {};
    }

    fn drop(context: ?*anyopaque) void {
        const task: *InsecureCertsTask = @ptrCast(@alignCast(context.?));
        task.side.allocator.destroy(task);
    }
};
