//! Selector parsing: Selectors 4 section 16's grammar over CSS Syntax 3
//! tokens (tokenizer.zig).
//!
//! Spec: https://drafts.csswg.org/selectors-4/#grammar (specs/w3c/
//! selectors-4.md, Editor's Draft of 18 September 2026) and CSS Syntax 3
//! 5.4.1 "parse something according to a CSS grammar": the whole input is
//! tokenized, blocks are matched ("[", "(" and functions, each closed by its
//! own closing token or by the end of the input - an unclosed construct is a
//! parse error, not a failure), and the grammar is matched against the
//! tokens.
//!
//! DOM declares no namespace prefixes; stylesheet callers supply a borrowed
//! namespace resolver. DOM's `*|E` and `|E` remain the namespace forms
//! that can be valid, and any named prefix is an undeclared one: the
//! selector is invalid (Selectors 4 3.9).
//!
//! Ownership: names and values are slices of the input as written, or - when
//! an escape had to be decoded or a name lowercased - of strings the
//! outermost SelectorList owns (`SelectorList.strings`). Either way the AST
//! lives no longer than the input and the list.

const std = @import("std");
const infra = @import("infra");
const Allocator = std.mem.Allocator;
const tokenizer_mod = @import("tokenizer.zig");
const Tokenizer = tokenizer_mod.Tokenizer;
const Token = tokenizer_mod.Token;
const AncestorHashes = infra.AncestorHashes;
const context = @import("context.zig");
const MatchResult = context.MatchResult;

// ============================================================================
// AST Node Types
// ============================================================================

/// A selector list: complex selectors, comma-separated in the source.
pub const SelectorList = struct {
    selectors: []ComplexSelector,
    allocator: Allocator,
    /// The decoded and lowercased strings the AST points into. Only the
    /// outermost list of a parse owns any; nested lists' are empty.
    strings: [][]u8 = &.{},

    /// Null for parsed/unique roots. Both immutable parent views point
    /// to their sole shared owner; the view is never separately destroyed.
    shared_owner: ?*@import("nesting.zig").SharedList = null,

    pub fn deinit(self: *SelectorList) void {
        std.debug.assert(self.shared_owner == null);
        self.deinitContents();
    }

    /// The single release dispatch for every initialized boxed list.
    /// Shared and unique ownership are disjoint by construction.
    pub fn releaseBoxed(self: *SelectorList) void {
        if (self.shared_owner) |owner| {
            owner.unref();
        } else {
            const allocator = self.allocator;
            self.deinit();
            allocator.destroy(self);
        }
    }

    /// Only the owner's zero-count path may destroy shared contents.
    pub fn deinitSharedContents(self: *SelectorList, owner: *@import("nesting.zig").SharedList) void {
        std.debug.assert(self.shared_owner == owner and owner.refs == 0);
        self.deinitContents();
    }

    fn deinitContents(self: *SelectorList) void {
        for (self.selectors) |*selector| {
            selector.deinit();
        }
        self.allocator.free(self.selectors);
        for (self.strings) |s| self.allocator.free(s);
        if (self.strings.len != 0) self.allocator.free(self.strings);
    }
};

/// CSS Specificity (a, b, c) tuple per Selectors Level 4
/// a = ID selectors count
/// b = class selectors + attribute selectors + pseudo-classes count
/// c = type selectors + pseudo-elements count
pub const Specificity = struct {
    id: u32 = 0, // a
    class: u32 = 0, // b
    element: u32 = 0, // c

    /// Compare two specificities
    /// Returns: .lt (less), .eq (equal), .gt (greater)
    pub fn compare(self: Specificity, other: Specificity) std.math.Order {
        if (self.id != other.id) return std.math.order(self.id, other.id);
        if (self.class != other.class) return std.math.order(self.class, other.class);
        return std.math.order(self.element, other.element);
    }

    /// Add two specificities together
    pub fn add(self: Specificity, other: Specificity) Specificity {
        return Specificity{
            .id = self.id + other.id,
            .class = self.class + other.class,
            .element = self.element + other.element,
        };
    }

    /// Return maximum of two specificities
    pub fn max(self: Specificity, other: Specificity) Specificity {
        return if (self.compare(other) == .gt) self else other;
    }
};

/// Backtracking analysis information for a complex selector.
///
/// Determines optimal restart points when matching fails, following
/// Firefox's Stylo computeBacktrackingInformation() approach.
pub const BacktrackingInfo = struct {
    /// Whether descendant combinators exist (enables descendant restart).
    has_descendant_combinator: bool = false,

    /// Whether sibling combinators exist (enables sibling restart).
    has_sibling_combinator: bool = false,

    /// Index of first descendant combinator (for restart position).
    /// null if no descendant combinator exists.
    first_descendant_index: ?usize = null,

    /// Index of first sibling combinator (for restart position).
    /// null if no sibling combinator exists.
    first_sibling_index: ?usize = null,

    /// Whether the selector can potentially benefit from ID fast-rejection.
    /// True if there's an ID selector in ancestor compounds.
    has_ancestor_id: bool = false,
};

/// Complex selector (combinator chain)
///
/// ## Storage Order: Right-to-Left (RTL)
///
/// Selectors are stored in **matching order** (right-to-left) for cache efficiency.
/// This matches Firefox's Stylo implementation.
///
/// Example: "div > p.active"
/// - `compound` = "p.active" (rightmost - subject element)
/// - `combinators` = [{Child, "div"}] (going toward ancestors)
///
/// For matching, iterate `combinators` forward:
/// 1. Match element against `compound`
/// 2. For each combinator pair, find ancestor/sibling matching the compound
pub const ComplexSelector = struct {
    /// The rightmost (subject) compound selector.
    /// This is what we match first against the target element.
    compound: CompoundSelector,

    /// Combinator chain going right-to-left (toward ancestors).
    /// Each pair is {combinator, compound} where compound is to the LEFT of combinator.
    combinators: []CombinatorPair,

    allocator: Allocator,

    /// A relative selector (Selectors 4 3.4, in :has()): anchored at an
    /// element by `initial_combinator`, the descendant combinator when none
    /// is written.
    is_relative: bool = false,

    /// For relative selectors, the initial combinator
    initial_combinator: ?Combinator = null,

    /// Precomputed hashes from ancestor selector components.
    /// Used for O(1) bloom filter rejection before tree traversal.
    ancestor_hashes: AncestorHashes = AncestorHashes.init(),

    /// Precomputed backtracking analysis for optimized failure recovery.
    backtracking: BacktrackingInfo = BacktrackingInfo{},

    pub fn deinit(self: *ComplexSelector) void {
        self.compound.deinit();
        for (self.combinators) |*pair| {
            pair.compound.deinit();
        }
        self.allocator.free(self.combinators);
    }

    /// Calculate specificity of this complex selector
    pub fn calculateSpecificity(self: *const ComplexSelector) Specificity {
        var spec = self.compound.calculateSpecificity();

        // Add specificity from all combinators
        for (self.combinators) |*pair| {
            spec = spec.add(pair.compound.calculateSpecificity());
        }

        return spec;
    }

    /// Compute ancestor hashes from the combinator chain.
    /// Call this after parsing to enable bloom filter fast-rejection.
    pub fn computeAncestorHashes(self: *ComplexSelector) void {
        self.ancestor_hashes = AncestorHashes.init();

        // Collect hashes from ancestor compounds (not the subject compound)
        for (self.combinators) |*pair| {
            self.collectHashesFromCompound(&pair.compound);
            if (self.ancestor_hashes.len >= 4) break; // Max 4 hashes
        }
    }

    /// Collect hashes from a compound selector's simple selectors.
    fn collectHashesFromCompound(self: *ComplexSelector, compound: *const CompoundSelector) void {
        for (compound.simple_selectors) |*simple| {
            switch (simple.*) {
                .Type => |type_sel| {
                    self.ancestor_hashes.addTagName(type_sel.tag_name);
                },
                .Id => |id_sel| {
                    self.ancestor_hashes.addId(id_sel.id);
                },
                .Class => |class_sel| {
                    self.ancestor_hashes.addClass(class_sel.class_name);
                },
                else => {},
            }
            if (self.ancestor_hashes.len >= 4) return;
        }
    }

    /// Compute backtracking information for optimized failure recovery.
    ///
    /// Analyzes the combinator chain to determine:
    /// - Which combinators allow descendant restart (space combinator)
    /// - Which combinators allow sibling restart (+ and ~ combinators)
    /// - Where restart should begin on failure
    ///
    /// This is similar to Firefox's computeBacktrackingInformation() in Stylo.
    pub fn computeBacktrackingInfo(self: *ComplexSelector) void {
        self.backtracking = BacktrackingInfo{};

        for (self.combinators, 0..) |*pair, i| {
            switch (pair.combinator) {
                .Descendant => {
                    self.backtracking.has_descendant_combinator = true;
                    if (self.backtracking.first_descendant_index == null) {
                        self.backtracking.first_descendant_index = i;
                    }
                },
                .NextSibling, .SubsequentSibling => {
                    self.backtracking.has_sibling_combinator = true;
                    if (self.backtracking.first_sibling_index == null) {
                        self.backtracking.first_sibling_index = i;
                    }
                },
                .Child => {
                    // Child combinator doesn't allow restart - must match exactly
                },
            }

            // Check for ID in ancestor compounds (for fast-rejection potential)
            for (pair.compound.simple_selectors) |*simple| {
                if (simple.* == .Id) {
                    self.backtracking.has_ancestor_id = true;
                    break;
                }
            }
        }
    }

    /// Determine what kind of retry is appropriate after a match failure.
    ///
    /// Returns the appropriate MatchResult hint based on where the failure occurred
    /// and what combinators are involved.
    pub fn getFailureRecovery(self: *const ComplexSelector, failed_at_index: usize) MatchResult {
        // If failure was at a descendant combinator, we can try other descendants
        if (failed_at_index < self.combinators.len) {
            const comb = self.combinators[failed_at_index].combinator;
            switch (comb) {
                .Descendant => return .not_matched_restart_descendant,
                .NextSibling, .SubsequentSibling => return .not_matched_restart_later_sibling,
                .Child => {
                    // Child combinator - check if there's a descendant combinator earlier
                    if (self.backtracking.first_descendant_index) |desc_idx| {
                        if (desc_idx < failed_at_index) {
                            return .not_matched_restart_descendant;
                        }
                    }
                    return .not_matched_globally;
                },
            }
        }

        // Failure at subject compound - check if we have restart options
        if (self.backtracking.has_descendant_combinator) {
            return .not_matched_restart_descendant;
        }
        if (self.backtracking.has_sibling_combinator) {
            return .not_matched_restart_later_sibling;
        }

        return .not_matched_globally;
    }
};

