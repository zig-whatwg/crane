//! The MCP server's path policy: where a tool may read and write files, as
//! chrome-devtools-mcp v1.13.0 decides it (src/McpContext.ts roots and
//! validatePath, #writeFile, saveFile, ensureExtension, loadResource;
//! src/utils/files.ts resolveCanonicalPath; src/ToolHandler.ts
//! validateAndResolvePathOrUrl; src/index.ts #combinedRoots;
//! src/utils/logger.ts escapeForLog; Copyright 2025 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md), translated:
//!
//! - the roots: the server's configured directories (--filesystem-root /
//!   --workspace; by default the OS temp directory), the client's MCP roots
//!   once it has listed them, and always the OS temp directory;
//!   --allow-unrestricted-paths lifts the check while the client has listed
//!   none;
//! - a path is allowed when its canonical form (every symbolic link resolved;
//!   a missing tail kept as written under its nearest existing parent) is a
//!   root's canonical form or under it, and the canonical form replaces it;
//! - a write goes to the checked path with its extension replaced, its
//!   parents made, created or truncated in place for its owner alone and
//!   never through a symbolic link at the target (platform.writeFilePrivate).
//!
//! What touches the machine goes through `Fs` (the platform's, or a test's).

const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const url = @import("url");

/// The operations the policy asks of the machine (`context` is the
/// implementation's own; the platform's needs none).
pub const Fs = struct {
    context: ?*const anyopaque = null,
    /// realpath(3); error.NotFound when the path or a component is missing,
    /// any other error when it cannot be resolved.
    realPath: *const fn (context: ?*const anyopaque, arena: Allocator, path: []const u8) anyerror![]const u8,
    /// Make a directory and its missing parents.
    makeDirectoryPath: *const fn (context: ?*const anyopaque, path: []const u8) anyerror!void,
    /// Write a file in place, owner-only, refusing a symbolic link at it.
    writeFilePrivate: *const fn (context: ?*const anyopaque, path: []const u8, bytes: []const u8) anyerror!void,
    readFile: *const fn (context: ?*const anyopaque, arena: Allocator, path: []const u8) anyerror![]const u8,
    /// The OS temp directory (Node's os.tmpdir()).
    tempDirectory: *const fn (context: ?*const anyopaque, arena: Allocator) anyerror![]const u8,

    fn real(self: Fs, arena: Allocator, path: []const u8) anyerror![]const u8 {
        return self.realPath(self.context, arena, path);
    }
    fn temp(self: Fs, arena: Allocator) anyerror![]const u8 {
        return self.tempDirectory(self.context, arena);
    }
};

pub const platform_fs: Fs = .{
    .realPath = struct {
        fn f(_: ?*const anyopaque, arena: Allocator, path: []const u8) anyerror![]const u8 {
            return platform.realPath(arena, platform.Str.from(path));
        }
    }.f,
    .makeDirectoryPath = struct {
        fn f(_: ?*const anyopaque, path: []const u8) anyerror!void {
            return platform.makeDirectoryPath(platform.Str.from(path));
        }
    }.f,
    .writeFilePrivate = struct {
        fn f(_: ?*const anyopaque, path: []const u8, bytes: []const u8) anyerror!void {
            return platform.writeFilePrivate(platform.Str.from(path), platform.Bytes.from(bytes));
        }
    }.f,
    .readFile = struct {
        fn f(_: ?*const anyopaque, arena: Allocator, path: []const u8) anyerror![]const u8 {
            return platform.readFile(arena, platform.Str.from(path), max_read_bytes) catch |err| {
                // A directory opens but does not read (EISDIR).
                const info = platform.fileInfo(platform.Str.from(path)) catch return err;
                return if (info.kind == .directory) error.IsDir else err;
            };
        }
    }.f,
    .tempDirectory = struct {
        fn f(_: ?*const anyopaque, arena: Allocator) anyerror![]const u8 {
            return platform.tempDirectory(arena);
        }
    }.f,
};

/// The most a read (sourcePath) takes.
pub const max_read_bytes = 64 << 20;

/// An MCP root as the client lists it.
pub const Root = struct {
    uri: []const u8,
    name: []const u8 = "",
};

