//! The two WPT runs compared (`zig build wpt-build-compare -- ...`): the
//! PRODUCTION run (wpt_runner) and the BUG-FINDING run
//! (wpt_runner_bug_finding) of the same tree over the same worklist.
//!
//! The browsers' model (the user, 2026-11-09: "ok then we should architect
//! ours like the way browsers do it"): wpt.fyi scores the shipping build, and
//! the debug and sanitizer builds of the same product run the same tests in
//! the browser's own CI, where what they may do differently is written down -
//! Firefox's metadata keys an expectation on `if debug:` or `if asan:`,
//! Chromium's expectations on `[ Debug ]`. Crane's two builds differ only in
//! detection (build_mode.zig `RunnerBuild`), so a result that differs between
//! them is a bug to investigate (flakes are bugs), never accepted silently.
//! The ones known are listed in tools/wpt_build_differences.txt, each with an
//! owner and its evidence; the list only goes down.
//!
//! What it reads:
//! - each run's journal (journal.zig): file statuses, and the bug-finding
//!   run's CRASH records and ownership violations;
//! - each run's result streams (`journal*.wptreport.jsonl`, the runner's
//!   result_reporter.zig ResultStream): every test's status and every
//!   subtest's;
//! - the bug-finding run's log: the allocator's leak and double-free
//!   reports, panics (a failed assertion or safety check, the full C
//!   sanitizer's reports), and faults at a poison address.
//!
//! What fails it (exit 1): the bug-finding gate - a crash, a poison read, a
//! leak, a double free, a panic, a refcount or ownership violation - and any
//! difference between the runs that the known list does not name, or a known
//! difference that no longer occurs (remove it: the list only goes down).
//!
//! std-only (with the std-only `host` module), so `zig build test` runs its
//! tests.

const std = @import("std");
const host = @import("host");
const journal = @import("journal.zig");

const Allocator = std.mem.Allocator;

// ============================================================================
// The known differences (tools/wpt_build_differences.txt)
// ============================================================================

/// The subtest field of a difference in a file's own status (the journal's).
pub const file_status = "*";

/// One known difference between the runs: its test (a journal path for a
/// file's status, a result stream's test URL for a subtest), its subtest
/// (`file_status` for the file's own), each run's status, who owns it and
/// the evidence for it.
pub const Known = struct {
    test_id: []const u8,
    subtest: []const u8,
    /// A status, or `|`-separated statuses the run may take (Firefox
    /// metadata's `expected: [PASS, FAIL]`): a timing-bound subtest's.
    production: []const u8,
    bug_finding: []const u8,
    owner: []const u8,
    evidence: []const u8,

    /// Whether a side lists more than one status: the difference comes and
    /// goes (a timing-bound subtest, tools/wpt_loss_dispositions.txt), so a
    /// run that does not show it is no reason to call the line stale.
    pub fn intermittent(self: Known) bool {
        return std.mem.indexOfScalar(u8, self.production, '|') != null or std.mem.indexOfScalar(u8, self.bug_finding, '|') != null;
    }

    fn matches(self: Known, d: Difference) bool {
        return std.mem.eql(u8, self.test_id, d.test_id) and std.mem.eql(u8, self.subtest, d.subtest) and
            listed(self.production, d.production) and listed(self.bug_finding, d.bug_finding);
    }
};

/// Whether `status` is one of `list`'s `|`-separated statuses.
fn listed(list: []const u8, status: []const u8) bool {
    var it = std.mem.splitScalar(u8, list, '|');
    while (it.next()) |s| if (std.mem.eql(u8, s, status)) return true;
    return false;
}

pub const KnownError = error{ InvalidKnown, OutOfMemory };

/// Where a known-differences file is wrong, for the message.
pub const KnownDiagnostic = struct {
    line: usize = 0,
    reason: []const u8 = "",
};

