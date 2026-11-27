//! Per-file V8 handle-count delta gate for `wpt_runner_bug_finding`
//! (queue-0.1-audit.md, "Bug-finding gate does not count V8 handles").
//!
//! In bug-finding mode, the WPT runner settles the Browser onto a clean
//! `about:blank` realm with forced GC before and after each file, samples the
//! engine adapter's live handle counters (`live_object_globals`,
//! `wrapper_cache_entries`, `global_handle_bytes`, `node_wrappers`), and checks
//! the net delta against `tools/wpt_handle_leaks_baseline.txt`.
//!
//! Gated counters:
//! - `live_object_globals`: exact live `Global<Object>` count in V8's wrapper
//!   ledger (catches leaked `Get` handles such as bind1 3a's `RouterRule` and
//!   retained cross-realm handles, without order-dependent noise from lazy
//!   per-isolate `FunctionTemplate` caching in `global_handle_bytes`).
//! - `wrapper_cache_entries`: live traced wrapper-cache entries across realms
//!   (catches retained contexts/wrappers after `about:blank` teardown + GC).
//!
//! `global_handle_bytes` and `node_wrappers` are still sampled and printed in
//! every diagnostic line for triage context.
//!
//! Any file whose net `live_object_globals` or `wrapper_cache_entries` delta
//! exceeds its recorded cap (0 / 0 for every unlisted file) emits a
//! `handle leak: <path>: ...` diagnostic line.
//!
//! Pure std (+ std-only `host`) so `zig build test` runs all unit tests.

const std = @import("std");
const host = @import("host");

const Allocator = std.mem.Allocator;

/// Default path of the checked-in per-file handle-leak baseline (a ratchet
/// whose entries only go down).
pub const default_baseline_path = "tools/wpt_handle_leaks_baseline.txt";

/// Live handle counters sampled from `engine.diagnosticCounters` at a clean
/// file boundary (after navigating to `about:blank` and forcing full GC).
pub const Snapshot = struct {
    live_object_globals: u64 = 0,
    wrapper_cache_entries: u64 = 0,
    global_handle_bytes: u64 = 0,
    node_wrappers: u64 = 0,

    pub fn diff(before: Snapshot, after: Snapshot) Delta {
        return .{
            .object_globals = signedDelta(before.live_object_globals, after.live_object_globals),
            .wrapper_cache_entries = signedDelta(before.wrapper_cache_entries, after.wrapper_cache_entries),
            .global_handle_bytes = signedDelta(before.global_handle_bytes, after.global_handle_bytes),
            .node_wrappers = signedDelta(before.node_wrappers, after.node_wrappers),
        };
    }
};

fn signedDelta(before: u64, after: u64) i64 {
    if (after >= before) {
        const d = after - before;
        return @intCast(@min(d, @as(u64, std.math.maxInt(i64))));
    }
    const d = before - after;
    const clamped: i64 = @intCast(@min(d, @as(u64, std.math.maxInt(i64))));
    return -clamped;
}

/// Net handle change across one test file (`after - before`). Negative values
/// mean earlier garbage settled out and never indicate a leak.
pub const Delta = struct {
    object_globals: i64 = 0,
    wrapper_cache_entries: i64 = 0,
    global_handle_bytes: i64 = 0,
    node_wrappers: i64 = 0,

    pub fn exceeds(self: Delta, max_object_globals: u64, max_wrapper_cache_entries: u64) bool {
        const obj_limit: i64 = @intCast(@min(max_object_globals, @as(u64, std.math.maxInt(i64))));
        const wc_limit: i64 = @intCast(@min(max_wrapper_cache_entries, @as(u64, std.math.maxInt(i64))));
        return self.object_globals > obj_limit or self.wrapper_cache_entries > wc_limit;
    }
};

fn counterToU64(v: anytype) u64 {
    return switch (@typeInfo(@TypeOf(v))) {
        .int => |info| if (info.signedness == .signed) (if (v < 0) 0 else @intCast(v)) else @intCast(v),
        else => @compileError("expected integer counter value"),
    };
}

/// Extract the handle counters from any slice of `{ name: []const u8, value: i64|u64 }`
/// (`engine.diagnosticCounters` in the runner, or synthetic counters in tests).
pub fn extractSnapshot(counters: anytype) Snapshot {
    var snap: Snapshot = .{};
    for (counters) |c| {
        if (std.mem.eql(u8, c.name, "live_object_globals")) {
            snap.live_object_globals = counterToU64(c.value);
        } else if (std.mem.eql(u8, c.name, "wrapper_cache_entries")) {
            snap.wrapper_cache_entries = counterToU64(c.value);
        } else if (std.mem.eql(u8, c.name, "global_handle_bytes")) {
            snap.global_handle_bytes = counterToU64(c.value);
        } else if (std.mem.eql(u8, c.name, "node_wrappers")) {
            snap.node_wrappers = counterToU64(c.value);
        }
    }
    return snap;
}

