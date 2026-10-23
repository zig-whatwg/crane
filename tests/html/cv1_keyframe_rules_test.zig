//! CSS Animations 1 §§3, 6.2–6.3: keyframe storage and live CSSOM edits.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn check(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, failure: *?anyerror) void {
            exercise(want) catch |err| {
                failure.* = err;
            };
        }
        fn exercise(want: []const u8) !void {
            const page = try helpers.Page.open();
            defer page.close();
            const actual = try page.evaluate(source);
            defer std.testing.allocator.free(actual);
            try std.testing.expectEqualStrings(want, actual);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &failure });
    thread.join();
    if (failure) |err| return err;
}

test "keyframes expose indexed live rules through the generated CSSRule chain" {
    try check(
        \\const sheet = new CSSStyleSheet();
        \\sheet.replaceSync('@keyframes "fade" { from {opacity:0} to {opacity:1} }');
        \\const rule = sheet.cssRules[0];
        \\if (!rule) 'missing rule'; else {
        \\ const child = rule[0], style = child.style;
        \\ JSON.stringify([rule instanceof CSSKeyframesRule, child instanceof CSSKeyframeRule,
        \\   rule.name, rule.type, child.type, rule.length, rule.cssRules.length,
        \\   child === rule.cssRules[0], rule[2] === undefined,
        \\   child.parentRule === rule, child.parentStyleSheet === sheet,
        \\   style.parentRule === child, style === child.style, child.keyText, child.cssText]);
        \\}
    , "[true,true,\"fade\",7,8,2,2,true,true,true,true,true,true,\"0%\",\"0% { opacity: 0; }\"]");
}

test "keyframe matching preserves selector order and removes only the last exact match" {
    try check(
        \\const sheet = new CSSStyleSheet();
        \\sheet.replaceSync('@keyframes a { 25%,75% {top:1px} 25%,75% {top:2px} 75%,25% {top:3px} }');
        \\const rule = sheet.cssRules[0];
        \\if (!rule) 'missing rule'; else {
        \\ const removed = rule.findRule('25%, 75%'), kept = rule.findRule('75%,25%');
        \\ const before = [removed.style.top, kept.style.top, rule.findRule('75%') === null];
        \\ rule.deleteRule('25%,75%');
        \\ rule.appendRule('to {top:4px}');
        \\ rule.appendRule('from {top:5px} to {top:6px}');
        \\ let error = ''; try { kept.keyText = 'invalid'; } catch(e) { error = e.name; }
        \\ const unchanged = kept.keyText === '75%, 25%';
        \\ kept.keyText = 'FROM, .5%, TO';
        \\ rule.name = 'initial';
        \\ JSON.stringify([before,rule.length,rule.findRule('25%,75%').style.top,
        \\   removed.parentRule === null,removed.parentStyleSheet === null,removed.style.top,
        \\   rule.findRule('to').style.top,error,unchanged,kept.keyText,rule.name,rule.cssText.includes('"initial"')]);
        \\}
    , "[[\"2px\",\"3px\",true],3,\"1px\",true,true,\"2px\",\"4px\",\"\",true,\"0%, 0.5%, 100%\",\"initial\",true]");
}

test "keyframe declarations share restrictions across parsing and every CSSOM setter" {
    try check(
        \\const sheet = new CSSStyleSheet();
        \\sheet.replaceSync('@keyframes a { from {top:1px!important;left:2px;animation-duration:1s;animation-timing-function:ease} }');
        \\const rule = sheet.cssRules[0];
        \\if (!rule) 'missing rule'; else {
        \\ const child = rule[0], style = child.style;
        \\ const before = [style.top,style.left,style.animationDuration,style.animationTimingFunction];
        \\ style.setProperty('left','3px','important'); style.animationDuration = '2s';
        \\ const after = [style.left,style.animationDuration];
        \\ child.style = 'bottom:4px;right:5px!important;animation:foo 1s;animation-timing-function:linear';
        \\ JSON.stringify([before,after,style.cssText,style === child.style,style.parentRule === child]);
        \\}
    , "[[\"\",\"2px\",\"\",\"ease\"],[\"2px\",\"\"],\"bottom: 4px; animation-timing-function: linear;\",true,true]");
}

test "keyframe rule model parsing releases every partially constructed child" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, modelAllocationFailure, .{});
}

fn modelAllocationFailure(allocator: std.mem.Allocator) !void {
    const dom = @import("dom");
    const css = dom.style.css;
    var parsed = try css.rules.parseStyleSheetContents(allocator, "@keyframes \"initial\" { from,entry -20% {opacity:0} invalid {top:2px} to {opacity:1} }");
    defer parsed.deinit();
    const model = (try dom.style.rules.build(.{ .parse = .{ .allocator = allocator } }, &parsed.items[0], .top)).?;
    defer model.unref();
    try std.testing.expectEqual(@as(usize, 2), model.children().?.items.len);
    const serialized = try model.serialize(allocator);
    defer allocator.free(serialized);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "\"initial\"") != null);
}