/// Parses the known differences: one per line, six TAB-separated fields -
/// `<test>\t<subtest or *>\t<production status>\t<bug-finding status>\t<owner>\t<evidence>`
/// - with `\t`, `\n` and `\\` escaped in a field (a subtest name may hold
/// anything). `#` starts a comment line; blank lines are skipped. Owner and
/// evidence are required: an entry nobody owns is an accepted bug.
/// The strings are `allocator`'s (an arena's, in practice).
pub fn parseKnown(allocator: Allocator, text: []const u8, diag: *KnownDiagnostic) KnownError![]Known {
    var list: std.ArrayList(Known) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    var n: usize = 0;
    while (lines.next()) |raw| {
        n += 1;
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0 or line[0] == '#') continue;
        var fields: [6][]const u8 = undefined;
        var count: usize = 0;
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |field| : (count += 1) {
            if (count == fields.len) return invalid(diag, n, "more than six TAB-separated fields");
            fields[count] = try unescape(allocator, field);
        }
        if (count != fields.len) return invalid(diag, n, "expected six TAB-separated fields: test, subtest (or *), production status, bug-finding status, owner, evidence");
        for (fields, 0..) |f, i| if (std.mem.trim(u8, f, " ").len == 0) return invalid(diag, n, switch (i) {
            0 => "the test is empty",
            1 => "the subtest is empty (* for the file's own status)",
            2, 3 => "a status is empty",
            4 => "no owner: every known difference has one",
            else => "no evidence: every known difference has it",
        });
        if (std.mem.eql(u8, fields[2], fields[3]) and std.mem.indexOfScalar(u8, fields[2], '|') == null) return invalid(diag, n, "the two statuses are the same: not a difference");
        for (fields[2..4]) |statuses| {
            var each = std.mem.splitScalar(u8, statuses, '|');
            while (each.next()) |status| {
                if (status.len == 0) return invalid(diag, n, "an empty status in a |-separated list");
                var rest = each;
                while (rest.next()) |other| if (std.mem.eql(u8, status, other)) return invalid(diag, n, "a status listed twice in one run's list");
            }
        }
        for (list.items) |k| {
            if (std.mem.eql(u8, k.test_id, fields[0]) and std.mem.eql(u8, k.subtest, fields[1])) return invalid(diag, n, "listed twice");
        }
        try list.append(allocator, .{
            .test_id = fields[0],
            .subtest = fields[1],
            .production = fields[2],
            .bug_finding = fields[3],
            .owner = fields[4],
            .evidence = fields[5],
        });
    }
    return list.toOwnedSlice(allocator);
}

fn invalid(diag: *KnownDiagnostic, line: usize, reason: []const u8) KnownError {
    diag.* = .{ .line = line, .reason = reason };
    return error.InvalidKnown;
}

fn unescape(allocator: Allocator, field: []const u8) Allocator.Error![]const u8 {
    if (std.mem.indexOfScalar(u8, field, '\\') == null) return allocator.dupe(u8, field);
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < field.len) : (i += 1) {
        if (field[i] == '\\' and i + 1 < field.len) {
            i += 1;
            try out.append(allocator, switch (field[i]) {
                't' => '\t',
                'n' => '\n',
                else => field[i],
            });
        } else try out.append(allocator, field[i]);
    }
    return out.toOwnedSlice(allocator);
}

/// `field` as a known-differences line spells it (`parseKnown`'s escapes).
pub fn writeEscaped(w: *std.Io.Writer, field: []const u8) std.Io.Writer.Error!void {
    for (field) |c| switch (c) {
        '\t' => try w.writeAll("\\t"),
        '\n' => try w.writeAll("\\n"),
        '\\' => try w.writeAll("\\\\"),
        else => try w.writeByte(c),
    };
}

// ============================================================================
// One run's results
// ============================================================================

/// One test's results in a run's result streams.
pub const TestResults = struct {
    status: []const u8,
    /// Subtest name -> status.
    subtests: std.StringArrayHashMapUnmanaged([]const u8) = .empty,
};

/// One run: its files' statuses (from its journal) and its tests' results
/// (from its result streams). Its strings are the arena's.
pub const Run = struct {
    /// Journal path -> the file's status.
    files: std.StringArrayHashMapUnmanaged(journal.Status) = .empty,
    /// Test URL -> its results.
    tests: std.StringArrayHashMapUnmanaged(TestResults) = .empty,
    /// The journal's records that name a build, by build.
    builds: std.EnumArray(journal.Build, usize) = .initFill(0),
    crashes: std.ArrayList([]const u8) = .empty,
    ownership_violations: usize = 0,

    pub fn addJournal(self: *Run, arena: Allocator, log: journal.Log) !void {
        for (log.records) |rec| {
            const path = try arena.dupe(u8, rec.path);
            try self.files.put(arena, path, rec.status);
            if (rec.status == .crash) try self.crashes.append(arena, path);
            self.ownership_violations += rec.ownership_violations;
            if (rec.build) |b| self.builds.getPtr(b).* += 1;
        }
    }

    /// Adds the result-stream lines in `bytes`. A line that does not parse is
    /// skipped (a stream's last line can be cut off by a crash); a test seen
    /// twice keeps its first result, as the journal's merge does.
    pub fn addStream(self: *Run, arena: Allocator, bytes: []const u8) !void {
        var lines = std.mem.splitScalar(u8, bytes, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0) continue;
            const parsed = std.json.parseFromSliceLeaky(std.json.Value, arena, line, .{}) catch continue;
            const obj = switch (parsed) {
                .object => |o| o,
                else => continue,
            };
            const test_id = stringField(obj, "test") orelse continue;
            if (self.tests.contains(test_id)) continue;
            var result: TestResults = .{ .status = stringField(obj, "status") orelse "" };
            if (obj.get("subtests")) |subs| switch (subs) {
                .array => |items| for (items.items) |item| switch (item) {
                    .object => |sub| {
                        const name = stringField(sub, "name") orelse continue;
                        const status = stringField(sub, "status") orelse continue;
                        const gop = try result.subtests.getOrPut(arena, name);
                        if (!gop.found_existing) gop.value_ptr.* = status;
                    },
                    else => {},
                },
                else => {},
            };
            try self.tests.put(arena, test_id, result);
        }
    }
};

