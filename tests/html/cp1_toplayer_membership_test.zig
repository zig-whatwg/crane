//! Q65: actual top-layer membership includes modal dialogs, not just popovers.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const input = @import("html").user_input;

const Mode = enum { modal, non_modal, popover };
const State = enum { focus_within, hover, active };

fn exercise(comptime mode: Mode, comptime state: State) !void {
    const page = try helpers.Page.open();
    defer page.close();
    const markup = if (mode == .popover)
        "<div id=outer><div id=layer popover=manual><button id=target>Target</button></div></div>"
    else
        "<div id=outer><dialog id=layer><button id=target>Target</button></dialog></div>";
    const open = switch (mode) {
        .modal => "cp1Layer.showModal();",
        .non_modal => "cp1Layer.show();",
        .popover => "cp1Layer.showPopover();",
    };
    try page.run("document.body.innerHTML = '" ++ markup ++ "';" ++
        \\globalThis.cp1Layer = document.getElementById('layer');
        \\globalThis.cp1Target = document.getElementById('target');
        \\globalThis.cp1Outer = document.getElementById('outer');
    ++ open);
    const expected = if (mode == .non_modal) "true,true,true,true" else "true,true,false,false";
    if (state == .focus_within) {
        try page.run(
            \\cp1Target.focus();
            \\if (!cp1Target.matches(':focus')) throw new Error('target focus');
            \\const got = [cp1Target, cp1Layer, cp1Outer, document.body].map(e => e.matches(':focus-within')).join(',');
        ++ "if (got !== '" ++ expected ++ "') throw new Error('focus-within boundary: ' + got);");
    } else {
        const document = page.browser.current_context.?.document_instance.?;
        const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
        var pointer: input.Pointer = .{};
        input.pointerMove(&pointer, target, .{});
        if (state == .hover) {
            try page.run(
                \\const got = [cp1Target, cp1Layer, cp1Outer, document.body].map(e => e.matches(':hover')).join(',');
            ++ "if (got !== '" ++ expected ++ "') throw new Error('hover boundary: ' + got);");
        } else {
            try page.run(
                \\globalThis.cp1Active = null;
                \\cp1Target.addEventListener('mousedown', () => {
                \\  cp1Active = [cp1Target, cp1Layer, cp1Outer, document.body].map(e => e.matches(':active')).join(',');
                \\}, {once: true});
            );
            input.pointerDown(&pointer, 0, .{});
            input.pointerUp(&pointer, 0, .{});
            try page.run("if (cp1Active !== '" ++ expected ++ "') throw new Error('active boundary: ' + cp1Active);");
        }
    }
}

fn check(comptime mode: Mode, comptime state: State) !void {
    const Case = struct {
        fn run() !void {
            try exercise(mode, state);
        }
    };
    errdefer std.debug.print("CP1_MEMBERSHIP mode={s} state={s} FAIL\n", .{ @tagName(mode), @tagName(state) });
    try helpers.onFreshThread(Case.run);
    std.debug.print("CP1_MEMBERSHIP mode={s} state={s} PASS\n", .{ @tagName(mode), @tagName(state) });
}

test "modal dialog bounds focus-within" {
    try check(.modal, .focus_within);
}
test "modal dialog bounds hover" {
    try check(.modal, .hover);
}
test "modal dialog bounds active" {
    try check(.modal, .active);
}
// Preservation: non-modal dialogs never enter the top layer.
test "non-modal dialog preserves focus-within ancestors" {
    try check(.non_modal, .focus_within);
}
test "non-modal dialog preserves hover ancestors" {
    try check(.non_modal, .hover);
}
test "non-modal dialog preserves active ancestors" {
    try check(.non_modal, .active);
}
// Preservation: Q8 already gives popovers an inclusive boundary.
test "popover preserves its focus-within boundary" {
    try check(.popover, .focus_within);
}
test "popover preserves its hover boundary" {
    try check(.popover, .hover);
}
test "popover preserves its active boundary" {
    try check(.popover, .active);
}
