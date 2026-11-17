//! Lane mp1: code that nothing reaches is gone (tmp/plans/feature-queue.md,
//! "DEAD CODE", found by lane wb1 when the WithBase types went).
//!
//! Each declaration pinned here lost its last caller earlier, and each went
//! in a commit of its own whose message carries the grep that shows no
//! caller:
//!
//! 1. The XPath tokenizer and parser in src/dom/xpath: the XPathExpression
//!    impl has a parser of its own and reads only the grammar's types
//!    (dom.xpath.ast), which stay.
//! 2. src/dom/fast_path.zig, a querySelector selector classifier: only its
//!    own test called it. Selector matching uses src/selector/fast_paths.zig.
//! 3. infra.BloomFilter: only ElementWithBase used it. The selector
//!    engine's AncestorBloomFilter stays.
//! 4. src/dom/attribute_algorithms.zig (handleAttributeChanges and the
//!    algorithms around it, over the generated types as values): its only
//!    caller was the deleted legacy token list. With it goes the legacy
//!    `queueMutationRecord` over `*Node` and `*NodeList`, which only
//!    handleAttributeChanges called; the live record queue is
//!    queueAttributeMutationRecord and queueTreeMutationRecord.

const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const infra = @import("infra");

test "the XPath tokenizer and parser that nothing calls are gone; the grammar's types stay" {
    try testing.expect(!@hasDecl(dom.xpath, "tokenizer"));
    try testing.expect(!@hasDecl(dom.xpath, "parser"));
    // XPathExpression's impl reads these.
    try testing.expect(@hasDecl(dom.xpath, "ast"));
}

test "the querySelector fast-path classifier that only its own test called is gone" {
    try testing.expect(!@hasDecl(dom, "fast_path"));
}

test "infra's BloomFilter, which only ElementWithBase used, is gone; the ancestor filter stays" {
    try testing.expect(!@hasDecl(infra, "BloomFilter"));
    try testing.expect(!@hasDecl(infra, "bloom_filter"));
    // The selector engine's (src/selector/context.zig).
    try testing.expect(@hasDecl(infra, "AncestorBloomFilter"));
}

test "the legacy attribute algorithms and the record queue only they called are gone" {
    try testing.expect(!@hasDecl(dom, "attribute_algorithms"));
    try testing.expect(!@hasDecl(dom.mutation_observer_algorithms, "queueMutationRecord"));
    // The record queues every mutation uses stay.
    try testing.expect(@hasDecl(dom.mutation_observer_algorithms, "queueAttributeMutationRecord"));
    try testing.expect(@hasDecl(dom.mutation_observer_algorithms, "queueTreeMutationRecord"));
}