/// One known per-file handle delta allowance in `tools/wpt_handle_leaks_baseline.txt`.
pub const Entry = struct {
    path: []const u8,
    max_object_globals: u64,
    max_wrapper_cache_entries: u64,
    owner: []const u8,
    reason: []const u8,
};

pub const Limits = struct {
    max_object_globals: u64 = 0,
    max_wrapper_cache_entries: u64 = 0,
};

pub const CheckResult = struct {
    leaked: bool,
    delta: Delta,
    limits: Limits,
};

pub const ParseError = error{ InvalidBaseline, OutOfMemory };

pub const ParseDiagnostic = struct {
    line: usize = 0,
    reason: []const u8 = "",
};

/// Parsed baseline of known per-file handle deltas. Unlisted files default to
/// `0` object globals and `0` wrapper cache entries.
pub const Baseline = struct {
    allocator: Allocator,
    entries: []Entry,

    pub fn empty(allocator: Allocator) Baseline {
        return .{ .allocator = allocator, .entries = &.{} };
    }

    pub fn deinit(self: *Baseline) void {
        for (self.entries) |e| {
            self.allocator.free(e.path);
            self.allocator.free(e.owner);
            self.allocator.free(e.reason);
        }
        if (self.entries.len > 0) self.allocator.free(self.entries);
        self.entries = &.{};
    }

    /// Parse TAB-separated lines:
    /// `<path>\t<max_object_globals>\t<max_wrapper_cache_entries>\t<owner>\t<reason>`
    /// Blank lines and `#` comments are skipped. Every entry must name its
    /// owner and reason, and each path may appear at most once.
    pub fn parse(allocator: Allocator, text: []const u8, diag: *ParseDiagnostic) ParseError!Baseline {
        var list: std.ArrayList(Entry) = .empty;
        errdefer {
            for (list.items) |e| {
                allocator.free(e.path);
                allocator.free(e.owner);
                allocator.free(e.reason);
            }
            list.deinit(allocator);
        }

        var lines = std.mem.splitScalar(u8, text, '\n');
        var line_no: usize = 0;
        while (lines.next()) |raw| {
            line_no += 1;
            const line = std.mem.trimEnd(u8, raw, "\r");
            if (line.len == 0 or line[0] == '#') continue;

            var fields: [5][]const u8 = undefined;
            var count: usize = 0;
            var it = std.mem.splitScalar(u8, line, '\t');
            while (it.next()) |field| : (count += 1) {
                if (count == fields.len) return fail(diag, line_no, "more than five TAB-separated fields");
                fields[count] = field;
            }
            if (count != fields.len) {
                return fail(diag, line_no, "expected five TAB-separated fields: path, max_object_globals, max_wrapper_cache_entries, owner, reason");
            }

            const path = std.mem.trim(u8, fields[0], " ");
            const owner = std.mem.trim(u8, fields[3], " ");
            const reason = std.mem.trim(u8, fields[4], " ");
            if (path.len == 0) return fail(diag, line_no, "path is empty");
            if (owner.len == 0) return fail(diag, line_no, "owner is empty");
            if (reason.len == 0) return fail(diag, line_no, "reason is empty");

            const max_obj = std.fmt.parseInt(u64, std.mem.trim(u8, fields[1], " "), 10) catch {
                return fail(diag, line_no, "max_object_globals must be an unsigned integer");
            };
            const max_wc = std.fmt.parseInt(u64, std.mem.trim(u8, fields[2], " "), 10) catch {
                return fail(diag, line_no, "max_wrapper_cache_entries must be an unsigned integer");
            };

            for (list.items) |existing| {
                if (std.mem.eql(u8, existing.path, path)) {
                    return fail(diag, line_no, "duplicate path in handle baseline");
                }
            }

            const owned_path = try allocator.dupe(u8, path);
            errdefer allocator.free(owned_path);
            const owned_owner = try allocator.dupe(u8, owner);
            errdefer allocator.free(owned_owner);
            const owned_reason = try allocator.dupe(u8, reason);
            errdefer allocator.free(owned_reason);

            try list.append(allocator, .{
                .path = owned_path,
                .max_object_globals = max_obj,
                .max_wrapper_cache_entries = max_wc,
                .owner = owned_owner,
                .reason = owned_reason,
            });
        }

        return .{
            .allocator = allocator,
            .entries = try list.toOwnedSlice(allocator),
        };
    }

    /// Load a baseline file from disk relative to cwd. Returns an empty
    /// baseline when the file does not exist (strict 0/0 limits).
    pub fn loadOptional(allocator: Allocator, path: []const u8, diag: *ParseDiagnostic) !Baseline {
        const text = host.cwd().readFileAlloc(host.io(), path, allocator, .limited(4 << 20)) catch |err| switch (err) {
            error.FileNotFound => return Baseline.empty(allocator),
            else => return err,
        };
        defer allocator.free(text);
        return parse(allocator, text, diag);
    }

    pub fn limitsFor(self: *const Baseline, path: []const u8) Limits {
        for (self.entries) |e| {
            if (std.mem.eql(u8, e.path, path)) {
                return .{
                    .max_object_globals = e.max_object_globals,
                    .max_wrapper_cache_entries = e.max_wrapper_cache_entries,
                };
            }
        }
        return .{};
    }

    pub fn check(self: *const Baseline, path: []const u8, before: Snapshot, after: Snapshot) CheckResult {
        const delta = Snapshot.diff(before, after);
        const limits = self.limitsFor(path);
        return .{
            .leaked = delta.exceeds(limits.max_object_globals, limits.max_wrapper_cache_entries),
            .delta = delta,
            .limits = limits,
        };
    }
};

