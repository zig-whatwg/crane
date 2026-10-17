//! Import-map integrity normalization and Document-owned merge semantics.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const runtime = @import("runtime");
const modules = dom.document_modules;

fn resolve(document: *runtime.Instance, url: []const u8) []const u8 {
    if (comptime @hasDecl(modules, "resolveModuleIntegrity")) return modules.resolveModuleIntegrity(document, url) orelse "";
    return "";
}

fn add(document: *runtime.Instance, url: []const u8, metadata: []const u8) !void {
    if (comptime @hasDecl(modules, "addIntegrityMapping")) return modules.addIntegrityMapping(document, url, metadata);
}

const Trial = struct {
    merge: bool,
    result: anyerror!void = {},
    fn run(self: *@This()) void {
        self.result = self.check();
    }
    fn check(self: *@This()) !void {
        const a = std.testing.allocator;
        const browser = try browser_mod.Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        const base = "https://sri.test/dir/page.html";
        try browser.navigateWithOptions(base, .window, .{ .skip_load = true });
        const context = browser.current_context orelse return error.NoContext;
        try context.loadHTML(
            \\<!doctype html><script type=importmap>{"integrity": {
            \\ "./one.js": "sha256-first", "/dir/one.js": "sha384-last",
            \\ "../two.js": "sha512-two", "https://sri.test/absolute.js": "absolute",
            \\ "bare": "ignored", "": "ignored", "./not-string.js": 12,
            \\ "http://[invalid": "ignored", "./empty.js": ""
            \\}}</script>
        , .{ .base_url = base });
        const document = context.document_instance orelse return error.NoDocument;
        if (self.merge) {
            // Entries are never replaced, so a borrowed result remains valid
            // even after another map adds the same URL and grows the map.
            try add(document, "https://sri.test/new.js", "sha256-first");
            const borrowed = resolve(document, "https://sri.test/new.js");
            try add(document, "https://sri.test/new.js", "sha512-second");
            try add(document, "https://sri.test/another.js", "sha384-other");
            try std.testing.expectEqualStrings("sha256-first", borrowed);
            try std.testing.expectEqualStrings("sha256-first", resolve(document, "https://sri.test/new.js"));
            try std.testing.expectEqualStrings("sha384-other", resolve(document, "https://sri.test/another.js"));
        } else {
            try std.testing.expectEqualStrings("sha384-last", resolve(document, "https://sri.test/dir/one.js"));
            try std.testing.expectEqualStrings("sha512-two", resolve(document, "https://sri.test/two.js"));
            try std.testing.expectEqualStrings("absolute", resolve(document, "https://sri.test/absolute.js"));
            for ([_][]const u8{ "https://sri.test/dir/bare", "https://sri.test/dir/not-string.js", "https://sri.test/missing.js", "https://sri.test/dir/empty.js" }) |url| {
                try std.testing.expectEqualStrings("", resolve(document, url));
            }
        }
    }
};

fn run(merge: bool) !void {
    var trial: Trial = .{ .merge = merge };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "sri import map normalizes URL keys skips invalid entries and resolves missing to empty" {
    try run(false);
}

test "sri import map merge keeps existing owned integrity values" {
    try run(true);
}
