//! set_logpoints' model, as chrome-devtools-mcp v1.13.0 builds it
//! (src/LogpointManager.ts, src/formatters/LogpointFormatter.ts,
//! src/devtools/DevtoolsUtils.ts createTargetUniverse and waitForSourceMaps;
//! Copyright 2026 Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md) over the
//! DevTools frontend's BreakpointManager, CompilerScriptMapping and
//! SourceMapManager, which it runs in a second CDP session on the page - its
//! "DevTools universe". The frontend's parts are reproduced, not copied
//! (devtools-frontend, BSD-3-Clause, Copyright The Chromium Authors;
//! THIRD_PARTY_NOTICES.md: front_end/models/breakpoints/BreakpointManager.ts
//! Breakpoint / ModelBreakpoint / Storage.computeId and backendCondition,
//! front_end/models/bindings/CompilerScriptMapping.ts, ResourceScriptMapping.ts
//! and DebuggerWorkspaceBinding.ts normalizeUILocation,
//! front_end/core/sdk/SourceMap.ts, SourceMapManager.ts, DebuggerModel.ts,
//! Script.ts):
//!
//! - the universe: a second session, attached the first time a page tool
//!   runs on the page (McpPage.init), its Debugger enabled as DevTools does
//!   with "skip all pauses" set - so a `debugger` statement never pauses,
//!   while a breakpoint's condition still runs;
//! - the workspace: the document's URL, each parsed script's URL, and the
//!   original source URLs of every attached source map (loaded lazily until
//!   logpoints exist, then eagerly so reloads and rebuilt bundles re-resolve);
//! - a logpoint: normalized through `DebuggerWorkspaceBinding` (so a generated
//!   location covered by a source map moves to its original source), kept by
//!   (url, from_source_map, line, column), bound at one or more backend
//!   `Debugger.setBreakpointByUrl` positions (`ModelBreakpoint.currentState`),
//!   with condition `/** DEVTOOLS_LOGPOINT */ console.log(<expression>)` and
//!   sourceURL `debugger://logpoint`.
//!
//! Minified-name substitution (NamesResolver) is batch 4b item 3c.

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const fetch = @import("fetch");
const session_mod = @import("session.zig");
const Session = session_mod.Session;
const Page = session_mod.Page;
const str = session_mod.str;
const paths_mod = @import("paths.zig");
pub const source_map = @import("source_map.zig");
pub const SourceMap = source_map.SourceMap;

/// LOGPOINT_FORMAT.
pub const logpoint_format = "<url>:<lineNumber>[:<columnNumber>] <expression>";

/// LogpointManager's SOURCE_MAP_LOAD_TIMEOUT_MS.
pub const default_source_map_timeout_ms: u32 = 5_000;

/// One logpoint as the tool's text gives it (parseLogpoint): a 1-based line
/// and column, all slices of that text.
pub const Request = struct {
    url: []const u8,
    line: u64,
    column: ?u64,
    expression: []const u8,
};

/// What parseLogpoint makes of `text`: the logpoint, or its error message.
pub const Parsed = union(enum) {
    ok: Request,
    invalid,
    not_one_based,
};

/// JavaScript's String.prototype.trim and \s, for ASCII.
fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0b or c == 0x0c;
}

fn digitsAt(text: []const u8, start: usize) usize {
    var end = start;
    while (end < text.len and std.ascii.isDigit(text[end])) end += 1;
    return end - start;
}

/// Number(digits): exact up to 2^64-1, saturated past it.
fn number(digits: []const u8) u64 {
    return std.fmt.parseInt(u64, digits, 10) catch std.math.maxInt(u64);
}

/// parseLogpoint: `/^(\S+?):(\d+)(?::(\d+))?\s+(\S.*)$/s` on the trimmed
/// text - the location is the shortest prefix ending in one or two numbers
/// and whitespace (a URL may hold colons: a port) - then the 1-based check.
pub fn parse(text: []const u8) Parsed {
    const t = std.mem.trim(u8, text, " \t\n\r\x0b\x0c");
    var i: usize = 1;
    while (i < t.len) : (i += 1) {
        // \S+? cannot cross whitespace: no later colon can start a match.
        if (isSpace(t[i - 1])) break;
        if (t[i] != ':') continue;
        const line_start = i + 1;
        const line_len = digitsAt(t, line_start);
        if (line_len == 0) continue;
        const after_line = line_start + line_len;
        var column: ?[]const u8 = null;
        var rest_start = after_line;
        // (?::(\d+))? first, as the greedy group tries.
        if (after_line < t.len and t[after_line] == ':') {
            const column_len = digitsAt(t, after_line + 1);
            const after_column = after_line + 1 + column_len;
            if (column_len > 0 and after_column < t.len and isSpace(t[after_column])) {
                column = t[after_line + 1 .. after_column];
                rest_start = after_column;
            }
        }
        // \s+(\S.*)$: whitespace, then the rest from its first non-space.
        if (rest_start >= t.len or !isSpace(t[rest_start])) continue;
        var expression_start = rest_start;
        while (expression_start < t.len and isSpace(t[expression_start])) expression_start += 1;
        if (expression_start >= t.len) continue;
        const request: Request = .{
            .url = t[0..i],
            .line = number(t[line_start..after_line]),
            .column = if (column) |c| number(c) else null,
            .expression = t[expression_start..],
        };
        if (request.line < 1 or (request.column != null and request.column.? == 0)) return .not_one_based;
        return .{ .ok = request };
    }
    return .invalid;
}

