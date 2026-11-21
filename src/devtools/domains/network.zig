//! The Network domain on page sessions: fetch instrumentation (design 3.9).
//!
//! TODO(lane cdpt): the handlers. Until then every Network command answers
//! "'Network.<command>' wasn't found" (src/devtools/dispatch.zig). The handler
//! interface is src/devtools/README.md's.

const PageSession = @import("../page_session.zig").PageSession;
const protocol = @import("../protocol/root.zig");

/// Per-session state of the domain.
pub const State = struct {};
