//! Shared word movement: Selection probe Q15 and trusted-key grant Q22.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn probeCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\// Forward uses Crane's existing next-word-start convention. The
        \\// probe used macOS word ends; backward needs no adjustment.
        \\const cases = [
        \\  ['héllo wörld end',0,'forward',6], // word end5 -> next start6
        \\  ['héllo wörld end',11,'backward',6], // unanimous
        \\  ['😀😀 ab end',0,'forward',5], // next word-like start; existing sf2
        \\  ['😀😀 ab end',1,'forward',5], // mid-pair; existing sf2
        \\  ['😀😀 ab end',3,'backward',0], // Chrome/Safari symbol run
        \\  ['😀😀 ab end',7,'backward',5], // unanimous
        \\  ['ab 😀😀 end',4,'backward',3], // Chrome/Firefox symbol run
        \\  ['ab 😀😀 end',6,'forward',8], // next start8, macOS next end11
        \\  ["can't go",0,'forward',6], // Chrome/Safari keep apostrophe; start6
        \\  ["can't go",5,'forward',6], // next start6, macOS next end8
        \\  ["can't go",8,'backward',6], // unanimous
        \\  ['hello,world',0,'forward',6], // next start6, C/S word end5
        \\  ['hello,world',6,'backward',0], // Firefox/Safari skip punctuation
        \\  ['희진DJ',0,'forward',2], // unanimous adjacent script boundary
        \\  ['희진DJ',4,'backward',2], // unanimous
        \\  ['DJ희진',0,'forward',2], // unanimous
        \\  ['DJ희진',4,'backward',2], // unanimous
        \\  ['ab 😀😀 end',0,'forward',3] // existing symbol run may be the next word
        \\];
        \\globalThis.sd1WordFailures = [];
        \\for (const [text, offset, direction, expected] of cases) {
        \\  const host=document.body.appendChild(document.createElement('div'));
        \\  host.contentEditable='true'; host.textContent=text;
        \\  const node=host.firstChild, selection=getSelection();
        \\  selection.collapse(node,offset); selection.modify('move',direction,'word');
        \\  const actual=selection.focusOffset;
        \\  if (actual!==expected || selection.focusNode!==node)
        \\    sd1WordFailures.push({text,offset,direction,expected,actual});
        \\  host.remove();
        \\}
    );
    const failures = try page.evaluate("JSON.stringify(sd1WordFailures)");
    defer std.testing.allocator.free(failures);
    try std.testing.expectEqualStrings("[]", failures);
}

test "sd1 seventeen word probe cases and symbol-run entry retain the next-start convention and UTF16 offsets" {
    try helpers.onFreshThread(probeCases);
}

fn press(page: helpers.Page, key: []const u8, modifiers: html.user_input.Modifiers) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    html.user_input.keyDown(&keyboard, document, .{ .key = key }, modifiers);
    html.user_input.keyUp(&keyboard, document, .{ .key = key }, modifiers);
}