/// Background HTTP/HTTPS source map loader. The `LibcurlBackend` is created on
/// the MCP thread before spawning and destroyed only after `joinThread`, while
/// cancellation uses `backend.getBackend().abort()` (an atomic store), so there
/// are no data races or dangling threads on teardown.
pub const MapLoader = struct {
    allocator: Allocator,
    compiled_url: []u8,
    resolved_map_url: []u8,
    backend: *fetch.network.LibcurlBackend,
    thread: platform.Thread,
    done: std.atomic.Value(bool) = .init(false),
    result: ?*SourceMap = null,

    pub fn start(allocator: Allocator, compiled_url: []const u8, resolved_map_url: []const u8) !*MapLoader {
        const loader = try allocator.create(MapLoader);
        errdefer allocator.destroy(loader);
        const compiled_copy = try allocator.dupe(u8, compiled_url);
        errdefer allocator.free(compiled_copy);
        const map_copy = try allocator.dupe(u8, resolved_map_url);
        errdefer allocator.free(map_copy);
        const backend = try fetch.network.LibcurlBackend.init(allocator);
        errdefer backend.deinit();
        loader.* = .{
            .allocator = allocator,
            .compiled_url = compiled_copy,
            .resolved_map_url = map_copy,
            .backend = backend,
            .thread = undefined,
        };
        loader.thread = try platform.spawnThread(.{}, run, loader);
        return loader;
    }

    fn run(ctx: ?*anyopaque) callconv(.c) void {
        const self: *MapLoader = @ptrCast(@alignCast(ctx.?));
        defer self.done.store(true, .release);
        const request: fetch.NetworkRequest = .{
            .url = self.resolved_map_url,
            .method = "GET",
            .headers = &.{},
            .body = null,
            .connect_timeout_ms = 5_000,
            .timeout_ms = 30_000,
            .follow_redirects = true,
            .max_redirects = 20,
        };
        var response = self.backend.getBackend().send(self.allocator, &request) catch return;
        defer response.deinit();
        if (response.status < 200 or response.status >= 300) return;
        const body = response.body orelse return;
        self.result = source_map.parse(self.allocator, self.compiled_url, self.resolved_map_url, body) catch null;
    }

    /// Abort an in-flight load, join its thread, and free everything.
    pub fn cancel(self: *MapLoader) void {
        self.backend.getBackend().abort();
        platform.joinThread(self.thread);
        if (self.result) |sm| sm.deinit();
        self.destroyAfterJoin();
    }

    /// Reclaim a finished load (`done == true`), returning the parsed map or null.
    pub fn finish(self: *MapLoader) ?*SourceMap {
        platform.joinThread(self.thread);
        const sm = self.result;
        self.result = null;
        self.destroyAfterJoin();
        return sm;
    }

    fn destroyAfterJoin(self: *MapLoader) void {
        const alloc = self.allocator;
        self.backend.deinit();
        alloc.free(self.compiled_url);
        alloc.free(self.resolved_map_url);
        alloc.destroy(self);
    }
};

pub const MapState = union(enum) {
    none,
    loading: *MapLoader,
    loaded: *SourceMap,
    failed,
};

/// A script V8 parsed in the page (Debugger.scriptParsed on the universe's
/// session): what DevTools' Script keeps of it for logpoints. OWNED.
pub const Script = struct {
    id: []u8,
    url: []u8,
    source_map_url: []u8,
    has_source_url: bool,
    has_syntax_error: bool,
    start_line: i64,
    start_column: i64,
    end_line: i64,
    end_column: i64,
    context_id: i64,
    parse_order: u64,
    map_state: MapState = .none,
    /// Eager wait already ran once for this script (avoids repeated waits on a
    /// permanently stuck map during non-logpoint tool calls).
    eager_waited: bool = false,

    /// Script.isInlineScript.
    pub fn isInlineScript(self: *const Script) bool {
        const starts_at_zero = self.start_line == 0 and self.start_column == 0;
        return self.url.len != 0 and !starts_at_zero;
    }

    /// Script.containsLocation.
    pub fn containsLocation(self: *const Script, line: i64, column: i64) bool {
        const after_start = (line == self.start_line and column >= self.start_column) or line > self.start_line;
        const before_end = line < self.end_line or (line == self.end_line and column <= self.end_column);
        return after_start and before_end;
    }

    /// Script.rawLocationToRelativeLocation.
    pub fn rawToRelative(self: *const Script, line: i64, column: i64) struct { line: i64, column: i64 } {
        var l = line;
        var c = column;
        if (!self.has_source_url and self.isInlineScript()) {
            l -= self.start_line;
            if (l == 0) c -= self.start_column;
        }
        return .{ .line = l, .column = c };
    }

    /// Script.relativeLocationToRawLocation.
    pub fn relativeToRaw(self: *const Script, line: i64, column: i64) struct { line: i64, column: i64 } {
        var l = line;
        var c = column;
        if (!self.has_source_url and self.isInlineScript()) {
            if (l == 0) c += self.start_column;
            l += self.start_line;
        }
        return .{ .line = l, .column = c };
    }

    fn deinit(self: *Script, allocator: Allocator) void {
        switch (self.map_state) {
            .loading => |loader| loader.cancel(),
            .loaded => |sm| sm.deinit(),
            .none, .failed => {},
        }
        self.map_state = .none;
        allocator.free(self.id);
        allocator.free(self.url);
        allocator.free(self.source_map_url);
    }
};

