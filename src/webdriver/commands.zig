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

    const info = protocol.SessionInfo{
        .sessionId = session.id,
        .capabilities = .{},
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
        return errorResponse(ctx.allocator, .unknown_error, "Navigation failed");
    };

    return .{
        .status = .ok,
        .body = try protocol.Response.successNull(ctx.allocator),
    };
}

/// GET /session/{sessionId}/url
fn handleGetUrl(allocator: Allocator, session: *Session) !CommandResult {
    const url = session.getUrl() catch |err| {
        std.log.err("Get URL failed: {}", .{err});
        return errorResponse(allocator, .no_such_window, "No window");
    };

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
