//! Focus state that follows the user's input is each top-level traversable's
//! (a tab's; lane gstate3): the input modality :focus-visible reads (HTML
//! 6.6.6 and Selectors 4 :focus-visible - the last interaction "in its
//! top-level traversable") and the text controls with an uncommitted user
//! edit (HTML 6.6.4 focus update steps, step 2.1). Both were one per thread:
//! another tab's key press decided this tab's :focus-visible, and another
//! tab's edits pushed this tab's pending edit out of a shared 16-entry table,
//! so its change event was never fired.
//!
//! Two Browsers on one thread are two top-level traversables there.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");
const Browser = @import("browser").Browser;

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.run, .{&result});
    thread.join();
    try result;
}

fn openPage(browser: *Browser, markup: []const u8) !*runtime.Instance {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context.?;
    try page.loadHTML(markup, .{ .base_url = "about:blank" });
    return page.document_instance.?;
}

fn byId(document: *runtime.Instance, id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

fn modalityPerTab() !void {
    const a = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer a.deinit();
    const document_a = try openPage(a, "<!doctype html><body><button id=b>b</button>");
    const b = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer b.deinit();
    const document_b = try openPage(b, "<!doctype html><body><button id=b>b</button>");

    try a.current_context.?.runScript("document.getElementById('b').focus();");
    const button_a = try byId(document_a, "b");
    // The user pressed a pointer button in tab A: its focused button is not
    // focus-visible (the heuristic for a pointer interaction).
    html.focus.noteInputModality(document_a, true);
    try std.testing.expect(!html.focus.matchesFocusVisible(button_a));
    // A key press in tab B is B's interaction, not A's.
    html.focus.noteInputModality(document_b, false);
    try std.testing.expect(!html.focus.matchesFocusVisible(button_a));
}

test "the input modality :focus-visible reads is its own top-level traversable's" {
    try onThread(modalityPerTab);
}

fn pendingEditPerTab() !void {
    const allocator = std.testing.allocator;
    const a = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer a.deinit();
    const document_a = try openPage(a, "<!doctype html><body><textarea id=t>before</textarea>");
    const page_a = a.current_context.?;
    try page_a.runScript(
        \\globalThis.events = [];
        \\const control = document.getElementById('t');
        \\control.addEventListener('change', () => events.push('change'));
        \\control.focus();
    );
    const textarea_a = try byId(document_a, "t");
    html.focus.willEditByUser(textarea_a);
    try interfaces.Node.set_textContent(textarea_a, runtime.DOMString.initInterned("after"));

    // Tab B's user begins editing seventeen controls of its own, none
    // committed.
    const b = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer b.deinit();
    var markup: std.ArrayListUnmanaged(u8) = .empty;
    defer markup.deinit(allocator);
    try markup.appendSlice(allocator, "<!doctype html><body>");
    for (0..17) |i| try markup.print(allocator, "<textarea id=t{d}>x</textarea>", .{i});
    const document_b = try openPage(b, markup.items);
    for (0..17) |i| {
        var id_buffer: [8]u8 = undefined;
        const id = try std.fmt.bufPrint(&id_buffer, "t{d}", .{i});
        html.focus.willEditByUser(try byId(document_b, id));
    }

    // Tab A's control loses focus: its user's edit is committed.
    html.focus.unfocusingSteps(textarea_a);
    const events = try page_a.evaluateScriptToString("events.join(',')", allocator);
    defer allocator.free(events);
    try std.testing.expectEqualStrings("change", events);
}

test "a text control's uncommitted user edit is its own top-level traversable's: another tab's edits never push it out" {
    try onThread(pendingEditPerTab);
}