/// One backend position sent to `Debugger.setBreakpointByUrl`
/// (`ModelBreakpoint.currentState` / `Breakpoint.lastResolvedState`). OWNED.
pub const BackendPosition = struct {
    url: []u8,
    line: u64,
    column: ?u64,
    condition: []u8,

    pub fn dupe(self: *const BackendPosition, allocator: Allocator) Allocator.Error!BackendPosition {
        const u = try allocator.dupe(u8, self.url);
        errdefer allocator.free(u);
        const cond = try allocator.dupe(u8, self.condition);
        return .{ .url = u, .line = self.line, .column = self.column, .condition = cond };
    }

    pub fn eql(self: *const BackendPosition, other: *const BackendPosition) bool {
        return self.line == other.line and
            self.column == other.column and
            std.mem.eql(u8, self.url, other.url) and
            std.mem.eql(u8, self.condition, other.condition);
    }

    pub fn deinit(self: *BackendPosition, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.condition);
    }
};

/// One V8 resolved location for a backend breakpoint. OWNED.
pub const ResolvedLocation = struct {
    breakpoint_id: []u8,
    script_id: []u8,

    pub fn deinit(self: *ResolvedLocation, allocator: Allocator) void {
        allocator.free(self.breakpoint_id);
        allocator.free(self.script_id);
    }
};

/// One logpoint: DevTools' Breakpoint (its storage state's url, resourceType,
/// line, column and condition) with its ModelBreakpoint's backend positions,
/// backend ids, and the scripts V8 resolved it in. OWNED.
pub const Logpoint = struct {
    url: []u8,
    /// True when the breakpoint's home UISourceCode is from a source map
    /// (`isFromSourceMap`).
    from_source_map: bool = false,
    /// 0-based, as the model keeps it.
    line: u64,
    column: ?u64,
    expression: []u8,
    /// ModelBreakpoint.#currentState.
    current_state: std.ArrayList(BackendPosition) = .empty,
    /// Breakpoint.#lastResolvedState.
    last_resolved_state: std.ArrayList(BackendPosition) = .empty,
    /// ModelBreakpoint.#breakpointIds.
    breakpoint_ids: std.ArrayList([]u8) = .empty,
    /// The scripts of its resolved locations (Breakpoint.#uiLocations).
    resolved: std.ArrayList(ResolvedLocation) = .empty,

    /// Breakpoint.bound.
    pub fn bound(self: *const Logpoint) bool {
        return self.resolved.items.len != 0;
    }

    pub fn clearResolved(self: *Logpoint, allocator: Allocator) void {
        for (self.resolved.items) |*loc| loc.deinit(allocator);
        self.resolved.clearRetainingCapacity();
    }

    pub fn clearCurrentState(self: *Logpoint, allocator: Allocator) void {
        for (self.current_state.items) |*pos| pos.deinit(allocator);
        self.current_state.clearRetainingCapacity();
    }

    pub fn clearLastResolvedState(self: *Logpoint, allocator: Allocator) void {
        for (self.last_resolved_state.items) |*pos| pos.deinit(allocator);
        self.last_resolved_state.clearRetainingCapacity();
    }

    pub fn clearBreakpointIds(self: *Logpoint, allocator: Allocator) void {
        for (self.breakpoint_ids.items) |id| allocator.free(id);
        self.breakpoint_ids.clearRetainingCapacity();
    }

    pub fn destroy(self: *Logpoint, allocator: Allocator) void {
        allocator.free(self.url);
        allocator.free(self.expression);
        self.clearCurrentState(allocator);
        self.current_state.deinit(allocator);
        self.clearLastResolvedState(allocator);
        self.last_resolved_state.deinit(allocator);
        self.clearBreakpointIds(allocator);
        self.breakpoint_ids.deinit(allocator);
        self.clearResolved(allocator);
        self.resolved.deinit(allocator);
        allocator.destroy(self);
    }
};

/// A workspace UISourceCode identity (either a served script/document or an
/// original source file from a source map).
pub const UiSource = struct {
    url: []const u8,
    from_source_map: bool,
};

/// A resolved location in a specific parsed script (0-based).
pub const RawLocation = struct {
    script_idx: usize,
    url: []const u8,
    line: u64,
    column: u64,
};

