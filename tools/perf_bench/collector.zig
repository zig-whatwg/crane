//! What one launch of one engine on one page produced: the page's marks,
//! each with the reading of the engine's process set taken when it arrived,
//! turned into journal records. Engine-free, so its rules are tested with
//! made-up marks and readings (the runner feeds it real ones).
//!
//! The harness's marks (tests/perf/harness.js):
//!   loaded  the page's load event; `load_ms` from its time origin
//!   begin   a timed workload's samples start
//!   end     ... and end: `ops` per sample, `wall_ms` per sample
//!   step    a chain's document loaded: `step`, `load_ms`
//!   error   a workload threw (`unsupported`: it needs what the engine lacks)
//!   log     a line for the run's log
//!   done    the page has finished
//! A timed record's CPU and instructions are the process set's between its
//! begin and end readings; its memory, the footprints at both and the peak
//! the 50 ms sampler saw between them.

const std = @import("std");
const Allocator = std.mem.Allocator;
const journal = @import("journal.zig");
const suite = @import("suite.zig");
const proc = @import("proc.zig");

pub const Mark = struct {
    token: []const u8 = "",
    type: []const u8,
    workload: []const u8 = "",
    ops: u64 = 0,
    wall_ms: []const f64 = &.{},
    load_ms: ?f64 = null,
    step: u32 = 0,
    message: []const u8 = "",
    unsupported: bool = false,
};

pub fn parseMark(arena: Allocator, body: []const u8) !Mark {
    return std.json.parseFromSliceLeaky(Mark, arena, body, .{ .ignore_unknown_fields = true });
}

/// The fields every record of a launch shares.
pub const Base = struct {
    round: u32,
    time: []const u8,
    host: journal.Host,
    engine: journal.Engine,
    page: []const u8,
    run: u32,
};

/// How a launch ended, for the workloads it left without a record.
pub const Ending = union(enum) {
    /// The page said done.
    done,
    /// The time ran out.
    timeout: u32,
    /// The engine's process ended first (its exit, as text).
    exited: []const u8,
    /// The engine could not be driven to the page (the protocol's error).
    driver: []const u8,
    /// The runner was told to stop.
    stopped,
};

const Pending = struct {
    workload: []const u8,
    begin: proc.Reading,
    footprint_start: u64,
    peak: u64,
};

