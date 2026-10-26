
The {{VirtualKeyboard}} API provides authors with greater control over
the visibility of the virtual keyboard (VK), and greater ability to
adapt the layout of web pages when VK visibility changes.

## Introduction

This section is non-normative.

The Virtual Keyboard (VK) is the on-screen keyboard used for input in
scenarios where a hardware keyboard may not be available. User agents
respond to the presence of the VK, without any exposure of this
information to web developers in the following way: 1. Repositioning the
user agent above the VK 2. Reducing the size of the layout viewport so
the VK doesn\'t occlude it 3. Reducing the size of the visual viewport
and padding the layout viewport to ensure it can be shifted above the VK
This API provides a fourth option that allows the user agent to leave
its layout and visual viewports unchanged and instead provide
information about the intersection of the VK and layout viewport so that
the author can adapt the layout of their web pages using JavaScript or
CSS environment variables.

Figure showing virtual keyboard on dual screen device ![Figure showing
virtual keyboard on dual screen
device](images/dual-screen-device.png){style="margin-left:auto; margin-right:auto; display: block;"
width="500" height="200"}

Figure showing virtual keyboard on single-touch screen device ![Figure
showing virtual keyboard on single-touch screen
device](images/single-touch-screen-device.png){style="margin-left:auto; margin-right:auto; display: block;"
width="500" height="200"}

This specification defines conformance criteria that apply to a single
product: the [user agent] that implements the
interfaces that it contains.

Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent. (In
particular, the algorithms defined in this specification are intended to
be easy to follow, and not intended to be performant.)

## The [VirtualKeyboard] Interface

``` idl

 partial interface Navigator {
 [SecureContext, SameObject] readonly attribute VirtualKeyboard virtualKeyboard;
 };

 [Exposed=Window, SecureContext]
 interface VirtualKeyboard : EventTarget {
 undefined show();
 undefined hide();
 readonly attribute DOMRect boundingRect;
 attribute boolean overlaysContent;
 attribute EventHandler ongeometrychange;
 };

```

The {{VirtualKeyboard}} object has an associated:

[boundingRect]

A {{DOMRect}}, initially has zero values.

[overlaysContent]

