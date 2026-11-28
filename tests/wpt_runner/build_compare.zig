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
//!   sanitizer's reports), faults at a poison address, and the per-file V8
//!   handle gate's leak lines and summaries (handle_gate.zig).
//!
//! What fails it (exit 1): the bug-finding gate - a crash, a poison read, a
//! leak (of the heap or of V8 handles), a double free, a panic, a refcount
//! or ownership violation, a handle gate that did not check every OK file -
//! and any
//! difference between the runs that the known list does not name, or a known
//! difference that no longer occurs (remove it: the list only goes down).
//!
//! std-only (with the std-only `host` module), so `zig build test` runs its
//! tests.

const std = @import("std");
const host = @import("host");
const journal = @import("journal.zig");
const handle_gate = @import("handle_gate.zig");

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
    /// A subtest's: its file's status in each run (the journal's), null
    /// when that run's journal has no such file (`journalPathOf`).
    production_file: ?[]const u8 = null,
    bug_finding_file: ?[]const u8 = null,
};

pub const missing = "MISSING";

/// The journal path of a result stream's test URL: without its leading "/"
/// and any variant (`?...`) or fragment. A test generated from a
/// `.any.js` file has a URL the journal does not name (`.any.html`).
pub fn journalPathOf(test_id: []const u8) []const u8 {
    var path = test_id;
    if (path.len > 0 and path[0] == '/') path = path[1..];
    if (std.mem.indexOfAny(u8, path, "?#")) |i| path = path[0..i];
    return path;
}

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
        const path = journalPathOf(test_id);
        const production_file: ?[]const u8 = if (production.files.get(path)) |f| f.toString() else null;
        const bug_finding_file: ?[]const u8 = if (bug_finding.files.get(path)) |f| f.toString() else null;
        for (result.subtests.keys(), result.subtests.values()) |name, status| {
            const theirs = other.subtests.get(name) orelse missing;
            if (std.mem.eql(u8, status, theirs)) continue;
            try out.append(arena, .{ .test_id = test_id, .subtest = name, .production = status, .bug_finding = theirs, .production_file = production_file, .bug_finding_file = bug_finding_file });
        }
        for (other.subtests.keys(), other.subtests.values()) |name, status| {
            if (result.subtests.contains(name)) continue;
            try out.append(arena, .{ .test_id = test_id, .subtest = name, .production = missing, .bug_finding = status, .production_file = production_file, .bug_finding_file = bug_finding_file });
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
        } else fileTimeoutLine(d, known);
        if (hit) |i| {
            seen[i] = true;
            matched += 1;
        } else try new.append(arena, d);
    }
    var stale: std.ArrayList(Known) = .empty;
    for (known, seen) |k, s| if (!s and !k.intermittent()) try stale.append(arena, k);
    return .{ .new = try new.toOwnedSlice(arena), .stale = try stale.toOwnedSlice(arena), .known = matched };
}

/// A subtest the run that timed its FILE out left unfinished - TIMEOUT or
/// NOTRUN where the other run has it PASS - is that file's difference, not
/// one of its own: the file's `*` line covers it when the line lists TIMEOUT
/// for that run. Only when that run's file status is TIMEOUT: a subtest
/// that timed out in a file that run finished is a difference of its own
/// (integrator 2026-11-19, lane maj1: tools/wpt_build_differences.txt's
/// client-url-creation-url line).
fn fileTimeoutLine(d: Difference, known: []const Known) ?usize {
    if (std.mem.eql(u8, d.subtest, file_status)) return null;
    const in_production = unfinished(d.production) and std.mem.eql(u8, d.bug_finding, "PASS");
    const in_bug_finding = unfinished(d.bug_finding) and std.mem.eql(u8, d.production, "PASS");
    if (!in_production and !in_bug_finding) return null;
    const file = (if (in_production) d.production_file else d.bug_finding_file) orelse return null;
    if (!std.mem.eql(u8, file, "TIMEOUT")) return null;
    const path = journalPathOf(d.test_id);
    for (known, 0..) |k, i| {
        if (!std.mem.eql(u8, k.subtest, file_status) or !std.mem.eql(u8, k.test_id, path)) continue;
        if (listed(if (in_production) k.production else k.bug_finding, "TIMEOUT")) return i;
    }
    return null;
}