/// A refusal's message (the tool's "Error: ..." line).
pub const Denied = error{Denied};

/// The server's policy: its configured roots and the client's, OWNED by
/// `allocator`.
pub const Policy = struct {
    allocator: Allocator,
    fs: Fs = platform_fs,
    /// --filesystem-root / --workspace, as given; null: the default, the OS
    /// temp directory (DEFAULT_FILESYSTEM_ROOT).
    configured: ?[]const []const u8 = null,
    /// --allow-unrestricted-paths.
    allow_unrestricted: bool = false,
    /// The client's roots/list answer; null until one came.
    client: ?[]Root = null,
    /// Why the last check refused (in the caller's arena).
    message: []const u8 = "",

    pub fn deinit(self: *Policy) void {
        self.freeClient();
    }

    fn freeClient(self: *Policy) void {
        const roots = self.client orelse return;
        for (roots) |r| {
            self.allocator.free(r.uri);
            self.allocator.free(r.name);
        }
        self.allocator.free(roots);
        self.client = null;
    }

    /// McpServer #updateRoots: the client's roots, copied.
    pub fn setClientRoots(self: *Policy, roots: []const Root) Allocator.Error!void {
        const copy = try self.allocator.alloc(Root, roots.len);
        var made: usize = 0;
        errdefer {
            for (copy[0..made]) |r| {
                self.allocator.free(r.uri);
                self.allocator.free(r.name);
            }
            self.allocator.free(copy);
        }
        for (roots, 0..) |r, i| {
            const uri = try self.allocator.dupe(u8, r.uri);
            errdefer self.allocator.free(uri);
            copy[i] = .{ .uri = uri, .name = try self.allocator.dupe(u8, r.name) };
            made += 1;
        }
        self.freeClient();
        self.client = copy;
    }

    fn deny(self: *Policy, arena: Allocator, comptime format: []const u8, args: anytype) Denied {
        self.message = std.fmt.allocPrint(arena, format, args) catch "Access denied.";
        return error.Denied;
    }

    /// McpContext.validatePath: the canonical path when allowed, else
    /// error.Denied with `message` set.
    pub fn validatePath(self: *Policy, arena: Allocator, path: []const u8) (Denied || Allocator.Error)![]const u8 {
        const canonical = resolveCanonicalPath(arena, self.fs, path) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return self.deny(arena, "Access denied: Cannot resolve base path for {s}.", .{try escapeForLog(arena, path)}),
        };
        // No client roots and the operator opted out: no check.
        if (self.client == null and self.allow_unrestricted) return canonical;
        const cwd = self.fs.real(arena, ".") catch "/";
        for (try self.rootPaths(arena)) |root| {
            const root_path = try resolve(arena, cwd, root);
            const canonical_root = self.fs.real(arena, root_path) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                // A root that cannot be resolved is skipped.
                else => continue,
            };
            const prefix = if (std.mem.endsWith(u8, canonical_root, "/")) canonical_root else try std.fmt.allocPrint(arena, "{s}/", .{canonical_root});
            if (std.mem.eql(u8, canonical, canonical_root) or std.mem.startsWith(u8, canonical, prefix)) return canonical;
        }
        return self.deny(arena, "Access denied: path {s} (canonical: {s}) is not within any of the configured workspace roots.", .{ try escapeForLog(arena, path), try escapeForLog(arena, canonical) });
    }

    /// McpContext.roots() as paths: #combinedRoots - the configured roots
    /// (none under --allow-unrestricted-paths) and the client's - then the
    /// OS temp directory. A client root that is not a file: URL is skipped
    /// (fileURLToPath throws for it).
    fn rootPaths(self: *Policy, arena: Allocator) Allocator.Error![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        const temp = self.fs.temp(arena) catch "/tmp";
        if (!self.allow_unrestricted) {
            if (self.configured) |dirs| try out.appendSlice(arena, dirs) else try out.append(arena, temp);
        }
        if (self.client) |roots| for (roots) |r| {
            const path = (try fileUrlToPath(arena, r.uri)) orelse continue;
            try out.append(arena, path);
        };
        try out.append(arena, temp);
        return out.items;
    }

    /// ToolHandler validateAndResolvePathOrUrl for one value: null for an
    /// empty one (dropped); a file: URL checked as its path and kept a file:
    /// URL; an http(s)/ws(s) URL kept where `allow_url`, else refused; any
    /// other string checked as a path.
    pub fn checkParam(self: *Policy, arena: Allocator, value: []const u8, allow_url: bool) (Denied || Allocator.Error)!?[]const u8 {
        if (std.mem.trim(u8, value, " \t\r\n\x0b\x0c").len == 0) return null;
        if (try urlScheme(arena, value)) |scheme| {
            if (std.mem.eql(u8, scheme, "file")) {
                const path = switch (try fileUrlPath(arena, value)) {
                    .path => |p| p,
                    .invalid => |message| return self.deny(arena, "{s}", .{message}),
                };
                return try pathToFileUrl(arena, try self.validatePath(arena, path));
            }
            for ([_][]const u8{ "http", "https", "ws", "wss" }) |remote| if (std.mem.eql(u8, scheme, remote)) {
                if (allow_url) return value;
                return self.deny(arena, "This parameter expects a file path, not a URL.", .{});
            };
        }
        return try self.validatePath(arena, value);
    }

    /// McpContext.saveFile: `data` to `path` with its extension made
    /// `extension`, the path checked (ensureExtension, then #writeFile's
    /// own check), its parents made; the path written.
    pub fn saveFile(self: *Policy, arena: Allocator, data: []const u8, path: []const u8, extension: []const u8) (Denied || Allocator.Error)![]const u8 {
        // ensureExtension.
        const resolved = try self.validatePath(arena, path);
        const current = extname(resolved);
        const target = try std.fmt.allocPrint(arena, "{s}{s}", .{ resolved[0 .. resolved.len - current.len], extension });
        // #writeFile.
        const checked = try self.validatePath(arena, target);
        const parent = dirname(checked);
        self.fs.makeDirectoryPath(self.fs.context, parent) catch return self.deny(arena, "Could not write {s}", .{try escapeForLog(arena, target)});
        self.fs.writeFilePrivate(self.fs.context, checked, data) catch return self.deny(arena, "Could not write {s}", .{try escapeForLog(arena, target)});
        // The name saveFile answers: the extension-replaced path.
        return target;
    }

    /// evaluate_script's source from `source_path` (the value validateToolFiles
    /// left): resolveScriptSource's resource URL, then loadResource's read
    /// (chrome-devtools-mcp v1.13.0 src/tools/script.ts resolveScriptSource,
    /// src/McpContext.ts loadResource). A value starting "file:" is the URL;
    /// any other - an http(s) URL included, which validateToolFiles let
    /// through - is pathToFileURL(value): a path under the working directory.
    /// So v1.13.0 never fetches a script source; loadResource's http(s)
    /// branch serves only the DevTools frontend's own loads. A later pin that
    /// starts fetching is caught by the differential case "files: script
    /// sources" (tools/mcp_diff/cases.json).
    pub fn loadScriptSource(self: *Policy, arena: Allocator, source_path: []const u8) (Denied || Allocator.Error)![]const u8 {
        const resource_url = if (std.mem.startsWith(u8, source_path, "file:"))
            source_path
        else
            try pathToFileUrl(arena, try resolve(arena, self.fs.real(arena, ".") catch "/", source_path));
        return self.readFileUrl(arena, resource_url);
    }

    /// loadResource for a file: URL: its path checked, then read as text
    /// (fs.readFile(path, 'utf-8')).
    pub fn readFileUrl(self: *Policy, arena: Allocator, file_url: []const u8) (Denied || Allocator.Error)![]const u8 {
        const path = switch (try fileUrlPath(arena, file_url)) {
            .path => |p| p,
            .invalid => |message| return self.deny(arena, "{s}", .{message}),
        };
        const checked = try self.validatePath(arena, path);
        const bytes = self.fs.readFile(self.fs.context, arena, checked) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // Node's fs.readFile message for the common cases.
            error.NotFound => return self.deny(arena, "ENOENT: no such file or directory, open '{s}'", .{checked}),
            error.AccessDenied => return self.deny(arena, "EACCES: permission denied, open '{s}'", .{checked}),
            error.IsDir => return self.deny(arena, "EISDIR: illegal operation on a directory, read", .{}),
            else => return self.deny(arena, "{t}, open '{s}'", .{ err, checked }),
        };
        return decodeUtf8Lossy(arena, bytes);
    }
};

