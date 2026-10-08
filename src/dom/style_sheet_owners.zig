//! What an element that owns a style sheet - a `link` or a `style` element -
//! owes its node document, and what the HTML parser tells those elements.
//!
//! HTML 4.2.4.3 and 4.2.6: while a link element's style sheet, or a style
//! element's, loads with its critical subresources (its @import rules), the
//! element delays its node document's load event. The loads are the
//! elements' state, and Document, whose "the end" waits on them at step 8,
//! asks here - the shape of `content_navigables.zig`, which does the same
//! for frames. When a load ends, its owner calls
//! `document_lifecycle.loadDelayMayHaveEnded`, as a frame does.
//!
//! HTML 4.2.6: the user agent runs "update a style block" when the element
//! "is popped off the stack of open elements of an HTML parser or XML
//! parser", and on becoming connected or disconnected only when it is not on
//! that stack. The parser drivers say when they create a style element and
//! when they pop it; until then its insertion and children changed steps
//! leave it alone, and a parsed `<style>` makes one style sheet, not one for
//! its insertion and another for its text (Blink's StyleElement
//! created_by_parser_ and FinishParsingChildren).
//!
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-link-element
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#update-a-style-block
//!
//! lint-impls: hook for HTMLLinkElement, HTMLStyleElement
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

/// Queries over the owners' live loads: the document's load-event delay
/// and its own script-blocking style sheet set.
pub const LoadDelay = struct {
    delays: *const fn (document: *runtime.Instance) bool,
    blocks_scripts: *const fn (document: *runtime.Instance) bool,
};

/// What the style element does when the parser creates and pops it.
pub const ParserSteps = struct {
    /// The parser created `element`, a style element, and will pop it.
    created: *const fn (element: *runtime.Instance) void,
    /// The parser popped `element` off its stack of open elements, its
    /// text inserted.
    popped: *const fn (element: *runtime.Instance) void,
    /// The parser made a link, with all token attributes installed.
    link_created: ?*const fn (element: *runtime.Instance) void = null,
};

var load_delay: ?LoadDelay = null;
var parser_steps: ?ParserSteps = null;

/// Called by the elements that load style sheets. Idempotent.
pub fn installLoadDelay(delay: LoadDelay) void {
    process_start.assertInstalling();
    load_delay = delay;
}

/// Called by the style element. Idempotent.
pub fn installParserSteps(steps: ParserSteps) void {
    process_start.assertInstalling();
    const link_created = if (parser_steps) |old| old.link_created else null;
    parser_steps = steps;
    if (parser_steps.?.link_created == null) parser_steps.?.link_created = link_created;
}

/// Called by the link element. Keeps the style element's parser hooks.
pub fn installLinkParserSteps(created: *const fn (element: *runtime.Instance) void) void {
    process_start.assertInstalling();
    if (parser_steps == null) parser_steps = .{ .created = &ignoreParserStep, .popped = &ignoreParserStep };
    parser_steps.?.link_created = created;
}

fn ignoreParserStep(element: *runtime.Instance) void {
    _ = element;
}

/// "The end" step 8: whether a style sheet an element in `document` loads
/// still delays its load event.
pub fn delaysLoadEvent(document: *runtime.Instance) bool {
    const delay = load_delay orelse return false;
    return delay.delays(document);
}

/// Whether `document`'s own script-blocking style sheet set is nonempty.
/// Document additionally checks its immediate container document's set.
pub fn blocksScripts(document: *runtime.Instance) bool {
    const delay = load_delay orelse return false;
    return delay.blocks_scripts(document);
}

/// The HTML parser created `element`, a style or link element in the HTML
/// namespace, and appended all token attributes before connection.
pub fn createdByParser(element: *runtime.Instance) void {
    const steps = parser_steps orelse return;
    steps.created(element);
    if (steps.link_created) |created| created(element);
}

/// The HTML parser popped `element`, a style element it created, off its
/// stack of open elements.
pub fn poppedByParser(element: *runtime.Instance) void {
    const steps = parser_steps orelse return;
    steps.popped(element);
}

test "without installed implementations nothing delays a load event, and the parser's calls do nothing" {
    const saved_delay = load_delay;
    const saved_steps = parser_steps;
    defer {
        load_delay = saved_delay;
        parser_steps = saved_steps;
    }
    load_delay = null;
    parser_steps = null;
    // Never dereferenced: with no implementation nothing reads it.
    var node: runtime.Instance = undefined;
    try @import("std").testing.expect(!delaysLoadEvent(&node));
    try @import("std").testing.expect(!blocksScripts(&node));
    createdByParser(&node);
    poppedByParser(&node);
}

var test_popped: usize = 0;

fn testDelays(document: *runtime.Instance) bool {
    _ = document;
    return true;
}

fn testCreated(element: *runtime.Instance) void {
    _ = element;
}

fn testPopped(element: *runtime.Instance) void {
    _ = element;
    test_popped += 1;
}

test "the installed implementations answer" {
    const saved_delay = load_delay;
    const saved_steps = parser_steps;
    defer {
        load_delay = saved_delay;
        parser_steps = saved_steps;
    }
    installLoadDelay(.{ .delays = &testDelays, .blocks_scripts = &testDelays });
    installParserSteps(.{ .created = &testCreated, .popped = &testPopped });
    var node: runtime.Instance = undefined;
    try @import("std").testing.expect(delaysLoadEvent(&node));
    try @import("std").testing.expect(blocksScripts(&node));
    test_popped = 0;
    poppedByParser(&node);
    try @import("std").testing.expectEqual(@as(usize, 1), test_popped);
}