fn unfinished(status: []const u8) bool {
    return std.mem.eql(u8, status, "TIMEOUT") or std.mem.eql(u8, status, "NOTRUN");
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
    /// The heap's leak report at a Browser's end (runtime.BrowserScope.
    /// reportHeapLeaks, allocator-hardening batch A): Browsers that ended
    /// with State blocks or Instance slots still alive in their heap - which
    /// the heap's release frees, so no allocator reports them as leaked.
    heap_leaks: usize = 0,
    /// Nodes the final sweep released at Browser ends (`heap swept:`): held
    /// past every realm's end - refcount decision D9's count, reported by
    /// refcount_teardown.agentEnded - never a gate failure here, so the
    /// heap does not report them twice (the integrator, 2026-11-23).
    heap_swept_nodes: usize = 0,
    /// A Browser that fell off the full heap reservation rung (`cage_alone`,
    /// `smaller_cage`, `unreserved`): general memory fell back to the host
    /// allocator, so the bug-finding run did not exercise the hardened pools
    /// (allocator-hardening design §10.2).
    unexpected_rungs: usize = 0,
    /// Files whose V8 handles rose past their cap in
    /// tools/wpt_handle_leaks_baseline.txt after the page closed and a full
    /// GC (`handle leak: <path>: ...`, handle_gate.writeDiagnostic): a handle
    /// leak fails the gate like a heap leak (tmp/plans/queue-0.1-audit.md,
    /// "Bug-finding gate does not count V8 handles"; audit report-I H1).
    handle_leaks: usize = 0,
    /// The runner processes' handle gate summaries (handle_gate.Tally): how
    /// many reported. Evidence for the reader; the gate holds the run's OK
    /// files to the per-file check lines (`handleCoverage`), which a process
    /// that dies mid-run keeps and its summary does not.
    handle_gate_runs: usize = 0,
    /// The baseline the first summary names ("none": 0 / 0 for every file).
    handle_baseline: []const u8 = "",

    pub fn total(self: LogFindings) usize {
        return self.leaks + self.bad_frees + self.panics + self.poison_reads + self.refcount + self.heap_leaks + self.unexpected_rungs;
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
        // The summary line, one per Browser; the per-type lines before it
        // name what it counts.
        if (contains(line, "heap leak: ") and contains(line, " alive at the Browser's end") and contains(line, " Instance slot(s)")) self.heap_leaks += 1;
        if (std.mem.indexOf(u8, line, "heap swept: ")) |at| {
            const rest = line[at + "heap swept: ".len ..];
            const digits = std.mem.indexOfNone(u8, rest, "0123456789") orelse rest.len;
            self.heap_swept_nodes += std.fmt.parseInt(usize, rest[0..digits], 10) catch 0;
        }
        // Design §10.2: Browser.init logs non-full heap reservation rungs
        // ("the Browser's heap got the <rung> rung: ..."); any non-full rung
        // fails the bug-finding gate.
        if (std.mem.indexOf(u8, line, "the Browser's heap got the ")) |at| {
            const rest = line[at + "the Browser's heap got the ".len ..];
            if (!std.mem.startsWith(u8, rest, "full ")) self.unexpected_rungs += 1;
        }
        if (handle_gate.isLeakLine(line)) self.handle_leaks += 1;
        if (handle_gate.Tally.parseSummary(line)) |t| {
            if (self.handle_gate_runs == 0) self.handle_baseline = if (t.baseline.len > 0) t.baseline else "none";
            self.handle_gate_runs += 1;
        }
    }
};

/// The bug-finding run's OK files against the handle gate's per-file lines
/// in its log(s) (handle_gate.zig): each OK file must have a check - a clean
/// line or a leak line. One the engine gave no counters for (`unread`), or
/// with no line at all, was not checked.
pub const HandleCoverage = struct {
    ok_files: usize = 0,
    checked: usize = 0,
    unread: usize = 0,
    unchecked: usize = 0,
    /// The first OK file (in the journal's order) with no line.
    first_unchecked: ?[]const u8 = null,
    /// OK files whose settle hit its bound before the closed page was gone
    /// (`handle unsettled:`): their reading is taken anyway, and named.
    unsettled: usize = 0,
    first_unsettled: ?[]const u8 = null,
    /// Leak lines of OK files: of files that read unsettled and are listed
    /// in tools/wpt_handle_unsettled.txt (pending the settle's end condition:
    /// counted, not failing), and of every other file (failing: over its
    /// tools/wpt_handle_leaks_baseline.txt cap after a settled reading, or
    /// unsettled and unlisted).
    pending_leaks: usize = 0,
    blocking_leaks: usize = 0,
    first_blocking_leak: ?[]const u8 = null,
    /// Unsettled readings of files the list does not name, with a handle
    /// leak (failing: the integrator's ruling 2026-11-28 3:10 AM ET, (a))...
    new_unsettled: usize = 0,
    first_new_unsettled: ?[]const u8 = null,
    /// ... and with none (reported, not failing: workers/ and xhr/ files
    /// read so in 1 of 3 FULL runs, never leaking).
    unsettled_quiet: usize = 0,
    first_unsettled_quiet: ?[]const u8 = null,
    /// Listed files that ran OK and settled: remove them (the list only goes
    /// down; failing, as a stale known difference is).
    stale_unsettled: usize = 0,
    first_stale_unsettled: ?[]const u8 = null,
};

/// The default list of files whose handle readings may be unsettled
/// (option B, the integrator 2026-11-27 10:31 PM ET).
pub const default_unsettled_path = "tools/wpt_handle_unsettled.txt";

/// The most entries tools/wpt_handle_unsettled.txt may hold: the 549 files
/// lane gate2's three FULL bug-finding runs all read unsettled (2026-11-27/28).
/// It only goes down - lower this as entries go, never raise it without the
/// integrator.
pub const max_unsettled_entries = 549;

/// The unsettled list: one worklist path a line, `#` comments; each path
/// once. A path followed by a TAB, `intermittent`, a TAB and its evidence
/// reads unsettled in some runs only (Firefox metadata's `expected: [PASS,
/// FAIL]`): never NEW when it reads so, never STALE when it settles. The
/// value is whether the entry is intermittent.
pub fn parseUnsettledList(arena: Allocator, text: []const u8) error{ OutOfMemory, InvalidUnsettledList }!std.StringHashMapUnmanaged(bool) {
    var set: std.StringHashMapUnmanaged(bool) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \r");
        if (line.len == 0 or line[0] == '#') continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const path = std.mem.trim(u8, fields.first(), " ");
        var intermittent = false;
        if (fields.next()) |kind| {
            if (!std.mem.eql(u8, kind, "intermittent")) return error.InvalidUnsettledList;
            const evidence = fields.next() orelse return error.InvalidUnsettledList;
            if (std.mem.trim(u8, evidence, " ").len == 0) return error.InvalidUnsettledList;
            intermittent = true;
        }
        if (path.len == 0) return error.InvalidUnsettledList;
        const gop = try set.getOrPut(arena, path);
        if (gop.found_existing) return error.InvalidUnsettledList;
        gop.value_ptr.* = intermittent;
    }
    return set;
}