/// A normalized UI location (`DebuggerWorkspaceBinding.normalizeUILocation`).
pub const NormalizedLocation = struct {
    url: []const u8,
    from_source_map: bool,
    line: u64,
    column: ?u64,
};

pub const WaitOutcome = enum { complete, timed_out };

/// A page's logpoint state: the universe's scripts (and their source maps) and
/// the logpoints (the manager's #records, in their order).
pub const State = struct {
    scripts: std.ArrayList(Script) = .empty,
    records: std.ArrayList(*Logpoint) = .empty,
    /// McpPage's #logpointManager exists: made on the first call that names
    /// a logpoint.
    manager: bool = false,
    /// SourceMapManager.lazyLoadingSettingDescriptor: true until logpoints
    /// exist on the page, then false so reloads and rebuilt bundles re-resolve.
    lazy_loading: bool = true,
    next_parse_order: u64 = 1,
    /// Set when a source map attaches and existing source-mapped logpoints may
    /// need their backend breakpoints updated.
    rebind_needed: bool = false,
    /// Wait budget for loading source maps (LogpointManager's 5 s default;
    /// overridable in tests so verify-mode timeout tests run fast).
    source_map_timeout_ms: u32 = default_source_map_timeout_ms,

    pub fn deinit(self: *State, allocator: Allocator) void {
        for (self.scripts.items) |*s| s.deinit(allocator);
        self.scripts.deinit(allocator);
        for (self.records.items) |r| r.destroy(allocator);
        self.records.deinit(allocator);
        self.* = .{};
    }

    /// Timeout seconds as reported in Chrome's error messages (5 seconds by
    /// default; rounds sub-second test overrides to 5 so messages match).
    pub fn timeoutSecondsLabel(self: *const State) u32 {
        return if (self.source_map_timeout_ms >= 1_000) self.source_map_timeout_ms / 1_000 else default_source_map_timeout_ms / 1_000;
    }

    /// An event of the universe's session.
    pub fn debuggerEvent(
        self: *State,
        allocator: Allocator,
        method: []const u8,
        params: std.json.ObjectMap,
        page_url: []const u8,
        paths: *paths_mod.Policy,
    ) !void {
        if (std.mem.eql(u8, method, "Debugger.scriptParsed")) {
            const id = str(params.get("scriptId"));
            if (id.len == 0) return;
            for (self.scripts.items) |s| if (std.mem.eql(u8, s.id, id)) return;
            const id_copy = try allocator.dupe(u8, id);
            errdefer allocator.free(id_copy);
            const url_copy = try allocator.dupe(u8, str(params.get("url")));
            errdefer allocator.free(url_copy);
            const sm_copy = try allocator.dupe(u8, str(params.get("sourceMapURL")));
            errdefer allocator.free(sm_copy);
            const has_source_url = if (params.get("hasSourceURL")) |v| v == .bool and v.bool else false;
            const has_syntax_error = if (params.get("hasSyntaxError")) |v| v == .bool and v.bool else false;
            const order = self.next_parse_order;
            self.next_parse_order += 1;
            try self.scripts.append(allocator, .{
                .id = id_copy,
                .url = url_copy,
                .source_map_url = sm_copy,
                .has_source_url = has_source_url,
                .has_syntax_error = has_syntax_error,
                .start_line = int(params.get("startLine")),
                .start_column = int(params.get("startColumn")),
                .end_line = int(params.get("endLine")),
                .end_column = int(params.get("endColumn")),
                .context_id = int(params.get("executionContextId")),
                .parse_order = order,
            });
            // When logpoints exist, source maps load eagerly (LogpointManager
            // #setLazySourceMapLoading(false)).
            if (!self.lazy_loading) {
                const idx = self.scripts.items.len - 1;
                self.startMapLoad(allocator, &self.scripts.items[idx], page_url, paths);
            }
            return;
        }
        if (std.mem.eql(u8, method, "Debugger.breakpointResolved")) {
            const id = str(params.get("breakpointId"));
            const location = params.get("location") orelse return;
            if (location != .object) return;
            const script_id = str(location.object.get("scriptId"));
            for (self.records.items) |r| {
                const owns = for (r.breakpoint_ids.items) |bp_id| {
                    if (std.mem.eql(u8, bp_id, id)) break true;
                } else false;
                if (!owns) continue;
                const bp_copy = try allocator.dupe(u8, id);
                errdefer allocator.free(bp_copy);
                const script_copy = try allocator.dupe(u8, script_id);
                errdefer allocator.free(script_copy);
                try r.resolved.append(allocator, .{ .breakpoint_id = bp_copy, .script_id = script_copy });
            }
        }
    }

    /// Start loading `script`'s source map if it has one and has not started.
    pub fn startMapLoad(
        self: *State,
        allocator: Allocator,
        script: *Script,
        page_url: []const u8,
        paths: *paths_mod.Policy,
    ) void {
        if (script.map_state != .none) return;
        if (script.source_map_url.len == 0 or script.has_syntax_error) return;

        var scratch = std.heap.ArenaAllocator.init(allocator);
        defer scratch.deinit();
        const tmp = scratch.allocator();

        // SourceMapManager.resolveRelativeSourceURL + ParsedURL.completeURL.
        const resolved_source_url = (source_map.completeUrl(tmp, page_url, script.url) catch null) orelse script.url;
        const resolved_map_url = (source_map.completeUrl(tmp, resolved_source_url, script.source_map_url) catch null) orelse {
            script.map_state = .failed;
            return;
        };

        // data: inline source map - decode and parse immediately.
        if (source_map.schemeIs(resolved_map_url, "data:")) {
            var data = (fetch.processDataUrl(allocator, resolved_map_url) catch {
                script.map_state = .failed;
                return;
            }) orelse {
                script.map_state = .failed;
                return;
            };
            defer data.deinit();
            const sm = source_map.parse(allocator, resolved_source_url, resolved_map_url, data.body) catch {
                script.map_state = .failed;
                return;
            };
            script.map_state = .{ .loaded = sm };
            self.rebind_needed = true;
            return;
        }

        // file: source map - subject to the server's path policy (McpContext.loadResource).
        if (source_map.schemeIs(resolved_map_url, "file:")) {
            const content = paths.readFileUrl(tmp, resolved_map_url) catch {
                script.map_state = .failed;
                return;
            };
            const sm = source_map.parse(allocator, resolved_source_url, resolved_map_url, content) catch {
                script.map_state = .failed;
                return;
            };
            script.map_state = .{ .loaded = sm };
            self.rebind_needed = true;
            return;
        }

        // http(s): load on a background thread so a slow map respects the 5 s
        // timeout while continuing in the background for a retry.
        if (source_map.schemeIs(resolved_map_url, "http:") or source_map.schemeIs(resolved_map_url, "https:")) {
            const loader = MapLoader.start(allocator, resolved_source_url, resolved_map_url) catch {
                script.map_state = .failed;
                return;
            };
            script.map_state = .{ .loading = loader };
            return;
        }

        script.map_state = .failed;
    }

    /// Reap any completed background source map loads. Returns true if any
    /// script still has a load in flight.
    pub fn pollLoads(self: *State) bool {
        var any_loading = false;
        for (self.scripts.items) |*s| {
            switch (s.map_state) {
                .loading => |loader| {
                    if (loader.done.load(.acquire)) {
                        if (loader.finish()) |sm| {
                            s.map_state = .{ .loaded = sm };
                            self.rebind_needed = true;
                        } else {
                            s.map_state = .failed;
                        }
                    } else {
                        any_loading = true;
                    }
                },
                else => {},
            }
        }
        return any_loading;
    }

    /// Start (if needed) and wait up to `source_map_timeout_ms` for the source
    /// maps of matching scripts (`only_url == null` waits for all scripts).
    /// Loads still pending at timeout keep running in the background.
    pub fn waitForMaps(self: *State, session: *Session, page: *Page, only_url: ?[]const u8) !WaitOutcome {
        for (self.scripts.items) |*s| {
            if (only_url) |u| if (!std.mem.eql(u8, s.url, u)) continue;
            if (s.source_map_url.len != 0 and !s.has_syntax_error and s.map_state == .none) {
                self.startMapLoad(session.allocator, s, page.url, &session.paths);
            }
        }
        const deadline = platform.monotonicMillis() + @as(i64, self.source_map_timeout_ms);
        while (true) {
            _ = self.pollLoads();
            var pending = false;
            for (self.scripts.items) |s| {
                if (only_url) |u| if (!std.mem.eql(u8, s.url, u)) continue;
                if (s.map_state == .loading) {
                    pending = true;
                    break;
                }
            }
            if (!pending) return .complete;
            if (platform.monotonicMillis() >= deadline) return .timed_out;
            _ = try session.client.pump(10 * std.time.ns_per_ms);
        }
    }

    /// A context went away (Runtime.executionContextDestroyed on the page's
    /// session): its scripts, their source maps, and the locations resolved in
    /// them (ModelBreakpoint.resetLocations on the global object's clear).
    pub fn contextDestroyed(self: *State, allocator: Allocator, context_id: i64) void {
        var i: usize = 0;
        while (i < self.scripts.items.len) {
            const s = &self.scripts.items[i];
            if (s.context_id != context_id) {
                i += 1;
                continue;
            }
            self.dropResolvedIn(allocator, s.id);
            s.deinit(allocator);
            _ = self.scripts.orderedRemove(i);
        }
    }

    /// Every context went away (Runtime.executionContextsCleared).
    pub fn contextsCleared(self: *State, allocator: Allocator) void {
        for (self.scripts.items) |*s| s.deinit(allocator);
        self.scripts.clearRetainingCapacity();
        for (self.records.items) |r| r.clearResolved(allocator);
    }

    fn dropResolvedIn(self: *State, allocator: Allocator, script_id: []const u8) void {
        for (self.records.items) |r| {
            var j: usize = 0;
            while (j < r.resolved.items.len) {
                if (std.mem.eql(u8, r.resolved.items[j].script_id, script_id)) {
                    var loc = r.resolved.orderedRemove(j);
                    loc.deinit(allocator);
                } else j += 1;
            }
        }
    }

    /// CompilerScriptMapping conflict/compatibility rule
    /// (`#shouldUseSourceMapForURL` + `compatibleForURL`): the newest parsed
    /// script mapping `source_url` sets the content/ignoreList baseline; older
    /// scripts remain active iff compatible with it.
    pub fn isActiveSourceMap(self: *const State, script_idx: usize, source_url: []const u8) bool {
        const sm = switch (self.scripts.items[script_idx].map_state) {
            .loaded => |m| m,
            else => return false,
        };
        var newest_order: u64 = 0;
        var newest_map: ?*const SourceMap = null;
        for (self.scripts.items) |s| {
            const candidate = switch (s.map_state) {
                .loaded => |m| m,
                else => continue,
            };
            if (!candidate.url_to_info.contains(source_url)) continue;
            if (newest_map == null or s.parse_order >= newest_order) {
                newest_order = s.parse_order;
                newest_map = candidate;
            }
        }
        const winner = newest_map orelse return false;
        return sm.compatibleForUrl(source_url, winner);
    }

    /// The workspace's Network project sources, in order: the document, each
    /// parsed script's URL (not `debugger://`), and each original source URL
    /// from an attached source map.
    pub fn uiSources(self: *const State, arena: Allocator, document: []const u8) Allocator.Error![]const UiSource {
        var out: std.ArrayList(UiSource) = .empty;
        if (isNetworkUrl(document)) {
            try out.append(arena, .{ .url = document, .from_source_map = false });
        }
        for (self.scripts.items) |s| {
            if (s.url.len == 0 or std.mem.startsWith(u8, s.url, "debugger://")) continue;
            const seen = for (out.items) |item| {
                if (!item.from_source_map and std.mem.eql(u8, item.url, s.url)) break true;
            } else false;
            if (!seen) try out.append(arena, .{ .url = s.url, .from_source_map = false });
        }
        for (self.scripts.items) |s| {
            const sm = switch (s.map_state) {
                .loaded => |m| m,
                else => continue,
            };
            for (sm.sourceUrls()) |src_url| {
                const seen = for (out.items) |item| {
                    if (item.from_source_map and std.mem.eql(u8, item.url, src_url)) break true;
                } else false;
                if (!seen) try out.append(arena, .{ .url = src_url, .from_source_map = true });
            }
        }
        return out.items;
    }

    /// Whether any script with `url` has a non-empty `sourceMapURL`.
    pub fn hasSourceMapUrl(self: *const State, url: []const u8) bool {
        for (self.scripts.items) |s| {
            if (std.mem.eql(u8, s.url, url) and s.source_map_url.len != 0 and !s.has_syntax_error) return true;
        }
        return false;
    }

    /// DebuggerWorkspaceBinding / CompilerScriptMapping + ResourceScriptMapping
    /// `uiLocationToRawLocations` (0-based line and column).
    pub fn uiLocationToRawLocations(
        self: *const State,
        arena: Allocator,
        source: UiSource,
        line: u64,
        column: u64,
    ) Allocator.Error![]const RawLocation {
        var out: std.ArrayList(RawLocation) = .empty;
        if (source.from_source_map) {
            for (self.scripts.items, 0..) |s, idx| {
                const sm = switch (s.map_state) {
                    .loaded => |m| m,
                    else => continue,
                };
                if (!sm.url_to_info.contains(source.url)) continue;
                if (!self.isActiveSourceMap(idx, source.url)) continue;
                const first = sm.sourceLineMapping(source.url, @intCast(line), @intCast(column)) orelse continue;
                const entries = try sm.findReverseEntries(arena, source.url, first.source_line, first.source_column, true);
                for (entries) |entry| {
                    const raw = s.relativeToRaw(entry.line, entry.column);
                    if (raw.line < 0 or raw.column < 0) continue;
                    try out.append(arena, .{
                        .script_idx = idx,
                        .url = s.url,
                        .line = @intCast(raw.line),
                        .column = @intCast(raw.column),
                    });
                }
            }
            return out.items;
        }
        // Non-source-map UISourceCode: external script (ResourceScriptMapping)
        // or inline script inside a document (ResourceMapping).
        for (self.scripts.items, 0..) |s, idx| {
            if (!std.mem.eql(u8, s.url, source.url)) continue;
            if (!s.has_source_url and s.isInlineScript() and !s.containsLocation(@intCast(line), @intCast(column))) continue;
            try out.append(arena, .{
                .script_idx = idx,
                .url = s.url,
                .line = line,
                .column = column,
            });
        }
        return out.items;
    }

    /// DebuggerWorkspaceBinding `rawLocationToUILocation`: CompilerScriptMapping
    /// first, falling back to the script's own URL.
    pub fn rawLocationToUiLocation(self: *const State, raw: RawLocation) NormalizedLocation {
        const s = &self.scripts.items[raw.script_idx];
        switch (s.map_state) {
            .loaded => |sm| {
                const rel = s.rawToRelative(@intCast(raw.line), @intCast(raw.column));
                if (sm.findEntry(rel.line, rel.column)) |entry| {
                    if (entry.source_url) |src_url| {
                        if (self.isActiveSourceMap(raw.script_idx, src_url) and entry.source_line >= 0 and entry.source_column >= 0) {
                            return .{
                                .url = src_url,
                                .from_source_map = true,
                                .line = @intCast(entry.source_line),
                                .column = @intCast(entry.source_column),
                            };
                        }
                    }
                }
            },
            else => {},
        }
        return .{
            .url = s.url,
            .from_source_map = false,
            .line = raw.line,
            .column = raw.column,
        };
    }

    /// DebuggerWorkspaceBinding.normalizeUILocation: round-trips through raw
    /// locations so a generated script location covered by a source map moves
    /// to its original source, and a mapped original line picks up its mapped
    /// source column.
    pub fn normalizeUiLocation(
        self: *const State,
        arena: Allocator,
        source: UiSource,
        line: u64,
        column: ?u64,
    ) Allocator.Error!NormalizedLocation {
        const raw_locations = try self.uiLocationToRawLocations(arena, source, line, column orelse 0);
        if (raw_locations.len > 0) {
            return self.rawLocationToUiLocation(raw_locations[0]);
        }
        return .{
            .url = source.url,
            .from_source_map = source.from_source_map,
            .line = line,
            .column = column,
        };
    }

    /// The record at (url, from_source_map, line, column): Storage.computeId's key.
    pub fn find(self: *const State, url: []const u8, from_source_map: bool, line: u64, column: ?u64) ?*Logpoint {
        for (self.records.items) |r| {
            if (r.from_source_map != from_source_map or r.line != line or !std.mem.eql(u8, r.url, url)) continue;
            if (r.column != column) continue;
            return r;
        }
        return null;
    }
};