pub const Collector = struct {
    arena: Allocator,
    base: Base,
    page: suite.Page,
    records: std.ArrayList(journal.Record) = .empty,
    log: std.ArrayList(u8) = .empty,
    /// Launch to the page's load mark (the first, for a chain).
    launch_ms: ?f64 = null,
    loaded_reading: ?proc.Reading = null,
    done: bool = false,
    /// How many load marks came (an instances row waits for each).
    loads: usize = 0,
    pending: ?*Pending = null,
    /// The most the sampler saw over the whole launch.
    peak_run: u64 = 0,
    chain_wall: std.ArrayList(f64) = .empty,
    chain_series: std.ArrayList(u64) = .empty,
    /// Workloads the page reported an error for: name -> (message, unsupported).
    failed: std.StringArrayHashMapUnmanaged(Failure) = .empty,

    const Failure = struct { message: []const u8, unsupported: bool };

    fn record(self: *Collector, workload: []const u8, kind: journal.Kind) journal.Record {
        return .{
            .format = journal.format_name,
            .round = self.base.round,
            .time = self.base.time,
            .host = self.base.host,
            .engine = self.base.engine,
            .page = self.base.page,
            .workload = workload,
            .kind = kind,
            .run = self.base.run,
            .status = .ok,
            .launch_ms = self.launch_ms,
        };
    }

    /// A footprint the sampler read.
    pub fn notePeak(self: *Collector, footprint: u64) void {
        if (footprint > self.peak_run) self.peak_run = footprint;
        if (self.pending) |p| if (footprint > p.peak) {
            p.peak = footprint;
        };
    }

    fn listed(self: *const Collector, workload: []const u8) bool {
        for (self.page.workloads) |w| if (std.mem.eql(u8, w, workload)) return true;
        return false;
    }

    fn hasRecord(self: *const Collector, workload: []const u8) bool {
        for (self.records.items) |r| if (std.mem.eql(u8, r.workload, workload)) return true;
        return false;
    }

    /// One mark, `at_ms` after launch, with the reading taken when it came.
    pub fn onMark(self: *Collector, mark: Mark, at_ms: f64, reading: *const proc.Reading) !void {
        const footprint = reading.footprint();
        self.notePeak(footprint);
        const t = mark.type;
        if (std.mem.eql(u8, t, "loaded")) {
            self.loads += 1;
            if (self.launch_ms == null) {
                self.launch_ms = at_ms;
                self.loaded_reading = reading.*;
            }
        } else if (std.mem.eql(u8, t, "begin")) {
            if (!self.listed(mark.workload)) return self.note("begin of an unlisted workload: {s}", .{mark.workload});
            const p = try self.arena.create(Pending);
            p.* = .{ .workload = try self.arena.dupe(u8, mark.workload), .begin = reading.*, .footprint_start = footprint, .peak = footprint };
            self.pending = p;
        } else if (std.mem.eql(u8, t, "end")) {
            const p = self.pending orelse return self.note("end without begin: {s}", .{mark.workload});
            if (!std.mem.eql(u8, p.workload, mark.workload)) return self.note("end of {s} while {s} ran", .{ mark.workload, p.workload });
            self.pending = null;
            const delta = reading.since(&p.begin);
            var r = self.record(p.workload, .timed);
            r.ops = mark.ops;
            r.wall_ms = try self.arena.dupe(f64, mark.wall_ms);
            r.cpu_ms = delta.cpuMs();
            r.instructions = if (delta.instructions > 0) delta.instructions else null;
            r.memory = .{
                .footprint_start = p.footprint_start,
                .footprint_end = footprint,
                .footprint_peak = @max(p.peak, @max(footprint, p.footprint_start)),
                .resident_end = reading.resident(),
                .processes = @intCast(reading.count),
            };
            if (r.wall_ms.len == 0 or r.ops == 0) {
                r.status = .@"error";
                r.message = "the end mark carried no samples";
            }
            try self.records.append(self.arena, r);
        } else if (std.mem.eql(u8, t, "step")) {
            if (self.launch_ms == null) self.launch_ms = at_ms;
            try self.chain_wall.append(self.arena, mark.load_ms orelse 0);
            try self.chain_series.append(self.arena, footprint);
        } else if (std.mem.eql(u8, t, "error")) {
            if (self.pending) |p| if (std.mem.eql(u8, p.workload, mark.workload)) {
                self.pending = null;
            };
            try self.failed.put(self.arena, try self.arena.dupe(u8, mark.workload), .{
                .message = try self.arena.dupe(u8, if (mark.message.len > 0) mark.message else "(no message)"),
                .unsupported = mark.unsupported,
            });
        } else if (std.mem.eql(u8, t, "log")) {
            try self.note("page: {s}", .{mark.message});
        } else if (std.mem.eql(u8, t, "settled")) {
            // The last record of this workload: its steady footprint.
            var i = self.records.items.len;
            while (i > 0) {
                i -= 1;
                const r = &self.records.items[i];
                if (!std.mem.eql(u8, r.workload, mark.workload)) continue;
                if (r.memory) |*m| m.footprint_settled = footprint;
                break;
            }
        } else if (std.mem.eql(u8, t, "done")) {
            self.done = true;
            if (self.page.kind == .timed) try self.pageRow(reading);
        } else {
            try self.note("unknown mark type: {s}", .{t});
        }
    }

    fn note(self: *Collector, comptime fmt: []const u8, args: anytype) !void {
        try self.log.print(self.arena, fmt ++ "\n", args);
    }

    /// The idle row (and the startup row beside it): the footprint `settled`
    /// read after the page was left alone.
    pub fn idle(self: *Collector, settled: *const proc.Reading) !void {
        const workload = self.page.workloads[0];
        const loaded = self.loaded_reading orelse return;
        var r = self.record(workload, .idle);
        const end = settled.footprint();
        self.notePeak(end);
        r.memory = .{
            .footprint_start = loaded.footprint(),
            .footprint_end = end,
            .footprint_peak = @max(self.peak_run, @max(end, loaded.footprint())),
            .resident_end = settled.resident(),
            .processes = @intCast(settled.count),
        };
        try self.records.append(self.arena, r);
        try self.startup(workload);
    }

    /// A timed page's own memory row, "page.<file stem>": from its load mark
    /// to its done mark (taken after the settle time, so steady), and the
    /// most the sampler saw over the launch.
    fn pageRow(self: *Collector, done: *const proc.Reading) !void {
        const loaded = self.loaded_reading orelse return;
        const stem = std.fs.path.stem(self.base.page);
        var r = self.record(try std.fmt.allocPrint(self.arena, "page.{s}", .{stem}), .idle);
        const end = done.footprint();
        r.memory = .{
            .footprint_start = loaded.footprint(),
            .footprint_end = end,
            .footprint_peak = @max(self.peak_run, @max(end, loaded.footprint())),
            .resident_end = done.resident(),
            .processes = @intCast(done.count),
            .footprint_settled = end,
        };
        try self.records.append(self.arena, r);
    }

    /// "startup.<name>": launch to the page's load mark, one sample.
    fn startup(self: *Collector, workload: []const u8) !void {
        const ms = self.launch_ms orelse return;
        const dot = std.mem.indexOfScalar(u8, workload, '.').?;
        var r = self.record(try std.fmt.allocPrint(self.arena, "startup.{s}", .{workload[dot + 1 ..]}), .startup);
        r.wall_ms = try self.arena.dupe(f64, &.{ms});
        try self.records.append(self.arena, r);
    }

    /// The instances row: the footprint with 1, 2, ... k running.
    pub fn instances(self: *Collector, series: []const u64, settled: *const proc.Reading) !void {
        var r = self.record(self.page.workloads[0], .instances);
        r.series = try self.arena.dupe(u64, series);
        const end = if (series.len > 0) series[series.len - 1] else 0;
        r.memory = .{
            .footprint_start = if (series.len > 0) series[0] else 0,
            .footprint_end = end,
            .footprint_peak = @max(self.peak_run, end),
            .resident_end = settled.resident(),
            .processes = @intCast(settled.count),
        };
        try self.records.append(self.arena, r);
    }

    /// The records for every listed workload once the launch is over: what
    /// the marks made, and for each workload without one, a record that says
    /// why.
    pub fn finish(self: *Collector, ending: Ending) ![]const journal.Record {
        if (self.page.kind == .chain and self.chain_wall.items.len > 0) {
            const workload = self.page.workloads[0];
            var r = self.record(workload, .chain);
            r.wall_ms = self.chain_wall.items;
            r.series = self.chain_series.items;
            const first = self.chain_series.items[0];
            const last = self.chain_series.items[self.chain_series.items.len - 1];
            r.memory = .{
                .footprint_start = first,
                .footprint_end = last,
                .footprint_peak = @max(self.peak_run, @max(first, last)),
                .resident_end = 0,
                .processes = 0,
            };
            r.ops = 1;
            if (self.chain_wall.items.len < self.page.steps) {
                r.status = statusOf(ending);
                r.message = try self.why(ending, workload);
            }
            try self.records.append(self.arena, r);
        }
        for (self.page.workloads) |w| {
            if (self.hasRecord(w)) continue;
            var r = self.record(w, switch (self.page.kind) {
                .timed => .timed,
                .chain => .chain,
                .idle => .idle,
                .instances => .instances,
            });
            if (self.failed.get(w)) |f| {
                r.status = if (f.unsupported) .unsupported else .@"error";
                r.message = f.message;
            } else {
                r.status = statusOf(ending);
                r.message = try self.why(ending, w);
                if (ending == .done) r.status = .@"error";
            }
            try self.records.append(self.arena, r);
        }
        return self.records.items;
    }

    fn statusOf(ending: Ending) journal.Status {
        return switch (ending) {
            .done => .@"error",
            .timeout, .stopped => .timeout,
            .exited => .crash,
            .driver => .@"error",
        };
    }

    fn why(self: *Collector, ending: Ending, workload: []const u8) ![]const u8 {
        return switch (ending) {
            .done => std.fmt.allocPrint(self.arena, "the page finished without a result for {s}", .{workload}),
            .timeout => |s| std.fmt.allocPrint(self.arena, "no result in {d} s", .{s}),
            .exited => |e| std.fmt.allocPrint(self.arena, "the engine exited before the workload ended: {s}", .{e}),
            .driver => |e| std.fmt.allocPrint(self.arena, "the engine could not be driven to the page: {s}", .{e}),
            .stopped => "the run was stopped (STOP file)",
        };
    }
};

