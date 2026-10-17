## 1. Introduction

### 1.1. Background

*This section is not normative.*

[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
defines one type of conditional group rule, the
[\@media](#at-ruledef-media) rule, and allows only style rules (not other @-rules)
inside of it. The [\@media] rule
provides the ability to have media-specific style sheets, which is also
provided by style sheet linking features such as
[\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) and
[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element). The restrictions on the contents of
[\@media] rules made them less useful;
they have forced authors using CSS features involving @-rules in
media-specific style sheets to use separate style sheets for each
medium.

This specification extends the rules for the contents of conditional
group rules to allow other @-rules, which enables authors to combine CSS
features involving @-rules with media specific style sheets within a
single style sheet.

This specification also defines an additional type of conditional group
rule, [\@supports](#at-ruledef-supports), to address author and user requirements.

The [\@supports](#at-ruledef-supports) rule allows CSS to be conditioned on
implementation support for CSS properties and values. This rule makes it
much easier for authors to use new CSS features and provide good
fallback for implementations that do not support those features. This is
particularly important for CSS features that provide new layout
mechanisms, and for other cases where a set of related styles needs to
be conditioned on property support.

### 1.2. Module Interactions

This module replaces and extends the
[\@media](#at-ruledef-media) rule feature defined in
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
section 7.2.1 and incorporates the modifications previously made
non-normatively by
[\[MEDIAQUERIES-4\]](#biblio-mediaqueries-4 "Media Queries Level 4")
section 1.

## 2. Processing of conditional group rules

This specification defines some CSS
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule), called [conditional group
rules], that associate a condition with
a group of other CSS rules. These different rules allow testing
different types of conditions, but share common behavior for how their
contents are used when the condition is true and when the condition is
false.

For example, this rule:

``` highlight
@media print {
 /* hide navigation controls when printing */
 #navigation { display: none }
}
```

causes a particular CSS rule (making elements with ID "navigation" be
display:none) apply only when the style sheet is used for a print
medium.

Each conditional group rule has a condition, which at any time evaluates
to true or false. When the condition is true, CSS processors **must**
apply the rules inside the group rule as though they were at the group
rule's location; when the condition is false, CSS processors **must
not** apply any of rules inside the group rule. The current state of the
condition does not affect the CSS object model, in which the contents of
the group rule always remain within the group rule.

Tests

If condition is true, rules applied in place.

- [at-supports-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-001.html "css/css-conditional/at-supports-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-001.html)
- [at-media-001.html](https://wpt.fyi/results/css/css-conditional/at-media-001.html "css/css-conditional/at-media-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-001.html)

------------------------------------------------------------------------

If condition is false, rules not applied.

- [css-supports-020.xht](https://wpt.fyi/results/css/css-conditional/css-supports-020.xht "css/css-conditional/css-supports-020.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-020.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-020.xht)
- [at-media-002.html](https://wpt.fyi/results/css/css-conditional/at-media-002.html "css/css-conditional/at-media-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-002.html)

------------------------------------------------------------------------

CSSOM contains rules regardless of condition.

- [conditional-CSSGroupingRule.html](https://wpt.fyi/results/css/css-conditional/js/conditional-CSSGroupingRule.html "css/css-conditional/js/conditional-CSSGroupingRule.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/conditional-CSSGroupingRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/conditional-CSSGroupingRule.html)

------------------------------------------------------------------------

This means that when multiple conditional group rules are nested, a rule
inside of both of them applies only when all of the rules\' conditions
are true.

Tests

Nested rules apply when all conditions are true.

- [at-supports-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-002.html "css/css-conditional/at-supports-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-002.html)
- [at-supports-003.html](https://wpt.fyi/results/css/css-conditional/at-supports-003.html "css/css-conditional/at-supports-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-003.html)
- [at-supports-004.html](https://wpt.fyi/results/css/css-conditional/at-supports-004.html "css/css-conditional/at-supports-004.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-004.html)
- [at-supports-005.html](https://wpt.fyi/results/css/css-conditional/at-supports-005.html "css/css-conditional/at-supports-005.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-005.html)
- [at-supports-048.html](https://wpt.fyi/results/css/css-conditional/at-supports-048.html "css/css-conditional/at-supports-048.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-048.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-048.html)
- [css-supports-025.xht](https://wpt.fyi/results/css/css-conditional/css-supports-025.xht "css/css-conditional/css-supports-025.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-025.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-025.xht)
- [css-supports-026.xht](https://wpt.fyi/results/css/css-conditional/css-supports-026.xht "css/css-conditional/css-supports-026.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-026.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-026.xht)
- [css-supports-046.xht](https://wpt.fyi/results/css/css-conditional/css-supports-046.xht "css/css-conditional/css-supports-046.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-046.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-046.xht)

------------------------------------------------------------------------

For example, with this set of nested
rules:

``` highlight
@media print { /* rule (1) */
 /* hide navigation controls when printing */
 #navigation { display: none }
 @media (max-width: 12cm) { /* rule (2) */
 /* keep notes in flow when printing to narrow pages */
 .note { float: none }
 }
}
```

the condition of the rule marked (1) is true for print media, and the
condition of the rule marked (2) is true when the width of the display
area (which for print media is the page box) is less than or equal to
12cm. Thus the rule [#navigation { display: none }] applies
whenever this style sheet is applied to print media, and the rule [.note
{ float: none }] is applied only when the style sheet is applied
to print media *and* the width of the page box is less than or equal to
12 centimeters.

When the condition for a conditional group rule changes, CSS processors
**must** reflect that the rules now apply or no longer apply, except for
properties whose definitions define effects of computed values that
persist past the lifetime of that value (such as for some properties in
[\[CSS3-TRANSITIONS\]](#biblio-css3-transitions "CSS Transitions Module Level 1")
and
[\[CSS3-ANIMATIONS\]](#biblio-css3-animations "CSS Animations Level 1")).

Tests

Change in condition simultaneous with change in condition application
(except per transition/animation rules).

- [at-media-dynamic-001.html](https://wpt.fyi/results/css/css-conditional/at-media-dynamic-001.html "css/css-conditional/at-media-dynamic-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-dynamic-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-dynamic-001.html)

------------------------------------------------------------------------

## 3. Contents of conditional group rules

All [conditional group
rules](#conditional-group-rule) are defined to take a
[\<rule-list\>](https://drafts.csswg.org/css-syntax-3/#typedef-rule-list) in their block, and accept any rule
that is normally allowed at the top-level of a stylesheet, and not
otherwise restricted. (For example, an
[\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import) rule must appear at the actual beginning of a
stylesheet, and so is not valid inside of another rule.)

Tests

Valid to nest all unrestricted top-level rules.

- [at-supports-content-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-content-002.html "css/css-conditional/at-supports-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-content-002.html)
- [at-supports-content-003.html](https://wpt.fyi/results/css/css-conditional/at-supports-content-003.html "css/css-conditional/at-supports-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-content-003.html)
- [at-supports-content-004.html](https://wpt.fyi/results/css/css-conditional/at-supports-content-004.html "css/css-conditional/at-supports-content-004.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-content-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-content-004.html)
- [at-media-content-002.html](https://wpt.fyi/results/css/css-conditional/at-media-content-002.html "css/css-conditional/at-media-content-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-content-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-content-002.html)
- [at-media-content-003.html](https://wpt.fyi/results/css/css-conditional/at-media-content-003.html "css/css-conditional/at-media-content-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-content-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-content-003.html)
- [at-media-content-004.html](https://wpt.fyi/results/css/css-conditional/at-media-content-004.html "css/css-conditional/at-media-content-004.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-content-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-content-004.html)

------------------------------------------------------------------------

Invalid or unknown rules inside the
[\<rule-list\>](https://drafts.csswg.org/css-syntax-3/#typedef-rule-list) must be considered invalid and
ignored, but do not invalidate the [conditional group
rule](#conditional-group-rule).

Tests

Invalid rules do not invalidate conditional group rule.

- [at-supports-content-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-content-001.html "css/css-conditional/at-supports-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-content-001.html)
- [at-media-content-001.html](https://wpt.fyi/results/css/css-conditional/at-media-content-001.html "css/css-conditional/at-media-content-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-content-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-content-001.html)

------------------------------------------------------------------------

Any namespace prefixes used in a [conditional group
rule](#conditional-group-rule) must have been declared, otherwise they are invalid.

For example, this rule containing a [CSS
qualified
name](https://drafts.csswg.org/css-namespaces-3/#css-qualified-name) is valid, because the [namespace
prefix](https://drafts.csswg.org/css-namespaces-3/#namespace-prefix) has been bound to a namespace url:

``` highlight
@namespace x url(http://www.w3.org/1999/xlink);
@supports (content: attr(x|href)) {
 // do something }
```

For example, to determine whether this
rule is valid:

``` highlight
@supports (content: attr(n|tooltip)) {
 // do something }
```

The user agent will consult the namespace map to see whether a namespace
url exists corresponding to the \"n\" prefix.

Validity of namespace prefixes depends on namespace map.

- [at-supports-namespace-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-namespace-001.html "css/css-conditional/at-supports-namespace-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-namespace-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-namespace-001.html)
- [at-supports-namespace-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-namespace-002.html "css/css-conditional/at-supports-namespace-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-namespace-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-namespace-002.html)

------------------------------------------------------------------------

## 4. Placement of conditional group rules

Conditional group rules are allowed wherever [style
rules](https://drafts.csswg.org/css-syntax-3/#style-rule) are allowed (at the top-level of a style sheet, as well
as within other conditional group rules). CSS processors **must**
process such rules as [described above](#processing).

Tests

Conditional group rules allowed wherever style rules are allowed.

- [at-media-001.html](https://wpt.fyi/results/css/css-conditional/at-media-001.html "css/css-conditional/at-media-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-001.html)
- [at-supports-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-001.html "css/css-conditional/at-supports-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-001.html)
- [at-supports-002.html](https://wpt.fyi/results/css/css-conditional/at-supports-002.html "css/css-conditional/at-supports-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-002.html)
- [at-supports-003.html](https://wpt.fyi/results/css/css-conditional/at-supports-003.html "css/css-conditional/at-supports-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-003.html)
- [at-supports-004.html](https://wpt.fyi/results/css/css-conditional/at-supports-004.html "css/css-conditional/at-supports-004.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-004.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-004.html)
- [at-supports-005.html](https://wpt.fyi/results/css/css-conditional/at-supports-005.html "css/css-conditional/at-supports-005.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-005.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-005.html)
- [css-supports-025.xht](https://wpt.fyi/results/css/css-conditional/css-supports-025.xht "css/css-conditional/css-supports-025.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-025.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-025.xht)
- [css-supports-026.xht](https://wpt.fyi/results/css/css-conditional/css-supports-026.xht "css/css-conditional/css-supports-026.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-026.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-026.xht)
- [css-supports-046.xht](https://wpt.fyi/results/css/css-conditional/css-supports-046.xht "css/css-conditional/css-supports-046.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-046.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-046.xht)

------------------------------------------------------------------------

Any
[at-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) that are not allowed after a style rule (e.g.,
[\@charset](https://drafts.csswg.org/css-syntax-3/#at-ruledef-charset),
[\@import](https://drafts.csswg.org/css-cascade-6/#at-ruledef-import), or
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules) are also not allowed after a conditional
group rule, and are therefore
[invalid](https://drafts.csswg.org/css-syntax-3/#css-invalid) when so placed.

Tests

At rules not allowed after style rule invalid after conditional group
rule.

- [at-media-003.html](https://wpt.fyi/results/css/css-conditional/at-media-003.html "css/css-conditional/at-media-003.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-003.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-003.html)
- [at-supports-045.html](https://wpt.fyi/results/css/css-conditional/at-supports-045.html "css/css-conditional/at-supports-045.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-045.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-045.html)

------------------------------------------------------------------------

## 5. Media-specific style sheets: the [\@media rule]
The [\@media] rule is a conditional group rule whose
condition is a media query. Its syntax is:

```
@media <media-query-list> {
 <rule-list>
}
```

It consists of the at-keyword
[\@media](#at-ruledef-media) followed by a (possibly empty) media query list (as
defined in
[\[MEDIAQUERIES-4\]](#biblio-mediaqueries-4 "Media Queries Level 4")),
followed by a block containing arbitrary rules. The condition of the
rule is the result of the media query.

This
[\@media](#at-ruledef-media) rule:

``` highlight
@media screen and (min-width: 35em),
 print and (min-width: 40em) {
 #section_navigation { float: left; width: 10em; }
}
```

has the condition [screen and (min-width: 35em), print and (min-width:
40em)], which is true for screen displays whose viewport is at
least 35 times the initial font size and for print displays whose
viewport is at least 40 times the initial font size. When either of
these is true, the condition of the rule is true, and the rule
[#section_navigation { float: left; width: 10em; }] is applied.

Media rule condition can be empty

- [at-media-whitespace-optional-001.html](https://wpt.fyi/results/css/css-conditional/at-media-whitespace-optional-001.html "css/css-conditional/at-media-whitespace-optional-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-whitespace-optional-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-whitespace-optional-001.html)

------------------------------------------------------------------------

Media rule condition is media query

- [at-media-001.html](https://wpt.fyi/results/css/css-conditional/at-media-001.html "css/css-conditional/at-media-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-001.html)
- [at-media-002.html](https://wpt.fyi/results/css/css-conditional/at-media-002.html "css/css-conditional/at-media-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-002.html)

------------------------------------------------------------------------

White space is optional where not required for tokenization.

- [at-media-whitespace-optional-001.html](https://wpt.fyi/results/css/css-conditional/at-media-whitespace-optional-001.html "css/css-conditional/at-media-whitespace-optional-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-whitespace-optional-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-whitespace-optional-001.html)
- [at-media-whitespace-optional-002.html](https://wpt.fyi/results/css/css-conditional/at-media-whitespace-optional-002.html "css/css-conditional/at-media-whitespace-optional-002.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-media-whitespace-optional-002.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-media-whitespace-optional-002.html)
- [at-supports-whitespace.html](https://wpt.fyi/results/css/css-conditional/at-supports-whitespace.html "css/css-conditional/at-supports-whitespace.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-whitespace.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-whitespace.html)

------------------------------------------------------------------------

## 6. Feature queries: the [\@supports rule]
The [\@supports] rule is a conditional group rule whose
condition tests whether the user agent supports CSS
[property:value] pairs. Authors can use it to write style sheets
that use new features when available but degrade gracefully when those
features are not supported. These queries are called [CSS feature
queries] or (colloquially) [supports queries].

 CSS has existing mechanisms for graceful degradation,
such as ignoring unsupported properties or values, but these are not
always sufficient when large groups of styles need to be tied to the
support for certain features, as is the case for use of new layout
system features.

The syntax of the condition in the
[\@supports](#at-ruledef-supports) rule is similar to that defined for
[\<media-condition\>](https://drafts.csswg.org/mediaqueries-5/#typedef-media-condition) in
[\[MEDIAQUERIES-4\]](#biblio-mediaqueries-4 "Media Queries Level 4"),
but without the \"unknown\" value logic:

- negation is needed so that the new-feature styles and the fallback
 styles can be separated (within the forward-compatible grammar's rules
 for the syntax of @-rules), and not required to override each other.

- conjunction (and) is needed so that multiple required features can be
 tested.

- disjunction (or) is needed when there are multiple alternative
 features for a set of styles, particularly when some of those
 alternatives are vendor-prefixed properties or values.

Therefore, the syntax of the
[\@supports](#at-ruledef-supports) rule allows testing for property:value pairs, and
arbitrary conjunctions (and), disjunctions (or), and negations (not) of
them.

The syntax of the
[\@supports](#at-ruledef-supports) rule is:

```
@supports <supports-condition> {
 <rule-list>
}
```

with
[\<supports-condition\>](#typedef-supports-condition) defined as:

```
<supports-condition> = not <supports-in-parens>
 | <supports-in-parens> [ and <supports-in-parens> ]*
 | <supports-in-parens> [ or <supports-in-parens> ]*
<supports-in-parens> = ( <supports-condition> ) | <supports-feature> | <general-enclosed>
<supports-feature> = <supports-decl>
<supports-decl> = ( <declaration> )
```

The above grammar is purposely very loose for forwards-compatibility
reasons, since the
[\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) production allows for substantial
future extensibility. Any
[\@supports](#at-ruledef-supports) rule that does not parse according to the grammar
above (that is, a rule that does not match this loose grammar which
includes the [\<general-enclosed\>] production) is invalid. Style sheets **must not** use such
a rule and processors **must** ignore such a rule (including all of its
contents).

Tests

White space is optional where not required for tokenization.

- [css-supports-015.xht](https://wpt.fyi/results/css/css-conditional/css-supports-015.xht "css/css-conditional/css-supports-015.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-015.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-015.xht)

------------------------------------------------------------------------

Grammatically-invalid \@supports rule is ignored.

- [at-supports-019.html](https://wpt.fyi/results/css/css-conditional/at-supports-019.html "css/css-conditional/at-supports-019.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-019.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-019.html)
- [at-supports-020.html](https://wpt.fyi/results/css/css-conditional/at-supports-020.html "css/css-conditional/at-supports-020.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-020.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-020.html)
- [at-supports-021.html](https://wpt.fyi/results/css/css-conditional/at-supports-021.html "css/css-conditional/at-supports-021.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-021.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-021.html)
- [at-supports-022.html](https://wpt.fyi/results/css/css-conditional/at-supports-022.html "css/css-conditional/at-supports-022.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-022.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-022.html)
- [at-supports-023.html](https://wpt.fyi/results/css/css-conditional/at-supports-023.html "css/css-conditional/at-supports-023.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-023.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-023.html)
- [at-supports-024.html](https://wpt.fyi/results/css/css-conditional/at-supports-024.html "css/css-conditional/at-supports-024.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-024.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-024.html)
- [at-supports-025.html](https://wpt.fyi/results/css/css-conditional/at-supports-025.html "css/css-conditional/at-supports-025.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-025.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-025.html)
- [at-supports-026.html](https://wpt.fyi/results/css/css-conditional/at-supports-026.html "css/css-conditional/at-supports-026.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-026.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-026.html)
- [at-supports-027.html](https://wpt.fyi/results/css/css-conditional/at-supports-027.html "css/css-conditional/at-supports-027.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-027.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-027.html)
- [at-supports-028.html](https://wpt.fyi/results/css/css-conditional/at-supports-028.html "css/css-conditional/at-supports-028.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-028.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-028.html)
- [at-supports-029.html](https://wpt.fyi/results/css/css-conditional/at-supports-029.html "css/css-conditional/at-supports-029.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-029.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-029.html)
- [at-supports-030.html](https://wpt.fyi/results/css/css-conditional/at-supports-030.html "css/css-conditional/at-supports-030.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-030.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-030.html)
- [at-supports-031.html](https://wpt.fyi/results/css/css-conditional/at-supports-031.html "css/css-conditional/at-supports-031.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-031.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-031.html)
- [at-supports-032.html](https://wpt.fyi/results/css/css-conditional/at-supports-032.html "css/css-conditional/at-supports-032.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-032.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-032.html)
- [at-supports-033.html](https://wpt.fyi/results/css/css-conditional/at-supports-033.html "css/css-conditional/at-supports-033.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-033.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-033.html)
- [css-supports-034.xht](https://wpt.fyi/results/css/css-conditional/css-supports-034.xht "css/css-conditional/css-supports-034.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-034.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-034.xht)
- [css-supports-037.xht](https://wpt.fyi/results/css/css-conditional/css-supports-037.xht "css/css-conditional/css-supports-037.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-037.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-037.xht)

------------------------------------------------------------------------

Each of these grammar terms is associated with a boolean result, as
follows:

[\<supports-condition\>](#typedef-supports-condition)\
[\<supports-in-parens\>](#typedef-supports-in-parens)

: The result is the result of the child subexpression.

not [\<supports-in-parens\>](#typedef-supports-in-parens)

: The result is the negation of the
 [\<supports-in-parens\>](#typedef-supports-in-parens) term.

 Tests

 Not negates supports condition.

 - [at-supports-009.html](https://wpt.fyi/results/css/css-conditional/at-supports-009.html "css/css-conditional/at-supports-009.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-009.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-009.html)
 - [at-supports-010.html](https://wpt.fyi/results/css/css-conditional/at-supports-010.html "css/css-conditional/at-supports-010.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-010.html)
 - [css-supports-016.xht](https://wpt.fyi/results/css/css-conditional/css-supports-016.xht "css/css-conditional/css-supports-016.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-016.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-016.xht)

 ------------------------------------------------------------------------

 Not must be followed by space.

 - [at-supports-014.html](https://wpt.fyi/results/css/css-conditional/at-supports-014.html "css/css-conditional/at-supports-014.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-014.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-014.html)
 - [css-supports-038.xht](https://wpt.fyi/results/css/css-conditional/css-supports-038.xht "css/css-conditional/css-supports-038.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-038.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-038.xht)

 ------------------------------------------------------------------------

 Not requires parentheses.

 - [css-supports-017.xht](https://wpt.fyi/results/css/css-conditional/css-supports-017.xht "css/css-conditional/css-supports-017.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-017.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-017.xht)
 - [css-supports-018.xht](https://wpt.fyi/results/css/css-conditional/css-supports-018.xht "css/css-conditional/css-supports-018.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-018.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-018.xht)

 ------------------------------------------------------------------------

[\<supports-in-parens\>](#typedef-supports-in-parens) \[ and [\<supports-in-parens\>] \]\*

: The result is true if all of the
 [\<supports-in-parens\>](#typedef-supports-in-parens) child terms are true, and false
 otherwise.

 Tests

 And condition is true iff all linked conditions are true.

 - [at-supports-007.html](https://wpt.fyi/results/css/css-conditional/at-supports-007.html "css/css-conditional/at-supports-007.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-007.html)
 - [at-supports-010.html](https://wpt.fyi/results/css/css-conditional/at-supports-010.html "css/css-conditional/at-supports-010.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-010.html)
 - [at-supports-012.html](https://wpt.fyi/results/css/css-conditional/at-supports-012.html "css/css-conditional/at-supports-012.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-012.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-012.html)
 - [css-supports-008.xht](https://wpt.fyi/results/css/css-conditional/css-supports-008.xht "css/css-conditional/css-supports-008.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-008.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-008.xht)
 - [css-supports-009.xht](https://wpt.fyi/results/css/css-conditional/css-supports-009.xht "css/css-conditional/css-supports-009.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-009.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-009.xht)
 - [css-supports-010.xht](https://wpt.fyi/results/css/css-conditional/css-supports-010.xht "css/css-conditional/css-supports-010.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-010.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-010.xht)
 - [css-supports-012.xht](https://wpt.fyi/results/css/css-conditional/css-supports-012.xht "css/css-conditional/css-supports-012.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-012.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-012.xht)

 ------------------------------------------------------------------------

 And requires parentheses.

 - [css-supports-019.xht](https://wpt.fyi/results/css/css-conditional/css-supports-019.xht "css/css-conditional/css-supports-019.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-019.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-019.xht)

 ------------------------------------------------------------------------

[\<supports-in-parens\>](#typedef-supports-in-parens) \[ or [\<supports-in-parens\>] \]\*

: The result is false if all of the
 [\<supports-in-parens\>](#typedef-supports-in-parens) child terms are false, and true
 otherwise.

 Tests

 Or condition is true iff any of linked conditions is true.

 - [at-supports-008.html](https://wpt.fyi/results/css/css-conditional/at-supports-008.html "css/css-conditional/at-supports-008.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-008.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-008.html)
 - [at-supports-010.html](https://wpt.fyi/results/css/css-conditional/at-supports-010.html "css/css-conditional/at-supports-010.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-010.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-010.html)
 - [at-supports-013.html](https://wpt.fyi/results/css/css-conditional/at-supports-013.html "css/css-conditional/at-supports-013.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-013.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-013.html)
 - [css-supports-006.xht](https://wpt.fyi/results/css/css-conditional/css-supports-006.xht "css/css-conditional/css-supports-006.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-006.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-006.xht)
 - [css-supports-007.xht](https://wpt.fyi/results/css/css-conditional/css-supports-007.xht "css/css-conditional/css-supports-007.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-007.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-007.xht)
 - [css-supports-011.xht](https://wpt.fyi/results/css/css-conditional/css-supports-011.xht "css/css-conditional/css-supports-011.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-011.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-011.xht)
 - [css-supports-021.xht](https://wpt.fyi/results/css/css-conditional/css-supports-021.xht "css/css-conditional/css-supports-021.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-021.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-021.xht)

 ------------------------------------------------------------------------

 Or must be followed by space.

 - [at-supports-043.html](https://wpt.fyi/results/css/css-conditional/at-supports-043.html "css/css-conditional/at-supports-043.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-043.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-043.html)
 - [css-supports-039.xht](https://wpt.fyi/results/css/css-conditional/css-supports-039.xht "css/css-conditional/css-supports-039.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-039.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-039.xht)

 ------------------------------------------------------------------------

 Or requires parentheses.

 - [css-supports-029.xht](https://wpt.fyi/results/css/css-conditional/css-supports-029.xht "css/css-conditional/css-supports-029.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-029.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-029.xht)
 - [css-supports-030.xht](https://wpt.fyi/results/css/css-conditional/css-supports-030.xht "css/css-conditional/css-supports-030.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-030.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-030.xht)

 ------------------------------------------------------------------------

[\<supports-decl\>](#typedef-supports-decl)

: The result is true if the UA
 [supports](#dfn-support) the
 declaration within the parentheses.

 Tests

 Supports condition is true iff declaration is supported.

 - [at-supports-001.html](https://wpt.fyi/results/css/css-conditional/at-supports-001.html "css/css-conditional/at-supports-001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-001.html)
 - [at-supports-017.html](https://wpt.fyi/results/css/css-conditional/at-supports-017.html "css/css-conditional/at-supports-017.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-017.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-017.html)
 - [at-supports-018.html](https://wpt.fyi/results/css/css-conditional/at-supports-018.html "css/css-conditional/at-supports-018.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-018.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-018.html)
 - [css-supports-001.xht](https://wpt.fyi/results/css/css-conditional/css-supports-001.xht "css/css-conditional/css-supports-001.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-001.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-001.xht)

 ------------------------------------------------------------------------

 Declaration cannot include semicolon.

 - [at-supports-038.html](https://wpt.fyi/results/css/css-conditional/at-supports-038.html "css/css-conditional/at-supports-038.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-038.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-038.html)
 - [at-supports-039.html](https://wpt.fyi/results/css/css-conditional/at-supports-039.html "css/css-conditional/at-supports-039.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-039.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-039.html)

 ------------------------------------------------------------------------

 Declaration value can be empty.

 - [css-supports-022.xht](https://wpt.fyi/results/css/css-conditional/css-supports-022.xht "css/css-conditional/css-supports-022.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-022.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-022.xht)

 ------------------------------------------------------------------------

 Declaration cannot include invalid !tokens.

 - [css-supports-043.xht](https://wpt.fyi/results/css/css-conditional/css-supports-043.xht "css/css-conditional/css-supports-043.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-043.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-043.xht)
 - [css-supports-044.xht](https://wpt.fyi/results/css/css-conditional/css-supports-044.xht "css/css-conditional/css-supports-044.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-044.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-044.xht)
 - [css-supports-045.xht](https://wpt.fyi/results/css/css-conditional/css-supports-045.xht "css/css-conditional/css-supports-045.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-045.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-045.xht)

 ------------------------------------------------------------------------

[\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed)

: The result is false.

 Authors must not use
 [\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) in their stylesheets. [It exists
 only for future-compatibility, so that new syntax additions do not
 invalidate too much of a
 [\<supports-condition\>](#typedef-supports-condition) in older user agents.]

 Tests

 Unrecognized but grammatically-valid condition is false, not
 invalid.

 - [at-supports-015.html](https://wpt.fyi/results/css/css-conditional/at-supports-015.html "css/css-conditional/at-supports-015.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-015.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-015.html)
 - [at-supports-046.html](https://wpt.fyi/results/css/css-conditional/at-supports-046.html "css/css-conditional/at-supports-046.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-046.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-046.html)
 - [css-supports-023.xht](https://wpt.fyi/results/css/css-conditional/css-supports-023.xht "css/css-conditional/css-supports-023.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-023.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-023.xht)
 - [css-supports-031.xht](https://wpt.fyi/results/css/css-conditional/css-supports-031.xht "css/css-conditional/css-supports-031.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-031.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-031.xht)
 - [css-supports-032.xht](https://wpt.fyi/results/css/css-conditional/css-supports-032.xht "css/css-conditional/css-supports-032.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-032.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-032.xht)
 - [css-supports-033.xht](https://wpt.fyi/results/css/css-conditional/css-supports-033.xht "css/css-conditional/css-supports-033.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-033.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-033.xht)
 - [css-supports-034.xht](https://wpt.fyi/results/css/css-conditional/css-supports-034.xht "css/css-conditional/css-supports-034.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-034.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-034.xht)
 - [css-supports-036.xht](https://wpt.fyi/results/css/css-conditional/css-supports-036.xht "css/css-conditional/css-supports-036.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-036.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-036.xht)
 - [css-supports-040.xht](https://wpt.fyi/results/css/css-conditional/css-supports-040.xht "css/css-conditional/css-supports-040.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-040.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-040.xht)
 - [css-supports-041.xht](https://wpt.fyi/results/css/css-conditional/css-supports-041.xht "css/css-conditional/css-supports-041.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-041.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-041.xht)
 - [css-supports-042.xht](https://wpt.fyi/results/css/css-conditional/css-supports-042.xht "css/css-conditional/css-supports-042.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-042.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-042.xht)
 - [css-supports-046.xht](https://wpt.fyi/results/css/css-conditional/css-supports-046.xht "css/css-conditional/css-supports-046.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-046.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-046.xht)

 ------------------------------------------------------------------------

 Brackets/parenthesis must be balanced

 - [css-supports-035.xht](https://wpt.fyi/results/css/css-conditional/css-supports-035.xht "css/css-conditional/css-supports-035.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-035.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-035.xht)

 ------------------------------------------------------------------------

The condition of the
[\@supports](#at-ruledef-supports) rule is the result of the
[\<supports-condition\>](#typedef-supports-condition) in its prelude.

For example, the following rule

``` highlight
@supports ( display: flex ) {
 body, #navigation, #content { display: flex; }
 #navigation { background: blue; color: white; }
 #article { background: white; color: black; }
}
```

applies the rules inside the
[\@supports](#at-ruledef-supports) rule only when [display:
flex](https://drafts.csswg.org/css-display-4/#propdef-display) is supported.

The following example shows an
additional
[\@supports](#at-ruledef-supports) rule that can be used to provide an alternative for
when [display:
flex](https://drafts.csswg.org/css-display-4/#propdef-display) is not supported:

``` highlight
@supports not ( display: flex ) {
 body { width: 100%; height: 100%; background: white; color: black; }
 #navigation { width: 25%; }
 #article { width: 75%; }
}
```

Note that the
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) declarations may be harmful to the
flex-based layout, so it is important that they be present only in the
non-flex styles.

The following example checks for
support for the
[box-shadow](https://drafts.csswg.org/css-backgrounds-3/#propdef-box-shadow) property, including checking for
support for vendor-prefixed versions of it. When the support is present,
it specifies both [box-shadow]
(with the prefixed versions) and
[border](https://drafts.csswg.org/css-backgrounds-3/#propdef-border) in a way what would cause the box
to become invisible were [box-shadow] not supported.

``` highlight
.noticebox {
 border: 1px solid black;
 padding: 1px;
}
@supports ( box-shadow: 0 0 2px black inset ) or
 ( -moz-box-shadow: 0 0 2px black inset ) or
 ( -webkit-box-shadow: 0 0 2px black inset ) or
 ( -o-box-shadow: 0 0 2px black inset ) {
 .noticebox {
 -moz-box-shadow: 0 0 2px black inset;
 -webkit-box-shadow: 0 0 2px black inset;
 -o-box-shadow: 0 0 2px black inset;
 box-shadow: 0 0 2px black inset; /* unprefixed last */
 /* override the rule above the @supports rule */
 border: none;
 padding: 2px;
 }
}
```

To avoid confusion between [and] and [or], the syntax
requires that both [and] and [or] be specified explicitly
(rather than, say, using commas or spaces for one of them). Likewise, to
avoid confusion caused by precedence rules, the syntax does not allow
[and], [or], and [not] operators to be mixed without a
layer of parentheses.

For example, the following rule is not
valid:

```
@supports (transition-property: color) or
 (animation-name: foo) and
 (transform: rotate(10deg)) {
 /* ... */
}
```

Instead, authors must write one of the following:

``` highlight
@supports ((transition-property: color) or
 (animation-name: foo)) and
 (transform: rotate(10deg)) {
 /* ... */
}
```

``` highlight
@supports (transition-property: color) or
 ((animation-name: foo) and
 (transform: rotate(10deg))) {
 /* ... */
}
```

Parentheses are required to mix operators.

- [at-supports-016.html](https://wpt.fyi/results/css/css-conditional/at-supports-016.html "css/css-conditional/at-supports-016.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-016.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-016.html)
- [css-supports-013.xht](https://wpt.fyi/results/css/css-conditional/css-supports-013.xht "css/css-conditional/css-supports-013.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-013.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-013.xht)
- [css-supports-014.xht](https://wpt.fyi/results/css/css-conditional/css-supports-014.xht "css/css-conditional/css-supports-014.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-014.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-014.xht)

------------------------------------------------------------------------

The declaration being tested must always occur within parentheses, when
it is the only thing in the expression.

For example, the following rule is not
valid:

```
@supports display: flex {
 /* ... */
}
```

Instead, authors must write:

``` highlight
@supports (display: flex) {
 /* ... */
}
```

Parentheses are required around declaration test.

- [at-supports-011.html](https://wpt.fyi/results/css/css-conditional/at-supports-011.html "css/css-conditional/at-supports-011.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-011.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-011.html)
- [at-supports-034.html](https://wpt.fyi/results/css/css-conditional/at-supports-034.html "css/css-conditional/at-supports-034.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-034.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-034.html)
- [at-supports-035.html](https://wpt.fyi/results/css/css-conditional/at-supports-035.html "css/css-conditional/at-supports-035.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-035.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-035.html)
- [at-supports-036.html](https://wpt.fyi/results/css/css-conditional/at-supports-036.html "css/css-conditional/at-supports-036.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-036.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-036.html)
- [at-supports-037.html](https://wpt.fyi/results/css/css-conditional/at-supports-037.html "css/css-conditional/at-supports-037.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-037.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-037.html)
- [css-supports-002.xht](https://wpt.fyi/results/css/css-conditional/css-supports-002.xht "css/css-conditional/css-supports-002.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-002.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-002.xht)

------------------------------------------------------------------------

The syntax allows extra parentheses when they are not needed. This
flexibility is sometimes useful for authors (for example, when
commenting out parts of an expression) and may also be useful for
authoring tools.

For example, authors may write:

``` highlight
@supports ((display: flex)) {
 /* ... */
}
```

Extra parentheses are allowed.

- [at-supports-006.html](https://wpt.fyi/results/css/css-conditional/at-supports-006.html "css/css-conditional/at-supports-006.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-006.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-006.html)
- [css-supports-003.xht](https://wpt.fyi/results/css/css-conditional/css-supports-003.xht "css/css-conditional/css-supports-003.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-003.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-003.xht)

------------------------------------------------------------------------

A trailing [!important] on a declaration being tested is allowed,
though it won't change the validity of the declaration.

For example, the following rule is
valid:

``` highlight
@supports (display: flex !important) {
 /* ... */
}
```

!important is allowed.

- [at-supports-007.html](https://wpt.fyi/results/css/css-conditional/at-supports-007.html "css/css-conditional/at-supports-007.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-007.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-007.html)
- [css-supports-004.xht](https://wpt.fyi/results/css/css-conditional/css-supports-004.xht "css/css-conditional/css-supports-004.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-004.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-004.xht)

------------------------------------------------------------------------

### 6.1. Definition of support

For forward-compatibility, [section 4.1.8 (Declarations and
properties)](https://www.w3.org/TR/CSS21/syndata.html#declaration) of
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
defines rules for handling invalid properties and values. CSS processors
that do not implement or partially implement a specification **must**
treat any part of a value that they do not implement, or do not have a
usable level of support for, as invalid according to this rule for
handling invalid properties and values, and therefore **must** discard
the declaration as a parse error.

A CSS processor is considered to [support] a declaration
(consisting of a property and value) if it accepts that declaration
(rather than discarding it as a parse error) within a [style
rule](https://drafts.csswg.org/css-syntax-3/#style-rule). If a processor does not implement, with a usable level
of support, both the property and the value given, then it **must not**
accept the declaration or claim support for it.

 Note that properties or values whose support is
effectively disabled by user preferences are still considered as
supported by this definition. For example, if a user has enabled a
high-contrast mode that causes colors to be overridden, the CSS
processor is still considered to support the
[color](https://drafts.csswg.org/css-color-4/#propdef-color) property even though declarations
of the [color] property may have no
effect. On the other hand, a developer-facing preference whose purpose
is to enable or disable support for an experimental CSS feature does
affect this definition of support.

These rules (and the equivalence between them) allow authors to use
fallback (either in the
[\[CSS1\]](#biblio-css1 "Cascading Style Sheets, level 1")
sense of declarations that are overridden by later declarations or with
the new capabilities provided by the
[\@supports](#at-ruledef-supports) rule in this specification) that works correctly for
the features implemented. This applies especially to compound values;
implementations must implement all parts of the value in order to
consider the declaration supported, either inside a style rule or in the
declaration condition of an [\@supports] rule.

Tests

Supports queries are true iff property declaration (including all
values) is parsed/supported.

- [css-supports-005.xht](https://wpt.fyi/results/css/css-conditional/css-supports-005.xht "css/css-conditional/css-supports-005.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-005.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-005.xht)
- [css-supports-020.xht](https://wpt.fyi/results/css/css-conditional/css-supports-020.xht "css/css-conditional/css-supports-020.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-020.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-020.xht)
- [css-supports-024.xht](https://wpt.fyi/results/css/css-conditional/css-supports-024.xht "css/css-conditional/css-supports-024.xht")
 [[(live
 test)]](http://wpt.live/css/css-conditional/css-supports-024.xht)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/css-supports-024.xht)
- [CSS-supports-CSSStyleDeclaration.html](https://wpt.fyi/results/css/css-conditional/js/CSS-supports-CSSStyleDeclaration.html "css/css-conditional/js/CSS-supports-CSSStyleDeclaration.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/CSS-supports-CSSStyleDeclaration.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/CSS-supports-CSSStyleDeclaration.html)
- [at-supports-044.html](https://wpt.fyi/results/css/css-conditional/at-supports-044.html "css/css-conditional/at-supports-044.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/at-supports-044.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/at-supports-044.html)

------------------------------------------------------------------------

## 7. APIs

Tests

- [idlharness.html](https://wpt.fyi/results/css/css-conditional/idlharness.html "css/css-conditional/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/idlharness.html)
- [001.html](https://wpt.fyi/results/css/css-conditional/js/001.html "css/css-conditional/js/001.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/001.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/001.html)

### 7.1. Extensions to the `CSSRule` interface

The `CSSRule` interface is extended as follows:

```
partial interface CSSRule {
 const unsigned short SUPPORTS_RULE = 12;

};
```

Tests

CSSRule.SUPPORTS_RULE = 12

- [conditional-CSSGroupingRule.html](https://wpt.fyi/results/css/css-conditional/js/conditional-CSSGroupingRule.html "css/css-conditional/js/conditional-CSSGroupingRule.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/conditional-CSSGroupingRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/conditional-CSSGroupingRule.html)

------------------------------------------------------------------------

### 7.2. The `CSSConditionRule` interface

The
[`CSSConditionRule`](#cssconditionrule) interface represents all the "conditional" at-rules,
which consist of a condition and a statement block.

```
[Exposed=Window]
interface CSSConditionRule : CSSGroupingRule {
 readonly attribute CSSOMString conditionText;
};
```

Tests

CSSConditionRule inherits from CSSGroupingRule.

- [conditional-CSSGroupingRule.html](https://wpt.fyi/results/css/css-conditional/js/conditional-CSSGroupingRule.html "css/css-conditional/js/conditional-CSSGroupingRule.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/conditional-CSSGroupingRule.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/conditional-CSSGroupingRule.html)

------------------------------------------------------------------------

CSSConditionRule has .conditionText attribute.

- [supports-conditionText.html](https://wpt.fyi/results/css/css-conditional/js/supports-conditionText.html "css/css-conditional/js/supports-conditionText.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/supports-conditionText.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/supports-conditionText.html)

------------------------------------------------------------------------

`conditionText` of type `CSSOMString`

: The `conditionText` attribute represents the condition
 of the rule. Since what this condition does varies between the
 derived interfaces of `CSSConditionRule`, those derived
 interfaces may specify different behavior for this attribute (see,
 for example, `CSSMediaRule` below). In the absence of
 such rule-specific behavior, the following rules apply:

 The `conditionText` attribute, on getting, must return
 the result of serializing the associated condition.

 Tests

 .conditionText returns serialization of condition.

 - [supports-conditionText.html](https://wpt.fyi/results/css/css-conditional/js/supports-conditionText.html "css/css-conditional/js/supports-conditionText.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/supports-conditionText.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/supports-conditionText.html)

 ------------------------------------------------------------------------

### 7.3. The `CSSMediaRule` interface

The [`CSSMediaRule`](#cssmediarule) interface represents a
[\@media](#at-ruledef-media) at-rule:

```
[Exposed=Window]
interface CSSMediaRule : CSSConditionRule {
 [SameObject, PutForwards=mediaText] readonly attribute MediaList media;
 readonly attribute boolean matches;
};
```

Tests

CSSMediaRule represents an \@media rule.

- [idlharness.html](https://wpt.fyi/results/css/css-conditional/idlharness.html "css/css-conditional/idlharness.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/idlharness.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/idlharness.html)

------------------------------------------------------------------------

`media` of type [`MediaList`](https://drafts.csswg.org/cssom-1/#medialist), readonly

: The `media` attribute must return a
 [`MediaList`](https://drafts.csswg.org/cssom-1/#medialist) object for the list of media queries specified with
 the [\@media](#at-ruledef-media) at-rule.

 Tests

 .media returns a MediaList matching the \@media condition.

 ------------------------------------------------------------------------

`matches` of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: The `matches` attribute returns true if the rule is in
 an stylesheet attached to a document whose
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) matches this rule's
 [`media`](#dom-cssmediarule-media) [media
 query](https://drafts.csswg.org/mediaqueries-5/#media-query), and returns false otherwise.

 Tests

 .matches matches the media query, returns boolean.

 ------------------------------------------------------------------------

`conditionText` of type `CSSOMString` (CSSMediaRule-specific definition for attribute on CSSConditionRule)

: The `conditionText` attribute (defined on the
 `CSSConditionRule` parent rule), on getting, must return
 the value of `media.mediaText` on the rule.

 Tests

 Value of CSSMediaRule.conditionText matches value of
 media.mediaText.

 ------------------------------------------------------------------------

### 7.4. The `CSSSupportsRule` interface

The [`CSSSupportsRule`](#csssupportsrule) interface represents a
[\@supports](#at-ruledef-supports) rule.

```
[Exposed=Window]
interface CSSSupportsRule : CSSConditionRule {
 readonly attribute boolean matches;
};
```

`matches` of type [`boolean`](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: The `matches` attribute returns the evaluation of the
 [CSS feature
 query](#css-feature-queries) represented in
 [`conditionText`](#dom-cssconditionrule-conditiontext).

 Tests

 CSSSupportsRule.matches returns true if matches feature query

 ------------------------------------------------------------------------

`conditionText` of type `CSSOMString` (CSSSupportsRule-specific definition for attribute on CSSConditionRule)

: The `conditionText` attribute (defined on the
 `CSSConditionRule` parent rule), on getting, must return
 the condition that was specified, without any logical
 simplifications, so that the returned condition will evaluate to the
 same result as the specified condition in any conformant
 implementation of this specification (including implementations that
 implement future extensions allowed by the
 [\<general-enclosed\>](https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed) extensibility mechanism in this
 specification). In other words, token stream simplifications are
 allowed (such as reducing whitespace to a single space or omitting
 it in cases where it is known to be optional), but logical
 simplifications (such as removal of unneeded parentheses, or
 simplification based on evaluating results) are not allowed.

 Tests

 CSSSupportsRule.conditionText can have tokenization simplifications.

 ------------------------------------------------------------------------

 CSSSupportsRule.conditionText cannot have other simplifications.

 ------------------------------------------------------------------------

### [7.5. ][ [The `CSS` namespace, and the `supports()` function]]
The
[`CSS`](https://drafts.csswg.org/cssom-1/#namespacedef-css) namespace holds useful CSS-related functions that do
not belong elsewhere.

```
partial namespace CSS {
 boolean supports(CSSOMString property, CSSOMString value);
 boolean supports(CSSOMString conditionText);
};
```

`supports(CSSOMString property, CSSOMString value)`, returns `boolean`

: :::
 When the
 [`supports(property, value)`](#dom-css-supports) method is invoked with two arguments
 `property` and `value`:
 1. If `property` is an [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive) match for any defined CSS property that the UA
 supports, or is a [custom property name
 string](https://drafts.css-houdini.org/css-typed-om-1/#custom-property-name-string), and `value` successfully
 [parses](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to that property's grammar, return
 `true`.

 2. Otherwise, return `false`.

 No CSS escape or whitespace processing is performed
 on the property name, so `CSS.supports(" width", "5px")`
 will return `false`, as \" width\" isn't the name of any
 property due to the leading space.

 [!important] flags are not part of property
 grammars, and will cause `value` to parse as invalid,
 just as they would in the value argument to
 [element.style.setProperty()].
 :::

 Tests

 CSS.supports(arg1, arg2) evaluates support of property arg1 with
 value arg2.

 ------------------------------------------------------------------------

`supports(CSSOMString conditionText)`, returns `boolean`

: :::
 When the
 [`supports(conditionText)`](#dom-css-supports-conditiontext) method is invoked with a single
 `conditionText` argument:
 1. If `conditionText`,
 [parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) and evaluated as a
 [\<supports-condition\>](#typedef-supports-condition), would return true, return
 `true`.

 2. Otherwise, If `conditionText`, wrapped in parentheses
 and then
 [parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) and evaluated as a
 [\<supports-condition\>](#typedef-supports-condition), would return true, return
 `true`.

 3. Otherwise, return `false`.

 All namespaces in the `conditionText` argument are
 considered invalid, just as they are in
 `document.querySelector("a|b")`.
 :::

 Tests

 CSS.supports(arg1) evaluates supports condition arg1.

 ------------------------------------------------------------------------

 CSS.supports(arg1) implies parentheses.

 - [supports-conditionText.html](https://wpt.fyi/results/css/css-conditional/js/supports-conditionText.html "css/css-conditional/js/supports-conditionText.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/supports-conditionText.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/supports-conditionText.html)

 ------------------------------------------------------------------------

Tests

- [CSS-supports-L3.html](https://wpt.fyi/results/css/css-conditional/js/CSS-supports-L3.html "css/css-conditional/js/CSS-supports-L3.html")
 [[(live
 test)]](http://wpt.live/css/css-conditional/js/CSS-supports-L3.html)
 [[(source)]](https://github.com/web-platform-tests/wpt/blob/master/css/css-conditional/js/CSS-supports-L3.html)

## [Security Considerations]
No security issues have been raised against this document

## [Privacy Considerations]
Various features in this specification, associated mainly with the
[\@media](#at-ruledef-media) rule but also to some degree with the
[\@supports](#at-ruledef-supports) rule, provide information to Web content about the
user's hardware and software and their configuration and state. Most of
the information is provided through the features in
[\[MEDIAQUERIES-4\]](#biblio-mediaqueries-4 "Media Queries Level 4")
rather than through the features in this specification. However, the
[\@supports] rule may provide some
additional details about the user's software and whether it is running
with non-default settings that may enable or disable certain features.

Most of this information can also be determined through other APIs.
However, the features in this specification are one of the ways this
information is exposed on the Web.

This information can also, in aggregate, be used to improve the accuracy
of
[fingerprinting](https://www.w3.org/2001/tag/doc/unsanctioned-tracking/)
of the user.

## 8. Changes

The following (non-editorial) changes were made to this specification
since the [15 August 2024 Candidate Recommendation
Draft](https://www.w3.org/TR/2024/CRD-css-conditional-3-20240815/):

- *none*

The following (non-editorial) changes were made to this specification
since the [13 January 2022 Candidate Recommendation
Snapshot](https://www.w3.org/TR/2022/CR-css-conditional-3-20220113/):

- Clarified that supports() must return false for invalid custom
 property values
- Fixed Web IDL, \"bool\" should have been \"boolean\"
- Clarified that a processor must support both the property and the
 value ([Issue 8795](https://github.com/w3c/csswg-drafts/issues/8795))
- Added .matches to \@media and \@supports ([Issue
 4240](https://github.com/w3c/csswg-drafts/issues/4240))
- Updated to the new parsing algo names and block production names.
- Removed procedure to set readonly CSSMediaRule.conditionText ([PR
 8796](https://github.com/w3c/csswg-drafts/pull/8796))
- Made conditionText readonly.

The following (non-editorial) changes were made to this specification
since the [8 December 2020 Candidate Recommendation
Snapshot](https://www.w3.org/TR/2020/CR-css-conditional-3-20201208/):

- Clarified that discarding property declarations only applies to style
 rules, not at-rules

- Clarified that !important is not part of the property grammar

- Split Security and Privacy into separate sections

- Defined the terms [CSS feature
 queries](#css-feature-queries) and [supports
 queries](#supports-queries)
 to refer to the conditional syntax of the
 [\@supports](#at-ruledef-supports) rules, to allow better cross-referencing.

- Removed the "unknown" value in [CSS feature
 queries](#css-feature-queries)' boolean logic, defining unrecognized syntaxes as
 "false" instead. ([Issue
 6175](https://github.com/w3c/csswg-drafts/issues/6175))

- Clarified [placement](#use) of [conditional group
 rules](#conditional-group-rule). ([Issue
 5697](https://github.com/w3c/csswg-drafts/issues/5697))

 > Conditional group rules are allowed [wherever style rules are
 > allowed (] at the top-level of a style sheet, ~~and
 > inside~~ [as well as within] other conditional group
 > rules [)] . CSS processors must process such rules as
 > described above.
 >
 > Any [at-] rules that are not allowed after a style rule
 > (e.g., \@charset , \@import , or \@namespace rules) are also not
 > allowed after a conditional group rule ~~. Therefore, style sheets
 > must not place such rules after a conditional group rule, and CSS
 > processors must ignore such rules.~~ [, and are therefore invalid
 > when so placed.]

The following (non-editorial) changes were made to this specification
since the [4 April 2013 Candidate
Recommendation](https://www.w3.org/TR/2013/CR-css3-conditional-20130404/):

- Clarified that namespaces in conditionText are invalid
- New editors added
- Added explicit call to
 [parse](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) rather than \"matches the grammar\"
- Removed duplicate CSSGroupingRule, which is already defined by CSSOM
- Rewrote the supports() text into algorithm form, to make it easier to
 express that you pay attention to the syntax of registered custom
 properties in the supports(prop, val) form.
- Moved the definition of \@supports selector to css-conditional-4.
- [\@supports](#at-ruledef-supports)\' is no longer at risk.
- Rewrote to use CSS Syntax grammars, not CSS 2.1 grammars
- Changed from CSS Interface to WebIDL-compatible CSS namespace
- Dropped requirement for spaces around [and], [or], and
 [not](https://drafts.csswg.org/mediaqueries-5/#valdef-media-not) keywords for consistency with [Media
 Queries](http://www.w3.org/TR/css3-mediaqueries/) (which are
 themselves constrained by compatibility with the output of some CSS
 minimizers that rely on some of the more arcane aspects of CSS
 tokenization). Note that white space\--or a comment\--is still
 required *after* these keywords, since without it they and the ensuing
 opening parenthesis will be tokenized as a function opening token.
- Allowed the `supports()` method to imply
 parentheses for simple declarations, for consistency with the \@import
 rule's supports() function.
- Fixed missing semicolons in IDL code.
- Updated links, terminology, and example code in response to changes to
 other modules.
- Spelling and grammatical corrections
- Added section on privacy and security considerations.

## [Acknowledgments]
Thanks to the ideas and feedback from Tab Atkins, Arthur Barstow, Ben
Callahan, [Tantek Çelik]{lang="tr"}, Alex Danilo, Elika Etemad, Pascal
Germroth, [Björn Höhrmann]{lang="de"}, Paul Irish, Brad Kemper, [Anne
van Kesteren]{lang="nl"}, Vitor Menezes, Alex Mogilevsky, Chris
Moschini, James Nurthen, Simon Pieters, [Florian Rivoal]{lang="fr"},
[Simon Sapin]{lang="fr"}, Nicholas Shanks, Ben Ward, Zack Weinberg,
Estelle Weyl, Boris Zbarsky, and all the rest of the
[www-style](http://lists.w3.org/Archives/Public/www-style/) community.
