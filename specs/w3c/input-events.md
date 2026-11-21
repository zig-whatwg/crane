
This specification defines additions to events for text and related
input to allow for the monitoring and manipulation of default browser
behavior in the context of text editor applications and other
applications that deal with text input and text formatting. This
specification builds on the UI events spec \[\[UI-EVENTS\]\].

Input Events Level 2 replaces the first version of Input Events
\[\[INPUT-EVENTS\]\] and includes:

- Inputtypes for beforeinput events for the start and end of IME
 compositions that allow isolation of the IME composition process.
- More requirements for cancelability of beforeinput events, so that all
 beforeinput events apart from those being emited within an IME
 composition process are cancelable.

The [test
suite](https://github.com/web-platform-tests/wpt/tree/master/input-events)
and [implementation
reports](https://w3c.github.io/test-results/input-events/) for the Input
Events specification are still work in progress.

## Introduction

This document describes editing related additions to 2 events -
[input](https://w3c.github.io/uievents/#event-type-input) and
[beforeinput](https://w3c.github.io/uievents/#beforeinput) which are
described in the UI events spec \[\[UI-EVENTS\]\]. The goal of these
events is to allow authors to understand and/or override default edit
behavior both before and after editing occurs.

## Definitions

[express intention]
: A user can [express an intention] to execute
 a specific editing operation by means of keyboard, IME, speech, or
 similar method. Specific input actions are mapped to intentions
 following platform-specific conventions.

[kill buffer]

: *This definition is not normative.*

 A kill buffer is a in-memory store of richtext content that is
 separate from the clipboard which allows for the temporal storage of
 content that was deleted using specific deletion commands. The user
 can replace the current selection with the content held in the kill
 buffer by indicating an intention to yank the kill buffer.

## Problems solved

*This section is not normative.*

Creating a webbased texteditor requires a considerable amount of
JavaScript on top of the browser code, among other things because:

1. Browsers do not handle all editing operations the same way.
2. Browsers are often buggy in the way they handle certain editing
 operations.
3. Individual sites may have custom preferences for how they want to
 handle certain editing operations.
4. The development of high-level text editing features in browsers has
 not followed the principles laid out in the [Extensible Web
 Manifesto](https://extensiblewebmanifesto.org/) in that development
 of these features has not always been in coordination with the needs
 of the web developer community.

This spec seeks to alleviate the problem by providing a simple way for
web developers to both override browser handling of all user input
related to text editing through the beforeinput event, and to monitor
what browsers have changed in the DOM due to user input through the
input event.

## Use cases

*This section is not normative.*

1. Creating a JavaScript text editor in which the \<strong\>-tag is
 used instead of the \<b\>-tag to mark text that the user marks as
 bold, using any browser-builtin way to mark a text as bold, without
 having access to all existing browsers.
2. Creating a JavaScript text editor which works with a data model in
 the background where JavaScript takes care of rendering changes to
 the edited text to the DOM.
3. Creating a JavaScript editor which only allows a subset of richtext
 editing (for example: bold is allowed, but italic not).
4. Creating a collaborative editor in which JavaScript is used to
 render changes to the DOM, based on user intentions with users using
 different browsers with different ways of expressing specific
 intentions.
5. Creating a JavaScript editor with different user access options,
 where some users only can add or delete text and other users only
 can add or remove certain types of formatting.

### Input Event Types

Input events are sent before (beforeinput event) and after (input event)
a user attempts to edit the markup. This includes insertion and deletion
of content, and formatting changes.

Input events are \[=dispatched=\] on elements that act as \[=editing
hosts=\], including elements with the contenteditable attribute set,
\[\^textarea\^\] elements, and \[\^input\^\] elements that permit text
input.

#### Interface InputEvent

``` idl

 partial interface InputEvent {
 readonly attribute DataTransfer? dataTransfer;
 sequence<StaticRange> getTargetRanges();
 };

 partial dictionary InputEventInit {
 DataTransfer? dataTransfer = null;
 sequence<StaticRange> targetRanges = ;
 };

```

The attributes {{InputEvent/inputType}} and [dataTransfer] of
{{InputEventInit}} initialize the corresponding attributes of the
{{InputEvent}} object.

The [targetRanges] attribute of
{{InputEventInit}} initializes the \[=target ranges=\] of the
{{InputEvent}} object, which `getTargetRanges()` returns.

##### Overview

*This section is not normative.*

The following table provides a summary of when the data and dataTransfer
attributes contain contents and when they are null as well as when the
getTargetRanges() method returns an empty or non-empty Array, based on
the inputType.

 Editing host inputType data dataTransfer getTargetRanges()
 ------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------ -------------- -------------------
 Contenteditable `"insertText"`, `"insertCompositionText"`, `"formatSetBlockTextDirection"`, `"formatSetInlineTextDirection"`, `"formatBackColor"`, `"formatFontColor"`, `"formatFontName"`, `"insertLink"` Yes null Non-empty Array
 Contenteditable `"insertFromPaste"`, `"insertFromPasteAsQuotation"`, `"insertFromDrop"`, `"insertReplacementText"`, `"insertFromYank"` null Yes Non-empty Array
 `<textarea>`, `<input type="text">` `"insertText"`, `"insertCompositionText"`, `"insertFromPaste"`, `"insertFromPasteAsQuotation"`, `"insertFromDrop"`, `"insertReplacementText"`, `"insertFromYank"`, `"formatSetBlockTextDirection"`, `"formatSetInlineTextDirection"`, `"formatBackColor"`, `"formatFontColor"`, `"formatFontName"`, `"insertLink"` Yes null Empty Array
 All `"historyUndo"`, `"historyRedo"` null null Empty Array
 Contenteditable All Remaining null null Non-empty Array
 `<textarea>`, `<input type="text">` All Remaining null null Empty Array

##### Attributes

The cancelability of the beforeinput event depends on the inputType.

The inputType to be picked depends on the user\'s [expression of
intention], whether or not the editing takes
place during an IME composition and the state of the selection.

This specification defines the inputType values as the values in the
inputType column of the following table.

 inputType User\'s expression of intention Part of IME composition beforeinput cancelable State of selection
 ---------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------------- ------------------------ --------------------
 `"insertText"` insert typed plain text No Yes Any
 `"insertReplacementText"` insert or replace existing content by means of a spell checker, auto-correct, writing suggestions or similar No Yes Any
 `"insertLineBreak"` insert a line break No Yes Any
 `"insertParagraph"` insert a paragraph break No Yes Any
 `"insertOrderedList"` insert a numbered list No Yes Any
 `"insertUnorderedList"` insert a bulleted list No Yes Any
 `"insertHorizontalRule"` insert a horizontal rule No Yes Any
 `"insertFromYank"` replace the current selection with content stored in a kill buffer No Yes Any
 `"insertFromDrop"` insert content by means of drop No Yes Any
 `"insertFromPaste"` paste content from clipboard or paste image from client provided image library No Yes Any
 `"insertFromPasteAsQuotation"` paste content from the clipboard as a quotation No Yes Any
 `"insertTranspose"` transpose the last two \[=grapheme cluster=\]. that were entered No Yes Any
 `"insertCompositionText"` replace the current composition string Yes No Any
 `"insertLink"` insert a link No Yes Any
 `"deleteWordBackward"` delete a word directly before the caret position No Yes Collapsed
 `"deleteWordForward"` delete a word directly after the caret position No Yes Collapsed
 `"deleteSoftLineBackward"` delete from the caret to the nearest visual line break before the caret position No Yes Collapsed
 `"deleteSoftLineForward"` delete from the caret to the nearest visual line break after the caret position No Yes Collapsed
 `"deleteEntireSoftLine"` delete from the nearest visual line break before the caret position to the nearest visual line break after the caret position No Yes Collapsed
 `"deleteHardLineBackward"` delete from the caret to the nearest beginning of a block element or [`br`](https://html.spec.whatwg.org/#the-br-element) element before the caret position No Yes Collapsed
 `"deleteHardLineForward"` delete from the caret to the nearest end of a block element or [`br`](https://html.spec.whatwg.org/#the-br-element) element after the caret position No Yes Collapsed
 `"deleteByDrag"` remove content from the DOM by means of drag No Yes Any
 `"deleteByCut"` remove the current selection as part of a cut No Yes Any
 `"deleteContent"` delete the selection without specifying the direction of the deletion and this intention is not covered by another inputType No Yes Non-collapsed
 `"deleteContentBackward"` delete the content directly before the caret position and this intention is not covered by another inputType or delete the selection with the selection collapsing to its start after the deletion No Yes Any
 `"deleteContentForward"` delete the content directly after the caret position and this intention is not covered by another inputType or delete the selection with the selection collapsing to its end after the deletion No Yes Any
 `"historyUndo"` undo the last editing action No Yes Any
 `"historyRedo"` to redo the last undone editing action No Yes Any
 `"formatBold"` initiate bold text No Yes Any
 `"formatItalic"` initiate italic text No Yes Any
 `"formatUnderline"` initiate underline text No Yes Any
 `"formatStrikeThrough"` initiate stricken through text No Yes Any
 `"formatSuperscript"` initiate superscript text No Yes Any
 `"formatSubscript"` initiate subscript text No Yes Any
 `"formatJustifyFull"` make the current selection fully justified No Yes Any
 `"formatJustifyCenter"` center align the current selection No Yes Any
 `"formatJustifyRight"` right align the current selection No Yes Any
 `"formatJustifyLeft"` left align the current selection No Yes Any
 `"formatIndent"` indent the current selection No Yes Any
 `"formatOutdent"` outdent the current selection No Yes Any
 `"formatRemove"` remove all formatting from the current selection No Yes Any
 `"formatSetBlockTextDirection"` set the text block direction No Yes Any
 `"formatSetInlineTextDirection"` set the text inline direction No Yes Any
 `"formatBackColor"` change the background color No Yes Any
 `"formatFontColor"` change the font color No Yes Any
 `"formatFontName"` change the font-family No Yes Any

Other specifications may expand on this definition.

The existence of the above mentioned `inputTypes` does not mean that any
given implementation will support all of these. But if a given browser
supports an editing operation which potentially leads to a change of the
DOM, it MUST \[=dispatch=\] the corresponding `beforeinput` and `input`
events.

If the selection is collapsed, `"deleteContentBackward"` will be used
both when the user asks for text deletion within a text node, and when
the user shows the intention to deletion of more complex elements or
merge paragraphs if the caret is at the start of a text node.

If the selection is collapsed, `"deleteContentForward"` will be used
both when the user asks for text deletion within a text node, and when
the user shows the intention to deletion of more complex elements or
merge paragraphs if the caret is at the end of a text node.

[`data`] holds information plaintext data related to what is to be
added to the document.

 inputType Editing host data
 ----------------------------------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------ -------------------------------------------------------------------------------------------------------------------------------------------------
 `"insertText"` or `"insertCompositionText"` Any the plain text string to be inserted
 `"insertFromPaste"`, `"insertFromPasteAsQuotation"`, `"insertFromDrop"`, `"insertTranspose"`, `"insertReplacementText"` or `"insertFromYank"` [`input`] or [`textarea`] the plain text string to be inserted
 `"formatSetInlineTextDirection"` or `"formatSetBlockTextDirection"` Any `"ltr"`, `"rtl"`, `"auto"` or `"null"`
 `"formatBackColor"` or `"formatFontColor"` Any a string containing a [serialized CSS component value] \[\[CSSOM\]\] of the proposed color
 `"formatFontName"` Any the proposed value of the font-family CSS property
 `"insertLink"` Any the url of the proposed link
 All remaining Any null

[dataTransfer] holds information about
richtext and plaintext data that is to be taken from or added to the
document in a {{DataTransfer}} object if there is relevant data.

+---------------------------------+-----------------------+-----------------------------------------------------------------------+
| inputType | Editing host | dataTransfer |
+=================================+=======================+=======================================================================+
| `"insertFromPaste"`, | `contenteditable` | A prepopulated {{DataTransfer}} object so that: |
| `"insertFromPasteAsQuotation"`, | | |
| `"insertFromDrop"`, | | 1. The {{DataTransfer}} object\'s [drag data |
| `"insertTranspose"`, | | store] is in |
| `"insertReplacementText"` or | | [read-only] mode. |
| `"insertFromYank"` | | \[\[HTML\]\] |
| | | 2. If the pasted content is a file, the {{DataTransfer}} object\'s |
| | | [drag data store item |
| | | list] |
| | | contains one entry with the [drag data item type |
| | | string] |
| | | being the file\'s \[=mime type=\], whose |
| | | [kind] is |
| | | *File*, and whose data is a [File |
| | | object] corresponding to the pasted |
| | | file. \[\[HTML\]\] |
| | | 3. The {{DataTransfer}} object\'s [drag data store item |
| | | list] |
| | | contains one entry with the [drag data item type |
| | | string] |
| | | `"text/html"`, whose |
| | | [kind] is |
| | | *Plain Unicode string*, and whose data is a HTML representation |
| | | of the content that is in the clipboard, or in the kill buffer, |
| | | to be dropped or otherwise the content that is to be added. |
| | | \[\[HTML\]\] |
| | | 4. The {{DataTransfer}} object\'s [drag data store item |
| | | list] |
| | | contains one entry with the [drag data item type |
| | | string] |
| | | `"text/plain"`, whose |
| | | [kind] is |
| | | *Plain Unicode string*, and whose data is a plain text |
| | | representation of the content that is to be pasted, dropped or |
| | | otherwise added. \[\[HTML\]\] |
| | | 5. If the content to be pasted is a link, the {{DataTransfer}} |
| | | object\'s [drag data store item |
| | | list] |
| | | contains one entry with the [drag data item type |
| | | string] |
| | | `"text/uri-list"`, whose |
| | | [kind] is |
| | | *Plain Unicode string*, and whose data is a plain text |
| | | representation of the link that is dropped or otherwise added. |
| | | \[\[HTML\]\] |
+---------------------------------+-----------------------+-----------------------------------------------------------------------+
| All remaining | Any | null |
+---------------------------------+-----------------------+-----------------------------------------------------------------------+

[getTargetRanges()] returns
the \[=target ranges=\] of the {{InputEvent}} object.

Each {{InputEvent}} object has associated [target ranges], which
is a sequence of StaticRanges. When an {{InputEvent}} object is created,
its \[=target ranges=\] are set to the value of the `targetRanges`
attribute of the {{InputEventInit}} dictionary, or to an empty sequence
if that attribute was not given.

A \[=user agent=\] MUST set the \[=target ranges=\] of a
[trusted] {{InputEvent}} that it
\[=dispatch=\]es as follows:

- If the \[=editing host=\] is a contenteditable node, the \[=target
 ranges=\] MUST represent the content that the event will modify if it
 is not canceled.
- Otherwise, if the \[=editing host=\] is an [EditContext editing
 host](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host)
 and the {{InputEvent/inputType}} is not `"insertCompositionText"`, the
 \[=target ranges=\] MUST represent the content that the \[=user
 agent=\] assumes to be affected by the event.
- Otherwise, the \[=target ranges=\] MUST be empty.

The \[=target ranges=\] of an {{InputEvent}} \[=dispatch=\]ed by a
\[=user agent=\] MUST cover only the [code
points] that the \[=user agent=\] would
normally replace, even if they are only part of a \[=grapheme
cluster=\].

When an {{InputEvent}} object is created by script, its \[=target
ranges=\] are the ones the creating script set through the
`targetRanges` attribute of the {{InputEventInit}} dictionary. A \[=user
agent=\] MUST NOT alter them, and MUST NOT derive them from the
\[=editing host=\], the {{InputEvent/inputType}} or the state of the
DOM. In particular, the \[=target ranges=\] of an {{InputEvent}} that is
not [trusted] are an empty
sequence if the creating script did not set them, even if the event is
dispatched on an \[=editing host=\] and has an {{InputEvent/inputType}}
for which a \[=user agent=\] would otherwise compute \[=target
ranges=\].

*This note is not normative.*

Being able to create an {{InputEvent}} with known \[=target ranges=\]
allows an editor to express an input intention that the \[=user agent=\]
doesn\'t have a way of mapping to a user gesture. For example, an editor
whose UI has a "delete word backward" button can dispatch a
`beforeinput` event with an {{InputEvent/inputType}} of
`"deleteWordBackward"` and the \[=target ranges=\] it computed for the
word before the caret, so that event handlers can act on it just as they
would act on a [trusted] event.

*This note is not normative.*

Depending on the script and the platform, deleting backward or forward
in a text node with a collapsed selection may affect one or multiple
[code points] or an entire \[=grapheme cluster=\].
For example, deleting backward in a text node containing "café" may
remove either the acute accent or the entire "é" character, depending on
the script and the platform.

##### Methods

 inputType Editing host Response of `getTargetRanges()`
 ------------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------
 `"historyUndo"` or `"historyRedo"` Any empty Array
 All remaining `contenteditable` an Array of [StaticRanges] \[\[DOM\]\] associated with event
 All remaining [`input`] or [`textarea`] an empty Array

The preceding table describes the \[=target ranges=\] a \[=user agent=\]
sets on the {{InputEvent}} objects it \[=dispatch=\]es as
[trusted] events.

For an {{InputEvent}} created by script, the \[=target ranges=\] are the
ones set in the {{InputEventInit}} dictionary, regardless of the
{{InputEvent/inputType}} or the \[=editing host=\].

#### Event definitions

::: event-definition

[[`beforeinput`](#event-type-beforeinput)]

: +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Type | **`beforeinput`** |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Interface | [`InputEvent`](#interface-InputEvent) |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Sync / Async | Sync |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Bubbles | Yes |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Trusted Targets | Any `Element` that is an \[=editing host=\]. |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | [Default | - For contentEditable=typing editing hosts for inputType `"insertCompositionText"`: |
 | action](https://www.w3.org/TR/uievents/#default-action) | \'Update the DOM\'. |
 | \[\[UI-EVENTS\]\] | - For `contentEditable="true"` \[=editing hosts=\] for all inputTypes: \'Update the |
 | | DOM\'. |
 | | - For [EditContext editing |
 | | hosts](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host) for |
 | | [EditContext-handled |
 | | inputTypes](https://w3c.github.io/edit-context/#dfn-editcontext-handled-inputtype): |
 | | [Handle input for |
 | | EditContext](https://w3c.github.io/edit-context/#dfn-handle-input-for-editcontext) |
 | | given the \[=editing host=\] element. |
 | | - None otherwise. |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+
 | Context\ | - [`InputEvent.data`](#dfn-data): the string containing the data |
 | (trusted events) | that was added to the element, which MAY be null if it doesn\'t apply. |
 | | - [`InputEvent.dataTransfer`](#dom-inputevent-datatransfer): |
 | | richtext data added or removed from element, which MAY be null if it doesn\'t |
 | | apply. |
 | | - `InputEvent.getTargetRanges()`: returns an array of StaticRanges |
 | | which will be affected by the change to the DOM if it is not canceled. |
 +---------------------------------------------------------+---------------------------------------------------------------------------------------+

 A \[=user agent=\] MUST \[=dispatch=\] this event when the user has
 attempted to input in a contenteditable element. It does not
 necessarily mean the \[=user agent=\] will then update the DOM.

 A \[=user agent=\] MUST NOT \[=dispatch=\] this event due to events
 that are not caused by attempted user input, such as system events.

 This does not prevent a script from \[=dispatch=\]ing a
 `beforeinput` event. Such an event is not
 [trusted], so its \[=target
 ranges=\] are the ones that were set when the {{InputEvent}} object
 was created, and `getTargetRanges()` returns them.

 ::: note
 *This note is not normative.*

 Third-party browser extensions, such as spelling or grammar
 checkers, may modify the contents of editable elements by
 dispatching synthetic beforeinput events (events whose
 {{Event/isTrusted}} attribute is `false`), as the \[=user agent=\]
 does not \[=dispatch=\] events for such modifications. To remain
 compatible with such extensions, JavaScript developers are advised
 to listen for these synthetic `beforeinput` events and to handle
 those whose {{InputEvent/inputType}} is `"insertReplacementText"`,
 `"insertFromPaste"`, `"deleteContent"`, `"deleteContentBackward"` or
 `"deleteContentForward"` in the same way as the corresponding
 trusted events.

 This applies also to editors that use an [EditContext editing
 host](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host):
 even though handling of the deletion inputTypes `"deleteContent"`,
 `"deleteContentBackward"` and `"deleteContentForward"` is usually
 not needed there, as the \[=user agent=\] handles them through the
 EditContext, editors should still handle synthetic `beforeinput`
 events of these inputTypes dispatched by extensions. Likewise, where
 a third-party extension inserts content the way a paste operation
 would, listening for the synthetic `beforeinput` event with
 inputType `"insertFromPaste"` is preferable to listening for a
 synthetic
 [paste](https://www.w3.org/TR/clipboard-apis/#clipboard-event-paste)
 \[\[CLIPBOARD-APIS\]\] event, as `paste` events do not carry target
 ranges.
 :::

::: event-definition

[[`input`](#event-type-input)]

: +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Type | **`input`** |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Interface | [`InputEvent`](#interface-InputEvent) |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Sync / Async | Sync |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Bubbles | Yes |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Trusted Targets | Any `Element` with `contenteditable` attribute enabled. |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | [Default | None |
 | action](https://www.w3.org/TR/uievents/#default-action) | |
 | \[\[UI-EVENTS\]\] | |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+
 | Context\ | - [`InputEvent.data`](#dfn-data): the string containing the |
 | (trusted events) | data that was added to the element, which MAY be null if it doesn\'t apply. |
 | | - [`InputEvent.dataTransfer`](#dom-inputevent-datatransfer): |
 | | richtext data added or removed from element, which MAY be null if it |
 | | doesn\'t apply. |
 | | - `InputEvent.getTargetRanges()`: returns an array of |
 | | StaticRanges which were affected by the change to the DOM. |
 +---------------------------------------------------------+-------------------------------------------------------------------------------+

 A \[=user agent=\] MUST \[=dispatch=\] this event immediately after
 the DOM has been updated due to user expressed intention to change
 the document contents which the browser has handled. If the browser
 makes no DOM change, either because the editing host is an
 [EditContext editing
 host](https://w3c.github.io/edit-context/#dfn-editcontext-editing-host)
 (which does not do automatic DOM changes) or because the \[=user
 agent=\] concludes that no DOM change is needed, the user agent MUST
 NOT dispatch this event.

 As for the `beforeinput` event, an {{InputEvent}} of type `input`
 that is created by script has the \[=target ranges=\] given in the
 {{InputEventInit}} dictionary, and `getTargetRanges()` returns them.

## Input Event Order During Composition

The start of a composition is marked by dispatching a
[compositionstart](https://www.w3.org/TR/uievents/#compositionstart)
event.

During a composition session, whenever a text composition system updates
its active text passage, a
[compositionupdate](https://www.w3.org/TR/uievents/#compositionupdate)
event is dispatched.

After each
[compositionupdate](https://www.w3.org/TR/uievents/#compositionupdate)
event, a pair of {{beforeinput}} and {{input}} events are dispatched.
The {{beforeinput}} and {{input}} events:

- Are not cancellable
- Have an {{InputEvent/inputType}} set to `"insertCompositionText"`
- Have a {{data}} attribute equal to that of the
 [compositionupdate](https://www.w3.org/TR/uievents/#compositionupdate)
 event
- Have a {{InputEvent/targetRange}} that surrounds the active text
 passage of the composition

The DOM contents of the active text passage are updated after the
{{beforeinput}} event is dispatched and before the {{input}} event is
dispatched.

The end of a composition session is marked by dispatching a
[compositionend](https://www.w3.org/TR/uievents/#compositionend)
event.

## Event order when using `"insertFromPaste"`

When an `"insertFromPaste"` {{beforeinput}} event is dispatched, it MUST
be preceded by a
[paste](https://www.w3.org/TR/clipboard-apis/#clipboard-event-paste)
\[\[CLIPBOARD-APIS\]\] event.

## Privacy and security considerations

*This section is not normative.*

There are no known security or privacy impacts of this feature beyond
[fingerprinting]
\[\[fingerprinting-guidance\]\] techniques that already are available
through existing events, such as the [`keydown`] and [`keypress`] \[\[UI-EVENTS\]\] events.

If this feature replaces existing events, it MAY lead to a decline in
available [fingerprinting]
\[\[fingerprinting-guidance\]\] techniques, as users\' intentions are
recorded, and not the particular type of hardware they used to
[express] this intention.

## Acknowledgements

Thanks to: Michael Aufreiter, Adrian Bateman, Oliver Buchtala, Robin
Berjon, Enrica Casucci, Bo Cupp, Domenic Denicola, Emil Eklund, Olivier
Forget, Aryeh Gregor, Marijn Haverbeke, Yoshifumi Inoue, Koji Ishii,
Gary Kacmarcik, Ian Kilpatrick, Frederico Caldeira Knabben, Takayoshi
Kochi, Piotrek Koszuliński, Travis Leithead, Grisha Lyukshin, Miles
Maxfield, Chaals McCathie Nevile, Masayuki Nakano, Ryosuke Niwa, Julie
Parent, Ben Peters, Florian Rivoal, Morgan Smith, Hallvord R. M. Steen,
Johan Sörlin, Cristian Talau, Dave Tapuska, Ojan Vafai, Léonie Watson,
Xiaoqian Wu, Chong Zhang, Joanmarie, and everyone in the Editing
Taskforce for their input and feedback.