const testing = std.testing;

fn fakeReading(pid: i32, cpu_ns: u64, footprint: u64) proc.Reading {
    var r: proc.Reading = .{};
    r.usages[0] = .{ .pid = pid, .cpu_ns = cpu_ns, .instructions = cpu_ns * 3, .footprint = footprint, .resident = footprint * 2 };
    r.count = 1;
    return r;
}

const test_base: Base = .{
    .round = 0,
    .time = "2026-11-05T18:00:00Z",
    .host = .{ .name = "h", .os = "macOS", .arch = "aarch64", .cpu = "M", .cores = 8, .memory_bytes = 1 },
    .engine = .{ .name = .chrome, .version = "157", .build = "stable", .binary = "c", .binary_sha256 = "abababababababababababababababababababababababababababababababab", .flags = &.{} },
    .page = "workloads/attributes.html",
    .run = 1,
};

test "timed: begin and end make one record, with the CPU and memory between them" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "p.html", .kind = .timed, .workloads = &.{ "dom.a", "dom.b" } } };
    try c.onMark(.{ .type = "loaded", .load_ms = 20 }, 300, &fakeReading(9, 1_000_000, 100));
    try c.onMark(.{ .type = "begin", .workload = "dom.a" }, 310, &fakeReading(9, 2_000_000, 150));
    c.notePeak(400);
    try c.onMark(.{ .type = "end", .workload = "dom.a", .ops = 1000, .wall_ms = &.{ 5.0, 6.0 } }, 330, &fakeReading(9, 12_000_000, 200));
    try c.onMark(.{ .type = "error", .workload = "dom.b", .message = "TypeError: x", .unsupported = true }, 331, &fakeReading(9, 12_000_000, 200));
    try c.onMark(.{ .type = "done" }, 332, &fakeReading(9, 12_000_000, 200));
    try testing.expect(c.done);
    const records = try c.finish(.done);
    // dom.a, the page's own row (made at done), dom.b's failure.
    try testing.expectEqual(@as(usize, 3), records.len);
    try testing.expectEqualStrings("page.attributes", records[1].workload);
    const r = records[0];
    try journal.validate(r);
    try testing.expectEqualStrings("dom.a", r.workload);
    try testing.expectEqual(@as(?f64, 10), r.cpu_ms);
    try testing.expectEqual(@as(?u64, 30_000_000), r.instructions);
    try testing.expectEqual(@as(u64, 150), r.memory.?.footprint_start);
    try testing.expectEqual(@as(u64, 200), r.memory.?.footprint_end);
    try testing.expectEqual(@as(u64, 400), r.memory.?.footprint_peak);
    try testing.expectEqual(@as(?f64, 300), r.launch_ms);
    try testing.expectEqual(journal.Status.unsupported, records[2].status);
    try testing.expectEqualStrings("TypeError: x", records[2].message.?);
    try journal.validate(records[2]);
}