/// Breakpoint.State.subset: true iff `state_a` is non-empty and every position
/// in `state_a` appears in `state_b`.
pub fn stateSubset(state_a: []const BackendPosition, state_b: []const BackendPosition) bool {
    if (state_a.len == 0 or state_b.len == 0) return false;
    for (state_a) |*a| {
        const found = for (state_b) |*b| {
            if (a.eql(b)) break true;
        } else false;
        if (!found) return false;
    }
    return true;
}

/// A document the workspace's Network project holds a source code for.
fn isNetworkUrl(url: []const u8) bool {
    return std.mem.startsWith(u8, url, "http://") or std.mem.startsWith(u8, url, "https://") or std.mem.startsWith(u8, url, "file://");
}

fn int(value: ?std.json.Value) i64 {
    const v = value orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

/// Breakpoint.backendCondition for a logpoint: LOGPOINT_PREFIX, the
/// expression, LOGPOINT_SUFFIX, and the condition's sourceURL.
pub fn backendCondition(arena: Allocator, expression: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "/** DEVTOOLS_LOGPOINT */ console.log({s})\n\n//# sourceURL=debugger://logpoint", .{expression});
}

/// The final path segment, lowercased (LogpointManager's baseName).
pub fn baseName(arena: Allocator, url: []const u8) ![]const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, url, '/');
    return std.ascii.allocLowerString(arena, if (slash) |s| url[s + 1 ..] else url);
}

