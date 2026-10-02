//! A script element's processing-model state, and the hook that reaches it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
//!
//! The state is HTML's (parser document, preparation-time document, force
//! async, from an external file, ready to be parser-executed, already
//! started, type, result). Its type lives in html/script_element.zig, where
//! both the HTMLScriptElement impl, which keeps one per element, and the
//! processing model in html/script_execution.zig can see it; the processing
//! model reaches an element's through `script_element.of`, which the impl
//! installs. These tests pin that the state the hook answers is the element's
//! own - the one its IDL members read - and that the state owns, and frees,
//! what it keeps.

const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");

const interfaces = html.interfaces;
const script_element = html.script_element;
const State = script_element.State;

const testing = std.testing;

test "a new script element state has the spec's initial values" {
    var state = State.init(testing.allocator);
    defer state.deinit();

    // "Initially, the parser document is null", "force async ... Initially,
    // script elements must have this flag set", and every other flag unset.
    try testing.expect(state.parser_document == null);
    try testing.expect(state.preparation_time_document == null);
    try testing.expect(state.force_async);
    try testing.expect(!state.from_external_file);
    try testing.expect(!state.ready_to_be_parser_executed);
    try testing.expect(!state.already_started);
    try testing.expect(!state.delaying_the_load_event);
    try testing.expectEqual(script_element.ScriptType.null, state.script_type);
    try testing.expect(state.result == .uninitialized);
    try testing.expect(state.cached_source_text == null);
    try testing.expect(state.script_url == null);
}

test "the state owns the source text and script URL it keeps, and frees them" {
    var state = State.init(testing.allocator);
    defer state.deinit();

    try state.cacheSourceText("first");
    // A second cache replaces the first, which is freed (testing.allocator
    // fails the test on a leak).
    try state.cacheSourceText("second");
    try testing.expectEqualStrings("second", state.cached_source_text.?);

    const first_url = try state.setScriptUrl("https://example.test/a.js");
    try testing.expectEqualStrings("https://example.test/a.js", first_url);
    const second_url = try state.setScriptUrl("https://example.test/b.js");
    // The element's own copy - the one a script result may point at.
    try testing.expect(second_url.ptr == state.script_url.?.ptr);
    try testing.expectEqualStrings("https://example.test/b.js", state.script_url.?);
}

test "a module script result holds html's module script, typed" {
    const Arm = @FieldType(script_element.ScriptResult, "module_script");
    try testing.expect(std.mem.endsWith(u8, @typeName(Arm), "module_script.ModuleScript"));
    try testing.expect(@typeInfo(Arm) == .pointer);
}

test "an HTML script element's state is reached through script_element.of, and is the one its IDL members read" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const element = try interfaces.HTMLScriptElement.init(allocator, ctx);
    defer interfaces.HTMLScriptElement.deinit(element);

    const state = script_element.of(element) orelse return error.NoScriptElementState;
    // "force async" is set on a new element, and the async getter returns it.
    try testing.expect(state.force_async);
    try testing.expect(try interfaces.HTMLScriptElement.get_async(element));

    // The same state: clearing it through the hook is what the getter sees.
    state.force_async = false;
    try testing.expect(!try interfaces.HTMLScriptElement.get_async(element));

    // And the other way: the async setter's "unset force async" is seen
    // through the hook.
    state.force_async = true;
    try interfaces.HTMLScriptElement.set_async(element, false);
    try testing.expect(!state.force_async);
}

test "an element that is no HTML script element has no script element state" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    const allocator = testing.allocator;

    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    // Creating a script element installs the hook; a div is then asked.
    const script = try interfaces.HTMLScriptElement.init(allocator, ctx);
    defer interfaces.HTMLScriptElement.deinit(script);
    const div = try interfaces.HTMLDivElement.init(allocator, ctx);
    defer interfaces.HTMLDivElement.deinit(div);

    try testing.expect(script_element.of(script) != null);
    try testing.expect(script_element.of(div) == null);
}
