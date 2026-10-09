//! The platform boundary, as a ratchet: `zig build lint-platform` (and so
//! `zig build test`) fails when any file references the OS, or a library the
//! platform owns, more often than tools/platform_boundary_baseline.txt records.
//!
//! docs/platform-protocol.md section 11: Crane's platform is an adapter, and
//! the protocol (`@import("platform")`, src/platform/protocol.zig) is the only
//! way to reach it. Outside src/platform/ there is no OS API, no libcurl,
//! mbedTLS, SQLite or LevelDB identifier, and no OS framework call.
//!
//! What is counted, per file and per key (the method of
//! tmp/plans/platform-inventory.md section 1, as lint-engine counts V8):
//!   * the bridges: `@import("clock")`, `@import("host")` (not src/url/'s
//!     `host`, the URL host module) and `@import("memory")`, and every member
//!     reached through them - `clock.monotonicMillis`;
//!   * std's OS namespaces: `std.c.*`, `std.posix.*`, `std.os.*`,
//!     `std.process.*`, also through an alias (`const c = std.c;`);
//!   * std.Io's OS members (`Dir`, `File`, `net`, `Clock`, `Timestamp`,
//!     `Threaded` but not its mutex calls or `global_single_threaded`) and
//!     `std.Io` as a value's type (an Io carries files and randomness);
//!   * threads (`std.Thread.spawn`, `getCpuCount`, `sleep`), the filesystem
//!     (`std.fs.*` but its pure members), the network (`std.net.*`,
//!     `std.http.Client`, `std.http.Server`);
//!   * `extern fn` declarations (not V8's FFI in the V8 adapter, which is the
//!     engine boundary's), target branches (`builtin.os.tag`,
//!     `builtin.target.os`), the environment (`getenv`, `environ`, `Environ`);
//!   * the libraries the platform owns: `curl_easy_*`, `curl_multi_*`,
//!     `curl_ws_*`, `curl_global_*`, `curl_slist_*`, `curl_share_*`, `CURL*`
//!     and Crane's curl wrappers' members; `mbedtls_*`, `psa_*`, `MBEDTLS_*`,
//!     `PSA_*`; `sqlite3_*`, `SQLITE_*`; `leveldb_*`.
//! Exempt: src/platform/ (the facade, the kit, the platforms), build-time code
//! (tools/, src/webidl/codegen/, src/webidl/parser/, the snapshot generator,
//! src/main.zig), src/webdriver/ while it is a separate executable (decision
//! 18), tests/, and `test` declarations; synchronisation, allocators,
//! `std.fs.path` and `std.time` constants are not OS access.
//!
//! Two keys hold the facade's own rules, in src/, tests/ and tools/ alike:
//!   * `platform.adapter` - the bound platform itself - anywhere but tests/
//!     (contract 1.3);
//!   * `platform-transitional.<name>` - today's backends the facade re-exports
//!     until their recipes step moves them (protocol.zig's TRANSITIONAL
//!     section). Today's callers are in the baseline; a new one fails.
//!
//! The baseline only goes down. After moving a file onto the protocol:
//!     zig build lint-platform -- --update
//! which refuses to record an increase.

const std = @import("std");

const baseline_path = "tools/platform_boundary_baseline.txt";

/// Directories scanned for .zig files.
const scanned_roots = [_][]const u8{ "src", "tests", "tools" };

/// The facade's re-exports of today's backends (protocol.zig, TRANSITIONAL).
pub const transitional_names = [_][]const u8{
    "media_backend",
    "media_adapter",
    "timer_backend",
    "clipboard_backend",
    "ClipboardBackend",
    "ClipboardResult",
    "ClipboardFormat",
    "ClipboardItem",
    "StubClipboardBackend",
    "DeniedClipboardBackend",
};

/// How a file is held to the boundary.
pub const Scope = enum {
    /// Not scanned at all: the platform itself, upstream code, this tool.
    none,
    /// Only the facade's rules (platform.adapter, the transitional names).
    facade_rules,
    /// Every key.
    full,
};

/// The scope of `path` (repo-relative, `/`-separated).
pub fn scopeOf(path: []const u8) Scope {
    if (!std.mem.endsWith(u8, path, ".zig")) return .none;
    if (std.mem.startsWith(u8, path, "src/platform/")) return .none;
    if (std.mem.startsWith(u8, path, "tests/wpt/")) return .none;
    if (std.mem.eql(u8, path, "tools/lint_platform_boundary.zig")) return .none;
    if (std.mem.startsWith(u8, path, "tests/") or std.mem.startsWith(u8, path, "tools/")) return .facade_rules;
    const build_time = [_][]const u8{ "src/webidl/codegen/", "src/webidl/parser/", "src/webdriver/" };
    for (build_time) |prefix| if (std.mem.startsWith(u8, path, prefix)) return .facade_rules;
    const entry_files = [_][]const u8{ "src/main.zig", "src/runtime/engines/v8/snapshot_generator.zig" };
    for (entry_files) |file| if (std.mem.eql(u8, path, file)) return .facade_rules;
    if (std.mem.startsWith(u8, path, "src/")) return .full;
    return .none;
}

