//! WebDriver Command Handlers
//!
//! Maps WebDriver HTTP endpoints to browser actions.

const std = @import("std");
const Allocator = std.mem.Allocator;
const protocol = @import("protocol.zig");
const Session = @import("session.zig").Session;
const SessionManager = @import("session.zig").SessionManager;

/// Command result
pub const CommandResult = struct {
    status: std.http.Status,
    body: []const u8,
};

/// Command handler context
pub const CommandContext = struct {
    allocator: Allocator,
    sessions: *SessionManager,
    method: std.http.Method,
    path: []const u8,
    body: []const u8,
};

/// Route a WebDriver command to its handler
pub fn handleCommand(ctx: CommandContext) !CommandResult {
    // Parse path components (use fixed-size buffer)
    var parts_buf: [16][]const u8 = undefined;
    var parts_count: usize = 0;

    var path_iter = std.mem.splitScalar(u8, ctx.path, '/');
    while (path_iter.next()) |part| {
        if (part.len > 0 and parts_count < parts_buf.len) {
            parts_buf[parts_count] = part;
            parts_count += 1;
        }
    }

    const parts = parts_buf[0..parts_count];

    // Route based on path
    if (parts.len == 0) {
        return errorResponse(ctx.allocator, .unknown_command, "Empty path");
    }

    // GET /status
    if (parts.len == 1 and std.mem.eql(u8, parts[0], "status")) {
        if (ctx.method == .GET) {
            return handleStatus(ctx.allocator);
        }
        return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
    }

    // POST /session - New session
    if (parts.len == 1 and std.mem.eql(u8, parts[0], "session")) {
        if (ctx.method == .POST) {
            return handleNewSession(ctx);
        }
        return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
    }

    // /session/{sessionId}/...
    if (parts.len >= 2 and std.mem.eql(u8, parts[0], "session")) {
        const session_id = parts[1];
        const session = ctx.sessions.getSession(session_id) orelse {
            return errorResponse(ctx.allocator, .invalid_session_id, "Session not found");
        };

        // DELETE /session/{sessionId} - Delete session
        if (parts.len == 2 and ctx.method == .DELETE) {
            return handleDeleteSession(ctx, session_id);
        }

        // /session/{sessionId}/url
        if (parts.len == 3 and std.mem.eql(u8, parts[2], "url")) {
            if (ctx.method == .POST) {
                return handleNavigate(ctx, session);
            }
            if (ctx.method == .GET) {
                return handleGetUrl(ctx.allocator, session);
            }
            return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
        }

        // GET /session/{sessionId}/title
        if (parts.len == 3 and std.mem.eql(u8, parts[2], "title") and ctx.method == .GET) {
            return handleGetTitle(ctx.allocator, session);
        }

        // POST /session/{sessionId}/back, /forward, /refresh (W3C WebDriver
        // 10.3-10.5)
        if (parts.len == 3 and ctx.method == .POST) {
            if (std.mem.eql(u8, parts[2], "back")) return handleHistory(ctx.allocator, session, .back);
            if (std.mem.eql(u8, parts[2], "forward")) return handleHistory(ctx.allocator, session, .forward);
            if (std.mem.eql(u8, parts[2], "refresh")) return handleHistory(ctx.allocator, session, .refresh);
        }

        // /session/{sessionId}/window (W3C WebDriver 11.1-11.5)
        if (parts.len >= 3 and std.mem.eql(u8, parts[2], "window")) {
            if (parts.len == 3) switch (ctx.method) {
                .GET => return handleGetWindowHandle(ctx.allocator, session),
                .POST => return handleSwitchToWindow(ctx, session),
                .DELETE => return handleCloseWindow(ctx, session, session_id),
                else => return errorResponse(ctx.allocator, .unknown_method, "Method not allowed"),
            };
            if (parts.len == 4 and std.mem.eql(u8, parts[3], "handles") and ctx.method == .GET) return handleGetWindowHandles(ctx.allocator, session);
            if (parts.len == 4 and std.mem.eql(u8, parts[3], "new") and ctx.method == .POST) return handleNewWindow(ctx.allocator, session);
        }

        // /session/{sessionId}/timeouts
        if (parts.len == 3 and std.mem.eql(u8, parts[2], "timeouts")) {
            if (ctx.method == .GET) {
                return handleGetTimeouts(ctx.allocator, session);
            }
            if (ctx.method == .POST) {
                return handleSetTimeouts(ctx, session);
            }
            return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
        }

        // /session/{sessionId}/execute/sync
        if (parts.len == 4 and std.mem.eql(u8, parts[2], "execute") and std.mem.eql(u8, parts[3], "sync")) {
            if (ctx.method == .POST) {
                return handleExecuteSync(ctx, session);
            }
            return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
        }

        // /session/{sessionId}/execute/async
        if (parts.len == 4 and std.mem.eql(u8, parts[2], "execute") and std.mem.eql(u8, parts[3], "async")) {
            if (ctx.method == .POST) {
                return handleExecuteAsync(ctx, session);
            }
            return errorResponse(ctx.allocator, .unknown_method, "Method not allowed");
        }

        return errorResponse(ctx.allocator, .unknown_command, "Unknown session command");
    }

    return errorResponse(ctx.allocator, .unknown_command, "Unknown command");
}

