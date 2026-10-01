//! WPT runner command-line options.
//!
//! Split out of main.zig so it can be tested. main.zig links V8 and libuv and
//! is only ever built as an executable, which means test blocks inside it are
//! never compiled, let alone run. Argument parsing decides what a run covers
//! and where it writes - it is exactly the part that should not depend on a
//! working browser to verify.

const std = @import("std");
const config = @import("config.zig");
const stall_watchdog = @import("stall_watchdog.zig");

/// Command-line options
pub const Options = struct {
    /// Directory filters (empty = all in-scope categories)
    filters: std.ArrayList([]const u8),
    /// Allocator for managing memory
    allocator: std.mem.Allocator,
    /// Output directory for results
    output_dir: []const u8 = "wpt-results",
    /// Verbose output (default: true, use --quiet to disable)
    verbose: bool = true,
    /// Number of parallel runners: 0 means "one per core", null means the flag
    /// was never given. The distinction matters because asking for parallelism
    /// at all is what routes a run through the supervisor, and `--parallel=0`
    /// is a real request for it.
    parallel: ?u32 = null,
    /// WPT root directory
    wpt_root: []const u8 = "tests/wpt",
    /// Specific test files to run (overrides directory filters)
    specific_files: std.ArrayList([]const u8),
    /// Maximum number of test files to run (0 = no limit)
    limit: usize = 0,
    /// Glob pattern to filter test names (e.g., "*constructor*")
    pattern: ?[]const u8 = null,
    /// Discover tests by walking the filesystem instead of reading
    /// MANIFEST.json. Kept as an escape hatch for a checkout whose manifest is
    /// stale or absent; it cannot report a denominator.
    legacy_scan: bool = false,
    /// Select every testharness source in MANIFEST.json (`--full-corpus`),
    /// not just the in-scope ones: the allowlist and the exclusion patterns in
    /// config.zig do not apply, directory arguments still narrow. This is the
    /// run a wpt.fyi upload is made from; the 0.1 gate is not.
    full_corpus: bool = false,
    /// Report what would run and exit without executing anything.
    discover_only: bool = false,
    /// Write the discovered source list, one path per line, to this file.
    worklist_out: ?[]const u8 = null,
    /// Run the paths in this worklist file instead of discovering tests.
    from_file: ?[]const u8 = null,
    /// Index into the worklist to start at. Journal indices are absolute
    /// worklist positions, so this is what makes a resumed child line up with
    /// the records an earlier child already wrote.
    start_index: usize = 0,
    /// Append a JSONL record per completed test file to this path.
    journal_path: ?[]const u8 = null,
    /// Supervise child runs: discover, then respawn this binary past each
    /// crash until the worklist is exhausted.
    supervise: bool = false,
    /// Compare the finished run against the baseline at this path. A regression
    /// makes the process exit nonzero, which is the whole point: it is what
    /// lets CI go red.
    baseline_path: ?[]const u8 = null,
    /// Rewrite the file named by `baseline_path` from this run instead of
    /// comparing against it. One path flag rather than two so a run cannot
    /// compare against one file and write to another.
    update_baseline: bool = false,
    /// How long a supervised child may add nothing to the journal before the
    /// supervisor kills it, in milliseconds. 0 disables the watchdog.
    ///
    /// The per-file ceiling does not bound the navigation, the parse, or the
    /// scripts the parser runs, and `fetch()` is synchronous, so a polling page
    /// can hold the process indefinitely. See stall_watchdog.zig.
    stall_limit_ms: u64 = stall_watchdog.default_stall_limit_ms,

    pub fn init(allocator: std.mem.Allocator) Options {
        return Options{
            .filters = .empty,
            .specific_files = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Options) void {
        for (self.filters.items) |f| {
            self.allocator.free(f);
        }
        self.filters.deinit(self.allocator);
        for (self.specific_files.items) |f| {
            self.allocator.free(f);
        }
        self.specific_files.deinit(self.allocator);
    }

    /// True when this process was spawned by a supervisor.
    pub fn isChild(self: Options) bool {
        return self.from_file != null;
    }

    /// True when this run should discover tests and then drive child processes
    /// rather than run the tests itself.
    ///
    /// `--parallel` implies it because parallelism is implemented by sharding
    /// the worklist across child processes; there is no in-process path to it.
    /// A child never sees either flag, so this cannot recurse.
    pub fn wantsSupervisor(self: Options) bool {
        return self.supervise or self.parallel != null;
    }

    /// True when this process runs tests with nobody watching it - neither a
    /// supervisor's child nor a supervisor - and so must bound itself
    /// (stall_watchdog.SelfWatchdog) with the limit a supervisor would use.
    /// `--stall-limit-ms=0` turns it off with the supervisor's.
    pub fn wantsSelfDeadline(self: Options) bool {
        return !self.isChild() and !self.wantsSupervisor() and self.stall_limit_ms != 0;
    }

    /// The runner count to hand `selection.resolveShardCount`, where 0 means
    /// "one per core". A plain `--supervise` asks for exactly one, which is the
    /// serial behaviour it has always had.
    pub fn shardRequest(self: Options) usize {
        return self.parallel orelse 1;
    }

    /// Where this run keeps its journal, or null if it keeps none.
    ///
    /// A journal is normally opt-in, but a baseline has nothing to compare
    /// against without one, so asking for a baseline implies a journal next to
    /// the report. Caller owns the returned path.
    pub fn journalPath(self: Options, allocator: std.mem.Allocator) !?[]const u8 {
        if (self.journal_path) |p| return try allocator.dupe(u8, p);
        if (self.baseline_path == null) return null;
        return try std.fs.path.join(allocator, &.{ self.output_dir, "journal.jsonl" });
    }

    /// True when this process joins a journal already in progress rather than
    /// starting one.
    ///
    /// Only a supervised child does. A fresh run that appended would stack this
    /// run's records on top of the last one's, and a comparison that read both
    /// would report the worse of the two as today's result.
    pub fn appendsToJournal(self: Options) bool {
        return self.isChild();
    }

    /// Where this process writes its wptreport.
    ///
    /// A supervised run is several processes, each covering a slice of the
    /// worklist; naming the reports after the slice keeps a later child from
    /// silently overwriting an earlier one's results.
    ///
    /// A shard's worklist starts at index 0 like every other shard's, so a
    /// journalled child also names its report after its journal
    /// (`wptreport-journal.shard1-0.json`): with the start index alone, the
    /// shards of one `--parallel` run overwrote a single wptreport-0.json.
    pub fn reportPath(self: Options, allocator: std.mem.Allocator) ![]const u8 {
        if (self.isChild()) {
            const name = if (self.journal_path) |j|
                try std.fmt.allocPrint(allocator, "wptreport-{s}-{d}.json", .{ journalStem(j), self.start_index })
            else
                try std.fmt.allocPrint(allocator, "wptreport-{d}.json", .{self.start_index});
            defer allocator.free(name);
            return std.fs.path.join(allocator, &.{ self.output_dir, name });
        }
        return std.fs.path.join(allocator, &.{ self.output_dir, "wptreport.json" });
    }

    /// Where a journalled run streams its wptreport results, or null if it
    /// keeps no journal. Caller owns the returned path.
    ///
    /// The report proper is written when a process finishes, so a child that
    /// crashes or is killed by the stall watchdog loses every result it held.
    /// The stream gets each file's results as JSON lines when the file is
    /// done, beside the journal and appended across restarts as the journal
    /// is: `journal.shard1.jsonl` streams to `journal.shard1.wptreport.jsonl`.
    pub fn resultsStreamPath(self: Options, allocator: std.mem.Allocator) !?[]const u8 {
        const journal = (try self.journalPath(allocator)) orelse return null;
        defer allocator.free(journal);
        const dir = std.fs.path.dirname(journal);
        const name = try std.fmt.allocPrint(allocator, "{s}.wptreport.jsonl", .{journalStem(journal)});
        defer allocator.free(name);
        if (dir) |d| return try std.fs.path.join(allocator, &.{ d, name });
        return try allocator.dupe(u8, name);
    }

    /// Check if a test path matches the filters
    pub fn matchesFilter(self: Options, test_path: []const u8) bool {
        // If specific files are specified, only those match
        if (self.specific_files.items.len > 0) {
            for (self.specific_files.items) |file| {
                if (std.mem.eql(u8, test_path, file)) {
                    return true;
                }
            }
            return false;
        }

        // If no filters, everything matches
        if (self.filters.items.len == 0) {
            return true;
        }

        // Check if path starts with any filter
        for (self.filters.items) |filter| {
            const clean_filter = std.mem.trimEnd(u8, filter, "/");
            if (std.mem.startsWith(u8, test_path, clean_filter)) {
                // Make sure it's a proper prefix (followed by / or end of string)
                if (test_path.len == clean_filter.len) return true;
                if (test_path.len > clean_filter.len and test_path[clean_filter.len] == '/') return true;
            }
        }
        return false;
    }
};

/// A journal's file name without its directory or `.jsonl` extension.
fn journalStem(journal_path: []const u8) []const u8 {
    const base = std.fs.path.basename(journal_path);
    return if (std.mem.endsWith(u8, base, ".jsonl")) base[0 .. base.len - ".jsonl".len] else base;
}

/// Check if a path looks like a test file
pub fn isTestFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".any.js") or
        std.mem.endsWith(u8, path, ".window.js") or
        std.mem.endsWith(u8, path, ".worker.js") or
        std.mem.endsWith(u8, path, ".html") or
        std.mem.endsWith(u8, path, ".htm") or
        std.mem.endsWith(u8, path, ".js");
}