/// One reference: its line and the key it is counted under.
pub const Reference = struct {
    line: u32,
    name: []const u8,
    /// The line's code, for the report.
    code: []const u8 = "",
};

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn codeOf(line: []const u8) []const u8 {
    const cut = std.mem.indexOf(u8, line, "//") orelse line.len;
    return line[0..cut];
}

fn identAt(text: []const u8, start: usize) []const u8 {
    var end = start;
    while (end < text.len and isIdentChar(text[end])) end += 1;
    return text[start..end];
}

/// `code` with every "..." string's contents and every '...' character
/// literal blanked. Same length.
fn blankStrings(buf: []u8, code: []const u8) []const u8 {
    const out = buf[0..code.len];
    @memcpy(out, code);
    var quote: u8 = 0;
    var i: usize = 0;
    while (i < out.len) : (i += 1) {
        const c = out[i];
        if (quote != 0) {
            if (c == '\\' and i + 1 < out.len) {
                out[i] = ' ';
                out[i + 1] = ' ';
                i += 1;
                continue;
            }
            if (c == quote) {
                quote = 0;
                continue;
            }
            out[i] = ' ';
        } else if (c == '"' or c == '\'') quote = c;
    }
    return out;
}

/// What an alias stands for: `c` -> "std.c", `clock` -> "clock".
const Alias = struct { name: []const u8, target: []const u8 };

fn aliasTarget(aliases: []const Alias, name: []const u8) ?[]const u8 {
    // The latest binding wins (a later `const c = ...` shadows nothing in Zig,
    // but two functions may bind the same name differently).
    var i = aliases.len;
    while (i > 0) {
        i -= 1;
        if (std.mem.eql(u8, aliases[i].name, name)) return aliases[i].target;
    }
    return null;
}

/// The module an `@import` path stands for, when the boundary cares: the
/// bridges, builtin, std, and the facade.
fn importTarget(path: []const u8, file: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, path, "clock")) return "clock";
    if (std.mem.eql(u8, path, "memory")) return "memory";
    // src/url's `host` is the URL host module, not the Io bridge.
    if (std.mem.eql(u8, path, "host")) return if (std.mem.startsWith(u8, file, "src/url/")) null else "host";
    if (std.mem.eql(u8, path, "builtin")) return "builtin";
    if (std.mem.eql(u8, path, "std")) return "std";
    if (std.mem.eql(u8, path, "platform")) return "platform";
    return null;
}

/// Whether the identifier after `lead` is the name a `const` / `var` binds.
fn declaresName(lead_text: []const u8) bool {
    const lead = std.mem.trimEnd(u8, lead_text, " \t");
    for ([_][]const u8{ "const", "var" }) |keyword| {
        if (!std.mem.endsWith(u8, lead, keyword)) continue;
        const k = lead.len - keyword.len;
        if (k == 0 or !isIdentChar(lead[k - 1])) return true;
    }
    return false;
}

fn isTransitional(name: []const u8) bool {
    for (transitional_names) |t| if (std.mem.eql(u8, t, name)) return true;
    return false;
}

fn hasPrefix(ident: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |p| if (std.mem.startsWith(u8, ident, p)) return true;
    return false;
}

/// The library an identifier belongs to, if the platform owns it.
fn libraryOf(ident: []const u8) ?[]const u8 {
    if (hasPrefix(ident, &.{ "curl_easy_", "curl_multi_", "curl_ws_", "curl_global_", "curl_slist_", "curl_share_", "CURL" })) return "curl";
    if (hasPrefix(ident, &.{ "mbedtls_", "psa_", "MBEDTLS_", "PSA_" })) return "mbedtls";
    if (hasPrefix(ident, &.{ "sqlite3_", "SQLITE_" })) return "sqlite";
    if (hasPrefix(ident, &.{"leveldb_"})) return "leveldb";
    return null;
}

const curl_wrappers = [_][]const u8{ "curl_backend", "curl_ffi", "curl_error", "curl_options" };

