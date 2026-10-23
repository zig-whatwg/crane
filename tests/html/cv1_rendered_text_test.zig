//! Selection API stringifier, CSS UI 4 §6.1, CSS Contain 2 §4.
const std = @import("std");
const Browser = @import("browser").Browser;

fn exercise(comptime source: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://cv1.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html><body><div id='target'></div></body>", .{ .base_url = "https://cv1.test/" });
    const text = try context.evaluateScriptToString(
        \\function selectText(node) {
        \\  const range = document.createRange(); range.selectNodeContents(node);
        \\  getSelection().removeAllRanges(); getSelection().addRange(range);
        \\  return getSelection().toString();
        \\}
    ++ source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn fresh(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, result: *?anyerror) void {
            exercise(source, want) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &result });
    thread.join();
    if (result) |err| return err;
}

test "Selection filters used user-select while text descendants and innerText survive" {
    try fresh(
        \\target.innerHTML = 'a<span style="user-select:none">hidden<strong style="user-select:text">b</strong></span>c';
        \\JSON.stringify([selectText(target), target.innerText]);
    , "[\"abc\",\"ahiddenbc\"]");
}

test "Selection beginning in an auto subtree follows a none ancestor" {
    try fresh(
        \\target.style.userSelect = 'none'; target.innerHTML = '<span>hidden</span>';
        \\selectText(target.firstChild);
    , "");
}

test "content-visibility skips selected content without changing raw Range text" {
    try fresh(
        \\target.style.contentVisibility = 'hidden'; target.textContent = 'raw';
        \\const selected = selectText(target);
        \\JSON.stringify([selected, getSelection().getRangeAt(0).toString(), target.innerText]);
    , "[\"\",\"raw\",\"\"]");
}

test "content-visibility applies to inline blocks but not non-atomic inlines or tables" {
    try fresh(
        \\target.innerHTML = '<span style="content-visibility:hidden">inline</span><span style="display:inline-block;content-visibility:hidden">skipped</span><span style="display:contents;content-visibility:hidden">contents</span>';
        \\selectText(target);
    , "inlinecontents");
}

test "the shared rendering predicate excludes skipped descendants but keeps their root box" {
    try fresh(
        \\target.tabIndex = 0; target.style.contentVisibility = 'hidden'; target.innerHTML = '<input>';
        \\target.focus(); const ownBox = document.activeElement === target;
        \\target.firstChild.focus(); const skipped = document.activeElement !== target.firstChild;
        \\target.style.contentVisibility = 'visible'; target.firstChild.focus();
        \\JSON.stringify([ownBox, skipped, document.activeElement === target.firstChild]);
    , "[true,true,true]");
}

test "user-select all preserves explicit script-created Range endpoints" {
    try fresh(
        \\target.style.userSelect = 'all'; target.innerHTML = '<span>abc</span>';
        \\const part = document.createRange(); part.setStart(target.firstChild.firstChild, 1); part.setEnd(target.firstChild.firstChild, 2);
        \\getSelection().removeAllRanges(); getSelection().addRange(part);
        \\getSelection().toString();
    , "b");
}

test "an editable host restores selection despite its specified none value" {
    try fresh(
        \\target.style.userSelect = 'none';
        \\target.innerHTML = '<div contenteditable style="user-select:none">editable</div>';
        \\selectText(target.firstChild);
    , "editable");
}

test "UA defaults suppress input buttons while ordinary buttons keep auto" {
    try fresh(
        \\target.innerHTML = '<input type=button><input type=submit><input type=RESET><input type=image><input type=file><button></button>';
        \\JSON.stringify(Array.from(target.children, e => getComputedStyle(e).userSelect));
    , "[\"none\",\"none\",\"none\",\"auto\",\"auto\",\"auto\"]");
}

test "a contents root inside skipped content uses innerText raw-text fallback" {
    try fresh(
        \\target.style.contentVisibility = 'hidden';
        \\target.innerHTML = '<span style="display:contents;text-transform:uppercase">raw</span>';
        \\const hidden = target.firstChild.innerText;
        \\target.style.contentVisibility = 'visible';
        \\JSON.stringify([hidden, target.firstChild.innerText]);
    , "[\"raw\",\"RAW\"]");
}

test "inherited editability does not turn every descendant into a selection host" {
    try fresh(
        \\target.contentEditable = 'true';
        \\target.innerHTML = '<span style="user-select:none">hidden</span><span>shown</span>';
        \\selectText(target);
    , "shown");
}

test "select options contribute no Selection text in either widget mode" {
    inline for (.{ "1", "2" }) |size| try fresh(
        \\const select = document.createElement('select');
        \\const option = document.createElement('option');
        \\option.innerHTML = 'a<span style="user-select:none">b<strong style="user-select:text">c</strong></span>d';
        \\select.append(option); target.append(select);
    ++ "select.size = " ++ size ++ ";" ++
        \\JSON.stringify([selectText(option), getSelection().getRangeAt(0).toString(), option.innerText, getComputedStyle(option).userSelect]);
    , "[\"\",\"abcd\",\"abcd\",\"auto\"]");
}

test "an option outside a select uses ordinary user-select filtering" {
    try fresh(
        \\const option = document.createElement('option');
        \\option.innerHTML = 'a<span style="user-select:none">b<strong style="user-select:text">c</strong></span>d';
        \\target.append(option);
        \\JSON.stringify([selectText(option), getSelection().getRangeAt(0).toString(), option.innerText, getComputedStyle(option).userSelect]);
    , "[\"acd\",\"abcd\",\"abcd\",\"auto\"]");
}

test "moving an option out of a select restores selection with original Range offsets" {
    try fresh(
        \\const select = document.createElement('select'), option = document.createElement('option');
        \\option.innerHTML = 'ab<span style="user-select:none">x<strong style="user-select:text">yz</strong></span>cd';
        \\select.append(option); target.append(select); const before = selectText(option);
        \\target.append(option);
        \\const range = document.createRange(); range.setStart(option.firstChild, 1); range.setEnd(option.lastChild, 1);
        \\getSelection().removeAllRanges(); getSelection().addRange(range);
        \\JSON.stringify([before, getSelection().toString(), range.toString()]);
    , "[\"\",\"byzc\",\"bxyzc\"]");
}
