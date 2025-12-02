
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Selection API

[W3C Working Draft](https://www.w3.org/standards/types#WD) 05 January
2025

More details about this document

This version:
: [https://www.w3.org/TR/2025/WD-selection-api-20250105/](https://www.w3.org/TR/2025/WD-selection-api-20250105/)

Latest published version:
: <https://www.w3.org/TR/selection-api/>

Latest editor\'s draft:
: <https://w3c.github.io/selection-api/>

History:
: <https://www.w3.org/standards/history/selection-api/>
: [Commit history](https://github.com/w3c/selection-api/commits/)

Test suite:
: <https://wpt.fyi/results/selection/>

Editor:
: [Ryosuke Niwa](mailto:rniwa@apple.com) ([Apple Inc.](https://www.apple.com/))

Feedback:
: [GitHub w3c/selection-api](https://github.com/w3c/selection-api/)
 ([pull requests](https://github.com/w3c/selection-api/pulls/), [new
 issue](https://github.com/w3c/selection-api/issues/new/choose),
 [open issues](https://github.com/w3c/selection-api/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2025 [World Wide
Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This document is a preliminary draft of a specification for the
Selection API and selection related functionality. It replaces a couple
of old sections of the [HTML
specification](https://www.w3.org/TR/html5/), the selection part of the
old [DOM Range
specification](https://www.w3.org/TR/2000/REC-DOM-Level-2-Traversal-Range-20001113/ranges.html).

This document defines APIs for selection, which allows users and authors
to select a portion of a document or specify a point of interest for
copy, paste, and other editing operations.

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] technical reports
index](https://www.w3.org/TR/) at https://www.w3.org/TR/.*

This is work in progress.

This document was published by the [Web Editing Working
Group](https://www.w3.org/groups/wg/webediting) as a Working Draft using
the [Recommendation
track](https://www.w3.org/policies/process/20231103/#recs-and-notes).

Publication as a Working Draft does not imply endorsement by [W3C] and its Members.

This is a draft document and may be updated, replaced or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/webediting/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent which the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [03 November 2023 [W3C] Process
Document](https://www.w3.org/policies/process/20231103/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Background](#background)
4. [2. Definition](#definition)
5. [3. Selection interface](#selection-interface)
6. [4. Extensions to Other
 Interfaces](#extensions-to-other-interfaces)
 1. [4.1 Extensions to `Document`
 interface](#extensions-to-document-interface)
 2. [4.2 Extensions to `Window`
 interface](#extensions-to-window-interface)
 3. [4.3 Extensions to `GlobalEventHandlers`
 interface](#extensions-to-globaleventhandlers-interface)
7. [5. Responding to DOM
 Mutations](#responding-to-dom-mutations)
8. [6. User Interactions](#user-interactions)
 1. [6.1 [`selectstart`]
 event](#selectstart-event)
 2. [6.2 [`selectionchange`]
 event](#selectionchange-event)
 1. [6.2.1 Scheduling `selectionchange`
 event](#scheduling-selectionchange-event)
 2. [6.2.2 Firing `selectionchange`
 event](#firing-selectionchange-event)
9. [7. Conformance](#conformance)
10. [8. Security and Privacy
 considerations](#security-and-privacy-considerations)
11. [A. Acknowledgements](#acknowledgements)
12. [B. References](#references)
 1. [B.1 Normative references](#normative-references)

::: header-wrapper
## 1. Background

*This section is non-normative.*

IE9 and Firefox 6.0a2 allow arbitrary ranges in the selection, which
follows what this spec originally said. However, this leads to
unpleasant corner cases that authors, implementers, and spec writers all
have to deal with, and they don\'t make any real sense. Chrome 14 dev
and Opera 11.11 aggressively normalize selections, like not letting them
lie inside empty elements and things like that, but this is also viewed
as a bad idea, because it takes flexibility away from authors.

So I changed the spec to a made-up compromise that allows some
simplification but doesn\'t constrain authors much. See
[discussion](https://lists.w3.org/Archives/Public/public-whatwg-archive/2011Jun/0193.html).
Basically it would throw exceptions in some places to try to stop the
selection from containing a range that had a [boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
other than an Element or Text node, or a boundary point that didn\'t
descend from a Document.

But this meant getRangeAt() had to start returning a copy, not a
reference. Also, it would be prone to things failing weirdly in corner
cases. Perhaps most significantly, all sorts of problems might arise
when DOM mutations transpire, like if a boundary point\'s node is
removed from its parent and the mutation rules would place the new
boundary point inside a non-Text/Element node. And finally, the
previously-specified behavior had the advantage of matching two major
implementations, while the new behavior matched no one. So I changed it
back.

See [bug 15470](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15470).
IE9, Firefox 12.0a1, Chrome 17 dev, and Opera Next 12.00 alpha all make
the range initially null.

::: header-wrapper
## 2. Definition

Every [document](https://dom.spec.whatwg.org/#document)
with a [browsing
context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc)
has a unique [selection] associated with it.

This is a requirement of the HTML spec. IE9 and Opera Next 12.00 alpha
seem to follow it, while Firefox 12.0a1 and Chrome 17 dev seem not to.
See [Mozilla bug](https://bugzilla.mozilla.org/show_bug.cgi?id=717339),
[WebKit bug](https://bugs.webkit.org/show_bug.cgi?id=76114).

This one [selection](#dfn-selection) must be shared by all the content of the
[document](https://dom.spec.whatwg.org/#document)
(though not by nested
[documents](https://dom.spec.whatwg.org/#document)),
including any [editing
hosts](https://html.spec.whatwg.org/multipage/interaction.html#editing-host)
in the
[document](https://dom.spec.whatwg.org/#document).

Each [selection](#dfn-selection) can be associated with a single
[range](https://dom.spec.whatwg.org/#concept-range).
When there is no
[range](https://dom.spec.whatwg.org/#concept-range)
associated with the [selection](#dfn-selection), the selection is [empty]. The selection must
be initially [empty](#dfn-empty).

A [document](https://dom.spec.whatwg.org/#document)\'s
[selection](#dfn-selection) is a singleton object associated with that
[document](https://dom.spec.whatwg.org/#document), so
it gets replaced with a new object when `Document.open()` is called. See
[bug 15470](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15470). IE9
and Opera Next 12.00 alpha allow the user to reset the range to null
after the fact by clicking somewhere; Firefox 12.0a1 and Chrome 17 dev
do not. We follow Gecko/WebKit, because it lessens the chance of
getRangeAt(0) throwing.

Once a [selection](#dfn-selection) is associated with a given
[range](https://dom.spec.whatwg.org/#concept-range), it
must continue to be associated with that same
[range](https://dom.spec.whatwg.org/#concept-range)
until this specification requires otherwise.

For instance, if the DOM changes in a way that changes the range\'s
boundary points, or a script modifies the boundary points of the range,
the same range object must continue to be associated with the selection.
However, if the user changes the selection or a script calls
[`addRange`](#dom-selection-addrange)`()`, the selection must be
associated with a new range object, as required elsewhere in this
specification.

If the [selection](#dfn-selection)\'s
[range](https://dom.spec.whatwg.org/#concept-range) is
not null and is
[collapsed](https://dom.spec.whatwg.org/#range-collapsed),
then the caret position must be at that
[range](https://dom.spec.whatwg.org/#concept-range)\'s
[boundary
point](https://dom.spec.whatwg.org/#concept-range-bp).
When the [selection](#dfn-selection) is not
[collapsed](https://dom.spec.whatwg.org/#range-collapsed),
this specification does not define the caret position; user agents
should follow platform conventions in deciding whether the caret is at
the start of the [selection](#dfn-selection), the end of the
[selection](#dfn-selection), or somewhere else.

Each [selection](#dfn-selection) has a [direction]: [forwards],
[backwards], or [directionless]. If the user creates a
[selection](#dfn-selection) by indicating first one [boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
of the
[range](https://dom.spec.whatwg.org/#concept-range) and
then the other (such as by clicking on one point and dragging to
another), and the first indicated [boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
is
[after](https://dom.spec.whatwg.org/#concept-range-bp-after)
the second, then the corresponding
[selection](#dfn-selection) must initially be
[backwards](#dfn-backwards). If the first indicated [boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
is
[before](https://dom.spec.whatwg.org/#concept-range-bp-before)
the second, then the corresponding
[selection](#dfn-selection) must initially be
[forwards](#dfn-forwards). Otherwise, it must be
[directionless](#dfn-directionless).

When the [selection](#dfn-selection)\'s
[range](https://dom.spec.whatwg.org/#concept-range) is
mutated by scripts, e.g. via
[`selectNode`](https://dom.spec.whatwg.org/#dom-range-selectnode)`(``node``)`,
[direction](#dfn-direction) of the
[selection](#dfn-selection) must be preserved.

Each [selection](#dfn-selection)s also have an [anchor] and a [focus]. If the
[selection](#dfn-selection)\'s
[range](https://dom.spec.whatwg.org/#concept-range) is
null, its [anchor](#dfn-anchor) and [focus](#dfn-focus) are both null. If the
[selection](#dfn-selection)\'s
[range](https://dom.spec.whatwg.org/#concept-range) is
not null and its [direction](#dfn-direction) is
[forwards](#dfn-forwards), its [anchor](#dfn-anchor) is the
[range](https://dom.spec.whatwg.org/#concept-range)\'s
[start](https://dom.spec.whatwg.org/#concept-range-start),
and its [focus](#dfn-focus) is the
[end](https://dom.spec.whatwg.org/#concept-range-end).
Otherwise, its [focus](#dfn-focus) is the
[start](https://dom.spec.whatwg.org/#concept-range-start)
and its [anchor](#dfn-anchor) is the
[end](https://dom.spec.whatwg.org/#concept-range-end).

[anchor](#dfn-anchor) and [focus](#dfn-focus) of
[selection](#dfn-selection) need not to be in the [document
tree](https://dom.spec.whatwg.org/#concept-document-tree).
It could be in a [shadow
tree](https://dom.spec.whatwg.org/#concept-shadow-tree)
of the same
[document](https://dom.spec.whatwg.org/#document).

Each [document](https://dom.spec.whatwg.org/#document),
[input](https://html.spec.whatwg.org/multipage/input.html#the-input-element)
element, and
[textarea](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element)
element has a boolean [has scheduled selectionchange
event], which is initially false.

::: header-wrapper
## 3. Selection interface

[Selection](#dfn-selection) interface provides a way to interact with the
[selection](#dfn-selection) associated with each document.

```
WebIDL[Exposed=Window]
interface Selection {
 readonly attribute Node? anchorNode;
 readonly attribute unsigned long anchorOffset;
 readonly attribute Node? focusNode;
 readonly attribute unsigned long focusOffset;
 readonly attribute boolean isCollapsed;
 readonly attribute unsigned long rangeCount;
 readonly attribute DOMString type;
 readonly attribute DOMString direction;
 Range getRangeAt(unsigned long index);
 undefined addRange(Range range);
 undefined removeRange(Range range);
 undefined removeAllRanges();
 undefined empty();
 sequence<StaticRange> getComposedRanges(optional GetComposedRangesOptions options = );
 undefined collapse(Node? node, optional unsigned long offset = 0);
 undefined setPosition(Node? node, optional unsigned long offset = 0);
 undefined collapseToStart();
 undefined collapseToEnd();
 undefined extend(Node node, optional unsigned long offset = 0);
 undefined setBaseAndExtent(Node anchorNode, unsigned long anchorOffset, Node focusNode, unsigned long focusOffset);
 undefined selectAllChildren(Node node);
 undefined modify(optional DOMString alter, optional DOMString direction, optional DOMString granularity);
 [CEReactions] undefined deleteFromDocument();
 boolean containsNode(Node node, optional boolean allowPartialContainment = false);
 stringifier;
};

dictionary GetComposedRangesOptions {
 sequence<ShadowRoot> shadowRoots = ;
};
```

[`anchorNode`]

: The attribute must return the
 [anchor](#dfn-anchor)
 [node](https://dom.spec.whatwg.org/#boundary-point-node)
 of [this](https://webidl.spec.whatwg.org/#this), or
 `null` if the [anchor](#dfn-anchor) is null or
 [anchor](#dfn-anchor) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).

[`anchorOffset`]

: The attribute must return the
 [anchor](#dfn-anchor)
 [offset](https://dom.spec.whatwg.org/#concept-range-bp-offset)
 of [this](https://webidl.spec.whatwg.org/#this), or
 `0` if the [anchor](#dfn-anchor) is null or
 [anchor](#dfn-anchor) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).

[`focusNode`]

: The attribute must return the
 [focus](#dfn-focus)
 [node](https://dom.spec.whatwg.org/#boundary-point-node)
 of [this](https://webidl.spec.whatwg.org/#this), or
 `null` if the [focus](#dfn-focus) is null or [focus](#dfn-focus) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).

[`focusOffset`]

: The attribute must return the
 [focus](#dfn-focus)
 [offset](https://dom.spec.whatwg.org/#concept-range-bp-offset)
 of [this](https://webidl.spec.whatwg.org/#this), or
 `0` if the [focus](#dfn-focus) is null or
 [focus](#dfn-focus) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).

[`isCollapsed`]

: The attribute must return true if and only if the anchor and focus
 are the same (including if both are null). Otherwise it must return
 false.

[`rangeCount`]

: The attribute must return `0` if
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty) or either [focus](#dfn-focus) or
 [anchor](#dfn-anchor) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree),
 and must return `1` otherwise.

[`type`]

: The attribute must return `"None"` if
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty) or either [focus](#dfn-focus) or
 [anchor](#dfn-anchor) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree),
 `"Caret"` if
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 is
 [collapsed](https://dom.spec.whatwg.org/#range-collapsed),
 and `"Range"` otherwise.

[`direction`]

: The attribute must return `"none"` if
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty) or this selection is
 [directionless](#dfn-directionless). `"forward"` if this selection\'s
 direction is [forwards](#dfn-forwards) and `"backward"` if this selection\'s
 direction is [backwards](#dfn-backwards).

[`getRangeAt()`] method

: The method must throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception if `index` is not `0`, or
 if [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty) or either [focus](#dfn-focus) or
 [anchor](#dfn-anchor) is not in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).
 Otherwise, it must return a reference to (not a copy of)
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range).

 ::::
 :::
 Note
 :::

 Thus subsequent calls of this method returns the same
 [range](https://dom.spec.whatwg.org/#concept-range)
 object if nothing has removed
 [this](https://webidl.spec.whatwg.org/#this)\'s
 range in the meantime. In particular,
 `getSelection().getRangeAt(0) === getSelection().getRangeAt(0)`
 evaluates to `true` if the
 [selection](#dfn-selection) is not [empty](#dfn-empty).
 ::::

[`addRange()`] method

: The method must follow these steps:

 1. If the
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 of the `range`\'s boundary points are not the
 [document](https://dom.spec.whatwg.org/#document)
 associated with
 [this](https://webidl.spec.whatwg.org/#this),
 abort these steps.
 2. If `rangeCount` is not `0`, abort these steps.
 3. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 range to `range` by a strong reference (not by making
 a copy).

 ::::
 :::
 Note
 :::

 Since
 [range](https://dom.spec.whatwg.org/#concept-range)
 is added by reference, subsequent calls to `getRangeAt(0)` returns
 the same object, and any changes that a script makes to
 [range](https://dom.spec.whatwg.org/#concept-range)
 after it is added must be reflected in the
 [selection](#dfn-selection), until something else removes or replaces
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range).
 In particular, the
 [selection](#dfn-selection) will contain `b` as opposed to
 `a` after running the following code:
 `var r = document.createRange(); r.selectNode(a); getSelection().addRange(r); r.selectNode(b);`
 ::::

 :::::
 :::
 Note
 :::

 :::
 At Step 2, Chrome 58 and Edge 25 do nothing. Firefox 51 gives you a
 multi-range selection. At least they keep the exisiting
 [range](https://dom.spec.whatwg.org/#concept-range).

 At Step 3, Chrome 58 and Firefox 51 store a reference, as described
 here. Edge 25 stores a copy. Firefox 51 changes its selection if the
 [range](https://dom.spec.whatwg.org/#concept-range)
 is modified.
 :::
 :::::

[`removeRange()`] method

: The method must make
 [this](https://webidl.spec.whatwg.org/#this)
 [empty](#dfn-empty) by disassociating its
 [range](https://dom.spec.whatwg.org/#concept-range)
 if [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 is `range`. Otherwise, it must throw a
 [`NotFoundError`](https://webidl.spec.whatwg.org/#notfounderror).

[`removeAllRanges()`] method

: The method must make
 [this](https://webidl.spec.whatwg.org/#this)
 [empty](#dfn-empty) by disassociating its
 [range](https://dom.spec.whatwg.org/#concept-range)
 if [this](https://webidl.spec.whatwg.org/#this) has
 an associated
 [range](https://dom.spec.whatwg.org/#concept-range).

[`empty()`] method

: The method must be an alias, and behave identically, to
 `removeAllRanges()`.

[`getComposedRanges()`] method

: 1. If [this](https://webidl.spec.whatwg.org/#this)
 is [empty](#dfn-empty), return an empty array.
 2. Otherwise, let `startNode` be [start
 node](https://dom.spec.whatwg.org/#concept-range-start-node)
 of the
 [range](https://dom.spec.whatwg.org/#concept-range)
 associated with
 [this](https://webidl.spec.whatwg.org/#this),
 and let `startOffset` be [start
 offset](https://dom.spec.whatwg.org/#concept-range-start-offset)
 of the
 [range](https://dom.spec.whatwg.org/#concept-range).
 3. While `startNode` is a
 [node](https://dom.spec.whatwg.org/#concept-node),
 `startNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is a [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root),
 and `startNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor)
 of any of
 `options`\[\"[`shadowRoots`](#dom-getcomposedrangesoptions-shadowroots)\"\], repeat these steps:
 1. Set `startOffset` to
 [index](https://dom.spec.whatwg.org/#concept-tree-index)
 of `startNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)\'s
 [host](https://url.spec.whatwg.org/#concept-host).
 2. Set `startNode` to `startNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)\'s
 [host](https://url.spec.whatwg.org/#concept-host)\'s
 [parent](https://dom.spec.whatwg.org/#concept-tree-parent).
 4. Let `endNode` be [end
 node](https://dom.spec.whatwg.org/#concept-range-end-node)
 of the
 [range](https://dom.spec.whatwg.org/#concept-range)
 associated with
 [this](https://webidl.spec.whatwg.org/#this),
 and let `endOffset` be [end
 offset](https://dom.spec.whatwg.org/#concept-range-end-offset)
 of the
 [range](https://dom.spec.whatwg.org/#concept-range).
 5. While `endNode` is a
 [node](https://dom.spec.whatwg.org/#concept-node),
 `endNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is a [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root),
 and `endNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor)
 of any of
 `options`\[\"[`shadowRoots`](#dom-getcomposedrangesoptions-shadowroots)\"\], repeat these steps:
 1. Set `endOffset` to
 [index](https://dom.spec.whatwg.org/#concept-tree-index)
 of `endNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)\'s
 [host](https://url.spec.whatwg.org/#concept-host)
 plus 1.
 2. Set `endNode` to `endNode`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)\'s
 [host](https://url.spec.whatwg.org/#concept-host)\'s
 [parent](https://dom.spec.whatwg.org/#concept-tree-parent).
 6. Return an array consisting of new
 [`StaticRange`](https://dom.spec.whatwg.org/#staticrange) whose [start
 node](https://dom.spec.whatwg.org/#concept-range-start-node)
 is `startNode`, [start
 offset](https://dom.spec.whatwg.org/#concept-range-start-offset)
 is `startOffset`, [end
 node](https://dom.spec.whatwg.org/#concept-range-end-node)
 is `endNode`, and [end
 offset](https://dom.spec.whatwg.org/#concept-range-end-offset)
 is `endOffset`.

[`collapse()`] method

: The method must follow these steps:

 1. If `node` is null, this method must behave
 identically as `removeAllRanges()` and abort these steps.
 2. If `node` is a
 [`DocumentType`](https://dom.spec.whatwg.org/#documenttype), throw an
 [`InvalidNodeTypeError`](https://webidl.spec.whatwg.org/#invalidnodetypeerror) exception and abort these steps.
 3. The method must throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception if ` offset` is longer
 than `node`\'s
 [length](https://dom.spec.whatwg.org/#concept-node-length)
 and abort these steps.
 4. If
 [document](https://dom.spec.whatwg.org/#document)
 associated with
 [this](https://webidl.spec.whatwg.org/#this) is
 not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor)
 of `node`, abort these steps.
 5. Otherwise, let `newRange` be a new
 [range](https://dom.spec.whatwg.org/#concept-range).
 6. [Set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 the
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 and the
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 of `newRange` to (`node`,
 `offset`).
 7. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to `newRange`.

[`setPosition()`] method

: The method must be an alias, and behave identically, to
 `collapse()`.

[`collapseToStart()`] method

: The method must throw
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception if the
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty). Otherwise, it must create a new
 [range](https://dom.spec.whatwg.org/#concept-range),
 [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 both its
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 and
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to the
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 of [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range),
 and then set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to the newly-created
 [range](https://dom.spec.whatwg.org/#concept-range).

 ::::
 :::
 Note
 :::

 For collapseToStart/End, IE9 mutates the existing range, while
 Firefox 9.0a2 and Chrome 15 dev replace it with a new one. The spec
 follows the majority and replaces it with a new one, leaving the old
 Range object unchanged.
 ::::

[`collapseToEnd()`] method

: The method must throw
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception if the
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty). Otherwise, it must create a new
 [range](https://dom.spec.whatwg.org/#concept-range),
 [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 both its
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 and
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to the
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 of [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range),
 and then set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to the newly-created
 [range](https://dom.spec.whatwg.org/#concept-range).

[`extend()`] method

: The method must follow these steps:

 1. If the
 [document](https://dom.spec.whatwg.org/#document)
 associated with
 [this](https://webidl.spec.whatwg.org/#this) is
 not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor)
 of `node`, abort these steps.
 2. If [this](https://webidl.spec.whatwg.org/#this)
 is [empty](#dfn-empty), throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror) exception and abort these steps.
 3. Let `oldAnchor` and `oldFocus` be the
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [anchor](#dfn-anchor) and [focus](#dfn-focus), and let `newFocus` be
 the [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 (`node`, `offset`).
 4. Let `newRange` be a new
 [range](https://dom.spec.whatwg.org/#concept-range).
 5. If `node`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is not the same as the
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root),
 [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 `newRange`\'s
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 and
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to `newFocus`.
 6. Otherwise, if `oldAnchor` is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 or equal to `newFocus`, [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 `newRange`\'s
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 to `oldAnchor`, then set its
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to `newFocus`.
 7. Otherwise, [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 `newRange`\'s
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 to `newFocus`, then set its
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to `oldAnchor`.
 8. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to `newRange`.
 9. If `newFocus` is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 `oldAnchor`, set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [direction](#dfn-direction) to
 [backwards](#dfn-backwards). Otherwise, set it to
 [forwards](#dfn-forwards).

 ::::
 :::
 Note
 :::

 Reverse-engineered circa January 2011. IE doesn\'t support it, so
 I\'m relying on Firefox (implemented extend() sometime before 2000)
 and WebKit (implemented extend() in 2007). I\'m mostly ignoring
 Opera, because gsnedders tells me its implementation isn\'t
 compatible. Firefox 12.0a1 seems to mutate the existing range. IE9
 doesn\'t support extend(), and it\'s impossible to tell whether
 Chrome 17 dev or Opera Next 12.00 alpha mutate or replace, because
 getRangeAt() returns a copy anyway. Nevertheless, I go against Gecko
 here, to be consistent with collapse().
 ::::

[`setBaseAndExtent()`] method

: The method must follow these steps:

 1. If `anchorOffset` is longer than
 `anchorNode`\'s
 [length](https://dom.spec.whatwg.org/#concept-node-length)
 or if `focusOffset` is longer than
 `focusNode`\'s
 [length](https://dom.spec.whatwg.org/#concept-node-length),
 throw an
 [`IndexSizeError`](https://webidl.spec.whatwg.org/#indexsizeerror) exception and abort these steps.
 2. If
 [document](https://dom.spec.whatwg.org/#document)
 associated with
 [this](https://webidl.spec.whatwg.org/#this) is
 not a [shadow-including inclusive
 ancestor](https://dom.spec.whatwg.org/#concept-shadow-including-inclusive-ancestor)
 of `anchorNode` or `focusNode`, abort
 these steps.
 3. Let `anchor` be the [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 (`anchorNode`, `anchorOffset`) and let
 `focus` be the [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 (`focusNode`, `focusOffset`).
 4. Let `newRange` be a new
 [range](https://dom.spec.whatwg.org/#concept-range).
 5. If `anchor` is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 `focus`, [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 the `newRange`\'s
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 to `anchor` and its
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to ` focus`. Otherwise, [set the
 start](https://dom.spec.whatwg.org/#concept-range-bp-set)
 them to `focus` and `anchor` respectively.
 6. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to `newRange`.
 7. If `focus` is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 `anchor`, set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [direction](#dfn-direction) to
 [backwards](#dfn-backwards). Otherwise, set it to
 [forwards](#dfn-forwards)

[`selectAllChildren()`] method

: The method must follow these steps:

 1. If `node` is a
 [`DocumentType`](https://dom.spec.whatwg.org/#documenttype), throw an
 [`InvalidNodeTypeError`](https://webidl.spec.whatwg.org/#invalidnodetypeerror) exception and abort these steps.
 2. If `node`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is not the
 [document](https://dom.spec.whatwg.org/#document)
 associated with
 [this](https://webidl.spec.whatwg.org/#this),
 abort these steps.
 3. Let `newRange` be a new
 [range](https://dom.spec.whatwg.org/#concept-range)
 and `childCount` be the number of
 [children](https://dom.spec.whatwg.org/#concept-tree-child)
 of `node`.
 4. Set `newRange`\'s
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 to (`node`, `0`).
 5. Set `newRange`\'s
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 to (`node`, `childCount`).
 6. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 to `newRange`.
 7. Set
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [direction](#dfn-direction) to `forwards`.

 :::::
 :::
 Note
 :::

 :::
 Based mostly on Firefox 9.0a2. It has a bug that I didn\'t
 reproduce, namely that if you pass a Document as the argument, the
 end offset becomes 1 instead of the number of children it has. It
 also throws a RangeException instead of DOMException, because its
 implementation predated their merging.

 IE9 behaves similarly but with glitches. It throws \"Unspecified
 error.\" if the node is detached or display:none, and apparently in
 some random other cases too. It throws \"Invalid argument.\" for
 detached comments (only!). Finally, if you pass it a comment, it
 seems to select the whole comment, unlike with text nodes.

 Chrome 16 dev behaves as you\'d expect given its Selection
 implementation. It refuses to select anything that\'s not visible,
 so it\'s almost always wrong. Opera 11.50 just does nothing in all
 my tests, as usual.

 The new range replaces any existing one, doesn\'t mutate it. This
 matches IE9 and Firefox 12.0a1. (Chrome 17 dev and Opera Next 12.00
 alpha can\'t be tested, because getRangeAt() returns a copy anyway.)
 :::
 :::::

[`modify()`] method

: The method must follow these steps:

 1. If `alter` is not [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"extend\" or \"move\", abort these steps.
 2. If `direction` is not [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"forward\", \"backward\", \"left\", or \"right\",
 abort these steps.
 3. If `granularity` is not [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"character\", \"word\", \"sentence\", \"line\",
 \"paragraph\", \"lineboundary\", \"sentenceboundary\",
 \"paragraphboundary\", \"documentboundary\", abort these steps.
 4. If [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection) is empty, abort these steps.
 5. Let `effectiveDirection` be
 [backwards](#dfn-backwards).
 6. If `direction` is [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"forward\", set `effectiveDirection` to
 [forwards](#dfn-forwards).
 7. If `direction` is [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"right\" and [inline base
 direction](https://www.w3.org/TR/css-writing-modes-4/#inline-base-direction)
 of [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection)\'s
 [focus](#dfn-focus) is
 [ltr](https://www.w3.org/TR/css-writing-modes-4/#valdef-direction-ltr),
 set `effectiveDirection` to
 [forwards](#dfn-forwards).
 8. If `direction` is [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"left\" and [inline base
 direction](https://www.w3.org/TR/css-writing-modes-4/#inline-base-direction)
 of [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection)\'s
 [focus](#dfn-focus) is
 [rtl](https://www.w3.org/TR/css-writing-modes-4/#valdef-direction-rtl),
 set `effectiveDirection` to
 [forwards](#dfn-forwards).
 9. Set
 [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection)\'s
 [direction](#dfn-direction) to
 `effectiveDirection`.
 10. If `alter` is [ASCII
 case-insensitive](https://infra.spec.whatwg.org/#ascii-case-insensitive)
 match with \"extend\", set
 [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection)\'s
 [focus](#dfn-focus) to the location as if the user had requested to
 extend selection by ` granularity`.
 11. Otherwise, set
 [this](https://webidl.spec.whatwg.org/#this)
 [selection](#dfn-selection)\'s
 [focus](#dfn-focus) and
 [anchor](#dfn-anchor) to the location as if the user had requested to
 move selection by `granularity`.

 ::::
 :::
 Note
 :::

 We need to more precisely define what it means to extend or move
 selection by each granularity.
 ::::

[`deleteFromDocument()`] method

: The method must invoke
 [`deleteContents`](https://dom.spec.whatwg.org/#dom-range-deletecontents)`()` on
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [range](https://dom.spec.whatwg.org/#concept-range)
 if [this](https://webidl.spec.whatwg.org/#this) is
 not [empty](#dfn-empty) and both [focus](#dfn-focus) and
 [anchor](#dfn-anchor) are in the [document
 tree](https://dom.spec.whatwg.org/#concept-document-tree).
 Otherwise the method must do nothing.

 ::::
 :::
 Note
 :::

 This is the one method that actually mutates the range instead of
 replacing it. This matches IE9 and Firefox 12.0a1. (Chrome 17 dev
 and Opera Next 12.00 alpha can\'t be tested, because getRangeAt()
 returns a copy anyway.)
 ::::

[`containsNode()`] method

: The method must return `false` if
 [this](https://webidl.spec.whatwg.org/#this) is
 [empty](#dfn-empty) or if `node`\'s
 [root](https://dom.spec.whatwg.org/#concept-tree-root)
 is not the document associated with
 [this](https://webidl.spec.whatwg.org/#this).

 Otherwise, if `allowPartialContainment` is `false`, the
 method must return `true` if and only if
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 of its
 [range](https://dom.spec.whatwg.org/#concept-range)
 is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 or visually equivalent to the first [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 in the `node` **and**
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 of its
 [range](https://dom.spec.whatwg.org/#concept-range)
 is
 [after](https://dom.spec.whatwg.org/#concept-range-bp-after)
 or visually equivalent to the last [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 in the `node`.

 If `allowPartialContainment` is `true`, the method must
 return `true` if and only if
 [start](https://dom.spec.whatwg.org/#concept-range-start)
 of its
 [range](https://dom.spec.whatwg.org/#concept-range)
 is
 [before](https://dom.spec.whatwg.org/#concept-range-bp-before)
 or visually equivalent to the last [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 in the `node` **and**
 [end](https://dom.spec.whatwg.org/#concept-range-end)
 of its
 [range](https://dom.spec.whatwg.org/#concept-range)
 is
 [after](https://dom.spec.whatwg.org/#concept-range-bp-after)
 or visually equivalent to the first [boundary
 point](https://dom.spec.whatwg.org/#concept-range-bp)
 in the `node`.

[`stringifier`]

: The stringification must return the string, which is the
 concatenation of the rendered text if there is a
 [range](https://dom.spec.whatwg.org/#concept-range)
 associated with
 [this](https://webidl.spec.whatwg.org/#this).

 If the selection is within a
 [textarea](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element)
 or
 [input](https://html.spec.whatwg.org/multipage/input.html#the-input-element)
 element, it must return the selected substring in its value.

See also
[nsISelection.idl](https://mxr.mozilla.org/mozilla/source/content/base/public/nsISelection.idl)
from Gecko. This spec doesn\'t have everything from there yet, in
particular selectionLanguageChange() and containsNode() are missing.
They are missing because I couldn\'t work out how to define them in
terms of Ranges.

Originally, the Selection interface was a Netscape feature. The original
implementation was carried on into Gecko (Firefox), and the feature was
later implemented independently by other browser engines. The Netscape
implementation always allowed multiple ranges in a single selection, for
instance so the user could select a column of a table However,
multi-range selections proved to be an unpleasant corner case that web
developers didn\'t know about and even Gecko developers rarely handled
correctly. Other browser engines never implemented the feature, and
clamped selections to a single range in various incompatible fashions.

This specification follows non-Gecko engines in restricting selections
to at most one range, but the API was still originally designed for
selections with arbitrary numbers of ranges. This explains oddities like
the coexistence of `removeRange()` and `removeAllRanges()`, and a
`getRangeAt()` method that takes an integer argument that must always be
zero.

All of the members of the
[`Selection`](#dom-selection) interface are defined in terms of
operations on the
[`range`](https://dom.spec.whatwg.org/#concept-range)
object (if any) represented by the object. These operations can raise
exceptions, as defined for the
[`Range`](https://dom.spec.whatwg.org/#range) interface; this can therefore result in the members of the
[Selection](#dfn-selection) interface raising exceptions as well, in addition to
any explicitly called out above.

::: header-wrapper
## 4. Extensions to Other Interfaces

This specification extends several interfaces to provide entry points to
the interfaces defined in this specification.

::: header-wrapper
### 4.1 Extensions to `Document` interface

The [[`Document`](https://dom.spec.whatwg.org/#document)] interface
is defined in \[[HTML](#bib-html "HTML Standard")\].

```
WebIDLpartial interface Document {
 Selection? getSelection();
};
```

[`getSelection()`] method

: The method must return the
 [selection](#dfn-selection) associated with
 [this](https://webidl.spec.whatwg.org/#this) if
 [this](https://webidl.spec.whatwg.org/#this) has an
 associated [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc),
 and it must return `null` otherwise.

::: header-wrapper
### 4.2 Extensions to `Window` interface

[[`Window`](https://html.spec.whatwg.org/multipage/window-object.html#window)] interface is defined in
\[[HTML](#bib-html "HTML Standard")\].

```
WebIDLpartial interface Window {
 Selection? getSelection();
};
```

[`getSelection()`] method

: The method must invoke and return the result of
 [`getSelection`](#dom-document-getselection)`()` on
 [this](https://webidl.spec.whatwg.org/#this)\'s
 [`Window`](https://html.spec.whatwg.org/multipage/window-object.html#window).[`document`](https://dom.spec.whatwg.org/#document)
 attribute.

::: header-wrapper
### 4.3 Extensions to `GlobalEventHandlers` interface

[[`GlobalEventHandlers`](https://html.spec.whatwg.org/multipage/webappapis.html#globaleventhandlers)] interface is defined in
\[[HTML](#bib-html "HTML Standard")\].

```
WebIDLpartial interface mixin GlobalEventHandlers {
 attribute EventHandler onselectstart;
 attribute EventHandler onselectionchange;
};
```

[`onselectstart`]

: The attribute must be an [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the [`selectstart`](#dfn-selectstart) event supported by all [HTML
 elements](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements),
 [`Document`](https://dom.spec.whatwg.org/#document) objects, and
 [`Window`](https://html.spec.whatwg.org/multipage/window-object.html#window) objects.

[`onselectionchange`]

: The attribute must be an [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes)
 for the
 [`selectionchange`](#dfn-selectionchange) event supported by all [HTML
 elements](https://html.spec.whatwg.org/multipage/infrastructure.html#html-elements),
 [`Document`](https://dom.spec.whatwg.org/#document) objects, and
 [`Window`](https://html.spec.whatwg.org/multipage/window-object.html#window) objects.

::: header-wrapper
## 5. Responding to DOM Mutations

When the user agent is to [replace
data](https://dom.spec.whatwg.org/#concept-cd-replace)
or [substring
data](https://dom.spec.whatwg.org/#concept-cd-substring)
on
[`CharacterData`](https://dom.spec.whatwg.org/#characterdata), the user agent must update the
[range](https://dom.spec.whatwg.org/#concept-range)
associated with [selection](#dfn-selection) of the [node
document](https://dom.spec.whatwg.org/#concept-node-document)
of the
[`CharacterData`](https://dom.spec.whatwg.org/#characterdata) as if it\'s a [live
range](https://dom.spec.whatwg.org/#concept-live-range).

When the user agent is to split a
[`Text`](https://dom.spec.whatwg.org/#text)
[node](https://dom.spec.whatwg.org/#concept-node), the
user agent must update the
[range](https://dom.spec.whatwg.org/#concept-range)
associated with [selection](#dfn-selection) of the [node
document](https://dom.spec.whatwg.org/#concept-node-document)
of the [`Text`](https://dom.spec.whatwg.org/#text) as if it\'s a [live
range](https://dom.spec.whatwg.org/#concept-live-range).

When the user agent is to run steps for `normalize()` method, the user
agent must update the
[range](https://dom.spec.whatwg.org/#concept-range)
associated with [selection](#dfn-selection) of the [node
document](https://dom.spec.whatwg.org/#concept-node-document)
of [this](https://webidl.spec.whatwg.org/#this) as if
it\'s a [live
range](https://dom.spec.whatwg.org/#concept-live-range).

When the user agent is to
[remove](https://dom.spec.whatwg.org/#concept-node-remove)
or
[insert](https://dom.spec.whatwg.org/#concept-node-insert)
a [node](https://dom.spec.whatwg.org/#concept-node),
the user agent must update the
[range](https://dom.spec.whatwg.org/#concept-range)
associated with [selection](#dfn-selection) of the [node
document](https://dom.spec.whatwg.org/#concept-node-document)
of the
[node](https://dom.spec.whatwg.org/#concept-node) as if
it\'s a [live
range](https://dom.spec.whatwg.org/#concept-live-range).

::: header-wrapper
## 6. User Interactions

The user agent should allow the user to change the
[selection](#dfn-selection) associated with the [active
document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).
If the user makes any modification to a
[selection](#dfn-selection), the user agent must create a new
[range](https://dom.spec.whatwg.org/#concept-range)
with suitable
[start](https://dom.spec.whatwg.org/#concept-range-start)
and
[end](https://dom.spec.whatwg.org/#concept-range-end)
of the
[range](https://dom.spec.whatwg.org/#concept-range) and
associate the [selection](#dfn-selection) with this new
[range](https://dom.spec.whatwg.org/#concept-range)
(not modify the existing
[range](https://dom.spec.whatwg.org/#concept-range)),
and set update [selection](#dfn-selection)\'s
[direction](#dfn-direction) to [forwards](#dfn-forwards) if the
[start](https://dom.spec.whatwg.org/#concept-range-start)
is
[before](https://dom.spec.whatwg.org/#concept-range-bp-before)
or equal to the
[end](https://dom.spec.whatwg.org/#concept-range-end),
[backwards](#dfn-backwards) if if the
[end](https://dom.spec.whatwg.org/#concept-range-end)
is
[before](https://dom.spec.whatwg.org/#concept-range-bp-before)
the
[start](https://dom.spec.whatwg.org/#concept-range-start),
or [directionless](#dfn-directionless) if the
[start](https://dom.spec.whatwg.org/#concept-range-start)
and the
[end](https://dom.spec.whatwg.org/#concept-range-end)
cannot be ordered due to the platform convention.

The user agent must not make a
[selection](#dfn-selection) [empty](#dfn-empty) if it was not already
[empty](#dfn-empty)
in response to any user actions (e.g. clicking on a non-editable
region).

See [bug 15470](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15470).
IE9 and Opera Next 12.00 alpha allow the user to reset the range to null
after the fact by clicking somewhere; Firefox 12.0a1 and Chrome 17 dev
do not. I follow Gecko/WebKit, because it lessens the chance of
getRangeAt(0) throwing.

::: header-wrapper
### 6.1 [`selectstart`] event

When the user agent is about to associate a new range
`newRange` to the
[selection](#dfn-selection) in response to a user initiated action, the user agent
must [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire)
named `selectstart`, which bubbles and is cancelable, at the
[node](https://dom.spec.whatwg.org/#boundary-point-node)
associated with the [boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
of `newRange`\'s
[start](https://dom.spec.whatwg.org/#concept-range-start)
prior to changing the selection if the
[selection](#dfn-selection) was previously
[empty](#dfn-empty)
or the previously associated range was
[collapsed](https://dom.spec.whatwg.org/#range-collapsed).

If the event is canceled, the user agent must not change the
[selection](#dfn-selection).

The user agent must not [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire)
when the user agent sets the
[selection](#dfn-selection) [empty](#dfn-empty).

::: header-wrapper
### 6.2 [`selectionchange`] event

When the [selection](#dfn-selection) is dissociated with its
[range](https://dom.spec.whatwg.org/#concept-range),
associated with a new
[range](https://dom.spec.whatwg.org/#concept-range), or
the associated
[range](https://dom.spec.whatwg.org/#concept-range)\'s
[boundary
point](https://dom.spec.whatwg.org/#concept-range-bp)
is mutated either by the user or the content script, the user agent must
[schedule a selectionchange
event](#dfn-schedule-a-selectionchange-event) on
[document](https://dom.spec.whatwg.org/#document).

When an
[`input`](https://html.spec.whatwg.org/multipage/input.html#the-input-element)
or
[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element)
element provide a text selection and its selection changes (in either
extent or [direction](#dfn-direction)), the user agent must
[schedule a selectionchange
event](#dfn-schedule-a-selectionchange-event) on the element.

::: header-wrapper
#### 6.2.1 Scheduling `selectionchange` event

To [schedule a selectionchange
event] on a node `target`,
run these steps:

1. If `target`\'s [has scheduled selectionchange
 event](#dfn-has-scheduled-selectionchange-event) is true, abort these steps.
2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task)
 on the [user interaction task
 source](https://html.spec.whatwg.org/multipage/webappapis.html#user-interaction-task-source)
 to [fire a selectionchange
 event](#dfn-fire-a-selectionchange-event) on `target`.

::: header-wrapper
#### 6.2.2 Firing `selectionchange` event

To [fire a selectionchange event] on a node
`target`, run these steps:

1. Set `target`\'s [has scheduled selectionchange
 event](#dfn-has-scheduled-selectionchange-event) to false.
2. If `target` is an element, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named `selectionchange`, which bubbles and not cancelable, at
 `target`.
3. Otherwise, if `target` is a document, [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire)
 named `selectionchange`, which does not bubble and not cancelable,
 at `target`.

::: header-wrapper
## 7. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

This specification defines conformance criteria that apply to a single
product: the [user
agent](https://infra.spec.whatwg.org/#user-agent) that
implements the interfaces that it contains.

::: header-wrapper
## 8. Security and Privacy considerations

There are no known security considerations for this standard.

To mitigate potential privacy risks of exposing user\'s use of assistive
technologies, for example, [user
agent](https://infra.spec.whatwg.org/#user-agent) may
elect to emulate mouse and keyboard events typically associated with
[`selectstart`](#dfn-selectstart) or
[`selectionchange`](#dfn-selectionchange) events when the user opts to modify the
[selection](#dfn-selection) of a document.

::: header-wrapper
## A. Acknowledgements

Many thanks to

- Aryeh Gregor, who is the original author of this specification as well
 as [HTML Editing API
 specification](https://dvcs.w3.org/hg/editing/raw-file/tip/editing.html)
- Contributors to the [HTML Editing API
 specification](https://dvcs.w3.org/hg/editing/raw-file/tip/editing.html) -
 Ehsan Akhgari, Tab Atkins, Mathias Bynens, Tim Down, Markus Ernst,
 Daniel Glazman, Tali Gregor (née Fuss), Stig Halvorsen, Jeff Harris,
 Ian Hickson, Cameron Heavon-Jones, Anne van Kesteren, Alfonso Martínez
 de Lizarrondo, Glenn Maynard, Ms2ger, Robert O\'Callahan, Julie
 Parent, Simon Pieters, Michael A. Puls II, Rich Schwerdtfeger, Jonas
 Sicking, Henri Sivonen, Smylers, Hallvord R. M. Steen, Roland Steiner,
 Annie Sullivan, timeless, Ojan Vafai, Brett Zamir, and Boris Zbarsky
 for their feedback, participation, or other helpful contributions

::: header-wrapper
## B. References

::: header-wrapper
### B.1 Normative references

\[css-writing-modes-4\]
: [CSS Writing Modes Level
 4](https://www.w3.org/TR/css-writing-modes-4/). Elika Etemad; Koji
 Ishii. W3C. 30 July 2019. W3C Candidate Recommendation. URL:
 <https://www.w3.org/TR/css-writing-modes-4/>

\[dom\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[url\]
: [URL Standard](https://url.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://url.spec.whatwg.org/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

[[↑]](#title)

[Permalink](#dfn-selection)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-selection-1 "§ 2. Definition")
 [(2)](#ref-for-dfn-selection-2 "Reference 2")
 [(3)](#ref-for-dfn-selection-3 "Reference 3")
 [(4)](#ref-for-dfn-selection-4 "Reference 4")
 [(5)](#ref-for-dfn-selection-5 "Reference 5")
 [(6)](#ref-for-dfn-selection-6 "Reference 6")
 [(7)](#ref-for-dfn-selection-7 "Reference 7")
 [(8)](#ref-for-dfn-selection-8 "Reference 8")
 [(9)](#ref-for-dfn-selection-9 "Reference 9")
 [(10)](#ref-for-dfn-selection-10 "Reference 10")
 [(11)](#ref-for-dfn-selection-11 "Reference 11")
 [(12)](#ref-for-dfn-selection-12 "Reference 12")
 [(13)](#ref-for-dfn-selection-13 "Reference 13")
 [(14)](#ref-for-dfn-selection-14 "Reference 14")
 [(15)](#ref-for-dfn-selection-15 "Reference 15")
 [(16)](#ref-for-dfn-selection-16 "Reference 16")
 [(17)](#ref-for-dfn-selection-17 "Reference 17")
 [(18)](#ref-for-dfn-selection-18 "Reference 18")
 [(19)](#ref-for-dfn-selection-19 "Reference 19")
- [§ 3. Selection
 interface](#ref-for-dfn-selection-20 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-selection-21 "Reference 2")
 [(3)](#ref-for-dfn-selection-22 "Reference 3")
 [(4)](#ref-for-dfn-selection-23 "Reference 4")
 [(5)](#ref-for-dfn-selection-24 "Reference 5")
 [(6)](#ref-for-dfn-selection-25 "Reference 6")
 [(7)](#ref-for-dfn-selection-26 "Reference 7")
 [(8)](#ref-for-dfn-selection-27 "Reference 8")
 [(9)](#ref-for-dfn-selection-28 "Reference 9")
 [(10)](#ref-for-dfn-selection-29 "Reference 10")
 [(11)](#ref-for-dfn-selection-30 "Reference 11")
 [(12)](#ref-for-dfn-selection-31 "Reference 12")
- [§ 4.1 Extensions to Document
 interface](#ref-for-dfn-selection-32 "§ 4.1 Extensions to Document interface")
- [§ 5. Responding to DOM
 Mutations](#ref-for-dfn-selection-33 "§ 5. Responding to DOM Mutations")
 [(2)](#ref-for-dfn-selection-34 "Reference 2")
 [(3)](#ref-for-dfn-selection-35 "Reference 3")
 [(4)](#ref-for-dfn-selection-36 "Reference 4")
- [§ 6. User
 Interactions](#ref-for-dfn-selection-37 "§ 6. User Interactions")
 [(2)](#ref-for-dfn-selection-38 "Reference 2")
 [(3)](#ref-for-dfn-selection-39 "Reference 3")
 [(4)](#ref-for-dfn-selection-40 "Reference 4")
 [(5)](#ref-for-dfn-selection-41 "Reference 5")
- [§ 6.1 selectstart
 event](#ref-for-dfn-selection-42 "§ 6.1 selectstart event")
 [(2)](#ref-for-dfn-selection-43 "Reference 2")
 [(3)](#ref-for-dfn-selection-44 "Reference 3")
 [(4)](#ref-for-dfn-selection-45 "Reference 4")
- [§ 6.2 selectionchange
 event](#ref-for-dfn-selection-46 "§ 6.2 selectionchange event")
- [§ 8. Security and Privacy
 considerations](#ref-for-dfn-selection-47 "§ 8. Security and Privacy considerations")

[Permalink](#dfn-empty)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-empty-1 "§ 2. Definition")
- [§ 3. Selection
 interface](#ref-for-dfn-empty-2 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-empty-3 "Reference 2")
 [(3)](#ref-for-dfn-empty-4 "Reference 3")
 [(4)](#ref-for-dfn-empty-5 "Reference 4")
 [(5)](#ref-for-dfn-empty-6 "Reference 5")
 [(6)](#ref-for-dfn-empty-7 "Reference 6")
 [(7)](#ref-for-dfn-empty-8 "Reference 7")
 [(8)](#ref-for-dfn-empty-9 "Reference 8")
 [(9)](#ref-for-dfn-empty-10 "Reference 9")
 [(10)](#ref-for-dfn-empty-11 "Reference 10")
 [(11)](#ref-for-dfn-empty-12 "Reference 11")
 [(12)](#ref-for-dfn-empty-13 "Reference 12")
 [(13)](#ref-for-dfn-empty-14 "Reference 13")
- [§ 6. User
 Interactions](#ref-for-dfn-empty-15 "§ 6. User Interactions")
 [(2)](#ref-for-dfn-empty-16 "Reference 2")
- [§ 6.1 selectstart
 event](#ref-for-dfn-empty-17 "§ 6.1 selectstart event")
 [(2)](#ref-for-dfn-empty-18 "Reference 2")

[Permalink](#dfn-direction)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-direction-1 "§ 2. Definition")
 [(2)](#ref-for-dfn-direction-2 "Reference 2")
- [§ 3. Selection
 interface](#ref-for-dfn-direction-3 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-direction-4 "Reference 2")
 [(3)](#ref-for-dfn-direction-5 "Reference 3")
 [(4)](#ref-for-dfn-direction-6 "Reference 4")
- [§ 6. User
 Interactions](#ref-for-dfn-direction-7 "§ 6. User Interactions")
- [§ 6.2 selectionchange
 event](#ref-for-dfn-direction-8 "§ 6.2 selectionchange event")

[Permalink](#dfn-forwards)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-forwards-1 "§ 2. Definition")
 [(2)](#ref-for-dfn-forwards-2 "Reference 2")
- [§ 3. Selection
 interface](#ref-for-dfn-forwards-3 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-forwards-4 "Reference 2")
 [(3)](#ref-for-dfn-forwards-5 "Reference 3")
 [(4)](#ref-for-dfn-forwards-6 "Reference 4")
 [(5)](#ref-for-dfn-forwards-7 "Reference 5")
 [(6)](#ref-for-dfn-forwards-8 "Reference 6")
- [§ 6. User
 Interactions](#ref-for-dfn-forwards-9 "§ 6. User Interactions")

[Permalink](#dfn-backwards)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-backwards-1 "§ 2. Definition")
- [§ 3. Selection
 interface](#ref-for-dfn-backwards-2 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-backwards-3 "Reference 2")
 [(3)](#ref-for-dfn-backwards-4 "Reference 3")
 [(4)](#ref-for-dfn-backwards-5 "Reference 4")
- [§ 6. User
 Interactions](#ref-for-dfn-backwards-6 "§ 6. User Interactions")

[Permalink](#dfn-directionless)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-directionless-1 "§ 2. Definition")
- [§ 3. Selection
 interface](#ref-for-dfn-directionless-2 "§ 3. Selection interface")
- [§ 6. User
 Interactions](#ref-for-dfn-directionless-3 "§ 6. User Interactions")

[Permalink](#dfn-anchor)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-anchor-1 "§ 2. Definition")
 [(2)](#ref-for-dfn-anchor-2 "Reference 2")
 [(3)](#ref-for-dfn-anchor-3 "Reference 3")
 [(4)](#ref-for-dfn-anchor-4 "Reference 4")
- [§ 3. Selection
 interface](#ref-for-dfn-anchor-5 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-anchor-6 "Reference 2")
 [(3)](#ref-for-dfn-anchor-7 "Reference 3")
 [(4)](#ref-for-dfn-anchor-8 "Reference 4")
 [(5)](#ref-for-dfn-anchor-9 "Reference 5")
 [(6)](#ref-for-dfn-anchor-10 "Reference 6")
 [(7)](#ref-for-dfn-anchor-11 "Reference 7")
 [(8)](#ref-for-dfn-anchor-12 "Reference 8")
 [(9)](#ref-for-dfn-anchor-13 "Reference 9")
 [(10)](#ref-for-dfn-anchor-14 "Reference 10")
 [(11)](#ref-for-dfn-anchor-15 "Reference 11")
 [(12)](#ref-for-dfn-anchor-16 "Reference 12")

[Permalink](#dfn-focus)

**Referenced in:**

- [§ 2. Definition](#ref-for-dfn-focus-1 "§ 2. Definition")
 [(2)](#ref-for-dfn-focus-2 "Reference 2")
 [(3)](#ref-for-dfn-focus-3 "Reference 3")
 [(4)](#ref-for-dfn-focus-4 "Reference 4")
- [§ 3. Selection
 interface](#ref-for-dfn-focus-5 "§ 3. Selection interface")
 [(2)](#ref-for-dfn-focus-6 "Reference 2")
 [(3)](#ref-for-dfn-focus-7 "Reference 3")
 [(4)](#ref-for-dfn-focus-8 "Reference 4")
 [(5)](#ref-for-dfn-focus-9 "Reference 5")
 [(6)](#ref-for-dfn-focus-10 "Reference 6")
 [(7)](#ref-for-dfn-focus-11 "Reference 7")
 [(8)](#ref-for-dfn-focus-12 "Reference 8")
 [(9)](#ref-for-dfn-focus-13 "Reference 9")
 [(10)](#ref-for-dfn-focus-14 "Reference 10")
 [(11)](#ref-for-dfn-focus-15 "Reference 11")
 [(12)](#ref-for-dfn-focus-16 "Reference 12")
 [(13)](#ref-for-dfn-focus-17 "Reference 13")
 [(14)](#ref-for-dfn-focus-18 "Reference 14")
 [(15)](#ref-for-dfn-focus-19 "Reference 15")

[Permalink](#dfn-has-scheduled-selectionchange-event)

**Referenced in:**

- [§ 6.2.1 Scheduling selectionchange
 event](#ref-for-dfn-has-scheduled-selectionchange-event-1 "§ 6.2.1 Scheduling selectionchange event")
- [§ 6.2.2 Firing selectionchange
 event](#ref-for-dfn-has-scheduled-selectionchange-event-2 "§ 6.2.2 Firing selectionchange event")

[Permalink](#dom-selection)
[exported]

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-1 "§ 3. Selection interface")
- [§ 4.1 Extensions to Document
 interface](#ref-for-dom-selection-2 "§ 4.1 Extensions to Document interface")
- [§ 4.2 Extensions to Window
 interface](#ref-for-dom-selection-3 "§ 4.2 Extensions to Window interface")

[Permalink](#dom-getcomposedrangesoptions)
[exported]

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-getcomposedrangesoptions-1 "§ 3. Selection interface")

[Permalink](#dom-getcomposedrangesoptions-shadowroots)
[exported]

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-getcomposedrangesoptions-shadowroots-1 "§ 3. Selection interface")
 [(2)](#ref-for-dom-getcomposedrangesoptions-shadowroots-2 "Reference 2")

[Permalink](#dom-selection-anchornode)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-anchornode-1 "§ 3. Selection interface")

[Permalink](#dom-selection-anchoroffset)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-anchoroffset-1 "§ 3. Selection interface")

[Permalink](#dom-selection-focusnode)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-focusnode-1 "§ 3. Selection interface")

[Permalink](#dom-selection-focusoffset)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-focusoffset-1 "§ 3. Selection interface")

[Permalink](#dom-selection-iscollapsed)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-iscollapsed-1 "§ 3. Selection interface")

[Permalink](#dom-selection-rangecount)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-rangecount-1 "§ 3. Selection interface")

[Permalink](#dom-selection-type)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-type-1 "§ 3. Selection interface")

[Permalink](#dom-selection-direction)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-direction-1 "§ 3. Selection interface")

[Permalink](#dom-selection-getrangeat)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-getrangeat-1 "§ 3. Selection interface")

[Permalink](#dom-selection-addrange)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 2. Definition](#ref-for-dom-selection-addrange-1 "§ 2. Definition")
- [§ 3. Selection
 interface](#ref-for-dom-selection-addrange-2 "§ 3. Selection interface")

[Permalink](#dom-selection-removerange)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-removerange-1 "§ 3. Selection interface")

[Permalink](#dom-selection-removeallranges)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-removeallranges-1 "§ 3. Selection interface")

[Permalink](#dom-selection-empty)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-empty-1 "§ 3. Selection interface")

[Permalink](#dom-selection-getcomposedranges)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-getcomposedranges-1 "§ 3. Selection interface")

[Permalink](#dom-selection-collapse)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-collapse-1 "§ 3. Selection interface")

[Permalink](#dom-selection-setposition)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-setposition-1 "§ 3. Selection interface")

[Permalink](#dom-selection-collapsetostart)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-collapsetostart-1 "§ 3. Selection interface")

[Permalink](#dom-selection-collapsetoend)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-collapsetoend-1 "§ 3. Selection interface")

[Permalink](#dom-selection-extend)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-extend-1 "§ 3. Selection interface")

[Permalink](#dom-selection-setbaseandextent)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-setbaseandextent-1 "§ 3. Selection interface")

[Permalink](#dom-selection-selectallchildren)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-selectallchildren-1 "§ 3. Selection interface")

[Permalink](#dom-selection-modify)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-modify-1 "§ 3. Selection interface")

[Permalink](#dom-selection-deletefromdocument)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-deletefromdocument-1 "§ 3. Selection interface")

[Permalink](#dom-selection-containsnode)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-containsnode-1 "§ 3. Selection interface")

[Permalink](#dom-selection-stringifier)
[exported]
[IDL](#webidl-1987235205 "Jump to IDL declaration")

**Referenced in:**

- [§ 3. Selection
 interface](#ref-for-dom-selection-stringifier-1 "§ 3. Selection interface")

[Permalink](#dom-document-getselection)
[exported]
[IDL](#webidl-313315997 "Jump to IDL declaration")

**Referenced in:**

- [§ 4.1 Extensions to Document
 interface](#ref-for-dom-document-getselection-1 "§ 4.1 Extensions to Document interface")
- [§ 4.2 Extensions to Window
 interface](#ref-for-dom-document-getselection-2 "§ 4.2 Extensions to Window interface")

[Permalink](#dom-window-getselection)
[exported]
[IDL](#webidl-1016100280 "Jump to IDL declaration")

**Referenced in:**

- [§ 4.2 Extensions to Window
 interface](#ref-for-dom-window-getselection-1 "§ 4.2 Extensions to Window interface")

[Permalink](#dom-globaleventhandlers-onselectstart)
[exported]
[IDL](#webidl-1185742786 "Jump to IDL declaration")

**Referenced in:**

- [§ 4.3 Extensions to GlobalEventHandlers
 interface](#ref-for-dom-globaleventhandlers-onselectstart-1 "§ 4.3 Extensions to GlobalEventHandlers interface")

[Permalink](#dom-globaleventhandlers-onselectionchange)
[exported]
[IDL](#webidl-1185742786 "Jump to IDL declaration")

**Referenced in:**

- [§ 4.3 Extensions to GlobalEventHandlers
 interface](#ref-for-dom-globaleventhandlers-onselectionchange-1 "§ 4.3 Extensions to GlobalEventHandlers interface")

[Permalink](#dfn-selectstart)

**Referenced in:**

- [§ 4.3 Extensions to GlobalEventHandlers
 interface](#ref-for-dfn-selectstart-1 "§ 4.3 Extensions to GlobalEventHandlers interface")
- [§ 8. Security and Privacy
 considerations](#ref-for-dfn-selectstart-2 "§ 8. Security and Privacy considerations")

[Permalink](#dfn-selectionchange)

**Referenced in:**

- [§ 4.3 Extensions to GlobalEventHandlers
 interface](#ref-for-dfn-selectionchange-1 "§ 4.3 Extensions to GlobalEventHandlers interface")
- [§ 8. Security and Privacy
 considerations](#ref-for-dfn-selectionchange-2 "§ 8. Security and Privacy considerations")

[Permalink](#dfn-schedule-a-selectionchange-event)

**Referenced in:**

- [§ 6.2 selectionchange
 event](#ref-for-dfn-schedule-a-selectionchange-event-1 "§ 6.2 selectionchange event")
 [(2)](#ref-for-dfn-schedule-a-selectionchange-event-2 "Reference 2")

[Permalink](#dfn-fire-a-selectionchange-event)

**Referenced in:**

- [§ 6.2.1 Scheduling selectionchange
 event](#ref-for-dfn-fire-a-selectionchange-event-1 "§ 6.2.1 Scheduling selectionchange event")
