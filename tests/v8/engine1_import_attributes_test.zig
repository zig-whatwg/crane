//! import() with an import attribute other than "type", on V8: HTML's
//! HostGetSupportedImportAttributes is « "type" », so the import() rejects
//! with a TypeError and the host's loadImportedModule is never asked - as
//! Blink's HostImportModuleDynamically rejects a ModuleRequest with an
//! invalid attribute key before its host steps. All three browsers pass
//! html/semantics/scripting-1/the-script-element/import-attributes/
//! dynamic-import-with-attributes-argument.any.js that way (feature-queue
//! :1277, Codex row 77 Q6).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agent, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The host's side of import(): it counts the loads it is asked for, and
/// fails each one at once.
const ImportHost = struct {
    loads: usize = 0,
    requests: [4]?*protocol.ImportRequest = .{ null, null, null, null },

    /// Fail every request the host was handed, as a host whose fetch failed.
    fn failAll(self: *ImportHost) void {
        for (&self.requests) |*slot| {
            const request = slot.* orelse continue;
            slot.* = null;
            protocol.finishDynamicImport(request, .{ .failure = .{ .number = 1 } });
        }
    }

    fn load(host: ?*anyopaque, realm: runtime.Context, referrer: protocol.ImportReferrer, specifier: []const u8, type_attribute: ?[]const u8, request: *protocol.ImportRequest) void {
        _ = realm;
        _ = referrer;
        _ = specifier;
        _ = type_attribute;
        const self: *ImportHost = @ptrCast(@alignCast(host.?));
        if (self.loads < self.requests.len) self.requests[self.loads] = request;
        self.loads += 1;
    }
};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        _ = info;
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

fn expectString(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

test "import() with an attribute key other than type rejects with a TypeError and asks the host nothing" {
    try setup();
    var host: ImportHost = .{};
    const hooks: protocol.HostHooks = .{ .loadImportedModule = ImportHost.load };
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    var reports: Reports = .{};
    try protocol.runClassicScript(realm, .{ .utf8 =
        \\globalThis.outcome = 'pending';
        \\import('./m.js', { with: { unsupportedKey: 'value' } }).then(
        \\  () => { globalThis.outcome = 'loaded'; },
        \\  (e) => { globalThis.outcome = e.constructor === TypeError ? 'TypeError' : String(e); });
    }, "https://example.test/s.js", null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try protocol.performMicrotaskCheckpoint(agent);
    try expectString(realm, "globalThis.outcome", "TypeError");
    try std.testing.expectEqual(@as(usize, 0), host.loads);

    // A "type" attribute alone, or none, still reaches the host.
    try protocol.runClassicScript(realm, .{ .utf8 = "import('./m.js', { with: { type: 'json' } }).catch(() => {}); import('./n.js', { with: {} }).catch(() => {});" }, "https://example.test/s.js", null, reports.reporter());
    try std.testing.expectEqual(@as(usize, 2), host.loads);
    host.failAll();
    try protocol.performMicrotaskCheckpoint(agent);
}