// ---------------------------------------------------------------------------
// Paths (Node's path module, POSIX)
// ---------------------------------------------------------------------------

/// path.resolve(cwd, p): absolute, `.` and `..` folded, no trailing slash.
pub fn resolve(arena: Allocator, cwd: []const u8, p: []const u8) Allocator.Error![]const u8 {
    const joined = if (p.len > 0 and p[0] == '/') p else try std.fmt.allocPrint(arena, "{s}/{s}", .{ cwd, p });
    var parts: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, joined, '/');
    while (it.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            _ = parts.pop();
            continue;
        }
        try parts.append(arena, part);
    }
    if (parts.items.len == 0) return "/";
    var out: std.ArrayList(u8) = .empty;
    for (parts.items) |part| {
        try out.append(arena, '/');
        try out.appendSlice(arena, part);
    }
    return out.items;
}

/// path.dirname of an absolute, folded path.
pub fn dirname(p: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, p, '/') orelse return ".";
    if (slash == 0) return "/";
    return p[0..slash];
}

/// path.basename of an absolute, folded path.
pub fn basename(p: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, p, '/') orelse return p;
    return p[slash + 1 ..];
}

/// path.extname: from the basename's last dot, unless that dot starts it.
pub fn extname(p: []const u8) []const u8 {
    const base = basename(p);
    const dot = std.mem.lastIndexOfScalar(u8, base, '.') orelse return "";
    if (dot == 0) return "";
    return base[dot..];
}