/// `handleCoverageListed` with no unsettled list: every unsettled file is new.
pub fn handleCoverage(arena: Allocator, logs: []const []const u8, run: *const Run) Allocator.Error!HandleCoverage {
    const none: std.StringHashMapUnmanaged(bool) = .empty;
    const no_baseline = handle_gate.Baseline.empty(arena);
    return handleCoverageListed(arena, logs, run, &none, &no_baseline);
}

/// The run's OK files against the handle gate's lines, judged with the tree's
/// unsettled list and its baseline: a leak line whose printed deltas are
/// within the file's caps in `baseline` is no leak, whatever caps the runner
/// applied (the integrator's ruling 2026-11-28 3:10 AM ET, (c): the baseline
/// file is the single source of truth).
pub fn handleCoverageListed(arena: Allocator, logs: []const []const u8, run: *const Run, allowed_unsettled: *const std.StringHashMapUnmanaged(bool), baseline: *const handle_gate.Baseline) Allocator.Error!HandleCoverage {
    var leaked: std.StringHashMapUnmanaged(void) = .empty;
    var checked: std.StringHashMapUnmanaged(void) = .empty;
    var unread: std.StringHashMapUnmanaged(void) = .empty;
    var unsettled: std.StringHashMapUnmanaged(void) = .empty;
    for (logs) |text| {
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            if (handle_gate.checkedPath(line)) |p| try checked.put(arena, p, {});
            if (handle_gate.parseLeakLine(line)) |l| {
                try checked.put(arena, l.path, {});
                const limits = baseline.limitsFor(l.path);
                if (l.delta.exceeds(limits.max_object_globals, limits.max_wrapper_cache_entries)) try leaked.put(arena, l.path, {});
            } else if (handle_gate.leakPath(line)) |p| {
                // A leak line whose deltas do not parse: judged a leak.
                try checked.put(arena, p, {});
                try leaked.put(arena, p, {});
            }
            if (handle_gate.unreadPath(line)) |p| try unread.put(arena, p, {});
            if (handle_gate.unsettledPath(line)) |p| try unsettled.put(arena, p, {});
        }
    }
    var c: HandleCoverage = .{};
    for (run.files.keys(), run.files.values()) |path, status| {
        if (status != .ok) continue;
        c.ok_files += 1;
        const is_unsettled = unsettled.contains(path);
        const is_listed = allowed_unsettled.contains(path);
        const is_intermittent = allowed_unsettled.get(path) orelse false;
        if (is_unsettled) {
            c.unsettled += 1;
            if (c.first_unsettled == null) c.first_unsettled = path;
            if (!is_listed) {
                if (leaked.contains(path)) {
                    c.new_unsettled += 1;
                    if (c.first_new_unsettled == null) c.first_new_unsettled = path;
                } else {
                    c.unsettled_quiet += 1;
                    if (c.first_unsettled_quiet == null) c.first_unsettled_quiet = path;
                }
            }
        } else if (is_listed and !is_intermittent and (checked.contains(path) or unread.contains(path))) {
            c.stale_unsettled += 1;
            if (c.first_stale_unsettled == null) c.first_stale_unsettled = path;
        }
        if (leaked.contains(path) and !(is_unsettled and !is_listed)) {
            if (is_unsettled and is_listed) {
                c.pending_leaks += 1;
            } else {
                c.blocking_leaks += 1;
                if (c.first_blocking_leak == null) c.first_blocking_leak = path;
            }
        }
        if (checked.contains(path)) {
            c.checked += 1;
        } else if (unread.contains(path)) {
            c.unread += 1;
        } else {
            c.unchecked += 1;
            if (c.first_unchecked == null) c.first_unchecked = path;
        }
    }
    return c;
}

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
    /// The bug-finding run's OK files against the handle gate's lines in the
    /// log (`handleCoverage`); null when no log was given.
    handle: ?HandleCoverage = null,

    pub fn passed(self: Report) bool {
        return self.gatePassed() and self.verdict.new.len == 0 and self.verdict.stale.len == 0 and self.wrong_build == 0;
    }

    pub fn gatePassed(self: Report) bool {
        const log_clean = if (self.log) |l| l.total() == 0 else true;
        return self.crashes.len == 0 and self.ownership_violations == 0 and log_clean and self.handleGateProblem() == null;
    }

    pub const HandleGateProblem = enum {
        /// No file's check in the log: the handle gate never ran (a runner
        /// from before it, or a log that is not the run's).
        not_run,
        /// An OK file was not checked: no line for it, or no counters.
        unchecked,
        /// A handle leak of a file not pending in the unsettled list.
        leaks,
        /// An unsettled reading of a file the list does not name.
        new_unsettled,
        /// A listed file that settled.
        stale_unsettled,
    };

    /// Why the handle gate's lines do not cover the run's OK files, or null
    /// when they do (or no log was given: then, as for leaks, nothing is read).
    pub fn handleGateProblem(self: Report) ?HandleGateProblem {
        const h = self.handle orelse return null;
        if (h.ok_files == 0) return null;
        if (h.checked == 0 and h.unread == 0) return .not_run;
        if (h.unchecked > 0 or h.unread > 0) return .unchecked;
        if (h.blocking_leaks > 0) return .leaks;
        if (h.new_unsettled > 0) return .new_unsettled;
        if (h.stale_unsettled > 0) return .stale_unsettled;
        return null;
    }

    pub fn write(self: Report, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("build compare: production {d} files, bug-finding {d} files\n", .{ self.production_files, self.bug_finding_files });
        if (self.wrong_build > 0) try w.print("  WRONG BUILD: {d} journal record(s) are not the side they were given as (a production journal as --production, a bug-finding one as --bug-finding)\n", .{self.wrong_build});
        try w.print("bug-finding gate: {s} - crashes {d}, ownership violations {d}", .{ if (self.gatePassed()) "PASS" else "FAIL", self.crashes.len, self.ownership_violations });
        if (self.log) |l| {
            const h = self.handle orelse HandleCoverage{};
            try w.print(", leaks {d}, bad frees {d}, panics {d}, poison reads {d}, refcount {d}, heap leaks {d}, unexpected rungs {d}, handle leaks {d} (and {d} node(s) swept at Browser ends, not counted)\n", .{ l.leaks, l.bad_frees, l.panics, l.poison_reads, l.refcount, l.heap_leaks, l.unexpected_rungs, h.blocking_leaks, l.heap_swept_nodes });
            if (self.handleGateProblem()) |p| switch (p) {
                .not_run => try w.print("  handle gate: NOT RUN - no file's handle check in the log, so none of the bug-finding run's {d} OK file(s) was checked\n", .{h.ok_files}),
                .unchecked => try w.print("  handle gate: NOT RECONCILED - checked {d} of the bug-finding run's {d} OK file(s): {d} unread (no counters), {d} with no check line (first: {s})\n", .{ h.checked, h.ok_files, h.unread, h.unchecked, h.first_unchecked orelse "-" }),
                else => {},
            };
            const problem = self.handleGateProblem();
            const coverage_ok = if (problem) |pr| pr != .not_run and pr != .unchecked else true;
            if (coverage_ok)
                try w.print("  handle gate: checked {d} of the bug-finding run's {d} OK file(s) ({d} runner process summaries), {d} handle leak(s) over the baseline (first: {s}); baseline {s}\n", .{ h.checked, h.ok_files, l.handle_gate_runs, h.blocking_leaks, h.first_blocking_leak orelse "-", if (l.handle_baseline.len > 0) l.handle_baseline else "none" });
            const listed_unsettled = h.unsettled - h.new_unsettled - h.unsettled_quiet;
            if (listed_unsettled > 0) try w.print("  handle gate: {d} OK file(s) read UNSETTLED, all listed in " ++ default_unsettled_path ++ " ({d} with a handle leak, pending)\n", .{ listed_unsettled, h.pending_leaks });
            if (h.unsettled_quiet > 0) try w.print("  handle gate: {d} unlisted file(s) read unsettled with no handle leak - reported, not failing (first: {s})\n", .{ h.unsettled_quiet, h.first_unsettled_quiet orelse "-" });
            if (h.new_unsettled > 0) try w.print("  handle gate: {d} NEW unsettled file(s) with a handle leak, not in " ++ default_unsettled_path ++ " (first: {s})\n", .{ h.new_unsettled, h.first_new_unsettled orelse "-" });
            if (h.stale_unsettled > 0) try w.print("  handle gate: {d} STALE entry(ies) of " ++ default_unsettled_path ++ " settled - remove them (first: {s})\n", .{ h.stale_unsettled, h.first_stale_unsettled orelse "-" });
        } else try w.writeAll(" (no log given: leaks, bad frees, panics, poison reads and handle leaks not read)\n");
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
    \\  --unsettled: the files whose handle reading may be unsettled
    \\           (default tools/wpt_handle_unsettled.txt)
    \\  --handle-baseline: the per-file handle caps re-applied to each leak
    \\           line (default tools/wpt_handle_leaks_baseline.txt)
    \\  --log:   the bug-finding run's log (a sweep's sweep.log), read for
    \\           leaks, bad frees, panics, poison reads and the V8 handle
    \\           gate's leaks and summaries; repeatable
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
    var unsettled_path: []const u8 = default_unsettled_path;
    var handle_baseline_path: []const u8 = handle_gate.default_baseline_path;
    var logs: std.ArrayList([]const u8) = .empty;
    for (args[1..]) |arg| {
        if (valueOf(arg, "--production")) |v| {
            production_dir = v;
        } else if (valueOf(arg, "--bug-finding")) |v| {
            bug_finding_dir = v;
        } else if (valueOf(arg, "--known")) |v| {
            known_path = v;
        } else if (valueOf(arg, "--unsettled")) |v| {
            unsettled_path = v;
        } else if (valueOf(arg, "--handle-baseline")) |v| {
            handle_baseline_path = v;
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

    const unsettled_text = readFile(arena, unsettled_path) catch |err| {
        try out.print("wpt_build_compare: cannot read {s}: {t}\n", .{ unsettled_path, err });
        return 2;
    };
    const allowed_unsettled = parseUnsettledList(arena, unsettled_text) catch |err| switch (err) {
        error.InvalidUnsettledList => {
            try out.print("wpt_build_compare: {s}: a path is listed twice\n", .{unsettled_path});
            return 2;
        },
        else => return err,
    };

    var hdiag: handle_gate.ParseDiagnostic = .{};
    const baseline = handle_gate.Baseline.load(arena, handle_baseline_path, &hdiag) catch |err| {
        try out.print("wpt_build_compare: cannot read the handle baseline {s}:{d}: {s} ({t})\n", .{ handle_baseline_path, hdiag.line, hdiag.reason, err });
        return 2;
    };

    var production: Run = .{};
    var bug_finding: Run = .{};
    try loadRun(arena, &production, pd);
    try loadRun(arena, &bug_finding, bd);

    var findings: ?LogFindings = null;
    var log_texts: std.ArrayList([]const u8) = .empty;
    for (logs.items) |path| {
        const text = readFile(arena, path) catch |err| {
            try out.print("wpt_build_compare: cannot read the log {s}: {t}\n", .{ path, err });
            return 2;
        };
        if (findings == null) findings = .{};
        findings.?.scan(text);
        try log_texts.append(arena, text);
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
        .handle = if (findings != null) try handleCoverageListed(arena, log_texts.items, &bug_finding, &allowed_unsettled, &baseline) else null,
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
pub fn loadRun(arena: Allocator, run: *Run, dir_path: []const u8) !void {
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

test "a file's timeout line also covers the subtests a run left unfinished when that run timed the file out" {
    // A run in which the FILE timed out reports the subtests it never reached
    // TIMEOUT or NOTRUN, where the other run has them PASS: one difference,
    // the file's (tools/wpt_build_differences.txt's client-url-creation-url
    // line, lane maj1's FULL A/B of 2026-11-19: 7 such subtests).
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const known = [_]Known{
        .{ .test_id = "sw/c.https.html", .subtest = file_status, .production = "OK|TIMEOUT", .bug_finding = "OK|TIMEOUT", .owner = "o", .evidence = "e" },
    };
    const diffs = [_]Difference{
        .{ .test_id = "sw/c.https.html", .subtest = file_status, .production = "OK", .bug_finding = "TIMEOUT" },
        .{ .test_id = "/sw/c.https.html", .subtest = "first", .production = "PASS", .bug_finding = "TIMEOUT", .production_file = "OK", .bug_finding_file = "TIMEOUT" },
        .{ .test_id = "/sw/c.https.html", .subtest = "second", .production = "PASS", .bug_finding = "NOTRUN", .production_file = "OK", .bug_finding_file = "TIMEOUT" },
    };
    const v = try check(a, &diffs, &known);
    try testing.expectEqual(@as(usize, 0), v.new.len);
    try testing.expectEqual(@as(usize, 3), v.known);
    // Either build: the production run timed it out.
    const flipped = [_]Difference{.{ .test_id = "/sw/c.https.html", .subtest = "third", .production = "NOTRUN", .bug_finding = "PASS", .production_file = "TIMEOUT", .bug_finding_file = "OK" }};
    try testing.expectEqual(@as(usize, 0), (try check(a, &flipped, &known)).new.len);
    // A subtest TIMEOUT inside a file that run finished (OK) is new.
    const finished = [_]Difference{.{ .test_id = "/sw/c.https.html", .subtest = "first", .production = "PASS", .bug_finding = "TIMEOUT", .production_file = "OK", .bug_finding_file = "OK" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, &finished, &known)).new.len);
    // A subtest that FAILs where the other run PASSes is no timeout's: new.
    const failed = [_]Difference{.{ .test_id = "/sw/c.https.html", .subtest = "first", .production = "PASS", .bug_finding = "FAIL", .production_file = "OK", .bug_finding_file = "TIMEOUT" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, &failed, &known)).new.len);
    // A file with no * line is not covered, nor one whose line lists no TIMEOUT.
    const other = [_]Difference{.{ .test_id = "/sw/d.https.html", .subtest = "first", .production = "PASS", .bug_finding = "TIMEOUT", .production_file = "OK", .bug_finding_file = "TIMEOUT" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, &other, &known)).new.len);
    const crash_line = [_]Known{.{ .test_id = "sw/c.https.html", .subtest = file_status, .production = "OK", .bug_finding = "CRASH", .owner = "o", .evidence = "e" }};
    try testing.expectEqual(@as(usize, 1), (try check(a, diffs[1..2], &crash_line)).new.len);
}

test "compare records each subtest's file status in both runs" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var production: Run = .{};
    var bug_finding: Run = .{};
    try production.files.put(a, "sw/c.https.html", .ok);
    try bug_finding.files.put(a, "sw/c.https.html", .timeout);
    try production.addStream(a, "{\"test\": \"/sw/c.https.html?x=1\", \"status\": \"OK\", \"subtests\": [{\"name\": \"first\", \"status\": \"PASS\"}]}\n");
    try bug_finding.addStream(a, "{\"test\": \"/sw/c.https.html?x=1\", \"status\": \"TIMEOUT\", \"subtests\": [{\"name\": \"first\", \"status\": \"TIMEOUT\"}]}\n");
    const diffs = try compare(a, &production, &bug_finding);
    try testing.expectEqual(@as(usize, 2), diffs.len);
    try testing.expectEqualStrings("OK", diffs[1].production_file.?);
    try testing.expectEqualStrings("TIMEOUT", diffs[1].bug_finding_file.?);
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
        \\warning(heap): heap leak: 3 block(s) of 112 B alive at the Browser's end: webidl.Event.State
        \\warning(heap): heap leak: 3 State block(s) and 3 Instance slot(s) alive at the Browser's end
        \\warning(heap): heap swept: 12 node(s) released at the Browser's end, after the final sweep
    );
    try testing.expectEqual(@as(usize, 2), f.leaks);
    try testing.expectEqual(@as(usize, 2), f.bad_frees);
    try testing.expectEqual(@as(usize, 1), f.panics);
    // A null-ish fault is a crash, not a poison read.
    try testing.expectEqual(@as(usize, 2), f.poison_reads);
    try testing.expectEqual(@as(usize, 2), f.refcount);
    // One Browser ended with blocks alive in its heap: counted once.
    try testing.expectEqual(@as(usize, 1), f.heap_leaks);
    // The final sweep's nodes are counted apart, and fail nothing.
    try testing.expectEqual(@as(usize, 12), f.heap_swept_nodes);
    try testing.expectEqual(@as(usize, 10), f.total());
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