A boolean, initially \`false\`. When this attribute is set to \`true\`,
a user agent MUST NOT resize its \[=document=\]\'s
[viewport](https://drafts.csswg.org/css2/#viewport) or [visual
viewport](https://wicg.github.io/visual-viewport/#dom-visualviewport).

[show()] method

The method must follow these steps:

1. Let \|window\| be \[=this=\]\'s \[=relevant global object=\]. Assert
 that \|window\| is a {{Window}} object.
2. If \|window\| does not have \[=sticky activation=\], abort these
 steps.
3. If the focused element is not a form control (such as the value of
 the \[=textarea=\] element), or an \[=editing host=\] (e.g., using
 [contenteditable](https://html.spec.whatwg.org/multipage/interaction.html#attr-contenteditable))
 then abort these steps.
4. If the {{ElementContentEditable/virtualKeyboardPolicy}} is not
 {{manual}} or
 [inputMode\'s](https://html.spec.whatwg.org/multipage/interaction.html#input-modalities:-the-inputmode-attribute)
 attribute value is
 [none](https://html.spec.whatwg.org/multipage/interaction.html#attr-inputmode-keyword-none)
 then abort these steps.
5. Call the system API to show the VK.
6. \[=In parallel=\], follow these steps:
 1. Wait for the virtual keyboard to be shown by the system.
 2. Call {{VirtualKeyboard/set the virtual keyboard bounding rect}}
 with the keyboard\'s OS reported bounding rectangle and the
 \[=document=\]\'s
 [viewport](https://drafts.csswg.org/css2/#viewport) rectangle.
 3. \[=Fire an event=\] named \"geometrychange\" at \[=this=\].

[hide()] method

The method must follow these steps:

1. Let \|window\| be \[=this=\]\'s \[=relevant global object=\]. Assert
 that \|window\| is a {{Window}} object.
2. If \|window\| does not have \[=sticky activation=\], abort these
 steps.
3. If the focused element\'s
 {{ElementContentEditable/virtualKeyboardPolicy}} is not {{manual}}
 or
 [inputMode\'s](https://html.spec.whatwg.org/multipage/interaction.html#input-modalities:-the-inputmode-attribute)
 attribute value is
 [none](https://html.spec.whatwg.org/multipage/interaction.html#attr-inputmode-keyword-none)
 then abort these steps.
4. Call the system API to hide the VK.
5. \[=In parallel=\], follow these steps:
 1. Wait for the virtual keyboard to be hidden by the system.
 2. Call {{VirtualKeyboard/set the virtual keyboard bounding rect}}
 with the keyboard\'s OS reported bounding rectangle (which has
 all 0 values) and the \[=document=\]\'s
 [viewport](https://drafts.csswg.org/css2/#viewport) rectangle.
 3. \[=Fire an event=\] named \"geometrychange\" at \[=this=\].

Platform heuristics may impose additional restrictions on VK
{{VirtualKeyboard/show()}} and {{VirtualKeyboard/hide()}}. e.g., on
Windows the pointer type MUST be touch or pen.

A few people have [expressed
concerns](https://github.com/MicrosoftEdge/MSEdgeExplainers/issues/415)
around {{VirtualKeyboard/show()}} and {{VirtualKeyboard/hide()}} methods
not being promise-based, but we believe it is a better design for web
developers to use {{VirtualKeyboard/ongeometrychange}} event since it is
fired when VK visibility changes, making the return values unnecessary.

{{VirtualKeyboard/overlaysContent}}

The {{VirtualKeyboard/overlaysContent}} getter steps are to return
\[=this=\]\'s {{VirtualKeyboard/overlaysContent}}.

The {{VirtualKeyboard/overlaysContent}} setter steps are to set
\[=this=\]\'s {{VirtualKeyboard/overlaysContent}} to the given value.

{{VirtualKeyboard/boundingRect}}

The attribute reports the intersection of the VK with the
\[=document=\]\'s [viewport](https://drafts.csswg.org/css2/#viewport) in
client coordinates. Call {{VirtualKeyboard/set the virtual keyboard
bounding rect}}.

[set the virtual keyboard bounding rect]

To set the virtual keyboard bounding rect, with \|osk\| (a DOMRect
representing the on-screen keyboard rectangle), and \|lv\| (a DOMRect
representing the \[=document=\]\'s
[viewport](https://drafts.csswg.org/css2/#viewport) rectangle) as
inputs, run the following steps:

1. Let \|osk\| be the on-screen keyboard rectangle that is the result
 of running the algorithm in {{VirtualKeyboard/show()}} or
 {{VirtualKeyboard/hide()}} on \[=this=\].
2. Let \|lv\| be the \[=document=\]\'s
 [viewport](https://drafts.csswg.org/css2/#viewport) that is the
 result of running the algorithm in {{VirtualKeyboard/show()}} or
 {{VirtualKeyboard/hide()}} on \[=this=\].
3. Map \|osk\| to the coordinate space of \|lv\|.
4. Let \|bounds\| be a {{DOMRect}} object.
5. Update \|bounds\| by intersecting \|lv\| with the \|osk\|.
6. Map \|bounds\| to the coordinate space of \|lv\|.
7. Return \|bounds\|.

The {{VirtualKeyboard/boundingRect}} getter steps are to return
\[=this=\]\'s {{VirtualKeyboard/boundingRect}}.

[ongeometrychange]

The event is dispatched when the intersection of the VK and the
\[=document=\]\'s [viewport](https://drafts.csswg.org/css2/#viewport)
changes, e.g., in response to the VK being shown or hidden or the
browser window being repositioned.

## Extensions to the [ElementContentEditable] mixin

``` idl

 partial interface mixin ElementContentEditable {
 [CEReactions] attribute DOMString virtualKeyboardPolicy;
 };