test "a workload the page never ended is a timeout, or a crash when the engine exited" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "p.html", .kind = .timed, .workloads = &.{"dom.a"} } };
    try c.onMark(.{ .type = "begin", .workload = "dom.a" }, 1, &fakeReading(9, 0, 1));
    const t = try c.finish(.{ .timeout = 300 });
    try testing.expectEqual(journal.Status.timeout, t[0].status);
    try testing.expectEqualStrings("no result in 300 s", t[0].message.?);
    try journal.validate(t[0]);

    var d: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "p.html", .kind = .timed, .workloads = &.{"dom.a"} } };
    const e = try d.finish(.{ .exited = "signal SEGV" });
    try testing.expectEqual(journal.Status.crash, e[0].status);
    try journal.validate(e[0]);
}

test "a chain: one wall sample and one footprint per step" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "load/news.html", .kind = .chain, .steps = 3, .workloads = &.{"load.news"} } };
    try c.onMark(.{ .type = "step", .workload = "load.news", .step = 0, .load_ms = 40 }, 500, &fakeReading(9, 0, 1000));
    try c.onMark(.{ .type = "step", .workload = "load.news", .step = 1, .load_ms = 30 }, 550, &fakeReading(9, 0, 1100));
    try c.onMark(.{ .type = "step", .workload = "load.news", .step = 2, .load_ms = 31 }, 600, &fakeReading(9, 0, 1150));
    try c.onMark(.{ .type = "done" }, 601, &fakeReading(9, 0, 1150));
    const records = try c.finish(.done);
    try testing.expectEqual(@as(usize, 1), records.len);
    try journal.validate(records[0]);
    try testing.expectEqualSlices(f64, &.{ 40, 30, 31 }, records[0].wall_ms);
    try testing.expectEqualSlices(u64, &.{ 1000, 1100, 1150 }, records[0].series);
    try testing.expectEqual(@as(?f64, 500), records[0].launch_ms);

    // A chain cut short says why, and keeps the steps it has.
    var d: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "load/news.html", .kind = .chain, .steps = 3, .workloads = &.{"load.news"} } };
    try d.onMark(.{ .type = "step", .workload = "load.news", .load_ms = 40 }, 500, &fakeReading(9, 0, 1000));
    const cut = try d.finish(.{ .timeout = 60 });
    try testing.expectEqual(journal.Status.timeout, cut[0].status);
    try testing.expectEqual(@as(usize, 1), cut[0].wall_ms.len);
}