/// Combinator with associated compound selector
pub const CombinatorPair = struct {
    combinator: Combinator,
    compound: CompoundSelector,
};

/// Combinator types
pub const Combinator = enum {
    Descendant, // space (whitespace)
    Child, // >
    NextSibling, // +
    SubsequentSibling, // ~
};

/// Compound selector (multiple simple selectors for same element)
pub const CompoundSelector = struct {
    simple_selectors: []SimpleSelector,
    allocator: Allocator,
    /// Quirks Mode 4.1, "the :active and :hover quirk": a compound outside
    /// any functional pseudo-class's argument that uses :active or :hover
    /// and no type, attribute, ID or class selector, no other pseudo-class
    /// and no pseudo-element. In quirks mode it matches only elements that
    /// match :any-link. Decided here, so matching reads one flag.
    active_hover_quirk: bool = false,

    pub fn deinit(self: *CompoundSelector) void {
        for (self.simple_selectors) |*selector| {
            selector.deinit(self.allocator);
        }
        self.allocator.free(self.simple_selectors);
    }

    /// Calculate specificity of this compound selector
    pub fn calculateSpecificity(self: *const CompoundSelector) Specificity {
        var spec = Specificity{};

        for (self.simple_selectors) |*selector| {
            spec = spec.add(selector.calculateSpecificity());
        }

        return spec;
    }

    /// Whether the compound holds a pseudo-element (and so represents no
    /// element in the tree: querySelector and matches() never match it).
    pub fn hasPseudoElement(self: *const CompoundSelector) bool {
        for (self.simple_selectors) |*simple| if (simple.* == .PseudoElement) return true;
        return false;
    }
};

/// The namespace a type, universal or attribute selector accepts (Selectors
/// 4 5.3 and 6.4). With no prefix declared, a type selector without a prefix
/// accepts any namespace, and an attribute selector without one accepts only
/// no namespace.
pub const NamespaceConstraint = enum {
    /// `*|` - any namespace, or none.
    any,
    /// `|` - no namespace.
    none,
};

/// Simple selector (atomic selector)
pub const SimpleSelector = union(enum) {
    /// `*`, `*|*` (any namespace) or `|*` (no namespace).
    Universal: struct { namespace: NamespaceConstraint = .any },
    /// A type selector: its name as written and ASCII-lowercased (HTML
    /// 4.16.2 compares HTML elements in HTML documents with the lowercase).
    Type: struct { tag_name: []const u8, lower_name: []const u8, namespace: NamespaceConstraint = .any },
    Class: struct { class_name: []const u8 },
    Id: struct { id: []const u8 },
    Attribute: AttributeSelector,
    /// CSS Namespaces 3: only namespaced selectors use these extra arms.
    /// The URI belongs to the outer SelectorList's strings; the old
    /// any/none representations and their matcher paths stay unchanged.
    NamespaceURI: struct { uri: []const u8 },
    /// Box this rare arm so SimpleSelector's size does not increase for
    /// every ordinary selector merely to hold the additional URI.
    NamespacedAttribute: *const struct { uri: []const u8, attribute: AttributeSelector },
    /// CSSOM keeps this unresolved; nesting.zig resolves it before matching.
    Nesting,
    PseudoClass: PseudoClassSelector,
    PseudoElement: PseudoElementSelector,

    pub fn deinit(self: *SimpleSelector, allocator: Allocator) void {
        switch (self.*) {
            .NamespacedAttribute => |attribute| allocator.destroy(attribute),
            .PseudoClass => |*pseudo| pseudo.deinit(allocator),
            .PseudoElement => |*pseudo| pseudo.deinit(allocator),
            else => {},
        }
    }

    /// Calculate specificity contribution of this simple selector
    pub fn calculateSpecificity(self: *const SimpleSelector) Specificity {
        return switch (self.*) {
            .Universal, .NamespaceURI, .Nesting => Specificity{}, // 0,0,0
            .Type => Specificity{ .element = 1 }, // 0,0,1
            .Class => Specificity{ .class = 1 }, // 0,1,0
            .Id => Specificity{ .id = 1 }, // 1,0,0
            .Attribute, .NamespacedAttribute => Specificity{ .class = 1 }, // 0,1,0
            .PseudoClass => |*pseudo| pseudo.calculateSpecificity(), // varies
            // 0,0,1; ::slotted() adds its argument's (CSS Scoping 3.2.2).
            .PseudoElement => |*pseudo| pseudo.calculateSpecificity(),
        };
    }
};

/// The attribute selector's case modifier (Selectors 4 6.3).
pub const AttributeCase = enum {
    /// No modifier: the document language decides (HTML 4.16.2).
    default,
    /// `i`: ASCII case-insensitive.
    insensitive,
    /// `s`: identical to.
    sensitive,
};

/// Attribute selector
pub const AttributeSelector = struct {
    /// The attribute's name as written, and ASCII-lowercased: HTML 4.16.2
    /// compares the lowercase with attributes of HTML elements in HTML
    /// documents and the name as written with every other attribute.
    name: []const u8,
    lower_name: []const u8,
    /// `[attr]` and `[|attr]` match only attributes in no namespace;
    /// `[*|attr]` any attribute with that local name.
    namespace: NamespaceConstraint = .none,
    matcher: AttributeMatcher,
    case: AttributeCase = .default,
    /// HTML 4.16.2: the lowercase name is one whose VALUES an HTML element
    /// in an HTML document matches ASCII case-insensitively (without `s`).
    /// Decided once, here, so matching plain selectors never looks it up.
    html_case_insensitive_value: bool = false,
};

/// Attribute matching operators
pub const AttributeMatcher = union(enum) {
    Presence, // [attr]
    Exact: struct { value: []const u8 }, // [attr="value"]
    Prefix: struct { value: []const u8 }, // [attr^="value"]
    Suffix: struct { value: []const u8 }, // [attr$="value"]
    Substring: struct { value: []const u8 }, // [attr*="value"]
    Includes: struct { value: []const u8 }, // [attr~="value"]
    DashMatch: struct { value: []const u8 }, // [attr|="value"]
};

/// Pseudo-class selector
pub const PseudoClassSelector = struct {
    kind: PseudoClassKind,

    pub fn deinit(self: *PseudoClassSelector, allocator: Allocator) void {
        switch (self.kind) {
            .Not, .Is, .Where, .Has => |selector_list_ptr| {
                selector_list_ptr.releaseBoxed();
            },
            .Host => |maybe| if (maybe) |selector_list_ptr| {
                selector_list_ptr.releaseBoxed();
            },
            .NthChild, .NthLastChild => |pattern| if (pattern.of) |selector_list_ptr| {
                selector_list_ptr.releaseBoxed();
            },
            .Lang => |ranges| allocator.free(ranges),
            else => {},
        }
    }

    /// Calculate specificity contribution of this pseudo-class
    pub fn calculateSpecificity(self: *const PseudoClassSelector) Specificity {
        return switch (self.kind) {
            // :where() always has 0 specificity
            .Where => Specificity{},

            // :is(), :not(), :has() take the max specificity of their arguments
            .Is, .Not, .Has => |selector_list_ptr| maxSpecificity(selector_list_ptr),

            // Selectors 4 16.1: ":nth-child(An+B of S)" is the specificity of
            // a pseudo-class plus that of its most specific complex selector
            // in S.
            .NthChild, .NthLastChild => |pattern| blk: {
                var spec = Specificity{ .class = 1 };
                if (pattern.of) |selector_list_ptr| spec = spec.add(maxSpecificity(selector_list_ptr));
                break :blk spec;
            },

            // CSS Scoping: :host() is a pseudo-class plus its argument.
            .Host => |maybe| blk: {
                var spec = Specificity{ .class = 1 };
                if (maybe) |selector_list_ptr| spec = spec.add(maxSpecificity(selector_list_ptr));
                break :blk spec;
            },

            // All other pseudo-classes count as class selectors (0,1,0)
            else => Specificity{ .class = 1 },
        };
    }

    fn maxSpecificity(list: *const SelectorList) Specificity {
        var max_spec = Specificity{};
        for (list.selectors) |*selector| max_spec = max_spec.max(selector.calculateSpecificity());
        return max_spec;
    }
};

/// Direction for :dir() pseudo-class
pub const Direction = enum {
    ltr,
    rtl,
    /// Selectors 4 7.1: "Values other than ltr and rtl are not invalid, but
    /// do not match anything."
    other,
};

/// Pseudo-class types
pub const PseudoClassKind = union(enum) {
    // Structural pseudo-classes
    FirstChild,
    LastChild,
    OnlyChild,
    FirstOfType,
    LastOfType,
    OnlyOfType,
    Empty,
    Root,

    // Nth pseudo-classes
    NthChild: NthPattern,
    NthLastChild: NthPattern,
    NthOfType: NthPattern,
    NthLastOfType: NthPattern,

    // Link pseudo-classes
    AnyLink,
    Link,
    Visited,

    // User action pseudo-classes
    Hover,
    Active,
    Focus,
    FocusVisible,
    FocusWithin,

    // Input pseudo-classes
    Enabled,
    Disabled,
    ReadOnly,
    ReadWrite,
    Checked,
    Valid,
    Invalid,
    Default,
    Indeterminate,
    Required,
    Optional,
    InRange,
    OutOfRange,
    PlaceholderShown,
    Autofill,
    UserValid,
    UserInvalid,
    Open,
    PopoverOpen,
    Modal,
    Playing,
    Paused,
    Seeking,
    Buffering,
    Stalled,
    Muted,
    VolumeLocked,
    Heading: u6,

    // Language pseudo-classes: :lang()'s language ranges (Selectors 4 7.2),
    // the slice owned by the pseudo-class, the strings by the list.
    Lang: []const []const u8,
    Dir: Direction,

    // Negation and matching
    Not: *SelectorList,
    Is: *SelectorList,
    Where: *SelectorList,
    /// :has(<relative-selector-list>): every selector is relative.
    Has: *SelectorList,

    // Scoping
    Scope,

    /// CSS Scoping 3.2.1: `:host` (null) or `:host(<compound-selector>)` - the
    /// shadow host, seen from inside its shadow tree. (:host-context() is
    /// not supported: see functionalPseudoClass.)
    Host: ?*SelectorList,

    // Location pseudo-class (Selectors 4 8.2): the document's target element.
    Target,

    // Custom state (HTML "custom state pseudo-class"): :state(<ident>)
    State: []const u8,

    // HTML 4.16.3: an element whose custom-element state is defined.
    Defined,
};

