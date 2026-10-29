//! Implementation for DocumentTimeline interface (Web Animations 1 4.3.1,
//! 6.3): a timeline whose current time follows its document's animation
//! frames, offset by its origin time. The timeline model is
//! AnimationTimeline's (its construction chain makes it).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-documenttimeline-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const animations = @import("dom").animations;
const DocumentTimeline = interfaces.DocumentTimeline;

pub const State = DocumentTimeline.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Constructor (6.3): a new DocumentTimeline associated with "the Document
/// associated with the Window that is the current global object", with the
/// origin time `options.originTime` (ms relative to its time origin).
pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(dictionaries.DocumentTimelineOptions)) !*runtime.Instance {
    const instance = try DocumentTimeline.init(ctx.allocator, ctx);
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const timeline = animations.hooks.timelineOf(instance) orelse return error.InvalidStateError;
    if (animations.registry.documentOfRealm(engine.currentRealm() orelse ctx)) |document| {
        timeline.document = animations.model.Link.to(document);
    }
    const given = options.getOrDefault(.{});
    timeline.origin_time = given.originTime orelse 0;
    return instance;
}
