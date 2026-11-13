## 1. Introduction

::: non-normative
*This section is not normative.*

CSS 2.1
[\[CSS21\]](#biblio-css21 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")
specifies an [initial containing
block](https://www.w3.org/TR/CSS21/visudet.html#containing-block-details)
for [continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media) that has the dimensions of the
[viewport](https://www.w3.org/TR/CSS21/visuren.html#viewport). Since the
viewport is generally no larger than the display, devices with smaller
displays such as phones or tablets typically present a smaller viewport
than larger devices like desktop or laptops.

Unfortunately, many documents have historically been designed against
larger viewports and exhibit a variety of bugs when viewed in smaller
viewports. These include unintended layout wrapping, clipped content,
awkward scrollable bounds, and script errors. To avoid these issues,
mobile browsers generally use a fixed initial containing block width
that mimics common desktop browser window size (typically 980-1024px).
The resulting layout is then scaled down to fit in the available screen
space.

Although this approach mitigates the issues mentioned above, the
downscaling means the CSS pixel size will be smaller than
[recommended](https://www.w3.org/TR/CSS21/syndata.html#length-units) by
CSS 2.1. Users will likely need to zoom on the content to view it
comfortably.

This mitigation is unnecessary for sites that have been designed to work
well on small viewports.

This specification is written from an
implementation-centric point of view, making it arguably difficult to
read. Significant editorial work may be needed to make it more
understandable to different audiences. It also should clarify which
viewport is referred to by various js APIs. See [this blog post by
ppk](http://www.quirksmode.org/blog/archives/2015/09/a_new_device_ad.html)
for a good discussion of these issues.

Various issues about this specification
and related specifications are listed in [this
report](https://www.w3.org/Graphics/SVG/WG/wiki/Proposals/Investigation_of_APIs_for_Level_of_detail#The_issues_on_existing_APIs).

## 2. Terminology

In CSS 2.1 a
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) is a feature of a user agent for [continuous
media](https://drafts.csswg.org/mediaqueries-5/#continuous-media) and used to establish the initial containing block for
[continuous media]. For [paged
media](https://drafts.csswg.org/mediaqueries-5/#paged-media), the initial containing block is based on the page
area. The page area can be set through
[\@page](https://drafts.csswg.org/css-page-3/#at-ruledef-page) rules.

This specification introduces a way of overriding the size of the
[viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) provided by the user agent (UA). Because of this, we
need to define [initial
viewport](#initial-viewport),
[layout viewport](#layout-viewport) and [visual
viewport](#visual-viewport).

[initial viewport]

: This refers to the viewport before any UA or author styles have
 overridden the
 [viewport](https://drafts.csswg.org/css2/#viewport%E2%91%A0) given by the window or viewing area of the UA.

 The [initial
 viewport](#initial-viewport) size will change with the size of the window or
 viewing area.

[layout viewport]
: This is the viewport you get after processing the viewport `<meta>`
 tag.

[visual viewport]

: This is the portion of the [layout
 viewport](#layout-viewport) that is currently visible, obtained by result of
 applying scale transform to it. This transform is applied to the
 [canvas](https://drafts.csswg.org/css2/#canvas) of the [layout viewport]
 and does not affect its internal coordinate space. The magnitude of
 the scale transform is known as the [visual
 viewport](#visual-viewport)'s [scale factor].

 The [visual
 viewport](#visual-viewport) can be smaller than the [layout
 viewport](#layout-viewport).

 The scale transform of the [visual
viewport](#visual-viewport)
is often referred to as \"pinch-zoom\". Conceptually, this transform
changes the size of the CSS [reference
pixel](https://drafts.csswg.org/css-values-4/#reference-pixel) and changes the size of the [layout
viewport](#layout-viewport)
(inversally) proportionally so that it does not cause reflow of the
page's contents.

When the [layout viewport](#layout-viewport) cannot fit inside the window or viewing area, either
because the [layout viewport] is larger than
the [initial viewport](#initial-viewport) or the zoom factor causes only parts of the [layout
viewport] to be visible, the UA should offer
a scrolling or panning mechanism.

 The [visual
viewport](#visual-viewport)'s
[scrolling
area](https://drafts.csswg.org/cssom-view-1/#scrolling-area) is the [layout
viewport](#layout-viewport).

This animation shows an example of a zoomed in visual viewport being
\"panned\" around (for example, by a user performing a touch drag). The
page is scaled so that the layout viewport is larger than the visual
viewport.

A scroll delta is applied to the visual viewport first. When the visual
viewport is at its extent, scroll delta will be applied to the layout
viewport. This behavior is implemented by the [perform a
scroll](https://drafts.csswg.org/cssom-view-1/#viewport-perform-a-scroll) steps.

!(data:image/svg+xml;base64,PHN2ZyBoZWlnaHQ9IjQwMCIgd2lkdGg9IjMwMCI+CiAgICAgPHJlY3QgZmlsbD0id2hpdGUiIGhlaWdodD0iMTAwJSIgc3Ryb2tlPSJncmV5IiBzdHJva2Utd2lkdGg9IjMiIHdpZHRoPSIxMDAlIiAvPgogICAgIDx0ZXh0IGZpbGw9ImdyZXkiIGZvbnQtZmFtaWx5PSJTYW5zIiBmb250LXNpemU9IjI1IiB4PSIxMCIgeT0iMzAiPgogICAgICAgIERvY3VtZW50CiAgICA8L3RleHQ+CiAgICAgPGcgaWQ9Imx2Ij4KICAgICAgPHJlY3QgZmlsbD0ibm9uZSIgaGVpZ2h0PSIyMDAiIHN0cm9rZT0iYmx1ZSIgc3Ryb2tlLXdpZHRoPSI0IiB3aWR0aD0iMjk2IiB4PSIyIiB5PSIyIiAvPgogICAgICA8dGV4dCBmaWxsPSJibHVlIiBmb250LWZhbWlseT0iU2FucyIgZm9udC1zaXplPSIxNSIgeD0iMTAiIHk9IjIwIj4KICAgICAgICBMYXlvdXQgVmlld3BvcnQKICAgICAgICA8L3RleHQ+CiAgICAgPC9nPgogICAgIDxnIGlkPSJ2diI+CiAgICAgIDxyZWN0IGZpbGw9Im5vbmUiIGhlaWdodD0iMTAwIiBzdHJva2U9InJlZCIgc3Ryb2tlLXdpZHRoPSI0IiB3aWR0aD0iMTQ4IiB4PSIyIiB5PSIyIiAvPgogICAgICA8dGV4dCBmaWxsPSJyZWQiIGZvbnQtZmFtaWx5PSJTYW5zIiBmb250LXNpemU9IjE1IiB4PSIxMCIgeT0iNjAiPgogICAgICAgIFZpc3VhbCBWaWV3cG9ydAogICAgICAgIDwvdGV4dD4KICAgICA8L2c+CiAgICA8L3N2Zz4=)\

Toggle Animation

It is recommended that initially the upper-left corners of the [layout
viewport](#layout-viewport)
and the window or viewing area are aligned if the base direction of the
document is ltr. Similarly, that the upper-right corners are aligned
when the base direction is rtl. The base direction for a document is
defined as the computed value of the
[direction](https://drafts.csswg.org/css-writing-modes-3/#propdef-direction) property for the first
`<BODY>` element of an HTML or XHTML document. For other document
types, it is the computed [direction] for the root element.

### 2.1. Display feature definition

A [Display feature] is a hardware feature that acts as a divider and creates
logically separate region of the viewport called
[`segments`](#dom-viewport-segments). It can be a fold area of a device with a foldable
screen or a physical split occupying a logical space within the viewport
for example some dual screen models.

Below is an illustration describing the concept of display features and
how they divide the viewport in
[`segments`](#dom-viewport-segments):

![Two images, showing two display feature configurations and the
respective segments. One image is showing an vertical display feature,
the other is showing an horizontal display
feature](display_features_general.svg){height="258"
style="width: 70%;height: auto; margin:auto; display: flex;"
width="560"}

## 3. Viewport `<meta>` element

Specify me

### 3.1. Properties

The recognized properties in the viewport `<meta>` element are:

- `width`
- `height`
- `initial-scale`
- `minimum-scale`
- `maximum-scale`
- `user-scalable`
- `interactive-widget`

### 3.2. Parsing algorithm

Below is an algorithm for parsing the `content` attribute of the
`<meta>` tag produced from testing Safari on the iPhone. [ The
testing was done on an iPod touch running iPhone OS 4. The UA string of
the browser:
`"Mozilla/5.0 (iPod; U; CPU iPhone OS 4_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7"`.]
The pseudo code notation used is based on the notation used in
[\[Algorithms\]](#biblio-algorithms "Introduction to Algorithms, Second Edition, MIT Press").

The whitespace class contains the following characters (ascii):

- Horizontal tab (0x09)
- Line feed (0x0a)
- Carriage return (0x0d)
- Space (0x20)

The recognized separator between property/value pairs is comma for the
Safari implementation. Some implementations have supported both commas
and semicolons. Because of that, existing content use semicolons instead
of commas. Authors should be using comma in order to ensure content
works as expected in all UAs, but implementors may add support for both
to ensure interoperability for existing content.

The separator class contains the following characters (ascii), with
comma as the preferred separator and semicolon as optional:

- Comma (0x2c)
- Semicolon (0x3b)

```
Parse-Content(S)
i ← 1
while i ≤ length[S]
 do while i ≤ length[S] and S[i] in [whitespace, separator, '=']
 do i ← i + 1
 if i ≤ length[S]
 then i ← Parse-Property(S, i)

Parse-Property(S, i)
start ← i
while i ≤ length[S] and S[i] not in [whitespace, separator, '=']
 do i ← i + 1
if i > length[S] or S[i] in [separator]
 then return i
property-name ← S[start .. (i - 1)]
while i ≤ length[S] and S[i] not in [separator, '=']
 do i ← i + 1
if i > length[S] or S[i] in [separator]
 then return i
while i ≤ length[S] and S[i] in [whitespace, '=']
 do i ← i + 1
if i > length[S] or S[i] in [separator]
 then return i
start ← i
while i ≤ length[S] and S[i] not in [whitespace, separator, '=']
 do i ← i + 1
property-value ← S[start .. (i - 1)]
Set-Property(property-name, property-value)
return i
```

[Set-Property] matches the [listed property
names](#meta-properties) case-insensitively. The
`property-value` strings are interpreted as follows:

1. If a prefix of `property-value` can be converted to a
 number using `strtod`, the value will be that number. The remainder
 of the string is ignored.
2. If the value can not be converted to a number as described above,
 the whole `property-value` string will be matched with
 the following strings case-insensitively: `yes`,
 `no`, `device-width`, `device-height`
3. If the string did not match any of the known strings, the value is
 unknown.

### [3.3. ][[extend-to-zoom]]
Specify extend-to-zoom behavior by the
viewport meta tag

### [3.4. ][[interactive-widget]]
The [`interactive-widget`] property specifies the effect that interactive
UI widgets have on the page's viewports. It defines whether widgets
overlay a given viewport or whether the viewport is shrunken so that it
remains fully visible while the widget is showing. Interactive UI
widgets are transient user agent or operating system UI through which a
user can provide input.

The most common such UI widget is a virtual keyboard.

The following is a list of valid values for
[interactive-widget](#interactive-widget) and the associated viewport-resizing behavior:

[`overlays-content`]
: Interactive UI widgets MUST NOT [resize](#resize) the [initial
 viewport](#initial-viewport) nor the [visual
 viewport](https://www.w3.org/TR/cssom-view-1/#visual-viewport). The user agent must perform the same steps as when
 [`VirtualKeyboard.overlaysContent`](https://w3c.github.io/virtual-keyboard#dom-virtualkeyboard-overlayscontent) is set to `true`.

[`resizes-content`]
: Interactive UI widgets MUST [resize](#resize) the [initial
 viewport](#initial-viewport) by the interactive widget.
 :::
 Since the [visual
 viewport](https://www.w3.org/TR/cssom-view-1/#visual-viewport)'s size is derived from the [initial
 viewport](#initial-viewport),
 [resizes-content](#resizes-content) will cause a resize of both the initial and visual
 viewports.
 :::

[`resizes-visual`]
: Interactive UI widgets MUST [resize](#resize) the [visual
 viewport](https://www.w3.org/TR/cssom-view-1/#visual-viewport) but MUST NOT [resize] the
 [initial
 viewport](https://drafts.csswg.org/css-viewport/#initial-viewport).

If no value, or an invalid value, is set for
[interactive-widget](#interactive-widget), the behavior implied by
[resizes-visual](#resizes-visual) is used as the default.

To [resize a viewport by an interactive widget], subtract from it
the intersection of the viewport rect with the widget's OS reported
bounding rect. In cases where this would result in a non-rectangular
viewport, the behavior is user agent defined.

Some examples where the result would non rectangular: a [floating or
split keyboard](https://support.apple.com/en-ca/HT207521), or a keyboard
that [occupies only
part](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/VirtualKeyboardAPI/explainer.md#motivation)
of the viewport.

#### 3.4.1. Interaction with virtualKeyboard.overlaysContent

[\[VIRTUAL-KEYBOARD\]](#biblio-virtual-keyboard "VirtualKeyboard API")
provides an imperative API to apply the
[overlays-content](#overlays-content) behavior via the
[`VirtualKeyboard.overlaysContent`](https://w3c.github.io/virtual-keyboard#dom-virtualkeyboard-overlayscontent) attribute. This attribute shadows the value set to
[interactive-widget](#interactive-widget), namely:

When
[`VirtualKeyboard.overlaysContent`](https://w3c.github.io/virtual-keyboard#dom-virtualkeyboard-overlayscontent) is set to `true`, the UA MUST ignore any value set to
[interactive-widget](#interactive-widget) when determining the resizing behavior of interactive
widgets.

When
[`VirtualKeyboard.overlaysContent`](https://w3c.github.io/virtual-keyboard#dom-virtualkeyboard-overlayscontent) is set to `false`, the UA MUST use the value set to
[interactive-widget](#interactive-widget), or the default behavior if a value is not set, when
determining the resizing behavior of interactive widgets.

Getting the value of
[`VirtualKeyboard.overlaysContent`](https://w3c.github.io/virtual-keyboard#dom-virtualkeyboard-overlayscontent) MUST return only the value previously set to it.

That is, unless previously set, `VirtualKeyboard.overlaysContent`
returns false even if `interactive-widget=overlays-content` is set via
the `<meta>` tag.

## 4. The [zoom property ]
An element becomes zoomed when the
[zoom](#propdef-zoom) property has a positive computed value different
than 1 (or when a flat tree ancestor has zoom).

To apply zoom, the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of a CSS property (including values inside of
[path()](https://drafts.csswg.org/css-shapes-1/#funcdef-basic-shape-path) strings) is pre-multiplied (before any other
steps in the [used value] stage) by the [used
value] of
[zoom](#propdef-zoom) for the element. It also multiplies the [natural
size](https://drafts.csswg.org/css-images-3/#natural-size) of all replaced elements, background images, and nested
frames (except for fenced frames
[\[FENCED-FRAME\]](#biblio-fenced-frame "Fenced Frame"))
by the [used value] of
[zoom].

 This results in a magnification or minification effect.

Nested values of [zoom](#propdef-zoom) multiply, resulting in additional
scaling of
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) values. The [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) for zoom is always its [effective
zoom](#effective-zoom).

The [zoom](#propdef-zoom) property has no effect on
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) property values with computed values
that are [auto] or
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value).

 Unlike
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform), scaling the
[zoom](#propdef-zoom) property affects layout.

 The computed value of
[font-size](https://drafts.csswg.org/css-fonts-4/#propdef-font-size) is never
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value); thus
[zoom](#propdef-zoom) always applies.

 [zoom](#propdef-zoom) does not affect or prevent
[transform](https://drafts.csswg.org/css-transforms-1/#propdef-transform) scaling.

Name:

[zoom]

[Value:](https://www.w3.org/TR/css-values/#value-defs)

[\<number
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#number-value)
[\|](https://drafts.csswg.org/css-values-4/#comb-one) [\<percentage
\[0,∞\]\>](https://drafts.csswg.org/css-values-4/#percentage-value)

[Initial:](https://www.w3.org/TR/css-cascade/#initial-values)

1

[Applies to:](https://www.w3.org/TR/css-cascade/#applies-to)

all
[\<length\>](https://drafts.csswg.org/css-values-4/#length-value) property values of all elements

[Inherited:](https://www.w3.org/TR/css-cascade/#inherited-property)

no

[Percentages:](https://www.w3.org/TR/css-values/#percentages)

Converted to
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

[Computed value:](https://www.w3.org/TR/css-cascade/#computed)

as specified, but with
[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value) converted to the equivalent
[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)

[Canonical order:](https://www.w3.org/TR/cssom/#serializing-css-values)

per grammar

[Animation type:](https://www.w3.org/TR/web-animations/#animation-type)

by computed value type

Media:

visual

The values of this property have the following meanings:

[[\<number\>](https://drafts.csswg.org/css-values-4/#number-value)]

: Positive floating point number indicating a zoom factor. Numbers
 smaller than 1.0 indicate a \"zoom out\" or minification effect,
 while numbers greater than 1.0 indicate a \"zoom in\" or
 magnification effect. A 0 value is treated as if it was 1.

 The treatment of 0 is a web compatibility quirk.

[[\<percentage\>](https://drafts.csswg.org/css-values-4/#percentage-value)]

: Positive floating point number, followed by a percentage character
 (\"%\") which indicates a zoom factor multiplied by 100. A 0
 percentage is treated as if it was 100%.

 The treatment of 0 is a web compatibility quirk.

Negative values for [zoom](#propdef-zoom) are illegal.

Example of the
[zoom](#propdef-zoom) property applied during hover for magnification
effect.

 <div class="messageBox">
 <div class="label">Text of the label</div>
 </div>

 <style>
 .messageBox {
 width: 10em;
 padding: 2em;
 border: medium solid lightblue;
 }

 .messageBox:hover {
 zoom: 150%;
 }

 .label {
 background: lightgrey;
 padding: 1em;
 text-align: center;
 }
 </style>

Here is an llustration of the before and after hover state of the
message box element: ![Two images showing the zooming effect before and
after zoom has applied. The second is 1.5
larger.](css_zoom_hover_example.png){height="270" width="704"}

Example of nested zoom. In this
example, \"Inner text\" is 4x as large as \"Outer text\", and \"Middle
text\" is 2x as large as \"Outer text\".

 <div style="zoom: 2">
 Middle text
 <div style="zoom: 2">
 Inner text
 <div>
 <div>
 Outer text

Example of replaced elements. In this
example, the image and iframe will be twice as large as their default
sizing.

 <div style="zoom: 2">
 <img src="...">
 <iframe src="..."></iframe>
 <div>

The [effective zoom] of an element is the product of its computed value of
[zoom](#propdef-zoom) and all flat tree ancestors\' computed values of
[zoom].

The [scaled] value
of a CSS length is the [used
value](https://drafts.csswg.org/css-cascade-5/#used-value) of that length; in particular it includes zoom.

The [unscaled]
value of a CSS length relative to an element is the
[scaled](#scaled) value divided by the
element's [effective zoom](#effective-zoom).

The [effective zoom](#effective-zoom) of an element in a nested frame may be a value other
than 1 even if [zoom](#propdef-zoom) is never set on an element in that
frame. This can be observed by authors via APIs such as
[`devicePixelRatio`](https://drafts.csswg.org/cssom-view-1/#dom-window-devicepixelratio) and
[`getBoundingClientRect`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect).

### 4.1. DOM and CSSOM interaction

Computed style APIs (i.e., all values returned by
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle)) that are non-auto and non-percentage lengths must be
[unscaled](#unscaled).

The
[`getBoundingClientRect`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect),
[`getClientRects`](https://drafts.csswg.org/cssom-view-1/#dom-element-getclientrects), and
[`IntersectionObserver`](https://w3c.github.io/IntersectionObserver/#intersectionobserver) APIs must return rects with
[scaled](#scaled) lengths.

All other APIs related to element geometries must return
[unscaled](#unscaled) lengths
(except as detailed below). This is explained in detail in [CSSOM View
§ 7 Extensions to the HTMLElement
Interface](https://drafts.csswg.org/cssom-view-1/#extensions-to-the-htmlelement-interface).

In cases where properties (such as
[`scrollTop`](https://drafts.csswg.org/cssom-view-1/#dom-element-scrolltop)) are propagated to the viewport, APIs for these lengths
must be in viewport units, and not be divided by the zoom of the
element.

The
[`devicePixelRatio`](https://drafts.csswg.org/cssom-view-1/#dom-window-devicepixelratio) of a frame is multiplied by the [effective
zoom](#effective-zoom)
inherited by its parent frame.

## [5. ][Extensions to the [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) Interface]
```
partial interface Window {
[SameObject, Replaceable] readonly attribute Viewport viewport;
};
```

## 6. The [`Viewport` Interface]
```
[Exposed=Window]
interface Viewport {
 readonly attribute FrozenArray<DOMRect>? segments;
};
```

## [7. ][ The [`segments`] property ]
The
[`segments`](#dom-viewport-segments) property is an array of
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) that represent the dimensions of each existing viewport
segment. Each
[`DOMRect`](https://drafts.csswg.org/geometry-1/#domrect) contains the geometry of the segment (x, y, width,
height) in CSS
[px](https://drafts.csswg.org/css-values-4/#px).

Additional details about the definition of a viewport segment can be
found here: [CSS Environment Variables 1 § 2.3 Viewport segment
variables](https://drafts.csswg.org/css-env-1/#viewport-segments).

The
[`segments`](#dom-viewport-segments) attribute getter steps are:

1. If the [`Viewport`](#viewport)'s associated
 [`Document`](https://dom.spec.whatwg.org/#document) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), return null.

2. Let `topLevelTraversable` be `document`'s
 [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global)'s
 [navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#navigable)'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable).

3. If
 `topLevelTraversable`.[\[\[DisplayFeaturesOverride\]\]](#top-level-traversable-displayfeaturesoverride) is non-null, return
 [`Viewport`](#viewport)'s
 [segments](https://drafts.csswg.org/css-env-1/#viewport-segments)
 array calculated from
 `topLevelTraversable`.[\[\[DisplayFeaturesOverride\]\]].

4. If there is only a single viewport segment (typically the size of
 the [`Viewport`](#viewport)) return an array with that single segment.

5. Otherwise, return the
 [`Viewport`](#viewport)'s
 [segments](https://drafts.csswg.org/css-env-1/#viewport-segments)
 array calculated from the hardware features.

:::: non-normative
*This section is not normative.*

The
[`segments`](#dom-viewport-segments) property represents an immutable snapshot of the device
[`segments`](#dom-viewport-segments) when the value was queried. If the device state changes
(rotation, window resize,
[posture](https://w3c.github.io/device-posture/#dfn-posture) change), the value previously retrieved will be
invalid. Developers can listen to
[`Screen Orientation`](https://w3c.github.io/screen-orientation/#dom-screenorientation-onchange),
[`Window Resize`](https://drafts.csswg.org/cssom-view-1/#eventdef-window-resize), or
[`Posture`](https://w3c.github.io/device-posture/#dom-deviceposture-onchange) changes events to detect device state changes.

If a viewport of 400px by 400px is
split horizontally into two side-by-side segments, the
[`segments`](#dom-viewport-segments) array will have the following content:
`[DOMRect(0, 0, 400, 200), DOMRect(0, 200, 400, 200)]`

## [Privacy Considerations]
No new privacy considerations have been reported on this specification.

## [Security Considerations]
No new security considerations have been reported on this specification.

## [Appendix A. Changes]
This appendix is *informative*.

### [Since the [29 March 2016 Working Draft](http://www.w3.org/TR/2016/WD-css-device-adapt-1-20160329/) ]
- Added [interactive-widgets] property to viewport meta
- Removed [\@viewport] rule
- Renamed spec from device-adapt to css-viewport
- CSSViewportRule exposed to Window

### [Since the [15 September 2011 First Public Working Draft](https://www.w3.org/TR/2011/WD-css-device-adapt-20110915/). ]
- Made various editorial improvements and clarifications.
- Added OM Interfaces.
- Added semi-colon as separator in meta viewport.
- Created UA stylesheets section.
- Added recommendation for when to respect orientation property.
- Dropped support for the resolution descriptor.
- Decouple width/height and zoom, introducing [extend-to-zoom]
 value for meta viewport translation.
- Made normative rules about interaction of [\@viewport] and
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media).
- Allow 0 for [\<viewport-length\>] and [zoom] values
- Removed support for device-width/height.
- Apply [\@viewport] to top level document only.
- Extend
 [\[CSS3-CONDITIONAL\]](#biblio-css3-conditional "CSS Conditional Rules Module Level 3")
 rather than CSS21 for nesting in
 [\@media](https://drafts.csswg.org/css-conditional-3/#at-ruledef-media).

## [Appendix B. Automation]
### [Automation of the [`segments`](#dom-viewport-segments) property]
The
[`segments`](#dom-viewport-segments) property poses a challenge to test authors, as
exercising this property requires access to specific hardware devices.
To address this challenge this document defines
[\[WEBDRIVER2\]](#biblio-webdriver2 "WebDriver")
[extension
commands](https://w3c.github.io/webdriver/#dfn-extension-commands) that allow users to control how the viewport is split
by one or more [display
features](#display-feature)
(such as a fold or a hinge between two separate displays).

A [display feature override] is a
[struct](https://infra.spec.whatwg.org/#struct) encapsulating the result of a single display feature.
It has a [orientation] (a string that is either \"vertical\" or \"horizontal\"), a
[mask length] (a
positive number describing the length of the feature in CSS
[px](https://drafts.csswg.org/css-values-4/#px)), and an [offset] (which describe the distance from the origin of the
viewport in CSS [px]).

#### [Internal slots]
To support the [extension commands]
below and their integration with the
[`segments`](#dom-viewport-segments) attribute getter steps, [top-level
traversables](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable) must have the following internal slots:

Internal slot

Description

[\[\[DisplayFeaturesOverride\]\]]

List of [display feature
override](#display-feature-override) that overrides those provided by the hardware, or
`null`.

#### [Extensions Commands]
##### [Set display features]
HTTP Method

[URI
Template](https://w3c.github.io/webdriver/#dfn-extension-command-uri-template)

POST

/session/{session id}/displayfeatures

This [extension
command](https://w3c.github.io/webdriver/#dfn-extension-commands) creates a setup that emulates a set of [display feature
override](#display-feature-override) by taking a list of display features as parameter.

:::: non-normative
*This section is not normative.*

This section exists because the input format is not trivial. Here is a
pseudo IDL example on how a [display feature
override](#display-feature-override) is defined:

```
enum OrientationType {
 "vertical",
 "horizontal"
};

interface DisplayFeature {
 readonly attribute OrientationType orientation;
 readonly attribute double offset;
 readonly attribute double maskLength;
};
```

Below is an illustration showing the various properties of a display
feature:

![Two images showing the meaning of each display feature attributes. One
image is showing a vertical display feature, the other is showing an
horizontal display feature](display_features.svg){height="258"
style="width: 70%;height: auto; margin:auto; display: flex;"
width="560"}

To create a
[\[\[DisplayFeaturesOverride\]\]](#top-level-traversable-displayfeaturesoverride) in the [current browsing
context](https://w3c.github.io/webdriver/#dfn-current-browsing-context) of the
[session](https://w3c.github.io/webdriver-bidi/#modules-session) with ID 23, the [local
end](https://w3c.github.io/webdriver/#dfn-local-ends) would POST to \`/session/23/displayfeatures\` with the
body:

```
{
 "features": [
 {
 "orientation": "horizontal",
 "offset": 190,
 "maskLength": 20
 }
 ]
}
```

Considering a viewport of 400px by 400px the command will result of a
[`segments`](#dom-viewport-segments) property with the following content:
`[DOMRect(0, 0, 400, 190), DOMRect(0, 210, 400, 190)]`

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) are:

1. Let `features` be the result of invoking [getting a
 property](https://w3c.github.io/webdriver/#dfn-getting-properties) \"features\" from `parameters`.
2. If `features` is not a
 [`Array`](https://tc39.es/ecma262/multipage/indexed-collections.html#sec-array-objects), return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
3. Let `parsedFeatures` be a new
 [list](https://infra.spec.whatwg.org/#list) of [display feature
 override](#display-feature-override).
4. For each `feature item` in `features`:
 1. If `feature item` is not an
 [`Object`](https://tc39.es/ecma262/multipage/fundamental-objects.html#sec-object-objects), return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 2. Let `mask length` be the result of invoking [getting
 a
 property](https://w3c.github.io/webdriver/#dfn-getting-properties) \"maskLength\" from `feature item`.
 3. If `mask length` is not a
 [`Number`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number-objects) or its value is
 [`NaN`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number.nan), +∞, −∞, or negative return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 4. Let `offset` be the result of invoking [getting a
 property](https://w3c.github.io/webdriver/#dfn-getting-properties) \"offset\" from `feature item`.
 5. If `offset` is not a
 [`Number`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number-objects) or its value is
 [`NaN`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-number.nan), +∞, −∞, or negative return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 6. Let `orientation` be the result of invoking [getting
 a
 property](https://w3c.github.io/webdriver/#dfn-getting-properties) \"orientation\" from `feature item`.
 7. If `orientation` is not a
 [`string`](https://webaudio.github.io/web-speech-api/#dom-speechgrammarlist-addfromstring-string-weight-string), return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 8. If `orientation` is neither \"vertical\" or
 \"vertical\", return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 9. If `orientation` is \"vertical\" and
 `mask length` + `offset` is greater than
 viewport width including the size of the rendered scrollbar,
 return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 10. If `orientation` is \"vertical\" and
 `mask length` + `offset` is greater than
 viewport height including the size of the rendered scrollbar,
 return
 [error](https://w3c.github.io/webdriver/#dfn-error) with [WebDriver error
 code](https://w3c.github.io/webdriver/#dfn-error-code) [invalid
 argument](https://w3c.github.io/webdriver/#dfn-invalid-argument).
 11. Let `override` be a new [display feature
 override](#display-feature-override).
 12. Set `override`'s [mask
 length](#display-feature-override-mask-length) to `mask length`.
 13. Set `override`'s
 [orientation](#display-feature-override-orientation) to `orientation`.
 14. Set `override`'s
 [offset](#display-feature-override-offset) to `offset`.
 15. [Append](https://infra.spec.whatwg.org/#list-append) `override` to
 `parsedFeatures`.
5. Let `topLevelTraversable` be the [current browsing
 context](https://w3c.github.io/webdriver/#dfn-current-browsing-context)'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable).
6. Set
 `topLevelTraversable`.[\[\[DisplayFeaturesOverride\]\]](#top-level-traversable-displayfeaturesoverride) to `parsedFeatures`.
7. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `null`.

##### [Clear display features]
HTTP Method

[URI
Template](https://w3c.github.io/webdriver/#dfn-extension-command-uri-template)

DELETE

/session/{session id}/displayfeatures

This [extension
command](https://w3c.github.io/webdriver/#dfn-extension-commands) removes the display features override and returns
control back to hardware.

The [remote end
steps](https://w3c.github.io/webdriver/#dfn-remote-end-steps) are:

1. Let `topLevelTraversable` be the [current browsing
 context](https://w3c.github.io/webdriver/#dfn-current-browsing-context)'s [top-level
 traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#bc-traversable).
2. Set `topLevelTraversable`.
 [\[\[DisplayFeaturesOverride\]\]](#top-level-traversable-displayfeaturesoverride) to `null`.
3. Return
 [success](https://w3c.github.io/webdriver/#dfn-success) with data `null`.