/// resolveCanonicalPath: realpath of path.resolve(p); when it does not
/// exist, the realpath of its nearest existing parent with the missing
/// segments after it. Any other failure is an error.
pub fn resolveCanonicalPath(arena: Allocator, fs: Fs, p: []const u8) anyerror![]const u8 {
    const cwd = fs.real(arena, ".") catch "/";
    const absolute = try resolve(arena, cwd, p);
    if (fs.real(arena, absolute)) |real| return real else |err| if (err != error.NotFound) return err;
    var current = absolute;
    var missing: std.ArrayList([]const u8) = .empty;
    while (true) {
        const parent = dirname(current);
        if (std.mem.eql(u8, parent, current)) return error.NotFound;
        if (fs.real(arena, parent)) |canonical_parent| {
            var out: std.ArrayList(u8) = .empty;
            try out.appendSlice(arena, canonical_parent);
            const segments = try arena.alloc([]const u8, missing.items.len + 1);
            segments[0] = basename(current);
            for (missing.items, 0..) |m, i| segments[1 + i] = m;
            for (segments) |segment| {
                if (out.items.len == 0 or out.items[out.items.len - 1] != '/') try out.append(arena, '/');
                try out.appendSlice(arena, segment);
            }
            return out.items;
        } else |err| {
            if (err != error.NotFound) return err;
            try missing.insert(arena, 0, basename(current));
            current = parent;
        }
    }
}

// ---------------------------------------------------------------------------
// URLs
// ---------------------------------------------------------------------------