/// The key a resolved member path is counted under, or null. `path` is the
/// dotted path with its head alias expanded ("std.c.getenv", "clock.wallMillis").
fn keyOfPath(path: []const u8, file: []const u8, scope: Scope, preceded_by_colon: bool) ?[]const u8 {
    var segments: [4][]const u8 = undefined;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, path, '.');
    while (it.next()) |segment| {
        if (n == segments.len) break;
        segments[n] = segment;
        n += 1;
    }
    const head = segments[0];
    const tail_start = head.len + 1;
    // The facade's rules hold everywhere scanned.
    if (std.mem.eql(u8, head, "platform") and n >= 2) {
        const second_end = tail_start + segments[1].len;
        if (std.mem.eql(u8, segments[1], "adapter")) {
            return if (std.mem.startsWith(u8, file, "tests/")) null else path[0..second_end];
        }
        if (isTransitional(segments[1])) return path[0..second_end];
        return null;
    }
    if (scope != .full) return null;
    if (std.mem.eql(u8, head, "clock") or std.mem.eql(u8, head, "host") or std.mem.eql(u8, head, "memory")) {
        if (n < 2) return null;
        return path[0 .. tail_start + segments[1].len];
    }
    if (std.mem.eql(u8, head, "builtin")) {
        if (n >= 3 and std.mem.eql(u8, segments[1], "os") and std.mem.eql(u8, segments[2], "tag")) return "builtin.os.tag";
        if (n >= 3 and std.mem.eql(u8, segments[1], "target") and std.mem.eql(u8, segments[2], "os")) return "builtin.target.os";
        return null;
    }
    if (!std.mem.eql(u8, head, "std") or n < 2) return null;
    const ns = segments[1];
    const ns_end = tail_start + ns.len;
    if (n < 3) {
        // `std.Io` itself as a parameter's or field's type: an Io value.
        if (std.mem.eql(u8, ns, "Io") and preceded_by_colon) return "std.Io";
        return null;
    }
    const member = segments[2];
    const member_end = ns_end + 1 + member.len;
    if (std.mem.eql(u8, ns, "c") or std.mem.eql(u8, ns, "posix") or std.mem.eql(u8, ns, "os") or std.mem.eql(u8, ns, "process")) {
        // libc memory handed to V8's C++ is the engine adapter's, not an OS
        // service.
        if (std.mem.eql(u8, ns, "c") and std.mem.startsWith(u8, file, "src/runtime/engines/") and
            (std.mem.eql(u8, member, "malloc") or std.mem.eql(u8, member, "free"))) return null;
        return path[0..member_end];
    }
    if (std.mem.eql(u8, ns, "Io")) {
        for ([_][]const u8{ "Dir", "File", "net", "Clock", "Timestamp" }) |m| if (std.mem.eql(u8, member, m)) return path[0..member_end];
        if (std.mem.eql(u8, member, "Threaded")) {
            if (n >= 4) {
                for ([_][]const u8{ "mutexLock", "mutexUnlock", "global_single_threaded" }) |m| if (std.mem.eql(u8, segments[3], m)) return null;
            }
            return path[0..member_end];
        }
        return null;
    }
    if (std.mem.eql(u8, ns, "Thread")) {
        for ([_][]const u8{ "spawn", "getCpuCount", "sleep" }) |m| if (std.mem.eql(u8, member, m)) return path[0..member_end];
        return null;
    }
    if (std.mem.eql(u8, ns, "fs")) {
        for ([_][]const u8{ "path", "max_path_bytes", "max_name_bytes", "base64_alphabet", "base64_encoder", "base64_decoder" }) |m| if (std.mem.eql(u8, member, m)) return null;
        return path[0..member_end];
    }
    if (std.mem.eql(u8, ns, "net")) return path[0..member_end];
    if (std.mem.eql(u8, ns, "http")) {
        if (std.mem.eql(u8, member, "Client") or std.mem.eql(u8, member, "Server")) return path[0..member_end];
        return null;
    }
    return null;
}

/// The token line ranges of every `test` declaration in `source`, 1-based and
/// inclusive. A file that does not parse yields none (its lines all count).
fn testLines(gpa: std.mem.Allocator, source: [:0]const u8) !std.ArrayList([2]u32) {
    var out: std.ArrayList([2]u32) = .empty;
    errdefer out.deinit(gpa);
    var tree = try std.zig.Ast.parse(gpa, source, .zig);
    defer tree.deinit(gpa);
    if (tree.errors.len > 0) return out;
    var i: u32 = 0;
    while (i < tree.nodes.len) : (i += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(i);
        if (tree.nodeTag(node) != .test_decl) continue;
        const first: u32 = @intCast(tree.tokenLocation(0, tree.firstToken(node)).line + 1);
        const last: u32 = @intCast(tree.tokenLocation(0, tree.lastToken(node)).line + 1);
        try out.append(gpa, .{ first, last });
    }
    return out;
}

fn inTest(ranges: []const [2]u32, line: u32) bool {
    for (ranges) |r| if (line >= r[0] and line <= r[1]) return true;
    return false;
}

