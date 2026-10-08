//! HTML script preparation's temporary parser state on an early return.
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element

const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

test "empty parser script preparation restores force async before returning" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const element = try interfaces.HTMLScriptElement.init(allocator, &ctx_data);
    defer interfaces.HTMLScriptElement.deinit(element);

    // Never dereferenced: an empty script returns at preparation step 6.
    var parser_document: runtime.Instance = undefined;
    const state = html.script_element.of(element).?;
    state.parser_document = &parser_document;
    state.force_async = false;

    try std.testing.expect(!try html.script_execution.prepareScriptElement(allocator, element));
    try std.testing.expect(state.parser_document == null);
    try std.testing.expect(state.force_async);
    try std.testing.expect(!state.already_started);
}

test "failed parser preparation with explicit async does not restore force async" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const element = try interfaces.HTMLScriptElement.init(allocator, &ctx_data);
    defer interfaces.HTMLScriptElement.deinit(element);
    try interfaces.HTMLScriptElement.set_async(element, true);

    var parser_document: runtime.Instance = undefined;
    const state = html.script_element.of(element).?;
    state.parser_document = &parser_document;
    state.force_async = false;

    try std.testing.expect(!try html.script_execution.prepareScriptElement(allocator, element));
    try std.testing.expect(state.parser_document == null);
    try std.testing.expect(!state.force_async);
    try std.testing.expect(!state.already_started);
}

test "the end leaves an unready deferred head ahead of ready later scripts" {
    interfaces.process_hooks.startHooksForTest();
    const allocator = std.testing.allocator;
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const document = try interfaces.Document.init(allocator, &ctx_data);
    defer interfaces.Document.deinit(document);
    const first = try interfaces.HTMLScriptElement.init(allocator, &ctx_data);
    defer interfaces.HTMLScriptElement.deinit(first);
    const second = try interfaces.HTMLScriptElement.init(allocator, &ctx_data);
    defer interfaces.HTMLScriptElement.deinit(second);
    const lists = @import("dom").document_scripts.of(document).?;
    try lists.addWhenParsingFinished(first);
    try lists.addWhenParsingFinished(second);
    html.script_element.of(second).?.ready_to_be_parser_executed = true;

    html.script_execution.executeScriptsWhenParsingFinished(allocator, document);
    try std.testing.expectEqual(@as(usize, 2), lists.scripts_to_execute_when_parsing_finished.items.len);
    try std.testing.expect(lists.scripts_to_execute_when_parsing_finished.items[0] == first);
    try std.testing.expect(lists.scripts_to_execute_when_parsing_finished.items[1] == second);

    // Once the head becomes ready, both entries may leave in their order.
    html.script_element.of(first).?.ready_to_be_parser_executed = true;
    html.script_execution.executeScriptsWhenParsingFinished(allocator, document);
    try std.testing.expectEqual(@as(usize, 0), lists.scripts_to_execute_when_parsing_finished.items.len);
}