/// Nth pattern (an+b)
pub const NthPattern = struct {
    a: i32, // Coefficient
    b: i32, // Constant
    /// ":nth-child(An+B of S)" and ":nth-last-child(An+B of S)": only the
    /// siblings matching S count, and the element must match S itself
    /// (Selectors 4 13.3.1). OWNED by the pseudo-class; null without "of".
    of: ?*SelectorList = null,
};

/// Pseudo-element selector: its name, ASCII-lowercased (Selectors 4 3.6.1).
/// A pseudo-element is no element of the tree, so a compound holding one
/// matches no element - except for the style engine, which matches
/// ::slotted() against the elements assigned to a slot and ::part() against
/// the parts of a shadow host (CSS Scoping 3.2.2, CSS Shadow Parts 4.1).
pub const PseudoElementSelector = struct {
    name: []const u8,
    /// ::slotted(<compound-selector>): the argument, a one-selector list.
    /// OWNED by the pseudo-element; null for any other.
    argument: ?*SelectorList = null,
    /// ::part(<ident>+): the part names, which an element must all have.
    /// The array is OWNED; each name, like every name in the AST, is a slice
    /// of the parsed text or of the outer list's decoded strings.
    part_names: []const []const u8 = &.{},

    pub fn deinit(self: *PseudoElementSelector, allocator: Allocator) void {
        if (self.argument) |list| {
            list.releaseBoxed();
            self.argument = null;
        }
        if (self.part_names.len != 0) allocator.free(self.part_names);
        self.part_names = &.{};
    }

    pub fn calculateSpecificity(self: *const PseudoElementSelector) Specificity {
        const own = Specificity{ .element = 1 };
        const list = self.argument orelse return own;
        if (list.selectors.len == 0) return own;
        return own.add(list.selectors[0].calculateSpecificity());
    }
};

// ============================================================================
// Parser Errors
// ============================================================================

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedEOF,
    InvalidSelector,
    OutOfMemory,
};

/// Selectors 4 17.1 "parse a selector": `source` as a <selector-list>, or an
/// error when it is an invalid selector. The list owns what it decoded.
pub fn parseSelectorList(allocator: Allocator, source: []const u8) ParserError!SelectorList {
    return parseWithOptions(allocator, source, .{});
}

/// A stylesheet's namespace bindings, borrowed ONLY for the parse. Each
/// URI used by the AST is copied into the outer list's owned strings.
pub const NamespaceResolver = struct {
    context: ?*const anyopaque = null,
    resolve: *const fn (?*const anyopaque, []const u8) ?[]const u8,
    default: ?[]const u8 = null,
};

pub const NestingContext = enum { style, scope };

pub const ParseOptions = struct {
    namespaces: ?NamespaceResolver = null,
    /// Nearest style/scope ancestor, ignoring intervening group rules.
    nesting: ?NestingContext = null,
};

pub fn parseWithOptions(allocator: Allocator, source: []const u8, options: ParseOptions) ParserError!SelectorList {
    return parseWithMode(allocator, source, options, false);
}

/// CSS Conditional 4 section 2.1: selector() accepts ONE complex selector,
/// with no forgiving parsing, even inside :is() and :where().
pub fn isSupported(allocator: Allocator, source: []const u8, options: ParseOptions) error{OutOfMemory}!bool {
    var list = parseWithMode(allocator, source, options, true) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return false,
    };
    defer list.deinit();
    return list.selectors.len == 1;
}

fn parseWithMode(allocator: Allocator, source: []const u8, options: ParseOptions, comptime support_check: bool) ParserError!SelectorList {
    // The tokens and the parse's working lists live on the stack while they
    // fit: querySelector parses on every call, and allocations are most of a
    // short selector's cost. The list and its strings use `allocator`.
    var stack = std.heap.stackFallback(4096, allocator);
    const scratch = stack.get();
    var tokenizer = Tokenizer.init(scratch, source);
    var parser = try Parser.initWithScratch(allocator, scratch, &tokenizer);
    defer parser.deinit();
    parser.namespaces = options.namespaces;
    parser.nesting = options.nesting;
    parser.support_check = support_check;
    return parser.parse();
}

/// A CSSOM selector and its owned serialized text. The caller frees text
/// and deinits selectors; their lifetimes remain paired.
pub const CssomSelector = struct { text: []u8, selectors: SelectorList };

/// Consumes `source` on success AND failure. Component-value preprocessing
/// has already run. Only parsed An+B spans change here; a forgiven invalid
/// selector remains unparsed text, never accidentally repaired.
pub fn parseCssomOwned(allocator: Allocator, source: []u8, options: ParseOptions) ParserError!CssomSelector {
    errdefer allocator.free(source);
    var stack = std.heap.stackFallback(4096, allocator);
    const scratch = stack.get();
    var tokenizer = Tokenizer.init(scratch, source);
    var parser = try Parser.initWithScratch(allocator, scratch, &tokenizer);
    defer parser.deinit();
    var rewrites: std.ArrayList(AnBRewrite) = .empty;
    defer rewrites.deinit(scratch);
    parser.namespaces = options.namespaces;
    parser.nesting = options.nesting;
    parser.anb_rewrites = &rewrites;
    parser.preserve_nesting = true;
    var list = try parser.parse();
    errdefer list.deinit();
    if (rewrites.items.len == 0) return .{ .text = source, .selectors = list };
    // Recursive pseudo-classes can add inner spans before their outer An+B.
    std.mem.sort(AnBRewrite, rewrites.items, {}, struct {
        fn less(_: void, a: AnBRewrite, b: AnBRewrite) bool {
            return a.start < b.start;
        }
    }.less);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var cursor: usize = 0;
    for (rewrites.items) |rewrite| {
        // compoundArgument validates once, then parses its one-selector
        // list. Its duplicate successful spans are identical.
        if (rewrite.start < cursor) continue;
        try out.appendSlice(allocator, source[cursor..rewrite.start]);
        var buffer: [64]u8 = undefined;
        try out.appendSlice(allocator, rewrite.text(&buffer));
        cursor = rewrite.end;
    }
    try out.appendSlice(allocator, source[cursor..]);
    const text = try out.toOwnedSlice(allocator);
    errdefer allocator.free(text);
    // Names without escapes still point into source, not the shorter text.
    // Use the existing owned-string list, never dangling borrowed slices.
    const count = list.strings.len;
    list.strings = try allocator.realloc(list.strings, count + 1);
    list.strings[count] = source;
    return .{ .text = text, .selectors = list };
}

const AnBRewrite = struct {
    start: usize,
    end: usize,
    a: i32 = 0,
    b: i32 = 0,
    has_of: bool = false,
    prefix: bool = false,

    /// CSS Syntax 3 section 9.1, steps 1–5.
    fn text(self: AnBRewrite, buffer: *[64]u8) []const u8 {
        if (self.prefix) return "& ";
        var written: usize = 0;
        if (self.a == 0) {
            written = (std.fmt.bufPrint(buffer, "{d}", .{self.b}) catch unreachable).len;
        } else {
            const first = if (self.a == 1) "n" else if (self.a == -1) "-n" else std.fmt.bufPrint(buffer, "{d}n", .{self.a}) catch unreachable;
            if (self.a == 1 or self.a == -1) @memcpy(buffer[0..first.len], first);
            written = first.len;
            if (self.b != 0) written += (std.fmt.bufPrint(buffer[written..], "{s}{d}", .{ if (self.b > 0) "+" else "", self.b }) catch unreachable).len;
        }
        if (self.has_of) {
            buffer[written] = ' ';
            written += 1;
        }
        return buffer[0..written];
    }
};

// ============================================================================
// Parser
// ============================================================================

/// What a selector may contain where it is being parsed.
const Context = struct {
    /// Only <complex-real-selector>s: no pseudo-element (the arguments of
    /// :is(), :where(), :not(), :has(), :nth-child(of) and :host()).
    real: bool = false,
    /// Inside :has(), where :has() is not valid (Selectors 4 4.5).
    in_has: bool = false,
    /// Selectors 4 sections 4.2–4.4: no implicit default namespace on
    /// the SUBJECT of a logical combination's argument. Explicit type
    /// and universal selectors, and ancestor compounds, still receive it.
    resist_default_namespace: bool = false,
};

/// An end-of-input token, what reading past a range returns.
const eof_token = Token{ .tag = .eof, .value = "", .start = 0, .end = 0 };

/// A cursor over a range of tokens: a block's contents or a comma-separated
/// piece. Past its end it reads EOF.
const Stream = struct {
    tokens: []const Token,
    pos: usize = 0,

    fn peek(self: *const Stream) Token {
        return self.peekAt(0);
    }

    fn peekAt(self: *const Stream, offset: usize) Token {
        const at = self.pos + offset;
        return if (at < self.tokens.len) self.tokens[at] else eof_token;
    }

    fn atEnd(self: *const Stream) bool {
        return self.pos >= self.tokens.len;
    }

    fn advance(self: *Stream) void {
        self.pos += 1;
    }

    /// Skip whitespace; whether there was any.
    fn skipWhitespace(self: *Stream) bool {
        const before = self.pos;
        while (self.pos < self.tokens.len and self.tokens[self.pos].tag == .whitespace) self.pos += 1;
        return self.pos != before;
    }
};