/// Every reference in `text` (the file at `path`), in line order. Keys are
/// allocated with `gpa`.
pub fn references(gpa: std.mem.Allocator, path: []const u8, text: []const u8) !std.ArrayList(Reference) {
    var out: std.ArrayList(Reference) = .empty;
    errdefer out.deinit(gpa);
    const scope = scopeOf(path);
    if (scope == .none) return out;

    const source = try gpa.dupeZ(u8, text);
    defer gpa.free(source);
    var tests = try testLines(gpa, source);
    defer tests.deinit(gpa);

    var aliases: std.ArrayList(Alias) = .empty;
    defer aliases.deinit(gpa);
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    var lines = std.mem.splitScalar(u8, text, '\n');
    var line_no: u32 = 0;
    while (lines.next()) |raw| {
        line_no += 1;
        const code = codeOf(raw);
        const trimmed = std.mem.trim(u8, code, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "\\\\")) continue;
        if (trimmed.len == 0) continue;
        const counted = !inTest(tests.items, line_no);

        try buf.resize(gpa, code.len);
        const plain = blankStrings(buf.items, code);

        // A `const name = <import or alias>[.path];` binds an alias (before
        // the line's references are counted: the binding's right-hand side
        // is counted like any other use).
        try bindAlias(gpa, &aliases, path, code, plain);

        if (!counted) continue;

        // 1. The bridges' imports, and inline imports with a member path.
        var search: usize = 0;
        const open = "@import(\"";
        while (std.mem.indexOfPos(u8, code, search, open)) |at| {
            const path_start = at + open.len;
            const path_end = std.mem.indexOfScalarPos(u8, code, path_start, '"') orelse break;
            search = path_end + 1;
            const target = importTarget(code[path_start..path_end], path) orelse continue;
            const is_bridge = std.mem.eql(u8, target, "clock") or std.mem.eql(u8, target, "host") or std.mem.eql(u8, target, "memory");
            if (is_bridge and scope == .full) {
                try out.append(gpa, .{ .line = line_no, .name = try std.fmt.allocPrint(gpa, "{s}.@import", .{target}), .code = trimmed });
            }
            // `@import("x").a.b`: the member path, resolved like an alias's.
            var end = path_end + 2;
            while (end < code.len and code[end] == '.') {
                const member = identAt(code, end + 1);
                if (member.len == 0) break;
                end += 1 + member.len;
            }
            if (end > path_end + 2) {
                const full = try std.fmt.allocPrint(gpa, "{s}{s}", .{ target, code[path_end + 2 .. end] });
                if (keyOfPath(full, path, scope, false)) |key| {
                    if (!is_bridge) try out.append(gpa, .{ .line = line_no, .name = try gpa.dupe(u8, key), .code = trimmed });
                }
                gpa.free(full);
            }
        }

        // 2. `extern fn NAME` (not V8's FFI, the engine boundary's).
        if (scope == .full and !std.mem.startsWith(u8, path, "src/runtime/engines/v8/")) {
            if (std.mem.indexOf(u8, plain, "extern ")) |at| {
                var rest = std.mem.trimStart(u8, plain[at + "extern ".len ..], " ");
                const raw_rest = std.mem.trimStart(u8, code[at + "extern ".len ..], " ");
                if (std.mem.startsWith(u8, raw_rest, "\"c\"")) rest = std.mem.trimStart(u8, rest[3..], " ");
                if (std.mem.startsWith(u8, rest, "fn ")) {
                    const name_at = @intFromPtr(rest.ptr) - @intFromPtr(plain.ptr) + 3;
                    const name = identAt(code, std.mem.indexOfNonePos(u8, code, name_at, " ") orelse name_at);
                    if (name.len > 0) try out.append(gpa, .{ .line = line_no, .name = try std.fmt.allocPrint(gpa, "extern.{s}", .{name}), .code = trimmed });
                }
            }
        }

        // 3. Identifiers: library names anywhere, member paths from their head.
        var i: usize = 0;
        while (i < plain.len) {
            if (!isIdentChar(plain[i]) or (i > 0 and (isIdentChar(plain[i - 1]) or plain[i - 1] == '@'))) {
                i += 1;
                continue;
            }
            const ident = identAt(plain, i);
            defer i += ident.len;
            if (std.ascii.isDigit(ident[0])) continue;
            const after_dot = i > 0 and plain[i - 1] == '.';
            if (scope == .full) {
                if (libraryOf(ident)) |library| {
                    try out.append(gpa, .{ .line = line_no, .name = try std.fmt.allocPrint(gpa, "{s}.{s}", .{ library, ident }), .code = trimmed });
                    continue;
                }
            }
            if (after_dot) continue;
            // The name a declaration binds is not a use.
            if (declaresName(plain[0..i])) continue;
            // The path that starts here: ident(.ident)*.
            var end = i + ident.len;
            while (end < plain.len and plain[end] == '.') {
                const member = identAt(plain, end + 1);
                if (member.len == 0) break;
                end += 1 + member.len;
            }
            const rest = plain[i + ident.len .. end];
            if (scope == .full) {
                for (curl_wrappers) |wrapper| {
                    if (std.mem.eql(u8, ident, wrapper) and rest.len > 1) {
                        const member = identAt(rest, 1);
                        try out.append(gpa, .{ .line = line_no, .name = try std.fmt.allocPrint(gpa, "curl-wrapper.{s}.{s}", .{ wrapper, member }), .code = trimmed });
                    }
                }
                for ([_][]const u8{ "getenv", "environ", "Environ" }) |env| {
                    if (std.mem.eql(u8, ident, env)) try out.append(gpa, .{ .line = line_no, .name = try std.fmt.allocPrint(gpa, "env.{s}", .{env}), .code = trimmed });
                }
            }
            const target = if (std.mem.eql(u8, ident, "std")) "std" else aliasTarget(aliases.items, ident) orelse continue;
            const full = try std.fmt.allocPrint(gpa, "{s}{s}", .{ target, rest });
            defer gpa.free(full);
            const before = std.mem.trimEnd(u8, plain[0..i], " \t");
            const colon = before.len > 0 and before[before.len - 1] == ':';
            if (keyOfPath(full, path, scope, colon)) |key| {
                try out.append(gpa, .{ .line = line_no, .name = try gpa.dupe(u8, key), .code = trimmed });
            }
        }
    }
    return out;
}

