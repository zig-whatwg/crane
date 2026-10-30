## 1. Introduction

::: non-normative
Paged media (e.g., paper, transparencies, photo album pages, pages
displayed on computer screens as printed output simulations) differ from
[continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media) in that the content of the document is split into one
or more discrete static display surfaces. To handle pages, CSS3 Paged
Media describes how:

- [page breaks](#page-breaks) are created and avoided;
- the page properties such as size, orientation, margins, border, and
 padding are specified;
- headers and footers are established within the page margins; and
- content such as page counters are placed in the headers and footers;

This module defines a [page model](#page-model) that specifies how a
document is formatted within a rectangular area, called the [page
box](#page-box-page-rule), that has finite width and height.

Although CSS3 does not specify how user agents transfer page boxes to
sheets, it does include certain mechanisms for telling user agents about
the intended page sheet [size and orientation](#page-size). In the
general case, CSS3 assumes that one page box will be transferred to one
surface of similar size.

 The
[\[CSS-BREAK-4\]](#biblio-css-break-4 "CSS Fragmentation Module Level 4")
specification addresses controls over
[fragmentation](https://drafts.csswg.org/css-break-4/#fragmentation) (pagination), such as the
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before),
[break-after](https://drafts.csswg.org/css-break-4/#propdef-break-after),
[break-inside](https://drafts.csswg.org/css-break-3/#propdef-break-inside),
[widows](https://drafts.csswg.org/css-break-4/#propdef-widows), and
[orphans](https://drafts.csswg.org/css-break-3/#propdef-orphans) properties.

### 1.1. Value Definitions

This specification follows the [CSS property definition
conventions](https://www.w3.org/TR/CSS2/about.html#property-defs) from
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
using the [value definition
syntax](https://www.w3.org/TR/css-values-3/#value-defs) from
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Value types not defined in this specification are defined in CSS Values
& Units
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
Combination with other CSS modules may expand the definitions of these
value types.

In addition to the property-specific values listed in their definitions,
all properties defined in this specification also accept the [CSS-wide
keywords](https://drafts.csswg.org/css-values-4/#css-wide-keywords) as their property value. For readability they have not
been repeated explicitly.

## 2. Page Terminology

The following terminology and accompanying diagrams help to describe the
page model:

[Page sheet]
: ![The corner of a page sheet with the non-printable area at the edge
 and printable area inside it](images/PageSheet.png){height="148"
 style="float: right;" width="194"} The page sheet is one surface of
 the physical medium. The illustration to the right shows a
 representation of the upper-left corner of a page sheet.

[Printable and non-printable areas]
: The non-printable area is the area of a page sheet that a physical
 device such as a printer is not capable of marking reliably, usually
 due to the printer's paper handling mechanism. This value is printer
 dependent and is usually a small region along each edge of the page
 sheet. The printable area is the area of page sheet that a printer
 *is* capable of marking reliably. The size of the printable area is
 the size of the page sheet reduced by the size of the non-printable
 area. A user agent may not know the dimensions of this area for a
 particular printing device; but when its dimensions are known, user
 agents may adjust the formatting of the document so that content
 falls within the printable area. How this adjustment is accomplished
 is device dependent within the constraints expressed in the sections
 [§ 7.4 Rendering page boxes that do not fit a page
 sheet](#renderingpages) and [§ 3.2 Content outside the page
 box](#content-outside-box).

[Page Orientation]
: The page orientation is defined by comparing the length of the edges
 of a [page box](#page-box). The
 page box is a rectangle with two perpendicular edges called the long
 edge and the short edge. The length of the long edge is always
 greater than or equal to the length of the short edge. When the page
 box is square, the two edges are of the same length and either can
 be used as the long edge with the other being the short edge. This
 specification defines page orientations of
 [portrait](#valdef-page-size-portrait) and
 [landscape](#valdef-page-size-landscape).

[Portrait Orientation]
: A portrait page's height is greater than or equal to its width.
 Horizontal elements are parallel to the short edge and vertical
 elements to the long edge.

[Landscape Orientation]

: A landscape page's width is greater than or equal to its height.
 Horizontal elements are parallel to the long edge and vertical
 elements to the short edge.

 Note that CSS3 makes no distinction between
 landscape and reverse-landscape orientations. However, future
 versions of CSS may do so. UAs should consider, when formatting for
 duplexed printing, the binding edge, page progression, and ease of
 reading when choosing between landscape and reverse-landscape
 renderings.

[Duplex Printing]
: Duplex printing prints one page box per side of a page sheet and
 uses both sides of the page sheet. This module provides no ability
 to specify whether a document is duplex printed, but the concept of
 left and right pages is based on the assumption that the document is
 duplex printed, regardless of whether or not it actually is.

[Binding Edge]
: The binding edge is the edge of the page box that is toward the
 binding if the material is bound. The binding edge often has a
 larger margin than the opposite edge to provide for the space used
 by the binding. The binding edge can be any of the four edges.
 However, page sheets are customarily bound so that the binding edge
 of page boxes with portrait orientation is vertical. This module
 provides no method to specify the binding edge. In duplex printing,
 the binding edge is on opposite sides of the page box for the left
 and right pages.

[Facing Pages]
: Facing pages are two sequential pages such that when the document is
 duplex printed they are on separate sheets of paper. Typically, the
 earlier page will be the back side of one sheet and the later page
 will be the front side of another. They are usually laid out so that
 the binding edges of facing pages are vertical and adjacent when the
 pages are placed in their normal reading orientation.

[Left Page]
: A page that would be on the left if it is part of a pair of facing
 pages as typically laid out. Page layouts for documents using a
 left-to-right page progression have the earlier of the facing pages
 on the left. Rules specific to the left page can be specified using
 the [:left](#valdef-page-left) [page
 selector](#page-selector).

[Right Page]
: A page that would be on the right if it is part of a pair of facing
 pages as typically laid out. Page layouts for documents using a
 right-to-left page progression have the earlier of the facing pages
 on the right. Rules specific to the right page can be specified
 using the [:right](#valdef-page-right) [page
 selector](#page-selector).

## 3. The Page Model

In the [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media) formatting model, the document is transferred into one
or more page boxes. The [page box] is a specialized CSS box that maps to a
rectangular print media surface, such as a page of paper. It is roughly
analogous to the
[viewport](https://www.w3.org/TR/CSS2/visuren.html#viewport).
!(images/PageBox.png){height="266" style="float: right;" width="267"}

As with other CSS [boxes](https://www.w3.org/TR/CSS2/box.html), a page
box consists of margin, border, padding, and content areas. The content
and margin areas of a page box have special functions:

In CSS 2.1, both the page box and page
area are simple rectangles. Neither is a CSS box with margins, borders,
and padding. This CSS box should be distinct from the page box and page
area, which would be its margin area and content area, respectively.
Naming ideas?

- The content area of a page box is called the [page area]. The content of the
 document is flowed into one or more page boxes. The page area acts as
 a container for all the boxes generated by the root element and its
 descendants that are laid out within a given page box. The edges of
 the page area on the first page establish the rectangle that is the
 initial [containing
 block](#containing-block)
 of the document.
- The margin area of a page box is divided into 16 [page-margin
 boxes].
 Each page-margin box has its own margin, border, padding and content
 areas. Page-margin boxes are typically used to display running headers
 and footers.

The properties of a [page box](#page-box) are determined by properties declared within the [page
context](#page-context), which is
the [declaration block](https://www.w3.org/TR/CSS2/syndata.html#x14) of
the [\@page](#at-ruledef-page) rule. Similarly the properties of a [page-margin
box](#page-margin-boxes) are
determined by properties declared within its [margin
context](#margin-context).
Declarations in the page context can affect the page box and/or inherit
to the page-margin boxes, but they do not apply to or inherit into the
document's root element or other content.

The [containing block](#containing-block) of the page box is specified using the
[size](#descdef-page-size) property in the [page
context](#page-context). The
width and horizontal margins of the page box are then calculated exactly
as for a [non-replaced block element in normal
flow](https://www.w3.org/TR/CSS2/visudet.html#blockwidth).
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
The height and vertical margins of the page box are calculated
analogously (instead of using the block height formulas). In both cases
if the values are over-constrained, instead of ignoring any margins, the
containing block is resized to coincide with the margin edges of the
page box.

### 3.1. Page Backgrounds and Painting Order

When drawing a page of content, the page layers are painted in the
following painting order (bottommost first):

1. page background
2. document canvas
3. page borders
4. document contents
5. page-margin boxes

In the page model, the page background behaves similar to the root
background: its [background painting
area](https://drafts.csswg.org/css-backgrounds-4/#background-painting-area) is the [bleed area](#bleed-area), which covers the entire page box, including its
margins (regardless of
[background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip)). Page backgrounds are anchored
within the page box's padding area by default (and honor
[background-origin](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-origin) if the UA supports
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3")).
However if
[background-attachment](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-attachment) is
[fixed](https://drafts.csswg.org/css-backgrounds-3/#valdef-background-attachment-fixed) then the image is positioned relative to the
page box including its margins (i.e. the [background positioning
area](https://drafts.csswg.org/css-backgrounds-4/#background-positioning-area) is the page's margin box).

The document canvas background is drawn as the page box's background: by
default its [background painting
area](https://drafts.csswg.org/css-backgrounds-4/#background-painting-area) covers the page box's border box, and for UAs that
support
[\[CSS-BACKGROUNDS-3\]](#biblio-css-backgrounds-3 "CSS Backgrounds and Borders Module Level 3"),
follows the
[background-clip](https://drafts.csswg.org/css-backgrounds-3/#propdef-background-clip) value specified on the root
element. It remains, however, positioned with respect to the root
element or page area as usual.

With respect to the page-margin boxes, the document canvas, page
borders, and all of the document contents are treated as a single
element with a `z-index` value of [0] that establishes a [stacking
context](https://www.w3.org/TR/CSS2/visuren.html#x43)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"):
the page-margin boxes never interleave with parts of the document
content or between the content and the canvas. They may only paint in
front of the document content or behind the document canvas. The page
background is always painted underneath everything else.

The
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) property applies to page-margin
boxes. Since the
[position](https://drafts.csswg.org/css-position-3/#propdef-position) property does not apply to
page-margin boxes,
[z-index](https://drafts.csswg.org/css2/#propdef-z-index) always affects page-margin boxes as
if they were positioned elements regardless of the
[position](https://drafts.csswg.org/css-position-3/#propdef-position) property's value. Each page-margin
boxes always establishes a stacking context.

The default painting order, or [CSS2.1 Appendix
E](https://www.w3.org/TR/CSS2/zindex.html) \"tree order\", of
page-margin boxes with respect to each other is as follows:

1. [\@top-left-corner](#at-ruledef-page-top-left-corner)
2. [\@top-left](#at-ruledef-page-top-left)
3. [\@top-center](#at-ruledef-page-top-center)
4. [\@top-right](#at-ruledef-page-top-right)
5. [\@top-right-corner](#at-ruledef-page-top-right-corner)
6. [\@right-top](#at-ruledef-page-right-top)
7. [\@right-middle](#at-ruledef-page-right-middle)
8. [\@right-bottom](#at-ruledef-page-right-bottom)
9. [\@bottom-right-corner](#at-ruledef-page-bottom-right-corner)
10. [\@bottom-right](#at-ruledef-page-bottom-right)
11. [\@bottom-center](#at-ruledef-page-bottom-center)
12. [\@bottom-left](#at-ruledef-page-bottom-left)
13. [\@bottom-left-corner](#at-ruledef-page-bottom-left-corner)
14. [\@left-bottom](#at-ruledef-page-left-bottom)
15. [\@left-middle](#at-ruledef-page-left-middle)
16. [\@left-top](#at-ruledef-page-left-top)

Start with
[\@top-left-corner](#at-ruledef-page-top-left-corner), then go clockwise. This order is arbitrary but
can be overridden with
[z-index](https://drafts.csswg.org/css2/#propdef-z-index). It only has a visible effect when
page-margin boxes overlap, which should not happen in most cases.

### 3.2. Content outside the page box

When formatting content in the page model, some content may end up
outside the page box. For example, an element whose
[white-space](https://drafts.csswg.org/css-text-4/#propdef-white-space) property has the value
[pre](https://drafts.csswg.org/css-text-4/#valdef-white-space-pre) can generate a box that is wider than the page
box. As another example, when boxes are positioned absolutely or
relatively, they may end up in \"inconvenient\" locations. For example,
images may be placed on the edge of the page box or 100,000 meters below
the page box.

A specification for the exact formatting of such elements lies outside
the scope of this document. However, it is recommended that authors and
user agents observe the following general principles concerning content
outside the page box:

- Content should be allowed slightly beyond the page box to allow pages
 to \"bleed\".

- User agents *SHOULD* avoid generating a large number of content-empty
 pages to honor the positioning of elements (e.g., printing 100 blank
 pages is probably neither the author's nor the user's intent). A
 [Content-empty page] is a page box whose page area contains no printable content
 other than backgrounds and/or borders. A page box whose page area
 contains generated content, or content whose visibility is
 [hidden](https://drafts.csswg.org/css-display-4/#valdef-visibility-hidden), or invisible content such as a zero-width
 space is not a content-empty page. On the other hand, a page
 containing only a background and/or borders and/or page-margin box
 content *is* a content-empty page.

 Note, however, that generating a small number of empty page boxes is
 sometimes necessary to honor the forced-break values for
 [page-break-before](https://drafts.csswg.org/css2/#propdef-page-break-before)/[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) and
 [page-break-after](https://drafts.csswg.org/css2/#propdef-page-break-after)/[break-after](https://drafts.csswg.org/css-break-4/#propdef-break-after).
 [\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
 [\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")

- Authors *SHOULD NOT* position elements in inconvenient locations just
 to avoid rendering them. Instead:
 - To suppress box generation entirely, set the
 [display](https://drafts.csswg.org/css2/#propdef-display) property to
 [none](https://drafts.csswg.org/css-display-4/#valdef-display-none).
 - To make a box invisible, set the
 [[visibility](https://drafts.csswg.org/css-display-4/#propdef-visibility)] property.

- This specification does not define how boxes positioned outside the
 page box are handled. Possibilities include discarding them or
 creating page boxes for them at the end of the document.

### 3.3. Page Progression

CSS distinguishes between left pages and right pages on all documents,
whether they are printed duplex or not. Each left page is followed by a
right page and vice versa. Left and right pages can be styled
differently with the [`:left` and `:right`
pseudo-classes](#left-right-first).

Whether the first page of a document is a left page or a right page
depends on the page progression of the document. The [page
progression] is the direction in which the printed pages of a document
would be sequenced when laid out side-to-side. For example, English and
horizontally-set Japanese typically progress from left to right, whereas
Arabic and vertically-set Japanese pages typically progress from right
to left.

The page progression direction is determined as follows:

- If text is laid out in horizontal lines, the [page
 progression](#page-progression) is the same as the [inline base
 direction](https://drafts.csswg.org/css-writing-modes-4/#inline-base-direction).
- If text is laid out in vertical lines, the [page
 progression](#page-progression) is the same as the [block flow
 direction](https://drafts.csswg.org/css-writing-modes-4/#block-flow-direction).

If the UA supports the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) and
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) properties from the CSS 3 Writing
Modes Module
[\[CSS-WRITING-MODES-3\]](#biblio-css-writing-modes-3 "CSS Writing Modes Level 3"),
it must
[determine](https://www.w3.org/TR/css3-writing-modes/#page-direction)
the [page progression](#page-progression) is determined by the [principal writing
mode](https://drafts.csswg.org/css-writing-modes-4/#principal-writing-mode).

In documents with a left-to-right [page
progression](#page-progression) the first page of the document is a right page, and
vice versa. To explicitly force a document to begin printing on a left
or right page, authors can specify a
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) value that that propagates a page
break to the root.
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
The UA must suppress the first (empty) page(s) in this case (and the
`:first` pseudo-class matches the first printed page).

html { break-before: always }

For an HTML document with a left-to-right page progression, the above
style rule will cause the first page of the document to print on a
\':left\' page

 html { break-before: left }

For an HTML document, the above style rule will cause the first page of
the document to print on a \':left\' page, regardless of the page
progression.

## 4. Page Selectors and the Page Context

### 4.1. The \@page Rule

Authors can specify various aspects of a page box, such as its
dimensions, orientation, and margins, within an
[\@page] rule. [\@page](#at-ruledef-page) rules are allowed wherever
[rule-sets](https://www.w3.org/TR/CSS2/syndata.html#rule-sets) are
allowed. An [\@page](#at-ruledef-page) rule consists of the keyword
[\@page](#at-ruledef-page), an optional comma-separated list of [page
selectors](#page-selector) and
a block of declarations (said to be in the [page context]). An
[\@page](#at-ruledef-page) rule can also contain other at-rules, interleaved
between declarations. The current level of this specification only
allows [margin at-rules](#margin-at-rule) inside
[\@page](#at-ruledef-page).

[\@page](#at-ruledef-page) rules without a selector list apply to every page.
Other [\@page](#at-ruledef-page) rules apply to pages that
[match](#match) at least one of their
selectors. Properties declared within the page context apply to the page
box.

If an error is encountered during the processing of a declaration block
within a page or a margin context, the [Rules for handling parsing
errors](https://www.w3.org/TR/CSS2/syndata.html#parsing-errors) apply;
that is, valid declarations within the block are applied.

### 4.2. Page selectors

A [page selector] is made of either a [page type
selector](#page-type-selector) or a [page
pseudo-class](#page-pseudo-class), followed by zero or more additional [page
pseudo-classes](#page-pseudo-class). No whitespace is allowed between components of a
selector. The
[\<page-selector\>](#typedef-page-selector) grammar and examples can be found
below.

A [page selector](#page-selector) is said to [match] a given page if and only if all of its
components match the page.

A [page type selector] is a case-sensitive [CSS
identifier](https://www.w3.org/TR/CSS2/syndata.html#value-def-identifier)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification").
It [matches](#match) pages of the
[named page type](#using-named-pages) generated by the
[page](#propdef-page) property. [ A page type name of [auto]
([ASCII
case-insensitive](https://www.w3.org/TR/CSS2/syndata.html#characters))
does not make the rule invalid, but must never match.
]

A [page pseudo-class] is [ASCII
case-insensitive](https://www.w3.org/TR/CSS2/syndata.html#characters)
and has the same syntax as
[pseudo-classes](https://www.w3.org/TR/selectors/#pseudo-classes) in
regular Selectors.
[\[SELECT\]](#biblio-select "Selectors Level 3") The
various [page
pseudo-classes](#page-pseudo-class) are defined below.

#### 4.2.1. Spread pseudo-classes: [:left, [:right](#valdef-page-right)]
When printing double-sided documents, left and right pages are often
formatted differently. This can be expressed by using the
[:left](#valdef-page-left) and
[:right](#valdef-page-right) page pseudo-classes.

All pages are automatically classified by user agents as either left
pages or right pages, based on [page progression](#progression). The
[:left] and [:right] pseudo-classes
only [match](#match)
[left](#left-page) or [right
pages](#right-page), respectively.

The following example creates left and
right binding edges using these pseudo-classes:

 @page :left {
 margin-left: 3cm;
 margin-right: 4cm;
 }

 @page :right {
 margin-left: 4cm;
 margin-right: 3cm;
 }

If different declarations have been given for left and right pages, the
user agent must honor these declarations even if the user agent does not
transfer the page boxes to left and right sheets (i.e., a printer that
only prints on one side of the medium must nevertheless produce
correctly formatted output).

***Note.** Adding declarations to the
[:left](#valdef-page-left) or
[:right](#valdef-page-right) pseudo-class does not necessarily influence whether
the document comes out of the printer double- or single-sided (which is
outside the scope of this specification).*

#### 4.2.2. First-page pseudo-class: [:first]
The [:first] pseudo-class
[matches](#match) the first printed
page of a document.

@page { margin: 2cm } /* All margins set to 2cm */

 @page :first {
 margin-top: 10cm /* Top margin on first page 10cm */
 }

#### 4.2.3. Blank-page pseudo-class: [:blank]
The [:blank] pseudo-class
[matches](#match) [content-empty
pages](#content-empty) that
appear as a result of [forced page
breaks](https://www.w3.org/TR/css3-break/#forced-breaks).

Only the
[left](https://drafts.csswg.org/css-break-4/#valdef-break-before-left),
[right](https://drafts.csswg.org/css-break-4/#valdef-break-before-right),
[recto](https://drafts.csswg.org/css-break-4/#valdef-break-before-recto) and
[verso](https://drafts.csswg.org/css-break-4/#valdef-break-before-verso) values of the
[break-before](https://drafts.csswg.org/css-break-3/#propdef-break-before) and
[break-after](https://drafts.csswg.org/css-break-4/#propdef-break-after) properties can generate pages that
match [:blank](#valdef-page-blank).

In this example, forced page break may
occur before `h1` elements.

 h1 { break-before: left }

 @page :blank {
 @top-center { content: "This page is intentionally left blank" }
 }

A page matched by
[:blank](#valdef-page-blank) can also be matched by other page pseudo-classes.

If headers have been specified on all right pages, a blank right page
will be matched by both `:blank` and `:right`. Therefore, margin boxes
set on right pages will have to be removed unless they are wanted on
blank pages. Here is an example where the top center header is removed
from blank pages, while the page number remains:

 h1 { break-before: left }

 @page :blank {
 @top-center { content: none }
 }

 @page :right {
 @top-center { content: "Preliminary edition" }
 @bottom-center { content: counter(page) }
 }

Due to the higher [specificity](#specificity) of `:blank` over `:right`, the top center header is
removed even if `content: none` comes before
`content: "Preliminary edition"`.

***Note.** Future versions of CSS may include other page
pseudo-classes.*

### 4.3. \@page rule grammar

[\@page](#at-ruledef-page) rules are
[parsed](https://drafts.csswg.org/css-syntax-3/#css-parse-something-according-to-a-css-grammar) according to the following grammar, plus the additional
rules noted below:

``` prod
@page = @page <page-selector-list>? { <declaration-rule-list> }
<page-selector-list> = <page-selector>#
<page-selector> = [ <ident-token>? <pseudo-page>* ]!
<pseudo-page> = : [ left | right | first | blank ]

/* Margin rules */
@top-left-corner = @top-left-corner { <declaration-list> };
@top-left = @top-left { <declaration-list> };
@top-center = @top-center { <declaration-list> };
@top-right = @top-right { <declaration-list> };
@top-right-corner = @top-right-corner { <declaration-list> };
@bottom-left-corner = @bottom-left-corner { <declaration-list> };
@bottom-left = @bottom-left { <declaration-list> };
@bottom-center = @bottom-center { <declaration-list> };
@bottom-right = @bottom-right { <declaration-list> };
@bottom-right-corner = @bottom-right-corner { <declaration-list> };
@left-top = @left-top { <declaration-list> };
@left-middle = @left-middle { <declaration-list> };
@left-bottom = @left-bottom { <declaration-list> };
@right-top = @right-top { <declaration-list> };
@right-middle = @right-middle { <declaration-list> };
@right-bottom = @right-bottom { <declaration-list> };
```

In addition, the following rules apply:

- No whitespace is allowed between the productions in
 [\<page-selector\>](#typedef-page-selector) or
 [\<pseudo-page\>](#typedef-pseudo-page) (similar to the rule for
 [\<compound-selector\>](https://drafts.csswg.org/selectors-4/#typedef-compound-selector)).

- The [\@page](#at-ruledef-page) rule can only contain [page
 properties](#page-property)
 and [margin at-rules](#margin-at-rule).

- The [margin at-rules](#margin-at-rule) can only contain [page-margin
 properties](#page-margin-property).

The following are examples of page
selectors (declaration block intentionally left blank)

 @page { ... }
 @page :left { ... }
 @page :right { ... }
 @page LandscapeTable { ... }
 @page CompanyLetterHead:first { ... } /* identifier and pseudo page. */
 @page:first { ... }
 @page toc, index { ... }
 @page :blank:first { ... }

The following are examples of page-margin boxes where the declaration
blocks are intentionally left blank.

 @page {
 @top-left { ... /* document name */ }
 @bottom-center { ... /* page number */}
 }
 @page :left { @left-middle { ... /* page number in left margin */ }}
 @page :right{ @right-middle { ... /* page number in right margins of right pages */}}

 @page :left { @bottom-left-corner { ... /* left page numbers */ }}
 @page :right { @bottom-right-corner { ... /* right page numbers */ }}
 @page :first { @bottom-left-corner { ... /* empty footer on 1st page */ }
 @bottom-right-corner { ... /* empty footer */ } }

### 4.4. Cascading in the page context

Declarations in page and margin contexts
[cascade](https://www.w3.org/TR/CSS2/cascade.html) just like
declarations in style rule for elements.

The [specificity] of a page selector is computed in a manner analogous to the
computations defined in the
[Selectors](https://www.w3.org/TR/CSS2/selector.html) module:

- Count the number of page type names (= `f`)

 Given the syntax of page selectors, `f` can only ever be 0
 or 1.

- Count the number of \':first\' or \':blank\' pseudo-classes (=
 `g`)

- Count the number of \':left\' or \':right\' pseudo-classes (=
 `h`)

Note: Repeated occurrences of the same pseudo-classes are allowed and do
increase specificity.

Due to storage limitations, implementations may have limitations on the
size of `f`, `g`, or `h`. If so, values
higher than the limit must be clamped to that limit, and not overflow.

Specificities are compared by comparing the three components in order
(`f`, `g`, `h`): the specificity with a
larger `f` value is more specific; if the two `f`
values are tied, then the two `g` values are compared, etc.
If all the values are tied, the two specificities are equal.

Some page specificity calculation examples follow:

 @page /* specificity = (0,0,0) */
 @page :left /* specificity = (0,0,1) */
 @page :first /* specificity = (0,1,0) */
 @page :blank:left /* specificity = (0,1,1) */
 @page artsy /* specificity = (1,0,0) */
 @page artsy:left /* specificity = (1,0,1) */
 @page artsy:first /* specificity = (1,1,0) */

Consider the following usage example:

 @page :left {
 margin-left: 4cm;
 }

 @page {
 margin-left: 3cm;
 }

Due to the higher specificity of the pseudo-class selector, the left
margin on left pages will be 4cm and all other pages (the right-facing
pages) will have a left margin of 3cm.

In this example, the higher
specificity of the green rules wins over the red rule. Therefore the
first page will have blue text in the top-left page-margin box and green
text in the top-right page-margin box, while subsequent pages will have
red text in the page-margin boxes.

 @page :first {
 color: green;

 @top-left {
 content: "foo";
 color: blue;
 }
 @top-right {
 content: "bar";
 }
 }

 @page { color: red;
 @top-center {
 content: "Page " counter(page);
 }
 }

Page contexts cascade, so the following stylesheet would style pages
with 25 millimeter margins and 14 point type in the page-margin boxes:

 @page { margin: 25mm;}
 @page { font-size: 14pt;}

## 5. Page-Margin Boxes

Page-margin boxes are boxes within the page margin that, like
pseudo-elements, can contain generated content.

Page-margin boxes can be used to create page headers and footers, which
are portions of the page set aside for supplementary information such as
the page number or document title.

Typically, a [page
header] is
located at the top of the page in documents with a predominately
horizontal writing direction and on the side opposite the [binding
edge](#binding-edge) for
documents with a predominately vertical writing direction. One possible
design of page headers for horizontally written documents uses the
[\@top-left-corner](#at-ruledef-page-top-left-corner),
[\@top-left](#at-ruledef-page-top-left),
[\@top-center](#at-ruledef-page-top-center),
[\@top-right](#at-ruledef-page-top-right) and
[\@top-right-corner](#at-ruledef-page-top-right-corner) page-margin boxes. Another design, for
vertically written documents, could use the
[\@right-top](#at-ruledef-page-right-top),
[\@right-middle](#at-ruledef-page-right-middle), and
[\@right-bottom](#at-ruledef-page-right-bottom) page-margin boxes for [right facing
pages](#right-page) and
[\@left-top](#at-ruledef-page-left-top),
[\@left-middle](#at-ruledef-page-left-middle), and
[\@left-bottom](#at-ruledef-page-left-bottom) for [left facing
pages](#left-page).

The [page footer] is typically at the opposite end of the page from the page
header. For example, the design of a horizontally written document with
a page header at the top of the page could use the
[\@bottom-left-corner](#at-ruledef-page-bottom-left-corner),
[\@bottom-left](#at-ruledef-page-bottom-left),
[\@bottom-center](#at-ruledef-page-bottom-center),
[\@bottom-right](#at-ruledef-page-bottom-right) and
[\@bottom-right-corner](#at-ruledef-page-bottom-right-corner) page-margin boxes as the page footer. The design
of a vertically written document could use the page-margin boxes of the
binding edge of the page for the page footer.

Page-margin boxes are positioned with respect to the page area and are
independent of page orientation, for example the top page-margin boxes
are above the page area in both portrait and landscape orientation. The
various page-margin boxes are defined and illustrated in the diagram
below:

Table 1 Page-Margin Box Definitions

Box

Description

Placement

top-left-corner

a fixed-size box defined by the intersection of the top and left margins
of the page box

![the top left corner box with margin, border, and padding, nested
within intersection of the page\'s top and left
margins](images/TopLeftCornerBox.png){height="47" width="181"}

top-left

a variable-width box filling the top page margin between the
top-left-corner and top-center page-margin boxes

![the top left box with margin, border, and padding, nested in the
page\'s top margin next to the top left corner
box](images/TopLeftMarginBox.png){height="47" width="181"}

top-center

a variable-width box centered horizontally between the page's left and
right border edges and filling the page top margin between the top-left
and top-right page-margin boxes

![the top center box with margin, border, and padding, centered within
the page\'s top margin](images/TopCenterMarginBox.png){height="47"
width="181"}

top-right

a variable-width box filling the top page margin between the top-center
and top-right-corner page-margin boxes

![the top right box with margin, border, and padding, nested within the
page\'s top margin](images/TopRightMarginBox.png){height="47"
width="181"}

top-right-corner

a fixed-size box defined by the intersection of the top and right
margins of the page box

![the top right corner box with margin, border, and padding, nested
within the intersection of the page\'s top and right
margin](images/TopRightCornerMarginBox.png){height="47" width="181"}

left-top

a variable-height box filling the left page margin between the
top-left-corner and left-middle page-margin boxes

![left-top, left-middle, and left-bottom page-margin boxes in the page
box\'s left margin](images/LeftMarginBoxes.png){height="226"
width="181"}

left-middle

a variable-height box centered vertically between the page's top and
bottom border edges and filling the left page margin between the
left-top and left-bottom page-margin boxes

left-bottom

a variable-height box filling the left page margin between the
left-middle and bottom-left-corner page-margin boxes

right-top

a variable-height box filling the right page margin between the
top-right-corner and right-middle page-margin boxes

![right-top, right-middle, and right-bottom page-margin boxes in the
page box\'s right margin](images/RightMarginBoxes.png){height="226"
width="181"}

right-middle

a variable-height box centered vertically between the page's top and
bottom border edges and filling the right page margin between the
right-top and right-bottom page-margin boxes

right-bottom

a variable-height box filling the right page margin between the
right-middle and bottom-right-corner page-margin boxes

bottom-left-corner

a fixed-size box defined by the intersection of the bottom and left
margins of the page box

![bottom left corner box with margin, border, and padding, nested within
the page margin at the intersection of the left and bottom page
margins](images/BottomLeftCornerBox.png){height="48" width="181"}

bottom-left

a variable-width box filling the bottom page margin between the
bottom-left-corner and bottom-center page-margin boxes

![bottom left page-margin box with margin, border, and padding, nested
within the page\'s bottom margin next to the bottom-left-corner
box](images/BottomLeftMarginBox.png){height="48" width="181"}

bottom-center

a variable-width box centered horizontally between the page's left and
right border edges and filling the bottom page margin between the
bottom-left and bottom-right page-margin boxes

![bottom center box with margin, border, and padding, nested within the
page\'s bottom margin and centered on the
page](images/BottomCenterMarginBox.png){height="48" width="181"}

bottom-right

a variable-width box filling the bottom page margin between the
bottom-center and bottom-right-corner page-margin boxes

![bottom right page-margin box with margin, border, and padding, nested
within the page\'s bottom margin and next to the bottom-right-corner
box](images/BottomRightMarginBox.png){height="48" width="181"}

bottom-right-corner

a fixed-size box defined by the intersection of the bottom and right
margins of the page box

![bottom right corner box with margin, border, and padding, nested
within the page margin at the intersection of the right and bottom page
margins](images/BottomRightCornerBox.png){height="48" width="181"}

### 5.1. At-rules for page-margin boxes

Page-margin boxes are created by [margin
at-rules](#margin-at-rule)
inside the [page context](#page-context).
Authors should put these rules after any declarations in the page
context as legacy clients may not handle declarations after margin
at-rules correctly.

A [margin at-rule] is an
[at-rule](https://drafts.csswg.org/css-syntax-3/#at-rule) that identifies the page-margin box (e.g.
[\@top-left](#at-ruledef-page-top-left)) and a block of descriptors (said to be in the
[margin context]).

The following style sheet establishes a page header containing the title
(\"Hamlet\") on the left side and the page number, preceded by \"Page
\", on the right side:

 @page {
 size: 8.5in 11in;
 margin: 10%;

 @top-left {
 content: "Hamlet";
 }
 @top-right {
 content: "Page " counter(page);
 }
 }

### 5.2. Populating page-margin boxes

As with the
[:before](https://drafts.csswg.org/css2/#selectordef-before) and
[:after](https://drafts.csswg.org/css2/#selectordef-after) pseudo-elements, a specified [content:
normal](https://drafts.csswg.org/css-content-3/#propdef-content) on a page-margin box computes to
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none). A page-margin box is [generated] if and only if the
computed value of its
[content](https://drafts.csswg.org/css-content-3/#propdef-content) property is not
[none](https://drafts.csswg.org/css-content-3/#valdef-content-none). Otherwise, no box is generated, as for elements
with [display:
none](https://drafts.csswg.org/css2/#propdef-display).

The
[display](https://drafts.csswg.org/css2/#propdef-display) property does not apply to
page-margin boxes.

The following style sheet creates a
green box in each corner of the page except the bottom-left corner.

 @page {
 @top-left-corner { content: " "; border: solid green; }
 @top-right-corner { content: url(foo.png); border: solid green; }
 @bottom-right-corner { content: counter(page); border: solid green; }
 @bottom-left-corner { content: normal; border: solid green; }
 }

### 5.3. Computing Page-margin Box Dimensions

The width and height of each page-margin box is determined by the rules
below. These rules define the equivalent of CSS2.1 Sections 10.3 and
10.6 for page-margin boxes.

The rules for applying
[min-height](https://drafts.csswg.org/css2/#propdef-min-height),
[max-height](https://drafts.csswg.org/css2/#propdef-max-height),
[min-width](https://drafts.csswg.org/css2/#propdef-min-width), and
[max-width](https://drafts.csswg.org/css2/#propdef-max-width)
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
do apply to page-margin boxes and may imply a recalculation of the
width, height, and/or margins if the dimensions resulting from the
specified
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) or
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height) violate their constraints. If the
UA does not support the
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) or
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) properties then it must behave as
if
[min-height](https://drafts.csswg.org/css2/#propdef-min-height) and
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) were always zero.

#### 5.3.1. Page-Margin Box Layout Terminology

In addition to the box model definitions in CSS2.1
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
and the sizing terms in CSS Sizing
[\[CSS-SIZING-3\]](#biblio-css-sizing-3 "CSS Box Sizing Module Level 3"),
the following terms are defined for use in the subsequent page-margin
box calculations:

[available width]
: The sum of the page's left border width, left padding, [page
 area](#page-box) width, right
 padding, and right border width. In other words, it is the distance
 between the [page box](#page-box)'s left right border edges. This quantity is used
 when calculating dimensions of the top and bottom page-margin boxes.

[available height]
: The sum of the page's top border width, top padding, [page
 area](#page-box) height, bottom
 padding, and bottom border width. In other words, it is the distance
 between the [page box](#page-box)'s top bottom border edges. This quantity is used
 when calculating dimensions of the left and right page-margin boxes.

[outer width]
: The width of the [outer
 edge](https://drafts.csswg.org/css-box-4/#outer-edge), as defined in
 [\[CSS-BOX-3\]](#biblio-css-box-3 "CSS Box Model Module Level 3").

[min-content width]
: Whichever of [min-content block
 size](https://drafts.csswg.org/css-sizing-3/#min-content-block-size) or [min-content inline
 size](https://drafts.csswg.org/css-sizing-3/#min-content-inline-size) is the physical width.

[max-content width]
: Whichever of [max-content block
 size](https://drafts.csswg.org/css-sizing-3/#max-content-block-size) or [max-content inline
 size](https://drafts.csswg.org/css-sizing-3/#max-content-inline-size) is the physical width.

[outer min width]
: Like the [outer width](#outer-width), except the [min-content
 width](#min-content-width) is used when the computed
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) is
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).

[outer max width]
: Like the [outer width](#outer-width), except the [max-content
 width](#max-content-width) is used when the computed
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) is
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto).

The [containing block] for a page-margin box depends on its
location:

For a corner page-margin box, it is the rectangle defined by the
intersection of the two page margins meeting at that corner.

For all other page-margin boxes, the [containing
block](#containing-block) is
the rectangle formed by the encapsulating page margin minus the
containing blocks of the adjacent corners\' page-margin boxes. This
means that the size of this containing block is given in one dimension
by the used page margin and in the other dimension by the [available
width](#available-width) (for
top and bottom page-margin boxes) or [available
height](#available-height)
(for left and right page-margin boxes).

#### 5.3.2. Page-Margin Box Variable Dimension Computation Rules

The following rules apply to
[\@top-left](#at-ruledef-page-top-left),
[\@top-center](#at-ruledef-page-top-center) and
[\@top-right](#at-ruledef-page-top-right) page-margin boxes, which are referred to as A,
B, and C, respectively, in this section.

##### 5.3.2.1. Margins

If the
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left) or
[margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right) property of any of the three boxes
computes to [auto], the used value is zero.

##### [5.3.2.2. ][Resolving [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) widths]
The following algorithm determines the used width of each box. For this
purpose, boxes that are not [generated](#generated) are assumed to have a
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and an [outer
width](#outer-width) of zero.

Note: The high-level goals are (in order of priority) to center the
middle box (B) if it is generated, to minimize overflow and overlap, and
to distribute space proportionally to the amount of content.

If the middle box (B) is not [generated](#generated), distribute the [available
width](#available-width) to A
and C as follows:

- If only one box has \'width: auto\', its used width is resolved so
 that the sum of the [outer width](#outer-width)s equals [available
 width](#available-width).
- [(#flex-fit) If A and C both have \'width: auto\',
 distribute the space to each box as follows:]
 1. If the sum of the outer [max-content
 widths](#max-content-width) is less than the [available
 width](#available-width), call that difference the [flex
 space].
 Calculate each box's [flex factor] as proportional to its outer
 [max-content
 width](#max-content-width), and set its used outer width to:
 [`max-content width`](#max-content-width)` + `[`flex space`](#flex-space)` × `[`flex factor`](#flex-factor)` ÷ ∑`[`flex factors`](#flex-factor)
 2. Otherwise if the sum of the outer [min-content
 widths](#min-content-width) is less than the [available
 width](#available-width), call that difference the [flex
 space](#flex-space)
 calculate each box's [flex
 factor](#flex-factor) as
 proportional to its [max-content
 width](#max-content-width) minus [min-content
 width](#min-content-width), and set its used outer width to:
 [`min-content width`](#min-content-width)` + `[`flex space`](#flex-space)` × `[`flex factor`](#flex-factor)` ÷ ∑`[`flex factors`](#flex-factor)
 3. Otherwise, calculate its outer size as in the previous case, but
 set each box's [flex factor](#flex-factor) as proportional to its outer [min-content
 width](#min-content-width).

 In each case, both [flex factors](#flex-factor) are assumed to be [1] if their sum is equal to
 zero.

If the middle box (B) is [generated](#generated), determine the
[auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) widths of A, B, and C as follows:

1. First, resolve any
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) width of the middle box (B): Assume there
 are two boxes, B and AC, where each of AC's dimensions is double the
 maximum of A and C. (This preserves B's centering.) Distribute the
 space to these two boxes (B and the imaginary AC) as described for A
 and C [above](#flex-fit).
2. Then, resolve any
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto) widths of the side boxes (A and C) by
 setting that box's outer width to
 `(`[`available width`](#available-width)` − used `[`outer width`](#outer-width)`s of B) ÷ 2`

##### [5.3.2.3. ][Handling [min-width](https://drafts.csswg.org/css2/#propdef-min-width) and [max-width](https://drafts.csswg.org/css2/#propdef-max-width)]
The
[min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
[max-width](https://drafts.csswg.org/css2/#propdef-max-width) properties
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
apply to page-margin boxes in the variable dimension like on normal
elements, except that the three boxes on the same side are considered
together.

More precisely:

1. The tentative used widths are calculated (without
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width) and
 [max-width](https://drafts.csswg.org/css2/#propdef-max-width)) following the rules under
 [§ 5.3.2.2 Resolving auto widths](#variable-auto-sizing).
2. If the tentative used width of any of the three boxes is greater
 than
 [max-width](https://drafts.csswg.org/css2/#propdef-max-width), the rules above are applied
 again, but this time using the computed value of
 [max-width](https://drafts.csswg.org/css2/#propdef-max-width) as the computed value for
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width).
3. If the resulting width of any of the three boxes is smaller than
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width), the rules above are applied
 again, but this time using the value of
 [min-width](https://drafts.csswg.org/css2/#propdef-min-width) as the computed value for
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width).

##### 5.3.2.4. Positioning

Once the dimensions of the boxes are determined, they are positioned as
follows:

- The left outer edge of A is flush with the left edge of the containing
 block
- The outer area of B is centered in the containing block.
- The right outer edge of C is flush with the right edge of the
 containing block.

##### 5.3.2.5. Boxes on other sides

The used values for
[\@bottom-left](#at-ruledef-page-bottom-left),
[\@bottom-center](#at-ruledef-page-bottom-center) and
[\@bottom-right](#at-ruledef-page-bottom-right) page-margin boxes are established by the same
rules as for
[\@top-left](#at-ruledef-page-top-left),
[\@top-center](#at-ruledef-page-top-center), and
[\@top-right](#at-ruledef-page-top-right), respectively.

The used values for
[\@left-top](#at-ruledef-page-left-top),
[\@left-middle](#at-ruledef-page-left-middle) and
[\@left-bottom](#at-ruledef-page-left-bottom) boxes are established by the same rules, with
\"width\" replaced by \"height\", \"left\" by \"top\", \"right\" by
\"bottom\" and \"center\" by \"middle\".

The used values for
[\@right-top](#at-ruledef-page-right-top),
[\@right-middle](#at-ruledef-page-right-middle) and
[\@right-bottom](#at-ruledef-page-right-bottom) page-margin boxes are established by the same
rules as for
[\@left-top](#at-ruledef-page-left-top),
[\@left-middle](#at-ruledef-page-left-middle) and
[\@left-bottom](#at-ruledef-page-left-bottom), respectively.

#### 5.3.3. Page-Margin Box Fixed Dimension Computation Rules

The rules below are used to calculate the used values of each
[\@top-left-corner](#at-ruledef-page-top-left-corner),
[\@top-left](#at-ruledef-page-top-left),
[\@top-center](#at-ruledef-page-top-center),
[\@top-right](#at-ruledef-page-top-right), and
[\@top-right-corner](#at-ruledef-page-top-right-corner) page-margin box's
[height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top), and
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) properties:

1. The following constraint must hold among the used values of the
 margin box's properties:

 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) +
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width) +
 [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top) +
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) +
 [padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom) +
 [border-bottom-width](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-width) +
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) = top page margin

2. If
 [border-top-width](https://drafts.csswg.org/css-borders-4/#propdef-border-top-width) +
 [padding-top](https://drafts.csswg.org/css-box-4/#propdef-padding-top) +
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) (if it is not
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto)) +
 [padding-bottom](https://drafts.csswg.org/css-box-4/#propdef-padding-bottom) +
 [border-bottom-width](https://drafts.csswg.org/css-borders-4/#propdef-border-bottom-width), plus
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and/or
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) if not [auto], is larger
 than the height of the top page margin, then any [auto] values
 for
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) or
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) are, for the following rules,
 treated as
 [\<safe-printable-inset\>](#typedef-safe-printable-inset).

3. If at this point all of
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height),
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top), and
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) have a computed value other
 than
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), the values are said to be
 \"over-constrained\". In this case, the specified value of
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) is treated as [auto].

4. If there is now exactly one value specified as [auto], its
 used value follows from the equality.

5. If
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) is set to
 [auto](https://drafts.csswg.org/css-sizing-3/#valdef-width-auto), any [auto] margin values become
 [\<safe-printable-inset\>](#typedef-safe-printable-inset) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) follows from the resulting
 equality.

6. If both
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) and
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) are [auto], their used
 values become equal. This vertically centers the page-margin box
 content within the top page margin. If
 [\<safe-printable-inset\>](#typedef-safe-printable-inset) is not [0] here, an
 additional adjustment step is performed: If the resulting
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top) in the previous step became
 less than
 [\<safe-printable-inset\>](#typedef-safe-printable-inset), subtract as much as possible of
 this difference from
 [margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) without making it negative.
 Then add this value to
 [margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top).

The same rules apply to the bottom page-margin boxes
(bottom-left-corner, bottom-left, bottom-center, bottom-right, and
bottom-right-corner), except that in the overconstrained case, the
[margin-bottom](https://drafts.csswg.org/css-box-4/#propdef-margin-bottom) is ignored rather than the
[margin-top](https://drafts.csswg.org/css-box-4/#propdef-margin-top).

Analogous rules govern the properties for the left and right page-margin
boxes with respect to
[width](https://drafts.csswg.org/css-sizing-3/#propdef-width) (top-left-corner, left-top,
left-middle, left-bottom, and bottom-left-corner; top-right-corner,
right-top, right-middle, right-bottom, bottom-right-corner), with
\"top\" replaced by \"left\", \"bottom\" replaced by \"right\", and
\"height\" replaced by \"width\". In the overconstrained case for left
(right) page-margin boxes, the specified value of
[margin-left](https://drafts.csswg.org/css-box-4/#propdef-margin-left)
([margin-right](https://drafts.csswg.org/css-box-4/#propdef-margin-right)) is ignored.

### 5.4. Page-margin box examples

The following is a collection of examples of page-margin box usage.

Here is an example of a page with only
a top-left header:

 @page {
 @top-left { content: "Header in Left Cell (top-left)" }
 }

Because there are no contents defined for the top-center or the
top-right page-margin boxes, the extent of the top-left page-margin box
is allowed to cross the center of the page box.

![Header Example 1](images/header-ex-1.png){height="177" width="737"}

The following is an example of a page
with a centered header:

 @page {
 @top-center { content: "Header in Center Cell (top-center)" }
 }

![Header Example 2](images/header-ex-2.png){height="177" width="737"}

The following is an example of a page
with a single header in the top-right page-margin box:

 @page {
 @top-right { content: "Header in Right Cell (top-right)" }
 }

Because the content of the center cell is empty, the extent of the
top-right page-margin box is allowed to cross the center of the page
box.

![Header Example 3](images/header-ex-3.png){height="177" width="737"}

The following is an example of a page
with a top-center and a top-left header:

 @page {
 @top-left { content: "Left Cell (top-left)" }
 @top-center { content: "Header in Center Cell (top-center)" }
 }

![Header Example 4](images/header-ex-4.png){height="177" width="737"}

The following is an example of a page
with a top-center and a top-right header:

 @page {
 @top-center { content: "Header in Center Cell (top-center)" }
 @top-right { content: "Right Cell (top-right)" }
 }

margin: 10%;

![Header Example 5](images/header-ex-5.png){height="177" width="737"}

The following is an example of a page
with top-left and top-right headers:

 @page {
 @top-left { content: "Header in top-left with approx. twice as many words as right cell." }
 @top-right { content: "Right cell (top-right)" }
 }

Because there are no center cell contents, the extent of the top-left is
allowed to cross the center of the page box.

![Header Example 6](images/header-ex-6.png){height="177" width="737"}

## 6. Page Properties

[Appendix A](#properties-list) defines the normative list of CSS 2.1
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
[properties that apply to page boxes](#page-property-list). If a
conforming user agent supports any of these properties on block boxes,
then it must also support that property in the [page
context](#page-context). This
specification additionally defines the
[size](#descdef-page-size) property that only applies in the page context.

Properties that apply to the page-margin boxes can also be set within
the page context: if inheritable or explicitly inherited (with the
[inherit](https://drafts.csswg.org/css-cascade-5/#valdef-all-inherit) keyword in the margin context), they will
inherit to the page-margin boxes.

The same appendix defines the normative list of CSS 2.1
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
[properties that apply to page-margin boxes](#page-property-list). If a
conforming user agent supports any of these properties on block boxes,
then it must also support that property in the [margin
context](#margin-context).

Other properties defined by
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
do not apply in these contexts. Behavior for properties not included in
CSS 2.1 is undefined.

 The intent of leaving other properties undefined is to
allow the gradual addition of appropriate CSS3 properties as they
emerge, without having to update this specification with each addition.

[As with elements in the
document](https://www.w3.org/TR/CSS2/cascade.html#value-stages), both
the page context and the margin context have a computed value for every
property, even if that property does not apply to the page or
page-margin box.

The normal rules for CSS properties apply with the following exceptions:

- page-margin boxes inherit from the page context. The page context
 inherits from the root element. However, since the previous revision
 of CSS Paged Media Level 3 did not specify this point, an
 implementation that sets inherited properties in the page context to
 their initial values (as for the root element) is also conformant to
 CSS Paged Media Level 3. Note that this exception will be removed in
 Level 4.
- Values in units of
 [em](https://drafts.csswg.org/css-values-4/#em) and
 [ex](https://drafts.csswg.org/css-values-4/#ex) are interpreted relative to the font associated
 with their context. When used on the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property in the margin context,
 they are relative to the font of the page context. When used on the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) property in the page context,
 they are relative to the
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) of the root element. However,
 since a previous revision of CSS Paged Media Level 3 was ambiguous on
 this point, an implementation that treats
 [em](https://drafts.csswg.org/css-values-4/#em) and
 [ex](https://drafts.csswg.org/css-values-4/#ex) on
 [font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) as relative to the initial value
 is also conformant to CSS Paged Media Level 3. Note that this
 exception will be removed in Level 4.
- Percentage values on the margin and padding properties are relative to
 the dimensions of the containing block. For right and left values,
 percentages are relative to the width of the containing block; for top
 and bottom values, percentages are relative to the height of the
 containing block.
- The used values of
 [width](https://drafts.csswg.org/css-sizing-3/#propdef-width) and
 [height](https://drafts.csswg.org/css-sizing-3/#propdef-height) have special computation rules
 for page boxes and page-margin boxes; see [Page Size](#page-size) and
 [Computing Page-Margin Box Dimensions](#margin-dimension).
- The page background is positioned and painted [as described
 above](#painting).
- The rules for counter scoping are modified [as described
 below](#page-based-counters).
- As on the \'::before\' and \'::after\' pseudo-elements, the
 [normal](https://drafts.csswg.org/css-content-3/#valdef-content-normal) value of the
 [content](https://drafts.csswg.org/css-content-3/#propdef-content) property computes to
 [none](https://drafts.csswg.org/css-content-3/#valdef-content-none) on page-margin boxes.
- On page-margin boxes, the
 [vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align) property behaves [as specified
 for table
 cells](https://www.w3.org/TR/CSS2/tables.html#height-layout). It
 *always* performs alignment in the vertical dimension, regardless of
 writing mode.

User agents should establish a default page margin via the user agent
stylesheet that includes any non-printable area. Authors should assume
that the default page area will not include unprintable regions.

### 6.1. Page-based counters

Counters can be defined and controlled within an
[\@page](#at-ruledef-page) rule, and used as content in page-margin boxes. This
is useful for maintaining a page count.

A
[counter-increment](https://drafts.csswg.org/css2/#propdef-counter-increment) within either a page or margin
context causes the counter to increment with the generation of each page
box.

If a counter is reset or incremented within the page context, it is in
scope for all page-margin boxes and obscures all counters of the same
name within the document.

If a counter is reset or incremented within a margin context, it is in
scope for that page-margin box and obscures any counters of the same
name in both the page context and the document.

If a counter that has not been reset or incremented within the margin
context or the page context is used by counter() or counters() in the
margin context, then the resultant value is exactly as if the
page-margin box were an element within the document at the start of the
page, inside the deepest element in the normal flow that spans the page
break. Use of the counter in this way does not affect the calculation of
the counter's value.

A counter named [page] is automatically created and incremented by
1 on every page of the document, unless the
[counter-increment](https://drafts.csswg.org/css2/#propdef-counter-increment) property in the [page
context](#page-context)
explicitly specifies a different increment for the [page] counter.
The implied [page] counter is a real counter, and can be directly
affected using the
[counter-increment](https://drafts.csswg.org/css2/#propdef-counter-increment) and
[counter-reset](https://drafts.csswg.org/css2/#propdef-counter-reset) properties when named explicitly in
those properties. It can also be used in the \'counter()\' and
\'counters()\' function forms.

The following rules result in the
placement of the current page number in the middle of the outside margin
of each page.

 @page {
 margin: 10%;

 @top-center {
 font-family: sans-serif;
 font-weight: bold;
 font-size: 2em;
 content: counter(page);
 }
 }

Adding the following rule will make all pages even-numbered.

 @page {
 counter-increment: page 2;
 }

Additionally, a counter named [pages] is automatically created by
the UA. Its value is always the total number of pages in the document.
(In continuous media this is always 1.) The value of [pages]
cannot be manipulated: while
[counter-reset](https://drafts.csswg.org/css2/#propdef-counter-reset) and
[counter-increment](https://drafts.csswg.org/css2/#propdef-counter-increment) statements that set it are valid,
they have no effect.

In all other respects, page-associated counters behave as described in
[\[CSS2\]](#biblio-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification"),
[Nested Counters and
Scope](https://www.w3.org/TR/CSS2/generate.html#scope) and
[Counters](https://www.w3.org/TR/CSS2/syndata.html#counter).

### 6.2. Page-margin boxes and default values

Properties used within page or margin contexts take their initial values
from their respective property definitions; however, user agents must
behave as though the values in the following table were established by
rules in the UA default style sheet.

Table 2. Default values for Page-Margin Boxes

Page-margin box

[text-align](https://drafts.csswg.org/css-text-3/#propdef-text-align)

[vertical-align](https://drafts.csswg.org/css-inline-3/#propdef-vertical-align)

[top-left-corner](#top-left-corner-box-def)

right

middle

[top-left](#top-left-box-def)

left

middle

[top-center](#top-center-box-def)

center

middle

[top-right](#top-right-box-def)

right

middle

[top-right-corner](#top-right-corner-box-def)

left

middle

[left-top](#left-top-box-def)

center

top

[left-middle](#left-middle-box-def)

center

middle

[left-bottom](#left-bottom-box-def)

center

bottom

[right-top](#right-top-box-def)

center

top

[right-middle](#right-middle-box-def)

center

middle

[right-bottom](#right-bottom-box-def)

center

bottom

[bottom-left-corner](#bottom-left-corner-box-def)

right

middle

[bottom-left](#bottom-left-box-def)

left

middle

[bottom-center](#bottom-center-box-def)

center

middle

[bottom-right](#bottom-right-box-def)

right

middle

[bottom-right-corner](#bottom-right-corner-box-def)

left

middle

This example style sheet could be used
to create a centered header with the current chapter name:

 body {counter-reset: chapter;}
 div.chapter {counter-increment: chapter;}
 @page {
 margin: 10%;
 @top-center { content: "Chapter" counter(chapter) }
 }

## 7. Page Size

People around the world use many different paper sizes. It is a goal of
this specification that web content should be adaptable to a range of
different sizes without having to write a specific style sheet for each
paper size.

However, in some situations it is important that a certain page size
achieves a certain style. One way to achieve this goal is to utilize the
[size](#descdef-page-size) property, which indicates that the document should
preferentially be displayed on a surface of a certain size; another
method is to use Media Queries
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
which allow different style sheets to be applied to different page
sizes.

### 7.1. Page size: the [size property]
Name:

[size]

For:

[\@page](#at-ruledef-page)

Value:

[\<length
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)[{1,2}](https://drafts.csswg.org/css-values-4/#mult-num-range)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[
[\<page-size\>](#typedef-page-size-page-size)
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) \[ portrait
[\|](https://drafts.csswg.org/css-values-4/#comb-one) landscape \] \]

Initial:

auto

Computed value:

specified value, with
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)s made absolute.

This property specifies the target size and orientation of the [page
box](#page-box)'s containing block.
In the general case, where one page box is rendered onto one [page
sheet](#page-sheet), the
[size](#descdef-page-size) property also indicates the size of the
destination page sheet.

The size of a page box can either be \"absolute\" (fixed size) or
\"scalable\" (i.e., fitting available sheet sizes). The first three
values in the table below can be used to create scalable page boxes.
Other values define a fixed-size page box, and thereby indicate the
preferred output media size. When possible, output should be rendered on
the media size indicated. If the specified size is not available, the
rules for [transposing a page box to a different size](#renderingpages)
apply.

If a [size](#descdef-page-size) property declaration is qualified by a
[width](https://drafts.csswg.org/css-anchor-position-1/#valdef-anchor-size-width),
[height](https://drafts.csswg.org/css-anchor-position-1/#valdef-anchor-size-height), [device-width], [device-height],
[aspect-ratio], [device-aspect-ratio] or [orientation]
media query
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4")
(or other conditional on the size of the paper), then the declaration
must be [ignored](https://www.w3.org/TR/CSS2/conform.html#ignore). Media
queries do not honor
[size](#descdef-page-size): they assume the paper size that would be chosen
if no [\@page](#at-ruledef-page) rules were specified.

It would be useful if media queries
could respond at least to sizes specified on an unqualified \@page.

Another option could be to do like [\@viewport] rules
[\[CSS-DEVICE-ADAPT\]](#biblio-css-device-adapt "CSS Viewport Module Level 1"):
First apply [\@page](#at-ruledef-page) rules (matching which selectors?), using the UA's
default page size for Media Queries and [viewport-percentage
lengths](https://www.w3.org/TR/css3-values/#viewport-relative-lengths)
[\[CSS-VALUES-3\]](#biblio-css-values-3 "CSS Values and Units Module Level 3").
The resulting page size is the \"base page size\". The entire set of
stylesheets is applied again, this time using the \"base page size\" for
Media Queries and viewport-percentage lengths.

In the following example

 @page {
 size: 4in 6in;
 }

 @media (max-width: 6in) {
 @page {
 size: letter;
 }
 }

The second `size` declaration is ignored, i.e. the specified value of
the `size` property is `4in 6in`.

[auto]
: The page box will be set to a size and orientation chosen by the UA.
 In the usual case, the page box size and orientation is chosen to
 match the target media sheet.

[landscape]
: Specifies that the page's content be printed in landscape
 orientation. The longer sides of the page box are horizontal. If a
 [\<page-size\>](#typedef-page-size-page-size) is not specified, the size of the
 page sheet is chosen by the UA.

[portrait]
: Specifies that the page's content be printed in portrait
 orientation. The shorter sides of the page box are horizontal. If a
 [\<page-size\>](#typedef-page-size-page-size) is not specified, the size of the
 page sheet is chosen by the UA.

[[\<length \[0,∞\]\>](https://drafts.csswg.org/css-values-4/#length-value)]
: The page box will be set to the given absolute dimension(s). If only
 one length value is specified, it sets both the width and height of
 the page box (i.e., the box is a square). If two length values are
 specified, the first establishes the page box width, and the second
 the page box height. Values in units of
 [em](https://drafts.csswg.org/css-values-4/#em) and
 [ex](https://drafts.csswg.org/css-values-4/#ex) refer to the page context's font. Negative
 lengths are illegal.

[[\<page-size\>](#typedef-page-size-page-size)]
: A page size can be specified using one of the following media names.
 This is the equivalent of specifying
 [size](#descdef-page-size) using length values. The definition of the
 media names comes from Media Standardized Names
 [\[PWGMSN\]](#biblio-pwgmsn "Media Standardized Names.").

 [A5]
 : Equivalent to the size of ISO A5 media: 148mm wide and 210 mm
 high.

 [A4]
 : Equivalent to the size of ISO A4 media: 210 mm wide and 297 mm
 high.

 [A3]
 : Equivalent to the size of ISO A3 media: 297mm wide and 420mm
 high.

 [B5]
 : Equivalent to the size of ISO B5 media: 176mm wide by 250mm
 high.

 [B4]
 : Equivalent to the size of ISO B4 media: 250mm wide by 353mm
 high.

 [JIS-B5]
 : Equivalent to the size of JIS B5 media: 182mm wide by 257mm
 high.

 [JIS-B4]
 : Equivalent to the size of JIS B4 media: 257mm wide by 364mm
 high.

 [letter]
 : Equivalent to the size of North American letter media: 8.5
 inches wide and 11 inches high

 [legal]
 : Equivalent to the size of North American legal: 8.5 inches wide
 by 14 inches high.

 [ledger]
 : Equivalent to the size of North American ledger: 11 inches wide
 by 17 inches high.

The
[\<page-size\>](#typedef-page-size-page-size) names can be used in conjunction with
[landscape](#valdef-page-size-landscape) or
[portrait](#valdef-page-size-portrait) to indicate both size and orientation.

@page {
 size: A4 landscape;
 }

The above example sets the width of the page box to be 297mm and the
height to be 210mm. The page box in this example should be rendered on a
page sheet size of 210 mm by 297 mm.

In the following example, the outer
edges of the page box will align with the page. The percentage value on
the
[[margin](https://drafts.csswg.org/css2/#propdef-margin)] property is relative to
the page size so if the page sheet dimensions are 210mm x 297mm (i.e.,
A4), the margins are 21mm and 29.7mm. Assuming there are no page borders
or padding set in the UA default style sheet, the resulting page area is
189mm by 267.3mm (210mm-21mm by 297mm-29.7mm).

 @page {
 size: auto;/* auto is the initial value */
 margin: 10%;
 }

@page {
 size: 8.5in 11in;/* width height */
 }

The above example sets the width of the page box to be 8.5 inches and
the height to be 11 inches. This indicates that the page sheet size
should be 8.5\"x11\" and the orientation
[portrait](#valdef-page-size-portrait).

#### 7.1.1. Media Queries

*This section is informative.*

By using Media Queries
[\[MEDIAQ\]](#biblio-mediaq "Media Queries Level 4"),
one style sheet can express different stylistic preferences for
different page sizes. Consider this example:

/* style sheet for "A4" printing */
 @media print and (width: 21cm) and (height: 29.7cm) {
 @page {
 margin: 3cm;
 }
 }

 /* style sheet for "letter" printing */
 @media print and (width: 8.5in) and (height: 11in) {
 @page {
 margin: 1in;
 }
 }

In the example above, \"A4\" sheets are given a \"3cm\" page margin, and
\"letter\" sheets are given a \"1in\" page margin.

#### 7.1.2. Rotating The Printed Page: the [page-orientation property]
Name:

[page-orientation]

For:

[\@page](#at-ruledef-page)

Value:

upright
[\|](https://drafts.csswg.org/css-values-4/#comb-one) rotate-left
[\|](https://drafts.csswg.org/css-values-4/#comb-one) rotate-right

Initial:

upright

Computed value:

as specified

High-quality printing implementations can handle pages of varying sizes
and orientations, so an author can choose the size of a page according
to what's best for that page's content. For example, they might use
[size: letter portrait;] for most pages in a document, but
switch to [size: letter landscape;] to lay out a wide
information table.

However, handling content flowing across pages of differing widths is a
relatively complex task, and is not yet solved in many popular printing
implementations (notably, web browsers). The
[page-orientation](#descdef-page-page-orientation) descriptor is intended to help such
implementations, allowing them to lay out pages in a single consistent
size, but change the orientation post-layout in the output medium (such
as PDF), so that pages which want to be displayed in a different
orientation can do so.

Its values are defined as:

[upright]

: No special orientation is applied; the page is laid out and
 formatted as normal.

[rotate-left]

: After the page has been laid out, if the output medium supports
 rotation, this value indicates that the page must be displayed
 rotated a quarter turn to the left (counter-clockwise) of how it was
 laid out.

[rotate-right]

: Same as
 [rotate-left](#valdef-page-orientation-rotate-left), except the page must be displayed rotated a
 quarter turn to the right (clockwise) of how it was laid out.

 Margin boxes and other positional things have no
special interaction with this property; they'll be laid out as normal in
the unrotated page, then rotated along with everything else.

This property is intended as a stop-gap for less-capable
implementations, allowing them to still print documents with a mix of
portrait and landscape orientations before they have the ability to flow
content across differently-size pages. It requires some awkward
contortions to use, such as specifying that a wide table containing only
English actually has a vertical
[writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) so it'll lay out \"sideways\", but
be rotated back to upright for readability in the printed output.

There should be no need to use this property in high-quality printing
implementations; instead, use
[size](#descdef-page-size) to control
[portrait](#valdef-page-size-portrait) vs
[landscape](#valdef-page-size-landscape) orientation of a page.

### 7.2. Crop and Registration Marks: the [marks property]
Name:

[marks]

For:

[\@page](#at-ruledef-page)

Value:

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) \[ crop
[\|\|](https://drafts.csswg.org/css-values-4/#comb-any) cross \]

Initial:

none

Computed value:

as specified

This property adds crop and/or registration marks to the document. These
are printed outside the page box to facilitate the trimming and
alignment of sheets of paper. Values have the following meanings:

[none]
: Specifies that neither crop marks nor registration marks should be
 printed: the area outside the [bleed
 area](#bleed-area) will be
 completely blank.

[crop]
: Specifies that crop marks should be printed. These are typically
 short lines outside the page box that are effectively extensions of
 the page box's four edges, thereby indicating the precise location
 of those edges without placing any ink near or within the page box
 itself.

[cross]
: Specifies that registration marks should be printed. These are
 typically cross-shaped marks outside each edge of the page box used
 to align sheets of paper during the printing process.

Note that crop marks and registration marks are only visible if the page
box is smaller than the printable area.

To set crop and cross marks on a
document, this code can be used:

 @page { marks: crop cross }

### 7.3. Bleed Area: the [bleed property]
Name:

[bleed]

For:

[\@page](#at-ruledef-page)

Value:

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)

Initial:

auto

Computed value:

as specified

This property specifies the extent of the [bleed area] outside the page box; in other
words the extent beyond the page box at which the page rendering is
clipped. Values have the following meanings:

[auto]
: Computes to [6pt] if
 [marks](#descdef-page-marks) has
 [crop](#valdef-page-marks-crop) and to zero otherwise.

[[\<length\>](https://drafts.csswg.org/css-values-4/#length-value)]
: Specifies by how far outward, in each direction, the [bleed
 area](#bleed-area) extends
 past the [page box](#page-box).
 Values may be negative, but there may be implementation-specific
 limits.

### 7.4. Rendering page boxes that do not fit a page sheet

If a page box does not match the target page sheet dimensions, the user
agent should do one of the following (in order of preference):

1. Render the page box at the indicated size on a larger page sheet.
2. Rotate the page box 90° if this will make the page box fit the page
 sheet.
3. Scale the page box to fit the page sheet. (The aspect ratio of the
 page box should be preserved.)
4. Graphically \"slice\" the page box onto multiple page sheets.
5. Clip overflowed content (least preferred).

The user agent may wish to consult the user before performing these
operations.

### 7.5. Positioning the page box on the sheet

When the page box is smaller than the page sheet, the user agent should
either:

- center the page box on the sheet since this will align double-sided
 pages and avoid accidental loss of information that is printed near
 the edge of the sheet; or
- position the page box in the upper left corner of the page sheet (or
 another corner, based on the
 [direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) and
 [writing-mode](https://drafts.csswg.org/css-writing-modes-4/#propdef-writing-mode) properties of the page box) as
 this may minimize media consumption.

The user agent may wish to consult the user in this regard.

### 7.6. Staying within the printable area: the [page-margin-safety property]
Name:

[page-margin-safety]

For:

[\@page](#at-ruledef-page)

Value:

none
[\|](https://drafts.csswg.org/css-values-4/#comb-one) clamp
[\|](https://drafts.csswg.org/css-values-4/#comb-one) add

Initial:

auto

Computed value:

as specified

The \"For:\" field above should also include the at-rules
\@top-left-corner, \@top-left, \@top-center, \@top-right,
\@top-right-corner, \@right-top, \@right-middle, \@right-bottom,
\@bottom-right-corner, \@bottom-right, \@bottom-center, \@bottom-left,
\@bottom-left-corner, \@left-bottom, \@left-middle, \@left-top.

However, multiple at-rules here are currently not supported by bikeshed.

Most printers have a small region along each edge of the page sheet
which is unprintable, typically due to the printer's paper handling
mechanism. This property can be used to help staying within the
[printable area](#printable-area), by adjusting the page margins and page margin box
margins.

Some printers don't have a uniform unprintable area width along each of
the four paper edges, and the printer may rotate the print output at
their own discretion. The user agent may therefore not be able to make
assumptions about which edge will be fed first into the printer, or what
orientation the sheet of paper has. If the user agent cannot make such
assumptions, only one will be provided (to be used on all 4 sides): The
larger of these four values. Otherwise, if the user agent can trust that
the four values are usable individually, and that no rotation is going
to take place, and so on, each side of the page may have individual
values.

Let this value be
[[\<safe-printable-inset\>](#typedef-safe-printable-inset)], which is a
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value).

This property only affects margins that are adjacent to one of the edges
of a sheet. For all other margins, i.e. those margins facing the page's
[page area](#page-area), its value
is 0. In other words, when page-margin-safety is specified in a margin
context, it will only have an effect at one or two sides. For instance,
\@page { \@top-right-corner { page-margin-safety: clamp; } } may only
clamp top and right margin values, as the bottom and left margins face
the document's contents, not the page's edges.

[none]
: Margins are not affected by unprintable regions

[clamp]
: The used margin values will be the maximum of the resolved value,
 and
 [\<safe-printable-inset\>](#typedef-safe-printable-inset) for the given side.

[add]
: The used margin values will be the resolved value, plus
 [\<safe-printable-inset\>](#typedef-safe-printable-inset) for the given side.

## 8. Page Breaks

The CSS Fragmentation Module
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
module defines how and where CSS boxes can be *fragmented*, including
across page breaks. It defines a few properties that indicate where the
user agent may or must break pages, and on what page (left or right) the
subsequent content resumes. Each page break ends layout in the current
[page box](#page-box) and causes
remaining pieces of the document tree to be laid out in a new page box.

### 8.1. Using named pages: [page]
Name:

[page]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

auto
[\|](https://drafts.csswg.org/css-values-4/#comb-one)
[\<custom-ident\>](https://drafts.csswg.org/css-values-4/#identifier-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

auto

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

boxes that create [class
A](https://www.w3.org/TR/css3-break/#btw-blocks) break points

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no (but see prose)

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

n/a

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

specified value

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

discrete

The [page](#propdef-page) property is used to specify a particular type of
page (called a [named page]) on which an element must be displayed. If necessary, a
[forced page
break](https://drafts.csswg.org/css-break-4/#forced-break) is introduced and a new page generated of the specified
type.

 This page can be styled by using the same type name in
a [page selector](#page-selectors).

Page type names are case-sensitive identifiers. However the [auto]
value, being a CSS keyword, is [ASCII
case-insensitive](https://www.w3.org/TR/CSS2/syndata.html#characters).

The [page](#propdef-page) property does not inherit. However, if the
[page](#propdef-page) value on an element is [auto], then its used
value is the value specified on its nearest ancestor with a non-auto
value. When specified on the root element, the used value for
[auto] is the empty string.

Because a previous version of this specification indicated that the
[page](#propdef-page) property is inherited, an implementation that
inherits the [page](#propdef-page) property and treats [auto] as always naming
the empty string remains conformant to CSS Paged Media Level 3. Note
that this exception will be removed in Level 4. Therefore authors should
not explicitly specify the [auto] value on a descendant of an
element with a non-[auto] value, as the resulting behavior will be
unpredictable.

The [page](#propdef-page) property works as follows:

1. First, any [auto] values are resolved against non-[auto]
 ancestors (as specified above).

2. Next, a [start [page](#propdef-page) value] and [end
 [page](#propdef-page) value] is determined for each box as the value
 (if any) propagated from its first or last child box (respectively),
 else the used value on the box itself. A child propagates its own
 [start](#start-page-value) or [end page
 value](#end-page-value) if
 and only if the [page](#propdef-page) property applies to it.

 A first or last child *box* is not always generated
 by a first or last child *element*. For example, an element could
 only have a previous sibling with \'display: none\' which does not
 generate any box.

3. The first printed page's type is the [start page
 value](#start-page-value) of the root.

4. If for any two boxes meeting at a [class
 A](https://www.w3.org/TR/css3-break/#btw-blocks) break point, the
 [end page value](#end-page-value) of the box preceding the break and [start page
 value](#start-page-value) of the box succeeding the break do not match, then
 a page break is forced between the two boxes, and content after the
 break resumes on a page box of the named type.

 Essentially, the two
[page](#propdef-page) values compared are those from the deepest boxes
meeting at the [class A break
point](https://www.w3.org/TR/css3-break/#btw-blocks), ignoring any
subtrees rooted by boxes to which the
[page](#propdef-page) property does not apply.

See
[\[CSS-BREAK-3\]](#biblio-css-break-3 "CSS Fragmentation Module Level 3")
for additional details on page breaks.

In this example, the two tables are
rendered on landscape pages (indeed, on the same page, if they fit). The
page type \"narrow\" is used for the \<p\> after the second table, as
the page properties for the table element are no longer in effect:

 @page narrow { size: 9cm 18cm }
 @page rotated { size: landscape }
 div { page: narrow }
 table { page: rotated }

with this document:

 <div>
 <table>...</table>
 <table>...</table>
 <p>This text is rendered on a 'narrow' page</p>
 </div>

In Japanese documents, sometimes
different parts of a single document will have different *kihon hanmen*.
[\[JLREQ\]](#biblio-jlreq "Requirements for Japanese Text Layout 日本語組版処理の要件(日本語版)")
The [page](#propdef-page) property, together with
[\@page](#at-ruledef-page) rules specifying different page widths, can
accommodate this type of layout:

 <!DOCTYPE html>
 <html lang="ja">
 <style>
 html {
 writing-mode: vertical-rl;
 line-height: 1.6;
 }
 .main {
 page: main;
 columns: 2;
 column-gap: 1rem;
 }
 .index {
 page: index;
 columns: 3;
 column-gap: 1rem;
 }
 @page {
 margin: auto; /* center kihon hanmen on page */
 width: 40rem; /* 1.6 × 25 lines */
 }
 @page main { height: 61rem; } /* 2 × 30 chars + 1 × gap */
 @page index { height: 62rem; } /* 3 × 20 chars + 2 × gap */
 </style>
 <section class="main"> ... </section>
 <section class="index"> ... </section>
 </html>

## 9. Image Properties

 This section has been moved to
[\[CSS-IMAGES-3\]](#biblio-css-images-3 "CSS Images Module Level 3").

## [ Appendix A: Applicable CSS2.1 Properties]
### [ CSS 2.1 Properties that apply within the page context]
This list defines the [page properties]. They are further described
in [§ 6 Page Properties](#page-properties).

[bidi properties](https://www.w3.org/TR/CSS2/visuren.html#direction)

direction

[background
properties](https://www.w3.org/TR/CSS2/colors.html#background-properties)

background-color

background-image

background-repeat

background-attachment

background-position

background

[border
properties](https://www.w3.org/TR/CSS2/box.html#border-properties)

border-top-width

border-right-width

border-bottom-width

border-left-width

border-width

border-top-color

border-right-color

border-bottom-color

border-left-color

border-color

border-top-style

border-right-style

border-bottom-style

border-left-style

border-style

border-top

border-right

border-bottom

border-left

border

[counter properties](https://www.w3.org/TR/CSS2/generate.html#counters)

counter-reset

counter-increment

[color](https://www.w3.org/TR/CSS2/colors.html#propdef-color)

[font properties](https://www.w3.org/TR/CSS2/fonts.html)

font-family

font-size

font-style

font-variant

font-weight

font

[height](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)
[properties](https://www.w3.org/TR/CSS2/visudet.html#min-max-heights)

height

min-height

max-height

[line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height)

[margin
properties](https://www.w3.org/TR/CSS2/box.html#margin-properties)

margin-top

margin-right

margin-bottom

margin-left

margin

[outline
properties](https://www.w3.org/TR/CSS2/ui.html#dynamic-outlines)

outline-width

outline-style

outline-color

outline

[padding
properties](https://www.w3.org/TR/CSS2/box.html#padding-properties)

padding-top

padding-right

padding-bottom

padding-left

padding

[quotes](https://www.w3.org/TR/CSS2/generate.html#quotes-specify)

[text properties](https://www.w3.org/TR/CSS2/text.html)

letter-spacing

text-align

text-decoration

text-indent

text-transform

white-space

word-spacing

[visibility](https://www.w3.org/TR/CSS2/visufx.html#visibility)

[width](https://www.w3.org/TR/CSS2/visudet.html#the-width-property)
[properties](https://www.w3.org/TR/CSS2/visudet.html#min-max-widths)

width

min-width

max-width

### [ CSS 2.1 properties that apply within the margin contexts]
This list defines the [page-margin properties].
They are further described in [§ 6 Page Properties](#page-properties).

[bidi properties](https://www.w3.org/TR/CSS2/visuren.html#direction)

direction

unicode-bidi

[background
properties](https://www.w3.org/TR/CSS2/colors.html#background-properties)

background-color

background-image

background-repeat

background-attachment

background-position

background

[border
properties](https://www.w3.org/TR/CSS2/box.html#border-properties)

border-top-width

border-right-width

border-bottom-width

border-left-width

border-width

border-top-color

border-right-color

border-bottom-color

border-left-color

border-color

border-top-style

border-right-style

border-bottom-style

border-left-style

border-style

border-top

border-right

border-bottom

border-left

border

[counter properties](https://www.w3.org/TR/CSS2/generate.html#counters)

counter-reset

counter-increment

content

[color](https://www.w3.org/TR/CSS2/colors.html#propdef-color)

[font properties](https://www.w3.org/TR/CSS2/fonts.html)

font-family

font-size

font-style

font-variant

font-weight

font

[height](https://www.w3.org/TR/CSS2/visudet.html#the-height-property)
[properties](https://www.w3.org/TR/CSS2/visudet.html#min-max-heights)

height

min-height

max-height

[line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height)

[margin
properties](https://www.w3.org/TR/CSS2/box.html#margin-properties)

margin-top

margin-right

margin-bottom

margin-left

margin

[outline
properties](https://www.w3.org/TR/CSS2/ui.html#dynamic-outlines)

outline-width

outline-style

outline-color

outline

[overflow](https://www.w3.org/TR/CSS2/visufx.html#overflow)

[padding
properties](https://www.w3.org/TR/CSS2/box.html#padding-properties)

padding-top

padding-right

padding-bottom

padding-left

padding

[quotes](https://www.w3.org/TR/CSS2/generate.html#quotes-specify)

[text properties](https://www.w3.org/TR/CSS2/text.html)

letter-spacing

text-align

text-decoration

text-indent

text-transform

white-space

word-spacing

[vertical-align](https://www.w3.org/TR/CSS2/visudet.html#line-height)

[visibility](https://www.w3.org/TR/CSS2/visufx.html#visibility)

[width](https://www.w3.org/TR/CSS2/visudet.html#the-width-property)
[properties](https://www.w3.org/TR/CSS2/visudet.html#min-max-widths)

width

min-width

max-width

[z-index](https://www.w3.org/TR/CSS2/visuren.html#z-index)

## [ Appendix B: Transfer Possibilities]
Often, but not always, the page box has a one-to-one correspondence to
the physical surface onto which the document is ultimately rendered. The
CSS3 page model specifies formatting within the page box, but it is the
user agent's responsibility to transfer the page box to the sheet. Some
user agent transfer possibilities that are not addressed by CSS3
include:

- Transferring one page box to one sheet (e.g. single-sided printing);
- Transferring two page boxes to the front and back surfaces of the same
 sheet (e.g. double-sided printing);
- Transferring N (small) page boxes to one sheet (called \"N-up\");
- Transferring one (large) page box to N x M sheets (called \"tiling\");
- Creating signatures. A [signature] is a group of pages printed on a sheet,
 which, when folded and trimmed like a book, appear in their proper
 sequence;
- Printing one document to multiple output trays;
- Generating files containing print instructions.

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

## [ Changes]
Changes since the [18 October 2018 Working
Draft](https://www.w3.org/TR/2018/WD-css-page-3-20181018/) are:

- Added
 [page-orientation](#descdef-page-page-orientation) descriptor.

Changes since the [14 March 2013 Working
Draft](https://www.w3.org/TR/2013/WD-css3-page-20130314/) are:

- Imported the [marks](#descdef-page-marks) and
 [bleed](#descdef-page-bleed) properties from
 [\[CSS3GCPM\]](#biblio-css3gcpm "CSS Generated Content for Paged Media Module").
- Added [auto](#valdef-page-bleed-auto) as the initial value of
 [bleed](#descdef-page-bleed) and allowed it to apply even when
 [marks](#descdef-page-marks) is
 [none](#valdef-page-marks-none).
- Added JIS-B4 and JIS-B5.

## [Acknowledgements]
The CSS Working Group would like to give very special thanks to this
module's former editors: Robert Stevahn (Hewlett-Packard), Håkon Wium
Lie (Opera Software), Jim Bigelow (Hewlett-Packard), Jacob Refstrup
(Hewlett-Packard), and Melinda Grant (Hewlett-Packard).

We would also like to acknowledge our expert contributors Michael Day
(YesLogic), Shinyu Murakami (Antenna House), Peter Linss
(Hewlett-Packard), and the other members of the CSS Working Group and
www-style community who have provided review and comment on CSS Paged
Media Level 3.