fn expectRange(page: helpers.Page, expected: []const u8) !void {
    const actual = try page.evaluate("JSON.stringify([control.selectionStart,control.selectionEnd,control.selectionDirection])");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

fn wordKeys() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const platform = try page.evaluate("navigator.platform");
    defer std.testing.allocator.free(platform);
    const is_mac = std.mem.indexOf(u8, platform, "Mac") != null;
    const word_modifiers: html.user_input.Modifiers = .{ .alt = is_mac, .ctrl = !is_mac };
    for ([_][]const u8{ "textarea", "input" }) |tag| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "document.body.innerHTML='<{s} id=control></{s}>'; globalThis.control=document.getElementById('control'); control.value='DJ희진'; control.focus();", .{ tag, tag });
        defer std.testing.allocator.free(source);
        try page.run(source);
        for ([_]bool{ false, true }) |alt| {
            const modifiers: html.user_input.Modifiers = .{ .alt = alt, .ctrl = !alt };
            if (alt != is_mac) {
                try page.run("control.setSelectionRange(0,0)");
                press(page, "ArrowRight", modifiers);
                try expectRange(page, "[0,0,\"none\"]");
                try page.run("control.setSelectionRange(4,4)");
                press(page, "ArrowLeft", modifiers);
                try expectRange(page, "[4,4,\"none\"]");
                continue;
            }
            try page.run("control.setSelectionRange(0,0)");
            press(page, "ArrowRight", modifiers);
            try expectRange(page, "[2,2,\"none\"]");
            try page.run("control.setSelectionRange(4,4)");
            press(page, "ArrowLeft", modifiers);
            try expectRange(page, "[2,2,\"none\"]");
            try page.run("control.setSelectionRange(0,0)");
            press(page, "ArrowRight", .{ .alt = alt, .ctrl = !alt, .shift = true });
            try expectRange(page, "[0,2,\"forward\"]");
            try page.run("control.setSelectionRange(4,4)");
            press(page, "ArrowLeft", .{ .alt = alt, .ctrl = !alt, .shift = true });
            try expectRange(page, "[2,4,\"backward\"]");
            // Continuing backward from a backward range moves its focus,
            // retaining the anchor at four and the direction.
            press(page, "ArrowLeft", .{ .alt = alt, .ctrl = !alt, .shift = true });
            try expectRange(page, "[0,4,\"backward\"]");
        }
        // A word command starts at the focus endpoint even for a range.
        try page.run("control.setSelectionRange(0,4,'backward')");
        press(page, "ArrowRight", word_modifiers);
        try expectRange(page, "[2,2,\"none\"]");
        // Extending across the anchor changes the direction only after
        // crossing it; the intermediate collapsed selection has none.
        try page.run("control.setSelectionRange(0,2,'backward')");
        press(page, "ArrowRight", .{ .alt = is_mac, .ctrl = !is_mac, .shift = true });
        try expectRange(page, "[2,2,\"none\"]");
        press(page, "ArrowRight", .{ .alt = is_mac, .ctrl = !is_mac, .shift = true });
        try expectRange(page, "[2,4,\"forward\"]");
        try page.run("control.readOnly=true; control.setSelectionRange(0,0)");
        press(page, "ArrowRight", word_modifiers);
        try expectRange(page, "[2,2,\"none\"]");
        try page.run("control.readOnly=false; control.setSelectionRange(0,0); control.addEventListener('keydown',e=>e.preventDefault(),{once:true})");
        press(page, "ArrowRight", word_modifiers);
        try expectRange(page, "[0,0,\"none\"]");
        // Combined modifiers and Meta are outside this word command.
        press(page, "ArrowRight", .{ .alt = true, .ctrl = true });
        try expectRange(page, "[0,0,\"none\"]");
        press(page, "ArrowRight", .{ .ctrl = true, .meta = true });
        try expectRange(page, "[0,0,\"none\"]");
        try page.run("control.disabled=true");
        press(page, "ArrowRight", word_modifiers);
        try expectRange(page, "[0,0,\"none\"]");
    }
}

test "sd1 word keys share boundaries and preserve selection direction, readonly and cancellation" {
    try helpers.onFreshThread(wordKeys);
}