/// `[pub] const name = @import("x")[.a.b];` or `const name = alias[.a];` or
/// `const name = std.c;`
fn bindAlias(gpa: std.mem.Allocator, aliases: *std.ArrayList(Alias), file: []const u8, code: []const u8, plain: []const u8) !void {
    var s = std.mem.trim(u8, plain, " \t\r");
    if (std.mem.startsWith(u8, s, "pub ")) s = std.mem.trimStart(u8, s[4..], " ");
    if (!std.mem.startsWith(u8, s, "const ")) return;
    s = std.mem.trimStart(u8, s[6..], " ");
    const name_at = @intFromPtr(s.ptr) - @intFromPtr(plain.ptr);
    const name = identAt(code, name_at);
    if (name.len == 0) return;
    s = std.mem.trimStart(u8, s[name.len..], " ");
    // A type annotation (`const x: T = ...`) is a value, not an alias.
    if (s.len == 0 or s[0] != '=') return;
    s = std.mem.trim(u8, s[1..], " \t;");
    const rhs_start = @intFromPtr(s.ptr) - @intFromPtr(plain.ptr);
    const rhs = code[rhs_start .. rhs_start + s.len];

    var target: []const u8 = undefined;
    var rest: []const u8 = undefined;
    const open = "@import(\"";
    if (std.mem.startsWith(u8, rhs, open)) {
        const end = std.mem.indexOfScalarPos(u8, rhs, open.len, '"') orelse return;
        target = importTarget(rhs[open.len..end], file) orelse return;
        rest = if (end + 2 <= rhs.len) rhs[end + 2 ..] else "";
    } else {
        const head = identAt(rhs, 0);
        if (head.len == 0) return;
        target = if (std.mem.eql(u8, head, "std")) "std" else aliasTarget(aliases.items, head) orelse return;
        rest = rhs[head.len..];
    }
    for (rest) |c| if (!(isIdentChar(c) or c == '.')) return;
    const full = try std.fmt.allocPrint(gpa, "{s}{s}", .{ target, rest });
    try aliases.append(gpa, .{ .name = name, .target = full });
}

/// Counts per "path key" key.
pub const Counts = std.StringHashMapUnmanaged(u32);

/// A key the current tree has more of than the baseline allows.
pub const Violation = struct { key: []const u8, allowed: u32, found: u32 };

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn violationLessThan(_: void, a: Violation, b: Violation) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

/// Every key in `current` above its baseline count - a key absent from the
/// baseline is allowed zero - sorted by key.
pub fn violations(gpa: std.mem.Allocator, current: *const Counts, baseline: *const Counts) !std.ArrayList(Violation) {
    var out: std.ArrayList(Violation) = .empty;
    errdefer out.deinit(gpa);
    var it = current.iterator();
    while (it.next()) |entry| {
        const allowed = baseline.get(entry.key_ptr.*) orelse 0;
        if (entry.value_ptr.* > allowed) {
            try out.append(gpa, .{ .key = entry.key_ptr.*, .allowed = allowed, .found = entry.value_ptr.* });
        }
    }
    std.mem.sort(Violation, out.items, {}, violationLessThan);
    return out;
}

/// Parse a baseline file: `path key count` per line, `#` comments.
pub fn parseBaseline(gpa: std.mem.Allocator, text: []const u8) !Counts {
    var counts: Counts = .empty;
    errdefer {
        var keys = counts.keyIterator();
        while (keys.next()) |key| gpa.free(key.*);
        counts.deinit(gpa);
    }
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const space = std.mem.lastIndexOfScalar(u8, line, ' ') orelse return error.MalformedBaseline;
        const count = std.fmt.parseInt(u32, line[space + 1 ..], 10) catch return error.MalformedBaseline;
        const key = try gpa.dupe(u8, std.mem.trimEnd(u8, line[0..space], " "));
        errdefer gpa.free(key);
        const gop = try counts.getOrPut(gpa, key);
        if (gop.found_existing) {
            gpa.free(key);
            gop.value_ptr.* += count;
        } else gop.value_ptr.* = count;
    }
    return counts;
}

const header =
    \\# Platform-boundary references outside src/platform/: path key count.
    \\# A ratchet - `zig build lint-platform`, part of `zig build test`, fails if any
    \\# count rises or a new pair appears (docs/platform-protocol.md section 11). After
    \\# moving a file onto the platform protocol (src/platform/protocol.zig), lower it
    \\# with `zig build lint-platform -- --update`. Never raise it by hand.
    \\