/// LogpointManager's locationKey: the url and the line and column asked for.
pub fn locationKey(arena: Allocator, url: []const u8, line: u64, column: ?u64) ![]const u8 {
    if (column) |c| return std.fmt.allocPrint(arena, "{s}:{d}:{d}", .{ url, line, c });
    return std.fmt.allocPrint(arena, "{s}:{d}", .{ url, line });
}

/// LogpointFormatter: the logpoints, or that there are none.
pub fn formatList(arena: Allocator, records: []const *Logpoint) ![]const u8 {
    if (records.len == 0) return "No logpoints are set on the page.";
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.print("{d} logpoint(s) set on the page:", .{records.len});
    for (records) |r| {
        try out.writer.print("\n- {s}:{d}", .{ r.url, r.line + 1 });
        if (r.column) |c| try out.writer.print(":{d}", .{c + 1});
        try out.writer.print(" logging `{s}` [", .{r.expression});
        if (!r.bound() or r.current_state.items.len == 0) {
            try out.writer.writeAll("not bound (no parsed script contains the location)");
        } else if (r.from_source_map) {
            try out.writer.writeAll("bound via source map at ");
            for (r.current_state.items, 0..) |pos, i| {
                if (i != 0) try out.writer.writeAll(", ");
                try out.writer.print("{s}:{d}:{d}", .{ pos.url, pos.line + 1, (pos.column orelse 0) + 1 });
            }
        } else {
            try out.writer.writeAll("bound");
        }
        try out.writer.writeAll("]");
    }
    return out.written();
}

