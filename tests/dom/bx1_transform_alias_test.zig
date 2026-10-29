//! Q59-Q61: resolve one-member shorthands before applying wrapper spelling.
//! Cascade 5 §3.1, CSSOM §§6.6.1, 6.7.2, 7.2 and Compat §3.4.1.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;
const allocator = testing.allocator;
const css = dom.style.css;

const Mode = enum { block, none, contents, ancestor_none };

const Page = struct {
    scope: runtime.BrowserScope,
    context: runtime.ContextData,
    window: *runtime.Instance = undefined,
    document: *runtime.Instance = undefined,
    parent: *runtime.Instance = undefined,
    target: *runtime.Instance = undefined,
    parent_style: *runtime.Instance = undefined,
    target_style: *runtime.Instance = undefined,

    fn init(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = .init(allocator), .context = try runtime.ContextData.init(allocator, .{}) };
        errdefer self.context.deinit();
        errdefer self.scope.deinit();
        self.context.browser_scope = &self.scope;
        self.window = try interfaces.Window.init(allocator, &self.context);
        errdefer interfaces.Window.deinit(self.window);
        self.document = blk: {
            const document = try interfaces.Document.init(allocator, &self.context);
            errdefer interfaces.Document.deinit(document);
            try dom.document_internals.setContentType(document, "text/html");
            try dom.document_internals.setDocumentType(document, .html);
            dom.window_globals.setDocument(self.window, document);
            dom.document_browsing_context.setWindow(document, self.window);
            break :blk document; // Window owns its associated document/tree.
        };
        const root = try self.append(self.document, "html");
        self.parent = try self.append(root, "div");
        self.target = try self.append(self.parent, "div");
        self.parent_style = try interfaces.HTMLElement.get_style(self.parent);
        self.target_style = try interfaces.HTMLElement.get_style(self.target);
    }

    fn deinit(self: *Page) void {
        interfaces.Window.deinit(self.window);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.context.deinit();
    }

    fn append(self: *Page, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
        const element = try interfaces.Document.call_createElement(self.document, .initInterned(name), .notPassed());
        errdefer dom.node_creation.destroyRoot(element);
        _ = try interfaces.Node.call_appendChild(parent, element);
        return element;
    }

    fn configure(self: *Page, mode: Mode) !void {
        try interfaces.CSSStyleDeclaration.set_cssText(self.target_style, .initEmpty());
        try set(self.parent_style, "display", if (mode == .ancestor_none) "none" else "block");
        try set(self.target_style, "display", if (mode == .ancestor_none) "block" else @tagName(mode));
    }

    fn computed(self: *Page) !*runtime.Instance {
        return interfaces.Window.call_getComputedStyle(self.window, self.target, .notPassed());
    }
};

fn set(style: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.CSSStyleDeclaration.call_setProperty(style, .initInterned(name), .initInterned(value), .notPassed());
}

fn expect(style: *runtime.Instance, name: []const u8, expected: []const u8) !void {
    var value = try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, .initInterned(name));
    defer value.deinit(style.ctx.allocator);
    try testing.expectEqualStrings(expected, value.asSlice());
}

fn expectPair(style: *runtime.Instance, canonical: []const u8, alias: []const u8, expected: []const u8, alias_expected: []const u8) !void {
    try expect(style, canonical, expected);
    try expect(style, alias, alias_expected);
}

// The native Window/document and its cascade remain outside this allocator.
// Only a temporary computed declaration's owned serialization path can fail.
fn readWithFailures(failing: std.mem.Allocator, page: *Page, canonical: []const u8, alias: []const u8, expected: []const u8, alias_expected: []const u8) !void {
    const style = try interfaces.CSSStyleProperties.initWith(failing, &page.context, .{
        .computed_for = dom.style.ComputedFor{ .element = page.target },
    });
    defer interfaces.CSSStyleProperties.deinit(style);
    try expectPair(style, canonical, alias, expected, alias_expected);
}

fn checkComputed(page: *Page, canonical: []const u8, alias: []const u8, expected: []const u8, alias_expected: []const u8) !void {
    const style = try page.computed();
    defer interfaces.CSSStyleProperties.deinit(style);
    try expectPair(style, canonical, alias, expected, alias_expected);
    try testing.checkAllAllocationFailures(allocator, readWithFailures, .{ page, canonical, alias, expected, alias_expected });
}