pub const Parser = struct {
    /// What the SelectorList and its strings are allocated with.
    allocator: Allocator,
    /// The tokens and the working lists of the parse, freed before it
    /// returns (the tokenizer's allocator).
    scratch: Allocator,
    tokenizer: *Tokenizer,
    /// Every token of the input, the EOF token last.
    tokens: []Token,
    /// Decoded and lowercased strings, handed to the list `parse` returns.
    strings: std.ArrayList([]u8) = .empty,
    /// After `parse`: the token the parse stopped at - always the EOF token,
    /// since the whole input is the selector list.
    current_token: ?Token = null,
    namespaces: ?NamespaceResolver = null,
    support_check: bool = false,
    nesting: ?NestingContext = null,
    preserve_nesting: bool = false,
    /// Present only for CSSOM: successful An+B spans, never a failed branch.
    anb_rewrites: ?*std.ArrayList(AnBRewrite) = null,

    pub fn init(allocator: Allocator, tokenizer: *Tokenizer) ParserError!Parser {
        return initWithScratch(allocator, tokenizer.allocator, tokenizer);
    }

    /// `scratch` is the tokenizer's allocator, for the tokens and the
    /// parse's working lists; `allocator` makes what `parse` returns.
    pub fn initWithScratch(allocator: Allocator, scratch: Allocator, tokenizer: *Tokenizer) ParserError!Parser {
        const tokens = try tokenizer.tokenize();
        var parser = Parser{ .allocator = allocator, .scratch = scratch, .tokenizer = tokenizer, .tokens = tokens };
        errdefer parser.deinit();
        // Decode, once, every value written with an escape (or a NUL or a
        // surrogate): the AST holds the decoded values.
        for (parser.tokens) |*token| {
            if (!token.needs_decode) continue;
            const decoded = try tokenizer_mod.decode(allocator, token.*);
            parser.strings.append(allocator, decoded) catch |err| {
                allocator.free(decoded);
                return err;
            };
            token.value = decoded;
        }
        parser.current_token = tokens[0];
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.scratch.free(self.tokens);
        for (self.strings.items) |s| self.allocator.free(s);
        self.strings.deinit(self.allocator);
    }

    /// Selectors 4 17.1 "parse a selector": the whole input as a
    /// <selector-list>. The list owns the strings the parse decoded.
    pub fn parse(self: *Parser) ParserError!SelectorList {
        const all = self.tokens[0 .. self.tokens.len - 1];
        var list = try self.parseList(all, .{}, .{ .forgiving = false, .relative = self.nesting != null, .nesting = self.nesting });
        errdefer list.deinit();
        self.current_token = self.tokens[self.tokens.len - 1];
        list.strings = try self.strings.toOwnedSlice(self.allocator);
        return list;
    }

    // ========================================================================
    // Lists
    // ========================================================================

    const ListKind = struct {
        /// <forgiving-selector-list> (16.1): invalid items are dropped.
        forgiving: bool,
        /// <relative-selector-list>.
        relative: bool,
        nesting: ?NestingContext = null,
    };

    /// A comma-separated list of complex (or relative) selectors over
    /// `tokens`. CSS Syntax 3 5.4.2 "parse a comma-separated list according
    /// to a CSS grammar": commas inside blocks do not separate.
    fn parseList(self: *Parser, tokens: []const Token, ctx: Context, kind: ListKind) ParserError!SelectorList {
        var selectors: std.ArrayList(ComplexSelector) = .empty;
        defer selectors.deinit(self.scratch);
        errdefer for (selectors.items) |*selector| selector.deinit();

        var piece_start: usize = 0;
        var i: usize = 0;
        while (true) {
            const at_comma = i < tokens.len and tokens[i].tag == .comma;
            if (i >= tokens.len or at_comma) {
                const piece = tokens[piece_start..i];
                const rewrite_count = if (self.anb_rewrites) |rewrites| rewrites.items.len else 0;
                if (self.parseComplex(piece, ctx, kind.relative, kind.nesting)) |selector| {
                    selectors.append(self.scratch, selector) catch |err| {
                        var dropped = selector;
                        dropped.deinit();
                        return err;
                    };
                } else |err| switch (err) {
                    error.OutOfMemory => return err,
                    // 16.1 "Remove all failure items ... and all items that
                    // are invalid selectors."
                    else => {
                        if (self.anb_rewrites) |rewrites| rewrites.shrinkRetainingCapacity(rewrite_count);
                        if (!kind.forgiving or self.support_check) return err;
                    },
                }
                if (i >= tokens.len) break;
                i += 1;
                piece_start = i;
                continue;
            }
            i = try self.skipComponentValue(tokens, i);
        }

        return SelectorList{
            .selectors = try self.allocator.dupe(ComplexSelector, selectors.items),
            .allocator = self.allocator,
        };
    }

    /// The index after the component value at `start`: a token, or a whole
    /// block or function up to its closing token (or the end).
    fn skipComponentValue(self: *Parser, tokens: []const Token, start: usize) ParserError!usize {
        if (closerOf(tokens[start].tag) == null) return start + 1;
        const close = try self.matchingClose(tokens, start);
        return if (close < tokens.len) close + 1 else close;
    }

    /// The index of the token closing the block or function opened at
    /// `open`, or `tokens.len` when the end of the input closes it (CSS
    /// Syntax 3 5.5.9 / 5.5.10: a parse error, not a failure). A closing
    /// token of another kind inside is an ordinary token.
    fn matchingClose(self: *Parser, tokens: []const Token, open: usize) ParserError!usize {
        var expected: std.ArrayList(Token.Tag) = .empty;
        defer expected.deinit(self.scratch);
        try expected.append(self.scratch, closerOf(tokens[open].tag).?);
        var i = open + 1;
        while (i < tokens.len) : (i += 1) {
            const tag = tokens[i].tag;
            if (tag == expected.items[expected.items.len - 1]) {
                _ = expected.pop();
                if (expected.items.len == 0) return i;
            } else if (closerOf(tag)) |closer| {
                try expected.append(self.scratch, closer);
            }
        }
        return tokens.len;
    }

    fn closerOf(tag: Token.Tag) ?Token.Tag {
        return switch (tag) {
            .function, .lparen => .rparen,
            .lbracket => .rbracket,
            .lbrace => .rbrace,
            else => null,
        };
    }

    // ========================================================================
    // Complex selectors
    // ========================================================================

    /// <complex-selector> (or <relative-selector>) over all of `tokens`,
    /// whitespace around it allowed. Stored right to left.
    fn parseComplex(self: *Parser, tokens: []const Token, ctx: Context, relative: bool, nesting: ?NestingContext) ParserError!ComplexSelector {
        var stream = Stream{ .tokens = tokens };
        _ = stream.skipWhitespace();

        const first_token = stream.peek();
        const explicit_combinator = combinatorOf(first_token) != null;
        var contains_nesting = false;
        if (nesting != null) for (tokens) |token| {
            // Nesting 1 section 3.1 counts a delim '&' even inside a
            // forgiven unknown pseudo-class, but never inside a string.
            if (token.isDelim('&')) {
                contains_nesting = true;
                break;
            }
        };

        var ltr_compounds: std.ArrayList(CompoundSelector) = .empty;
        defer ltr_compounds.deinit(self.scratch);
        var ltr_combinators: std.ArrayList(Combinator) = .empty;
        defer ltr_combinators.deinit(self.scratch);
        errdefer for (ltr_compounds.items) |*compound| compound.deinit();

        // <relative-selector> = <combinator>? <complex-selector>: with no
        // combinator the descendant combinator is implied (3.4).
        var initial_combinator: ?Combinator = null;
        if (relative) {
            initial_combinator = combinatorOf(stream.peek()) orelse .Descendant;
            if (combinatorOf(stream.peek()) != null) {
                stream.advance();
                _ = stream.skipWhitespace();
            }
        }

        // "An empty selector, i.e. one that contains no compound selector,
        // is invalid."
        if (stream.atEnd()) return error.InvalidSelector;

        while (true) {
            var compound = try self.parseCompound(&stream, ctx);
            const has_pseudo_element = compound.hasPseudoElement();
            ltr_compounds.append(self.scratch, compound) catch |err| {
                compound.deinit();
                return err;
            };

            const had_whitespace = stream.skipWhitespace();
            if (stream.atEnd()) break;
            // 3.6.5: a combinator after a pseudo-element is invalid (none of
            // the pseudo-elements here has internal structure).
            if (has_pseudo_element) return error.InvalidSelector;

            const combinator: Combinator = if (combinatorOf(stream.peek())) |explicit| blk: {
                stream.advance();
                _ = stream.skipWhitespace();
                break :blk explicit;
            } else if (had_whitespace) .Descendant else return error.InvalidSelector;
            // A combinator with no compound after it.
            if (stream.atEnd()) return error.InvalidSelector;
            try ltr_combinators.append(self.scratch, combinator);
        }

        // Convert to RTL storage order: [div, p, span] with combinators
        // [>, +] becomes compound=span, combinators=[{+, p}, {>, div}].
        const compounds = ltr_compounds.items;
        const pairs: []CombinatorPair = if (compounds.len == 1) &.{} else try self.allocator.alloc(CombinatorPair, compounds.len - 1);
        for (pairs, 0..) |*pair, k| {
            const i = compounds.len - 2 - k;
            pair.* = .{ .combinator = ltr_combinators.items[i], .compound = compounds[i] };
        }
        const subject = compounds[compounds.len - 1];
        // Ownership of every compound has moved into `result`.
        ltr_compounds.clearRetainingCapacity();

        var result = ComplexSelector{
            .compound = subject,
            .combinators = pairs,
            .allocator = self.allocator,
            .is_relative = relative,
            .initial_combinator = initial_combinator,
        };
        errdefer result.deinit();
        if (nesting) |context_kind| {
            const has_scope = context_kind == .scope and @import("nesting.zig").containsScope(&result);
            if (explicit_combinator or (!contains_nesting and !has_scope)) {
                const simples = try self.allocator.alloc(SimpleSelector, 1);
                var owns_simples = true;
                errdefer if (owns_simples) self.allocator.free(simples);
                simples[0] = if (context_kind == .style) .Nesting else .{ .PseudoClass = .{ .kind = .Scope } };
                const old_len = result.combinators.len;
                result.combinators = try self.allocator.realloc(result.combinators, old_len + 1);
                result.combinators[old_len] = .{
                    .combinator = initial_combinator orelse .Descendant,
                    .compound = .{ .allocator = self.allocator, .simple_selectors = simples },
                };
                owns_simples = false;
                // Scope's implicit anchor is omitted by CSSOM. A style
                // rule's implicit & is serialized (Nesting 1 section 3.1).
                if (context_kind == .style) if (self.anb_rewrites) |rewrites|
                    try rewrites.append(self.scratch, .{ .start = first_token.start, .end = first_token.start, .prefix = true });
            }
            result.is_relative = false;
            result.initial_combinator = null;
        }
        result.computeAncestorHashes();
        result.computeBacktrackingInfo();
        return result;
    }

    /// <combinator> = '>' | '+' | '~'
    fn combinatorOf(token: Token) ?Combinator {
        if (token.tag != .delim) return null;
        return switch (token.delim) {
            '>' => .Child,
            '+' => .NextSibling,
            '~' => .SubsequentSibling,
            else => null,
        };
    }

    // ========================================================================
    // Compound selectors
    // ========================================================================

    /// <compound-selector> [ <pseudo-compound-selector> ]*: a type selector
    /// and subclass selectors, then pseudo-elements with the pseudo-classes
    /// allowed after them - no whitespace in between.
    fn parseCompound(self: *Parser, stream: *Stream, ctx: Context) ParserError!CompoundSelector {
        var simples: std.ArrayList(SimpleSelector) = .empty;
        defer simples.deinit(self.scratch);
        errdefer for (simples.items) |*simple| simple.deinit(self.allocator);

        const type_selector = try self.parseTypeSelector(stream);
        if (type_selector) |resolved| {
            try simples.append(self.scratch, resolved.simple);
            if (resolved.uri) |uri| try simples.append(self.scratch, .{ .NamespaceURI = .{ .uri = uri } });
        }

        // The pseudo-element the compound has reached, if any.
        var pseudo_element: ?[]const u8 = null;
        while (true) {
            const token = stream.peek();
            var simple: SimpleSelector = switch (token.tag) {
                .hash => blk: {
                    // <id-selector> = <hash-token>, whose value "must be an
                    // identifier".
                    if (!token.hash_is_id or pseudo_element != null) return error.InvalidSelector;
                    stream.advance();
                    break :blk .{ .Id = .{ .id = token.value } };
                },
                .delim => blk: {
                    if (token.delim == '&') {
                        if (pseudo_element != null) return error.InvalidSelector;
                        stream.advance();
                        break :blk if (self.preserve_nesting) .Nesting else try @import("nesting.zig").scopeReference(self.allocator);
                    }
                    // <class-selector> = '.' <ident-token>
                    if (token.delim != '.') break;
                    if (pseudo_element != null) return error.InvalidSelector;
                    const name = stream.peekAt(1);
                    if (name.tag != .ident) return error.InvalidSelector;
                    stream.pos += 2;
                    break :blk .{ .Class = .{ .class_name = name.value } };
                },
                .lbracket => blk: {
                    if (pseudo_element != null) return error.InvalidSelector;
                    const close = try self.matchingClose(stream.tokens, stream.pos);
                    const contents = stream.tokens[stream.pos + 1 .. close];
                    stream.pos = if (close < stream.tokens.len) close + 1 else close;
                    break :blk try self.parseAttribute(contents);
                },
                .colon => blk: {
                    if (stream.peekAt(1).tag == .colon) {
                        // <pseudo-element-selector> = ':' <pseudo-class-selector>
                        if (ctx.real) return error.InvalidSelector;
                        stream.pos += 2;
                        const parsed = try self.parsePseudoElement(stream, pseudo_element);
                        pseudo_element = parsed.name;
                        break :blk .{ .PseudoElement = parsed };
                    }
                    stream.advance();
                    const parsed = try self.parsePseudoClass(stream, ctx, pseudo_element);
                    if (parsed == .PseudoElement) {
                        // A legacy one-colon pseudo-element (:before, ...).
                        if (ctx.real or pseudo_element != null) {
                            var dropped = parsed;
                            dropped.deinit(self.allocator);
                            return error.InvalidSelector;
                        }
                        pseudo_element = parsed.PseudoElement.name;
                    }
                    break :blk parsed;
                },
                else => break,
            };
            simples.append(self.scratch, simple) catch |err| {
                simple.deinit(self.allocator);
                return err;
            };
        }

        if (simples.items.len == 0) return error.InvalidSelector;
        if (type_selector == null) if (self.namespaces) |ns| if (ns.default) |uri| {
            var after = stream.*;
            _ = after.skipWhitespace();
            if (!ctx.resist_default_namespace or !after.atEnd()) {
                // CSS Namespaces 3 section 3: the omitted universal type
                // still imposes the default namespace on this compound.
                const owned = try self.ownUri(uri);
                try simples.insert(self.scratch, 0, .{ .NamespaceURI = .{ .uri = owned } });
            }
        };
        return CompoundSelector{
            .active_hover_quirk = !ctx.real and usesOnlyActiveOrHover(simples.items),
            .simple_selectors = try self.allocator.dupe(SimpleSelector, simples.items),
            .allocator = self.allocator,
        };
    }

    /// Quirks Mode 4.1's conditions on a compound's simple selectors: it uses
    /// :active or :hover, and nothing else - the universal selector being a
    /// type selector (Selectors 4 5.2).
    fn usesOnlyActiveOrHover(simples: []const SimpleSelector) bool {
        var uses = false;
        for (simples) |simple| switch (simple) {
            .NamespaceURI => {}, // An implicit namespace is not an explicit universal.
            .PseudoClass => |pseudo| switch (pseudo.kind) {
                .Active, .Hover => uses = true,
                else => return false,
            },
            else => return false,
        };
        return uses;
    }

    /// <type-selector> = <wq-name> | <ns-prefix>? '*', where
    /// <wq-name> = <ns-prefix>? <ident-token> and
    /// <ns-prefix> = [ <ident-token> | '*' ]? '|' - no whitespace inside.
    /// Null when the compound starts with no type selector.
    const ResolvedType = struct { simple: SimpleSelector, uri: ?[]const u8 = null };

    fn ownUri(self: *Parser, uri: []const u8) ParserError![]const u8 {
        const owned = try self.allocator.dupe(u8, uri);
        errdefer self.allocator.free(owned);
        try self.strings.append(self.allocator, owned);
        return owned;
    }

    fn namespaceUri(self: *Parser, prefix: []const u8) ParserError![]const u8 {
        const resolver = self.namespaces orelse return error.InvalidSelector;
        const uri = resolver.resolve(resolver.context, prefix) orelse return error.InvalidSelector;
        return self.ownUri(uri);
    }

    fn parseTypeSelector(self: *Parser, stream: *Stream) ParserError!?ResolvedType {
        const t0 = stream.peek();
        const t1 = stream.peekAt(1);
        const t2 = stream.peekAt(2);

        // ns-prefix '|' followed by a name or '*'.
        if (t1.isDelim('|') and (t0.tag == .ident or t0.isDelim('*'))) {
            if (t2.tag != .ident and !t2.isDelim('*')) return error.InvalidSelector;
            // Selectors 4 section 5.3: an undeclared prefix is invalid.
            const uri = if (t0.tag == .ident) try self.namespaceUri(t0.value) else null;
            stream.pos += 3;
            return .{ .simple = try self.typeOrUniversal(t2, .any), .uri = uri };
        }
        if (t0.isDelim('|')) {
            if (t1.tag != .ident and !t1.isDelim('*')) return error.InvalidSelector;
            stream.pos += 2;
            return .{ .simple = try self.typeOrUniversal(t1, .none) };
        }
        if (t0.tag == .ident or t0.isDelim('*')) {
            stream.advance();
            const uri = if (self.namespaces) |ns| if (ns.default) |value| try self.ownUri(value) else null else null;
            return .{ .simple = try self.typeOrUniversal(t0, .any), .uri = uri };
        }
        return null;
    }

    fn typeOrUniversal(self: *Parser, name: Token, namespace: NamespaceConstraint) ParserError!SimpleSelector {
        if (name.tag != .ident) return .{ .Universal = .{ .namespace = namespace } };
        return .{ .Type = .{ .tag_name = name.value, .lower_name = try self.lowercase(name.value), .namespace = namespace } };
    }

    // ========================================================================
    // Attribute selectors
    // ========================================================================

    /// <attribute-selector> = '[' <wq-name> ']' |
    ///   '[' <wq-name> <attr-matcher> [ <string-token> | <ident-token> ]
    ///   <attr-modifier>? ']'
    /// over the block's contents (whitespace allowed between the parts, not
    /// inside the name or the matcher).
    fn attributeSimple(self: *Parser, attribute: AttributeSelector, uri: ?[]const u8) ParserError!SimpleSelector {
        const resolved = uri orelse return .{ .Attribute = attribute };
        const Box = @typeInfo(@FieldType(SimpleSelector, "NamespacedAttribute")).pointer.child;
        const boxed = try self.allocator.create(Box);
        boxed.* = .{ .uri = resolved, .attribute = attribute };
        return .{ .NamespacedAttribute = boxed };
    }

    fn parseAttribute(self: *Parser, contents: []const Token) ParserError!SimpleSelector {
        var stream = Stream{ .tokens = contents };
        _ = stream.skipWhitespace();

        // <wq-name>
        var namespace: NamespaceConstraint = .none;
        var uri: ?[]const u8 = null;
        const t0 = stream.peek();
        const t1 = stream.peekAt(1);
        const t2 = stream.peekAt(2);
        const name_token: Token = if (t0.isDelim('*') and t1.isDelim('|')) blk: {
            if (t2.tag != .ident) return error.InvalidSelector;
            namespace = .any;
            stream.pos += 3;
            break :blk t2;
        } else if (t0.isDelim('|') and t1.tag == .ident) blk: {
            stream.pos += 2;
            break :blk t1;
        } else if (t0.tag == .ident) blk: {
            // ident '|' ident is a named prefix; ident '|' '=' is the
            // attribute's unprefixed name and its dash-match operator.
            if (t1.isDelim('|') and t2.tag == .ident) {
                uri = try self.namespaceUri(t0.value);
                stream.pos += 3;
                break :blk t2;
            }
            stream.advance();
            break :blk t0;
        } else return error.InvalidSelector;

        const lower_name = try self.lowercase(name_token.value);
        var selector = AttributeSelector{
            .name = name_token.value,
            .lower_name = lower_name,
            .namespace = namespace,
            .matcher = .Presence,
            .html_case_insensitive_value = isHtmlCaseInsensitiveValueAttribute(lower_name),
        };

        _ = stream.skipWhitespace();
        if (stream.atEnd()) return self.attributeSimple(selector, uri);

        // <attr-matcher> = [ '~' | '|' | '^' | '$' | '*' ]? '='
        const m0 = stream.peek();
        if (m0.tag != .delim) return error.InvalidSelector;
        var operator: u21 = '=';
        if (m0.delim != '=') {
            if (!stream.peekAt(1).isDelim('=')) return error.InvalidSelector;
            operator = m0.delim;
            stream.advance();
        }
        stream.advance();
        _ = stream.skipWhitespace();

        // [ <string-token> | <ident-token> ]
        const value_token = stream.peek();
        if (value_token.tag != .string and value_token.tag != .ident) return error.InvalidSelector;
        const value = value_token.value;
        stream.advance();
        selector.matcher = switch (operator) {
            '=' => .{ .Exact = .{ .value = value } },
            '~' => .{ .Includes = .{ .value = value } },
            '|' => .{ .DashMatch = .{ .value = value } },
            '^' => .{ .Prefix = .{ .value = value } },
            '$' => .{ .Suffix = .{ .value = value } },
            '*' => .{ .Substring = .{ .value = value } },
            else => return error.InvalidSelector,
        };

        // <attr-modifier> = i | s, ASCII case-insensitive (3.7).
        _ = stream.skipWhitespace();
        if (!stream.atEnd()) {
            const modifier = stream.peek();
            if (modifier.tag != .ident) return error.InvalidSelector;
            if (std.ascii.eqlIgnoreCase(modifier.value, "i")) {
                selector.case = .insensitive;
            } else if (std.ascii.eqlIgnoreCase(modifier.value, "s")) {
                selector.case = .sensitive;
            } else return error.InvalidSelector;
            stream.advance();
            _ = stream.skipWhitespace();
        }
        if (!stream.atEnd()) return error.InvalidSelector;
        return self.attributeSimple(selector, uri);
    }

    // ========================================================================
    // Pseudo-classes
    // ========================================================================

    /// After ':': <pseudo-class-selector> = ':' <ident-token> |
    /// ':' <function-token> <any-value> ')' - or a legacy one-colon
    /// pseudo-element. `after_pseudo_element` is the pseudo-element this
    /// compound already has: only some pseudo-classes may follow one.
    fn parsePseudoClass(self: *Parser, stream: *Stream, ctx: Context, after_pseudo_element: ?[]const u8) ParserError!SimpleSelector {
        const token = stream.peek();
        switch (token.tag) {
            .ident => {
                stream.advance();
                const name = token.value;
                // 16: <legacy-pseudo-element-selector> = ':' [before | after
                // | first-line | first-letter], never a pseudo-class.
                for ([_][]const u8{ "before", "after", "first-line", "first-letter" }) |legacy| {
                    if (std.ascii.eqlIgnoreCase(name, legacy)) return .{ .PseudoElement = .{ .name = legacy } };
                }
                const kind = simplePseudoClass(name) orelse return error.InvalidSelector;
                if (after_pseudo_element) |pseudo| if (!allowedAfterPseudoElement(pseudo, kind)) return error.InvalidSelector;
                return .{ .PseudoClass = .{ .kind = kind } };
            },
            .function => {
                const close = try self.matchingClose(stream.tokens, stream.pos);
                const args = stream.tokens[stream.pos + 1 .. close];
                stream.pos = if (close < stream.tokens.len) close + 1 else close;
                const kind = try self.functionalPseudoClass(token.value, args, ctx);
                var selector = PseudoClassSelector{ .kind = kind };
                if (after_pseudo_element) |pseudo| if (!allowedAfterPseudoElement(pseudo, kind)) {
                    selector.deinit(self.allocator);
                    return error.InvalidSelector;
                };
                return .{ .PseudoClass = selector };
            },
            else => return error.InvalidSelector,
        }
    }

    /// The non-functional pseudo-classes, by name (ASCII case-insensitive,
    /// Selectors 4 3.5). Null for one Crane does not support, which makes the
    /// selector invalid (3.9: "UAs must treat as invalid any pseudo-classes
    /// ... for which they have no usable level of support").
    fn simplePseudoClass(name: []const u8) ?PseudoClassKind {
        const Entry = struct { []const u8, PseudoClassKind };
        const table = [_]Entry{
            .{ "first-child", .FirstChild },             .{ "last-child", .LastChild },
            .{ "only-child", .OnlyChild },               .{ "first-of-type", .FirstOfType },
            .{ "last-of-type", .LastOfType },            .{ "only-of-type", .OnlyOfType },
            .{ "empty", .Empty },                        .{ "root", .Root },
            .{ "scope", .Scope },                        .{ "any-link", .AnyLink },
            .{ "link", .Link },                          .{ "visited", .Visited },
            .{ "hover", .Hover },                        .{ "active", .Active },
            .{ "focus", .Focus },                        .{ "focus-visible", .FocusVisible },
            .{ "focus-within", .FocusWithin },           .{ "enabled", .Enabled },
            .{ "disabled", .Disabled },                  .{ "read-only", .ReadOnly },
            .{ "read-write", .ReadWrite },               .{ "checked", .Checked },
            .{ "valid", .Valid },                        .{ "invalid", .Invalid },
            .{ "default", .Default },                    .{ "indeterminate", .Indeterminate },
            .{ "required", .Required },                  .{ "optional", .Optional },
            .{ "in-range", .InRange },                   .{ "out-of-range", .OutOfRange },
            .{ "placeholder-shown", .PlaceholderShown }, .{ "autofill", .Autofill },
            // Appendix B: a legacy selector alias of :autofill.
            .{ "-webkit-autofill", .Autofill },          .{ "user-valid", .UserValid },
            .{ "user-invalid", .UserInvalid },           .{ "open", .Open },
            .{ "popover-open", .PopoverOpen },           .{ "modal", .Modal },
            .{ "playing", .Playing },                    .{ "paused", .Paused },
            .{ "seeking", .Seeking },                    .{ "buffering", .Buffering },
            .{ "stalled", .Stalled },                    .{ "muted", .Muted },
            .{ "volume-locked", .VolumeLocked },         .{ "heading", .{ .Heading = 0b111111 } },
            .{ "target", .Target },                      .{ "defined", .Defined },
            .{ "host", .{ .Host = null } },
        };
        for (table) |entry| {
            if (std.ascii.eqlIgnoreCase(name, entry[0])) return entry[1];
        }
        return null;
    }

    /// 3.6.3: "This specification allows any pseudo-element to be followed
    /// by any combination of the logical combination pseudo-classes and the
    /// user action pseudo-classes." ::part() (CSS Shadow Parts) also allows
    /// the pseudo-classes that are not tree-structural.
    fn allowedAfterPseudoElement(pseudo_element: []const u8, kind: PseudoClassKind) bool {
        switch (kind) {
            .Hover, .Active, .Focus, .FocusVisible, .FocusWithin, .Is, .Where, .Not => return true,
            .FirstChild, .LastChild, .OnlyChild, .FirstOfType, .LastOfType, .OnlyOfType, .Empty, .Root, .NthChild, .NthLastChild, .NthOfType, .NthLastOfType, .Has, .Scope, .Host => return false,
            else => return std.mem.eql(u8, pseudo_element, "part"),
        }
    }

    /// A functional pseudo-class `name(` over its arguments `args`.
    fn functionalPseudoClass(self: *Parser, name: []const u8, args: []const Token, ctx: Context) ParserError!PseudoClassKind {
        const real = Context{ .real = true, .in_has = ctx.in_has };
        const logical = Context{ .real = true, .in_has = ctx.in_has, .resist_default_namespace = true };
        if (std.ascii.eqlIgnoreCase(name, "not")) {
            // 4.3: :not(<complex-real-selector-list>).
            return .{ .Not = try self.boxedList(args, logical, .{ .forgiving = false, .relative = false }) };
        }
        if (std.ascii.eqlIgnoreCase(name, "is")) {
            return .{ .Is = try self.boxedList(args, logical, .{ .forgiving = true, .relative = false }) };
        }
        if (std.ascii.eqlIgnoreCase(name, "where")) {
            return .{ .Where = try self.boxedList(args, logical, .{ .forgiving = true, .relative = false }) };
        }
        if (std.ascii.eqlIgnoreCase(name, "has")) {
            // 4.5: "The :has() pseudo-class cannot be nested; :has() is not
            // valid within :has()", and its argument is a
            // <relative-selector-list> (unforgiving since 2022 - all three
            // engines).
            if (ctx.in_has) return error.InvalidSelector;
            return .{ .Has = try self.boxedList(args, .{ .real = true, .in_has = true }, .{ .forgiving = false, .relative = true }) };
        }
        if (std.ascii.eqlIgnoreCase(name, "nth-child") or std.ascii.eqlIgnoreCase(name, "nth-last-child")) {
            var stream = Stream{ .tokens = args };
            var pattern = try parseAnPlusB(&stream);
            errdefer if (pattern.of) |list| {
                list.releaseBoxed();
            };
            _ = stream.skipWhitespace();
            const anb_end = stream.pos;
            if (!stream.atEnd()) {
                // 13.3.1: :nth-child(<an+b> [of <complex-real-selector-list>]?)
                const of = stream.peek();
                if (of.tag != .ident or !std.ascii.eqlIgnoreCase(of.value, "of")) return error.InvalidSelector;
                stream.advance();
                pattern.of = try self.boxedList(args[stream.pos..], real, .{ .forgiving = false, .relative = false });
            }
            try self.recordAnB(args, anb_end, pattern, pattern.of != null);
            return if (std.ascii.eqlIgnoreCase(name, "nth-child")) .{ .NthChild = pattern } else .{ .NthLastChild = pattern };
        }
        if (std.ascii.eqlIgnoreCase(name, "nth-of-type") or std.ascii.eqlIgnoreCase(name, "nth-last-of-type")) {
            var stream = Stream{ .tokens = args };
            const pattern = try parseAnPlusB(&stream);
            _ = stream.skipWhitespace();
            if (!stream.atEnd()) return error.InvalidSelector;
            try self.recordAnB(args, stream.pos, pattern, false);
            return if (std.ascii.eqlIgnoreCase(name, "nth-of-type")) .{ .NthOfType = pattern } else .{ .NthLastOfType = pattern };
        }
        if (std.ascii.eqlIgnoreCase(name, "lang")) return .{ .Lang = try self.parseLanguageRanges(args) };
        if (std.ascii.eqlIgnoreCase(name, "dir")) {
            // 7.1: "The argument to :dir() must be a single identifier".
            const ident = try singleToken(args, .ident);
            return .{ .Dir = if (std.ascii.eqlIgnoreCase(ident.value, "ltr")) .ltr else if (std.ascii.eqlIgnoreCase(ident.value, "rtl")) .rtl else .other };
        }
        if (std.ascii.eqlIgnoreCase(name, "state")) {
            // HTML: ":state(<custom-ident>)".
            return .{ .State = (try singleToken(args, .ident)).value };
        }
        if (std.ascii.eqlIgnoreCase(name, "heading")) return .{ .Heading = try parseHeadingLevels(args) };
        if (std.ascii.eqlIgnoreCase(name, "host")) {
            // CSS Scoping 3.2.1: :host(<compound-selector>).
            return .{ .Host = try self.compoundArgument(args, real) };
        }
        // :host-context() (CSS Scoping 3.2.1) is invalid here, as in Firefox
        // and Safari - only Chrome parses it (wpt.fyi cc74d2669f,
        // css/css-shadow/host-context-parsing.html: ":host-context(.a)"
        // valid PASS/FAIL/FAIL), and the CSSWG marks it at risk.
        return error.InvalidSelector;
    }

    /// A selector list in a block of its own, owned by the pseudo-class.
    fn boxedList(self: *Parser, tokens: []const Token, ctx: Context, kind: ListKind) ParserError!*SelectorList {
        const list = try self.allocator.create(SelectorList);
        errdefer self.allocator.destroy(list);
        list.* = try self.parseList(tokens, ctx, kind);
        return list;
    }

    /// A <compound-selector> argument (:host(), ::slotted()),
    /// as a one-selector list.
    fn compoundArgument(self: *Parser, tokens: []const Token, ctx: Context) ParserError!*SelectorList {
        var stream = Stream{ .tokens = tokens };
        _ = stream.skipWhitespace();
        const start = stream.pos;
        if (stream.atEnd()) return error.InvalidSelector;
        var compound = try self.parseCompound(&stream, ctx);
        compound.deinit();
        _ = stream.skipWhitespace();
        if (!stream.atEnd()) return error.InvalidSelector;
        // Parsed once to validate; parse the same tokens as a complex
        // selector of one compound, which is what matching takes.
        return self.boxedList(tokens[start..], ctx, .{ .forgiving = false, .relative = false });
    }

    /// The only token of `args` (whitespace around it allowed), of `tag`.
    fn singleToken(args: []const Token, tag: Token.Tag) ParserError!Token {
        var stream = Stream{ .tokens = args };
        _ = stream.skipWhitespace();
        const token = stream.peek();
        if (token.tag != tag) return error.InvalidSelector;
        stream.advance();
        _ = stream.skipWhitespace();
        if (!stream.atEnd()) return error.InvalidSelector;
        return token;
    }

    /// 7.2: :lang() takes "a comma-separated list of one or more language
    /// ranges", each a valid <ident> or <string>.
    fn parseLanguageRanges(self: *Parser, args: []const Token) ParserError![]const []const u8 {
        var ranges: std.ArrayList([]const u8) = .empty;
        defer ranges.deinit(self.scratch);
        var stream = Stream{ .tokens = args };
        while (true) {
            _ = stream.skipWhitespace();
            const token = stream.peek();
            if (token.tag != .ident and token.tag != .string) return error.InvalidSelector;
            try ranges.append(self.scratch, token.value);
            stream.advance();
            _ = stream.skipWhitespace();
            if (stream.atEnd()) break;
            if (stream.peek().tag != .comma) return error.InvalidSelector;
            stream.advance();
        }
        return try self.allocator.dupe([]const u8, ranges.items);
    }

    /// HTML :heading(<integer>#), CSS Values 4 integer syntax. Keep only
    /// levels 1-6 in the mask, while accepting every syntactically valid
    /// integer.
    fn parseHeadingLevels(args: []const Token) ParserError!u6 {
        var levels: u6 = 0;
        var stream = Stream{ .tokens = args };
        while (true) {
            _ = stream.skipWhitespace();
            const token = stream.peek();
            if (token.tag != .number or !token.is_integer) return error.InvalidSelector;
            if (token.number >= 1 and token.number <= 6) levels |= @as(u6, 1) << @as(u3, @intFromFloat(token.number - 1));
            stream.advance();
            _ = stream.skipWhitespace();
            if (stream.atEnd()) return levels;
            if (stream.peek().tag != .comma) return error.InvalidSelector;
            stream.advance();
        }
    }

    // ========================================================================
    // Pseudo-elements
    // ========================================================================

    /// After '::': a pseudo-element - its name (lowercase) and the argument
    /// of ::slotted() or ::part() - or an error for one Crane does not know.
    /// `after` is the pseudo-element already in the compound: 3.6.4 allows
    /// only defined sub-pseudo-elements after one.
    fn parsePseudoElement(self: *Parser, stream: *Stream, after: ?[]const u8) ParserError!PseudoElementSelector {
        const token = stream.peek();
        var pseudo: PseudoElementSelector = .{ .name = "" };
        errdefer pseudo.deinit(self.allocator);
        pseudo.name = switch (token.tag) {
            .ident => blk: {
                stream.advance();
                if (knownPseudoElement(token.value, &plain_pseudo_elements)) |known| break :blk known;
                // Appendix B: "All other pseudo-elements whose names begin
                // with "-webkit-" ... and that are not functional notations
                // must be treated as valid at parse time."
                if (!self.support_check and token.value.len > 8 and std.ascii.startsWithIgnoreCase(token.value, "-webkit-")) break :blk try self.lowercase(token.value);
                return error.InvalidSelector;
            },
            .function => blk: {
                const known = knownPseudoElement(token.value, &functional_pseudo_elements) orelse return error.InvalidSelector;
                const close = try self.matchingClose(stream.tokens, stream.pos);
                const args = stream.tokens[stream.pos + 1 .. close];
                stream.pos = if (close < stream.tokens.len) close + 1 else close;
                try self.parsePseudoElementArgument(known, args, &pseudo);
                break :blk known;
            },
            else => return error.InvalidSelector,
        };
        const name = pseudo.name;
        if (after) |first| {
            // ::before::marker and ::after::marker; the tree-abiding
            // pseudo-elements of a ::slotted() or ::part() element.
            const ok = if (std.mem.eql(u8, first, "before") or std.mem.eql(u8, first, "after"))
                std.mem.eql(u8, name, "marker")
            else if (std.mem.eql(u8, first, "slotted") or std.mem.eql(u8, first, "part"))
                !std.mem.eql(u8, name, "slotted") and !std.mem.eql(u8, name, "part")
            else
                false;
            if (!ok) return error.InvalidSelector;
        }
        return pseudo;
    }

    const plain_pseudo_elements = [_][]const u8{
        "before",          "after",       "first-line", "first-letter",         "marker",
        "placeholder",     "selection",   "backdrop",   "file-selector-button", "grammar-error",
        "spelling-error",  "target-text", "cue",        "details-content",      "search-text",
        "checkmark",       "picker-icon", "column",     "scroll-marker",        "scroll-marker-group",
        "view-transition",
    };

    const functional_pseudo_elements = [_][]const u8{
        "slotted",             "part",                  "highlight",
        "cue",                 "view-transition-group", "view-transition-image-pair",
        "view-transition-old", "view-transition-new",   "picker",
        "scroll-button",
    };

    fn knownPseudoElement(name: []const u8, table: []const []const u8) ?[]const u8 {
        for (table) |known| if (std.ascii.eqlIgnoreCase(name, known)) return known;
        return null;
    }

    /// ::slotted(<compound-selector>), ::part(<ident>+), ::highlight(<ident>);
    /// the others need some argument. ::slotted()'s compound and ::part()'s
    /// names are kept in `pseudo` for matching.
    fn parsePseudoElementArgument(self: *Parser, name: []const u8, args: []const Token, pseudo: *PseudoElementSelector) ParserError!void {
        if (std.mem.eql(u8, name, "slotted")) {
            pseudo.argument = try self.compoundArgument(args, .{ .real = true });
            return;
        }
        var stream = Stream{ .tokens = args };
        _ = stream.skipWhitespace();
        if (stream.atEnd()) return error.InvalidSelector;
        if (std.mem.eql(u8, name, "part")) {
            var names: std.ArrayList([]const u8) = .empty;
            defer names.deinit(self.scratch);
            while (!stream.atEnd()) {
                if (stream.peek().tag != .ident) return error.InvalidSelector;
                try names.append(self.scratch, stream.peek().value);
                stream.advance();
                _ = stream.skipWhitespace();
            }
            pseudo.part_names = try self.allocator.dupe([]const u8, names.items);
        } else if (std.mem.eql(u8, name, "highlight")) {
            _ = try singleToken(args, .ident);
        }
    }

    // ========================================================================
    // An+B
    // ========================================================================

    /// CSS Syntax 3 6.2 <an+b>, from the start of `stream` (leading
    /// whitespace allowed). Leaves the stream after the B part.
    fn parseAnPlusB(stream: *Stream) ParserError!NthPattern {
        _ = stream.skipWhitespace();
        const token = stream.peek();
        switch (token.tag) {
            .ident => {
                // odd | even
                if (std.ascii.eqlIgnoreCase(token.value, "odd")) {
                    stream.advance();
                    return .{ .a = 2, .b = 1 };
                }
                if (std.ascii.eqlIgnoreCase(token.value, "even")) {
                    stream.advance();
                    return .{ .a = 2, .b = 0 };
                }
                stream.advance();
                // -n... forms: A is -1.
                if (token.value.len > 0 and token.value[0] == '-') return nAndB(stream, -1, token.value[1..]);
                return nAndB(stream, 1, token.value);
            },
            .delim => {
                // '+'?† n ...: the '+' must touch the ident.
                if (token.delim != '+') return error.InvalidSelector;
                const ident = stream.peekAt(1);
                if (ident.tag != .ident or ident.value.len == 0 or ident.value[0] == '-') return error.InvalidSelector;
                stream.pos += 2;
                return nAndB(stream, 1, ident.value);
            },
            .number => {
                // <integer>: A is 0, B is the integer's value.
                if (!token.is_integer) return error.InvalidSelector;
                stream.advance();
                return .{ .a = 0, .b = clampInt(token.number) };
            },
            .dimension => {
                // <n-dimension> ... : A is the dimension's value.
                if (!token.is_integer) return error.InvalidSelector;
                stream.advance();
                return nAndB(stream, clampInt(token.number), token.value);
            },
            else => return error.InvalidSelector,
        }
    }

    /// The rest of an <an+b> whose A part is `a` and whose ident (or unit),
    /// without A's sign, is `unit`: "n", "n-", or "n-<digits>".
    fn nAndB(stream: *Stream, a: i32, unit: []const u8) ParserError!NthPattern {
        if (unit.len == 0 or (unit[0] != 'n' and unit[0] != 'N')) return error.InvalidSelector;
        const rest = unit[1..];
        if (rest.len == 0) {
            // n, optionally followed by <signed-integer> or
            // ['+' | '-'] <signless-integer>.
            const save = stream.pos;
            _ = stream.skipWhitespace();
            const next = stream.peek();
            if (next.tag == .number and next.is_integer and next.sign != .none) {
                stream.advance();
                return .{ .a = a, .b = clampInt(next.number) };
            }
            if (next.isDelim('+') or next.isDelim('-')) {
                stream.advance();
                _ = stream.skipWhitespace();
                const int = stream.peek();
                if (int.tag != .number or !int.is_integer or int.sign != .none) return error.InvalidSelector;
                stream.advance();
                // Browser probe Q26 (2026-10-27): all three clamp this
                // separate unsigned B token before applying its sign.
                const b = clampInt(int.number);
                return .{ .a = a, .b = if (next.delim == '-') -b else b };
            }
            stream.pos = save;
            return .{ .a = a, .b = 0 };
        }
        if (rest[0] != '-') return error.InvalidSelector;
        const digits = rest[1..];
        if (digits.len == 0) {
            // n- <signless-integer>: B is the negation of the integer.
            _ = stream.skipWhitespace();
            const int = stream.peek();
            if (int.tag != .number or !int.is_integer or int.sign != .none) return error.InvalidSelector;
            stream.advance();
            return .{ .a = a, .b = -clampInt(int.number) };
        }
        // n-<digits>: B is the digits, negated.
        for (digits) |d| if (!std.ascii.isDigit(d)) return error.InvalidSelector;
        // Chrome 156 + Safari 27 reject overflow in a joined n-<digits>;
        // Firefox 158 clamps it (integrator Q26 probe, 2026-10-27).
        // WebKit consumeANPlusB parses the signed suffix as an int.
        const value = std.fmt.parseInt(i32, rest, 10) catch return error.InvalidSelector;
        return .{ .a = a, .b = value };
    }

    fn recordAnB(self: *Parser, args: []const Token, end: usize, pattern: NthPattern, has_of: bool) ParserError!void {
        const rewrites = self.anb_rewrites orelse return;
        std.debug.assert(end != 0);
        const rewrite = AnBRewrite{ .start = args[0].start, .end = args[end - 1].end, .a = pattern.a, .b = pattern.b, .has_of = has_of };
        var buffer: [64]u8 = undefined;
        if (std.mem.eql(u8, rewrite.text(&buffer), self.tokenizer.input[rewrite.start..rewrite.end])) return;
        try rewrites.append(self.scratch, rewrite);
    }

    fn clampInt(value: f64) i32 {
        const max: f64 = std.math.maxInt(i32);
        const min: f64 = std.math.minInt(i32);
        return @intFromFloat(std.math.clamp(@trunc(value), min, max));
    }

    // ========================================================================
    // Utilities
    // ========================================================================

    /// `s` ASCII-lowercased: `s` itself when it has no uppercase ASCII, else
    /// a copy the parse's list owns.
    fn lowercase(self: *Parser, s: []const u8) ParserError![]const u8 {
        for (s) |c| {
            if (std.ascii.isUpper(c)) break;
        } else return s;
        const lowered = try std.ascii.allocLowerString(self.allocator, s);
        self.strings.append(self.allocator, lowered) catch |err| {
            self.allocator.free(lowered);
            return err;
        };
        return lowered;
    }
};

