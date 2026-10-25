//! Font value reader integration through the owning public APIs.
//! Uses public FontFace constructors, document.fonts and rendering selection.
//! The comma in ordinary family names makes apiFamily take its valid raw-name
//! quoting path, so the e2 family-selector RED is independent of the separate
//! familyDescriptor typed-value unwrap RED. No owner state is manufactured.
const std = @import("std");
const browser_mod = @import("browser");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");

const Face = struct {
    style: []const u8 = "normal",
    stretch: []const u8 = "normal",
    weight: []const u8 = "400",
};
const Case = struct {
    family: []const u8 = "Ci1, Used",
    markup: []const u8,
    faces: []const Face,
    loading: []const bool,
};

fn selection(case: Case) !void {
    const allocator = std.testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(case.markup, .{ .base_url = "about:blank" });
    const realm = browser.getRealm() orelse return error.NoRealm;
    defer dom.document_fetches.abortAll(realm);
    const doc_value = try browser.evaluateScript("document");
    defer doc_value.release();
    const document = engine.convertToPlatformObject(realm, doc_value.borrow()) orelse return error.NoDocument;
    const set = try interfaces.Document.get_fonts(document);
    const created = try browser.evaluateScript("globalThis.ci1UsedFaces = [];");
    created.release();
    for (case.faces, 0..) |face, index| {
        const script = try std.fmt.allocPrint(allocator, "globalThis.ci1UsedFaces.push(new FontFace('{s}', 'url(http://127.0.0.1:65533/ci1-used-{d})', " ++
            "{{style:'{s}', stretch:'{s}', weight:'{s}'}})); document.fonts.add(globalThis.ci1UsedFaces[{d}]);", .{ case.family, index, face.style, face.stretch, face.weight, index });
        defer allocator.free(script);
        const result = try browser.evaluateScript(script);
        result.release();
    }
    const state = dom.style.hooks.fontSetOf(set) orelse return error.NoFontSetState;
    try std.testing.expectEqual(case.faces.len, state.members.items.len);
    try std.testing.expectEqual(case.faces.len, case.loading.len);
    for (state.members.items) |member| {
        try std.testing.expectEqual(._unloaded_, try interfaces.FontFace.get_status(member.face.instance));
    }
    dom.style.engine.resource_loading.updateRendering(document);
    for (state.members.items, case.loading) |member, loading| {
        const actual = try interfaces.FontFace.get_status(member.face.instance);
        const expected: @TypeOf(actual) = if (loading) ._loading_ else ._unloaded_;
        try std.testing.expectEqual(expected, actual);
    }
    dom.document_fetches.abortAll(realm);
    try std.testing.expectEqual(@as(usize, 0), browser.agent_host.fetches.inFlight());
}

fn fresh(comptime case: Case) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            selection(case) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

const angle_faces = [_]Face{ .{}, .{ .style = "oblique 5deg" }, .{ .style = "oblique 15deg" } };
const width_faces = [_]Face{ .{ .stretch = "75%" }, .{}, .{ .stretch = "125%" } };

test "ci1 e1 used font consumes the explicit positive oblique angle" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:oblique 5deg\">A</span></body>",
        .faces = &angle_faces,
        .loading = &.{ false, true, false },
    });
}

test "ci1 e1 used font consumes the explicit negative oblique angle" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:oblique -15deg\">A</span></body>",
        .faces = &.{ .{}, .{ .style = "oblique -5deg" }, .{ .style = "oblique -15deg" } },
        .loading = &.{ false, false, true },
    });
}

test "ci1 e1 used font consumes a computed oblique calculation" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:oblique calc(5deg + 10deg)\">A</span></body>",
        .faces = &angle_faces,
        .loading = &.{ false, false, true },
    });
}

test "ci1 e1 plain oblique keeps the existing fourteen degree selection" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:oblique\">A</span></body>",
        .faces = &angle_faces,
        .loading = &.{ false, false, true },
    });
}

test "ci1 e1 zero computed oblique keeps normal selection" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:oblique calc(5deg - 5deg)\">A</span></body>",
        .faces = &angle_faces,
        .loading = &.{ true, false, false },
    });
}

test "ci1 e1 used font consumes a literal width percentage" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-width:75%\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ true, false, false },
    });
}

test "ci1 e1 used font consumes a computed width keyword" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-width:condensed\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ true, false, false },
    });
}

test "ci1 e1 used font consumes a computed width calculation" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-width:calc(50% + 25%)\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ true, false, false },
    });
}

test "ci1 e1 used font consumes the font-stretch alias" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-stretch:expanded\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ false, false, true },
    });
}

test "ci1 e1 initial width keeps normal selection" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used'\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ false, true, false },
    });
}

test "ci1 existing italic and numeric weight selection stays intact" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-style:italic;font-weight:700\">A</span></body>",
        .faces = &.{ .{}, .{ .style = "italic" }, .{ .style = "italic", .weight = "700" } },
        .loading = &.{ false, false, true },
    });
}

test "ci1 e2 used font consumes inherited typed families independently of descriptor parsing" {
    try fresh(.{
        .markup = "<!doctype html><body><div style=\"font-family:'Ci1, Used'\"><span>A</span></div></body>",
        .faces = &.{.{}},
        .loading = &.{true},
    });
}

test "ci1 e2 quoted generic family selects its named face" {
    try fresh(.{
        .family = "serif",
        .markup = "<!doctype html><body><span style=\"font-family:'serif'\">A</span></body>",
        .faces = &.{.{}},
        .loading = &.{true},
    });
}

test "ci1 e2 unquoted generic does not select an identically named face" {
    try fresh(.{
        .family = "serif",
        .markup = "<!doctype html><body><span style=\"font-family:serif\">A</span></body>",
        .faces = &.{.{}},
        .loading = &.{false},
    });
}

test "ci1 e1 explicit normal font stretch keeps normal selection" {
    try fresh(.{
        .markup = "<!doctype html><body><span style=\"font-family:'Ci1, Used';font-stretch:normal\">A</span></body>",
        .faces = &width_faces,
        .loading = &.{ false, true, false },
    });
}