fn unicodeSpaceCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\// Row129 Q30/RULING.md, Chrome156/Firefox158/Safari27,
        \\// 2026-10-27: NBSP is skipped, NNBSP belongs to the word,
        \\// and EM/IDEOGRAPHIC spaces are their own stops (C/F).
        \\// Forward uses Q15's next-start convention, not macOS word ends.
        \\const cases = [];
        \\for (const [label, space, expected] of [
        \\  ['NBSP','\u00a0',[3,3,0,3]],
        \\  ['EM SPACE','\u2003',[2,3,2,3]],
        \\  ['NARROW NBSP','\u202f',[6,6,0,0]],
        \\  ['IDEOGRAPHIC SPACE','\u3000',[2,3,2,3]]
        \\]) {
        \\  const starts=[[0,'forward'],[2,'forward'],[3,'backward'],[5,'backward']];
        \\  for(let i=0;i<starts.length;i++)
        \\    cases.push([label,'ab'+space+'cd end',...starts[i],expected[i]]);
        \\}
        \\cases.push(['emoji NBSP forward','😀\u00a0😀 ab',0,'forward',3]);
        \\cases.push(['emoji NBSP backward','😀\u00a0😀 ab',3,'backward',0]);
        \\globalThis.sd1SpaceFailures=[];
        \\for(const [label,value,offset,direction,expected] of cases) {
        \\  const host=document.body.appendChild(document.createElement('div'));
        \\  host.contentEditable='true';host.textContent=value;
        \\  const text=host.firstChild,selection=getSelection();
        \\  selection.collapse(text,offset);selection.modify('move',direction,'word');
        \\  if(selection.focusOffset!==expected || selection.focusNode!==text)
        \\    sd1SpaceFailures.push({label,offset,direction,expected,actual:selection.focusOffset});
        \\  host.remove();
        \\}
    );
    const failures = try page.evaluate("JSON.stringify(sd1SpaceFailures)");
    defer std.testing.allocator.free(failures);
    try std.testing.expectEqualStrings("[]", failures);
}

test "sd1 eighteen Unicode-space probe cases preserve the browser movement policies" {
    try helpers.onFreshThread(unicodeSpaceCases);
}

fn utf16RegressionCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\// Native replay of the unchanged 74-case sf2 WPT control.
        \\globalThis.sd1Utf16Cases=0;
        \\globalThis.sd1Utf16Failures=[];
        \\function assert_equals(actual,expected,message) {
        \\  if(actual!==expected) throw new Error(message+': '+actual+' != '+expected);
        \\}
        \\function assert_array_equals(actual,expected) {
        \\  if(JSON.stringify(actual)!==JSON.stringify(expected))
        \\    throw new Error(JSON.stringify(actual)+' != '+JSON.stringify(expected));
        \\}
        \\function test(body,name) {
        \\  sd1Utf16Cases++;
        \\  try { body(); } catch(e) { sd1Utf16Failures.push([name,String(e)]); }
        \\}
        \\
        \\// A text's offsets are UTF-16 code units (DOM "length", Infra "string").
        \\// Moving by word through non-ASCII text must land where it lands in ASCII
        \\// text of the same code-unit shape: an accented letter is one code unit and
        \\// a letter like any other, an astral character is two. Crane's layout-less
        \\// word granularity breaks words at ASCII whitespace and punctuation; each
        \\// text below ends with " end", and no move below leaves its text node.
        \\function move(data, offset, alter, direction) {
        \\  const p = document.createElement("p");
        \\  p.textContent = data;
        \\  document.body.append(p);
        \\  const text = p.firstChild;
        \\  const selection = getSelection();
        \\  try {
        \\    selection.collapse(text, offset);
        \\    selection.modify(alter, direction, "word");
        \\    assert_equals(selection.focusNode, text, `${direction} from ${offset} stays in its text`);
        \\    return [selection.anchorOffset, selection.focusOffset];
        \\  } finally {
        \\    selection.removeAllRanges();
        \\    p.remove();
        \\  }
        \\}
        \\
        \\const shapes = [
        \\  // [non-ASCII, ASCII of the same code-unit shape, offsets to start from]
        \\  ["héllo wörld end", "hello world end", [0, 2, 5, 6, 9, 11, 15]],
        \\  ["日本語 テキスト end", "abc defg end", [0, 1, 3, 4, 6, 8, 12]],
        \\  ["\u{1F600}\u{1F600} ab, cd end", "xxxx ab, cd end", [0, 2, 4, 5, 7, 9, 15]],
        \\];
        \\
        \\for (const [data, ascii, offsets] of shapes) {
        \\  for (const offset of offsets) {
        \\    for (const direction of ["forward", "backward"]) {
        \\      // Moves that would leave the text node: back from its start, forward
        \\      // through its last word.
        \\      if (direction === "backward" && offset === 0) continue;
        \\      if (direction === "forward" && offset >= ascii.length - 3) continue;
        \\      for (const alter of ["move", "extend"]) {
        \\        test(() => {
        \\          assert_array_equals(move(data, offset, alter, direction), move(ascii, offset, alter, direction));
        \\        }, `${alter} ${direction} by word from ${offset} in ${JSON.stringify(data)}`);
        \\      }
        \\    }
        \\  }
        \\}
        \\
        \\test(() => {
        \\  // Code units, not bytes: "héllo " is six code units and seven bytes.
        \\  assert_array_equals(move("héllo wörld end", 0, "move", "forward"), [6, 6]);
        \\  assert_array_equals(move("héllo wörld end", 11, "move", "backward"), [6, 6]);
        \\  assert_array_equals(move("\u{1F600}\u{1F600} ab end", 0, "move", "forward"), [5, 5]);
        \\  assert_array_equals(move("\u{1F600}\u{1F600} ab end", 7, "move", "backward"), [5, 5]);
        \\}, "word moves count UTF-16 code units");
        \\
        \\test(() => {
        \\  // An offset between the two halves of a surrogate pair is inside a word.
        \\  assert_array_equals(move("\u{1F600}\u{1F600} ab end", 1, "move", "forward"), [5, 5]);
        \\  assert_array_equals(move("\u{1F600}\u{1F600} ab end", 3, "move", "backward"), [0, 0]);
        \\  assert_array_equals(move("ab \u{1F600}\u{1F600} end", 4, "extend", "backward"), [4, 3]);
        \\  assert_array_equals(move("ab \u{1F600}\u{1F600} end", 6, "extend", "forward"), [6, 8]);
        \\}, "a word move from inside a surrogate pair leaves it whole");
    );
    const result = try page.evaluate("JSON.stringify([sd1Utf16Cases,sd1Utf16Failures])");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("[74,[]]", result);
}