/// The scheme of `value` when the URL Standard's parser takes it (`new
/// URL(value)` succeeds), else null.
fn urlScheme(arena: Allocator, value: []const u8) Allocator.Error!?[]const u8 {
    const parsed = url.parser.basic_url_parser.parse(arena, value, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    return try arena.dupe(u8, parsed.scheme());
}

/// fileURLToPath on POSIX for a root's URI: null where Node throws (not a
/// file: URL, a host, an encoded slash).
pub fn fileUrlToPath(arena: Allocator, uri: []const u8) Allocator.Error!?[]const u8 {
    const scheme = (try urlScheme(arena, uri)) orelse return null;
    if (!std.mem.eql(u8, scheme, "file")) return null;
    return switch (try fileUrlPath(arena, uri)) {
        .path => |p| p,
        .invalid => null,
    };
}

pub const FileUrl = union(enum) {
    path: []const u8,
    /// Node's message where fileURLToPath throws.
    invalid: []const u8,
};

/// fileURLToPath (POSIX: getPathFromURLPosix): the percent-decoded pathname.
fn fileUrlPath(arena: Allocator, file_url: []const u8) Allocator.Error!FileUrl {
    const parsed = url.parser.basic_url_parser.parse(arena, file_url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return .{ .invalid = "Invalid URL" },
    };
    if (parsed.host) |host| {
        const name = url.host_serializer.serializeHost(arena, host) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return .{ .invalid = "Invalid URL" },
        };
        // Node names process.platform; the built-in platforms' names are
        // Node's ("darwin", "linux").
        if (name.len != 0) return .{ .invalid = try std.fmt.allocPrint(arena, "File URL host must be \"localhost\" or empty on {s}", .{platform.name}) };
    }
    var path: std.ArrayList(u8) = .empty;
    switch (parsed.path) {
        .opaque_path => |p| try path.appendSlice(arena, p),
        .segments => |*segments| for (segments.toSlice()) |segment| {
            try path.append(arena, '/');
            try path.appendSlice(arena, segment);
        },
    }
    var i: usize = 0;
    while (i + 2 < path.items.len) : (i += 1) {
        if (path.items[i] == '%' and path.items[i + 1] == '2' and (path.items[i + 2] == 'f' or path.items[i + 2] == 'F')) {
            return .{ .invalid = "File URL path must not include encoded / characters" };
        }
    }
    return .{ .path = try percentDecode(arena, path.items) };
}

fn percentDecode(arena: Allocator, text: []const u8) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == '%' and i + 2 < text.len) {
            const hi = std.fmt.charToDigit(text[i + 1], 16) catch null;
            const lo = std.fmt.charToDigit(text[i + 2], 16) catch null;
            if (hi != null and lo != null) {
                try out.append(arena, hi.? * 16 + lo.?);
                i += 2;
                continue;
            }
        }
        try out.append(arena, text[i]);
    }
    return out.items;
}

/// pathToFileURL(path).href on POSIX: "file://" and the path, `%`, `\`,
/// newline, carriage return and tab encoded first, then what the URL
/// pathname setter encodes (C0 controls, space, `"`, `#`, `<`, `>`, `?`,
/// backquote, `{`, `}` and every non-ASCII byte).
pub fn pathToFileUrl(arena: Allocator, path: []const u8) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, "file://");
    for (path) |c| {
        const encode = switch (c) {
            '%', '\\', '\n', '\r', '\t', ' ', '"', '#', '<', '>', '?', '`', '{', '}' => true,
            else => c < 0x20 or c >= 0x7f,
        };
        if (encode) try out.print(arena, "%{X:0>2}", .{c}) else try out.append(arena, c);
    }
    return out.items;
}

/// UTF-8 decode as the Encoding Standard's UTF-8 decoder does it (what
/// Node's 'utf-8' file reads and TextDecoder do): each maximal subpart of an
/// invalid sequence becomes one U+FFFD, the byte that ended it decoded
/// afresh. The result is UTF-8.
pub fn decodeUtf8Lossy(arena: Allocator, bytes: []const u8) Allocator.Error![]const u8 {
    if (std.unicode.utf8ValidateSlice(bytes)) return bytes;
    const replacement = "\u{FFFD}";
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacity(arena, bytes.len + 8);
    var needed: u3 = 0;
    var seen: u3 = 0;
    var start: usize = 0;
    var lower: u8 = 0x80;
    var upper: u8 = 0xBF;
    var i: usize = 0;
    while (i < bytes.len) {
        const b = bytes[i];
        if (needed == 0) {
            start = i;
            switch (b) {
                0x00...0x7F => try out.append(arena, b),
                0xC2...0xDF => needed = 1,
                0xE0...0xEF => {
                    if (b == 0xE0) lower = 0xA0;
                    if (b == 0xED) upper = 0x9F;
                    needed = 2;
                },
                0xF0...0xF4 => {
                    if (b == 0xF0) lower = 0x90;
                    if (b == 0xF4) upper = 0x8F;
                    needed = 3;
                },
                else => try out.appendSlice(arena, replacement),
            }
            i += 1;
            continue;
        }
        if (b < lower or b > upper) {
            // The sequence so far is one error; this byte starts afresh.
            needed = 0;
            seen = 0;
            lower = 0x80;
            upper = 0xBF;
            try out.appendSlice(arena, replacement);
            continue;
        }
        lower = 0x80;
        upper = 0xBF;
        seen += 1;
        i += 1;
        if (seen == needed) {
            try out.appendSlice(arena, bytes[start..i]);
            needed = 0;
            seen = 0;
        }
    }
    if (needed != 0) try out.appendSlice(arena, replacement);
    return out.items;
}