;

/// Format counts as a baseline file, keys sorted.
pub fn formatBaseline(gpa: std.mem.Allocator, counts: *const Counts) ![]u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    defer keys.deinit(gpa);
    var it = counts.keyIterator();
    while (it.next()) |key| try keys.append(gpa, key.*);
    std.mem.sort([]const u8, keys.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, header);
    for (keys.items) |key| {
        const line = try std.fmt.allocPrint(gpa, "{s} {d}\n", .{ key, counts.get(key).? });
        defer gpa.free(line);
        try out.appendSlice(gpa, line);
    }
    return out.toOwnedSlice(gpa);
}

fn scanDir(
    arena: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    current: *Counts,
    sites: *std.StringHashMapUnmanaged(std.ArrayList(Reference)),
    files: *std.StringHashMapUnmanaged(void),
) !void {
    var dir = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const path = try std.fmt.allocPrint(arena, "{s}/{s}", .{ root, entry.path });
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (scopeOf(path) == .none) continue;
        if (std.mem.indexOf(u8, path, ".zig-cache/") != null) continue;
        // Generated per build (addTestFilesFromDir), gitignored.
        if (std.mem.endsWith(u8, path, "/.all_tests.zig")) continue;
        const text = try std.Io.Dir.cwd().readFileAlloc(io, path, arena, .limited(64 << 20));
        const refs = try references(arena, path, text);
        if (refs.items.len > 0) try files.put(arena, path, {});
        for (refs.items) |ref| {
            const key = try std.fmt.allocPrint(arena, "{s} {s}", .{ path, ref.name });
            const gop = try current.getOrPut(arena, key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
            const site = try sites.getOrPut(arena, key);
            if (!site.found_existing) site.value_ptr.* = .empty;
            try site.value_ptr.append(arena, ref);
        }
    }
}

pub fn main(init: std.process.Init) !void {
    var arena_state = std.heap.ArenaAllocator.init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = init.io;

    var update = false;
    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--update")) {
            update = true;
        } else {
            std.debug.print("usage: lint_platform_boundary [--update]\n", .{});
            std.process.exit(2);
        }
    }

    var current: Counts = .empty;
    var sites = std.StringHashMapUnmanaged(std.ArrayList(Reference)).empty;
    var files: std.StringHashMapUnmanaged(void) = .empty;
    for (scanned_roots) |root| try scanDir(arena, io, root, &current, &sites, &files);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    var total: usize = 0;
    var values = current.valueIterator();
    while (values.next()) |value| total += value.*;

    const text: ?[]u8 = std.Io.Dir.cwd().readFileAlloc(io, baseline_path, arena, .limited(64 << 20)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    if (text == null) {
        if (!update) {
            try out.print("platform boundary: no {s}; record one with `zig build lint-platform -- --update`.\n", .{baseline_path});
            try out.flush();
            std.process.exit(1);
        }
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("platform boundary: first baseline recorded - {d} references in {d} files, {d} keys.\n", .{ total, files.count(), current.count() });
        return;
    }
    const baseline = try parseBaseline(arena, text.?);

    const found = try violations(arena, &current, &baseline);
    if (found.items.len > 0) {
        try out.print("platform boundary: {d} key(s) above the baseline.\n\n", .{found.items.len});
        for (found.items) |v| {
            try out.print("  {s}: allowed {d}, found {d}\n", .{ v.key, v.allowed, v.found });
            if (sites.get(v.key)) |list| {
                const path_end = std.mem.indexOfScalar(u8, v.key, ' ') orelse v.key.len;
                for (list.items) |ref| try out.print("      {s}:{d}: {s}\n", .{ v.key[0..path_end], ref.line, ref.code });
            }
        }
        try out.print(
            \\
            \\Everything platform-specific goes through the platform protocol,
            \\@import("platform") (src/platform/protocol.zig; docs/platform-protocol.md
            \\section 11, recipes in docs/platform-protocol-recipes.md). An operation it
            \\lacks is requested from the integrator and added there (contract section 12).
            \\
        , .{});
        try out.flush();
        std.process.exit(1);
    }

    var lowered: usize = 0;
    var base_it = baseline.iterator();
    while (base_it.next()) |entry| {
        if ((current.get(entry.key_ptr.*) orelse 0) < entry.value_ptr.*) lowered += 1;
    }
    if (update) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = baseline_path, .data = try formatBaseline(arena, &current) });
        try out.print("platform boundary: baseline lowered - {d} references in {d} files, {d} keys.\n", .{ total, files.count(), current.count() });
    } else if (lowered > 0) {
        try out.print("platform boundary: {d} key(s) paid down; record it with `zig build lint-platform -- --update`.\n", .{lowered});
    } else {
        try out.print("platform boundary: {d} references in {d} files, none above the baseline.\n", .{ total, files.count() });
    }
}

// ============================================================================
// Tests - the rules
// ============================================================================