test "sd1 retains all 74 unchanged sf2 UTF16 word movement cases" {
    try helpers.onFreshThread(utf16RegressionCases);
}

// Row129 Q32/Q33, Chrome156/Firefox158/Safari27, 2026-10-27.
// q32w and q32z have 62 identical Chrome/Firefox results. Forward uses
// Q15's next START convention: the next backward stop, never a WB3d
// interior. Every row states the measured macOS value and Crane's value.
const MixedSpaceCase = struct { text: []const u8, offset: u32, forward: bool, expected: u32 };
const mixed_space_cases = [_]MixedSpaceCase{
    .{ .text = "ab cd end", .offset = 0, .forward = true, .expected = 2 }, // q32w FIGURE SPACE: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32w FIGURE SPACE: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32w FIGURE SPACE: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 5, .forward = false, .expected = 3 }, // q32w FIGURE SPACE: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 0, .forward = true, .expected = 4 }, // q32w ASCII EM: raw macOS 2 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 2, .forward = true, .expected = 4 }, // q32w ASCII EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = true, .expected = 4 }, // q32w ASCII EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = false, .expected = 0 }, // q32w ASCII EM: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 4, .forward = false, .expected = 0 }, // q32w ASCII EM: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 6, .forward = false, .expected = 4 }, // q32w ASCII EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 0, .forward = true, .expected = 2 }, // q32w EM ASCII: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 2, .forward = true, .expected = 4 }, // q32w EM ASCII: raw macOS 6 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = true, .expected = 4 }, // q32w EM ASCII: raw macOS 6 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = false, .expected = 2 }, // q32w EM ASCII: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 4, .forward = false, .expected = 2 }, // q32w EM ASCII: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 6, .forward = false, .expected = 4 }, // q32w EM ASCII: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 0, .forward = true, .expected = 2 }, // q32w EM EM: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 2, .forward = true, .expected = 4 }, // q32w EM EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = true, .expected = 4 }, // q32w EM EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 3, .forward = false, .expected = 2 }, // q32w EM EM: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 4, .forward = false, .expected = 2 }, // q32w EM EM: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 6, .forward = false, .expected = 4 }, // q32w EM EM: raw macOS 4 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab\tcd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 9: raw macOS 5 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab\tcd end", .offset = 3, .forward = false, .expected = 0 }, // q32z 9: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 20: raw macOS 5 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 0 }, // q32z 20: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z a0: raw macOS 5 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 0 }, // q32z a0: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 1680: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 1680: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2000: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2000: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2001: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2001: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2002: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2002: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2003: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2003: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2004: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2004: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2005: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2005: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2006: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2006: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2007: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2007: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2008: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2008: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 2009: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 2009: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 200a: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 200a: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 6 }, // q32z 202f: raw macOS 5 -> Crane 6 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 0 }, // q32z 202f: raw macOS 0 -> Crane 0 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 205f: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 205f: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab　cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z 3000: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab　cd end", .offset = 3, .forward = false, .expected = 2 }, // q32z 3000: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 2, .forward = true, .expected = 3 }, // q32z a0+2003: raw macOS 4 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 4, .forward = false, .expected = 3 }, // q32z a0+2003: raw macOS 3 -> Crane 3 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 2, .forward = true, .expected = 4 }, // q32z 2003+a0: raw macOS 3 -> Crane 4 (Q15/Q32/Q33).
    .{ .text = "ab  cd end", .offset = 4, .forward = false, .expected = 2 }, // q32z 2003+a0: raw macOS 2 -> Crane 2 (Q15/Q32/Q33).
};

