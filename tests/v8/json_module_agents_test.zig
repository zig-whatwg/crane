//! An agent's JSON modules wait for evaluation in its own isolate's record
//! (instances B2): v8_wrapper.cpp's per-isolate data (embedder slot 2, as
//! Blink keeps V8PerIsolateData), made with the isolate and ended with it.
//!
//! The parsed values waited in one process-wide vector under a mutex, every
//! entry tagged with its isolate and every lookup a scan of every agent's
//! entries; one whose module was never evaluated nor released outlived its
//! isolate there, its handles of a disposed isolate compared against the next
//! isolate's modules. Two agents on two threads now each hold only their own.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const no_hooks: protocol.HostHooks = .{};

fn parsed(result: protocol.ParseResult) !*protocol.ModuleRecord {
    return switch (result) {
        .record => |record| record,
        .parse_error => |e| {
            e.release();
            return error.DidNotParse;
        },
    };
}

const JsonGraph = struct {
    json: *protocol.ModuleRecord,

    fn resolve(data: ?*anyopaque, referrer: *protocol.ModuleRecord, request: protocol.ModuleRequest) ?*protocol.ModuleRecord {
        _ = referrer;
        const self: *JsonGraph = @ptrCast(@alignCast(data.?));
        if (!std.mem.eql(u8, request.specifier, "./d.json")) return null;
        return self.json;
    }
};

/// An agent that parses `modules` JSON modules and keeps them unevaluated
/// while `other` (if any) lives and ends on a thread of its own.
const Side = struct {
    modules: usize,
    other: ?*Side = null,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Side) !void {
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://json.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);

        var records: [8]*protocol.ModuleRecord = undefined;
        std.debug.assert(self.modules <= records.len);
        for (records[0..self.modules]) |*record| record.* = try parsed(try protocol.parseJSONModule(realm, "{\"n\": 1}", "https://json.test/k.json", null));
        var released: usize = 0;
        defer for (records[released..self.modules]) |record| protocol.releaseModuleRecord(record);
        // This agent's, and no other's.
        try testing.expectEqual(self.modules, ffi.v8_Isolate_PendingSyntheticModuleCount(isolate));

        if (self.other) |other| {
            const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{other});
            thread.join();
            if (other.failure) |err| return err;
            try testing.expectEqual(self.modules, ffi.v8_Isolate_PendingSyntheticModuleCount(isolate));
        }

        // One evaluated through an import: its value is taken out.
        const main = try parsed(try protocol.parseModule(realm, "import d from './d.json' with { type: 'json' }; globalThis.n = d.n;", "https://json.test/main.js", null));
        defer protocol.releaseModuleRecord(main);
        var graph: JsonGraph = .{ .json = records[0] };
        if (try protocol.linkModule(realm, main, JsonGraph.resolve, &graph)) |link_error| {
            link_error.release();
            return error.LinkFailed;
        }
        const run_scope = try protocol.prepareToRunScript(realm);
        const evaluation = try protocol.evaluateModule(realm, main);
        protocol.cleanUpAfterRunningScript(run_scope);
        switch (evaluation) {
            .completed => {},
            .rejected, .pending => |value| {
                value.release();
                return error.ModuleDidNotComplete;
            },
        }
        try testing.expectEqual(self.modules - 1, ffi.v8_Isolate_PendingSyntheticModuleCount(isolate));

        // The rest released unevaluated: theirs go with them.
        for (records[0..self.modules]) |record| protocol.releaseModuleRecord(record);
        released = self.modules;
        try testing.expectEqual(@as(usize, 0), ffi.v8_Isolate_PendingSyntheticModuleCount(isolate));
    }
};

test "each agent's JSON modules wait in its own isolate, and another agent's end leaves them" {
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();

    var other: Side = .{ .modules = 3 };
    var page: Side = .{ .modules = 5, .other = &other };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{&page});
    thread.join();
    if (page.failure) |err| return err;
}