fn stringField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    return switch (obj.get(key) orelse return null) {
        .string => |s| s,
        else => null,
    };
}

// ============================================================================
// The comparison
// ============================================================================

/// A test or subtest whose result differs between the runs. "MISSING" for a
/// run that has none.
pub const Difference = struct {
    test_id: []const u8,
    subtest: []const u8,
    production: []const u8,
    bug_finding: []const u8,
};

pub const missing = "MISSING";

/// Every difference between the two runs, in the production run's order
/// (files, then tests, then subtests), then what only the bug-finding run has.
pub fn compare(arena: Allocator, production: *const Run, bug_finding: *const Run) ![]Difference {
    var out: std.ArrayList(Difference) = .empty;
    // Files' own statuses (the journals).
    for (production.files.keys(), production.files.values()) |path, status| {
        const other = bug_finding.files.get(path);
        if (other != null and other.? == status) continue;
        try out.append(arena, .{ .test_id = path, .subtest = file_status, .production = status.toString(), .bug_finding = if (other) |o| o.toString() else missing });
    }
    for (bug_finding.files.keys(), bug_finding.files.values()) |path, status| {
        if (production.files.contains(path)) continue;
        try out.append(arena, .{ .test_id = path, .subtest = file_status, .production = missing, .bug_finding = status.toString() });
    }
    // Tests and their subtests (the result streams). A test only one run has
    // is its file's difference above (the run that crashed on it streamed
    // nothing), and is not repeated subtest by subtest.
    for (production.tests.keys(), production.tests.values()) |test_id, result| {
        const other = bug_finding.tests.get(test_id) orelse continue;
        for (result.subtests.keys(), result.subtests.values()) |name, status| {
            const theirs = other.subtests.get(name) orelse missing;
            if (std.mem.eql(u8, status, theirs)) continue;
            try out.append(arena, .{ .test_id = test_id, .subtest = name, .production = status, .bug_finding = theirs });
        }
        for (other.subtests.keys(), other.subtests.values()) |name, status| {
            if (result.subtests.contains(name)) continue;
            try out.append(arena, .{ .test_id = test_id, .subtest = name, .production = missing, .bug_finding = status });
        }
    }
    return out.toOwnedSlice(arena);
}

/// The differences against the known list: `new` - observed and not listed
/// (or listed with other statuses) - and `stale` - listed and no longer
/// observed, to be removed (the list only goes down).
pub const Verdict = struct {
    new: []const Difference,
    stale: []const Known,
    known: usize,
};

pub fn check(arena: Allocator, differences: []const Difference, known: []const Known) !Verdict {
    var new: std.ArrayList(Difference) = .empty;
    const seen = try arena.alloc(bool, known.len);
    @memset(seen, false);
    var matched: usize = 0;
    for (differences) |d| {
        const hit = for (known, 0..) |k, i| {
            if (k.matches(d)) break i;
        } else null;
        if (hit) |i| {
            seen[i] = true;
            matched += 1;
        } else try new.append(arena, d);
    }
    var stale: std.ArrayList(Known) = .empty;
    for (known, seen) |k, s| if (!s and !k.intermittent()) try stale.append(arena, k);
    return .{ .new = try new.toOwnedSlice(arena), .stale = try stale.toOwnedSlice(arena), .known = matched };
}

// ============================================================================
// The bug-finding gate: what its log says
// ============================================================================