```

Add handling of input and textarea.

The [virtualKeyboardPolicy] is an [enumerated
attribute](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#enumerated-attribute)
whose keywords are the `empty string`, `auto`, and `manual`. The IDL
attribute must
[reflect](https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#reflect)
the respective content attributes of the same name. When specified on an
element that is a contenteditable host, `auto` causes the corresponding
editable element to automatically show the VK when it is focused or
tapped & `manual` decouples focus and tap on the editable element from
changes in the VK's current state - the VK remains as it was.\
The change in setting of any
{{ElementContentEditable/virtualKeyboardPolicy}} attribute value,
negates currently defined behavior, unless it is a change from `auto` to
`empty string` or vice versa.

Specify timing relative to events like focus.

- When [auto] enumerated attribute is set, the VK is handled by
 the browser.
- When [manual] enumerated attribute is set, it prevents the
 default handling of the VK in a browser and needs to be handled by the
 script.
- When [empty string] enumerated attribute is set, the VK is
 handled by the browser.

## Virtual Keyboard Visibility Change CSS environment variables.

The {{VirtualKeyboard}} API proposes six new [CSS environment
variables](https://drafts.csswg.org/css-env-1/#environment) that the web
developers can utilize to calculate the virtual keyboard\'s size and
adjust layout in a declarative way.

These CSS env should be added to the [CSS env variable
spec](https://drafts.csswg.org/css-env-1/#env-function).

### Keyboard inset variables

Name

Value

[keyboard-inset-top]

[length](https://drafts.csswg.org/css-values-3/#length-value)

[keyboard-inset-right]

[length](https://drafts.csswg.org/css-values-3/#length-value)

[keyboard-inset-bottom]

[length](https://drafts.csswg.org/css-values-3/#length-value)

[keyboard-inset-left]

[length](https://drafts.csswg.org/css-values-3/#length-value)

[keyboard-inset-width]

[length](https://drafts.csswg.org/css-values-3/#length-value)

[keyboard-inset-height]

[length](https://drafts.csswg.org/css-values-3/#length-value)

The keyboard insets are six [environment
variables](https://drafts.csswg.org/css-env-1/#environment) that define
a rectangle by its top, right, bottom, and left insets from the edge of
the viewport. Default value of the keyboard insets are \"0px\" if a
fallback value is not provided else it gets updated when
{{VirtualKeyboard/boundingRect}} value changes. The width & height
insets are calculated from the remaining insets for developer
ergonomics.

## Examples

### Example with usage of VK control APIs.

 42

 let div = document.querySelector("div")
 div.addEventListener("focusout", handleFocusOut)
 div.addEventListener("dblclick", handleDblClick)

 function handleFocusOut() {
 let formula = parseIntoFormula(div.firstChild.data)
 div.setAttribute("data-formula", formula)
 div.firstChild.data = evaluateFormula(formula)
 }

 function handleDblClick(e) {
 div.firstChild.data = div.getAttribute("data-formula")

 if (e.pointerType == "touch") {
 navigator.virtualKeyboard.show()
 }
 }

 function parseIntoFormula(text) {
 return "12+30"
 }

 function evaluateFormula(formula) {
 return "42"
 }

 function handleSuccessfulShow() {
 // handle success of VK shown
 }

 function handleFailedShow() {
 // handle failure of VK shown
 }

### Examples with usage of overlaysContent and geometry event as a result of VK showing.

 body {
 display: grid;
 margin: 8px;
 height: calc(100vh - 16px);
 grid-template:
 "messages" 1fr
 "input" auto
 "keyboard" env(keyboard-inset-height, 0px);
 }
 input[type=text]::placeholder {
 color: #444;
 }
 input[type=text] {
 padding: 10px;
 font-size: 24px;
 border: 4px solid black;
 border-radius: 4px;
 background-color: #86DBF6;
 justify-self: center;
 }

 ...

 if ("virtualKeyboard" in navigator) {
 navigator.virtualKeyboard.overlaysContent = true
 }

The figure and markup below are a representation of a canvas-based
spreadsheet that repositions the active cell when the VK is shown. The
\`geometrychange\` event triggers a paint request for the canvas. The
painting code can then use the \`boundingRect\` property to render the
active cell in the proper location. ![Figure showing virtual keyboard on
single-touch screen
device](images/spreadsheet-example.svg){style="margin-left:auto; margin-right:auto; display: block;"
width="700" height="300"}

 body {
 display: grid;
 margin: 0;
 height: 100vh;
 grid-template:
 "controls" min-content
 "cells" 1fr;
 }
 #controls {
 height: 100px;
 background-color: #139CFF;
 }
 canvas {
 justify-self: stretch;
 align-self: stretch;
 }

 ...

 navigator.virtualKeyboard.overlaysContent = true

 navigator.virtualKeyboard.addEventListener("geometrychange", () => {
 // Request the canvas be repainted so it can reposition
 // the active cell above the virtual keyboard.
 requestAnimationFrame(paintCanvas)
 })

 paintCanvas() {
 let keyboardRect = navigator.virtualKeyboard.boundingRect
 // Use keyboard rect in omitted code below to paint cells in the
 // proper position accounting for the keyboard rect along with
 // any panning of the cell area that the user may have performed.
 }

The figure below represents a map application that presents a map on one
window segment and search results on another. Using the proposal for
[Window
Segments](https://github.com/MicrosoftEdge/MSEdgeExplainers/blob/main/Foldables/explainer.md)
and media queries, the search box shown will increase its bottom margin
to remain visible whenever the virtual keyboard appears on the left side
of the foldable device. ![Figure showing virtual keyboard on
single-touch screen
device](images/example.png){style="margin-left:auto; margin-right:auto; display: block;"
width="700" height="300"}

 @media (spanning: single-fold-vertical) {
 body {
 display: grid;
 margin: 0;
 height: 100vh;
 grid-template-columns: env(fold-left) calc(100vw - env(fold-right));
 grid-column-gap: calc(env(fold-right) - env(fold-left));
 }
 .map {
 grid-column: 1;
 grid-row: 1;
 }
 .search-box {
 /* overlay into same grid column as the map */
 grid-column: 1;
 grid-row: 1;

 /* position the search box at the bottom of the cell, centered */
 align-self: end;

 /* margin when keyboard not showing on left screen */
 margin: 20px;

 /* give it a little style */
 padding: 10px;
 font-size: 24px;
 border: 4px solid black;
 border-radius: 4px;
 background-color: #86DBF6;
 }
 .locations-list {
 grid-column: 2;
 grid-row: 1;
 }

 @media (env(keyboard-inset-right) <= env(fold-left)) {
 /* keyboard is on the left screen, adjust search box */
 .search-box {
 margin-bottom: calc(20px + env(keyboard-inset-height));
 }
 }
 }

 ...

 ...

 navigator.virtualKeyboard.overlaysContent = true

## Privacy and Security Considerations

Because VirtualKeyboard APIs may reveal some aspects about layout of
user\'s VK, user agents must ensure that no extra information is exposed
to the script that it already has through existing APIs. To mitigate
potential security and privacy risks, browsers are expected to follow
best practices described below.

### {{VirtualKeyboard/hide()}} and {{VirtualKeyboard/show()}} methods

- User Agent MUST only allow {{VirtualKeyboard/hide()}} and
 {{VirtualKeyboard/show()}} methods to be called in a [Secure
 Context](https://w3c.github.io/webappsec-secure-contexts/).
- User Agent MUST only allow the {{VirtualKeyboard/show()}} method to be
 called when \[=sticky activation=\] is present.

### {{VirtualKeyboard/boundingRect}}, {{VirtualKeyboard/overlaysContent}} and {{VirtualKeyboard/ongeometrychange}} attributes

User Agent MUST only allow {{VirtualKeyboard/overlaysContent}} to be set
in a [secure](https://w3c.github.io/webappsec-secure-contexts/), \[=
top-level browsing context=\].

## Contributors

Add contributors