/// escapeForLog: JSON.stringify of the text, then U+007F-U+009F, U+2028 and
/// U+2029 as \uXXXX.
pub fn escapeForLog(arena: Allocator, text: []const u8) Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(arena, '"');
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        const len = std.unicode.utf8ByteSequenceLength(c) catch 1;
        const cp: u21 = if (len > 1 and i + len <= text.len) (std.unicode.utf8Decode(text[i .. i + len]) catch c) else c;
        const step = if (len > 1 and i + len <= text.len) len else 1;
        switch (cp) {
            '"' => try out.appendSlice(arena, "\\\""),
            '\\' => try out.appendSlice(arena, "\\\\"),
            0x08 => try out.appendSlice(arena, "\\b"),
            0x09 => try out.appendSlice(arena, "\\t"),
            0x0a => try out.appendSlice(arena, "\\n"),
            0x0c => try out.appendSlice(arena, "\\f"),
            0x0d => try out.appendSlice(arena, "\\r"),
            0x00...0x07, 0x0b, 0x0e...0x1f, 0x7f...0x9f, 0x2028, 0x2029 => try out.print(arena, "\\u{x:0>4}", .{@as(u32, cp)}),
            else => try out.appendSlice(arena, text[i .. i + step]),
        }
        i += step;
    }
    try out.append(arena, '"');
    return out.items;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

const testing = std.testing;

/// A machine of paths: `links` maps a path to what it resolves to; a path
/// exists when it is in `dirs` (after its links).
const FakeFs = struct {
    dirs: []const []const u8,
    links: []const [2][]const u8 = &.{},
    cwd: []const u8 = "/home/u",
    temp: []const u8 = "/tmp",
    /// What every read gives; null: the file is missing.
    file: ?[]const u8 = "x",

    fn of(context: ?*const anyopaque) *const FakeFs {
        return @ptrCast(@alignCast(context.?));
    }
    fn realPath(context: ?*const anyopaque, arena: Allocator, path: []const u8) anyerror![]const u8 {
        const self = of(context);
        const absolute = try resolve(arena, self.cwd, path);
        var current: []const u8 = "/";
        var it = std.mem.splitScalar(u8, absolute[1..], '/');
        while (it.next()) |part| {
            if (part.len == 0) continue;
            const next = if (std.mem.eql(u8, current, "/")) try std.fmt.allocPrint(arena, "/{s}", .{part}) else try std.fmt.allocPrint(arena, "{s}/{s}", .{ current, part });
            var resolved: []const u8 = next;
            for (self.links) |l| if (std.mem.eql(u8, l[0], next)) {
                resolved = l[1];
            };
            var found = false;
            for (self.dirs) |d| if (std.mem.eql(u8, d, resolved)) {
                found = true;
            };
            if (!found) return error.NotFound;
            current = resolved;
        }
        return current;
    }
    fn tempDirectory(context: ?*const anyopaque, _: Allocator) anyerror![]const u8 {
        return of(context).temp;
    }
    fn none(_: ?*const anyopaque, _: []const u8) anyerror!void {}
    fn write(_: ?*const anyopaque, _: []const u8, _: []const u8) anyerror!void {}
    fn read(context: ?*const anyopaque, _: Allocator, _: []const u8) anyerror![]const u8 {
        return of(context).file orelse error.NotFound;
    }
    fn fs(self: *const FakeFs) Fs {
        return .{ .context = self, .realPath = realPath, .makeDirectoryPath = none, .writeFilePrivate = write, .readFile = read, .tempDirectory = tempDirectory };
    }
};

