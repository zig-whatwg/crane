//! Implementation for CSSStartingStyleRule interface (CSS Transitions 2
//! 3.3.1): an @starting-style rule, a CSSGroupingRule with no members of its
//! own. Its child rules (cssRules, insertRule, deleteRule) are the grouping
//! rule's, read from the rule it is a view of; the generated construction
//! chain makes its CSSGroupingRule and CSSRule parts.
//!
//! Spec: https://drafts.csswg.org/css-transitions-2/#the-cssstartingstylerule-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const CSSStartingStyleRule = interfaces.CSSStartingStyleRule;

pub const State = CSSStartingStyleRule.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};