/// What the bug-finding run's log reports, counted by kind. Each is a gate
/// failure: the run exists to have none.
pub const LogFindings = struct {
    /// The allocator's `memory address 0x.. leaked:` reports.
    leaks: usize = 0,
    /// `Double free detected`, and a free whose size or alignment does not
    /// match its allocation (the allocator's other reports).
    bad_frees: usize = 0,
    /// `panic:` - a failed assertion, a safety check, the full C sanitizer.
    panics: usize = 0,
    /// A fault at a poison address: the Zig allocator's 0xdd fill, glibc's
    /// MALLOC_PERTURB_=85 fill and macOS's MallocScribble (0x55 freed,
    /// 0xaa new) - a read of freed (or never-written) memory.
    poison_reads: usize = 0,
    /// `refcount:` invariant reports (CRANE_REFCOUNT_CHECK) and failed
    /// isolate cleanup validations.
    refcount: usize = 0,

    pub fn total(self: LogFindings) usize {
        return self.leaks + self.bad_frees + self.panics + self.poison_reads + self.refcount;
    }

    pub fn scan(self: *LogFindings, text: []const u8) void {
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| self.scanLine(line);
    }

    fn scanLine(self: *LogFindings, line: []const u8) void {
        // "memory address 0x.. leaked: <trace>": with no trace frames (the
        // sweep allocator's) the line can end at the colon.
        if (contains(line, " leaked:") and contains(line, "memory address 0x")) self.leaks += 1;
        if (contains(line, "Double free detected") or contains(line, "does not match free size") or contains(line, "does not match free alignment")) self.bad_frees += 1;
        if (contains(line, "panic: ")) self.panics += 1;
        if (poisonFault(line)) self.poison_reads += 1;
        if (std.mem.startsWith(u8, std.mem.trimStart(u8, line, " "), "refcount: ") or contains(line, "Cleanup validation failed")) self.refcount += 1;
    }
};

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// Whether `line` reports a fault at an address made of one poison byte
/// (`Segmentation fault at address 0xdddddddddddddddd`, or a few bytes past
/// it: a field of a poisoned pointer's object).
fn poisonFault(line: []const u8) bool {
    const at = std.mem.indexOf(u8, line, " at address 0x") orelse return false;
    const hex = line[at + " at address 0x".len ..];
    var digits: usize = 0;
    while (digits < hex.len and std.ascii.isHex(hex[digits])) digits += 1;
    if (digits < 12) return false;
    // The leading 8 hex digits (4 bytes) of one poison byte: the low ones may
    // carry a field offset.
    for ([_][]const u8{ "dddddddd", "55555555", "aaaaaaaa" }) |fill| {
        if (std.ascii.eqlIgnoreCase(hex[0..8], fill)) return true;
    }
    return false;
}

// ============================================================================
// The report
// ============================================================================

pub const Report = struct {
    production_files: usize,
    bug_finding_files: usize,
    differences: []const Difference,
    verdict: Verdict,
    crashes: []const []const u8,
    ownership_violations: usize,
    log: ?LogFindings,
    /// Journal records that name the wrong build, or none: a run given as
    /// the wrong side.
    wrong_build: usize,

    pub fn passed(self: Report) bool {
        return self.gatePassed() and self.verdict.new.len == 0 and self.verdict.stale.len == 0 and self.wrong_build == 0;
    }

    pub fn gatePassed(self: Report) bool {
        const log_clean = if (self.log) |l| l.total() == 0 else true;
        return self.crashes.len == 0 and self.ownership_violations == 0 and log_clean;
    }

    pub fn write(self: Report, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("build compare: production {d} files, bug-finding {d} files\n", .{ self.production_files, self.bug_finding_files });
        if (self.wrong_build > 0) try w.print("  WRONG BUILD: {d} journal record(s) are not the side they were given as (a production journal as --production, a bug-finding one as --bug-finding)\n", .{self.wrong_build});
        try w.print("bug-finding gate: {s} - crashes {d}, ownership violations {d}", .{ if (self.gatePassed()) "PASS" else "FAIL", self.crashes.len, self.ownership_violations });
        if (self.log) |l| {
            try w.print(", leaks {d}, bad frees {d}, panics {d}, poison reads {d}, refcount {d}\n", .{ l.leaks, l.bad_frees, l.panics, l.poison_reads, l.refcount });
        } else try w.writeAll(" (no log given: leaks, bad frees, panics and poison reads not read)\n");
        for (self.crashes) |path| try w.print("  CRASH {s}\n", .{path});
        try w.print("differences: {d} ({d} known, {d} NEW, {d} STALE)\n", .{ self.differences.len, self.verdict.known, self.verdict.new.len, self.verdict.stale.len });
        if (self.verdict.new.len > 0) {
            try w.writeAll("NEW differences - each is a bug to investigate; a line for tools/wpt_build_differences.txt once it has an owner and evidence:\n");
            for (self.verdict.new) |d| {
                try writeEscaped(w, d.test_id);
                try w.writeByte('\t');
                try writeEscaped(w, d.subtest);
                try w.print("\t{s}\t{s}\t<owner>\t<evidence>\n", .{ d.production, d.bug_finding });
            }
        }
        if (self.verdict.stale.len > 0) {
            try w.writeAll("STALE known differences - no longer seen; remove them (the list only goes down):\n");
            for (self.verdict.stale) |k| {
                try w.writeAll("  ");
                try writeEscaped(w, k.test_id);
                try w.writeByte('\t');
                try writeEscaped(w, k.subtest);
                try w.print("\t{s}\t{s}\t{s}\n", .{ k.production, k.bug_finding, k.owner });
            }
        }
        try w.print("build compare: {s}\n", .{if (self.passed()) "PASS" else "FAIL"});
    }
};