/// GET /status
fn handleStatus(allocator: Allocator) !CommandResult {
    const status = .{
        .ready = true,
        .message = "Crane WebDriver ready",
    };
    return .{
        .status = .ok,
        .body = try protocol.Response.success(allocator, status),
    };
}

/// POST /session
fn handleNewSession(ctx: CommandContext) !CommandResult {
    _ = protocol.NewSessionRequest.parse(ctx.allocator, ctx.body) catch {};

    const session = ctx.sessions.createSession() catch |err| {
        std.log.err("Failed to create session: {}", .{err});
        return errorResponse(ctx.allocator, .session_not_created, "Failed to create browser session");
    };

    // se:cdp (Selenium 4) and goog:chromeOptions.debuggerAddress
    // (chromedriver): the session's Browser over the Chrome DevTools
    // Protocol, as Playwright's SELENIUM_REMOTE_URL route takes it
    // (devtools_endpoint.zig). A build without CDP answers neither.
    session.cdp.start(ctx.allocator, session.host) catch |err| {
        const any: anyerror = err;
        if (any != error.CdpNotBuilt) std.log.warn("WebDriver: the session's CDP endpoint did not start: {}", .{err});
    };
    var url_buffer: [160]u8 = undefined;
    var address_buffer: [32]u8 = undefined;
    const cdp_url = session.cdp.url(&url_buffer);
    const debugger_address = session.cdp.debuggerAddress(&address_buffer);

    const Capabilities = struct {
        base: protocol.SessionInfo.SessionCapabilities = .{},
        @"se:cdp": ?[]const u8 = null,
        @"goog:chromeOptions": ?struct { debuggerAddress: []const u8 } = null,

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            inline for (@typeInfo(protocol.SessionInfo.SessionCapabilities).@"struct".field_names) |name| {
                try jws.objectField(name);
                try jws.write(@field(self.base, name));
            }
            if (self.@"se:cdp") |v| {
                try jws.objectField("se:cdp");
                try jws.write(v);
            }
            if (self.@"goog:chromeOptions") |v| {
                try jws.objectField("goog:chromeOptions");
                try jws.write(v);
            }
            try jws.endObject();
        }
    };
    const info = .{
        .sessionId = session.id,
        .capabilities = Capabilities{
            .@"se:cdp" = cdp_url,
            .@"goog:chromeOptions" = if (debugger_address) |a| .{ .debuggerAddress = a } else null,
        },
    };

    return .{
        .status = .ok,
        .body = try protocol.Response.success(ctx.allocator, info),
    };
}

/// DELETE /session/{sessionId}
fn handleDeleteSession(ctx: CommandContext, session_id: []const u8) !CommandResult {
    if (ctx.sessions.deleteSession(session_id)) {
        return .{
            .status = .ok,
            .body = try protocol.Response.successNull(ctx.allocator),
        };
    }
    return errorResponse(ctx.allocator, .invalid_session_id, "Session not found");
}

/// POST /session/{sessionId}/url
fn handleNavigate(ctx: CommandContext, session: *Session) !CommandResult {
    const req = protocol.NavigateRequest.parse(ctx.allocator, ctx.body) catch {
        return errorResponse(ctx.allocator, .invalid_argument, "Invalid navigate request");
    };

    session.navigate(req.url) catch |err| {
        std.log.err("Navigation failed: {}", .{err});
        return switch (err) {
            error.NoSuchWindow => errorResponse(ctx.allocator, .no_such_window, "No window"),
            error.Timeout => errorResponse(ctx.allocator, .timeout, "The page load timed out"),
            error.InvalidUrl => errorResponse(ctx.allocator, .invalid_argument, "Invalid URL"),
            else => errorResponse(ctx.allocator, .unknown_error, "Navigation failed"),
        };
    };

    return .{
        .status = .ok,
        .body = try protocol.Response.successNull(ctx.allocator),
    };
}