fn mixedSpaceCase(index: usize) !void {
    const case = mixed_space_cases[index];
    const page = try helpers.Page.open();
    defer page.close();
    const encoded_text = try std.json.Stringify.valueAlloc(std.testing.allocator, case.text, .{});
    defer std.testing.allocator.free(encoded_text);
    const source = try std.fmt.allocPrint(std.testing.allocator, "const host=document.body.appendChild(document.createElement('div'));host.contentEditable='true';host.textContent={s};" ++
        "globalThis.sd1Q32Node=host.firstChild;globalThis.sd1Q32Selection=getSelection();sd1Q32Selection.collapse(sd1Q32Node,{d});sd1Q32Selection.modify('move','{s}','word');", .{ encoded_text, case.offset, if (case.forward) "forward" else "backward" });
    defer std.testing.allocator.free(source);
    try page.run(source);
    const result = try page.evaluate("JSON.stringify([sd1Q32Selection.focusNode===sd1Q32Node,sd1Q32Selection.focusOffset])");
    defer std.testing.allocator.free(result);
    const expected = try std.fmt.allocPrint(std.testing.allocator, "[true,{d}]", .{case.expected});
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, result);
}

fn mixedSpaceCaseRunner(comptime index: usize) type {
    return struct {
        fn run() !void {
            try mixedSpaceCase(index);
        }
    };
}

test "sd1 Q32 q32w FIGURE SPACE forward from 0" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(0).run);
}

test "sd1 Q32 q32w FIGURE SPACE forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(1).run);
}

test "sd1 Q32 q32w FIGURE SPACE backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(2).run);
}

test "sd1 Q32 q32w FIGURE SPACE backward from 5" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(3).run);
}

test "sd1 Q32 q32w ASCII EM forward from 0" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(4).run);
}

test "sd1 Q32 q32w ASCII EM forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(5).run);
}

test "sd1 Q32 q32w ASCII EM forward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(6).run);
}

test "sd1 Q32 q32w ASCII EM backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(7).run);
}

