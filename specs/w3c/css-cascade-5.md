## 1. Introduction

CSS defines a finite set of parameters, called
[properties], that direct the rendering of a
document. Each [property](#css-property) has a name (e.g.,
[color](https://drafts.csswg.org/css-color-4/#propdef-color),
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size), or
[border-style](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-style)), a value space (e.g.,
[\<color\>](https://drafts.csswg.org/css-color-5/#typedef-color),
[\<length-percentage\>](https://drafts.csswg.org/css-values-4/#typedef-length-percentage), [\[ solid \| dashed \| dotted \| ...
\]]), and a defined behavior on the rendering of the document.
Properties values are assigned to various parts of the document via
[property
declarations](https://drafts.csswg.org/css-syntax-3/#css-property-declarations), which assign the property a value (e.g.
[red](https://drafts.csswg.org/css-color-4/#valdef-color-red), [12pt],
[dotted](https://drafts.csswg.org/css-backgrounds-3/#valdef-line-style-dotted)) for the associated element or box.

One of the fundamental design principles of CSS is
[cascading](#cascade), which allows
several style sheets to influence the presentation of a document. When
different
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) try to set a value for the same element/property
combination, the conflicts must somehow be resolved.

The opposite problem arises when no
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) try to set a value for an element/property combination.
In this case, a value is be found by way of
[inheritance](#css-inheritance) or by looking at the property's [initial
value](#initial-value).

The [cascading](#cascade) and
[defaulting](#defaulting) process takes a set of
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) as input, and outputs a [specified
value](#specified-value) for
each property on each element.

The rules for finding the specified value for all properties on all
elements in the document are described in this specification. The rules
for finding the specified values in the page context and its margin
boxes are described in
[\[css-page-3\]](#biblio-css-page-3 "CSS Paged Media Module Level 3").

### 1.1. Module Interactions

*This section is normative.*

This module replaces and extends the rules for assigning property
values, cascading, and inheritance defined in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
chapter 6.

Other CSS modules may expand the definitions of some of the syntax and
features defined here. For example, the Media Queries Level 4
specification, when combined with this module, expands the definition of
the
[\<media-query\>](https://drafts.csswg.org/mediaqueries-4/#typedef-media-query) value type as used in this
specification.

For the purpose of this specification, [text
nodes](https://drafts.csswg.org/css-display-4/#text-nodes) are treated as
[element](https://drafts.csswg.org/css-display-3/#elements) children of their associated element, and possess the
full set of properties; since they cannot be targeted by selectors all
of their computed values are assigned by [defaulting](#defaulting).

## 2. Importing Style Sheets: the [\@import rule]
The [\@import] rule allows users to import style rules
from other style sheets. If an
[\@import](#at-ruledef-import) rule refers to a valid stylesheet, user agents must
treat the contents of the stylesheet as if they were written in place of
the [\@import] rule, with two
exceptions:

- If a feature (such as the
 [\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rule) *explicitly* defines that it only
 applies to a particular stylesheet, and not any imported ones, then it
 doesn't apply to the imported stylesheet.

- If a feature relies on the relative ordering of two or more constructs
 in a stylesheet (such as the requirement that
 [\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules must not have any other rules other than
 [\@import](#at-ruledef-import) preceding it), it only applies between constructs
 in the same stylesheet.

For example,
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) in style rules from imported stylesheets interact with
the cascade as if they were written literally into the stylesheet at the
point of the [\@import](#at-ruledef-import).

Any [\@import](#at-ruledef-import) rules must precede all other valid at-rules and style
rules in a style sheet (ignoring
[\@charset](https://drafts.csswg.org/css-syntax-3/#at-ruledef-charset),
[\@supports-condition](https://drafts.csswg.org/css-conditional-5/#at-ruledef-supports-condition), and [[\@layer] statement](#layer-empty)
rules) and must not have any other valid at-rules or style rules between
it and previous [\@import] rules, or
else the [\@import] rule is invalid.
The syntax of [\@import] is:

``` prod
@import [ <url> | <string> ]
 [ layer | layer(<layer-name>) ]?
 <import-conditions> ;

<import-conditions> = [ supports( [ <supports-condition> | <declaration> ] ) ]?
 <media-query-list>?
```

where:

- the
 [\<url\>](https://drafts.csswg.org/css-values-4/#url-value) or
 [\<string\>](https://drafts.csswg.org/css-values-4/#string-value) gives the URL of the style sheet to
 be imported.

- the optional [layer] keyword or [layer()] function assigns
 the contents of the style sheet into its own anonymous [cascade
 layer](#cascade-layers) or
 into the named [cascade layer].

 The layer is added to the [layer order](#layer-ordering) even if the
 import fails to load the stylesheet, but is subject to any [import
 conditions](#import-conditions) (just as if declared by an
 [\@layer](#at-ruledef-layer) rule wrapped in the appropriate [conditional group
 rules](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule)).

- the optional
 [\<import-conditions\>](#typedef-import-conditions) states the [import
 conditions](#import-conditions) under which it applies.

The following [conditional
[\@import] rule](#conditional-import) only loads the style sheet
when the UA
[supports](https://www.w3.org/TR/css-conditional-3/#support-definition)
[display:
flex](https://drafts.csswg.org/css-display-4/#propdef-display), and only applies the style sheet on a
[handheld](https://www.w3.org/TR/CSS2/media.html#media-types) device
with a [maximum viewport
width](https://www.w3.org/TR/mediaqueries-4/#width) of 400px.

 @import url("narrow.css") supports(display: flex) handheld and (max-width: 400px);

The following layer imports load the
style sheets into the [framework.component] layer, and an un-named
layer, respectively:

 @import url("tabs.css") layer(framework.component);
 @import url("override.css") layer;

If a
[\<string\>](https://drafts.csswg.org/css-values-4/#string-value) is provided, it must be interpreted
as a
[\<url\>](https://drafts.csswg.org/css-values-4/#url-value) with the same value.

The following lines are equivalent in
meaning and illustrate both
[\@import](#at-ruledef-import) syntaxes (one with
[url()](https://drafts.csswg.org/css-values-4/#funcdef-url) and one with a bare string):

```
@import "mystyle.css";
@import url("mystyle.css");
```

### 2.1. Conditional [\@import Rules]
[Import conditions] allow the import to be media-- or feature-support--dependent.
In the absence of any [import
conditions](#import-conditions), the import is unconditional. (Specifying [all]
for the
[\<media-query-list\>](https://drafts.csswg.org/mediaqueries-4/#typedef-media-query-list) has the same effect.) If the [import
conditions] do not match, the rules in the
imported stylesheet do not apply, exactly as if the imported stylesheet
were wrapped in
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) and/or
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports) blocks with the given conditions.

The following rules illustrate how
[\@import](#at-ruledef-import) rules can be made media-dependent:

```
@import url("fineprint.css") print;
@import url("bluish.css") projection, tv;
@import url("narrow.css") handheld and (max-width: 400px);
```

User agents may therefore avoid fetching a conditional import as long as
the [import conditions](#import-conditions) do not match. Additionally, if a
[\<supports-condition\>](https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition) blocks the application of the
imported style sheet, the UA *must not* fetch the style sheet (unless it
is loaded through some other link) and *must* return null for the import
rule's CSSImportRule.styleSheet value (even if it is loaded through some
other link).

The following rule illustrates how an
author can provide fallback rules for legacy user agents without
impacting network performance on newer user agents:

```
@import url("fallback-layout.css") supports(not (display: flex));
@supports (display: flex) {
 ...
}
```

The [import conditions](#import-conditions) are given by
[\<media-query-list\>](https://drafts.csswg.org/mediaqueries-4/#typedef-media-query-list), which is parsed and interpreted as a
[media query
list](https://drafts.csswg.org/mediaqueries-4/#media-query-list), and
[\<supports-condition\>](https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition), is parsed and interpreted as a
[supports
query](https://drafts.csswg.org/css-conditional-3/#supports-queries). If a
[\<declaration\>](https://drafts.csswg.org/css-conditional-5/#typedef-declaration) is given in place of a
[\<supports-condition\>], it must be interpreted as a
[\<supports-decl\>](https://drafts.csswg.org/css-conditional-5/#typedef-supports-decl) (i.e. the extra set of parentheses is
implied) and treated as a
[\<supports-condition\>].

For example, the following two lines
are equivalent:

```
@import "mystyle.css" supports(display: flex);
@import "mystyle.css" supports((display: flex));
```

The evaluation and full syntax of the [import
conditions](#import-conditions) are defined by the [Media
Queries](https://www.w3.org/TR/mediaqueries/)
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
and [CSS Conditional Rules](https://www.w3.org/TR/css-conditional/)
[\[CSS-CONDITIONAL-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
specifications.

### 2.2. Processing Stylesheet Imports

When the same style sheet is imported or linked to a document in
multiple places, user agents must process (or act as though they do)
each link as though the link were to an independent style sheet.

 This does not place any requirements on resource
fetching, only how the style sheet is reflected in the CSSOM and used in
specs such as this one. Assuming appropriate caching, it is perfectly
appropriate for a UA to fetch a style sheet only once, even though it's
linked or imported multiple times.

The [cascade origin](#origin) of an
imported style sheet is the [cascade origin] of the
style sheet that imported it.

The [environment
encoding](https://drafts.csswg.org/css-syntax-3/#environment-encoding) of an imported style sheet is the encoding of the style
sheet that imported it.
[\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3")

### 2.3. Content-Type of CSS Style Sheets

The processing of imported style sheets depends on the actual type of
the linked resource:

- If the resource does not have [Content-Type
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type), the type is treated as `text/css`.

- If the host document is in [quirks
 mode](https://dom.spec.whatwg.org/#concept-document-quirks), and the host document's origin is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with the linked resource
 [response's](https://fetch.spec.whatwg.org/#concept-response)
 [URL's](https://fetch.spec.whatwg.org/#concept-response-url) origin, the type is treated as `text/css`.

- Otherwise, the type is determined from its [Content-Type
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type).

If the linked resource's type is `text/css`, it must be interpreted as a
CSS style sheet. Otherwise, it must be interpreted as a network error.

## 3. Shorthand Properties

Some properties are [shorthand properties], meaning that they allow authors to
specify the values of several properties with a single property. A
[shorthand property](#shorthand-property) sets all of its [longhand sub-properties], exactly as if
expanded in place.

When values are omitted from a
[shorthand](#shorthand-property) form, unless otherwise defined, each "missing"
[sub-property](#longhand) is assigned
its [initial value](#initial-value).

This means that a
[shorthand](#shorthand-property) [property
declaration](https://drafts.csswg.org/css-syntax-3/#css-property-declarations) always sets *all* of its
[sub-properties](#longhand), even
those that are not explicitly set. Carelessly used, this might result in
inadvertently resetting some [sub-properties].
Carefully used, a [shorthand] can
guarantee a "blank slate" by resetting
[sub-properties] inadvertently cascaded from other
sources.

For example, writing [background:
green](https://drafts.csswg.org/css-backgrounds-3/#propdef-background) rather than [background-color:
green](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-color) ensures that the background color overrides
any earlier
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) that might have set the background to an image with
[background-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-image).

For example, the CSS Level 1
[font](https://drafts.csswg.org/css-fonts-4/#propdef-font) property is a
[shorthand](#shorthand-property) property for setting
[font-style](https://drafts.csswg.org/css-fonts-4/#propdef-font-style),
[font-variant](https://drafts.csswg.org/css-fonts-4/#propdef-font-variant),
[font-weight](https://drafts.csswg.org/css-fonts-4/#propdef-font-weight),
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size),
[line-height](https://drafts.csswg.org/css2/#propdef-line-height), and
[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family) all at once. The multiple declarations of
this example:

```
h1 {
 font-weight: bold;
 font-size: 12pt;
 line-height: 14pt;
 font-family: Helvetica;
 font-variant: normal;
 font-style: normal;
}
```

can therefore be rewritten as

```
h1 { font: bold 12pt/14pt Helvetica }
```

As more
[font](https://drafts.csswg.org/css-fonts-4/#propdef-font)
[sub-properties](#longhand) are
introduced into CSS, the shorthand declaration resets those to their
initial values as well.

In some cases, a
[shorthand](#shorthand-property) might have different syntax or special keywords that
don't directly correspond to values of its
[sub-properties](#longhand). (In
such cases, the [shorthand] will
explicitly define the expansion of its values.)

In other cases, a property might be a [reset-only
sub-property] of the shorthand: Like other
[sub-properties](#longhand), it is
reset to its initial value by the shorthand when unspecified, but the
shorthand might not include syntax to set the
[sub-property] to any of its other values. [For
example, the
[border](https://drafts.csswg.org/css-backgrounds-3/#propdef-border) shorthand resets
[border-image](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-image) to its initial value of
[none], but has no syntax to set it to anything else.
[\[css-backgrounds-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3")]

If a [shorthand](#shorthand-property) is specified as one of the [CSS-wide
keywords](https://www.w3.org/TR/css-values/#common-keywords)
[\[css-values-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3"),
it sets all of its [sub-properties](#longhand) to that keyword, including any that are [reset-only
sub-properties](#reset-only-sub-property). (Note that these keywords cannot be combined with
other values in a single
[declaration](https://drafts.csswg.org/css-syntax-3/#declaration), not even in a shorthand.)

Declaring a
[shorthand](#shorthand-property) property to be [!important] is equivalent to
declaring all of its [sub-properties](#longhand) to be [!important].

### 3.1. Property Aliasing

Properties sometimes change names after being supported for a while,
such as vendor-prefixed properties being standardized. The original name
still needs to be supported for compatibility reasons, but the new name
is preferred. To accomplish this, CSS defines two different ways of
"aliasing" old syntax to new syntax.

[legacy name aliases]
: When the old property's value syntax is identical to that of the new
 property, the two names are aliased with an operation on par with
 case-mapping: at parse time, the old property is converted into the
 new property. This conversion also applies in the CSSOM, both for
 string arguments and property accessors: requests for the old
 property name transparently transfer to the new property name
 instead.
 :::
 (#example-519bf7b3) For example, if [old-name]
 is a [legacy name
 alias](#legacy-name-alias) for [new-name],
 `getComputedStyle(el).oldName` will return the computed
 style of the `newName` property, and
 `el.style.setProperty("old-name", "value")` will set the
 [new-name] property to `"value"`.
 :::

[legacy shorthands]
: When the old property has a distinct syntax from the new property,
 the two names are aliased using the
 [shorthand](#shorthand-property) mechanism. These shorthands are defined to be
 [legacy shorthands](#legacy-shorthand), and their use is *deprecated*. They otherwise
 behave exactly as regular shorthands, except that the CSSOM will not
 use them when serializing declarations.
 [\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
 :::
 (#example-c7a1887e) For example, the
 [page-break-\*] properties are [legacy
 shorthands](#legacy-shorthand) for the [break-\*] properties (see [CSS
 Fragmentation 3 § 3.4 Page Break Aliases: the page-break-before,
 page-break-after, and page-break-inside
 properties](https://drafts.csswg.org/css-break-3/#page-break-properties)).
 Setting [page-break-before:
 always](https://drafts.csswg.org/css2/#propdef-page-break-before) expands to [break-before:
 page](https://drafts.csswg.org/css-break-3/#propdef-break-before) at parse time, like other shorthands do.
 Similarly, if [break-before: page] is set, calling
 `getComputedStyle(el).pageBreakBefore` will return
 `"always"`. However, when serializing a style block (see
 [CSSOM § 6.7.2 Serializing CSS
 Values](https://drafts.csswg.org/cssom-1/#serializing-css-values)),
 the [page-break-before] property will never be chosen as the shorthand to
 serialize to, regardless of whether it or
 [break-before] was
 specified; instead, [break-before] will always be chosen.
 :::

### 3.2. Resetting All Properties: the [all property]
Name:

[all]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

initial
[\|](https://drafts.csswg.org/css-values-4/#comb-one) inherit [\|] unset
[\|] revert [\|] revert-layer
[\|] revert-rule

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

see individual properties

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

see individual properties

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

see individual properties

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

see individual properties

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

see individual properties

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

see individual properties

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

The [all](#propdef-all) property is a
[shorthand](#shorthand-property) that resets *all* CSS properties except
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) and
[unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi). It only accepts the [CSS-wide
keywords](https://www.w3.org/TR/css-values/#common-keywords). It does
not reset [custom
properties](https://drafts.csswg.org/css-variables-2/#custom-property)
[\[css-variables-1\]](#biblio-css-variables-1 "CSS Custom Properties for Cascading Variables Module Level 1").

 The excepted CSS properties
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) and
[unicode-bidi](https://drafts.csswg.org/css-writing-modes-3/#propdef-unicode-bidi) are actually markup-level features,
and [should not be set in the author's style
sheet](https://www.w3.org/TR/css-writing-modes-3/#text-direction). (They
exist as CSS properties only to style document languages not supported
by the UA.) Authors should use the appropriate markup, such as HTML's
`dir` attribute, instead.
[\[css-writing-modes-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3")

For example, if an author specifies
[all: initial](#propdef-all) on an element, it will block all inheritance and
reset all properties, as if no rules appeared in the author, user, or
user-agent levels of the cascade.

This can be useful for the root element of a \"widget\" included in a
page, which does not wish to inherit the styles of the outer page. Note,
however, that any \"default\" style applied to that element (such as,
e.g. [display:
block](https://drafts.csswg.org/css-display-4/#propdef-display) from the UA style sheet on block elements
such as `<div>`) will also be blown away.

## 4. Value Processing

Once a user agent has parsed a document and constructed a document tree,
it must assign, to every element in the [flat
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree), and correspondingly to every box in the formatting
structure, a value to every property that applies to the target [media
type](https://drafts.csswg.org/mediaqueries-4/#media-type).

The final value of a CSS property for a given element or box is the
result of a multi-step calculation:

1. First, all the [declared
 values](#declared-value)
 applied to an element are collected, for each property on each
 element. There may be zero or many [declared
 values] applied to the element.
2. Cascading yields the [cascaded
 value](#cascaded-value).
 There is at most one [cascaded value] per
 property per element.
3. Defaulting yields the [specified
 value](#specified-value).
 Every element has exactly one [specified
 value] per property.
4. Resolving value dependencies yields the [computed
 value](#computed-value).
 Every element has exactly one [computed
 value] per property.
5. Formatting the document yields the [used
 value](#used-value). An element
 only has a [used value] for a given property
 if that property applies to the element.
6. Finally, the used value is transformed to the [actual
 value](#actual-value) based
 on constraints of the display environment. As with the [used
 value](#used-value), there may
 or may not be an [actual value] for a given
 property on an element.

Elements that are not
[connected](https://dom.spec.whatwg.org/#connected) or are not part of the document's [flattened element
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree) do not participate in CSS value processing, and do not
have [declared](#declared-value), [cascaded](#cascaded-value),
[specified](#specified-value), [computed](#computed-value), [used](#used-value), or [actual](#actual-value) values, even if they potentially have style
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) assigned to them (for example, by a `style` attribute).

### 4.1. Declared Values

Each [property
declaration](https://drafts.csswg.org/css-syntax-3/#css-property-declarations) [applied to an element](#filtering) contributes a
[declared value] for that property associated with the
element. See [Filtering Declarations](#filtering) for details.

These values are then processed by the
[cascade](#cascade) to choose a
single "winning value".

#### 4.1.1. Value Aliasing

Some property values have [legacy value aliases]: at parse time, the legacy syntax is converted
into the new syntax, resulting in a [declared
value](#declared-value)
different from the parsed input. These aliases are typically used for
handling legacy compatibility requirements, such as converting
[vendor-prefixed](https://drafts.csswg.org/css-2025/#vendor-prefix) values to their standard equivalents.

### 4.2. Cascaded Values

The [cascaded value] represents the result of [the
cascade](#cascade): it is the [declared
value](#declared-value) that
wins the cascade (is sorted first in the [output of the
cascade](#output-of-the-cascade)). If the [output of the
cascade] is an empty list, there is no
[cascaded value](#cascaded-value).

### 4.3. Specified Values

The [specified value] is the value of a given property that
the style sheet authors intended for that element. It is the result of
putting the [cascaded value](#cascaded-value) through the [defaulting](#defaulting) processes,
guaranteeing that a [specified
value](#specified-value)
exists for every property on every element.

In many cases, the [specified
value](#specified-value) is
the [cascaded value](#cascaded-value). However, if there is no [cascaded
value] at all, the [specified
value] is [defaulted](#defaulting). The
[CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) are handled specially when they are the [cascaded
value] of a property, setting the [specified
value] as required by that keyword, see
[§ 7.3 Explicit Defaulting](#defaulting-keywords).

### 4.4. Computed Values

The [computed value] is the result of resolving the [specified
value](#specified-value) as
defined in the "Computed Value" line of the property definition table,
generally absolutizing it in preparation for
[inheritance](#css-inheritance).

 The [computed
value](#computed-value) is the
value that is transferred from parent to child during
[inheritance](#css-inheritance). For historical reasons, it is not necessarily the
value returned by the
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) function, which sometimes returns [used
values](#used-value).
[\[CSSOM\]](#biblio-cssom "CSS Object Model (CSSOM)")
Furthermore, the [computed value] is an
abstract data representation: their definitions reflect that data
representation, not how that data is serialized. For example,
serialization rules often allow omitting certain values which are
implied during parsing; but those values are nonetheless part of the
[computed value].

A [specified
value](#specified-value) can
be either absolute (i.e., not relative to another value, as in
[red](https://drafts.csswg.org/css-color-4/#valdef-color-red) or [2mm]) or relative (i.e., relative to
another value, as in
[auto](https://drafts.csswg.org/animation-triggers-1/#valdef-timeline-trigger-active-range-auto), [2em]). Computing a relative value
generally absolutizes it:

- values with relative units
 ([em](https://drafts.csswg.org/css-values-4/#em),
 [ex](https://drafts.csswg.org/css-values-3/#ex),
 [vh](https://drafts.csswg.org/css-values-4/#vh),
 [vw](https://drafts.csswg.org/css-values-4/#vw)) must be made absolute by multiplying with the
 appropriate reference size
- certain keywords (e.g., [smaller],
 [bolder](https://drafts.csswg.org/css-fonts-4/#valdef-font-weight-bolder)) must be replaced according to their
 definitions
- percentages on some properties must be multiplied by a reference value
 (defined by the property)
- valid relative URLs must be resolved to become absolute.

See examples (f), (g) and (h) in the [table below](#stages-examples).

 In general, the [computed
value](#computed-value)
resolves the [specified
value](#specified-value) as
far as possible without laying out the document or performing other
expensive or hard-to-parallelize operations, such as resolving network
requests or retrieving values other than from the element and its
parent.

The [computed value](#computed-value) exists even when the property does not apply. However,
some properties may change how they determine the [computed
value] based on whether the property [applies
to](#apply) the element.

### 4.5. Used Values

The [used value] is the result of taking the [computed
value](#computed-value) and
completing any remaining calculations to make it the absolute
theoretical value used in the formatting of the document.

For example, a declaration of [width:
auto](https://drafts.csswg.org/css-sizing-3/#propdef-width) can't be resolved into a length without
knowing the layout of the element's ancestors, so the [computed
value](#computed-value) is
[auto](https://drafts.csswg.org/animation-triggers-1/#valdef-timeline-trigger-active-range-auto), while the [used
value](#used-value) is an absolute
length, such as [100px].
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")

As another example, a `<div>` might
have a computed
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) value of
[auto](https://drafts.csswg.org/animation-triggers-1/#valdef-timeline-trigger-active-range-auto), but acquire a used
[break-before] value of
[page](https://drafts.csswg.org/css-break-4/#valdef-break-before-page) by propagation from its first child.
[\[css-break-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")

If a property does not [apply to](#apply) this element or box type then it has no [used
value](#used-value) for that
property.

For example, the
[flex](https://drafts.csswg.org/css-flexbox-2/#propdef-flex) property has no [used
value](#used-value) on elements
that aren't [flex
items](https://drafts.csswg.org/css-flexbox-2/#flex-item).

#### 4.5.1. Applicable Properties

If a property does not [apply to] an element or box type---​as noted in its
"Applies to" line---​this means it does not directly take effect on that
type of box or element.

 A property that does not apply can still have
*indirect* formatting effects if its computed value affects the
computation of other properties that do apply; and of course its
[computed value](#computed-value), which always exists, can still inherit to descendants
and take effect on them.

Even though
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) and
[text-orientation](https://drafts.csswg.org/css-writing-modes-4/#propdef-text-orientation) do not apply to table rows (they do
not affect how the table row or its children are laid out), setting them
on such boxes will still affect the calculation of font relative units
such as [ch](https://drafts.csswg.org/css-values-4/#ch), and thus possibly any property that takes a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

Setting
[text-transform](https://drafts.csswg.org/css-text-4/#propdef-text-transform) on an HTML
[`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element) element (which is [display:
block](https://drafts.csswg.org/css-display-4/#propdef-display) by default) will have an effect, even though
[text-transform] only
applies to [inline
boxes](https://drafts.csswg.org/css-display-4/#inline-box), because the property inherits into the paragraph's
anonymous [root inline
box](https://drafts.csswg.org/css-inline-3/#root-inline-box) and applies to the text it contains.

 A property defined to apply to "all elements" applies
to all elements and [display
types](https://drafts.csswg.org/css-display-4/#display-type), but not necessarily to all
[pseudo-element](https://drafts.csswg.org/selectors-4/#pseudo-element) types, since pseudo-elements often have their own
specific rendering models or other restrictions. The
[::before](https://drafts.csswg.org/css-pseudo-4/#selectordef-before) and
[::after](https://drafts.csswg.org/css-pseudo-4/#selectordef-after) pseudo-elements, however, are defined to
generate boxes almost exactly like normal elements and are therefore
defined accept all properties that apply to "all elements". See
[\[CSS-PSEUDO-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4")
for more information about [pseudo-elements].

### 4.6. Actual Values

A [used value](#used-value) is in
principle ready to be used, but a user agent may not be able to make use
of the value in a given environment. [For example, a user agent may only
be able to render borders with integer pixel widths and may therefore
have to approximate the [used](#used-value) width. Also, the font size of an element may need
adjustment based on the availability of fonts or the value of the
[font-size-adjust](https://drafts.csswg.org/css-fonts-4/#propdef-font-size-adjust) property.] The [actual
value] is the used value after any such adjustments have
been made.

 By probing the actual values of elements, much can be
learned about how the document is laid out. However, not all information
is recorded in the actual values. For example, the actual value of the
[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after) property does not reflect whether
there is a page break or not after the element. Similarly, the actual
value of
[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans) does not reflect how many orphan
lines there is in a certain element. See examples (j) and (k) in the
[table below](#stages-examples).

### 4.7. Examples

Examples of CSS Value Computation

Property

Winning declaration

Cascaded value

Specified value

Computed value

Used value

Actual value

\(a\)

[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align)

`text-align: left`

[left]

[left]

[left]

[left]

[left]

\(b\)

[border-top-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-top-width),
[border-right-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-right-width),
[border-bottom-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-bottom-width),
[border-left-width](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-left-width)

`border-width: inherit`

[inherit]

[4.2px]

[4.2px]

[4.2px]

[4px]

\(c\)

[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

[(none)]

[(none)]

[auto] [(initial value)]

[auto]

[120px]

[120px]

\(d\)

[list-style-position](https://drafts.csswg.org/css-lists-3/#propdef-list-style-position)

`list-style-position: inherit`

[inherit]

[inside]

[inside]

[inside]

[inside]

\(e\)

[list-style-position](https://drafts.csswg.org/css-lists-3/#propdef-list-style-position)

`list-style-position: initial`

[initial]

[outside] [(initial value)]

[outside]

[outside]

[outside]

\(f\)

[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size)

`font-size: 1.2em`

[1.2em]

[1.2em]

[14.1px]

[14.1px]

[14px]

\(g\)

[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

`width: 80%`

[80%]

[80%]

[80%]

[354.2px]

[354px]

\(h\)

[width](https://drafts.csswg.org/css-sizing-3/#propdef-width)

`width: auto`

[auto]

[auto]

[auto]

[134px]

[134px]

\(i\)

[height](https://drafts.csswg.org/css-sizing-3/#propdef-height)

`height: auto`

[auto]

[auto]

[auto]

[176px]

[176px]

\(j\)

[page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after)

[(none)]

[(none)]

[auto] [(initial value)]

[auto]

[auto]

[auto]

\(k\)

[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans)

`orphans: 3`

[3]

[3]

[3]

[3]

[3]

### 4.8. Per-Fragment Value Processing

Certain CSS features can interfere with value processing on a
per-fragment basis. See for example [CSS Pseudo-Elements 4 § 2.1.3
Inheritance and the ::first-line
Pseudo-element](https://drafts.csswg.org/css-pseudo-4/#first-line-inheritance)
which alters inheritance for fragments within the
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) pseudo-element. In such cases, where individual
fragments are given different [specified
values](#specified-value),
any values that resolve based on the [computed
value](#computed-value) of
other properties (such as
[currentcolor](https://drafts.csswg.org/css-color-4/#valdef-color-currentcolor) or
[em](https://drafts.csswg.org/css-values-4/#em) units) are resolved per [box
fragment](https://drafts.csswg.org/css-break-4/#box-fragment). Subsequent value processing proceeds as normal in each
fragment.

APIs that assume a singular value per
[box](https://drafts.csswg.org/css-display-4/#box) (rather than per [box
fragment](https://drafts.csswg.org/css-break-4/#box-fragment)) must ignore the effects of non-[tree-abiding
pseudo-elements](https://drafts.csswg.org/css-pseudo-4/#tree-abiding). (For example,
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) styles have no effect on the value returned by
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle).)

For example, given the following
markup:

``` highlight
<div><span>First line<br />Second line</span></div>
<div><span>First line</span></div>
<div>First line<br><span>Second line</span></div>
<style>
div { color: blue; }
div::first-line { color: yellow; }
span { border: thin solid currentcolor; }
</style>
```

In each
[`div`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element), the "First line" text is yellow and the "Second
line" text is blue; the border for each fragment of the
[`span`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-span-element)s that wrap each line matches that color.

However,
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) on all three of the spans will return `"blue"` for
[border-color](https://drafts.csswg.org/css-backgrounds-3/#propdef-border-color), because the effects of a
[::first-line](https://drafts.csswg.org/css-pseudo-4/#selectordef-first-line) pseudo-element are ignored for APIs that aren't
fragment-aware.

## 5. Filtering

In order to find the [declared
values](#declared-value),
implementations must first identify all
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) that apply to each element. A declaration applies to an
element if:

- It belongs to a style sheet that currently applies to this document.
- It is not qualified by a conditional rule
 [\[CSS-CONDITIONAL-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
 with a false condition.
- It belongs to a style rule whose selector matches the element.
 [\[SELECT\]](#biblio-select "Selectors Level 3")
 (Taking [scoping](https://www.w3.org/TR/selectors-4/#scoping) into
 account, if necessary.)
- It is syntactically valid: the declaration's property is a known
 property name, and the declaration's value matches the syntax for that
 property.

The values of the
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) that apply form, for each property on each element, a
list of [declared values](#declared-value). The next section, the
[cascade](#cascade), prioritizes
these lists.

## 6. Cascading

The [cascade] takes
an unordered list of [declared
values](#declared-value) for a
given property on a given element, sorts them by their
[declaration's](https://drafts.csswg.org/css-syntax-3/#declaration) precedence as determined below, and outputs a single
[cascaded value](#cascaded-value).

### 6.1. Cascade Sorting Order

The cascade sorts
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) according to the following criteria, in descending
order of precedence:

Origin and Importance

: The [origin](#origin) of a
 [declaration](https://drafts.csswg.org/css-syntax-3/#declaration) is based on where it comes from and its
 [importance](#important) is
 whether or not it is declared with [!important] (see
 [below](#importance)). The precedence of the various
 [origins] is, in descending order:

 1. Transition declarations
 [\[css-transitions-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
 2. [Important](#important)
 [user agent](#cascade-origin-ua) declarations
 3. [Important](#important)
 [user](#cascade-origin-user) declarations
 4. [Important](#important)
 [author](#cascade-origin-author) declarations
 5. Animation declarations
 [\[css-animations-1\]](#biblio-css-animations-1 "CSS Animations Level 1")
 6. [Normal](#normal)
 [author](#cascade-origin-author) declarations
 7. [Normal](#normal)
 [user](#cascade-origin-user) declarations
 8. [Normal](#normal) [user
 agent](#cascade-origin-ua) declarations

 Declarations from [origins](#origin) earlier in this list win over declarations from
 later [origins].

Context

: A document language can provide for blending
 [declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) sourced from different [encapsulation
 contexts], such as the nested [tree
 contexts](https://drafts.csswg.org/css-shadow-1/#tree-context) of [shadow
 trees](https://dom.spec.whatwg.org/#concept-shadow-tree) in the
 [\[DOM\]](#biblio-dom "DOM Standard").

 When comparing two declarations that are sourced from different
 [encapsulation
 contexts](#encapsulation-contexts), then for [normal](#normal) rules the declaration from the outer context wins,
 and for [important](#important)
 rules the declaration from the inner context wins. For this purpose,
 [\[DOM\]](#biblio-dom "DOM Standard") [tree
 contexts](https://drafts.csswg.org/css-shadow-1/#tree-context) are considered to be nested in [shadow-including
 tree
 order](https://dom.spec.whatwg.org/#concept-shadow-including-tree-order).

 This effectively means that
 [normal](#normal) declarations
 belonging to an [encapsulation
 context](#encapsulation-contexts) can set defaults that are easily overridden by the
 outer context, while [important](#important) declarations belonging to an [encapsulation
 context] can enforce requirements
 that cannot be overridden by the outer context.

Element-Attached Styles

: Separately for [normal](#normal)
 and [important](#important)
 [declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations), declarations that are attached directly to an
 element (such as the [contents of a style
 attribute](https://www.w3.org/TR/css-style-attr/#interpret)) rather
 than indirectly mapped by means of a style rule selector take
 precedence over declarations the same
 [importance] that are mapped via style rule.

 See
 [\[CSSSTYLEATTR\]](#biblio-cssstyleattr "CSS Style Attributes").

 Non-CSS presentational hints (such as
 presentational markup) are handled separately, see [§ 6.5 Precedence
 of Non-CSS Presentational Hints](#preshint).

Layers

: [Declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) within each [origin](#origin) and
 [context](#encapsulation-contexts) can be explicitly assigned to a [cascade
 layer](#cascade-layers).
 For the purpose of this step, any declaration not assigned to an
 explicit layer is added to an implicit final layer.

 Cascade layers (like declarations) are sorted by order of
 appearance, see [§ 6.4.3 Layer Ordering](#layer-ordering). When
 comparing declarations that belong to different layers, then for
 [normal](#normal) rules the
 declaration whose [cascade
 layer](#cascade-layers) is
 latest in the layer order wins, and for
 [important](#important) rules
 the declaration whose [cascade layer] is
 earliest wins.

 This follows the same logic used for precedence of
 [normal](#normal) and
 [important](#important)
 [origins](#origin), thus the
 [!important] flag maintains the same "override" purpose in
 both settings.

Specificity
: The [Selectors module](https://www.w3.org/TR/selectors/#specificity)
 [\[SELECT\]](#biblio-select "Selectors Level 3")
 describes how to compute the specificity of a selector. Each
 [declaration](https://drafts.csswg.org/css-syntax-3/#declaration) has the same specificity as the style rule it
 appears in. The declaration with the highest specificity wins.

Order of Appearance
: The last
 [declaration](https://drafts.csswg.org/css-syntax-3/#declaration) in document order wins. For this purpose:
 - Style sheets are ordered in [final CSS style
 sheets](https://drafts.csswg.org/cssom-1/#documentorshadowroot-final-css-style-sheets) order.
 - Declarations from [imported style
 sheets](#at-ruledef-import) are ordered as if their style sheets were
 substituted in place of the
 [\@import] rule.
 - Declarations from style sheets independently linked by the
 originating document are treated as if they were concatenated in
 linking order, as determined by the host document language.
 - Declarations from style attributes are ordered according to the
 document order of the element the style attribute appears on, and
 are all placed after any style sheets.
 [\[CSSSTYLEATTR\]](#biblio-cssstyleattr "CSS Style Attributes")

The [output of the cascade] is a (potentially empty) sorted list of
[declared values](#declared-value) for each property on each element.

### 6.2. Cascading Origins

Each style rule has a [cascade origin], which determines where it
enters the cascade. CSS defines three core
[origins](#origin):

[Author Origin]
: The author specifies style sheets for a source document according to
 the conventions of the document language. For instance, in HTML,
 style sheets may be included in the document or linked externally.

[User Origin]
: The user may be able to specify style information for a particular
 document. For example, the user may specify a file that contains a
 style sheet or the user agent may provide an interface that
 generates a user style sheet (or behaves as if it did).

[User-Agent Origin]
: Conforming user agents must apply a default style sheet (or behave
 as if they did). A user agent's default style sheet should present
 the elements of the document language in ways that satisfy general
 presentation expectations for the document language (e.g., for
 visual browsers, the EM element in HTML is presented using an italic
 font). See e.g. the [HTML user agent style
 sheet](https://html.spec.whatwg.org/multipage/rendering.html#the-css-user-agent-style-sheet-and-presentational-hints).
 [\[HTML\]](#biblio-html "HTML Standard")

Extensions to CSS define the following additional
[origins](#origin):

[Animation Origin]
: CSS Animations
 [\[css-animations-1\]](#biblio-css-animations-1 "CSS Animations Level 1")
 generate "virtual" rules representing their effects when running.

[Transition Origin]
: Like CSS Animations, CSS Transitions
 [\[css-transitions-1\]](#biblio-css-transitions-1 "CSS Transitions Module Level 1")
 generate "virtual" rules representing their effects when running.

### [6.3. ][ Important Declarations: the [!important] annotation]
CSS attempts to create a balance of power between author and user style
sheets. By default, rules in an author's style sheet override those in a
user's style sheet, which override those in the user-agent's default
style sheet. To balance this, a
[declaration](https://drafts.csswg.org/css-syntax-3/#declaration) can be marked
[important](#important), which
increases its weight in the cascade and inverts the order of precedence.

A
[declaration](https://drafts.csswg.org/css-syntax-3/#declaration) is [important] if it has a
[!important] annotation as defined by
[\[css-syntax-3\]](#biblio-css-syntax-3 "CSS Syntax Module Level 3"),
i.e. if the last two (non-whitespace, non-comment) tokens in its value
are the delimiter token [!] followed by the identifier token
[important]. All other declarations are [normal]
(non-[important](#important)).

```
[hidden] { display: none !important; }
```

An [important](#important)
declaration takes precedence over a [normal](#normal) declaration. Author and user style sheets may contain
[important] declarations, with
[user-origin](#cascade-origin-user) [important] declarations
overriding
[author-origin](#cascade-origin-author) [important] declarations. This
CSS feature improves accessibility of documents by giving users with
special requirements (large fonts, color combinations, etc.) control
over presentation.

[Important](#important)
declarations from all origins take precedence over animations. This
allows authors to override animated values in important cases. (Animated
values normally override all other rules.)
[\[css-animations-1\]](#biblio-css-animations-1 "CSS Animations Level 1")

[User-agent style
sheets](#cascade-origin-ua)
may also contain [important](#important) declarations. These override all
[author](#cascade-origin-author) and
[user](#cascade-origin-user) declarations.

The first rule in the user's style
sheet in the following example contains an [!important]
declaration, which overrides the corresponding declaration in the
author's style sheet. The declaration in the second rule will also win
due to being marked [!important]. However, the third declaration
in the user's style sheet is not [!important] and will therefore
lose to the second rule in the author's style sheet (which happens to
set style on a
[shorthand](#shorthand-property) property). Also, the third author rule will lose to the
second author rule since the second declaration is [!important].
This shows that [!important] declarations have a function also
within author style sheets.

```
/* From the user's style sheet */
p { text-indent: 1em !important }
p { font-style: italic !important }
p { font-size: 18pt }

/* From the author's style sheet */
p { text-indent: 1.5em !important }
p { font: normal 12pt sans-serif !important }
p { font-size: 24pt }
```

Property

Winning value

[text-indent](https://drafts.csswg.org/css-text-4/#propdef-text-indent)

[1em]

[font-style](https://drafts.csswg.org/css-fonts-4/#propdef-font-style)

[italic](https://drafts.csswg.org/css-fonts-4/#valdef-font-style-italic)

[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size)

[12pt]

[font-family](https://drafts.csswg.org/css-fonts-4/#propdef-font-family)

[sans-serif](https://drafts.csswg.org/css-fonts-4/#valdef-font-family-sans-serif)

### 6.4. Cascade Layers

In the same way that [cascade origins](#origin) provide a balance of power between user and author
styles, [cascade layers] provide a structured way to
organize and balance concerns within a single origin. Rules within a
single [cascade layer](#cascade-layers) cascade together, without interleaving with style rules
outside the layer.

Authors can create layers to represent element defaults, third-party
libraries, themes, components, overrides, and other styling
concerns---​and are able to re-order the cascade of layers in an explicit
way, without altering selectors or specificity within each layer, or
relying on order of appearance to resolve conflicts across layers.

For example, the following generates
an explicit
[reset](https://drafts.csswg.org/animation-triggers-1/#valdef-animation-action-reset) layer, with lower cascade precedence than any
unlayered styles:

```
audio {
 /* specificity of 0,0,1 - implicit (final) layer */
 display: flex;
}

@layer reset {
 audio[controls] {
 /* specificity of 0,1,1 - explicit "reset" layer */
 display: block;
 }
}
```

The unlayered declarations on the
[`audio`](https://html.spec.whatwg.org/multipage/media.html#audio) element take precedence over the explicitly layered
declarations on `audio[controls]`---​even though the unlayered styles
have a lower specificity, and come first in the order of appearance.

[At-rules](https://drafts.csswg.org/css-syntax-3/#at-rule) (such as
[\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes),
[\@font-face](https://drafts.csswg.org/css-fonts-5/#at-font-face-rule),
[\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page), etc.) that are defined inside [cascade
layers](#cascade-layers) also
use the layer order when resolving collisions or
[cascading](#cascade).

For example, authors could override
the animation from a framework, by providing keyframes with the same
name in a higher-precedence layer:

```
/* establish the layer order, so the "override" layer takes precedence */
@layer framework, override;

@layer override {
 @keyframes slide-left {
 from { translate: 0; }
 to { translate: -100% 0; }
 }
}

@layer framework {
 @keyframes slide-left {
 from { margin-left: 0; }
 to { margin-left: -100%; }
 }
}

.sidebar { animation: slide-left 300ms; }
```

In this case the [override] layer has a higher cascade precedence
than the [framework] layer, so `slide-left` will animate using the
`translate` property rather than `margin-left`.

#### 6.4.1. Declaring Cascade Layers

Cascade layers can be declared:

- using an [\@import](#at-ruledef-import) rule with the [layer] keyword or
 [layer()] function, assigning the contents of the imported file
 into that layer.

- using a [\@layer block at-rule](#layer-block), assigning its child
 style rules into that layer.

- using a [\@layer statement at-rule](#layer-empty), declaring a named
 layer without assigning any rules.

Provide an attribute for assigning link
or style elements to cascade layers? [\[w3c/csswg-drafts Issue
#5853\]](https://github.com/w3c/csswg-drafts/issues/5853)

#### 6.4.2. Layer Naming and Nesting

A [cascade layer](#cascade-layers) has a [layer name], which is an ordered list representing each
level of layer nesting, each segment of which can be named (as a [CSS
identifier](https://drafts.csswg.org/css-values-4/#css-css-identifier)) or anonymous. (Thus, when a layer is nested inside of
another layer, this concatenates their names.) One layer is nested in
another when it is declared within the scope of another layer, e.g. an
[\@layer](#at-ruledef-layer) rule inside another
[\@layer], a layered
[\@import](#at-ruledef-import) inside a layered import, or an
[\@layer] rule inside a layered import.

[Layer names](#layer-name)
represent the same [cascade
layer](#cascade-layers) if
they contain the same segments in the same order; however anonymous
segments have unique identities for each occurrence. Note that nesting
can cause multiple layers to share the same anonymous segment.

Explicit layer identifiers provide a
way to assign multiple style blocks to a single layer. In the following
example, the contents of `headings.css` and `links.css` are cascaded
within the same layer as the `audio[controls]` rule:

```
@import url(headings.css) layer(default);
@import url(links.css) layer(default);

@layer default {
 audio[controls] {
 display: block;
 }
}
```

In this example, the nested
[framework.base] layer is distinct from the top-level [base]
layer:

```
@layer base {
 p { max-width: 70ch; }
}

@layer framework {
 @layer base {
 p { margin-block: 0.75em; }
 }

 @layer theme {
 p { color: #222; }
 }
}
```

The resulting layers can be represented as a tree:

1. [base]

2. [framework]

 1. [base]

 2. [theme]

or as a flat list with nested identifiers:

1. [base]

2. [framework.base]

3. [framework.theme]

Syntactically, an explicit [layer
name](#layer-name) is represented
by the
[\<layer-name\>](#typedef-layer-name) in
[\@layer](#at-ruledef-layer) and
[\@import](#at-ruledef-import) rules, which is a period-separated list of
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) tokens with no intervening white
space:

``` prod
<layer-name> = <ident> [ '.' <ident> ]*
```

The [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) are reserved for future use, and cause the rule to be
invalid at parse time if used as an
[\<ident\>](https://drafts.csswg.org/css-values-4/#typedef-ident) in the
[\<layer-name\>](#typedef-layer-name). When multiple identifiers are
concatenated with a period, this is a shorthand representing those
layers nested in order.

```
@layer framework {
 @layer default {
 p { margin-block: 0.75em; }
 }

 @layer theme {
 p { color: #222; }
 }
}

@layer framework.theme {
 /* These styles will be added to the theme layer inside the framework layer */
 blockquote { color: rebeccapurple; }
}
```

 A nested layer cannot "escape" its parent layer to
reference layers outside itself.

##### 6.4.2.1. Anonymous Layers

When a [\@layer](#at-ruledef-layer) rule omits its
[\<layer-name\>](#typedef-layer-name), or an
[\@import](#at-ruledef-import) rule uses the [layer] keyword (which does not
provide a [\<layer-name\>]),
its [layer name](#layer-name)
gains a unique anonymous segment; it therefore cannot be referenced from
the outside.

Each occurrence of an anonymous layer
declaration represents a unique cascade layer, thus:

- Multiple unnamed layer rules place their styles into separate layers,
 as each occurrence is referencing a distinct anonymous layer name.

 ```
 @layer { /* layer 1 */ }
 @layer { /* layer 2 */ }
 ```

- Within a single unnamed layer, child layers with the same name refer
 to the same cascade layer, because they share the same anonymous
 parent layer.

 ```
 @layer {
 @layer foo { /* layer 1 */ }
 @layer foo { /* also layer 1 */ }
 }
 ```

- Whereas in separate unnamed layers, child layers with the same name
 refer to different cascade layers, because they have distinct
 anonymous parent layers.

 ```
 @layer {
 @layer foo { /* layer 1 */ }
 }
 @layer {
 @layer foo { /* layer 2 */ }
 }
 ```

A layer declared without a
[\<layer-name\>](#typedef-layer-name) does not provide any external hook for
re-arranging or adding styles.

While this can be a mere convenience for brevity, it can also be used by
teams as a way to force an organizing convention (all code in that layer
must be defined in the same place), or by libraries wanting to merge &
hide a set of internal "private" layers that they don't want exposed to
author manipulation:

```
/* bootstrap-base.css */
/* unnamed wrapper layers around each sub-file */
@import url(base-forms.css) layer;
@import url(base-links.css) layer;
@import url(base-headings.css) layer;
```

```
/* bootstrap.css */
/* the internal names are hidden from access, subsumed in "base" */
@import url(bootstrap-base.css) layer(base);
```

```
/* author.css */
/* author has access to bootstrap.base layer, but not into unnamed layers */
@import url(bootstrap.css) layer(bootstrap);

/* Adds additional styles to the bootstrap layer: */
@layer bootstrap
```

#### 6.4.3. Layer Ordering

Cascade layers are sorted by the order in which they first are declared,
with nested layers grouped within their parent layer. Unlayered rules
are sorted later than any layered rules within the same parent layer (if
any).

Given the following layer rules:

```
/* unlayered styles come last in the layer order */
h1 { color: darkslateblue; }

@layer reset.type {
 strong { font-weight: bold; }
}

@layer framework {
 .title { font-weight: 100; }

 @layer theme {
 h1, h2 { color: maroon; }
 }
}

@layer reset {
 [hidden] { display: none; }
}
```

The outer layers are sorted first, with any unlayered style rules added
to an implicit outer layer which has higher precedence than (comes
after) the explicit layers:

1. [reset](https://drafts.csswg.org/animation-triggers-1/#valdef-animation-action-reset)

2. [framework]

3. (implicit outer layer)

Within each layer, nested layers are sorted in appearance order, and
style rules without further nesting are similarly added to an implicit
sub-layer after the explicitly nested layers:

1. [reset.type]

2. [reset](https://drafts.csswg.org/animation-triggers-1/#valdef-animation-action-reset) (implicit sub-layer)

3. [framework.theme]

4. [framework] (implicit sub-layer)

5. (implicit outer layer)

Layers that are defined inside of a [conditional group
rule](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule) do not contribute to the layer order unless the
condition is true or unless the [conditional group
rule] can evaluate differently for
different elements in the document.

 Since the layer order is global to the document, any
layers defined inside an element-sensitive [conditional group
rule](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule) need to be accommodated when establishing the global
layer order, regardless of the rule's condition. Conditions that are
global to the document, however (such as
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) and
[\@supports](https://drafts.csswg.org/css-conditional-3/#at-ruledef-supports)) can accommodate such
[\@layer](#at-ruledef-layer) rules conditionally.

For example, the following layer order
will depend on which media conditions match:

```
@media (min-width: 30em) {
 @layer layout {
 .title { font-size: x-large; }
 }
}

@media (prefers-color-scheme: dark) {
 @layer theme {
 .title { color: white; }
 }
}

@layer theme, layout;
```

If the first media-query matches based on viewport dimensions, then the
[layout](https://drafts.csswg.org/css-contain-2/#valdef-contain-layout) layer will come first in the layer order. If the
color-scheme preference query matches, or if neither condition is true,
then [theme] will come first in the layer order.

Authors who want to avoid this behavior can establish an explicit
ordering of layers in advance, and avoid defining new layers inside
conditional rules.

 [Cascade
layers](#cascade-layers) are
scoped to their [origin](#origin) and
[context](#encapsulation-contexts), so the ordering of layers in the light DOM has no
impact on the order of identically-named layers in the shadow DOM (and
vice versa).

Allow authors to explicitly place
unlayered styles in the layer order [\[Issue
#6323\]](https://github.com/w3c/csswg-drafts/issues/6323)

#### 6.4.4. Declaring Layers Inline: the [\@layer rule]
The [\@layer] rule declares a [cascade
layer](#cascade-layers), with
the option to assign style rules.

##### 6.4.4.1. Assigning Styles Inline: the [\@layer block at-rule]
The [\@layer](#at-ruledef-layer) [block
at-rule](https://drafts.csswg.org/css-syntax-3/#block-at-rule) assigns its child style rules to a particular named
[cascade layer](#cascade-layers). This block layer-assignment syntax is:

``` prod
@layer <layer-name>? {
 <rule-list>
}
```

Such [\@layer](#at-ruledef-layer) block rules have the same restrictions and processing
as a [conditional group
rule](https://drafts.csswg.org/css-conditional-3/#conditional-group-rule)
[\[CSS-CONDITIONAL-3\]](#biblio-css-conditional-3 "CSS Conditional Rules Module Level 3")
with a true condition.

For example,
[\@layer](#at-ruledef-layer) and
[\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media) can be mixed:

```
@layer framework {
 h1, h2 { color: maroon; background: white;}

 @media (prefers-color-scheme: dark) {
 h1, h2 { color: red; background: black; }
 }
}
```

[\@layer](#at-ruledef-layer) [block
at-rules](https://drafts.csswg.org/css-syntax-3/#block-at-rule) cannot be interleaved with
[\@import](#at-ruledef-import) rules.

##### 6.4.4.2. Declaring Without Styles: the [\@layer statement at-rule]
The [\@layer](#at-ruledef-layer) rule can also be used to define new layers without
assigning any style rules, by providing only the [layer
name](#layer-name):

``` prod
@layer <layer-name>#;
```

Such empty [\@layer](#at-ruledef-layer) rules are allowed before
[\@import](#at-ruledef-import) and
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules (after the
[\@charset](https://drafts.csswg.org/css-syntax-3/#at-ruledef-charset) rule, if any) as well as everywhere
[\@layer] [block
at-rules](https://drafts.csswg.org/css-syntax-3/#block-at-rule) are allowed.

 No
[\@layer](#at-ruledef-layer) rules are allowed between
[\@import](#at-ruledef-import) and
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules. Any [\@layer] rule that comes after an [\@import] or [\@namespace] rule will
cause any subsequent [\@import] or
[\@namespace] rules to be ignored.

Unlike the [block syntax](#layer-block), multiple comma-separated layer
names can be provided in this syntax, declaring each of the layers in
the order specified.

 Since layer ordering is defined by first occurrence of
the layer name (see [§ 6.4.3 Layer Ordering](#layer-ordering)), this
rule allows a page to declare the order of its layers up front, so that
their order is apparent without having to read the entire style sheet.
It also allows inline layers to be interleaved with imported layers,
which is not possible with the [block syntax](#layer-block).

The statement syntax allows
establishing a layer order in advance, regardless of the order in which
style rules are added to each layer. It can be helpful to establish that
layer order in advance, before any
[\@import](#at-ruledef-import) rules. In this example, the imported `theme.css`
style rules will override any rules added in the later [default]
block since the order of layers has already been established:

```
@layer default, theme, components;
@import url(theme.css) layer(theme);

@layer default {
 audio[controls] {
 display: block;
 }
}
```

It's also possible to have
[\@import](#at-ruledef-import) rules help establish the order, by placing them
between [\@layer](#at-ruledef-layer) rules. This example will have the same result:

```
@layer default;
@import url(theme.css) layer(theme);
@layer components;

@layer default {
 audio[controls] {
 display: block;
 }
}
```

However, [\@import](#at-ruledef-import) and
[\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules must be consecutive, without any
intervening rules. The following is invalid:

```
@import url(default.css) layer(default);
@layer theme;
@import url(components.css) layer(components);

@layer theme {
 audio[controls] {
 display: block;
 }
}
```

### 6.5. Precedence of Non-CSS Presentational Hints

The UA may choose to honor presentational hints in a source document's
markup, for example the `bgcolor` attribute or
[`s`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-s-element) element in
[\[HTML\]](#biblio-html "HTML Standard"). All
document language-based styling must be translated to corresponding CSS
rules and enter the cascade as rules in either the
[UA-origin](#cascade-origin-ua) or a special-purpose [author presentational hint
origin] between the regular [user
origin](#cascade-origin-user) and the [author
origin](#cascade-origin-author). For the purpose of
[cascading](#cascade) this [author
presentational hint
origin](#author-presentational-hint-origin) is treated as an independent
[origin](#origin); however for the
purpose of the [revert](#valdef-all-revert) keyword (but not for the
[revert-layer](#valdef-all-revert-layer) keyword) it is considered part of the [author
origin].

A document language may define whether such a presentational hint enters
the [cascade](#cascade) as
[UA-origin](#cascade-origin-ua) or
[author-origin](#cascade-origin-author); if so, the UA must behave accordingly. For example,
[\[SVG11\]](#biblio-svg11 "Scalable Vector Graphics (SVG) 1.1 (Second Edition)")
maps its presentation attributes into the [author
origin].

 Presentational hints entering the
[cascade](#cascade) as
[UA-origin](#cascade-origin-ua) rules can be overridden by
[author-origin](#cascade-origin-author) or
[user-origin](#cascade-origin-user) styles. Presentational hints entering the cascade as
[author presentational hint
origin](#author-presentational-hint-origin) rules can be overridden by
[author-origin] styles, but not by
non-[important](#important)
[user-origin] styles. Host languages
should choose the appropriate origin for presentational hints with these
considerations in mind.

## 7. Defaulting

When the [cascade](#cascade) does not
result in a value, the [specified
value](#specified-value)
must be found some other way. [Inherited
properties](#inherited-property) draw their defaults from their parent element through
[inheritance](#css-inheritance); all other properties take their [initial
value](#initial-value). Authors
can explicitly request inheritance or initialization via the
[inherit](#valdef-all-inherit) and
[initial](#valdef-all-initial) keywords.

### 7.1. Initial Values

Each property has an [initial value], defined in the property's definition table.
If the property is not an [inherited
property](#inherited-property), and the [cascade](#cascade) does not result in a value, then the [specified
value](#specified-value) of
the property is its [initial
value](#initial-value).

### 7.2. Inheritance

[Inheritance] propagates property
values from parent elements to their children. The [inherited
value] of a
property on an element is the [computed
value](#computed-value) of
the property on the element's parent element. For the root element,
which has no parent element, the [inherited
value](#inherited-value) is
the [initial value](#initial-value) of the property.

For a [\[DOM\]](#biblio-dom "DOM Standard") tree
with shadows, inheritance operates on the [flattened element
tree](https://drafts.csswg.org/css-shadow-1/#flat-tree). [This means that slotted elements inherit from the
[`slot`](https://html.spec.whatwg.org/multipage/scripting.html#the-slot-element) they're assigned to, rather than directly from
their [light
tree](https://dom.spec.whatwg.org/#concept-light-tree) parent.]
[Pseudo-elements](https://drafts.csswg.org/selectors-4/#pseudo-element) inherit according to the fictional tag sequence
described for each [pseudo-element].
[\[CSS-PSEUDO-4\]](#biblio-css-pseudo-4 "CSS Pseudo-Elements Module Level 4")

Some properties are [inherited properties], as
defined in their property definition table. This means that, unless the
[cascade](#cascade) results in a
value, the value will be determined by
[inheritance](#css-inheritance).

A property can also be explicitly inherited. See the
[inherit](#valdef-all-inherit) keyword.

 Inheritance follows the document tree and is not
intercepted by [anonymous
boxes](https://www.w3.org/TR/CSS2/visuren.html#box-gen), or otherwise
affected by manipulations of the box tree.

### 7.3. Explicit Defaulting

Several CSS-wide property values are defined below; declaring a property
to have these values explicitly specifies a particular defaulting
behavior. As specified in [CSS Values and
Units](https://www.w3.org/TR/css-values/#common-keywords)
[\[css-values-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3"),
all CSS properties can accept these values.

The keywords [revert](#valdef-all-revert),
[revert-layer](#valdef-all-revert-layer), and
[revert-rule](#valdef-all-revert-rule) are [cascade-dependent
keywords]; some contexts may restrict
their use while allowing the other [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords).

#### 7.3.1. Resetting a Property: the [initial keyword]
The [initial] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) represents the value defined as the property's [initial
value](#initial-value).

If the [cascaded value](#cascaded-value) of a property is the
[initial](#valdef-all-initial) keyword, the property's [specified
value](#specified-value) is
its [initial value](#initial-value).

#### 7.3.2. Explicit Inheritance: the [inherit keyword]
The [inherit] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) represents the property's [computed
value](#computed-value) on
the parent element.

If the [cascaded value](#cascaded-value) of a property is the
[inherit](#valdef-all-inherit) keyword, the property's
[specified](#specified-value) and [computed
values](#computed-value) are
the [inherited value](#inherited-value).

#### 7.3.3. Erasing All Declarations: the [unset keyword]
The [unset] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) acts as either
[inherit](#valdef-all-inherit) or
[initial](#valdef-all-initial), depending on whether the property is
[inherited](#inherited-property) or not.

If the [cascaded value](#cascaded-value) of a property is the
[unset](#valdef-all-unset) keyword, then if it is an inherited property, this is
treated as [inherit](#valdef-all-inherit), and if it is not, this is treated as
[initial](#valdef-all-initial). This keyword effectively erases all [declared
values](#declared-value)
occurring earlier in the [cascade](#cascade), correctly inheriting or not as appropriate for the
property (or all longhands of a
[shorthand](#shorthand-property)).

#### 7.3.4. Rolling Back Cascade Origins: the [revert keyword]
The [revert] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) rolls back the cascade to the [cascaded
value](#cascaded-value) of
the earlier [origin](#origin).

If the [cascaded value](#cascaded-value) of a property is the
[revert](#valdef-all-revert) keyword, the behavior depends on the [cascade
origin](#origin) to which the
[declaration](https://drafts.csswg.org/css-syntax-3/#declaration) belongs:

[user-agent origin](#cascade-origin-ua)
: Equivalent to [unset](#valdef-all-unset).

[user origin](#cascade-origin-user)
: Rolls back the [cascaded
 value](#cascaded-value)
 to the user-agent level, so that the [specified
 value](#specified-value)
 is calculated as if no
 [author-origin](#cascade-origin-author) or
 [user-origin](#cascade-origin-user) rules were specified for this property on this
 element.

[author origin](#cascade-origin-author)
: Rolls back the [cascaded
 value](#cascaded-value)
 to the user level, so that the [specified
 value](#specified-value)
 is calculated as if no
 [author-origin](#cascade-origin-author) rules were specified for this property on this
 element. For the purpose of
 [revert](#valdef-all-revert), this origin includes the Animation
 [origin](#origin).

 Effectively the
[revert](#valdef-all-revert) keyword is substituted with the value from the
earlier [cascade origin](#origin).
Thus, reverting a [shorthand
property](#shorthand-property) reverts all its longhands; reverting any [property
alias](#aliasing) of a property reverts all of them; reverting one of
the paired properties in a [logical property
group](https://drafts.csswg.org/css-logical-1/#logical-property-group) also reverts the other one; etc.

#### 7.3.5. Rolling Back Cascade Layers: the [revert-layer keyword]
The [revert-layer] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) rolls back the cascade similar to
[revert](#valdef-all-revert), except it works by [cascade
layer](#cascade-layers)
rather than by [cascade origin](#origin).

If the [cascaded value](#cascaded-value) of a property is the
[revert-layer](#valdef-all-revert-layer) keyword, the [cascaded
value] is rolled back to the earlier
[layer](#cascade-layers), so
that the [specified value](#specified-value) is calculated as if no rules were specified in the
current [cascade layer]---​or between its
[normal](#normal) and
[important](#important) levels in
the [cascade](#cascade)---​for this
property on this element. For
[revert-layer] in
[important] [element-attached
styles](#style-attr), however, it only reverts the [element-attached
styles](#style-attr) and the intervening [animation
origin](#cascade-origin-animation), and not any of the intervening
[author-origin](#cascade-origin-author) [important] rules.

For example, applying
[revert-layer](#valdef-all-revert-layer) to the
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) in layer `two`, reverts the
[height] property to the value
defined in layer `one`, yielding a [height] of `100px`.

```
@layer one {
 div { height: 100px }
}

@layer two {
 div { height: 200px }
 div { height: revert-layer }
}
```

Note that since
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) and
[block-size](https://drafts.csswg.org/css-logical-1/#propdef-block-size) are paired properties in a [logical
property
group](https://drafts.csswg.org/css-logical-1/#logical-property-group), the following layer `two` declaration would also
revert to the [height] defined in
layer `one`.

```
@layer two {
 div { height: 200px }
 div { block-size: revert-layer }
}
```

 If there are no lower-precedence
[declarations](https://drafts.csswg.org/cssom-1/#cssstyledeclaration-declarations) in the same [cascade origin](#origin) as the
[revert-layer](#valdef-all-revert-layer) value, the [cascaded
value](#cascaded-value) will
roll back to the previous origin.

 The [animation
origin](#cascade-origin-animation) is not collapsed with the [author
origin](#cascade-origin-author) for this purpose as it is for
[revert](#valdef-all-revert), and thus effectively forms its own [cascade
layer](#cascade-layers).

#### 7.3.6. Rolling Back Rules: the [revert-rule keyword]
The [revert-rule] [CSS-wide
keyword](https://drafts.csswg.org/css-values-4/#css-wide-keywords) rolls back the cascade similar to
[revert](#valdef-all-revert) and
[revert-layer](#valdef-all-revert-layer), except it works by [style
rule](https://drafts.csswg.org/css-syntax-3/#style-rule) rather than [cascade origin](#origin) or [cascade
layer](#cascade-layers).

If the [cascaded value](#cascaded-value) of a property is the
[revert-rule](#valdef-all-revert-rule) keyword, the [cascaded
value] is rolled back such that the
[specified value](#specified-value) is calculated as if the current [style
rule](https://drafts.csswg.org/css-syntax-3/#style-rule) had not been present at all.

The
[revert-rule](#valdef-all-revert-rule) keyword can be combined with
[if()](https://drafts.csswg.org/css-values-5/#funcdef-if) to conditionally ignore a declaration:

```
div {
 border-radius: 5px;
}
.apply-sharp {
 border-radius: if(style(--mode:sharp): 0px; else: revert-rule);
}
```

Given an element `<div class=apply-sharp>`, the above style sets
[border-radius] to `0px` only when the [computed
value](#computed-value) of
`--mode` is `sharp`.

[revert-rule](#valdef-all-revert-rule) keyword behaves like
[revert-layer](#valdef-all-revert-layer) in the [animation
origin](#cascade-origin-animation).

## 8. Layer APIs

### 8.1. The `CSSLayerBlockRule` interface

The
[`CSSLayerBlockRule`](#csslayerblockrule) interface represents the
[\@layer](#at-ruledef-layer) [block rule](#layer-block):

```
[Exposed=Window]
interface CSSLayerBlockRule : CSSGroupingRule {
 readonly attribute CSSOMString name;
};
```

Its [`name`] attribute
represents the [layer name](#layer-name) declared by the at-rule itself, and is an empty string
if the layer is anonymous.

For example, additional nested context
is not added from wrapping layer rules.

```
@layer outer {
 @layer foo.bar
}
```

in this case the
[`name`](#dom-csslayerblockrule-name) of the inner
[\@layer](#at-ruledef-layer) rule is "foo.bar" (and not "outer.foo.bar").

### 8.2. The `CSSLayerStatementRule` interface

The
[`CSSLayerStatementRule`](#csslayerstatementrule) interface represents the
[\@layer](#at-ruledef-layer) [statement](#layer-empty):

```
[Exposed=Window]
interface CSSLayerStatementRule : CSSRule {
 readonly attribute FrozenArray<CSSOMString> nameList;
};
```

Its [`nameList`] attribute represents the list of [layer
names](#layer-name) declared by
the at-rule, normalized following the same rule as the
[`CSSLayerBlockRule`](#csslayerblockrule)'s
[`name`](#dom-csslayerblockrule-name) attribute.

## 9. Changes

### 9.1. Changes since the 13 Jan 2022 Candidate Recommendation Snapshot

Non-trivial changes since the [13 January 2022 Candidate Recommendation
Snapshot](CSS%20Cascading%20and%20Inheritance%20Level%205):

- Added the
 [revert-rule](#valdef-all-revert-rule) keyword. ([Issue
 10443](https://github.com/w3c/csswg-drafts/issues/10443))

- Clarify that all "aliases" of a property are reverted by
 [revert](#valdef-all-revert)/[revert-layer](#valdef-all-revert-layer).

- Clarify that style sheets are ordered in [final CSS style
 sheets](https://drafts.csswg.org/cssom-1/#documentorshadowroot-final-css-style-sheets) order.

- Clarify that only
 [\@layer](#at-ruledef-layer) statement rules are ignored when checking validity
 of [\@import](#at-ruledef-import), not empty [\@layer] block rules.

### 9.2. Changes since the 15 Oct 2021 Working Draft

Non-trivial changes since the [15 October 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-5-20211015/):

- Updated grammar style for \@import media queries and supports
 conditions

- Allowed functional notation parse-time aliases ([Issue
 6193](https://github.com/w3c/csswg-drafts/issues/6193))

- Made CSSImportRule.layerName nullable ([Issue
 6576](https://github.com/w3c/csswg-drafts/issues/6576))

- Clarified that revert-layer in style attr does not revert author
 layers ([Issue 6743](https://github.com/w3c/csswg-drafts/issues/6743))

- Clarified revert-layer on style attr and keyframes ([Issue
 6743](https://github.com/w3c/csswg-drafts/issues/6743))

- Added [§ 4.1.1 Value Aliasing](#value-aliasing) section. ([Issue
 6193](https://github.com/w3c/csswg-drafts/issues/6193))

- Added [§ 8 Layer APIs](#layer-apis) section. ([Issue
 6576](https://github.com/w3c/csswg-drafts/issues/6576))

- Clarified the behavior of
 [revert-layer](#valdef-all-revert-layer) keyword when used in the style attribute or
 [\@keyframes](https://drafts.csswg.org/css-animations-1/#at-ruledef-keyframes) at-rule. ([Issue
 6743](https://github.com/w3c/csswg-drafts/issues/6743))

- Clarified the behavior of the [layer] keyword and
 [layer()] function on
 [\@import](#at-ruledef-import) rules. ([Issue
 6776](https://github.com/w3c/csswg-drafts/issues/6776))

### 9.3. Changes since the 29 August 2021 Working Draft

Changes since the [29 August 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-5-20210829/) include:

- Revert the ordering of unlayered styles. (See [§ 9.4 Changes since the
 8 June 2021 Working Draft](#changes-2021-06) and [Issue
 6284](https://github.com/w3c/csswg-drafts/issues/6284))

- Defined presentational hints to use the [author presentational hint
 origin](#author-presentational-hint-origin) instead of layers, matching update to
 [\[CSS-CASCADE-4\]](#biblio-css-cascade-4 "CSS Cascading and Inheritance Level 4").
 ([Issue 6659](https://github.com/w3c/csswg-drafts/issues/6659))

### 9.4. Changes since the 8 June 2021 Working Draft

Significant changes since the [8 June 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-5-20210608/) include:

- Reserve the CSS-wide keywords for future use in layer-names. ([Issue
 6323](https://github.com/w3c/csswg-drafts/issues/6323))

- Clarify that [\@layer](#at-ruledef-layer) rules respect global conditional rules, but
 are always applied to the layer order when declared in non-global
 conditions such as a container query. ([Issue
 6407](https://github.com/w3c/csswg-drafts/issues/6407))

- Name-defining at-rules follow layer order for collision resolution,
 similar to specificity resolution. ([Issue
 6404](https://github.com/w3c/csswg-drafts/issues/6404))

- Disallow interleaving of
 [\@layer](#at-ruledef-layer) with
 [\@import](#at-ruledef-import) or
 [\@namespace](https://drafts.csswg.org/css-namespaces-3/#at-ruledef-namespace) rules. ([Issue
 6522](https://github.com/w3c/csswg-drafts/issues/6522))

### 9.5. Changes since the 19 March 2021 Working Draft

Significant changes since the [19 March 2021 Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-5-20210319/) include:

- Switched the ordering of unlayered styles from highest to lowest
 precedence in the normal origins. ([Issue
 6284](https://github.com/w3c/csswg-drafts/issues/6284))

### 9.6. Changes since the 19 January 2021 Working Draft

Significant changes since the [19 January 2021 First Public Working
Draft](https://www.w3.org/TR/2021/WD-css-cascade-5-20210119/) include:

- Switched [layer](#cascade-layers) import syntax from using
 [\@layer](#at-ruledef-layer) to using
 [\@import](#at-ruledef-import). ([Issue
 5681](https://github.com/w3c/csswg-drafts/issues/5681))

- Added
 [revert-layer](#valdef-all-revert-layer) keyword. ([Issue
 5793](https://github.com/w3c/csswg-drafts/issues/5793))

### 9.7. Additions Since Level 4

The following features have been added since [Level
4](https://www.w3.org/TR/css-cascade-4/):

- Added [cascade layers](#cascade-layers) to the [cascade](#cascade) sort criteria (and defined style attributes as a
 distinct step of the [cascade] sort criteria so
 that they interact appropriately).

- Introduced the
 [\@layer](#at-ruledef-layer) rule for defining cascade layers.

- Added [layer]/[layer()] option to
 [\@import](#at-ruledef-import) definition.

- Introduced the
 [revert-layer](#valdef-all-revert-layer) keyword for rolling back values to previous
 layers.

### 9.8. Additions Since Level 3

The following features have been added since [Level
3](https://www.w3.org/TR/css-cascade-3/):

- Introduced [revert](#valdef-all-revert) keyword, for rolling back the cascade.

- Introduced
 [supports()](https://drafts.csswg.org/css-conditional-5/#funcdef-supports) syntax for supports-conditional
 [\@import](#at-ruledef-import) rules.

- Added [encapsulation
 context](#encapsulation-contexts) to the [cascade](#cascade) sort criteria to accommodate Shadow DOM.
 [\[DOM\]](#biblio-dom "DOM Standard")

- Defined the property two aliasing mechanisms CSS uses to support
 legacy syntaxes. See [§ 3.1 Property Aliasing](#aliasing).

### 9.9. Additions Since Level 2

The following features have been added since [Level
2](http://www.w3.org/TR/CSS2/cascade.html):

- The [all](#propdef-all) shorthand
- The [initial](#valdef-all-initial) keyword
- The [unset](#valdef-all-unset) keyword
- Incorporation of animations and transitions into the
 [cascade](#cascade).

## [Acknowledgments]
David Baron, Tantek Çelik, Florian Rivoal, Noam Rosenthal, Simon Sapin,
Jen Simmons, and Boris Zbarsky contributed to this specification.

## [ Privacy Considerations]
- The cascade process does not distinguish between same-origin and
 cross-origin stylesheets, enabling the content of cross-origin
 stylesheets to be inferred from the computed styles they apply to a
 document.

- User preferences and UA defaults expressed via application of style
 rules are exposed by the cascade process, and can be inferred from the
 computed styles they apply to a document.

- The [\@import](#at-ruledef-import) rule assumes that resources without [`Content-Type`
 metadata](https://html.spec.whatwg.org/multipage/urls-and-fetching.html#content-type)
 (or any same-origin file if the host document is in quirks mode) are
 `text/css`, potentially allowing arbitrary files to be imported into
 the page and interpreted as CSS, potentially allowing sensitive data
 to be inferred from the computed styles they apply to a document.

## [ Security Considerations]
- The [\@import](#at-ruledef-import) rule does not apply the [CORS
 protocol](https://fetch.spec.whatwg.org/#cors-protocol) to loading cross-origin stylesheets, instead allowing
 them to be freely imported and applied.