/// Records in `run` that are not `want`'s: a journal given as the wrong side.
/// Records naming no build (journals from before the split) count too.
pub fn wrongBuild(run: *const Run, want: journal.Build) usize {
    var n: usize = 0;
    for (std.enums.values(journal.Build)) |b| {
        if (b != want) n += run.builds.get(b);
    }
    var named: usize = 0;
    for (std.enums.values(journal.Build)) |b| named += run.builds.get(b);
    return n + (run.files.count() -| named);
}

// ============================================================================
// The command
// ============================================================================

const usage =
    \\usage: wpt_build_compare --production=<dir> --bug-finding=<dir> [--known=<file>] [--log=<file>]...
    \\  <dir>: a run's output directory - its journal.jsonl and every
    \\         journal*.wptreport.jsonl under it (a sweep's full/ directory)
    \\  --known: the known differences (default tools/wpt_build_differences.txt)
    \\  --log:   the bug-finding run's log (a sweep's sweep.log), read for
    \\           leaks, bad frees, panics and poison reads; repeatable
    \\Exit status: 0 when the bug-finding gate passes and every difference is
    \\known and every known one seen; 1 otherwise; 2 on a usage error.
    \\
;

pub fn main(init: std.process.Init) !u8 {
    host.adopt(init.io);
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    const args = try init.minimal.args.toSlice(arena);
    var production_dir: ?[]const u8 = null;
    var bug_finding_dir: ?[]const u8 = null;
    var known_path: []const u8 = "tools/wpt_build_differences.txt";
    var logs: std.ArrayList([]const u8) = .empty;
    for (args[1..]) |arg| {
        if (valueOf(arg, "--production")) |v| {
            production_dir = v;
        } else if (valueOf(arg, "--bug-finding")) |v| {
            bug_finding_dir = v;
        } else if (valueOf(arg, "--known")) |v| {
            known_path = v;
        } else if (valueOf(arg, "--log")) |v| {
            try logs.append(arena, v);
        } else {
            try out.print("wpt_build_compare: unknown argument {s}\n{s}", .{ arg, usage });
            return 2;
        }
    }
    const pd = production_dir orelse {
        try out.writeAll(usage);
        return 2;
    };
    const bd = bug_finding_dir orelse {
        try out.writeAll(usage);
        return 2;
    };

    const known_text = readFile(arena, known_path) catch |err| {
        try out.print("wpt_build_compare: cannot read {s}: {t}\n", .{ known_path, err });
        return 2;
    };
    var diag: KnownDiagnostic = .{};
    const known = parseKnown(arena, known_text, &diag) catch |err| switch (err) {
        error.InvalidKnown => {
            try out.print("wpt_build_compare: {s}:{d}: {s}\n", .{ known_path, diag.line, diag.reason });
            return 2;
        },
        else => return err,
    };

    var production: Run = .{};
    var bug_finding: Run = .{};
    try loadRun(arena, &production, pd);
    try loadRun(arena, &bug_finding, bd);

    var findings: ?LogFindings = null;
    for (logs.items) |path| {
        const text = readFile(arena, path) catch |err| {
            try out.print("wpt_build_compare: cannot read the log {s}: {t}\n", .{ path, err });
            return 2;
        };
        if (findings == null) findings = .{};
        findings.?.scan(text);
    }

    const differences = try compare(arena, &production, &bug_finding);
    const report: Report = .{
        .production_files = production.files.count(),
        .bug_finding_files = bug_finding.files.count(),
        .differences = differences,
        .verdict = try check(arena, differences, known),
        .crashes = bug_finding.crashes.items,
        .ownership_violations = bug_finding.ownership_violations,
        .log = findings,
        .wrong_build = wrongBuild(&production, .production) + wrongBuild(&bug_finding, .bug_finding),
    };
    try report.write(out);
    return if (report.passed()) 0 else 1;
}