test "sd1 Q32 q32w ASCII EM backward from 4" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(8).run);
}

test "sd1 Q32 q32w ASCII EM backward from 6" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(9).run);
}

test "sd1 Q32 q32w EM ASCII forward from 0" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(10).run);
}

test "sd1 Q32 q32w EM ASCII forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(11).run);
}

test "sd1 Q32 q32w EM ASCII forward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(12).run);
}

test "sd1 Q32 q32w EM ASCII backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(13).run);
}

test "sd1 Q32 q32w EM ASCII backward from 4" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(14).run);
}

test "sd1 Q32 q32w EM ASCII backward from 6" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(15).run);
}

test "sd1 Q32 q32w EM EM forward from 0" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(16).run);
}

test "sd1 Q32 q32w EM EM forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(17).run);
}

test "sd1 Q32 q32w EM EM forward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(18).run);
}

test "sd1 Q32 q32w EM EM backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(19).run);
}

test "sd1 Q32 q32w EM EM backward from 4" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(20).run);
}

test "sd1 Q32 q32w EM EM backward from 6" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(21).run);
}

test "sd1 Q32 q32z 9 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(22).run);
}

test "sd1 Q32 q32z 9 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(23).run);
}

test "sd1 Q32 q32z 20 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(24).run);
}

test "sd1 Q32 q32z 20 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(25).run);
}

test "sd1 Q32 q32z a0 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(26).run);
}

test "sd1 Q32 q32z a0 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(27).run);
}

test "sd1 Q32 q32z 1680 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(28).run);
}

test "sd1 Q32 q32z 1680 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(29).run);
}

test "sd1 Q32 q32z 2000 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(30).run);
}

test "sd1 Q32 q32z 2000 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(31).run);
}

test "sd1 Q32 q32z 2001 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(32).run);
}

test "sd1 Q32 q32z 2001 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(33).run);
}

test "sd1 Q32 q32z 2002 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(34).run);
}

test "sd1 Q32 q32z 2002 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(35).run);
}

test "sd1 Q32 q32z 2003 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(36).run);
}

test "sd1 Q32 q32z 2003 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(37).run);
}

test "sd1 Q32 q32z 2004 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(38).run);
}

test "sd1 Q32 q32z 2004 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(39).run);
}

test "sd1 Q32 q32z 2005 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(40).run);
}

test "sd1 Q32 q32z 2005 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(41).run);
}

test "sd1 Q32 q32z 2006 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(42).run);
}

test "sd1 Q32 q32z 2006 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(43).run);
}

test "sd1 Q32 q32z 2007 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(44).run);
}

test "sd1 Q32 q32z 2007 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(45).run);
}

test "sd1 Q32 q32z 2008 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(46).run);
}

test "sd1 Q32 q32z 2008 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(47).run);
}

test "sd1 Q32 q32z 2009 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(48).run);
}

test "sd1 Q32 q32z 2009 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(49).run);
}

test "sd1 Q32 q32z 200a forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(50).run);
}

test "sd1 Q32 q32z 200a backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(51).run);
}

test "sd1 Q32 q32z 202f forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(52).run);
}

test "sd1 Q32 q32z 202f backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(53).run);
}

test "sd1 Q32 q32z 205f forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(54).run);
}

test "sd1 Q32 q32z 205f backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(55).run);
}

test "sd1 Q32 q32z 3000 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(56).run);
}

test "sd1 Q32 q32z 3000 backward from 3" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(57).run);
}

test "sd1 Q32 q32z a0+2003 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(58).run);
}

test "sd1 Q32 q32z a0+2003 backward from 4" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(59).run);
}

test "sd1 Q32 q32z 2003+a0 forward from 2" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(60).run);
}

test "sd1 Q32 q32z 2003+a0 backward from 4" {
    try helpers.onFreshThread(mixedSpaceCaseRunner(61).run);
}
