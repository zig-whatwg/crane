//! The Emulation domain on page sessions: per-tab overrides of the platform's answers (design 3.8).
//!
//! TODO(lane cdph): the handlers. Until then every Emulation command answers
//! "'Emulation.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