const testing = std.testing;

fn expectRefs(path: []const u8, text: []const u8, expected: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const refs = try references(arena.allocator(), path, text);
    var got: std.ArrayList(u8) = .empty;
    for (refs.items) |ref| try got.print(arena.allocator(), "{d}:{s}\n", .{ ref.line, ref.name });
    var want: std.ArrayList(u8) = .empty;
    for (expected) |e| try want.print(arena.allocator(), "{s}\n", .{e});
    try testing.expectEqualStrings(want.items, got.items);
}

test "scope: the platform, upstream WPT and this tool are not scanned; build-time code, tests and the WebDriver server only for the facade's rules" {
    try testing.expectEqual(Scope.none, scopeOf("src/platform/kit/posix/root.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/platform/protocol.zig"));
    try testing.expectEqual(Scope.none, scopeOf("tests/wpt/tools/x.zig"));
    try testing.expectEqual(Scope.none, scopeOf("tools/lint_platform_boundary.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("tools/gc_bench.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("tests/wpt_runner/main.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("src/webdriver/server.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("src/webidl/codegen/writer.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("src/webidl/parser/lexer.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("src/main.zig"));
    try testing.expectEqual(Scope.facade_rules, scopeOf("src/runtime/engines/v8/snapshot_generator.zig"));
    try testing.expectEqual(Scope.full, scopeOf("src/fetch/network/curl_backend.zig"));
    try testing.expectEqual(Scope.full, scopeOf("src/runtime/engines/v8/context_manager.zig"));
    try testing.expectEqual(Scope.none, scopeOf("src/runtime/engines/v8/v8_wrapper.cpp"));
}

test "the bridges: their imports and every member reached through them" {
    try expectRefs("src/a.zig",
        \\const clock = @import("clock");
        \\const host = @import("host");
        \\const mem = @import("memory");
        \\fn f() void {
        \\    const t = clock.monotonicMillis();
        \\    var dir = host.cwd();
        \\    _ = mem.residentBytes();
        \\    _ = @import("clock").wallMillis();
        \\}
    , &.{
        "1:clock.@import",
        "2:host.@import",
        "3:memory.@import",
        "5:clock.monotonicMillis",
        "6:host.cwd",
        "7:memory.residentBytes",
        "8:clock.@import",
    });
}

test "src/url's host is the URL host module, not the bridge" {
    try expectRefs("src/url/internal/host_parser.zig",
        \\const host = @import("host");
        \\const h = host.parse(input);
    , &.{});
}

test "std's OS namespaces, also through an alias; synchronisation and pure members are not counted" {
    try expectRefs("src/a.zig",
        \\const c = std.c;
        \\const posix = std.posix;
        \\fn f(io: std.Io) void {
        \\    _ = c.getenv("HOME");
        \\    _ = posix.getrandom(buf);
        \\    _ = std.process.argsAlloc(a);
        \\    var d = std.Io.Dir.cwd();
        \\    std.Io.Threaded.mutexLock(&m);
        \\    _ = std.Io.Threaded.global_single_threaded.io();
        \\    var mutex: std.Io.Mutex = .init;
        \\    _ = std.fs.path.join(a, parts);
        \\    _ = std.fs.max_path_bytes;
        \\    _ = std.time.ns_per_ms;
        \\    const t = try std.Thread.spawn(.{}, run, .{});
        \\    _ = std.Thread.getCpuCount();
        \\    var lock: std.Thread.Mutex = .{};
        \\    _ = std.http.Client;
        \\    _ = std.http.Method.GET;
        \\}
    , &.{
        "3:std.Io",
        "4:std.c.getenv",
        "5:std.posix.getrandom",
        "6:std.process.argsAlloc",
        "7:std.Io.Dir",
        "14:std.Thread.spawn",
        "15:std.Thread.getCpuCount",
        "17:std.http.Client",
    });
}

test "externs, target branches and the environment" {
    try expectRefs("src/file/blob_url_store.zig",
        \\extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;
        \\pub extern fn arc4random() u32;
        \\const builtin = @import("builtin");
        \\const x = switch (builtin.os.tag) { .macos => 1, else => 2 };
        \\const y = @import("builtin").os.tag == .linux;
        \\const z = builtin.target.os.tag;
        \\const home = getenv("HOME");
        \\const m = builtin.mode;
    , &.{
        "1:extern.getentropy",
        "2:extern.arc4random",
        "4:builtin.os.tag",
        "5:builtin.os.tag",
        "6:builtin.target.os",
        "7:env.getenv",
    });
}

test "V8's FFI externs and libc memory in the engine adapter belong to the engine boundary" {
    try expectRefs("src/runtime/engines/v8/protocol_agents.zig",
        \\extern fn v8_Isolate_New() ?*anyopaque;
        \\const p = std.c.malloc(n);
        \\std.c.free(p);
        \\const e = std.c.getenv("X");
    , &.{
        "4:std.c.getenv",
    });
}

test "the libraries the platform owns, and Crane's curl wrappers" {
    try expectRefs("src/fetch/network/connection_pool.zig",
        \\const curl_backend = @import("curl_backend.zig");
        \\_ = curl.curl_easy_setopt(h, curl.CURLOPT_URL, url);
        \\const rc = mbedtls_ssl_get_alpn_protocol(ssl);
        \\_ = sqlite3_step(stmt) == SQLITE_ROW;
        \\leveldb_put(db, o, k, kl, v, vl, &err);
        \\try curl_backend.globalInit();
        \\const not_curl = curly_brace;
    , &.{
        "2:curl.curl_easy_setopt",
        "2:curl.CURLOPT_URL",
        "3:mbedtls.mbedtls_ssl_get_alpn_protocol",
        "4:sqlite.sqlite3_step",
        "4:sqlite.SQLITE_ROW",
        "5:leveldb.leveldb_put",
        "6:curl-wrapper.curl_backend.globalInit",
    });
}

test "test declarations are exempt" {
    try expectRefs("src/a.zig",
        \\const clock = @import("clock");
        \\test "reads the clock" {
        \\    _ = clock.monotonicMillis();
        \\    _ = std.c.getenv("HOME");
        \\}
        \\fn f() i64 {
        \\    return clock.wallMillis();
        \\}
    , &.{
        "1:clock.@import",
        "7:clock.wallMillis",
    });
}

test "comments, strings and multiline strings are not references" {
    try expectRefs("src/a.zig",
        \\// clock.monotonicMillis is how this used to work
        \\const msg = "call std.c.getenv and curl_easy_perform";
        \\const doc =
        \\    \\const clock = @import("clock");
        \\;
        \\const ch = '"';
        \\const e = std.c.getenv("HOME");
    , &.{
        "7:std.c.getenv",
    });
}

test "platform.adapter counts outside tests/; the transitional names count everywhere" {
    try expectRefs("src/html/a.zig",
        \\const platform = @import("platform");
        \\const control = platform.adapter.control;
        \\const media = @import("platform").media_backend;
        \\const t = platform.timer_backend;
        \\const now = platform.monotonicNow();
    , &.{
        "2:platform.adapter",
        "3:platform.media_backend",
        "4:platform.timer_backend",
    });
    try expectRefs("tests/wpt_runner/x.zig",
        \\const platform = @import("platform");
        \\const control = platform.adapter.control;
        \\const media = @import("platform").media_backend;
        \\const c = std.c.getenv("X");
    , &.{
        "3:platform.media_backend",
    });
    try expectRefs("tools/repl.zig",
        \\const p = @import("platform");
        \\_ = p.adapter;
    , &.{
        "2:platform.adapter",
    });
}

test "a violation is any key above its baseline, including a key the baseline lacks (a swap)" {
    var current: Counts = .empty;
    defer current.deinit(testing.allocator);
    var baseline: Counts = .empty;
    defer baseline.deinit(testing.allocator);

    try baseline.put(testing.allocator, "a.zig clock.monotonicMillis", 2);
    // The same total, one call swapped for another.
    try current.put(testing.allocator, "a.zig clock.monotonicMillis", 1);
    try current.put(testing.allocator, "a.zig clock.wallMillis", 1);
    // Paid down.
    try baseline.put(testing.allocator, "b.zig std.c.getenv", 3);
    try current.put(testing.allocator, "b.zig std.c.getenv", 1);
    // Grown.
    try baseline.put(testing.allocator, "c.zig curl.CURLOPT_URL", 1);
    try current.put(testing.allocator, "c.zig curl.CURLOPT_URL", 2);

    var found = try violations(testing.allocator, &current, &baseline);
    defer found.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), found.items.len);
    try testing.expectEqualStrings("a.zig clock.wallMillis", found.items[0].key);
    try testing.expectEqual(@as(u32, 0), found.items[0].allowed);
    try testing.expectEqualStrings("c.zig curl.CURLOPT_URL", found.items[1].key);
    try testing.expectEqual(@as(u32, 1), found.items[1].allowed);
}

test "the baseline round-trips, sorted, and ignores comments" {
    var counts: Counts = .empty;
    defer counts.deinit(testing.allocator);
    try counts.put(testing.allocator, "src/b.zig std.c.getenv", 2);
    try counts.put(testing.allocator, "src/a.zig clock.@import", 1);
    const text = try formatBaseline(testing.allocator, &counts);
    defer testing.allocator.free(text);
    try testing.expect(std.mem.indexOf(u8, text, "src/a.zig clock.@import 1\nsrc/b.zig std.c.getenv 2\n") != null);
    var parsed = try parseBaseline(testing.allocator, text);
    defer {
        var it = parsed.keyIterator();
        while (it.next()) |key| testing.allocator.free(key.*);
        parsed.deinit(testing.allocator);
    }
    try testing.expectEqual(@as(u32, 2), parsed.get("src/b.zig std.c.getenv").?);
    try testing.expectEqual(@as(u32, 2), parsed.count());
}
