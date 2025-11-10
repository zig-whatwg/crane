//! WHATWG DOM Standard Implementation
//!
//! Spec: https://dom.spec.whatwg.org/

const std = @import("std");

// Dependencies
pub const infra = @import("infra");
pub const webidl = @import("webidl");

// WebIDL generated interfaces
pub const AbortSignal = @import("abort_signal").AbortSignal;
pub const EventTarget = @import("event_target").EventTarget;
pub const Event = @import("event").Event;
pub const Node = @import("node").Node;
pub const NodeList = @import("node_list").NodeList;
pub const Element = @import("element").Element;
pub const CharacterData = @import("character_data").CharacterData;
pub const Text = @import("text").Text;
pub const Comment = @import("comment").Comment;
pub const DocumentFragment = @import("document_fragment").DocumentFragment;
pub const DOMTokenList = @import("dom_token_list").DOMTokenList;
pub const Attr = @import("attr").Attr;

test {
    std.testing.refAllDecls(@This());
}