test "unexpected non-full heap rungs fail the bug-finding gate (§10.2)" {
    var f: LogFindings = .{};
    f.scan(
        \\warning(browser): the Browser's heap got the cage_alone rung: its objects partition is in the cage's upper half
        \\warning(browser): the Browser's heap got the smaller_cage rung: its objects partition is in the cage's upper half
        \\warning(browser): the Browser's heap got the unreserved rung: its objects partition is in the cage's upper half
    );
    // Those are Browser.init's own line (src/browser/Browser.zig, at
    // Browser.heap_rung_log_level, which main.zig holds at or above the
    // runner's log level); a Browser on the full rung logs nothing.
    try testing.expectEqual(@as(usize, 3), f.unexpected_rungs);
    try testing.expectEqual(@as(usize, 3), f.total());

    var rung_fail: Report = .{
        .production_files = 1,
        .bug_finding_files = 1,
        .differences = &.{},
        .verdict = .{ .new = &.{}, .stale = &.{}, .known = 0 },
        .crashes = &.{},
        .ownership_violations = 0,
        .log = f,
        .wrong_build = 0,
    };
    try testing.expect(!rung_fail.gatePassed());
    try testing.expect(!rung_fail.passed());

    var buf: [2048]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try rung_fail.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "unexpected rungs 3") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "bug-finding gate: FAIL") != null);
}