/// Parse command-line arguments
/// What `parseArgsDiagnosed` could not parse.
pub const Diagnostic = struct {
    /// The first argument that looked like an option and was not one.
    unknown_option: []const u8 = "",
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var diag: Diagnostic = .{};
    return parseArgsDiagnosed(allocator, args, &diag);
}

/// `parseArgs`, saying which argument it rejected. An argument that starts
/// with '-' and is no option here is `error.UnknownOption`, never ignored: an
/// ignored flag leaves a run that does something other than what was asked,
/// and the default run is the whole in-scope corpus.
pub fn parseArgsDiagnosed(allocator: std.mem.Allocator, args: []const []const u8, diag: *Diagnostic) !Options {
    var options = Options.init(allocator);
    errdefer options.deinit();

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.startsWith(u8, arg, "--output=")) {
            options.output_dir = arg["--output=".len..];
        } else if (std.mem.eql(u8, arg, "--quiet") or std.mem.eql(u8, arg, "-q")) {
            // Quiet mode: minimal output (progress bar only)
            options.verbose = false;
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            options.verbose = true;
        } else if (std.mem.startsWith(u8, arg, "--parallel=")) {
            const value = arg["--parallel=".len..];
            options.parallel = std.fmt.parseInt(u32, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--wpt-root=")) {
            options.wpt_root = arg["--wpt-root=".len..];
        } else if (std.mem.startsWith(u8, arg, "--limit=")) {
            const value = arg["--limit=".len..];
            options.limit = std.fmt.parseInt(usize, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--pattern=")) {
            options.pattern = arg["--pattern=".len..];
        } else if (std.mem.eql(u8, arg, "--legacy-scan")) {
            options.legacy_scan = true;
        } else if (std.mem.eql(u8, arg, "--full-corpus")) {
            options.full_corpus = true;
        } else if (std.mem.eql(u8, arg, "--discover-only")) {
            options.discover_only = true;
        } else if (std.mem.startsWith(u8, arg, "--worklist-out=")) {
            options.worklist_out = arg["--worklist-out=".len..];
        } else if (std.mem.startsWith(u8, arg, "--from-file=")) {
            options.from_file = arg["--from-file=".len..];
        } else if (std.mem.startsWith(u8, arg, "--start-index=")) {
            const value = arg["--start-index=".len..];
            options.start_index = std.fmt.parseInt(usize, value, 10) catch 0;
        } else if (std.mem.startsWith(u8, arg, "--journal=")) {
            options.journal_path = arg["--journal=".len..];
        } else if (std.mem.eql(u8, arg, "--supervise")) {
            options.supervise = true;
        } else if (std.mem.startsWith(u8, arg, "--baseline=")) {
            options.baseline_path = arg["--baseline=".len..];
        } else if (std.mem.eql(u8, arg, "--update-baseline")) {
            options.update_baseline = true;
        } else if (std.mem.startsWith(u8, arg, "--stall-limit-ms=")) {
            const value = arg["--stall-limit-ms=".len..];
            options.stall_limit_ms = std.fmt.parseInt(u64, value, 10) catch
                stall_watchdog.default_stall_limit_ms;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            diag.unknown_option = arg;
            return error.UnknownOption;
        } else {
            // Directory or file filter
            // Check if it's a specific file (has extension) or a directory
            if (isTestFile(arg)) {
                try options.specific_files.append(allocator, try allocator.dupe(u8, arg));
            } else {
                try options.filters.append(allocator, try allocator.dupe(u8, arg));
            }
        }
    }

    return options;
}