fn valueOf(arg: []const u8, comptime name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name ++ "=")) return null;
    return arg[name.len + 1 ..];
}

fn readFile(arena: Allocator, path: []const u8) ![]u8 {
    return host.cwd().readFileAlloc(host.io(), path, arena, .unlimited);
}

/// A run's output directory: its journal.jsonl, and every
/// journal*.wptreport.jsonl in it and below it (a sweep's chunks).
fn loadRun(arena: Allocator, run: *Run, dir_path: []const u8) !void {
    const journal_path = try std.fs.path.join(arena, &.{ dir_path, "journal.jsonl" });
    const log = try journal.read(arena, journal_path);
    try run.addJournal(arena, log);
    var dir = try host.cwd().openDir(host.io(), dir_path, .{ .iterate = true });
    defer dir.close(host.io());
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(host.io())) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.basename;
        if (!std.mem.startsWith(u8, name, "journal") or !std.mem.endsWith(u8, name, ".wptreport.jsonl")) continue;
        // A retry's streams are evidence, never a result (main.zig retryFailures).
        if (std.mem.startsWith(u8, entry.path, "retry")) continue;
        const bytes = try dir.readFileAlloc(host.io(), entry.path, arena, .unlimited);
        try run.addStream(arena, bytes);
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "a known difference is six TAB-separated fields, with an owner and evidence, and escapes in a field" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: KnownDiagnostic = .{};
    const text =
        "# comment\n" ++
        "\n" ++
        "dom/a.html\t*\tOK\tCRASH\tlane-x\tpoison read in Node::x (tmp/x.log)\n" ++
        "/dom/b.html\tname with \\t a tab\tPASS\tFAIL\tlane-y\tleak report\n";
    const known = try parseKnown(arena.allocator(), text, &diag);
    try testing.expectEqual(@as(usize, 2), known.len);
    try testing.expectEqualStrings("dom/a.html", known[0].test_id);
    try testing.expectEqualStrings(file_status, known[0].subtest);
    try testing.expectEqualStrings("CRASH", known[0].bug_finding);
    try testing.expectEqualStrings("name with \t a tab", known[1].subtest);
    try testing.expectEqualStrings("lane-y", known[1].owner);
}

test "a known difference with no owner, no evidence, equal statuses or listed twice is refused" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var diag: KnownDiagnostic = .{};
    try testing.expectError(error.InvalidKnown, parseKnown(arena.allocator(), "a.html\t*\tOK\tCRASH\t \tevidence\n", &diag));
    try testing.expectEqualStrings("no owner: every known difference has one", diag.reason);
    try testing.expectError(error.InvalidKnown, parseKnown(arena.allocator(), "a.html\t*\tOK\tCRASH\towner\t\n", &diag));
    try testing.expectEqualStrings("no evidence: every known difference has it", diag.reason);
    try testing.expectError(error.InvalidKnown, parseKnown(arena.allocator(), "a.html\t*\tOK\tOK\towner\tevidence\n", &diag));
    try testing.expectError(error.InvalidKnown, parseKnown(arena.allocator(), "a.html\t*\tOK\n", &diag));
    try testing.expectEqual(@as(usize, 1), diag.line);
    try testing.expectError(error.InvalidKnown, parseKnown(arena.allocator(), "a\t*\tOK\tCRASH\to\te\na\t*\tOK\tERROR\to\te\n", &diag));
    try testing.expectEqualStrings("listed twice", diag.reason);
    try testing.expectEqual(@as(usize, 2), diag.line);
}

test "the committed known-differences file parses" {
    // tools/wpt_build_differences.txt, read from the repository root (the
    // harness tests run there): every line has its owner and evidence.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const text = host.cwd().readFileAlloc(host.io(), "tools/wpt_build_differences.txt", arena.allocator(), .unlimited) catch |err| switch (err) {
        error.FileNotFound => return error.SkipZigTest,
        else => return err,
    };
    var diag: KnownDiagnostic = .{};
    _ = parseKnown(arena.allocator(), text, &diag) catch |err| {
        std.debug.print("tools/wpt_build_differences.txt:{d}: {s}\n", .{ diag.line, diag.reason });
        return err;
    };
}