/// McpPage.init's #initDevToolsUniverseNoThrow: the universe's session on
/// the page, once - createTargetUniverse's target over a new session
/// (Target.attachToTarget, flattened), whose DebuggerModel starts as
/// enableDebugger does: skip all pauses (the universe's setting), enable
/// with DevTools' script cache (1e8 bytes), no pause on exceptions, async
/// stacks 32 deep. A failure is logged, as Google's server logs it, and
/// tried again at the next page tool.
pub fn initUniverse(session: *Session, page: *Page) !void {
    if (page.debugger_session_id != null or page.closed) return;
    var params_buffer: [256]u8 = undefined;
    const params = std.fmt.bufPrint(&params_buffer, "{{\"targetId\":{f},\"flatten\":true}}", .{std.json.fmt(page.target_id, .{})}) catch return;
    var r = session.client.call("Target.attachToTarget", params, "", session_mod.command_timeout_ms) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return,
    };
    defer r.deinit();
    const result = r.result() orelse return;
    const id = str(result.object.get("sessionId"));
    if (id.len == 0) return;
    page.debugger_session_id = try session.allocator.dupe(u8, id);
    const steps = [_][2][]const u8{
        .{ "Debugger.setSkipAllPauses", "{\"skip\":true}" },
        .{ "Debugger.enable", "{\"maxScriptsCacheSize\":100000000}" },
        .{ "Debugger.setPauseOnExceptions", "{\"state\":\"none\"}" },
        .{ "Debugger.setAsyncCallStackDepth", "{\"maxDepth\":32}" },
    };
    for (steps) |step| {
        var answer = session.client.call(step[0], step[1], page.debugger_session_id.?, session_mod.command_timeout_ms) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return,
        };
        answer.deinit();
    }
}