// ============================================================================
// Tests
// ============================================================================

test "parseArgs defaults" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var options = try parseArgs(allocator, &.{});
    defer options.deinit();

    try testing.expectEqualStrings("wpt-results", options.output_dir);
    try testing.expectEqualStrings("tests/wpt", options.wpt_root);
    try testing.expect(options.verbose);
    try testing.expectEqual(@as(usize, 0), options.filters.items.len);
    try testing.expectEqual(@as(usize, 0), options.limit);
    try testing.expect(!options.supervise);
    try testing.expect(!options.isChild());
}

test "parseArgs rejects an option it does not know, and names it" {
    // An unknown flag used to be ignored, so a typo ran the whole in-scope
    // corpus serially - 9,278 runs, outside every runner budget - instead of
    // what was asked (2026-10-01: `--allocator-self-check` on a runner built
    // before the flag existed).
    const testing = std.testing;
    var diag: Diagnostic = .{};
    try testing.expectError(error.UnknownOption, parseArgsDiagnosed(testing.allocator, &.{ "dom/", "--paralel=3" }, &diag));
    try testing.expectEqualStrings("--paralel=3", diag.unknown_option);
    try testing.expectError(error.UnknownOption, parseArgs(testing.allocator, &.{"-x"}));
}

test "parseArgs: --verbose, which zig build wpt passes, is an option" {
    const testing = std.testing;
    var options = try parseArgs(testing.allocator, &.{ "--quiet", "--verbose" });
    defer options.deinit();
    try testing.expect(options.verbose);
}