test "a V8 handle leak line in the bug-finding log counts in the gate's total, as a heap leak's does" {
    // The bug-finding runner prints this line (main.zig, handle_gate.writeDiagnostic)
    // for a file whose net live_object_globals or wrapper_cache_entries rose past
    // its tools/wpt_handle_leaks_baseline.txt cap after the page closed and a full GC.
    var f: LogFindings = .{};
    f.scan(
        \\warning(handle): handle leak: streams/a.html: live_object_globals +1 (max 0), wrapper_cache_entries +5 (max 0), global_handle_bytes +64, node_wrappers 0
    );
    try testing.expectEqual(@as(usize, 1), f.handle_leaks);
    // The gate judges it through the handle coverage (option B: a leak of a
    // file pending in the unsettled list is counted, not failing).
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const run = try fixtureRun(arena_state.allocator(), &.{.{ .index = 0, .path = "streams/a.html", .status = .ok }}, "");
    const h = try handleCoverage(arena_state.allocator(), &.{"warning(handle): handle leak: streams/a.html: live_object_globals +1 (max 0), wrapper_cache_entries +5 (max 0), global_handle_bytes +64, node_wrappers 0"}, &run);
    try testing.expectEqual(@as(usize, 1), h.blocking_leaks);
}

test "a V8 handle leak fails the bug-finding gate like a heap leak, and the handle gate must have checked every OK file" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    // The bug-finding run: three OK files, one TIMEOUT (never checked).
    const records = [_]journal.Record{
        .{ .index = 0, .path = "streams/a.html", .status = .ok },
        .{ .index = 1, .path = "dom/b.html", .status = .ok },
        .{ .index = 2, .path = "dom/c-crash.html", .status = .ok, .crashtest = true },
        .{ .index = 3, .path = "dom/d.html", .status = .timeout },
    };
    const run = try fixtureRun(arena, &records, "");
    // Each OK file's check is a line of its own (main.zig, handle_gate.zig):
    // a runner process that dies mid-run (a stall, a crash) loses its end
    // summary, never the lines of the files it checked.
    const log =
        \\warning(handle): handle leak: streams/a.html: live_object_globals +1 (max 0), wrapper_cache_entries +5 (max 0), global_handle_bytes +64, node_wrappers 0
        \\handle checked: dom/b.html
        \\handle checked: dom/c-crash.html
        \\handle gate: checked 3 file(s), 1 handle leak(s) over the baseline, 0 OK file(s) unread (no counters); baseline tools/wpt_handle_leaks_baseline.txt (5 entries)
        \\warning(heap): heap leak: 3 State block(s) and 3 Instance slot(s) alive at the Browser's end
    ;
    var f: LogFindings = .{};
    f.scan(log);
    try testing.expectEqual(@as(usize, 1), f.handle_leaks);
    try testing.expectEqual(@as(usize, 1), f.heap_leaks);
    try testing.expectEqual(@as(usize, 1), f.total());
    try testing.expectEqual(@as(usize, 1), f.handle_gate_runs);
    try testing.expectEqualStrings("tools/wpt_handle_leaks_baseline.txt", f.handle_baseline);
    const coverage = try handleCoverage(arena, &.{log}, &run);
    try testing.expectEqual(@as(usize, 3), coverage.ok_files);
    try testing.expectEqual(@as(usize, 3), coverage.checked);
    try testing.expectEqual(@as(usize, 0), coverage.unchecked);
    try testing.expectEqual(@as(usize, 0), coverage.unsettled);
    // A file read at the settle's bound is named, and still judged by its check.
    const late = try handleCoverage(arena, &.{ log, "handle unsettled: dom/b.html: after 80 rounds the event loop has pending work and 1 agent(s) beyond the clean reading are alive" }, &run);
    try testing.expectEqual(@as(usize, 1), late.unsettled);
    try testing.expectEqualStrings("dom/b.html", late.first_unsettled.?);
    try testing.expectEqual(@as(usize, 3), late.checked);

    var report: Report = .{
        .production_files = 4,
        .bug_finding_files = 4,
        .differences = &.{},
        .verdict = .{ .new = &.{}, .stale = &.{}, .known = 0 },
        .crashes = &.{},
        .ownership_violations = 0,
        .log = f,
        .handle = coverage,
        .wrong_build = 0,
    };
    try testing.expect(!report.gatePassed());
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try report.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle leaks 1") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "bug-finding gate: FAIL") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: checked 3 of the bug-finding run's 3 OK file(s)") != null);

    // Clean: every OK file checked, no leak.
    var clean = report;
    clean.log = .{ .handle_gate_runs = 1 };
    clean.handle = try handleCoverage(arena, &.{"handle checked: streams/a.html\nhandle checked: dom/b.html\nhandle checked: dom/c-crash.html\n"}, &run);
    try testing.expect(clean.gatePassed());
    try testing.expect(clean.handleGateProblem() == null);

    // A log with no check line: the handle gate never ran (a runner from
    // before it, or a log that is not the run's).
    var unrun = report;
    unrun.log = .{};
    unrun.handle = try handleCoverage(arena, &.{"heap swept: 0 node(s)"}, &run);
    try testing.expect(!unrun.gatePassed());
    w = .fixed(&buf);
    try unrun.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: NOT RUN") != null);

    // An OK file with no check line, and one the engine gave no counters for.
    var short = report;
    short.log = .{};
    short.handle = try handleCoverage(arena, &.{"handle checked: dom/b.html\nhandle unread: dom/c-crash.html\n"}, &run);
    try testing.expectEqual(@as(usize, 1), short.handle.?.unchecked);
    try testing.expectEqual(@as(usize, 1), short.handle.?.unread);
    try testing.expect(!short.gatePassed());
    w = .fixed(&buf);
    try short.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: NOT RECONCILED - checked 1 of the bug-finding run's 3 OK file(s): 1 unread (no counters), 1 with no check line (first: streams/a.html)") != null);

    // No log given: the handle gate is not read (as leaks are not).
    var no_log = clean;
    no_log.log = null;
    no_log.handle = null;
    try testing.expect(no_log.gatePassed());
}

