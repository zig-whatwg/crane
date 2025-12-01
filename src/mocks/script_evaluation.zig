//! Mock Script Evaluation for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML script evaluation
//! when the HTML specification scripting section is implemented.
//! See: https://html.spec.whatwg.org/multipage/webappapis.html#hostimportmoduledynamically
//!
//! Script evaluation is how worker scripts are executed. This mock
//! records script evaluations for testing without actual JS execution.
//!
//! HTML spec concepts mocked:
//! - Script fetching
//! - Classic script evaluation
//! - Module script evaluation
//! - importScripts() for workers

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Script type (classic vs module).
pub const ScriptType = enum {
    classic,
    module,
};

/// Result of script evaluation.
pub const EvaluationResult = union(enum) {
    /// Script evaluated successfully.
    success: void,

    /// Script threw an error.
    error_thrown: []const u8,

    /// Script fetch failed.
    fetch_error: []const u8,

    /// Script was aborted.
    aborted: void,
};

/// Record of a script evaluation.
pub const ScriptRecord = struct {
    /// URL of the script.
    url: []const u8,

    /// Type of script.
    script_type: ScriptType,

    /// When the script was evaluated (mock timestamp).
    evaluated_at: i64,

    /// Result of evaluation.
    result: EvaluationResult,

    /// Whether this was from importScripts().
    from_import_scripts: bool,

    allocator: Allocator,

    pub fn deinit(self: *ScriptRecord) void {
        self.allocator.free(self.url);
        switch (self.result) {
            .error_thrown => |msg| self.allocator.free(msg),
            .fetch_error => |msg| self.allocator.free(msg),
            else => {},
        }
        self.allocator.destroy(self);
    }
};

/// Mock Script Evaluator.
///
/// Records script evaluation attempts for testing.
/// Can be configured to succeed or fail for specific URLs.
pub const ScriptEvaluator = struct {
    allocator: Allocator,

    /// Records of evaluated scripts.
    evaluation_records: std.ArrayListUnmanaged(*ScriptRecord),

    /// URLs configured to fail fetch.
    fetch_failures: std.StringHashMapUnmanaged([]const u8),

    /// URLs configured to throw errors.
    throw_errors: std.StringHashMapUnmanaged([]const u8),

    /// Default behavior: succeed or fail.
    default_success: bool = true,

    /// Mock timestamp counter.
    timestamp: i64 = 0,

    const Self = @This();

    /// Initialize the script evaluator.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .evaluation_records = .{},
            .fetch_failures = .{},
            .throw_errors = .{},
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.evaluation_records.items) |record| {
            record.deinit();
        }
        self.evaluation_records.deinit(self.allocator);

        // Free failure messages
        var fetch_iter = self.fetch_failures.iterator();
        while (fetch_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.fetch_failures.deinit(self.allocator);

        var throw_iter = self.throw_errors.iterator();
        while (throw_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.throw_errors.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Evaluate a script.
    ///
    /// This mock:
    /// 1. Records the evaluation attempt
    /// 2. Checks configured failures
    /// 3. Returns appropriate result
    pub fn evaluateScript(
        self: *Self,
        url: []const u8,
        script_type: ScriptType,
    ) !EvaluationResult {
        return self.evaluateScriptInternal(url, script_type, false);
    }

    /// Evaluate scripts via importScripts().
    ///
    /// Per HTML spec:
    /// - Only valid in classic worker scripts
    /// - Fetches and evaluates scripts synchronously
    /// - Throws if any script fails
    pub fn importScripts(self: *Self, urls: []const []const u8) !void {
        for (urls) |url| {
            const result = try self.evaluateScriptInternal(url, .classic, true);
            switch (result) {
                .success => {},
                .error_thrown => |msg| {
                    _ = msg;
                    return error.ScriptError;
                },
                .fetch_error => |msg| {
                    _ = msg;
                    return error.FetchError;
                },
                .aborted => return error.Aborted,
            }
        }
    }

    fn evaluateScriptInternal(
        self: *Self,
        url: []const u8,
        script_type: ScriptType,
        from_import: bool,
    ) !EvaluationResult {
        self.timestamp += 1;

        // Determine result
        var result: EvaluationResult = undefined;

        if (self.fetch_failures.get(url)) |msg| {
            result = .{ .fetch_error = try self.allocator.dupe(u8, msg) };
        } else if (self.throw_errors.get(url)) |msg| {
            result = .{ .error_thrown = try self.allocator.dupe(u8, msg) };
        } else if (self.default_success) {
            result = .success;
        } else {
            result = .{ .error_thrown = try self.allocator.dupe(u8, "Default failure") };
        }

        // Record the evaluation
        const record = try self.allocator.create(ScriptRecord);
        errdefer self.allocator.destroy(record);

        record.* = .{
            .url = try self.allocator.dupe(u8, url),
            .script_type = script_type,
            .evaluated_at = self.timestamp,
            .result = result,
            .from_import_scripts = from_import,
            .allocator = self.allocator,
        };

        try self.evaluation_records.append(self.allocator, record);

        return result;
    }

    // === Configuration ===

    /// Configure a URL to fail fetch.
    pub fn configureFetchFailure(self: *Self, url: []const u8, message: []const u8) !void {
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        const msg_copy = try self.allocator.dupe(u8, message);
        try self.fetch_failures.put(self.allocator, url_copy, msg_copy);
    }

    /// Configure a URL to throw an error.
    pub fn configureThrowError(self: *Self, url: []const u8, message: []const u8) !void {
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);
        const msg_copy = try self.allocator.dupe(u8, message);
        try self.throw_errors.put(self.allocator, url_copy, msg_copy);
    }

    /// Set default behavior.
    pub fn setDefaultSuccess(self: *Self, success: bool) void {
        self.default_success = success;
    }

    // === Query ===

    /// Check if a script URL was evaluated.
    pub fn hasEvaluated(self: *const Self, url: []const u8) bool {
        for (self.evaluation_records.items) |record| {
            if (std.mem.eql(u8, record.url, url)) {
                return true;
            }
        }
        return false;
    }

    /// Get evaluation count for a URL.
    pub fn getEvaluationCount(self: *const Self, url: []const u8) usize {
        var count: usize = 0;
        for (self.evaluation_records.items) |record| {
            if (std.mem.eql(u8, record.url, url)) {
                count += 1;
            }
        }
        return count;
    }

    /// Get all evaluation records.
    pub fn getRecords(self: *const Self) []const *ScriptRecord {
        return self.evaluation_records.items;
    }

    /// Get total number of evaluations.
    pub fn getTotalEvaluations(self: *const Self) usize {
        return self.evaluation_records.items.len;
    }

    /// Clear all records (for testing reset).
    pub fn clearRecords(self: *Self) void {
        for (self.evaluation_records.items) |record| {
            record.deinit();
        }
        self.evaluation_records.clearRetainingCapacity();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ScriptEvaluator.init and deinit" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    try std.testing.expectEqual(@as(usize, 0), evaluator.getTotalEvaluations());
}

test "ScriptEvaluator.evaluateScript records evaluation" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    const result = try evaluator.evaluateScript("https://example.com/sw.js", .module);

    try std.testing.expectEqual(EvaluationResult.success, result);
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/sw.js"));
    try std.testing.expectEqual(@as(usize, 1), evaluator.getTotalEvaluations());
}