/// HTML 4.16.2: the attributes whose values an HTML element in an HTML
/// document matches ASCII case-insensitively, by (lowercase) name.
pub fn isHtmlCaseInsensitiveValueAttribute(lower_name: []const u8) bool {
    const names = [_][]const u8{
        "accept",  "accept-charset", "align",     "alink",      "axis",     "bgcolor",
        "charset", "checked",        "clear",     "codetype",   "color",    "compact",
        "declare", "defer",          "dir",       "direction",  "disabled", "enctype",
        "face",    "frame",          "hreflang",  "http-equiv", "lang",     "language",
        "link",    "media",          "method",    "multiple",   "nohref",   "noresize",
        "noshade", "nowrap",         "readonly",  "rel",        "rev",      "rules",
        "scope",   "scrolling",      "selected",  "shape",      "target",   "text",
        "type",    "valign",         "valuetype", "vlink",
    };
    for (names) |name| if (std.mem.eql(u8, lower_name, name)) return true;
    return false;
}

// ============================================================================
// Tests
// ============================================================================

const testing = @import("std").testing;

fn parseSelector(allocator: std.mem.Allocator, input: []const u8) !SelectorList {
    return parseSelectorList(allocator, input);
}

test "BacktrackingInfo - no combinators" {
    var selector = try parseSelector(testing.allocator, "div.class");
    defer selector.deinit();
    const complex = &selector.selectors[0];
    try testing.expect(!complex.backtracking.has_descendant_combinator);
    try testing.expect(!complex.backtracking.has_sibling_combinator);
    try testing.expect(complex.backtracking.first_descendant_index == null);
    try testing.expect(complex.backtracking.first_sibling_index == null);
}