test "path.resolve, dirname, basename, extname as Node's POSIX path module" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try testing.expectEqualStrings("/home/u/a/b", try resolve(arena, "/home/u", "a/./b/"));
    try testing.expectEqualStrings("/x", try resolve(arena, "/home/u", "/a/../x"));
    try testing.expectEqualStrings("/", try resolve(arena, "/home/u", "/../.."));
    try testing.expectEqualStrings("/a", dirname("/a/b"));
    try testing.expectEqualStrings("/", dirname("/a"));
    try testing.expectEqualStrings("b.txt", basename("/a/b.txt"));
    try testing.expectEqualStrings(".txt", extname("/a/b.txt"));
    try testing.expectEqualStrings("", extname("/a/.hidden"));
    try testing.expectEqualStrings(".gz", extname("/a/b.tar.gz"));
    try testing.expectEqualStrings("", extname("/a/b"));
}

test "validatePath: inside a root, a missing tail under an existing parent, a symlink escape, the temp directory, a root of /" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const machine: FakeFs = .{
        .dirs = &.{ "/home", "/home/u", "/work", "/work/site", "/secret", "/tmp", "/private", "/private/tmp" },
        .links = &.{ .{ "/work/site/escape", "/secret" }, .{ "/tmp", "/private/tmp" } },
    };
    var policy: Policy = .{ .allocator = testing.allocator, .fs = machine.fs(), .configured = &.{"/work"} };
    defer policy.deinit();

    try testing.expectEqualStrings("/work/site", try policy.validatePath(arena, "/work/site"));
    try testing.expectEqualStrings("/work/site/new/file.txt", try policy.validatePath(arena, "/work/site/new/file.txt"));
    // The temp directory, through its link.
    try testing.expectEqualStrings("/private/tmp/x.txt", try policy.validatePath(arena, "/tmp/x.txt"));
    // A symbolic link out of the root.
    try testing.expectError(error.Denied, policy.validatePath(arena, "/work/site/escape/key"));
    try testing.expectEqualStrings("Access denied: path \"/work/site/escape/key\" (canonical: \"/secret/key\") is not within any of the configured workspace roots.", policy.message);
    // A relative path from the working directory.
    try testing.expectError(error.Denied, policy.validatePath(arena, "x.js"));
    try testing.expectEqualStrings("Access denied: path \"x.js\" (canonical: \"/home/u/x.js\") is not within any of the configured workspace roots.", policy.message);
    // A root of "/" holds everything.
    var everything: Policy = .{ .allocator = testing.allocator, .fs = machine.fs(), .configured = &.{"/"} };
    defer everything.deinit();
    try testing.expectEqualStrings("/secret/key", try everything.validatePath(arena, "/secret/key"));
}

test "roots: by default the temp directory only; client roots join; unrestricted lifts the check until the client lists roots" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const machine: FakeFs = .{ .dirs = &.{ "/home", "/home/u", "/work", "/tmp" } };
    var policy: Policy = .{ .allocator = testing.allocator, .fs = machine.fs() };
    defer policy.deinit();
    try testing.expectError(error.Denied, policy.validatePath(arena, "/work/a"));
    try testing.expectEqualStrings("/tmp/a", try policy.validatePath(arena, "/tmp/a"));
    try policy.setClientRoots(&.{ .{ .uri = "file:///work", .name = "work" }, .{ .uri = "https://example.com/" } });
    try testing.expectEqualStrings("/work/a", try policy.validatePath(arena, "/work/a"));

    var open: Policy = .{ .allocator = testing.allocator, .fs = machine.fs(), .allow_unrestricted = true };
    defer open.deinit();
    try testing.expectEqualStrings("/home/u/a", try open.validatePath(arena, "a"));
    try open.setClientRoots(&.{.{ .uri = "file:///work" }});
    try testing.expectError(error.Denied, open.validatePath(arena, "a"));
}

