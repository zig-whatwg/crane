//! Font Loading3 §3.1: parse the shorthand with initial absolute values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Checks = if (@hasDecl(css, "font_request")) struct {
    fn resolved(result: *css.font_request.FontLoadingResult) !*css.font_request.FontRequest {
        if (result.* != .resolved) return error.ExpectedResolvedFont;
        return &result.resolved;
    }
    fn request(allocator: std.mem.Allocator) !void {
        var result = (try css.font_request.parseForFontLoading(.{ .allocator = allocator }, "condensed oblique -10deg small-caps bolder 2em/1.5 'Scoped Family', \\48 elvetica, serif")) orelse return error.ExpectedFont;
        defer result.deinit();
        const value = try resolved(&result);
        try testing.expectEqual(@as(f32, 700), value.weight);
        try testing.expectEqual(@as(f32, 75), value.stretch_pct);
        try testing.expectEqual(@as(f32, 32), value.size_px);
        try testing.expectEqual(@as(f32, -10), value.style.oblique);
        try testing.expectEqual(@as(usize, 3), value.families.len);
        try testing.expectEqualStrings("Scoped Family", value.families[0].named.name);
        try testing.expectEqualStrings("Helvetica", value.families[1].named.name);
        try testing.expectEqual(@as(u64, 0), value.families[0].named.scope.serial);
        try testing.expectEqual(@as(u64, 0), value.families[1].named.scope.serial);
        try testing.expect(value.families[2] == .generic);
    }

    fn relativeWeights() !void {
        for ([_][]const u8{ "lighter 100% serif", "bolder 1rem serif", "normal medium serif" }, [_]f32{ 100, 700, 400 }) |input, weight| {
            var result = (try css.font_request.parseForFontLoading(.{ .allocator = testing.allocator }, input)) orelse return error.ExpectedFont;
            defer result.deinit();
            const value = try resolved(&result);
            try testing.expectEqual(weight, value.weight);
            try testing.expectEqual(@as(f32, 16), value.size_px);
        }
    }

    fn invalid(allocator: std.mem.Allocator) !void {
        // Q59/Q112: elementless tree counts and random are syntax failures.
        // The final probes-1023t ruling rejects function-token occurrences,
        // including fixed/cancelled forms, without changing CSS style parsing.
        for ([_][]const u8{ "", "inherit", "initial", "unset", "revert", "revert-layer", "revert-rule", "var(--font)", "italic 12px", "12px var(--family)", "12px v\\61 r(--family)", "italic italic 12px serif", "normal normal normal normal normal 12px serif", "10% 12px serif", "1001 12px serif", "oblique 91deg 12px serif", "calc(sibling-index() * 1px) serif", "calc(sibling-count() * 1px) serif", "16px/calc(sibling-index() * 1px) serif", "calc(random(1px, 2px)) serif" }) |input| {
            if (try css.font_request.parseForFontLoading(.{ .allocator = allocator }, input)) |result| {
                var owned = result;
                owned.deinit();
                return error.UnexpectedFont;
            }
        }
    }

    const SystemState = struct {
        name: [9]u8 = "Host Face".*,
        families: [1]css.font_family.FamilyRef = undefined,
        calls: usize = 0,
        missing: bool = false,
    };
    fn systemResolve(context: ?*anyopaque, keyword: css.font_system.Keyword) ?css.font_system.SystemValues {
        const state: *SystemState = @ptrCast(@alignCast(context.?));
        std.debug.assert(keyword == .caption);
        state.calls += 1;
        if (state.missing) return null;
        state.families[0] = .{ .named = .{ .name = &state.name, .scope = .{ .serial = 91 } } };
        return .{ .families = &state.families, .style = .{ .oblique = -20 }, .weight = 650, .stretch_pct = 87.5, .size_px = 18.5 };
    }
    fn injectedSystem(allocator: std.mem.Allocator, missing: bool) !void {
        var state = SystemState{ .missing = missing };
        var result = (try css.font_request.parseForFontLoading(.{ .allocator = allocator, .system_fonts = .{ .context = &state, .resolve = systemResolve } }, "caption")) orelse return error.ExpectedFont;
        defer result.deinit();
        const value = try resolved(&result);
        try testing.expect(state.calls > 0);
        @memset(&state.name, 'x');
        if (missing) {
            try testing.expect(value.style == .normal);
            try testing.expectEqual(@as(f32, 400), value.weight);
            try testing.expectEqual(@as(f32, 100), value.stretch_pct);
            try testing.expectEqual(@as(f32, 16), value.size_px);
            try testing.expectEqual(css.font_family.Generic.sans_serif, value.families[0].generic);
        } else {
            try testing.expectEqualStrings("Host Face", value.families[0].named.name);
            try testing.expectEqual(@as(u64, 0), value.families[0].named.scope.serial);
            try testing.expectEqual(@as(f32, -20), value.style.oblique);
            try testing.expectEqual(@as(f32, 650), value.weight);
            try testing.expectEqual(@as(f32, 87.5), value.stretch_pct);
            try testing.expectEqual(@as(f32, 18.5), value.size_px);
        }
    }

    fn systemFallback(allocator: std.mem.Allocator) !void {
        for ([_][]const u8{ "caption", "icon", "menu", "message-box", "small-caption", "status-bar" }) |input| {
            var result = (try css.font_request.parseForFontLoading(.{ .allocator = allocator }, input)) orelse return error.ExpectedFont;
            defer result.deinit();
            const value = try resolved(&result);
            try testing.expect(value.style == .normal);
            try testing.expectEqual(@as(f32, 400), value.weight);
            try testing.expectEqual(@as(f32, 100), value.stretch_pct);
            try testing.expectEqual(@as(f32, 16), value.size_px);
            try testing.expectEqual(@as(usize, 1), value.families.len);
            try testing.expect(value.families[0] == .generic);
        }
    }
} else struct {};

test "font requests own decoded families and use typed style width and initial relative values" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.request, .{});
}

test "font loading relative weights resolve against normal instead of an element" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try Checks.relativeWeights();
}

test "font loading rejects CSS-wide values variables and invalid shorthand at every allocation failure" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.invalid, .{});
}

test "system fonts use the pure UA default in font loading when no resolver is supplied" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.systemFallback, .{});
}

test "font loading copies a borrowed system resolver result into a document request" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.injectedSystem, .{false});
}

test "a present system resolver returning no font uses the documented fallback" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.injectedSystem, .{true});
}