test "idle: the settled footprint, and the startup row beside it" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "memory/idle.html", .kind = .idle, .settle_ms = 3000, .workloads = &.{"memory.idle-page"} } };
    try c.onMark(.{ .type = "loaded", .load_ms = 5 }, 250, &fakeReading(9, 0, 5000));
    c.notePeak(9000);
    try c.idle(&fakeReading(9, 0, 6000));
    const records = try c.finish(.done);
    try testing.expectEqual(@as(usize, 2), records.len);
    try testing.expectEqualStrings("memory.idle-page", records[0].workload);
    try testing.expectEqual(@as(u64, 6000), records[0].memory.?.footprint_end);
    try testing.expectEqual(@as(u64, 9000), records[0].memory.?.footprint_peak);
    try testing.expectEqualStrings("startup.idle-page", records[1].workload);
    try testing.expectEqualSlices(f64, &.{250}, records[1].wall_ms);
    for (records) |r| try journal.validate(r);
}

test "steady memory: each workload's settled footprint, and the page's own row" {
    // The integrator (2026-11-05): Crane's footprint grows within a page, so
    // round 0 measures memory per workload and per page, steady and peak.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var c: Collector = .{ .arena = a, .base = test_base, .page = .{ .page = "workloads/attributes.html", .kind = .timed, .workloads = &.{"dom.a"} } };
    try c.onMark(.{ .type = "loaded", .load_ms = 20 }, 300, &fakeReading(9, 0, 100));
    try c.onMark(.{ .type = "begin", .workload = "dom.a" }, 310, &fakeReading(9, 0, 150));
    c.notePeak(900);
    try c.onMark(.{ .type = "end", .workload = "dom.a", .ops = 10, .wall_ms = &.{1.0} }, 320, &fakeReading(9, 1_000_000, 800));
    // After the workload's teardown and the settle time: what it kept.
    try c.onMark(.{ .type = "settled", .workload = "dom.a" }, 330, &fakeReading(9, 1_000_000, 600));
    try c.onMark(.{ .type = "done" }, 340, &fakeReading(9, 1_000_000, 500));
    const records = try c.finish(.done);
    try testing.expectEqual(@as(usize, 2), records.len);
    try testing.expectEqual(@as(?u64, 600), records[0].memory.?.footprint_settled);
    try testing.expectEqual(@as(u64, 800), records[0].memory.?.footprint_end);
    try testing.expectEqual(@as(u64, 900), records[0].memory.?.footprint_peak);
    // The page's row: loaded -> done (settled), and the whole launch's peak.
    const page = records[1];
    try testing.expectEqualStrings("page.attributes", page.workload);
    try testing.expectEqual(journal.Kind.idle, page.kind);
    try testing.expectEqual(@as(u64, 100), page.memory.?.footprint_start);
    try testing.expectEqual(@as(u64, 500), page.memory.?.footprint_end);
    try testing.expectEqual(@as(?u64, 500), page.memory.?.footprint_settled);
    try testing.expectEqual(@as(u64, 900), page.memory.?.footprint_peak);
    for (records) |r| try journal.validate(r);
}

test "marks: a JSON body, unknown fields ignored" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const m = try parseMark(arena.allocator(), "{\"token\":\"t\",\"type\":\"end\",\"workload\":\"dom.a\",\"ops\":5,\"wall_ms\":[1.5,2],\"ua\":\"x\"}");
    try testing.expectEqualStrings("end", m.type);
    try testing.expectEqual(@as(u64, 5), m.ops);
    try testing.expectEqualSlices(f64, &.{ 1.5, 2 }, m.wall_ms);
}
