
This document is a preliminary draft of a specification for the
Selection API and selection related functionality. It replaces a couple
of old sections of the [HTML
specification](https://www.w3.org/TR/html5/), the selection part of the
old [DOM Range
specification](https://www.w3.org/TR/2000/REC-DOM-Level-2-Traversal-Range-20001113/ranges.html).

This document defines APIs for selection, which allows users and authors
to select a portion of a document or specify a point of interest for
copy, paste, and other editing operations.

This is work in progress.

## Background

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
selection from containing a range that had a boundary point other than
an Element or Text node, or a boundary point that didn\'t descend from a
Document.

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

## Definition

Every document with a \[=Document/browsing context=\] has a unique
[selection] associated with it.

This is a requirement of the HTML spec. IE9 and Opera Next 12.00 alpha
seem to follow it, while Firefox 12.0a1 and Chrome 17 dev seem not to.
See [Mozilla bug](https://bugzilla.mozilla.org/show_bug.cgi?id=717339),
[WebKit bug](https://bugs.webkit.org/show_bug.cgi?id=76114).

This one selection must be shared by all the content of the document
(though not by nested documents), including any \[=editing hosts=\] in
the document.

Each selection can be associated with a single range. When there is no
range associated with the selection, the selection is [empty]. The
selection must be initially empty.

A document\'s selection is a singleton object associated with that
document, so it gets replaced with a new object when `Document.open()`
is called. See [bug
15470](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15470). IE9 and
Opera Next 12.00 alpha allow the user to reset the range to null after
the fact by clicking somewhere; Firefox 12.0a1 and Chrome 17 dev do not.
We follow Gecko/WebKit, because it lessens the chance of getRangeAt(0)
throwing.

Once a selection is associated with a given range, it must continue to
be associated with that same range until this specification requires
otherwise.

For instance, if the DOM changes in a way that changes the range\'s
boundary points, or a script modifies the boundary points of the range,
the same range object must continue to be associated with the selection.
However, if the user changes the selection or a script calls
{{addRange()}}, the selection must be associated with a new range
object, as required elsewhere in this specification.

If the selection\'s range is not null and is \[=range/collapsed=\], then
the caret position must be at that range\'s boundary point. When the
selection is not \[=range/collapsed=\], this specification does not
define the caret position; user agents should follow platform
conventions in deciding whether the caret is at the start of the
selection, the end of the selection, or somewhere else.

Each selection has a [direction]: [forwards],
[backwards], or [directionless]. If the user creates a
selection by indicating first one boundary point of the range and then
the other (such as by clicking on one point and dragging to another),
and the first indicated boundary point is \[=boundary point/after=\] the
second, then the corresponding selection must initially be backwards. If
the first indicated boundary point is \[=boundary point/before=\] the
second, then the corresponding selection must initially be forwards.
Otherwise, it must be directionless.

When the selection\'s range is mutated by scripts, e.g. via
{{Range/selectNode(node)}}, direction of the selection must be
preserved.

Each selections also have an [anchor] and a [focus]. If the
selection\'s range is null, its anchor and focus are both null. If the
selection\'s range is not null and its direction is forwards, its anchor
is the range\'s \[=range/start=\], and its focus is the \[=range/end=\].
Otherwise, its focus is the \[=range/start=\] and its anchor is the
\[=range/end=\].

anchor and focus of selection need not to be in the \[=document tree=\].
It could be in a \[=shadow tree=\] of the same \[=document=\].

Each document, input element, and textarea element has a boolean [has
scheduled selectionchange event], which is initially false.

## Selection interface

Selection interface provides a way to interact with the selection
associated with each document.

``` idl

 [Exposed=Window]
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

[anchorNode]

: The attribute must return the anchor \[=boundary point/node=\] of
 \[=this=\], or \`null\` if the anchor is null or anchor is not in
 the \[=document tree=\].

[anchorOffset]

: The attribute must return the anchor \[=boundary point/offset=\] of
 \[=this=\], or `0` if the anchor is null or anchor is not in the
 \[=document tree=\].

[focusNode]

: The attribute must return the focus \[=boundary point/node=\] of
 \[=this=\], or \`null\` if the focus is null or focus is not in the
 \[=document tree=\].

[focusOffset]

: The attribute must return the focus \[=boundary point/offset=\] of
 \[=this=\], or `0` if the focus is null or focus is not in the
 \[=document tree=\].

[isCollapsed]

: The attribute must return true if and only if the anchor and focus
 are the same (including if both are null). Otherwise it must return
 false.

[rangeCount]

: The attribute must return `0` if \[=this=\] is empty or either focus
 or anchor is not in the \[=document tree=\], and must return `1`
 otherwise.

[type]

: The attribute must return \`\"None\"\` if \[=this=\] is empty or
 either focus or anchor is not in the \[=document tree=\],
 \`\"Caret\"\` if \[=this=\]\'s range is \[=range/collapsed=\], and
 \`\"Range\"\` otherwise.

[direction]

: The attribute must return \`\"none\"\` if \[=this=\] is empty or
 this selection is directionless. \`\"forward\"\` if this
 selection\'s direction is forwards and \`\"backward\"\` if this
 selection\'s direction is backwards.

[getRangeAt()] method

: The method must throw an {{IndexSizeError}} exception if
 `index` is not `0`, or if \[=this=\] is empty or either
 focus or anchor is not in the \[=document tree=\]. Otherwise, it
 must return a reference to (not a copy of) \[=this=\]\'s range.

 Thus subsequent calls of this method returns the same range object
 if nothing has removed \[=this=\]\'s range in the meantime. In
 particular,
 `getSelection().getRangeAt(0) === getSelection().getRangeAt(0)`
 evaluates to `true` if the selection is not empty.

[addRange()] method

: The method must follow these steps:

 1. If the \[=tree/root=\] of the `range`\'s boundary
 points are not the document associated with \[=this=\], abort
 these steps.
 2. If `rangeCount` is not `0`, abort these steps.
 3. Set \[=this=\]\'s range to `range` by a strong
 reference (not by making a copy).

 Since range is added by reference, subsequent calls to
 `getRangeAt(0)` returns the same object, and any changes that a
 script makes to range after it is added must be reflected in the
 selection, until something else removes or replaces \[=this=\]\'s
 range. In particular, the selection will contain `b` as
 opposed to `a` after running the following code:
 `var r = document.createRange(); r.selectNode(a); getSelection().addRange(r); r.selectNode(b);`

 ::: note
 At Step 2, Chrome 58 and Edge 25 do nothing. Firefox 51 gives you a
 multi-range selection. At least they keep the exisiting range.

 At Step 3, Chrome 58 and Firefox 51 store a reference, as described
 here. Edge 25 stores a copy. Firefox 51 changes its selection if the
 range is modified.
 :::

[removeRange()] method

: The method must make \[=this=\] empty by disassociating its range if
 \[=this=\]\'s range is `range`. Otherwise, it must throw
 a {{NotFoundError}}.

[removeAllRanges()] method

: The method must make \[=this=\] empty by disassociating its range if
 \[=this=\] has an associated range.

[empty()] method

: The method must be an alias, and behave identically, to
 `removeAllRanges()`.

[getComposedRanges()] method

: 1. If \[=this=\] is empty, return an empty array.
 2. Otherwise, let `startNode` be \[=range/start node=\]
 of the \[=range=\] associated with \[=this=\], and let
 `startOffset` be \[=range/start offset=\] of the
 \[=range=\].
 3. While `startNode` is a \[=node=\],
 `startNode`\'s \[=tree/root=\] is a \[=shadow
 root=\], and `startNode`\'s \[=tree/root=\] is not a
 \[=shadow-including inclusive ancestor=\] of any of
 `options`\[\"{{GetComposedRangesOptions/shadowRoots}}\"\],
 repeat these steps:
 1. Set `startOffset` to \[=tree/index=\] of
 `startNode`\'s \[=tree/root=\]\'s \[=host=\].
 2. Set `startNode` to `startNode`\'s
 \[=tree/root=\]\'s \[=host=\]\'s \[=tree/parent=\].
 4. Let `endNode` be \[=range/end node=\] of the
 \[=range=\] associated with \[=this=\], and let
 `endOffset` be \[=range/end offset=\] of the
 \[=range=\].
 5. While `endNode` is a \[=node=\],
 `endNode`\'s \[=tree/root=\] is a \[=shadow root=\],
 and `endNode`\'s \[=tree/root=\] is not a
 \[=shadow-including inclusive ancestor=\] of any of
 `options`\[\"{{GetComposedRangesOptions/shadowRoots}}\"\],
 repeat these steps:
 1. Set `endOffset` to \[=tree/index=\] of
 `endNode`\'s \[=tree/root=\]\'s \[=host=\] plus
 1.
 2. Set `endNode` to `endNode`\'s
 \[=tree/root=\]\'s \[=host=\]\'s \[=tree/parent=\].
 6. Return an array consisting of new {{StaticRange}} whose
 \[=range/start node=\] is `startNode`, \[=range/start
 offset=\] is `startOffset`, \[=range/end node=\] is
 `endNode`, and \[=range/end offset=\] is
 `endOffset`.

[collapse()] method

: The method must follow these steps:

 1. If `node` is null, this method must behave
 identically as `removeAllRanges()` and abort these steps.
 2. If `node` is a {{DocumentType}}, throw an
 {{InvalidNodeTypeError}} exception and abort these steps.
 3. The method must throw an {{IndexSizeError}} exception if
 ` offset` is longer than `node`\'s
 \[=Node/length=\] and abort these steps.
 4. If document associated with \[=this=\] is not a
 \[=shadow-including inclusive ancestor=\] of `node`,
 abort these steps.
 5. Otherwise, let `newRange` be a new range.
 6. \[=Range/Set the start=\] the \[=range/start=\] and the
 \[=range/end=\] of `newRange` to (`node`,
 `offset`).
 7. Set \[=this=\]\'s range to `newRange`.

[setPosition()] method

: The method must be an alias, and behave identically, to
 `collapse()`.

[collapseToStart()] method

: The method must throw {{InvalidStateError}} exception if the
 \[=this=\] is empty. Otherwise, it must create a new range,
 \[=Range/set the start=\] both its \[=range/start=\] and
 \[=range/end=\] to the \[=range/start=\] of \[=this=\]\'s range, and
 then set \[=this=\]\'s range to the newly-created range.

 For collapseToStart/End, IE9 mutates the existing range, while
 Firefox 9.0a2 and Chrome 15 dev replace it with a new one. The spec
 follows the majority and replaces it with a new one, leaving the old
 Range object unchanged.

[collapseToEnd()] method

: The method must throw {{InvalidStateError}} exception if the
 \[=this=\] is empty. Otherwise, it must create a new range,
 \[=Range/set the start=\] both its \[=range/start=\] and
 \[=range/end=\] to the \[=range/end=\] of \[=this=\]\'s range, and
 then set \[=this=\]\'s range to the newly-created range.

[extend()] method

: The method must follow these steps:

 1. If the document associated with \[=this=\] is not a
 \[=shadow-including inclusive ancestor=\] of `node`,
 abort these steps.
 2. If \[=this=\] is empty, throw an {{InvalidStateError}} exception
 and abort these steps.
 3. Let `oldAnchor` and `oldFocus` be the
 \[=this=\]\'s anchor and focus, and let `newFocus` be
 the boundary point (`node`, `offset`).
 4. Let `newRange` be a new range.
 5. If `node`\'s \[=tree/root=\] is not the same as the
 \[=this=\]\'s range\'s \[=tree/root=\], \[=Range/set the
 start=\] `newRange`\'s \[=range/start=\] and
 \[=range/end=\] to `newFocus`.
 6. Otherwise, if `oldAnchor` is \[=boundary
 point/before=\] or equal to `newFocus`, \[=Range/set
 the start=\] `newRange`\'s \[=range/start=\] to
 `oldAnchor`, then set its \[=range/end=\] to
 `newFocus`.
 7. Otherwise, \[=Range/set the start=\] `newRange`\'s
 \[=range/start=\] to `newFocus`, then set its
 \[=range/end=\] to `oldAnchor`.
 8. Set \[=this=\]\'s range to `newRange`.
 9. If `newFocus` is \[=boundary point/before=\]
 `oldAnchor`, set \[=this=\]\'s direction to
 backwards. Otherwise, set it to forwards.

 Reverse-engineered circa January 2011. IE doesn\'t support it, so
 I\'m relying on Firefox (implemented extend() sometime before 2000)
 and WebKit (implemented extend() in 2007). I\'m mostly ignoring
 Opera, because gsnedders tells me its implementation isn\'t
 compatible. Firefox 12.0a1 seems to mutate the existing range. IE9
 doesn\'t support extend(), and it\'s impossible to tell whether
 Chrome 17 dev or Opera Next 12.00 alpha mutate or replace, because
 getRangeAt() returns a copy anyway. Nevertheless, I go against Gecko
 here, to be consistent with collapse().

[setBaseAndExtent()] method

: The method must follow these steps:

 1. If `anchorOffset` is longer than
 `anchorNode`\'s \[=Node/length=\] or if
 `focusOffset` is longer than
 `focusNode`\'s \[=Node/length=\], throw an
 {{IndexSizeError}} exception and abort these steps.
 2. If document associated with \[=this=\] is not a
 \[=shadow-including inclusive ancestor=\] of
 `anchorNode` or `focusNode`, abort these
 steps.
 3. Let `anchor` be the boundary point
 (`anchorNode`, `anchorOffset`) and let
 `focus` be the boundary point
 (`focusNode`, `focusOffset`).
 4. Let `newRange` be a new range.
 5. If `anchor` is \[=boundary point/before=\]
 `focus`, \[=Range/set the start=\] the
 `newRange`\'s \[=range/start=\] to
 `anchor` and its \[=range/end=\] to
 ` focus`. Otherwise, \[=Range/set the start=\] them
 to `focus` and `anchor` respectively.
 6. Set \[=this=\]\'s range to `newRange`.
 7. If `focus` is \[=boundary point/before=\]
 `anchor`, set \[=this=\]\'s direction to backwards.
 Otherwise, set it to forwards

[selectAllChildren()] method

: The method must follow these steps:

 1. If `node` is a {{DocumentType}}, throw an
 {{InvalidNodeTypeError}} exception and abort these steps.
 2. If `node`\'s \[=tree/root=\] is not the document
 associated with \[=this=\], abort these steps.
 3. Let `newRange` be a new range and
 `childCount` be the number of \[=tree/children=\] of
 `node`.
 4. Set `newRange`\'s \[=range/start=\] to
 (`node`, `0`).
 5. Set `newRange`\'s \[=range/end=\] to
 (`node`, `childCount`).
 6. Set \[=this=\]\'s range to `newRange`.
 7. Set \[=this=\]\'s direction to `forwards`.

 ::: note
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

[modify()] method

: The method must follow these steps:

 1. If `alter` is not ASCII case-insensitive match with
 \"extend\" or \"move\", abort these steps.
 2. If `direction` is not ASCII case-insensitive match
 with \"forward\", \"backward\", \"left\", or \"right\", abort
 these steps.
 3. If `granularity` is not ASCII case-insensitive match
 with \"character\", \"word\", \"sentence\", \"line\",
 \"paragraph\", \"lineboundary\", \"sentenceboundary\",
 \"paragraphboundary\", \"documentboundary\", abort these steps.
 4. If this selection is empty, abort these steps.
 5. Let `effectiveDirection` be backwards.
 6. If `direction` is ASCII case-insensitive match with
 \"forward\", set `effectiveDirection` to forwards.
 7. If `direction` is ASCII case-insensitive match with
 \"right\" and the resolved text direction at this selection\'s
 focus is [ltr]{xref-type="css-value" xref-for="direction"}, set
 `effectiveDirection` to forwards.
 8. If `direction` is ASCII case-insensitive match with
 \"left\" and the resolved text direction at this selection\'s
 focus is [rtl]{xref-type="css-value" xref-for="direction"}, set
 `effectiveDirection` to forwards.
 9. Set this selection\'s direction to
 `effectiveDirection`.
 10. If `alter` is ASCII case-insensitive match with
 \"extend\", set this selection\'s focus to the location as if
 the user had requested to extend selection by
 ` granularity`.
 11. Otherwise, set this selection\'s focus and anchor to the
 location as if the user had requested to move selection by
 `granularity`.

 The [resolved text direction] at a boundary point is
 [ltr]{xref-type="css-value" xref-for="direction"} if the [embedding
 direction](https://www.unicode.org/reports/tr9/#BD3) (\[\[!UAX9\]\]
 BD3) of the character at that position is L, and
 [rtl]{xref-type="css-value" xref-for="direction"} if the [embedding
 direction](https://www.unicode.org/reports/tr9/#BD3) is R.

 At a bidi boundary---where adjacent characters have different
 embedding directions---user agents may use additional context (such
 as caret affinity based on the direction of cursor movement) to
 determine which character\'s embedding direction to use.

 We need to more precisely define what it means to extend or move
 selection by each granularity.

[deleteFromDocument()] method

: The method must invoke {{Range/deleteContents()}} on \[=this=\]\'s
 range if \[=this=\] is not empty and both focus and anchor are in
 the \[=document tree=\]. Otherwise the method must do nothing.

 This is the one method that actually mutates the range instead of
 replacing it. This matches IE9 and Firefox 12.0a1. (Chrome 17 dev
 and Opera Next 12.00 alpha can\'t be tested, because getRangeAt()
 returns a copy anyway.)

[containsNode()] method

: The method must return `false` if \[=this=\] is empty or if
 `node`\'s \[=tree/root=\] is not the document associated
 with \[=this=\].

 Otherwise, if `allowPartialContainment` is `false`, the
 method must return `true` if and only if \[=range/start=\] of its
 range is \[=boundary point/before=\] or visually equivalent to the
 first boundary point in the `node` **and**
 \[=range/end=\] of its range is \[=boundary point/after=\] or
 visually equivalent to the last boundary point in the
 `node`.

 If `allowPartialContainment` is `true`, the method must
 return `true` if and only if \[=range/start=\] of its range is
 \[=boundary point/before=\] or visually equivalent to the last
 boundary point in the `node` **and** \[=range/end=\] of
 its range is \[=boundary point/after=\] or visually equivalent to
 the first boundary point in the `node`.

[stringifier]

: The stringification must return the string, which is the
 concatenation of the rendered text if there is a \[=range=\]
 associated with \[=this=\].

 If the selection is within a textarea or input element, it must
 return the selected substring in its value.

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

All of the members of the {{Selection}} interface are defined in terms
of operations on the `range` object (if any) represented by the object.
These operations can raise exceptions, as defined for the {{Range}}
interface; this can therefore result in the members of the Selection
interface raising exceptions as well, in addition to any explicitly
called out above.

## Extensions to Other Interfaces

This specification extends several interfaces to provide entry points to
the interfaces defined in this specification.

### Extensions to `Document` interface

The [`Document`] interface is defined in
\[\[HTML\]\].

```

 partial interface Document {
 Selection? getSelection();
 };

```

[getSelection()] method

: The method must return the selection associated with \[=this=\] if
 \[=this=\] has an associated \[=Document/browsing context=\], and it
 must return \`null\` otherwise.

### Extensions to \`Window\` interface

The [`Window`]
interface is defined in \[\[HTML\]\].

``` idl

 partial interface Window {
 Selection? getSelection();
 };

```

[getSelection()] method

: The method must invoke and return the result of
 {{Document/getSelection()}} on \[=this=\]\'s {{Window.document}}
 attribute.

### Extensions to \`GlobalEventHandlers\` interface

The [`GlobalEventHandlers`] interface is
defined in \[\[HTML\]\].

``` idl

 partial interface mixin GlobalEventHandlers {
 attribute EventHandler onselectstart;
 attribute EventHandler onselectionchange;
 };

```

[onselectstart]

: The attribute must be an event handler IDL attribute for the
 selectstart event supported by all HTML elements, {{Document}}
 objects, and {{Window}} objects.

[onselectionchange]

: The attribute must be an event handler IDL attribute for the
 selectionchange event supported by all HTML elements, {{Document}}
 objects, and {{Window}} objects.

## Responding to DOM Mutations

When the user agent is to \[=replace data=\] or
\[=CharacterData/substring data=\] on {{CharacterData}}, the user agent
must update the range associated with selection of the \[=Node/node
document=\] of the {{CharacterData}} as if it\'s a live range.

When the user agent is to split a {{Text}} \[=node=\], the user agent
must update the range associated with selection of the \[=Node/node
document=\] of the {{Text}} as if it\'s a live range.

When the user agent is to run steps for `normalize()` method, the user
agent must update the range associated with selection of the
\[=Node/node document=\] of \[=this=\] as if it\'s a live range.

When the user agent is to \[=remove=\] or \[=insert=\] a \[=node=\], the
user agent must update the range associated with selection of the
\[=Node/node document=\] of the \[=node=\] as if it\'s a live range.

## User Interactions

The user agent should allow the user to change the selection associated
with the \[=navigable/active document=\]. If the user makes any
modification to a selection, the user agent must create a new range with
suitable \[=range/start=\] and \[=range/end=\] of the range and
associate the selection with this new range (not modify the existing
range), and set update selection\'s direction to forwards if the
\[=range/start=\] is \[=boundary point/before=\] or equal to the
\[=range/end=\], backwards if if the \[=range/end=\] is \[=boundary
point/before=\] the \[=range/start=\], or directionless if the
\[=range/start=\] and the \[=range/end=\] cannot be ordered due to the
platform convention.

The user agent must not make a selection empty if it was not already
empty in response to any user actions (e.g. clicking on a non-editable
region).

See [bug 15470](https://www.w3.org/Bugs/Public/show_bug.cgi?id=15470).
IE9 and Opera Next 12.00 alpha allow the user to reset the range to null
after the fact by clicking somewhere; Firefox 12.0a1 and Chrome 17 dev
do not. I follow Gecko/WebKit, because it lessens the chance of
getRangeAt(0) throwing.

### [`selectstart`] event

When the user agent is about to associate a new range
`newRange` to the selection in response to a user initiated
action, the user agent must fire an event named `selectstart`, which
bubbles and is cancelable, at the \[=boundary point/node=\] associated
with the boundary point of `newRange`\'s \[=range/start=\]
prior to changing the selection if the selection was previously empty or
the previously associated range was \[=range/collapsed=\].

If the event is canceled, the user agent must not change the selection.

The user agent must not fire an event when the user agent sets the
selection empty.

### [`selectionchange`] event

When the selection is dissociated with its range, associated with a new
range, or the associated range\'s boundary point is mutated either by
the user or the content script, the user agent must schedule a
selectionchange event on document.

When an \[\^input\^\] or \[\^textarea\^\] element provide a text
selection and its selection changes (in either extent or
\[=direction=\]), the user agent must schedule a selectionchange event
on the element.

#### Scheduling `selectionchange` event

To [schedule a selectionchange event] on a node
`target`, run these steps:

1. If `target`\'s has scheduled selectionchange event is
 true, abort these steps.
2. Set `target`\'s has scheduled selectionchange event to
 true.
3. Queue a task on the user interaction task source to fire a
 selectionchange event on `target`.

#### Firing `selectionchange` event

To [fire a selectionchange event] on a node `target`,
run these steps:

1. Set `target`\'s has scheduled selectionchange event to
 false.
2. If `target` is an element, fire an event named
 `selectionchange`, which bubbles and not cancelable, at
 `target`.
3. Otherwise, if `target` is a document, fire an event named
 `selectionchange`, which does not bubble and not cancelable, at
 `target`.

This specification defines conformance criteria that apply to a single
product: the user agent that implements the interfaces that it contains.

## Security and Privacy considerations

There are no known security considerations for this standard.

To mitigate potential privacy risks of exposing user\'s use of assistive
technologies, for example, user agent may elect to emulate mouse and
keyboard events typically associated with selectstart or selectionchange
events when the user opts to modify the selection of a document.

## Acknowledgements

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