test "a check line names its file: clean, unread, or its leak line" {
    try testing.expectEqualStrings("dom/b.html", handle_gate.checkedPath("handle checked: dom/b.html").?);
    try testing.expectEqualStrings("dom/c.html", handle_gate.unreadPath("handle unread: dom/c.html").?);
    try testing.expectEqualStrings("dom/w.any.worker.html", handle_gate.unsettledPath("handle unsettled: dom/w.any.worker.html: after 80 rounds the event loop has pending work and 1 agent(s) beyond the clean reading are alive").?);
    try testing.expectEqualStrings("streams/a.html", handle_gate.leakPath("warning(handle): handle leak: streams/a.html: live_object_globals +1 (max 0), wrapper_cache_entries 0 (max 0), global_handle_bytes +8, node_wrappers 0").?);
    try testing.expect(handle_gate.checkedPath("handle gate: checked 3 file(s), 0 handle leak(s) over the baseline, 0 OK file(s) unread (no counters); baseline none (every file held to 0 / 0)") == null);
    try testing.expect(handle_gate.leakPath("warning(heap): heap leak: 3 State block(s) and 3 Instance slot(s) alive at the Browser's end") == null);
}

test "option B: an unsettled reading is pending only for a listed file; a new unsettled file, a listed file that settled, and a settled leak fail the gate" {
    // The integrator's ruling, 2026-11-27 10:31 PM ET: a reading the settle
    // could not bring to its end condition is reported and counted, never a
    // pass by itself - tools/wpt_handle_unsettled.txt lists the files allowed
    // to read so (pending the settle's service-worker end and bfcache flush),
    // and it only goes down.
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const records = [_]journal.Record{
        .{ .index = 0, .path = "fetch/sw.any.js", .status = .ok },
        .{ .index = 1, .path = "fetch/sw-quiet.any.js", .status = .ok },
        .{ .index = 2, .path = "dom/clean.html", .status = .ok },
    };
    const run = try fixtureRun(arena, &records, "");
    const allowed = try parseUnsettledList(arena, "# pending hsettle1\nfetch/sw.any.js\nfetch/sw-quiet.any.js\n");
    var no_baseline = handle_gate.Baseline.empty(testing.allocator);
    defer no_baseline.deinit();
    try testing.expectEqual(@as(usize, 2), allowed.count());

    // Both listed files read unsettled; one also leaks +1: pending, the gate passes.
    const pending_log =
        \\handle unsettled: fetch/sw.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\warning(handle): handle leak: fetch/sw.any.js: live_object_globals +1 (max 0), wrapper_cache_entries 0 (max 0), global_handle_bytes 0, node_wrappers 0
        \\handle unsettled: fetch/sw-quiet.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw-quiet.any.js
        \\handle checked: dom/clean.html
    ;
    var f: LogFindings = .{};
    f.scan(pending_log);
    var report: Report = .{
        .production_files = 3,
        .bug_finding_files = 3,
        .differences = &.{},
        .verdict = .{ .new = &.{}, .stale = &.{}, .known = 0 },
        .crashes = &.{},
        .ownership_violations = 0,
        .log = f,
        .handle = try handleCoverageListed(arena, &.{pending_log}, &run, &allowed, &no_baseline),
        .wrong_build = 0,
    };
    const h = report.handle.?;
    try testing.expectEqual(@as(usize, 2), h.unsettled);
    try testing.expectEqual(@as(usize, 1), h.pending_leaks);
    try testing.expectEqual(@as(usize, 0), h.blocking_leaks);
    try testing.expect(report.gatePassed());
    var buf: [4096]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try report.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "bug-finding gate: PASS") != null);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "2 OK file(s) read UNSETTLED, all listed in tools/wpt_handle_unsettled.txt (1 with a handle leak, pending)") != null);

    // A file that settled before now reads unsettled: NEW, the gate fails.
    const new_log =
        \\handle unsettled: dom/clean.html: after 80 rounds the event loop has pending work and 0 agent(s) beyond the clean reading are alive
        \\handle checked: dom/clean.html
        \\handle unsettled: fetch/sw.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw.any.js
        \\handle unsettled: fetch/sw-quiet.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw-quiet.any.js
    ;
    // (The integrator's ruling 2026-11-28 3:10 AM ET, (a): with no leak it is
    // reported, not failing - workers/ and xhr/ files read so in 1 run of 3.)
    report.log = .{};
    report.handle = try handleCoverageListed(arena, &.{new_log}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 0), report.handle.?.new_unsettled);
    try testing.expectEqual(@as(usize, 1), report.handle.?.unsettled_quiet);
    try testing.expect(report.gatePassed());
    w = .fixed(&buf);
    try report.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: 1 unlisted file(s) read unsettled with no handle leak - reported, not failing (first: dom/clean.html)") != null);
    // With a leak, the unlisted unsettled file is NEW and fails the gate.
    const new_leak_log = new_log ++ "\nwarning(handle): handle leak: dom/clean.html: live_object_globals +1 (max 0), wrapper_cache_entries 0 (max 0), global_handle_bytes 0, node_wrappers 0";
    report.handle = try handleCoverageListed(arena, &.{new_leak_log}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 1), report.handle.?.new_unsettled);
    try testing.expect(!report.gatePassed());
    w = .fixed(&buf);
    try report.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: 1 NEW unsettled file(s) with a handle leak, not in tools/wpt_handle_unsettled.txt (first: dom/clean.html)") != null);

    // A listed file that settled: STALE, the list only goes down.
    const stale_log =
        \\handle unsettled: fetch/sw.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw.any.js
        \\handle checked: fetch/sw-quiet.any.js
        \\handle checked: dom/clean.html
    ;
    report.handle = try handleCoverageListed(arena, &.{stale_log}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 1), report.handle.?.stale_unsettled);
    try testing.expect(!report.gatePassed());
    w = .fixed(&buf);
    try report.write(&w);
    try testing.expect(std.mem.indexOf(u8, w.buffered(), "handle gate: 1 STALE entry(ies) of tools/wpt_handle_unsettled.txt settled - remove them (first: fetch/sw-quiet.any.js)") != null);

    // A settled file's leak is a leak, listed or not.
    const leak_log =
        \\handle unsettled: fetch/sw.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw.any.js
        \\handle unsettled: fetch/sw-quiet.any.js: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive
        \\handle checked: fetch/sw-quiet.any.js
        \\warning(handle): handle leak: dom/clean.html: live_object_globals +1 (max 0), wrapper_cache_entries 0 (max 0), global_handle_bytes 0, node_wrappers 0
    ;
    var lf: LogFindings = .{};
    lf.scan(leak_log);
    report.log = lf;
    report.handle = try handleCoverageListed(arena, &.{leak_log}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 1), report.handle.?.blocking_leaks);
    try testing.expect(!report.gatePassed());
}

