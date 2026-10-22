
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Accessible Name and Description Computation 1.2

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 12 October
2026

More details about this document

This version:
: [https://w3c.github.io/aria/accname/](https://w3c.github.io/aria/accname/)

Latest published version:
: <https://www.w3.org/TR/accname-1.2/>

Latest editor\'s draft:
: <https://w3c.github.io/aria/accname/>

History:
: <https://www.w3.org/standards/history/accname-1.2/>
: [Commit history](https://github.com/w3c/aria/commits/main/accname/)

Latest Recommendation:
: <https://www.w3.org/TR/accname/>

Editors:
: [Bryan Garaventa] ([Invited
 Expert](https://github.com/whatsock))
: [Melanie Sumner] ([Invited
 Expert](https://github.com/melsumner))

Former editors:
: [Michael Cooper] ([W3C](https://www.w3.org/))
: [Joanmarie Diggs] ([Igalia,
 S.L.](https://www.igalia.com/)) (Editor until
 March 2021)
: [Richard Schwerdtfeger]
 ([Knowbility](https://knowbility.org/)) (Editor
 until October 2017)
: [Joseph Scheuhammer] ([Inclusive Design Research
 Centre, OCAD University](https://idrc.ocadu.ca/)) (Editor until May 2017)
: [James Craig] ([Apple
 Inc.](https://www.apple.com/accessibility/))
 (Editor until May 2016)
: [Andi Snow-Weaver] ([IBM](https://www.ibm.com/)) (Editor until December 2012)
: [Aaron Leventhal] ([IBM](https://www.ibm.com/)) (Editor until January 2009)

Feedback:
: [GitHub w3c/accname](https://github.com/w3c/accname/) ([pull
 requests](https://github.com/w3c/aria/pulls?q=is%3Apr+is%3Aopen+label%3A%22spec%3Aaccname%22),
 [new issue](https://github.com/w3c/accname/issues/new/choose), [open
 issues](https://github.com/w3c/accname/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2014-2026 [World
Wide Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

This document describes how [user
agents](https://infra.spec.whatwg.org/#user-agent) determine the
[names](#dfn-accessible-name) and
[descriptions](#dfn-accessible-description) of [accessible
objects](https://www.w3.org/TR/wai-aria-1.2/#dfn-accessible-object) from web content languages. This
information is in turn exposed through [accessibility [APIs]](https://www.w3.org/TR/wai-aria-1.2/#dfn-accessibility-api) so that [assistive
technologies](#dfn-assistive-technologies) can identify these
objects and present their names or descriptions to users. Documenting
the algorithm through which names and descriptions are to be determined
promotes interoperable exposure of these properties among different
accessibility [APIs]
and helps to ensure that this information appears in a manner consistent
with author intent.

The accessible name and description computation specification defines
support that applies across multiple content technologies. This includes
accessible name and description provided by general-purpose
[[WAI-ARIA]](https://www.w3.org/TR/wai-aria-1.2/)
\[[WAI-ARIA](#bib-wai-aria "Accessible Rich Internet Applications (WAI-ARIA) 1.1")\]
[roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role),
[states](https://www.w3.org/TR/wai-aria-1.2/#dfn-state), and
[properties](https://www.w3.org/TR/wai-aria-1.2/#dfn-property)
as well as features specific to individual content languages.

This document updates and will eventually supersede the accessible name
and description guidance in the [Accessible Name and Description
Computation 1.1](https://www.w3.org/TR/accname-1.1/)
\[[ACCNAME-1.1](#bib-accname-1-1 "Accessible Name and Description Computation 1.1")\] [W3C]
Recommendation. It is part of the [WAI-ARIA] suite described in the
[[WAI-ARIA]
Overview](https://www.w3.org/WAI/intro/aria.php).

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

This document was published by the [Accessible Rich Internet
Applications Working Group](https://www.w3.org/groups/wg/aria) as an
Editor\'s Draft.

Publication as an Editor\'s Draft does not imply endorsement by
[W3C] and its Members.

This is a draft document and may be updated, replaced, or obsoleted by
other documents at any time. It is inappropriate to cite this document
as other than a work in progress.

This document was produced by a group operating under the [[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/). [W3C] maintains a [public list of any
patent
disclosures](https://www.w3.org/groups/wg/aria/ipr){rel="disclosure"}
made in connection with the deliverables of the group; that page also
includes instructions for disclosing a patent. An individual who has
actual knowledge of a patent that the individual believes contains
[Essential
Claim(s)](https://www.w3.org/policies/patent-policy/#def-essential) must
disclose the information in accordance with [section 6 of the
[W3C] Patent
Policy](https://www.w3.org/policies/patent-policy/#sec-Disclosure).

This document is governed by the [18 August 2025 [W3C] Process
Document](https://www.w3.org/policies/process/20250818/).

## Table of Contents

1. [Abstract](#abstract)
2. [Status of This Document](#sotd)
3. [1. Introduction](#intro)
4. [2. Important Terms](#terms)
5. [3. Conformance](#conformance)
6. [4. Name and Description](#mapping_additional_nd)
 1. [4.1 Name Computation](#mapping_additional_nd_name)
 2. [4.2 Description
 Computation](#mapping_additional_nd_description)
 3. [4.3 Text Equivalent
 Computation](#mapping_additional_nd_te)
 1. [4.3.1 Terminology](#terminology)
 2. [4.3.2 Computation steps](#computation-steps)
7. [5. Accessible Name and Description
 Mapping](#accessible-name-and-description-mapping)
8. [6. Appendices](#appendices)
 1. [6.1 Change Log](#changelog)
 1. [6.1.1 Substantive changes since the last public working
 draft](#substantive-changes-since-the-last-public-working-draft)
 2. [6.1.2 Substantive changes since the [Accessible Name and
 Description Computation 1.1
 Recommendation]](#substantive-changes-since-the-accessible-name-and-description-computation-1-1-recommendation)
 2. [6.2 Acknowledgments](#acknowledgements)
 1. [6.2.1 ARIA WG participants at the time of
 publication](#ack_group)
 2. [6.2.2 Enabling funders](#ack_funders)
9. [A. References](#references)
 1. [A.1 Normative references](#normative-references)
 2. [A.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

[User agents](https://infra.spec.whatwg.org/#user-agent) acquire information from the [DOM] \[[DOM](#bib-dom "DOM Standard")\] and create a parallel structure called the
[accessibility
tree](https://www.w3.org/TR/wai-aria/#dfn-accessibility-tree), made up of [accessible
objects](https://www.w3.org/TR/wai-aria/#dfn-accessible-object). An accessible object provides information
about its [role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role),
[states](https://www.w3.org/TR/wai-aria/#dfn-state), and
[properties](https://www.w3.org/TR/wai-aria/#dfn-property).
An example is an accessible object whose role is `menuitem`, is
currently in an `enabled` state, with a `haspopup` property, indicating
that it leads to a sub-menu.

The two properties of accessible objects described in this document are
its [accessible
name](#dfn-accessible-name) and [accessible
description](#dfn-accessible-description). The name is a short
label that provides information about the purpose of the object. An
example of an accessible name for a menu item is `New`, signifying that
the menu item provides for the creation of new documents, windows, and
so on.

The description is a short explanation that further clarifies the nature
of the accessible object. It is not always necessary to provide a
description if the name is sufficient, but it can help a user better
understand the use of the object.

[Accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api) currently support flat, unstructured
strings for accessible names and descriptions. The result of the
name/description computation is thus a flat string.

The terms \"accessible name\" and \"accessible description\" are used to
emphasize that they are properties of [accessible
objects](https://www.w3.org/TR/wai-aria/#dfn-accessible-object) as exposed by [Accessibility [APIs]](https://www.w3.org/TR/wai-aria/#dfn-accessibility-api). However, they are frequently referred to
hereafter as simply \"name\" and \"description\".

::: header-wrapper
## 2. Important Terms

*This section is non-normative.*

While some terms are defined in place, the following definitions are
used throughout this document.

[Assistive Technologies]

: Hardware and/or software that:

 - relies on services provided by a [user
 agent](https://infra.spec.whatwg.org/#user-agent)
 to retrieve and render Web content
 - works with a user agent or web content itself through the use of
 [APIs], and
 - provides services beyond those offered by the user agent to
 facilitate user interaction with web content by people with
 disabilities

 This definition may differ from that used in other documents.

 Examples of assistive technologies that are important in the context
 of this document include the following:

 - screen magnifiers, which are used to enlarge and improve the
 visual readability of rendered text and images;
 - screen readers, which are most-often used to convey information
 through synthesized speech or a refreshable Braille display;
 - text-to-speech software, which is used to convert text into
 synthetic speech;
 - speech recognition software, which is used to allow spoken control
 and dictation;
 - alternate input technologies (including head pointers, on-screen
 keyboards, single switches, and sip/puff devices), which are used
 to simulate the keyboard;
 - alternate pointing devices, which are used to simulate mouse
 pointing and clicking.

[Accessible Description]

: An accessible description provides additional information, related
 to an interface element, that complements the [accessible
 name](#dfn-accessible-name). The accessible description might or
 might not be visually perceivable.

[Accessible Name]

: The accessible name is the name of a user interface element. Each
 platform [accessibility [API]](https://www.w3.org/TR/wai-aria-1.2/#dfn-accessibility-api)
 provides the accessible name property. The value of the accessible
 name may be derived from a visible (e.g., the visible text on a
 button) or invisible (e.g., the text alternative that describes an
 icon) property of the user interface element. See related
 [accessible
 description](#dfn-accessible-description).

 A simple use for the accessible name property may be illustrated by
 an \"OK\" button. The text \"OK\" is the accessible name. When the
 button receives focus, assistive technologies may concatenate the
 platform\'s role description with the accessible name. For example,
 a screen reader may speak \"push-button OK\" or \"OK button\". The
 order of concatenation and specifics of the role description (e.g.,
 \"button\", \"push-button\", \"clickable button\") are determined by
 platform [accessibility [API]](https://www.w3.org/TR/wai-aria-1.2/#dfn-accessibility-api)s or [assistive
 technologies](#dfn-assistive-technologies).

[Tooltip attribute]

: Any host language attribute that would result in a user agent
 generating a tooltip such as in response to a mouse hover in desktop
 user agents.

::: header-wrapper
## 3. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, and *MUST NOT* in this document are to be
interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

Normative sections provide requirements that authors, user agents and
assistive technologies *MUST* follow for an implementation to conform to
this specification.

Non-normative (informative) sections provide information useful to
understanding the specification. Such sections may contain examples of
recommended practice, but it is not required to follow such
recommendations in order to conform to this specification.

::: header-wrapper
## 4. Name and Description

The starting point of the name and description computation is a
[DOM]
[element](https://dom.spec.whatwg.org/#concept-element).
The output is a flat, unstructured string that can be as simple as a
single word, or a string of space-separated tokens. Examples include
`Save` and `Reload from disk`.

An important factor is the
[element\'s](https://dom.spec.whatwg.org/#concept-element)
[role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role), that
determines which content contributes to the name string. Roles have a
`nameFrom` [RDF] property,
with three possible values:

author
: name is generated from values provided by the author in explicit
 markup features such as the `aria-label` and `aria-labelledby`
 [attribute](https://dom.spec.whatwg.org/#concept-attribute),
 or a host language labeling mechanism, such as the `alt` or `title`
 [attribute](https://dom.spec.whatwg.org/#concept-attribute)
 in [HTML], or the `desc`
 [element](https://dom.spec.whatwg.org/#concept-element)
 in [SVG].

contents
: name is generated from the [text
 nodes](https://dom.spec.whatwg.org/#exclusive-text-node) associated with the
 [element](https://dom.spec.whatwg.org/#concept-element).
 Although this may be allowed in addition to \"author\" in some
 [roles](https://www.w3.org/TR/wai-aria-1.3/#dfn-role),
 \"content\" is used only if higher priority \"author\" features are
 not provided. Priority is defined by the [text equivalent
 computation](#mapping_additional_nd_te) algorithm.

prohibited
: the element has no name. Authors MUST NOT use the
 [`aria-label`](https://w3c.github.io/aria/#aria-label)
 or
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 attributes to name the element.

The [Accessible Rich Internet Applications ([WAI-ARIA])
1.2](https://w3c.github.io/aria/#)
\[[WAI-ARIA](#bib-wai-aria "Accessible Rich Internet Applications (WAI-ARIA) 1.1")\] specification provides lists of [roles that
support name from
author](https://w3c.github.io/aria/#namefromauthor), [roles
that support name from
content](https://w3c.github.io/aria/#namefromcontent) and
[roles that cannot be
named](https://w3c.github.io/aria/#namefromprohibited).

::: header-wrapper
### 4.1 Name Computation

[User agents](https://infra.spec.whatwg.org/#user-agent) *MUST* compute an [accessible
name](#dfn-accessible-name) using the rules outlined
below in the section titled [Text Equivalent
Computation](#mapping_additional_nd_te).

::: header-wrapper
### 4.2 Description Computation

The following table provides the order of precedence for markup that can
be applied to compute an [accessible
description](#dfn-accessible-description). [User
agents](https://infra.spec.whatwg.org/#user-agent) *MUST* use the first applicable entry from the table
where the listed conditions are met, as described in the last column.
The user agent *MUST NOT* use any markup other that the first relevant
markup found, even if that markup results in an empty description:

+-----------------+-----------------------------------------------------------------------------------------+-----------------------------------------------------------------------+-------------------------------------------+
| Precedence | Attribute | Applicable conditions | How used to compute description |
+=================+=========================================================================================+=======================================================================+===========================================+
| 1 | [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) | Use on any element | [Name |
| | attribute | | computation](#mapping_additional_nd_name) |
| | | | on all nodes referenced by |
| | | | aria-describedby on the element, |
| | | | concatenated, and separated by a space |
| | | | character |
+-----------------+-----------------------------------------------------------------------------------------+-----------------------------------------------------------------------+-------------------------------------------+
| 2 | [`aria-description`](https://w3c.github.io/aria/#aria-description) | Use on any element | As a flat string |
| | attribute | | |
+-----------------+-----------------------------------------------------------------------------------------+-----------------------------------------------------------------------+-------------------------------------------+
| 3 | host language features which participate in the description calculation | Unique host language features *MAY* participate in the description | Either a [text equivalent |
| | | computation for an element, only if they were not already used for | computation](#mapping_additional_nd_te) |
| | | the accessible name of the applicable element. See [[HTML] AAM: Accessible Description | string value of the host language |
| | | Computation](https://www.w3.org/TR/html-aam-1.0/#accdesc-computation) | attribute. |
| | | for the [HTML] elements | |
| | | which meet this condition. | |
+-----------------+-----------------------------------------------------------------------------------------+-----------------------------------------------------------------------+-------------------------------------------+
| 4 | host language tooltip attribute or equivalent feature (e.g., [HTML] `title` attribute) | - Only use if not already used for the accessible name of this node | |
+-----------------+-----------------------------------------------------------------------------------------+-----------------------------------------------------------------------+-------------------------------------------+

::: header-wrapper
### 4.3 Text Equivalent Computation

The text equivalent computation is used by both the [accessible
name](#dfn-accessible-name) and [accessible
description](#dfn-accessible-description). There are different
rules provided for several different types of
[elements](https://dom.spec.whatwg.org/#concept-element),
[nodes](https://dom.spec.whatwg.org/#concept-node), and
combinations of markup. Text alternatives are built up, when
appropriate, from all the relevant content contained within an
[element](https://dom.spec.whatwg.org/#concept-element).
This is accomplished via steps 2.2 and 2.6, which are recursive, using
the full set of rules to retrieve text from its own children or nodes it
references.

The purpose of the computation is to create a
[perceivable](https://www.w3.org/TR/wai-aria-1.2/#dfn-perceivable) label or description for alternative
presentations, in the form of a flat string of space separated textual
tokens.

::: header-wrapper
#### 4.3.1 Terminology

Root node
: The [DOM]
 [node](https://dom.spec.whatwg.org/#concept-node) or
 [element](https://dom.spec.whatwg.org/#concept-element)
 for which the text alternative is sought.

Current node
: The [DOM]
 [node](https://dom.spec.whatwg.org/#concept-node) currently traversed to compute the `root node`\'s text
 equivalent. Initially, the `current node` is the `root node`, but at
 later stages is either some descendant of the `root node`, or
 another referenced node.

Rendered child nodes
: The
 [nodes](https://dom.spec.whatwg.org/#concept-node)
 that are rendered as child nodes of a given node when taking [shadow
 roots](https://dom.spec.whatwg.org/#concept-shadow-root) and
 [slots](https://dom.spec.whatwg.org/#concept-slot) into consideration.

Flat string
: A string of characters where all carriage returns, newlines, tabs,
 and form-feeds are replaced with a single space, and multiple spaces
 are reduced to a single space. The string contains only character
 data; it does not contain any markup.

Total accumulated text
: The text equivalent computed up to, but not including the
 `current node`.

Accumulated text
: Text accumulated at a step or sequence of steps described below. It
 is temporary storage for those steps.

Result
: The text equivalent computed at one of the steps described below.

Append the result, without a space, to X

: - If X is empty, copy the `result` to X.
 - If X is non-empty, copy the `result` to the end of X.

Append the result, with a space, to X

: - If X is empty, copy the `result` to X.
 - If X is non-empty, add a space to the end of X and then copy the
 `result` to X after the space.

Prepend result, without a space, to X

: - If X is empty, copy the `result` to X.
 - If X is non-empty, copy the `result` to the start of X.

Prepend the result, with a space, to X

: - If X is empty, copy the `result` to X.
 - If X is non-empty, copy the `result` to the start of X, and add a
 space after the copy.

::: header-wrapper
#### 4.3.2 Computation steps

The text alternative for a given element is computed as follows:

1. [*Initialization:* Set the `root node` to the given
 element, the `current node` to the `root node`, and the
 `total accumulated text` to the empty string (\"\"). If the
 `root node`\'s role prohibits naming, return the empty string
 (\"\").]
2. [*Computation:* Compute the text alternative for the
 `current node`:]
 1. [*Hidden Not Referenced:* If the `current node` is
 [[hidden](https://www.w3.org/TR/wai-aria/#dfn-hidden)]
 **and is**:]

 1. **Not** part of an `aria-labelledby` or `aria-describedby`
 traversal, where the node directly referenced by that
 relation was hidden.
 2. **Nor** part of a native host language text alternative
 [element](https://dom.spec.whatwg.org/#concept-element) (e.g. `label` in [HTML]) or
 [attribute](https://dom.spec.whatwg.org/#concept-attribute) traversal, where the root of
 that traversal was hidden.

 Return the empty string.

 :::::
 :::
 Note
 :::

 :::
 It\'s important to clarify the broad definition of hidden for
 the purposes of accessible name calculation:

 1. Nodes with [CSS]
 properties `display:none`, `visibility:hidden`,
 `visibility:collapse` or `content-visibility:hidden`: They
 are considered hidden, as they match the guidelines \"not
 perceivable\" and \"explicitly hidden\".
 2. Nodes with [CSS]
 properties `opacity:0` or `filter:opacity(0%)`, or similar
 [SVG] mechanisms:
 They are not considered hidden. Text hidden with these
 methods can still be selected or copied, and user agents
 still expose it in their accessibility trees.
 3. Nodes with the `aria-hidden="true"` property: it is
 considered hidden, matching the \"explicitly hidden\"
 guideline.
 4. Nodes hidden off screen or behind another object: they are
 not considered hidden. They are exposed in the accessibility
 tree and they can even name on-screen objects.
 :::
 :::::

 :::::
 :::
 Note
 :::

 :::
 By default, [assistive
 technologies](#dfn-assistive-technologies) do not relay
 hidden information, but an author can explicitly override that
 and include hidden text as part of the [accessible
 name](#dfn-accessible-name) or
 [accessible
 description](#dfn-accessible-description) by using
 `aria-labelledby` or `aria-describedby`.
 :::
 :::::

 ::: marker
 [Example 1](#example-1)
 :::

 The following examples show the meaning of the clause \"Not part
 of an `aria-labelledby` or `aria-describedby` traversal, where
 the node directly referenced by that relation was hidden.\".

 First, `element1`\'s [accessible
 name](#dfn-accessible-name) is \"hello\"
 because, although `element3` is hidden, it is part of an
 `aria-labelledby` traversal started in `element2`, which is
 hidden too.

 ::::
 ::: marker
 [Example](#example-1-0)
 :::

 ``` highlight
 <element1 id="el1" aria-labelledby="el2" />
 <element2 id="el2" class="hidden">
 <element3 id="el3" class="hidden">hello</element3>
 </element2>
 ```
 ::::

 ::: marker
 [Example 2](#example-2)
 :::

 Conversely, `element1` has no [accessible
 name](#dfn-accessible-name) if
 `element3` is hidden and it is part of an `aria-labelledby`
 traversal started in `element2`, but `element2` is not hidden.

 ``` highlight
 <element1 id="el1" aria-labelledby="el2" />
 <element2 id="el2">
 <element3 id="el3" class="hidden">hello</element3>
 </element2>
 ```

 2. [*LabelledBy:* Otherwise, if the `current node` has
 an `aria-labelledby`
 [attribute](https://dom.spec.whatwg.org/#concept-attribute)
 that contains at least one valid IDREF, and the `current node`
 is not already part of an ongoing `aria-labelledby` or
 `aria-describedby` traversal, process its IDREFs in the order
 they occur:]
 1. [ Set the `accumulated text` to the empty
 string.]
 2. [For each IDREF:]
 1. [Set the `current node` to the node
 referenced by the IDREF.]
 2. [*LabelledBy Traversal:* Compute the
 text alternative of the `current node` beginning with
 the overall [Computation](#comp_computation) step. Set
 the `result` to that text
 alternative.]
 3. [Append a space character and the
 `result` to the
 `accumulated text`.]
 3. [Return the `accumulated text` if it is not
 the empty string (\"\").]

 ::::
 The result of [LabelledBy Traversal](#comp_labelledby_traversal)
 in combination with [Hidden Not
 Referenced](#comp_hidden_not_referenced) means that [user
 agents](https://infra.spec.whatwg.org/#user-agent) *MUST* include all nodes in the
 subtree as part of the [accessible
 name](#dfn-accessible-name) or
 [accessible
 description](#dfn-accessible-description), when the
 node referenced by `aria-labelledby` or `aria-describedby` is
 hidden.

 ::: marker
 [Example 3](#example-3)
 :::

 The following example shows the meaning of the clause \"... and
 the `current node` is not already part of an `aria-labelledby`
 traversal ...\" .

 1. `element1`\'s [accessible
 name](#dfn-accessible-name) is
 \"hello\" because this is a first traversal of its
 `aria-labelledby`, leading to `element3`.
 2. `element2` has no [accessible
 name](#dfn-accessible-name). The
 computation involves a first traversal of its
 `aria-labelledby` leading to `element1`, but `element1`\'s
 `aria-labelledby` is not subsequently followed.

 ``` highlight
 <element1 id="el1" aria-labelledby="el3" />
 <element2 id="el2" aria-labelledby="el1" />
 <element3 id="el3"> hello </element3>
 ```
 ::::

 3. [*Embedded Control:* Otherwise, if the `current node`
 is a control embedded within the label (e.g. any element
 directly referenced by `aria-labelledby`) for another
 [widget](https://www.w3.org/TR/wai-aria/#dfn-widget), where the user can adjust the
 embedded control\'s value, then return the embedded control as
 part of the text alternative in the following
 manner:]

 1. [*Textbox:* If the embedded control has role
 [textbox](https://w3c.github.io/aria/#textbox),
 return its value.]
 2. [*Combobox/Listbox:* If the embedded control has role
 [combobox](https://w3c.github.io/aria/#combobox)
 or
 [listbox](https://w3c.github.io/aria/#listbox),
 return the text alternative of the chosen
 [option](https://w3c.github.io/aria/#option).]
 3. [*Range:* If the embedded control has role
 [range](https://w3c.github.io/aria/#range)
 (e.g., a
 [spinbutton](https://w3c.github.io/aria/#spinbutton)
 or
 [slider](https://w3c.github.io/aria/#slider)):]
 1. [If the `aria-valuetext` property is present, return its
 value,]
 2. [Otherwise, if the `aria-valuenow` property is present,
 return its
 value,]
 3. [Otherwise, use the value as specified by a host
 language
 attribute.]

 ::: marker
 [Example 4](#example-4)
 :::

 Consider a [check
 box](https://w3c.github.io/aria/#checkbox)
 label that contains a text input field: \"Flash the screen
 \[input\] times\". If the input field has the value \"5\", the
 complete label is \"Flash the screen 5 times\", e.g.:

 ``` highlight
 <label for="flash">
 <input type="checkbox" id="flash">
 Flash the screen <span tabindex="0" aria-label="number of times" contenteditable>5</span> times.
 </label>
 ```

 4. [*AriaLabel:* Otherwise, if the `current node` is not
 a
 [slot](https://dom.spec.whatwg.org/#concept-slot)
 element and has an `aria-label`
 [attribute](https://dom.spec.whatwg.org/#concept-attribute)
 whose value is not undefined, not the empty string, nor, when
 trimmed of
 [whitespace](https://infra.spec.whatwg.org/#ascii-whitespace), is not the empty string:]

 1. If traversal of the `current node` is due to [Name From
 Content descendant node
 recursion](#comp_name_from_content_for_each_child) **and**
 the `current node` is an embedded control, ignore
 `aria-label` and skip to rule [Embedded
 Control](#comp_embedded_control).
 2. Otherwise, return the value of `aria-label`.

 ::: marker
 [Example 5](#example-5)
 :::

 The following example shows the interaction of `aria-labelledby`
 and `aria-label` when a
 [node](https://dom.spec.whatwg.org/#concept-node) has an `aria-labelledby` that refers to itself. The
 `<span >` elements have the [accessible
 names](#dfn-accessible-name) \"Delete
 Documentation.pdf\" and \"Delete HolidayLetter.pdf\",
 respectively.

 ::::
 ::: marker
 [Example](#example-5-0)
 :::

 ``` highlight
 <h1>Files</h1>
 <ul>
 <li>
 <a id="file_row1" href="./files/Documentation.pdf">Documentation.pdf</a>
 <span tabindex="0" id="del_row1" aria-label="Delete" aria-labelledby="del_row1 file_row1"></span>
 </li>
 <li>
 <a id="file_row2" href="./files/HolidayLetter.pdf">HolidayLetter.pdf</a>
 <span tabindex="0" id="del_row2" aria-label="Delete" aria-labelledby="del_row2 file_row2"></span>
 </li>
 </ul>
 ```
 ::::

 5. [*Host Language Label:* Otherwise, if the
 `current node`\'s native markup provides an
 [attribute](https://dom.spec.whatwg.org/#concept-attribute)
 (e.g. `alt`) or
 [element](https://dom.spec.whatwg.org/#concept-element)
 (e.g. [HTML] `label` or
 [SVG] `title`) that
 defines a text alternative, return that alternative in the form
 of a `flat string` as defined by the host language (e.g.,
 [[HTML]-AAM](https://www.w3.org/TR/html-aam-1.0/#accessible-name-and-description-computation)),
 unless the `current node` is exposed as presentational
 (`` or ``,
 `a`).]

 :::::
 :::
 Note
 :::

 :::
 Important! The accessible name for native [HTML] elements may be calculated
 differently depending on host language. Make sure to review
 [[HTML]-AAM](https://www.w3.org/TR/html-aam-1.0/#accessible-name-and-description-computation)
 for more information.
 :::
 :::::

 :::::
 :::
 Note
 :::

 :::
 For example, in [HTML],
 the `img` element\'s `alt` attribute defines a text alternative
 string, and the `label` element provides text for the referenced
 form element. In [SVG2], the `desc` and
 `title` elements provide a description of their parent element.
 :::
 :::::

 6. [*Name From Content:* Otherwise, if the
 `current node's`
 [role](https://www.w3.org/TR/wai-aria-1.3/#dfn-role) allows
 [name from
 content](https://w3c.github.io/aria/#namefromcontent),
 or if the `current node` is referenced by `aria-labelledby`,
 `aria-describedby`, or is a native host language text
 alternative
 [element](https://dom.spec.whatwg.org/#concept-element)
 (e.g. `label` in [HTML]), or is a descendant of a
 native host language text alternative
 [element](https://dom.spec.whatwg.org/#concept-element):]

 1. [*Name From Content Reset:* Set the
 `accumulated text` to the empty
 string.]
 2. [*Name From Generated Content:* Check for
 [CSS] generated
 textual content associated with the `current node` and
 include it in the `accumulated text`. The [CSS] [`::before` and
 `::after`](https://www.w3.org/TR/selectors-3/#gen-content)
 pseudo elements
 \[[CSS2](#bib-css2 "Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification")\] can provide textual content for
 [elements](https://dom.spec.whatwg.org/#concept-element) that have a content model, in addition to the
 [`::marker`](https://www.w3.org/TR/css-pseudo-4/#selectordef-marker)
 pseudo element.]
 1. [For `::marker` pseudo elements, [User
 agents](https://infra.spec.whatwg.org/#user-agent) *MUST* prepend [CSS] textual content, without
 a space, to the textual content of the `current node` if
 the `current node` supports
 `::marker`.]
 2. [For `::before` pseudo elements, [User
 agents](https://infra.spec.whatwg.org/#user-agent) *MUST* prepend [CSS] textual content, without
 a space, to the textual content of the
 `current node`.]
 3. [For `::after` pseudo elements, [User
 agents](https://infra.spec.whatwg.org/#user-agent) *MUST* append [CSS] textual content, without
 a space, to the textual content of the
 `current node`.]
 3. [*Determine Child Nodes:* Determine the
 `rendered child nodes` of the
 `current node`:]
 1. [If the `current node` has an attached [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root),
 set the `rendered child nodes` to be the child nodes of
 the [shadow
 root](https://dom.spec.whatwg.org/#concept-shadow-root).]
 2. [Otherwise, if the `current node` is a
 [slot](https://dom.spec.whatwg.org/#concept-slot)
 with [assigned
 nodes](https://dom.spec.whatwg.org/#slot-assigned-nodes),
 set the `rendered child nodes` to be the [assigned
 nodes](https://dom.spec.whatwg.org/#slot-assigned-nodes)
 of the
 `current node`.]
 3. [Otherwise, set the `rendered child nodes` to be the
 child nodes of the
 `current node`.]
 4. [*Name From Each Child:* For each
 `rendered child node` of the
 `current node`:]
 1. [Set the `current node` to the
 `rendered child node`.]
 2. [Compute the text alternative of the
 `current node` beginning with the overall
 [Computation](#comp_computation) step. Set the `result`
 to that text
 alternative.]
 3. [Append the `result` to the
 `accumulated text`.]
 5. [Return the `accumulated text` if it is not
 the empty string (\"\").]

 **Important**: Each
 [node](https://dom.spec.whatwg.org/#concept-node) in the subtree is consulted only once. If text has
 been collected from a descendant, but is referenced by another
 IDREF in some descendant node, then that second, or subsequent,
 reference is not followed. This is done to avoid infinite loops.

 :::::
 :::
 Note
 :::

 :::
 This step can apply to the child nodes themselves, which means
 the computation is recursive and results in text collected from
 all the elements in the `current node`\'s subtree, no matter how
 deep it is. However, any given descendant
 [node\'s](https://dom.spec.whatwg.org/#concept-node) text alternative can result from higher precedent
 markup described in steps B through D above, where \"Namefrom:
 author\" attributes provide the text alternative for the entire
 subtree.
 :::
 :::::

 :::::
 :::
 Note
 :::

 :::
 18 January 2024: The ARIA Working Group is considering the
 feasibility of joining text strings with and without spaces,
 depending on the [CSS]
 `display` value of the `current node`, and its adjacent nodes
 and pseudo-elements. The ongoing discussion is in [AccName
 #225](https://github.com/w3c/accname/issues/225).
 :::
 :::::

 7. [*Text Node:* Otherwise, if the `current node` is a
 [text
 node](https://dom.spec.whatwg.org/#exclusive-text-node), return its textual
 contents.]

 8. [*Recursive Name From Content:* Otherwise, if the
 `current node` is a descendant of an element whose [Accessible
 Name](#dfn-accessible-name) or
 [Accessible
 Description](#dfn-accessible-description) is being
 computed, and contains descendants, proceed to [Name From
 Content
 Reset](#comp_name_from_content_reset).]

 9. [*Tooltip:* Otherwise, if the `current node` has a
 [Tooltip
 attribute](#dfn-tooltip-attribute), return its
 value.]

 :::::
 :::
 Note
 :::

 :::
 Tooltip attributes are used only if nothing else, including
 subtree content, has provided results.
 :::
 :::::

 10. [Append a space character and the `result` of each step above to
 the `total accumulated text`.]
3. [After all steps are completed, the `total accumulated text` is used
 as the [accessible
 name](#dfn-accessible-name) or [accessible
 description](#dfn-accessible-description) of the
 [element](https://dom.spec.whatwg.org/#concept-element)
 that initiated the computation.]

::: header-wrapper
## 5. Accessible Name and Description Mapping

Information concerning name and description accessibility [API] mappings, including
relationships, such as labelled-by/label-for and
described-by/description-for, is documented in the [Core Accessibility
[API]
Mappings](https://w3c.github.io/aria/core-aam/)
specification
\[[CORE-AAM-1.2](#bib-core-aam-1-2 "Core Accessibility API Mappings 1.2")\]. See the mapping table entries for
[`aria-label`](https://w3c.github.io/aria/core-aam/#ariaLabel),
[`aria-labelledby`](https://w3c.github.io/aria/core-aam/#ariaLabelledBy),
and
[`aria-describedby`](https://w3c.github.io/aria/core-aam/#ariaDescribedBy).

::: header-wrapper
## 6. Appendices

::: header-wrapper
### 6.1 Change Log

::: header-wrapper
#### 6.1.1 Substantive changes since the last public working draft

- [Add steps for shadow roots and
 slots](https://github.com/w3c/accname/commit/67ca225)
 ([#167](https://github.com/w3c/accname/pull/167))
- [Fixed handling of surrounding whitespace for [CSS] pseudo elements, inline and block
 level elements, and embedded
 widgets](https://github.com/w3c/accname/commit/b05bdac)
- [update accname \'flash screen\' example to use native clickable label
 element](https://github.com/w3c/accname/commit/681094c)
- [Clarify description computation for
 aria-describedby](https://github.com/w3c/accname/commit/881d960)
 ([#177](https://github.com/w3c/accname/pull/177))
- [Add support for
 aria-description](https://github.com/w3c/accname/commit/81361ec)
 ([#69](https://github.com/w3c/accname/pull/69))
- [Temporary revert within step 2H to reference 2F.i instead of 2F until
 logic can be drafted to correctly handle roles that should not be
 traversed.](https://github.com/w3c/accname/commit/bb65de3)
- [Remove label in Step
 2E](https://github.com/w3c/accname/commit/c01d761)
- [Specify behavior when following a hidden subtree via aria-labelledby
 or -describedby](https://github.com/w3c/accname/commit/3efa7de)
- [add accessible name & desc
 definitions](https://github.com/w3c/accname/commit/65a6358)
- [\* Move tooltip def to
 accname](https://github.com/w3c/accname/commit/82a5087)
- [removed menu button example from step
 2C](https://github.com/w3c/accname/commit/a2a7039)
- [updated step 2c prose for
 consistency](https://github.com/w3c/accname/commit/8e1d42f)
- [reorder computation
 steps](https://github.com/w3c/accname/commit/ef5724a)
- [Only use accumulated text that is not empty
 (\"\")](https://github.com/w3c/accname/commit/fe3a05d)
- [add name from
 prohibited](https://github.com/w3c/accname/commit/1f451d6)
- [change normative references to informative in
 abstract](https://github.com/w3c/accname/commit/af10971)
- [Update the algorithm to handle roles where naming is not
 supported](https://github.com/w3c/accname/commit/45dbaa2)
 ([#53](https://github.com/w3c/accname/pull/53))

::: header-wrapper
#### 6.1.2 Substantive changes since the [Accessible Name and Description Computation 1.1 Recommendation](https://www.w3.org/TR/accname-1.1/)

- 27-June-2019: Add statement allowing for the possibility of naming
 being prohibited on the root node. Note: This change in and of itself
 has no implementation impact, but it allows other specifications to
 optionally prohibit naming for a top-level element. Furthermore, even
 if this prohibition is made within a specification, that prohibition
 will not have any impact on calculating name from contents.

::: header-wrapper
### 6.2 Acknowledgments

*This section is non-normative.*

The following people contributed to the development of this document.

- [Aaron Leventhal](https://github.com/aleventhal)
- [Adam Page](https://github.com/adampage)
- [Carolyn MacLeod](https://github.com/carmacleod)
- [Cynthia Shelly](https://github.com/cyns)
- [Daniel Montalvo](https://github.com/daniel-montalvo)
- [Jacobo Aragunde Pérez](https://github.com/jaragunde)
- [JaEun Jemma Ku](https://github.com/a11ydoer)
- [James Craig](https://github.com/cookiecrook)
- [James Nurthen](https://github.com/jnurthen)
- [Jason Kiss](https://github.com/jasonkiss)
- [joanmarie](https://github.com/joanmarie)
- [Joseph Scheuhammer](https://github.com/klown)
- [Kasper Isager Dalsgarð](https://github.com/kasperisager)
- [Marcos Cáceres](https://github.com/marcoscaceres)
- [Nolan Lawson](https://github.com/nolanlawson)
- [Oisín Nolan](https://github.com/OisinNolan)
- [Patrick H. Lauke](https://github.com/patrickhlauke)
- [Peter Krautzberger](https://github.com/pkra)
- [Philippe Le Hegaret](https://github.com/plehegar)
- [Richard Schwerdtfeger](https://github.com/richschwer)
- [Scott O\'Hara](https://github.com/scottaohara)
- [Sebastien Stettler](https://github.com/billybonks)
- [Valerie Young](https://github.com/spectranaut)

::: header-wrapper
#### 6.2.1 ARIA WG participants at the time of publication

- Rahim Abdi (Apple Inc.)
- NAVYA AGARWAL (Adobe)
- Joey Arhar (Google LLC)
- Bernardo Barlach (Google LLC)
- Benjamin Beaudry (Microsoft Corporation)
- Zoë Bijl ([W3C] Invited
 Experts)
- Gautier Chomel (EDRLab)
- Aleksandar Cindrikj (Netcetera)
- Keith Cirkel (Mozilla Foundation)
- Daniel Clark (Microsoft Corporation)
- James Craig (Apple Inc.)
- Diego Della Rossa (UsableNet)
- Joanmarie Diggs (Igalia)
- Tamsin Ewing ([W3C])
- Mayuri Faldu (Navy Federal Credit Union)
- Betsy Fanning (PDF Association)
- Steve Faulkner (TetraLogical Services Ltd)
- Patrick Foster (axes4 GmbH)
- Jane Fulton (Cisco)
- Bryan Garaventa ([W3C]
 Invited Experts)
- Matt Garrish (DAISY Consortium)
- Doug Geoffray (Microsoft Corporation)
- Ariella Gilmore (IBM Corporation)
- Taylore Givens (Microsoft Corporation)
- David Grogan (Google LLC)
- Shirisha Gubba ([W3C] Invited
 Experts)
- Jon Gunderson (University of Illinois)
- Oliver Habersetzer (SAP SE)
- Theo Hale ([W3C] Invited
 Experts)
- Sunny Hardasani (Adobe)
- Matthew Hardy (Adobe)
- Chris Harrelson (Google LLC)
- Sarah Higley (Microsoft Corporation)
- Hans Hillen (TPGi)
- takumi hiramatsu (Cybozu)
- Stanley Hon (Microsoft Corporation)
- Michael Jackson (Microsoft Corporation)
- John Jansen (Microsoft Corporation)
- Jilin Jiang (Ant Group Co., Ltd.)
- Duff Johnson (PDF Association)
- Summer Jones (Thomson Reuters Corp.)
- Yuki Kamahori (Cybozu)
- William Kilian (Kilian Codes LLC)
- Matthew King ([W3C] Invited
 Experts)
- Zachary Kinsey (TargetStream Technologies)
- Daisuke Kobayashi (Cybozu)
- Peter Krautzberger (krautzource UG)
- Nina Krauß (SAP SE)
- JaEun Jemma Ku (University of Illinois)
- Steven Lambert (Deque Systems, Inc.)
- Joe Lamyman (TetraLogical Services Ltd)
- Charles LaPierre (Benetech)
- Patrick Lauke (TetraLogical Services Ltd)
- Philip Lazarevic (Level Access)
- Leo Lee (Microsoft Corporation)
- Brett Lewis (TPGi)
- Alison Maher (Microsoft Corporation)
- Gurpreet Kaur Mangera (Rakuten Group, Inc.)
- Mark McCarthy (University of Illinois)
- Katie McDermott (See Me Please)
- Eduardo Meza Etienne (Navy Federal Credit Union)
- Clay Miller (Microsoft Corporation)
- Hirotaka Minamida (Cybozu)
- Daniel Montalvo ([W3C])
- Baldino Morelli (UsableNet)
- Jacques Newman (Microsoft Corporation)
- James Nurthen (Evinced Inc.)
- Scott O\'Hara (Microsoft Corporation)
- Lola Odelola ([W3C] Invited
 Experts)
- Neil Osman (Evinced Inc.)
- Yusuke Oyama (Cybozu)
- Adam Page (Hilton)
- Michael Pennisi (Igalia)
- Giacomo Petri (UsableNet)
- Noah Praskins (TPGi)
- Lucas Radaelli (Google LLC)
- Paul Rayius (PDFix-US)
- Mark Rogers (Powermapper Software)
- Adrian Roselli ([W3C] Invited
 Experts)
- Marco Sabidussi (UsableNet)
- Trisha Salas (Level Access)
- Stefan Schnabel (SAP SE)
- Harris Schneiderman (Deque Systems, Inc.)
- Raymond Schwartz (Navy Federal Credit Union)
- Kyra Seevers (Google LLC)
- Davis Shaver (The Washington Post)
- Cynthia Shelly ([W3C] Invited
 Experts)
- Tzviya Siegman ([W3C])
- Avneesh Singh (DAISY Consortium)
- Michael\[tm\] Smith (sideshowbarker) ([W3C])
- Francis Storr (Intel Corporation)
- Nobukiyo Sugisaki (Cybozu)
- Melanie Sumner (IBM Corporation)
- Alexander Surkov (Igalia)
- James Teh (Mozilla Foundation)
- Roman Toda (Foxit software)
- David Tseng (Google LLC)
- Cybozu [W3C] (Cybozu)
- Tyler Wilcock (Apple Inc.)
- Jan Williams (TPGi)

::: header-wrapper
#### 6.2.2 Enabling funders

This publication has been funded in part with U.S. Federal funds from
the Department of Education, National Institute on Disability,
Independent Living, and Rehabilitation Research (NIDILRR), initially
under contract number ED-OSE-10-C-0067, then under contract number
HHSP23301500054C, and now under HHS75P00120P00168. The content of this
publication does not necessarily reflect the views or policies of the
U.S. Department of Education, nor does mention of trade names,
commercial products, or organizations imply endorsement by the U.S.
Government.

::: header-wrapper
## A. References

::: header-wrapper
### A.1 Normative references

\[CORE-AAM-1.2\]
: [Core Accessibility API Mappings
 1.2](https://www.w3.org/TR/core-aam-1.2/). Valerie Young; Cynthia
 Shelly. W3C. 23 September 2026. CRD. URL:
 <https://www.w3.org/TR/core-aam-1.2/>

\[CSS2\]
: [Cascading Style Sheets Level 2 Revision 1 (CSS 2.1)
 Specification](https://www.w3.org/TR/CSS2/). Bert Bos; Tantek Çelik;
 Ian Hickson; Håkon Wium Lie. W3C. 7 June 2011. W3C Recommendation.
 URL: <https://www.w3.org/TR/CSS2/>

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[html-aam-1.0\]
: [HTML Accessibility API Mappings
 1.0](https://www.w3.org/TR/html-aam-1.0/). Scott O\'Hara; Rahim
 Abdi. W3C. 5 October 2026. W3C Working Draft. URL:
 <https://www.w3.org/TR/html-aam-1.0/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/info/rfc2119/). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc2119/>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/info/rfc8174/). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/info/rfc8174/>

\[WAI-ARIA\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.1](https://www.w3.org/TR/wai-aria-1.1/). Joanmarie Diggs; Shane
 McCarron; Michael Cooper; Richard Schwerdtfeger; James Craig. W3C.
 14 December 2017. W3C Recommendation. URL:
 <https://www.w3.org/TR/wai-aria-1.1/>

::: header-wrapper
### A.2 Informative references

\[ACCNAME-1.1\]
: [Accessible Name and Description Computation
 1.1](https://www.w3.org/TR/accname-1.1/). Joanmarie Diggs; Bryan
 Garaventa; Michael Cooper. W3C. 18 December 2018. W3C
 Recommendation. URL: <https://www.w3.org/TR/accname-1.1/>

\[wai-aria-1.2\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.2](https://www.w3.org/TR/wai-aria-1.2/). Joanmarie Diggs; James
 Nurthen; Michael Cooper; Carolyn MacLeod. W3C. 6 June 2023. W3C
 Recommendation. URL: <https://www.w3.org/TR/wai-aria-1.2/>

[[↑]](#title)

[Permalink](#dfn-assistive-technologies)

**Referenced in:**

- [§ Abstract](#ref-for-dfn-assistive-technologies-1 "§ Abstract")
- [§ 2. Important
 Terms](#ref-for-dfn-assistive-technologies-2 "§ 2. Important Terms")
- [§ 4.3.2 Computation
 steps](#ref-for-dfn-assistive-technologies-3 "§ 4.3.2 Computation steps")

[Permalink](#dfn-accessible-description)
[exported]

**Referenced in:**

- [§ Abstract](#ref-for-dfn-accessible-description-1 "§ Abstract")
- [§ 1.
 Introduction](#ref-for-dfn-accessible-description-2 "§ 1. Introduction")
- [§ 2. Important
 Terms](#ref-for-dfn-accessible-description-3 "§ 2. Important Terms")
- [§ 4.2 Description
 Computation](#ref-for-dfn-accessible-description-4 "§ 4.2 Description Computation")
- [§ 4.3 Text Equivalent
 Computation](#ref-for-dfn-accessible-description-5 "§ 4.3 Text Equivalent Computation")
- [§ 4.3.2 Computation
 steps](#ref-for-dfn-accessible-description-6 "§ 4.3.2 Computation steps")
 [(2)](#ref-for-dfn-accessible-description-7 "Reference 2")
 [(3)](#ref-for-dfn-accessible-description-8 "Reference 3")
 [(4)](#ref-for-dfn-accessible-description-9 "Reference 4")

[Permalink](#dfn-accessible-name)
[exported]

**Referenced in:**

- [§ Abstract](#ref-for-dfn-accessible-name-1 "§ Abstract")
- [§ 1.
 Introduction](#ref-for-dfn-accessible-name-2 "§ 1. Introduction")
- [§ 2. Important
 Terms](#ref-for-dfn-accessible-name-3 "§ 2. Important Terms")
- [§ 4.1 Name
 Computation](#ref-for-dfn-accessible-name-4 "§ 4.1 Name Computation")
- [§ 4.3 Text Equivalent
 Computation](#ref-for-dfn-accessible-name-5 "§ 4.3 Text Equivalent Computation")
- [§ 4.3.2 Computation
 steps](#ref-for-dfn-accessible-name-6 "§ 4.3.2 Computation steps")
 [(2)](#ref-for-dfn-accessible-name-7 "Reference 2")
 [(3)](#ref-for-dfn-accessible-name-8 "Reference 3")
 [(4)](#ref-for-dfn-accessible-name-9 "Reference 4")
 [(5)](#ref-for-dfn-accessible-name-10 "Reference 5")
 [(6)](#ref-for-dfn-accessible-name-11 "Reference 6")
 [(7)](#ref-for-dfn-accessible-name-12 "Reference 7")
 [(8)](#ref-for-dfn-accessible-name-13 "Reference 8")
 [(9)](#ref-for-dfn-accessible-name-14 "Reference 9")

[Permalink](#dfn-tooltip-attribute)

**Referenced in:**

- [§ 4.3.2 Computation
 steps](#ref-for-dfn-tooltip-attribute-1 "§ 4.3.2 Computation steps")
