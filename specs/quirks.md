# Introduction


## History

Browsers have several rendering modes to render HTML documents. The reason for this is basically a historical accident. The CSS specification was incompatible with the behavior of existing browsers which existing Web content relied on. In order to comply with the specification while not breaking existing content, browsers introduced a new rendering mode (no-quirks mode). Some browsers still had the shrink-wrapping behavior for images in table cells in their no-quirks mode, and sites started relying on that, so browsers that implemented the specification's behavior introduced a third mode (limited-quirks mode). In hindsight, it would have been better to make the default CSS behavior be compatible with what the existing content relied on and providing opt-ins to different behavior. The different modes have since gained a few differences outside of CSS.


## Goals

- Create a specification for rendering old (or indeed new, if they happen to have a particular pragma) HTML documents.

  The HTML specification [defines](https://html.spec.whatwg.org/multipage/syntax.html#the-initial-insertion-mode) when a document is set to [quirks mode](https://dom.spec.whatwg.org/#concept-document-quirks), [limited-quirks mode](https://dom.spec.whatwg.org/#concept-document-limited-quirks) or [no-quirks mode](https://dom.spec.whatwg.org/#concept-document-no-quirks). [HTML]

- Remove quirks from implementations that are not needed for Web compatibility.

  For example, [Gecko has removed a quirk about list item bullet size](https://bugzilla.mozilla.org/show_bug.cgi?id=648331), and [Chromium has removed a quirk where display was forced to table or inline-table on `table` elements](https://bugs.chromium.org/p/chromium/issues/detail?id=369979).

- Get interoperability on quirks that *are* needed for Web compatibility.

  For example, [Gecko aligned their implementation of the :active and :hover quirk](https://bugzilla.mozilla.org/show_bug.cgi?id=783213) with this specification and thereby achieved closer interoperability with other browsers.

- Where possible, limit quirks to a fixed set of legacy features so they don't propagate into new features.

  For example, [§ 3.1 The hashless hex color quirk](#the-hashless-hex-color-quirk) is limited to a fixed set of CSS properties so that the quirk does not apply in SVG features that also accept colors, or in [CSS gradients where the grammar could otherwise become ambiguous](https://bugs.webkit.org/show_bug.cgi?id=153730).

This specification does not enumerate all quirks that currently exist in browsers. A number of quirks are specified in HTML, DOM, CSSOM and CSSOM View. [HTML] [DOM] [CSSOM] [CSSOM-VIEW] If a quirk is not specified anywhere, it is probably due to the second bullet point above.


## Common infrastructure


### Conformance

All diagrams, examples, and notes in this specification are non-normative, as are all sections explicitly marked non-normative. Everything else in this specification is normative.

The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in the normative parts of this specification are to be interpreted as described in RFC2119. For readability, these words do not appear in all uppercase letters in this specification. [[RFC2119]]


### Terminology

When this specification refers to a "`foo` element", it means an element with the local name `foo` and having the namespace `http://www.w3.org/1999/xhtml`.

When this specification refers to a "`foo` attribute", it means an attribute with the local name `foo` and having no namespace.

The document's body element is the first child of the document element that is a `body` element, if there is one, and the document element is an `html` element. Otherwise it is null.

The document's body element is different from HTML's the body element, since the latter can be a `frameset` element.


## CSS


### The hashless hex color quirk

See [CSS Color 4 § B Deprecated Quirky Hex Colors](https://drafts.csswg.org/css-color-4/#quirky-color).


### The unitless length quirk

See [CSS Values 4 § C Quirky Lengths](https://drafts.csswg.org/css-values-4/#deprecated-quirky-length).


### The line height calculation quirk

In quirks mode and limited-quirks mode, an inline box that matches all of the following conditions, must, for the purpose of line height calculation, act as if the box had a line-height of zero.

- The border-top-width, border-bottom-width, padding-top and padding-bottom properties have a used value of zero and the box has a vertical writing mode, or the border-right-width, border-left-width, padding-right and padding-left properties have a used value of zero and the box has a horizontal writing mode.

- It either contains no text or it contains only collapsed whitespace.


### The blocks ignore line-height quirk

In quirks mode and limited-quirks mode, for a block container element whose content is composed of inline-level elements, the element's line-height must be ignored for the purpose of calculating the minimal height of line boxes within the element.

This means that the "strut" is not created.


### The percentage height calculation quirk

In quirks mode, for the purpose of calculating the height of an element `element`, if the computed value of the position property of `element` is relative or static, the specified value for the height property of `element` is a <percentage>, and `element` does not have a computed value of the display property that is table-row, table-row-group, table-header-group, table-footer-group, table-cell or table-caption, the containing block of `element` must be calculated using the following algorithm, aborting on the first step that returns a value:

1.  Let `element` be the nearest ancestor containing block of `element`, if there is one. Otherwise, return the initial containing block.

2.  If `element` has a computed value of the display property that is table-cell, then return a UA-defined value.

3.  If `element` has a computed value of the height property that is not auto, then return `element`.

4.  If `element` has a computed value of the position property that is absolute, or if `element` is a not a block container or a table wrapper box, then return `element`.

5.  Jump to the first step.

It is at the time or writing undefined how percentage heights inside tables work in CSS. This specification does not try to specify what to use as the containing block for calculating percentage heights in tables. Godspeed!

This quirk needs to take writing modes into account.


### The `html` element fills the viewport quirk

In quirks mode, if the document element `element` matches all of the following conditions:

- `element` is an `html` element.

- The computed value of the width property of `element` is auto and `element` has a vertical writing mode, or the computed value of the height property of `element` is auto and `element` has a horizontal writing mode. [CSS-WRITING-MODES-3]

...then `element` must have its border box size in the block flow direction set using the following algorithm:

1.  Let `margins` be sum of the used values of the margin-left and margin-right properties of `element` if `element` has a vertical writing mode, otherwise let `margins` be the sum of the used values of the margin-top and margin-bottom properties of `element`.

2.  Let `size` be the size of the initial containing block in the block flow direction minus `margins`.

3.  Return the bigger value of `size` and the normal border box size the element would have according to the CSS specification.


### The `body` element fills the `html` element quirk

In quirks mode, if the document's body element `body` is not null and if it matches all of the following conditions:

- The computed value of the width property of `body` is auto and `body` has a vertical writing mode, or the computed value of the height property of `body` is auto and `body` has a horizontal writing mode. [CSS-WRITING-MODES-3]

- The computed value of the position property of `body` is not absolute or fixed.

- The computed value of the float property of `body` is none.

- `body` is not an inline-level element.

- `body` is not a multi-column spanning element. [CSS3-MULTICOL]

...then `body` must have its border box size in the block flow direction set using the following algorithm:

1.  Let `margins` be the sum of the used values of the margin-left and margin-right properties of `body` if `body` has a vertical writing mode, otherwise let `margins` be the sum of the used values of the margin-top and margin-bottom properties of `body`.

2.  Let `size` be the size of `body`'s parent element's content box in the block flow direction minus `margins`.

3.  Return the bigger value of `size` and the normal border box size the element would have according to the CSS specification.

What should happen if the `html` and the `body` have different writing modes?


### The table cell width calculation quirk

In quirks mode, for the purpose of calculating the min-content width of an inline formatting context for which a table cell `cell` is the containing block, if `cell` has a computed value of the width property that is auto, `img` elements that are inline-level replaced elements in that inline formatting context must not have a soft wrap opportunity before or after them. [CSS-TEXT-3] [INTRINSIC]


### The table cell nowrap minimum width calculation quirk

In quirks mode, an element `cell` that matches all of the following conditions must act as if it had an outer min-content width of a table cell in the automatic table layout algorithm that is the bigger value of `cell`'s computed value of the width property and the outer min-content width of a table cell. [INTRINSIC]

- `cell` is a `td` element or a `th` element.

- `cell` has a `nowrap` attribute.

- The computed value of the width property of `cell` is a <length> that is not zero.


### The collapsing table quirk

In quirks mode, an element `table` that matches all of the following conditions must have a used value of the height property of 0 and a used value of the border-style property of none.

- `table` has a computed value of the display property that is table.

- `table` has no child table-row-group, table-header-group, table-footer-group or table-caption box.

- `table` has no child table-column-group box that itself has a child table-column box.


### The text decoration doesn't propagate into tables quirk

In quirks mode, text decoration must not propagate into `table` elements.


### The tables inherit color from body quirk

In quirks mode, the initial value of the color property must be quirk-inherit, a special value that has no keyword mapping to it.

The computed value of the color property of an element `element` must be calculated using the following algorithm:

1.  If the specified value of the color property of `element` is not quirk-inherit, jump to the last step.

2.  If `element` is not a `table` element, jump to the last step.

3.  If the document's body element is null, jump to the last step.

4.  Return the used value of the color property of the document's body element. Abort these steps.

5.  If the specified value of the color property of `element` is quirk-inherit, let the specified value of the color property of `element` be the initial value of the color property according to the CSS specification. Return the computed value of the color property of `element` as specified in the CSS specification.


### The table cell height box sizing quirk

In quirks mode, elements that have a computed value of the display property of table-cell must act as they have used value of the box-sizing property of border-box, but only for the purpose of the height, min-height and max-height properties.


## Selectors


### The :active and :hover quirk

In quirks mode, a compound selector `selector` that matches all of the following conditions must not match elements that would not also match the :any-link selector. [SELECTORS4]

- `selector` uses the :active or :hover pseudo-classes.

- `selector` does not use a type selector.

- `selector` does not use an attribute selector.

- `selector` does not use an ID selector.

- `selector` does not use a class selector.

- `selector` does not use a pseudo-class selector other than :active and :hover.

- `selector` does not use a pseudo-element selector.

- `selector` is not part of an argument to a functional pseudo-class or pseudo-element.


## Security and Privacy Considerations

There are no known security or privacy impacts in this specification.