test "the checked-in unsettled list parses, each path once, and only goes down" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const text = try host.cwd().readFileAlloc(host.io(), default_unsettled_path, arena, .limited(4 << 20));
    const allowed = try parseUnsettledList(arena, text);
    try testing.expect(allowed.count() <= max_unsettled_entries);
    try testing.expectError(error.InvalidUnsettledList, parseUnsettledList(arena, "a.html\na.html\n"));
    try testing.expectError(error.InvalidUnsettledList, parseUnsettledList(arena, "a.html\tsometimes\tx\n"));
    try testing.expectError(error.InvalidUnsettledList, parseUnsettledList(arena, "a.html\tintermittent\t\n"));
}

test "an intermittent unsettled entry is neither NEW when it reads unsettled nor STALE when it settles" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const records = [_]journal.Record{.{ .index = 0, .path = "workers/w.html", .status = .ok }};
    const run = try fixtureRun(arena, &records, "");
    const allowed = try parseUnsettledList(arena, "workers/w.html\tintermittent\tunsettled in 1 of 2 FULL runs\n");
    var no_baseline = handle_gate.Baseline.empty(testing.allocator);
    defer no_baseline.deinit();
    try testing.expect(allowed.get("workers/w.html").?);
    const settled = try handleCoverageListed(arena, &.{"handle checked: workers/w.html"}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 0), settled.stale_unsettled);
    const unsettled = try handleCoverageListed(arena, &.{"handle unsettled: workers/w.html: after 80 rounds the event loop has no pending work and 1 agent(s) beyond the clean reading are alive\nhandle checked: workers/w.html"}, &run, &allowed, &no_baseline);
    try testing.expectEqual(@as(usize, 0), unsettled.new_unsettled);
    try testing.expectEqual(@as(usize, 1), unsettled.unsettled);
}