test "parseArgs collects directory filters and scalar options" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{
        "url/",
        "dom/",
        "--quiet",
        "--limit=42",
        "--parallel=4",
        "--pattern=*constructor*",
        "--output=/tmp/out",
        "--wpt-root=/tmp/wpt",
    };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(usize, 2), options.filters.items.len);
    try testing.expectEqualStrings("url/", options.filters.items[0]);
    try testing.expectEqualStrings("dom/", options.filters.items[1]);
    try testing.expect(!options.verbose);
    try testing.expectEqual(@as(usize, 42), options.limit);
    try testing.expectEqual(@as(?u32, 4), options.parallel);
    try testing.expectEqualStrings("*constructor*", options.pattern.?);
    try testing.expectEqualStrings("/tmp/out", options.output_dir);
    try testing.expectEqualStrings("/tmp/wpt", options.wpt_root);
}

test "parseArgs routes a path with a test extension to specific_files" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "url/url-constructor.any.js", "dom/" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(usize, 1), options.specific_files.items.len);
    try testing.expectEqualStrings("url/url-constructor.any.js", options.specific_files.items[0]);
    try testing.expectEqual(@as(usize, 1), options.filters.items.len);
    try testing.expectEqualStrings("dom/", options.filters.items[0]);
}

test "--full-corpus is off by default and parsed when given" {
    const allocator = std.testing.allocator;

    var plain = try parseArgs(allocator, &.{"dom/"});
    defer plain.deinit();
    try std.testing.expect(!plain.full_corpus);

    var full = try parseArgs(allocator, &.{ "--full-corpus", "--discover-only", "--worklist-out=full.txt", "css/" });
    defer full.deinit();
    try std.testing.expect(full.full_corpus);
    try std.testing.expect(full.discover_only);
    try std.testing.expectEqualStrings("full.txt", full.worklist_out.?);
    // A directory argument still narrows a full-corpus run.
    try std.testing.expectEqual(@as(usize, 1), full.filters.items.len);
}

