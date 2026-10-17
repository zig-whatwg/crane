//! A CharacterData node's data, read in place by the tree's own algorithms.
//!
//! The IDL `data` getter answers a new DOMString that its caller frees: right
//! for script, which gets a copy of the string anyway. DOM's own reads only
//! look at the bytes - Node's textContent and nodeValue getters and the
//! "descendant text content" they concatenate (DOM 4.4), isEqualNode's data
//! comparison, an option's text and a textarea's child text content (HTML) -
//! and a copy per Text node would put an allocation on each of those paths.
//! They may not reach into CharacterData's impl (AGENTS.md "The impls
//! boundary"), so CharacterData installs the read here, the shape of
//! `blob_bytes.zig`. WebKit's `CharacterData::data()` returns its String by
//! reference for the same reason (Source/WebCore/dom/CharacterData.h).
//!
//! The bytes are BORROWED: valid until the node's data next changes ("replace
//! data", DOM 4.10) or the node is freed. A caller copies what it keeps.
//!
//! Spec: https://dom.spec.whatwg.org/#interface-characterdata
//!
//! lint-impls: hook for CharacterData, ProcessingInstruction
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Steps = struct {
    /// `node`'s data, borrowed (see above), or null when `node` has no
    /// CharacterData part.
    data_of: *const fn (node: *runtime.Instance) ?[]const u8,
};

pub const ProcessingInstructionSteps = struct {
    /// Replace-data step 12: update the PI's attribute map from its new data.
    data_changed: *const fn (*runtime.Instance) void,
};

const Hooks = struct {
    character_data: ?Steps = null,
    processing_instruction: ?ProcessingInstructionSteps = null,
};
// process-wide: immutable algorithms set by install (CharacterData) and installProcessingInstruction at process start; each reads only the supplied node, with no instance state
var steps: Hooks = .{};

/// Called by CharacterData's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    process_start.assertInstalling();
    steps.character_data = s;
}

/// `node`'s data, borrowed until it next changes: copy what you keep. Null
/// when `node` is no CharacterData node (or CharacterData installed nothing).
pub fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const s = steps.character_data orelse return null;
    return s.data_of(node);
}

/// Called by ProcessingInstruction's installHooks, once at process start.
pub fn installProcessingInstruction(s: ProcessingInstructionSteps) void {
    process_start.assertInstalling();
    steps.processing_instruction = s;
}

/// Only CharacterData's PI branch calls this; ordinary Text mutations never
/// enter the PI owner or parse any attributes.
pub fn processingInstructionDataChanged(node: *runtime.Instance) void {
    const s = steps.processing_instruction orelse return;
    s.data_changed(node);
}