test "checkParam: empty dropped, file: URLs kept as file: URLs, remote URLs only where allowed" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const machine: FakeFs = .{ .dirs = &.{ "/home", "/home/u", "/tmp" } };
    var policy: Policy = .{ .allocator = testing.allocator, .fs = machine.fs() };
    defer policy.deinit();
    try testing.expectEqual(@as(?[]const u8, null), try policy.checkParam(arena, "  ", false));
    try testing.expectEqualStrings("file:///tmp/a%20b.js", (try policy.checkParam(arena, "file:///tmp/a%20b.js", false)).?);
    try testing.expectEqualStrings("https://example.com/x.js", (try policy.checkParam(arena, "https://example.com/x.js", true)).?);
    try testing.expectError(error.Denied, policy.checkParam(arena, "http://x/../../etc/passwd", false));
    try testing.expectEqualStrings("This parameter expects a file path, not a URL.", policy.message);
    try testing.expectEqualStrings("/tmp/out", (try policy.checkParam(arena, "/tmp/out", false)).?);
}

test "decodeUtf8Lossy: the Encoding Standard's UTF-8 decode, each maximal invalid subpart one U+FFFD" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try testing.expectEqualStrings("a\u{e9}\u{20ac}\u{1f600}", try decodeUtf8Lossy(arena, "a\u{e9}\u{20ac}\u{1f600}"));
    try testing.expectEqualStrings("a\u{FFFD}b", try decodeUtf8Lossy(arena, "a\xffb"));
    // E0 needs A0-BF next: E0 is one error, the 80 another.
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}", try decodeUtf8Lossy(arena, "\xe0\x80"));
    // A sequence cut short: one error, then the byte that cut it.
    try testing.expectEqualStrings("\u{FFFD}a", try decodeUtf8Lossy(arena, "\xe2\x82a"));
    try testing.expectEqualStrings("x\u{FFFD}", try decodeUtf8Lossy(arena, "x\xf0\x9f\x98"));
    // A surrogate's encoding (ED A0 80) is three errors.
    try testing.expectEqualStrings("\u{FFFD}\u{FFFD}\u{FFFD}", try decodeUtf8Lossy(arena, "\xed\xa0\x80"));
}

test "loadScriptSource: a file: URL read once its path is checked; any other value a path under the working directory, an http(s) URL too" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const machine: FakeFs = .{ .dirs = &.{ "/home", "/home/u", "/tmp" }, .file = "() => 1" };
    var policy: Policy = .{ .allocator = testing.allocator, .fs = machine.fs() };
    defer policy.deinit();
    try testing.expectEqualStrings("() => 1", try policy.loadScriptSource(arena, "/tmp/s.js"));
    try testing.expectEqualStrings("() => 1", try policy.loadScriptSource(arena, "file:///tmp/s.js"));
    // resolveScriptSource: pathToFileURL("https://a.test/x.js") under the
    // working directory - never fetched.
    try testing.expectError(error.Denied, policy.loadScriptSource(arena, "https://a.test/x.js"));
    try testing.expectEqualStrings("Access denied: path \"/home/u/https:/a.test/x.js\" (canonical: \"/home/u/https:/a.test/x.js\") is not within any of the configured workspace roots.", policy.message);
    const missing: FakeFs = .{ .dirs = &.{ "/home", "/home/u", "/tmp" }, .file = null };
    var none: Policy = .{ .allocator = testing.allocator, .fs = missing.fs() };
    defer none.deinit();
    try testing.expectError(error.Denied, none.loadScriptSource(arena, "/tmp/s.js"));
    try testing.expectEqualStrings("ENOENT: no such file or directory, open '/tmp/s.js'", none.message);
}

test "saveFile: the extension replaced, the path checked; escapeForLog as JSON.stringify plus C1 and line separators" {
    var arena_state = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const machine: FakeFs = .{ .dirs = &.{ "/home", "/home/u", "/tmp" } };
    var policy: Policy = .{ .allocator = testing.allocator, .fs = machine.fs() };
    defer policy.deinit();
    try testing.expectEqualStrings("/tmp/snap.txt", try policy.saveFile(arena, "x", "/tmp/snap.md", ".txt"));
    try testing.expectEqualStrings("/tmp/out.json", try policy.saveFile(arena, "x", "/tmp/out", ".json"));
    try testing.expectEqualStrings("\"a\\\"b\\n\\u007f\\u2028\"", try escapeForLog(arena, "a\"b\n\x7f\u{2028}"));
}