/// POST /session/{sessionId}/back, /forward, /refresh: the browser's own
/// back, forward and reload (HTML traverse the history by a delta, reload),
/// then the wait for the navigation to complete.
fn handleHistory(allocator: Allocator, session: *Session, action: enum { back, forward, refresh }) !CommandResult {
    const result = switch (action) {
        .back => session.back(),
        .forward => session.forward(),
        .refresh => session.refresh(),
    };
    result catch |err| return switch (err) {
        error.NoSuchWindow => errorResponse(allocator, .no_such_window, "No window"),
        error.Timeout => errorResponse(allocator, .timeout, "The page load timed out"),
        else => errorResponse(allocator, .unknown_error, "Navigation failed"),
    };
    return .{ .status = .ok, .body = try protocol.Response.successNull(allocator) };
}

/// GET /session/{sessionId}/window
fn handleGetWindowHandle(allocator: Allocator, session: *Session) !CommandResult {
    const handle = session.windowHandle(allocator) catch return errorResponse(allocator, .no_such_window, "No window");
    defer allocator.free(handle);
    return .{ .status = .ok, .body = try protocol.Response.success(allocator, handle) };
}

/// GET /session/{sessionId}/window/handles
fn handleGetWindowHandles(allocator: Allocator, session: *Session) !CommandResult {
    const handles = session.windowHandles(allocator) catch return errorResponse(allocator, .unknown_error, "No handles");
    defer {
        for (handles) |h| allocator.free(h);
        allocator.free(handles);
    }
    return .{ .status = .ok, .body = try protocol.Response.success(allocator, handles) };
}

/// POST /session/{sessionId}/window {handle}
fn handleSwitchToWindow(ctx: CommandContext, session: *Session) !CommandResult {
    const parsed = std.json.parseFromSlice(struct { handle: []const u8 }, ctx.allocator, ctx.body, .{ .ignore_unknown_fields = true }) catch
        return errorResponse(ctx.allocator, .invalid_argument, "Invalid handle");
    defer parsed.deinit();
    session.switchToWindow(parsed.value.handle) catch return errorResponse(ctx.allocator, .no_such_window, "No such window");
    return .{ .status = .ok, .body = try protocol.Response.successNull(ctx.allocator) };
}

/// DELETE /session/{sessionId}/window: the remaining handles; with none
/// left the session ends (W3C WebDriver 11.2 step 5).
fn handleCloseWindow(ctx: CommandContext, session: *Session, session_id: []const u8) !CommandResult {
    const closed = session.closeWindow(ctx.allocator) catch return errorResponse(ctx.allocator, .no_such_window, "No window");
    defer {
        for (closed.handles) |h| ctx.allocator.free(h);
        ctx.allocator.free(closed.handles);
    }
    const body = try protocol.Response.success(ctx.allocator, closed.handles);
    if (closed.ended) _ = ctx.sessions.deleteSession(session_id);
    return .{ .status = .ok, .body = body };
}

/// POST /session/{sessionId}/window/new
fn handleNewWindow(allocator: Allocator, session: *Session) !CommandResult {
    const handle = session.newWindow(allocator) catch return errorResponse(allocator, .unknown_error, "No new window");
    defer allocator.free(handle);
    return .{ .status = .ok, .body = try protocol.Response.success(allocator, .{ .handle = handle, .type = "tab" }) };
}

/// GET /session/{sessionId}/url
fn handleGetUrl(allocator: Allocator, session: *Session) !CommandResult {
    const url = session.getUrl(allocator) catch |err| {
        std.log.err("Get URL failed: {}", .{err});
        return errorResponse(allocator, .no_such_window, "No window");
    };
    defer allocator.free(url);

    return .{
        .status = .ok,
        .body = try protocol.Response.success(allocator, url),
    };
}

/// GET /session/{sessionId}/title
fn handleGetTitle(allocator: Allocator, session: *Session) !CommandResult {
    const title = session.getTitle(allocator) catch |err| {
        std.log.err("Get title failed: {}", .{err});
        return errorResponse(allocator, .no_such_window, "No window");
    };
    defer allocator.free(title);

    return .{
        .status = .ok,
        .body = try protocol.Response.success(allocator, title),
    };
}