test "BacktrackingInfo - descendant combinator" {
    var selector = try parseSelector(testing.allocator, "div p");
    defer selector.deinit();
    const complex = &selector.selectors[0];
    try testing.expect(complex.backtracking.has_descendant_combinator);
    try testing.expect(!complex.backtracking.has_sibling_combinator);
    try testing.expectEqual(@as(?usize, 0), complex.backtracking.first_descendant_index);
}

test "BacktrackingInfo - child combinator" {
    var selector = try parseSelector(testing.allocator, "div > p");
    defer selector.deinit();
    const complex = &selector.selectors[0];
    try testing.expect(!complex.backtracking.has_descendant_combinator);
    try testing.expect(!complex.backtracking.has_sibling_combinator);
}

test "BacktrackingInfo - sibling combinators" {
    var selector = try parseSelector(testing.allocator, "div + p");
    defer selector.deinit();
    const complex = &selector.selectors[0];
    try testing.expect(!complex.backtracking.has_descendant_combinator);
    try testing.expect(complex.backtracking.has_sibling_combinator);
    try testing.expectEqual(@as(?usize, 0), complex.backtracking.first_sibling_index);
}

test "BacktrackingInfo - mixed combinators" {
    var selector = try parseSelector(testing.allocator, "div > span p + a");
    defer selector.deinit();
    const complex = &selector.selectors[0];
    try testing.expect(complex.backtracking.has_descendant_combinator);
    try testing.expect(complex.backtracking.has_sibling_combinator);
}