fn fixtureRun(arena: Allocator, records: []const journal.Record, stream: []const u8) !Run {
    var run: Run = .{};
    try run.addJournal(arena, .{ .allocator = arena, .records = @constCast(records) });
    try run.addStream(arena, stream);
    return run;
}

test "the runs compared: a file's status, a subtest's, and a subtest only one run has" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const production = try fixtureRun(a, &.{
        .{ .index = 0, .path = "dom/a.html", .status = .ok, .build = .production },
        .{ .index = 1, .path = "dom/b.html", .status = .ok, .build = .production },
        .{ .index = 2, .path = "dom/c.html", .status = .ok, .build = .production },
    },
        \\{"test": "/dom/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}, {"name": "y", "status": "PASS", "message": null}]}
        \\{"test": "/dom/b.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}]}
        \\{"test": "/dom/c.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "z", "status": "PASS", "message": null}]}
        \\
    );
    const bug_finding = try fixtureRun(a, &.{
        .{ .index = 0, .path = "dom/a.html", .status = .ok, .build = .bug_finding },
        .{ .index = 1, .path = "dom/b.html", .status = .crash, .build = .bug_finding },
        .{ .index = 2, .path = "dom/c.html", .status = .ok, .build = .bug_finding },
    },
        \\{"test": "/dom/a.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "x", "status": "PASS", "message": null}, {"name": "y", "status": "FAIL", "message": "m"}]}
        \\{"test": "/dom/c.html", "status": "OK", "message": null, "duration": 1, "subtests": [{"name": "z", "status": "PASS", "message": null}, {"name": "w", "status": "PASS", "message": null}]}
        \\
    );
    const diffs = try compare(a, &production, &bug_finding);
    try testing.expectEqual(@as(usize, 3), diffs.len);
    // b crashed in the bug-finding run: its file's status, not its subtests.
    try testing.expectEqualStrings("dom/b.html", diffs[0].test_id);
    try testing.expectEqualStrings(file_status, diffs[0].subtest);
    try testing.expectEqualStrings("OK", diffs[0].production);
    try testing.expectEqualStrings("CRASH", diffs[0].bug_finding);
    try testing.expectEqualStrings("/dom/a.html", diffs[1].test_id);
    try testing.expectEqualStrings("y", diffs[1].subtest);
    try testing.expectEqualStrings("FAIL", diffs[1].bug_finding);
    try testing.expectEqualStrings("w", diffs[2].subtest);
    try testing.expectEqualStrings(missing, diffs[2].production);
    try testing.expectEqual(@as(usize, 1), bug_finding.crashes.items.len);
    try testing.expectEqual(@as(usize, 0), wrongBuild(&production, .production));
    try testing.expectEqual(@as(usize, 3), wrongBuild(&production, .bug_finding));
}

test "a difference the list names is known; one it does not is NEW; a listed one not seen is STALE" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const diffs = [_]Difference{
        .{ .test_id = "dom/b.html", .subtest = file_status, .production = "OK", .bug_finding = "CRASH" },
        .{ .test_id = "/dom/a.html", .subtest = "y", .production = "PASS", .bug_finding = "FAIL" },
    };
    const known = [_]Known{
        .{ .test_id = "dom/b.html", .subtest = file_status, .production = "OK", .bug_finding = "CRASH", .owner = "o", .evidence = "e" },
        .{ .test_id = "dom/gone.html", .subtest = file_status, .production = "OK", .bug_finding = "TIMEOUT", .owner = "o", .evidence = "e" },
    };
    const v = try check(a, &diffs, &known);
    try testing.expectEqual(@as(usize, 1), v.known);
    try testing.expectEqual(@as(usize, 1), v.new.len);
    try testing.expectEqualStrings("y", v.new[0].subtest);
    try testing.expectEqual(@as(usize, 1), v.stale.len);
    try testing.expectEqualStrings("dom/gone.html", v.stale[0].test_id);
    // A listed difference whose statuses moved is a new one, and the old line stale.
    const moved = [_]Difference{.{ .test_id = "dom/b.html", .subtest = file_status, .production = "OK", .bug_finding = "TIMEOUT" }};
    const v2 = try check(a, &moved, known[0..1]);
    try testing.expectEqual(@as(usize, 1), v2.new.len);
    try testing.expectEqual(@as(usize, 1), v2.stale.len);
}

test "a timing-bound difference lists the statuses each run takes, and is neither new when seen nor stale when not" {
    // Firefox metadata's `expected: [PASS, FAIL]`: a subtest that hinges on a
    // sub-tick gap passes or fails in either build (tools/wpt_loss_dispositions.txt
    // `timing-bound`). Seen with any of its statuses it is known; unseen it is
    // not stale - it simply landed the same way in both runs.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var diag: KnownDiagnostic = .{};
    const known = try parseKnown(a, "/sw/nt.https.html\tnav timing\tPASS|FAIL\tPASS|FAIL\ttiming-bound\tgeneration 211's disposition; x10: production 3/10, bug-finding 4/10\n", &diag);
    try testing.expect(known[0].intermittent());
    const seen = [_]Difference{.{ .test_id = "/sw/nt.https.html", .subtest = "nav timing", .production = "PASS", .bug_finding = "FAIL" }};
    const v = try check(a, &seen, known);
    try testing.expectEqual(@as(usize, 1), v.known);
    try testing.expectEqual(@as(usize, 0), v.new.len);
    const flipped = [_]Difference{.{ .test_id = "/sw/nt.https.html", .subtest = "nav timing", .production = "FAIL", .bug_finding = "PASS" }};
    try testing.expectEqual(@as(usize, 0), (try check(a, &flipped, known)).new.len);
    const unseen = try check(a, &.{}, known);
    try testing.expectEqual(@as(usize, 0), unseen.stale.len);
    // A status outside the list is new.
    const crashed = [_]Difference{.{ .test_id = "/sw/nt.https.html", .subtest = "nav timing", .production = "PASS", .bug_finding = "TIMEOUT" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, &crashed, known)).new.len);
    // "PASS|PASS" names one status: no difference.
    try testing.expectError(error.InvalidKnown, parseKnown(a, "/a\tx\tPASS|PASS\tPASS\to\te\n", &diag));
}

test "the bug-finding log: leaks, bad frees, panics, poison reads and refcount reports are counted" {
    var f: LogFindings = .{};
    f.scan(
        \\error(DebugAllocator): memory address 0x7f0012345678 leaked:
        \\error(DebugAllocator): memory address 0x7f0012345700 leaked:
        \\error(DebugAllocator): Double free detected. Allocation:  First free:  Second free:
        \\error(DebugAllocator): Allocation size 16 bytes does not match free size 8. Allocation:  Free:
        \\thread 1234 panic: reached unreachable code
        \\Segmentation fault at address 0xdddddddddddddded
        \\Segmentation fault at address 0x5555555555555555
        \\Segmentation fault at address 0x10
        \\refcount: node 0x1 has 2 parents
        \\warning: Cleanup validation failed for: templates
        \\a test that mentions leaked: memory in its message
    );
    try testing.expectEqual(@as(usize, 2), f.leaks);
    try testing.expectEqual(@as(usize, 2), f.bad_frees);
    try testing.expectEqual(@as(usize, 1), f.panics);
    // A null-ish fault is a crash, not a poison read.
    try testing.expectEqual(@as(usize, 2), f.poison_reads);
    try testing.expectEqual(@as(usize, 2), f.refcount);
    try testing.expectEqual(@as(usize, 9), f.total());
}

test "the report passes only with the gate clean and the differences all known" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var buf: [4096]u8 = undefined;
    var clean: Report = .{
        .production_files = 2,
        .bug_finding_files = 2,
        .differences = &.{},
        .verdict = .{ .new = &.{}, .stale = &.{}, .known = 0 },
        .crashes = &.{},
        .ownership_violations = 0,
        .log = .{},
        .wrong_build = 0,
    };
    try testing.expect(clean.passed());
    var w: std.Io.Writer = .fixed(&buf);
    try clean.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "build compare: PASS") != null);

    var leaky = clean;
    leaky.log = .{ .leaks = 1 };
    try testing.expect(!leaky.passed());
    var crashed = clean;
    crashed.crashes = &.{"dom/b.html"};
    try testing.expect(!crashed.gatePassed());
    var mixed = clean;
    mixed.wrong_build = 3;
    try testing.expect(!mixed.passed());
    const new = [_]Difference{.{ .test_id = "/a.html", .subtest = "x\ty", .production = "PASS", .bug_finding = "FAIL" }};
    var unexplained = clean;
    unexplained.differences = &new;
    unexplained.verdict = .{ .new = &new, .stale = &.{}, .known = 0 };
    try testing.expect(!unexplained.passed());
    w = .fixed(&buf);
    try unexplained.write(&w);
    // The NEW line is ready for the known list once it has an owner and evidence.
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "/a.html\tx\\ty\tPASS\tFAIL\t<owner>\t<evidence>\n") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "build compare: FAIL") != null);
}