test "a journalled run streams its results beside the journal" {
    const allocator = std.testing.allocator;

    var none = try parseArgs(allocator, &.{"dom/"});
    defer none.deinit();
    try std.testing.expectEqual(@as(?[]const u8, null), try none.resultsStreamPath(allocator));

    var child = try parseArgs(allocator, &.{ "--from-file=out/worklist.shard1.txt", "--journal=out/journal.shard1.jsonl", "--output=out" });
    defer child.deinit();
    const path = (try child.resultsStreamPath(allocator)).?;
    defer allocator.free(path);
    try std.testing.expectEqualStrings("out/journal.shard1.wptreport.jsonl", path);
}

test "shards of one run write differently named reports" {
    const allocator = std.testing.allocator;

    // Every shard's worklist starts at 0, so naming a report after the start
    // index alone made three shards overwrite one wptreport-0.json.
    var a = try parseArgs(allocator, &.{ "--from-file=o/worklist.shard0.txt", "--journal=o/journal.shard0.jsonl", "--output=o" });
    defer a.deinit();
    var b = try parseArgs(allocator, &.{ "--from-file=o/worklist.shard1.txt", "--journal=o/journal.shard1.jsonl", "--output=o" });
    defer b.deinit();
    const pa = try a.reportPath(allocator);
    defer allocator.free(pa);
    const pb = try b.reportPath(allocator);
    defer allocator.free(pb);
    try std.testing.expect(!std.mem.eql(u8, pa, pb));
    try std.testing.expectEqualStrings("o/wptreport-journal.shard0-0.json", pa);
}

test "parseArgs reads supervisor flags" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--supervise", "--output=wpt-results" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expect(options.supervise);
    try testing.expect(!options.isChild());

    const path = try options.reportPath(allocator);
    defer allocator.free(path);
    try testing.expectEqualStrings("wpt-results/wptreport.json", path);
}

test "parseArgs reads child flags" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{
        "--from-file=wpt-results/worklist.txt",
        "--start-index=1234",
        "--journal=wpt-results/journal.jsonl",
        "--output=wpt-results",
    };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqualStrings("wpt-results/worklist.txt", options.from_file.?);
    try testing.expectEqual(@as(usize, 1234), options.start_index);
    try testing.expectEqualStrings("wpt-results/journal.jsonl", options.journal_path.?);
    try testing.expect(options.isChild());
}

test "each child of a supervised run writes its own report" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Two children of the same run must not land on the same filename, or the
    // later one silently discards the earlier one's results.
    const first = [_][]const u8{ "--from-file=w.txt", "--start-index=0", "--output=out" };
    var a = try parseArgs(allocator, &first);
    defer a.deinit();

    const second = [_][]const u8{ "--from-file=w.txt", "--start-index=17", "--output=out" };
    var b = try parseArgs(allocator, &second);
    defer b.deinit();

    const a_path = try a.reportPath(allocator);
    defer allocator.free(a_path);
    const b_path = try b.reportPath(allocator);
    defer allocator.free(b_path);

    try testing.expectEqualStrings("out/wptreport-0.json", a_path);
    try testing.expectEqualStrings("out/wptreport-17.json", b_path);
}