fn fail(diag: *ParseDiagnostic, line: usize, reason: []const u8) ParseError {
    diag.* = .{ .line = line, .reason = reason };
    return error.InvalidBaseline;
}

/// Format a clear, machine-scannable diagnostic line for a file whose handle
/// delta exceeded its baseline.
pub fn writeDiagnostic(w: *std.Io.Writer, path: []const u8, result: CheckResult) std.Io.Writer.Error!void {
    try w.print(
        "handle leak: {s}: live_object_globals {s}{d} (max {d}), wrapper_cache_entries {s}{d} (max {d}), global_handle_bytes {s}{d}, node_wrappers {s}{d}",
        .{
            path,
            signPrefix(result.delta.object_globals),
            result.delta.object_globals,
            result.limits.max_object_globals,
            signPrefix(result.delta.wrapper_cache_entries),
            result.delta.wrapper_cache_entries,
            result.limits.max_wrapper_cache_entries,
            signPrefix(result.delta.global_handle_bytes),
            result.delta.global_handle_bytes,
            signPrefix(result.delta.node_wrappers),
            result.delta.node_wrappers,
        },
    );
}

fn signPrefix(v: i64) []const u8 {
    return if (v > 0) "+" else "";
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "extractSnapshot reads signed and unsigned V8 handle counters and ignores unrelated counters" {
    const Counter = struct { name: []const u8, value: i64 };
    const counters = [_]Counter{
        .{ .name = "full_gc_count", .value = 99 },
        .{ .name = "live_object_globals", .value = 12 },
        .{ .name = "wrapper_cache_entries", .value = 7 },
        .{ .name = "global_handle_bytes", .value = 1024 },
        .{ .name = "node_wrappers", .value = 3 },
    };
    const snap = extractSnapshot(&counters);
    try testing.expectEqual(@as(u64, 12), snap.live_object_globals);
    try testing.expectEqual(@as(u64, 7), snap.wrapper_cache_entries);
    try testing.expectEqual(@as(u64, 1024), snap.global_handle_bytes);
    try testing.expectEqual(@as(u64, 3), snap.node_wrappers);
}

test "Snapshot.diff computes positive, zero, and negative deltas" {
    const before: Snapshot = .{
        .live_object_globals = 20,
        .wrapper_cache_entries = 10,
        .global_handle_bytes = 2048,
        .node_wrappers = 5,
    };
    const after: Snapshot = .{
        .live_object_globals = 23,
        .wrapper_cache_entries = 10,
        .global_handle_bytes = 2000,
        .node_wrappers = 4,
    };
    const d = Snapshot.diff(before, after);
    try testing.expectEqual(@as(i64, 3), d.object_globals);
    try testing.expectEqual(@as(i64, 0), d.wrapper_cache_entries);
    try testing.expectEqual(@as(i64, -48), d.global_handle_bytes);
    try testing.expectEqual(@as(i64, -1), d.node_wrappers);
}

test "Baseline.check flags positive object_globals or wrapper_cache_entries and ignores template-only global_handle_bytes growth" {
    const text =
        "# comment line\n\n" ++
        "service-workers/router/rule.html\t2\t5\tlane-sw\tknown router condition holder\n";
    var diag: ParseDiagnostic = .{};
    var base = try Baseline.parse(testing.allocator, text, &diag);
    defer base.deinit();
    try testing.expectEqual(@as(usize, 1), base.entries.len);

    const before: Snapshot = .{ .live_object_globals = 10, .wrapper_cache_entries = 4, .global_handle_bytes = 512 };
    // Unlisted file with 0 object/wrapper delta even when lazy FunctionTemplate caching adds +64 global_handle_bytes -> clean
    try testing.expect(!base.check("dom/clean.html", before, .{ .live_object_globals = 10, .wrapper_cache_entries = 4, .global_handle_bytes = 576 }).leaked);
    // Unlisted file with negative delta -> clean
    try testing.expect(!base.check("dom/clean.html", before, .{ .live_object_globals = 8, .wrapper_cache_entries = 3, .global_handle_bytes = 480 }).leaked);
    // Unlisted file with +1 object global -> leaked
    try testing.expect(base.check("dom/leak.html", before, .{ .live_object_globals = 11, .wrapper_cache_entries = 4, .global_handle_bytes = 520 }).leaked);
    // Unlisted file with +1 wrapper cache entry -> leaked
    try testing.expect(base.check("dom/leak.html", before, .{ .live_object_globals = 10, .wrapper_cache_entries = 5, .global_handle_bytes = 520 }).leaked);

    // Baseline file within cap -> clean
    try testing.expect(!base.check("service-workers/router/rule.html", before, .{ .live_object_globals = 12, .wrapper_cache_entries = 9 }).leaked);
    // Baseline file exceeding object cap -> leaked
    try testing.expect(base.check("service-workers/router/rule.html", before, .{ .live_object_globals = 13, .wrapper_cache_entries = 9 }).leaked);
    // Baseline file exceeding wrapper cache cap -> leaked
    try testing.expect(base.check("service-workers/router/rule.html", before, .{ .live_object_globals = 12, .wrapper_cache_entries = 10 }).leaked);
}

test "Baseline.parse rejects malformed lines, missing owner/reason, bad integers, and duplicates" {
    var diag: ParseDiagnostic = .{};
    try testing.expectError(error.InvalidBaseline, Baseline.parse(testing.allocator, "only\tfour\tfields\there", &diag));
    try testing.expectEqual(@as(usize, 1), diag.line);

    try testing.expectError(error.InvalidBaseline, Baseline.parse(testing.allocator, "a.html\tnotnum\t0\towner\treason", &diag));
    try testing.expectError(error.InvalidBaseline, Baseline.parse(testing.allocator, "a.html\t0\t0\t\treason", &diag));
    try testing.expectError(error.InvalidBaseline, Baseline.parse(testing.allocator, "a.html\t0\t0\towner\t", &diag));
    try testing.expectError(error.InvalidBaseline, Baseline.parse(testing.allocator, "a.html\t0\t0\to1\tr1\na.html\t1\t8\to2\tr2", &diag));
    try testing.expectEqual(@as(usize, 2), diag.line);
}

test "writeDiagnostic emits a clear handle leak line" {
    var base = Baseline.empty(testing.allocator);
    defer base.deinit();
    const res = base.check(
        "service-workers/router.html",
        .{ .live_object_globals = 10, .wrapper_cache_entries = 4, .global_handle_bytes = 512, .node_wrappers = 2 },
        .{ .live_object_globals = 15, .wrapper_cache_entries = 6, .global_handle_bytes = 552, .node_wrappers = 2 },
    );
    try testing.expect(res.leaked);
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try writeDiagnostic(&w, "service-workers/router.html", res);
    try testing.expectEqualStrings(
        "handle leak: service-workers/router.html: live_object_globals +5 (max 0), wrapper_cache_entries +2 (max 0), global_handle_bytes +40, node_wrappers 0",
        w.buffered(),
    );
}

test "checked-in tools/wpt_handle_leaks_baseline.txt exists and parses cleanly" {
    const text = try host.cwd().readFileAlloc(host.io(), default_baseline_path, testing.allocator, .limited(4 << 20));
    defer testing.allocator.free(text);
    var diag: ParseDiagnostic = .{};
    var base = try Baseline.parse(testing.allocator, text, &diag);
    defer base.deinit();
}
