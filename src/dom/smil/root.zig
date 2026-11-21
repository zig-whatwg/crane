//! SVG animation elements' timing model (SVG Animations 2, SMIL Animation):
//! time values, the timing attributes' grammars, one animation element's
//! intervals and events, and an SVG document fragment's timeline.
//!
//! The pure model (time, parse, timed_element, time_container) touches no
//! node; `document_animations` connects it to the DOM: the animation
//! elements and outermost svg elements of a document, the rendering step
//! that moves their timelines, the TimeEvents, and the animated values the
//! SVG DOM's animVal reads.
pub const time = @import("time.zig");
pub const parse = @import("parse.zig");
pub const timed_element = @import("timed_element.zig");
pub const time_container = @import("time_container.zig");
pub const document_animations = @import("document_animations.zig");

pub const Time = time.Time;
pub const Interval = time.Interval;
pub const TimedElement = timed_element.TimedElement;
pub const TimeContainer = time_container.TimeContainer;