test "the compare re-applies the tree's baseline to each leak line's printed deltas: under the caps is no leak, over them is" {
    // The integrator's ruling 2026-11-28 3:10 AM ET, (c): the baseline file is
    // the single source of truth, whatever caps the runner applied.
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const records = [_]journal.Record{
        .{ .index = 0, .path = "html/bfcache/held.html", .status = .ok },
        .{ .index = 1, .path = "dom/new.html", .status = .ok },
    };
    const run = try fixtureRun(arena, &records, "");
    var diag: handle_gate.ParseDiagnostic = .{};
    var baseline = try handle_gate.Baseline.parse(testing.allocator, "html/bfcache/held.html\t2\t170\thleak-bfcache1\ta page the back/forward cache keeps\n", &diag);
    defer baseline.deinit();
    const none: std.StringHashMapUnmanaged(bool) = .empty;
    // The runner (with an older baseline) printed the held page at 86 wrapper
    // entries: within the tree's caps (2 / 170), so no leak; dom/new.html's +1 is.
    const log =
        \\warning(handle): handle leak: html/bfcache/held.html: live_object_globals +2 (max 2), wrapper_cache_entries +86 (max 81), global_handle_bytes +3552, node_wrappers +16
        \\warning(handle): handle leak: dom/new.html: live_object_globals +1 (max 0), wrapper_cache_entries 0 (max 0), global_handle_bytes 0, node_wrappers 0
    ;
    const h = try handleCoverageListed(arena, &.{log}, &run, &none, &baseline);
    try testing.expectEqual(@as(usize, 2), h.checked);
    try testing.expectEqual(@as(usize, 1), h.blocking_leaks);
    try testing.expectEqualStrings("dom/new.html", h.first_blocking_leak.?);
    // A holder that grows past its object-global cap is a leak again.
    const grown = try handleCoverageListed(arena, &.{"warning(handle): handle leak: html/bfcache/held.html: live_object_globals +3 (max 2), wrapper_cache_entries +86 (max 170), global_handle_bytes 0, node_wrappers 0"}, &run, &none, &baseline);
    try testing.expectEqual(@as(usize, 1), grown.blocking_leaks);
}