test "BacktrackingInfo - ancestor ID detection" {
    var selector = try parseSelector(testing.allocator, "#header div p");
    defer selector.deinit();
    try testing.expect(selector.selectors[0].backtracking.has_ancestor_id);
}

test "getFailureRecovery - descendant combinator failure" {
    var selector = try parseSelector(testing.allocator, "div span p");
    defer selector.deinit();
    try testing.expectEqual(MatchResult.not_matched_restart_descendant, selector.selectors[0].getFailureRecovery(0));
}

test "getFailureRecovery - sibling combinator failure" {
    var selector = try parseSelector(testing.allocator, "div + p");
    defer selector.deinit();
    try testing.expectEqual(MatchResult.not_matched_restart_later_sibling, selector.selectors[0].getFailureRecovery(0));
}

test "getFailureRecovery - child combinator failure with descendant backup" {
    var selector = try parseSelector(testing.allocator, "div span > p");
    defer selector.deinit();
    try testing.expectEqual(MatchResult.not_matched_restart_descendant, selector.selectors[0].getFailureRecovery(1));
}

test "parse :target as a pseudo-class" {
    var selector = try parseSelector(testing.allocator, "div:target");
    defer selector.deinit();
    const simple = selector.selectors[0].compound.simple_selectors;
    try testing.expect(simple[simple.len - 1].PseudoClass.kind == .Target);
}