/// GET /session/{sessionId}/timeouts
fn handleGetTimeouts(allocator: Allocator, session: *Session) !CommandResult {
    return .{
        .status = .ok,
        .body = try protocol.Response.success(allocator, session.timeouts),
    };
}

/// POST /session/{sessionId}/timeouts
fn handleSetTimeouts(ctx: CommandContext, session: *Session) !CommandResult {
    const timeouts = protocol.Timeouts.parse(ctx.allocator, ctx.body) catch {
        return errorResponse(ctx.allocator, .invalid_argument, "Invalid timeouts");
    };

    if (timeouts.script) |v| session.timeouts.script = v;
    if (timeouts.pageLoad) |v| session.timeouts.pageLoad = v;
    if (timeouts.implicit) |v| session.timeouts.implicit = v;

    return .{
        .status = .ok,
        .body = try protocol.Response.successNull(ctx.allocator),
    };
}

/// POST /session/{sessionId}/execute/sync
fn handleExecuteSync(ctx: CommandContext, session: *Session) !CommandResult {
    const req = protocol.ExecuteScriptRequest.parse(ctx.allocator, ctx.body) catch {
        return errorResponse(ctx.allocator, .invalid_argument, "Invalid script request");
    };

    const result = session.executeScript(ctx.allocator, req.script, req.args) catch |err| {
        std.log.err("Execute sync failed: {}", .{err});
        return switch (err) {
            error.NoSuchWindow => errorResponse(ctx.allocator, .no_such_window, "No window"),
            error.JavascriptError => errorResponse(ctx.allocator, .javascript_error, "Script error"),
            else => errorResponse(ctx.allocator, .unknown_error, "Script execution failed"),
        };
    };

    if (result) |value| {
        defer ctx.allocator.free(value);
        // Value is already JSON, wrap in response
        const body = try std.fmt.allocPrint(ctx.allocator, "{{\"value\":{s}}}", .{value});
        return .{
            .status = .ok,
            .body = body,
        };
    }

    return .{
        .status = .ok,
        .body = try protocol.Response.successNull(ctx.allocator),
    };
}

/// POST /session/{sessionId}/execute/async
fn handleExecuteAsync(ctx: CommandContext, session: *Session) !CommandResult {
    const req = protocol.ExecuteScriptRequest.parse(ctx.allocator, ctx.body) catch {
        return errorResponse(ctx.allocator, .invalid_argument, "Invalid script request");
    };

    const result = session.executeAsyncScript(ctx.allocator, req.script, req.args) catch |err| {
        std.log.err("Execute async failed: {}", .{err});
        return switch (err) {
            error.NoSuchWindow => errorResponse(ctx.allocator, .no_such_window, "No window"),
            error.JavascriptError => errorResponse(ctx.allocator, .javascript_error, "Script error"),
            error.ScriptTimeout => errorResponse(ctx.allocator, .script_timeout, "Script timeout"),
            else => errorResponse(ctx.allocator, .unknown_error, "Async script execution failed"),
        };
    };

    if (result) |value| {
        defer ctx.allocator.free(value);
        // Parse the JSON result to unwrap it properly
        // The value is a JSON string that was stringified by the callback
        // Try to parse it to check if double-stringified
        const inner_value = if (std.json.parseFromSlice(std.json.Value, ctx.allocator, value, .{})) |parsed| blk: {
            defer parsed.deinit();
            // Re-serialize the parsed value using Zig 0.15 API
            const serialized = std.json.Stringify.valueAlloc(ctx.allocator, parsed.value, .{}) catch {
                break :blk value;
            };
            break :blk serialized;
        } else |_| value;
        defer if (inner_value.ptr != value.ptr) ctx.allocator.free(inner_value);

        const body = try std.fmt.allocPrint(ctx.allocator, "{{\"value\":{s}}}", .{inner_value});
        return .{
            .status = .ok,
            .body = body,
        };
    }

    return .{
        .status = .ok,
        .body = try protocol.Response.successNull(ctx.allocator),
    };
}

/// Create error response
fn errorResponse(allocator: Allocator, code: protocol.ErrorCode, message: []const u8) !CommandResult {
    return .{
        .status = code.httpStatus(),
        .body = try protocol.Response.err(allocator, code, message),
    };
}