test "parseArgs reads baseline flags" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--baseline=tests/wpt_expectations.jsonl", "--update-baseline" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    try testing.expectEqualStrings("tests/wpt_expectations.jsonl", options.baseline_path.?);
    try testing.expect(options.update_baseline);
}

test "asking for a baseline implies a journal to compare from" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--baseline=b.jsonl", "--output=out" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    const path = (try options.journalPath(allocator)).?;
    defer allocator.free(path);
    try testing.expectEqualStrings("out/journal.jsonl", path);
}

test "an explicit journal path beats the one a baseline implies" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = [_][]const u8{ "--baseline=b.jsonl", "--output=out", "--journal=/tmp/j.jsonl" };
    var options = try parseArgs(allocator, &args);
    defer options.deinit();

    const path = (try options.journalPath(allocator)).?;
    defer allocator.free(path);
    try testing.expectEqualStrings("/tmp/j.jsonl", path);
}

test "a run with neither flag keeps no journal" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var options = try parseArgs(allocator, &.{"url/"});
    defer options.deinit();

    try testing.expect((try options.journalPath(allocator)) == null);
}

test "only a supervised child appends to an existing journal" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // A fresh run that appended would stack today's records on yesterday's, and
    // fromLog keeps the worse of a duplicated path - so a passing run would
    // inherit last week's crash and fail the comparison.
    var fresh = try parseArgs(allocator, &.{"--journal=j.jsonl"});
    defer fresh.deinit();
    try testing.expect(!fresh.appendsToJournal());

    var child = try parseArgs(allocator, &.{ "--journal=j.jsonl", "--from-file=w.txt" });
    defer child.deinit();
    try testing.expect(child.appendsToJournal());
}

test "parseArgs never reads an unrecognised flag as a filter" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // A leading dash means "an option", so an unknown one must not be mistaken
    // for a directory filter and silently narrow the run to nothing - nor be
    // ignored, which widens it to everything: it is an error.
    const args = [_][]const u8{"--not-a-real-flag"};
    try testing.expectError(error.UnknownOption, parseArgs(allocator, &args));
}

test "isTestFile" {
    const testing = std.testing;

    try testing.expect(isTestFile("url/url-constructor.any.js"));
    try testing.expect(isTestFile("dom/event.window.js"));
    try testing.expect(isTestFile("streams/byte.worker.js"));
    try testing.expect(isTestFile("html/test.html"));
    try testing.expect(!isTestFile("url"));
    try testing.expect(!isTestFile("dom/nodes"));
}

test "matchesFilter" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var options = Options.init(allocator);
    defer options.deinit();

    try options.filters.append(allocator, try allocator.dupe(u8, "url/"));

    try testing.expect(options.matchesFilter("url/url-constructor.any.js"));
    try testing.expect(!options.matchesFilter("dom/events/Event.html"));

    // A filter names a directory, so it must match a whole path segment.
    // "url" must not pull in "urlpattern".
    try testing.expect(!options.matchesFilter("urlpattern/urlpattern.any.js"));
}

test "matchesFilter with specific files overrides directory filters" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var options = Options.init(allocator);
    defer options.deinit();

    try options.filters.append(allocator, try allocator.dupe(u8, "url/"));
    try options.specific_files.append(allocator, try allocator.dupe(u8, "dom/events/Event.html"));

    try testing.expect(options.matchesFilter("dom/events/Event.html"));
    try testing.expect(!options.matchesFilter("url/url-constructor.any.js"));
}

test "config is reachable from options" {
    // options.zig exists to be testable without V8; keep the config import it
    // shares with main.zig honest.
    try std.testing.expectEqual(config.FileType.any_js, config.FileType.fromPath("url/a.any.js"));
}

test "--parallel implies the supervisor" {
    const testing = std.testing;
    const args = [_][]const u8{ "wpt-runner", "--parallel=4" };

    var options = try parseArgs(testing.allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(?u32, 4), options.parallel);
    try testing.expect(options.wantsSupervisor());
}