fn transformCases(comptime overflow: bool) !void {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    const input = if (overflow) "scale(1e308) scale(2)" else "scale(2)";
    const matrix = if (overflow) "matrix(infinity, 0, 0, infinity, 0, 0)" else "matrix(2, 0, 0, 2, 0, 0)";
    inline for (std.meta.tags(Mode)) |mode| {
        for ([_][]const u8{ "transform", "-webkit-transform" }) |name| {
            try page.configure(mode);
            try set(page.target_style, name, input);
            if (!overflow) {
                // Specified getPropertyValue and setProperty cross-name controls.
                try expectPair(page.target_style, "transform", "-webkit-transform", "scale(2)", "scale(2)");
            }
            const wanted = if (mode == .none) "none" else matrix;
            try checkComputed(&page, "transform", "-webkit-transform", wanted, wanted);
        }
    }
}

fn perspectiveCases() !void {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    inline for (std.meta.tags(Mode)) |mode| {
        for ([_][]const u8{ "perspective", "-webkit-perspective" }) |name| {
            for ([_][]const u8{ "25px", "none" }) |input| {
                try page.configure(mode);
                try set(page.target_style, name, input);
                try expectPair(page.target_style, "perspective", "-webkit-perspective", input, input);
                try checkComputed(&page, "perspective", "-webkit-perspective", input, input);
            }
        }
    }
}

fn orientationCases() !void {
    var page: Page = undefined;
    try page.init();
    defer page.deinit();
    // Q61/probe1026s: retain Crane's coherent Blink grammar and spelling.
    // Safari's mixed spelling belongs to its different alias grammar;
    // Firefox does not ship this alias. No production parser changes here.
    const cases = [_]struct { name: []const u8, input: []const u8, canonical: []const u8, alias: []const u8 }{
        .{ .name = "text-orientation", .input = "mixed", .canonical = "mixed", .alias = "vertical-right" },
        .{ .name = "-webkit-text-orientation", .input = "vertical-right", .canonical = "mixed", .alias = "vertical-right" },
        .{ .name = "text-orientation", .input = "upright", .canonical = "upright", .alias = "upright" },
        .{ .name = "-webkit-text-orientation", .input = "upright", .canonical = "upright", .alias = "upright" },
        .{ .name = "text-orientation", .input = "sideways", .canonical = "sideways", .alias = "sideways" },
        .{ .name = "-webkit-text-orientation", .input = "sideways", .canonical = "sideways", .alias = "sideways" },
        .{ .name = "text-orientation", .input = "sideways-right", .canonical = "sideways", .alias = "sideways" },
        .{ .name = "-webkit-text-orientation", .input = "sideways-right", .canonical = "sideways", .alias = "sideways" },
    };
    inline for (std.meta.tags(Mode)) |mode| {
        for (cases) |case| {
            try page.configure(mode);
            try set(page.target_style, case.name, case.input);
            try checkComputed(&page, "text-orientation", "-webkit-text-orientation", case.canonical, case.alias);
        }
    }
}

fn fresh(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            body() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "one-member shorthand census covers every computed wrapper" {
    var count: usize = 0;
    inline for (std.meta.tags(css.properties.Shorthand)) |shorthand| {
        const longhands = shorthand.longhands();
        if (longhands.len == 1) {
            count += 1;
            const expected: css.properties.Longhand = switch (shorthand) {
                ._webkit_transform => .transform,
                ._webkit_perspective => .perspective,
                ._webkit_text_orientation => .text_orientation,
                else => return error.UncoveredOneMemberShorthand,
            };
            try testing.expectEqual(expected, longhands[0]);
        }
    }
    try testing.expectEqual(@as(usize, 3), count);
}

test "computed transform alias uses the canonical resolver in every display case" {
    try fresh(struct {
        fn run() !void {
            try transformCases(false);
        }
    }.run);
}

test "overflowed transform alias retains the resolved matrix and own-none rule" {
    try fresh(struct {
        fn run() !void {
            try transformCases(true);
        }
    }.run);
}

test "perspective wrapper already shares canonical computed readback" {
    try fresh(perspectiveCases);
}

test "text orientation wrapper preserves its own spelling after resolution" {
    try fresh(orientationCases);
}
