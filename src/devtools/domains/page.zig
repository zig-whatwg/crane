//! The Page domain on page sessions: frames, navigation, lifecycle events, scripts on new documents, isolated worlds, dialogs (design 3.3).
//!
//! TODO(lane cdph): the handlers. Until then every Page command answers
//! "'Page.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