test "parse: the shortest location, a port's colon, a column, the 1-based check" {
    const t = std.testing;
    const a = parse("src/app.ts:42 'total', cart.total").ok;
    try t.expectEqualStrings("src/app.ts", a.url);
    try t.expectEqual(@as(u64, 42), a.line);
    try t.expect(a.column == null);
    try t.expectEqualStrings("'total', cart.total", a.expression);
    const b = parse("  http://localhost:8080/a.js:3:7   x, y  ").ok;
    try t.expectEqualStrings("http://localhost:8080/a.js", b.url);
    try t.expectEqual(@as(u64, 3), b.line);
    try t.expectEqual(@as(u64, 7), b.column.?);
    try t.expectEqualStrings("x, y", b.expression);
    // A column with no whitespace after it is no column: the line must be
    // followed by whitespace.
    try t.expect(parse("a.js:3:x y") == .invalid);
    try t.expect(parse("a.js 1") == .invalid);
    try t.expect(parse("a.js:1") == .invalid);
    try t.expect(parse("a.js:0 x") == .not_one_based);
    try t.expect(parse("a.js:1:0 x") == .not_one_based);
    // The expression may span lines (the s flag).
    try t.expectEqualStrings("a,\nb", parse("a.js:1 a,\nb").ok.expression);
}

test "formatList: none, bound, source-mapped (single and multi), and unbound" {
    const t = std.testing;
    var arena_state = std.heap.ArenaAllocator.init(t.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try t.expectEqualStrings("No logpoints are set on the page.", try formatList(arena, &.{}));
    var url_a = "http://h/a.js".*;
    var url_b = "http://h/b.html".*;
    var url_c = "http://h/src/c.ts".*;
    var url_gen1 = "http://h/c1.js".*;
    var url_gen2 = "http://h/c2.js".*;
    var e1 = "'x', x".*;
    var e2 = "y".*;
    var e3 = "z".*;
    var bp_id = "bp1".*;
    var s_id = "1".*;
    var cond = "c".*;

    var first: Logpoint = .{ .url = &url_a, .line = 3, .column = 0, .expression = &e1 };
    try first.resolved.append(arena, .{ .breakpoint_id = &bp_id, .script_id = &s_id });
    try first.current_state.append(arena, .{ .url = &url_a, .line = 3, .column = 0, .condition = &cond });

    var second: Logpoint = .{ .url = &url_b, .line = 1, .column = null, .expression = &e2 };

    var third: Logpoint = .{ .url = &url_c, .from_source_map = true, .line = 2, .column = 2, .expression = &e3 };
    try third.resolved.append(arena, .{ .breakpoint_id = &bp_id, .script_id = &s_id });
    try third.current_state.append(arena, .{ .url = &url_gen1, .line = 0, .column = 36, .condition = &cond });
    try third.current_state.append(arena, .{ .url = &url_gen2, .line = 1, .column = 36, .condition = &cond });

    try t.expectEqualStrings(
        "3 logpoint(s) set on the page:\n" ++
            "- http://h/a.js:4:1 logging `'x', x` [bound]\n" ++
            "- http://h/b.html:2 logging `y` [not bound (no parsed script contains the location)]\n" ++
            "- http://h/src/c.ts:3:3 logging `z` [bound via source map at http://h/c1.js:1:37, http://h/c2.js:2:37]",
        try formatList(arena, &.{ &first, &second, &third }),
    );
}
