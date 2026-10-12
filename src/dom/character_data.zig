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
//! lint-impls: hook for CharacterData
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Steps = struct {
    /// `node`'s data, borrowed (see above), or null when `node` has no
    /// CharacterData part.
    data_of: *const fn (node: *runtime.Instance) ?[]const u8,
};

// process-wide: an immutable function pointer CharacterData installs once at process start (crane.Process); it reads only the node it is given, so one serves every Browser and thread
var steps: ?Steps = null;

/// Called by CharacterData's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    process_start.assertInstalling();
    steps = s;
}

/// `node`'s data, borrowed until it next changes: copy what you keep. Null
/// when `node` is no CharacterData node (or CharacterData installed nothing).
pub fn dataOf(node: *runtime.Instance) ?[]const u8 {
    const s = steps orelse return null;
    return s.data_of(node);
}