test "ScriptEvaluator.configureFetchFailure" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    try evaluator.configureFetchFailure("https://example.com/bad.js", "404 Not Found");

    const result = try evaluator.evaluateScript("https://example.com/bad.js", .classic);

    switch (result) {
        .fetch_error => |msg| {
            try std.testing.expectEqualStrings("404 Not Found", msg);
        },
        else => return error.ExpectedFetchError,
    }
}

test "ScriptEvaluator.configureThrowError" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    try evaluator.configureThrowError("https://example.com/error.js", "SyntaxError");

    const result = try evaluator.evaluateScript("https://example.com/error.js", .classic);

    switch (result) {
        .error_thrown => |msg| {
            try std.testing.expectEqualStrings("SyntaxError", msg);
        },
        else => return error.ExpectedErrorThrown,
    }
}

test "ScriptEvaluator.importScripts evaluates multiple scripts" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    const urls = [_][]const u8{
        "https://example.com/lib1.js",
        "https://example.com/lib2.js",
    };
    try evaluator.importScripts(&urls);

    try std.testing.expectEqual(@as(usize, 2), evaluator.getTotalEvaluations());
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/lib1.js"));
    try std.testing.expect(evaluator.hasEvaluated("https://example.com/lib2.js"));

    // Check they're marked as from importScripts
    for (evaluator.getRecords()) |record| {
        try std.testing.expect(record.from_import_scripts);
    }
}

test "ScriptEvaluator.importScripts fails on error" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    try evaluator.configureFetchFailure("https://example.com/missing.js", "Not found");

    const urls = [_][]const u8{
        "https://example.com/good.js",
        "https://example.com/missing.js",
    };

    const result = evaluator.importScripts(&urls);
    try std.testing.expectError(error.FetchError, result);

    // First script was evaluated, second failed
    try std.testing.expectEqual(@as(usize, 2), evaluator.getTotalEvaluations());
}

test "ScriptEvaluator.setDefaultSuccess" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    evaluator.setDefaultSuccess(false);

    const result = try evaluator.evaluateScript("https://example.com/any.js", .classic);

    switch (result) {
        .error_thrown => {},
        else => return error.ExpectedErrorThrown,
    }
}

test "ScriptEvaluator.getEvaluationCount" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    _ = try evaluator.evaluateScript("https://example.com/sw.js", .module);
    _ = try evaluator.evaluateScript("https://example.com/sw.js", .module);
    _ = try evaluator.evaluateScript("https://example.com/other.js", .module);

    try std.testing.expectEqual(@as(usize, 2), evaluator.getEvaluationCount("https://example.com/sw.js"));
    try std.testing.expectEqual(@as(usize, 1), evaluator.getEvaluationCount("https://example.com/other.js"));
}

test "ScriptEvaluator.clearRecords" {
    const allocator = std.testing.allocator;

    const evaluator = try ScriptEvaluator.init(allocator);
    defer evaluator.deinit();

    _ = try evaluator.evaluateScript("https://example.com/sw.js", .module);
    try std.testing.expectEqual(@as(usize, 1), evaluator.getTotalEvaluations());

    evaluator.clearRecords();
    try std.testing.expectEqual(@as(usize, 0), evaluator.getTotalEvaluations());
}