test "--parallel=0 means auto, which is still a parallel run" {
    const testing = std.testing;
    const args = [_][]const u8{ "wpt-runner", "--parallel=0" };

    var options = try parseArgs(testing.allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(?u32, 0), options.parallel);
    try testing.expect(options.wantsSupervisor());
}

test "no --parallel leaves the run serial" {
    const testing = std.testing;
    const args = [_][]const u8{"wpt-runner"};

    var options = try parseArgs(testing.allocator, &args);
    defer options.deinit();

    try testing.expectEqual(@as(?u32, null), options.parallel);
    try testing.expect(!options.wantsSupervisor());
}

test "--supervise alone still supervises" {
    const testing = std.testing;
    const args = [_][]const u8{ "wpt-runner", "--supervise" };

    var options = try parseArgs(testing.allocator, &args);
    defer options.deinit();

    try testing.expect(options.wantsSupervisor());
}

test "shardRequest is zero for a serial run" {
    const testing = std.testing;

    var serial = Options.init(testing.allocator);
    defer serial.deinit();
    serial.supervise = true;
    try testing.expectEqual(@as(usize, 1), serial.shardRequest());

    var auto = Options.init(testing.allocator);
    defer auto.deinit();
    auto.parallel = 0;
    try testing.expectEqual(@as(usize, 0), auto.shardRequest());
}

test "the stall watchdog is on by default and can be turned off" {
    const testing = std.testing;

    // On by default: a sweep that has to be asked for the backstop does not
    // have one the first time it needs it.
    var plain = try parseArgs(testing.allocator, &.{"wpt-runner"});
    defer plain.deinit();
    try testing.expectEqual(stall_watchdog.default_stall_limit_ms, plain.stall_limit_ms);

    var tightened = try parseArgs(testing.allocator, &.{ "wpt-runner", "--stall-limit-ms=30000" });
    defer tightened.deinit();
    try testing.expectEqual(@as(u64, 30_000), tightened.stall_limit_ms);

    // Zero is a real value, not a parse failure: it means "never kill", which
    // is what a debugging session attached to a hung child wants.
    var off = try parseArgs(testing.allocator, &.{ "wpt-runner", "--stall-limit-ms=0" });
    defer off.deinit();
    try testing.expectEqual(@as(u64, 0), off.stall_limit_ms);

    // Garbage falls back to the default rather than to zero, so a typo cannot
    // silently disable the backstop.
    var typo = try parseArgs(testing.allocator, &.{ "wpt-runner", "--stall-limit-ms=soon" });
    defer typo.deinit();
    try testing.expectEqual(stall_watchdog.default_stall_limit_ms, typo.stall_limit_ms);
}

test "only a run with neither a supervisor nor a parent bounds itself" {
    const testing = std.testing;
    // `wpt_runner <path>` runs in this process with nobody watching it: it
    // must carry its own deadline (stall_watchdog.SelfWatchdog).
    var single = try parseArgs(testing.allocator, &.{ "wpt-runner", "dom/nodes/Node-cloneNode.html" });
    defer single.deinit();
    try testing.expect(single.wantsSelfDeadline());

    // A supervised child is watched by its parent's journal watchdog; a second
    // deadline inside it would race the parent's and record the hang twice.
    var child = try parseArgs(testing.allocator, &.{ "wpt-runner", "--from-file=w.txt", "--journal=j.jsonl" });
    defer child.deinit();
    try testing.expect(!child.wantsSelfDeadline());

    // A supervisor runs no tests itself.
    var parent = try parseArgs(testing.allocator, &.{ "wpt-runner", "--parallel=2", "dom/" });
    defer parent.deinit();
    try testing.expect(!parent.wantsSelfDeadline());

    // --stall-limit-ms=0 turns it off, as it does the supervisor's.
    var off = try parseArgs(testing.allocator, &.{ "wpt-runner", "--stall-limit-ms=0", "dom/x.html" });
    defer off.deinit();
    try testing.expect(!off.wantsSelfDeadline());
}