test "parse :state(ident) keeping its ident" {
    var selector = try parseSelector(testing.allocator, ":state(--green)");
    defer selector.deinit();
    const kind = selector.selectors[0].compound.simple_selectors[0].PseudoClass.kind;
    try testing.expectEqualStrings("--green", kind.State);
    try testing.expectError(error.InvalidSelector, parseSelector(testing.allocator, ":state()"));
    try testing.expectError(error.InvalidSelector, parseSelector(testing.allocator, ":state(1)"));
}

test "parse :nth-child(An+B of S), its selector list owned by the pseudo-class" {
    var selector = try parseSelector(testing.allocator, ":nth-child(2 of :state(--green), .x)");
    defer selector.deinit();
    const pattern = selector.selectors[0].compound.simple_selectors[0].PseudoClass.kind.NthChild;
    try testing.expectEqual(@as(i32, 0), pattern.a);
    try testing.expectEqual(@as(i32, 2), pattern.b);
    try testing.expectEqual(@as(usize, 2), pattern.of.?.selectors.len);

    var plain = try parseSelector(testing.allocator, ":nth-last-child(2n+1)");
    defer plain.deinit();
    try testing.expect(plain.selectors[0].compound.simple_selectors[0].PseudoClass.kind.NthLastChild.of == null);
}

test "the specificity of :nth-child(An+B of S) adds S's most specific selector" {
    var selector = try parseSelector(testing.allocator, ":nth-child(2 of #a, .b)");
    defer selector.deinit();
    const spec = selector.selectors[0].calculateSpecificity();
    try testing.expectEqual(@as(u32, 1), spec.id);
    try testing.expectEqual(@as(u32, 1), spec.class);
}

/// Parse `input`, which must be an invalid selector: whatever the parse made
/// before it failed is freed (std.testing.allocator fails the test if not).
fn expectInvalidSelector(input: []const u8) !void {
    if (parseSelector(testing.allocator, input)) |parsed| {
        var list = parsed;
        list.deinit();
        std.debug.print("parsed as valid: \"{s}\"\n", .{input});
        return error.TestUnexpectedResult;
    } else |_| {}
}

test "an attribute selector that fails after its name frees what it made" {
    // Each fails after the name was lowered into an allocation of its own
    // (leaks lane, 2026-10-02: 42 in dom/nodes/ParentNode-querySelector-All.html alone).
    try expectInvalidSelector("[Foo=]");
    try expectInvalidSelector("[foo=]");
    try expectInvalidSelector("[Foo bar]");
    try expectInvalidSelector("[FOO='bar' x]");
    try expectInvalidSelector("div [Foo~=]");
    // The success path still hands the name to the selector.
    var valid = try parseSelector(testing.allocator, "[Foo='bar' i]");
    defer valid.deinit();
    const attribute = valid.selectors[0].compound.simple_selectors[0].Attribute;
    try testing.expectEqualStrings("foo", attribute.lower_name);
    try testing.expectEqualStrings("Foo", attribute.name);
    try testing.expect(attribute.case == .insensitive);
}

test "a functional pseudo-class that fails frees its selector list and its block" {
    // Each parses part of an argument into a list before failing.
    try expectInvalidSelector(":not(.a ])");
    try expectInvalidSelector(":not([)");
    try expectInvalidSelector(":not(.a, %)");
    try expectInvalidSelector(":has(> .a, >)");
    try expectInvalidSelector(":nth-child(2 of .a, %)");
    try expectInvalidSelector(":nth-child(2 of [)");
    try expectInvalidSelector(":nth-last-child(2n+1 of .a .b %)");
    try expectInvalidSelector("div:not([foo=]):is(.a)");
    try expectInvalidSelector(":is(.a):not(.b) %");
    // The success path still owns each list.
    var valid = try parseSelector(testing.allocator, ":not(.a, [b]):is(.c):where(.d):has(> .e):nth-child(2 of .f)");
    defer valid.deinit();
    try testing.expectEqual(@as(usize, 5), valid.selectors[0].compound.simple_selectors.len);
}
