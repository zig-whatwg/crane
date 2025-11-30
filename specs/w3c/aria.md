
[![W3C](https://www.w3.org/StyleSheets/TR/2021/logos/W3C){crossorigin=""
height="48" width="72"}](https://www.w3.org/)

# Accessible Rich Internet Applications (WAI-ARIA) 1.3

[W3C Editor\'s Draft](https://www.w3.org/standards/types#ED) 23 October
2025

More details about this document

This version:
: [https://w3c.github.io/aria/](https://w3c.github.io/aria/)

Latest published version:
: <https://www.w3.org/TR/wai-aria-1.3/>

Latest editor\'s draft:
: <https://w3c.github.io/aria/>

History:
: <https://www.w3.org/standards/history/wai-aria-1.3/>
: [Commit history](https://github.com/w3c/aria/commits/)

Latest Recommendation:
: <https://www.w3.org/TR/wai-aria/>

Editors:
: [James Nurthen] ([Adobe](https://www.adobe.com/))
: [Peter Krautzberger] ([krautzource
 UG](https://www.krautzource.com))
: [Daniel Montalvo] ([W3C](https://www.w3.org))

Former editors:
: [Michael Cooper] ([W3C](https://www.w3.org)) (Editor until 2023)
: [Joanmarie Diggs] ([Igalia,
 S.L.](https://www.igalia.com)) (Editor until
 2021)
: [Shane McCarron] ([Spec-Ops])
 (Editor until 2018)
: [Richard Schwerdtfeger]
 ([Knowbility](https://knowbility.org/)) (Editor
 until October 2017)
: [James Craig] ([Apple
 Inc.](https://www.apple.com/accessibility))
 (Editor until May 2016)

Feedback:
: [GitHub w3c/aria](https://github.com/w3c/aria/) ([pull
 requests](https://github.com/w3c/aria/pulls/), [new
 issue](https://github.com/w3c/aria/issues/new/choose), [open
 issues](https://github.com/w3c/aria/issues/))

[Copyright](https://www.w3.org/policies/#copyright) © 2013-2025 [World
Wide Web Consortium](https://www.w3.org/). [W3C]^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document
license](https://www.w3.org/copyright/software-license-2023/ "W3C Software and Document Notice and License"){rel="license"}
rules apply.

------------------------------------------------------------------------

## Abstract

Accessibility of web content requires semantic information about
widgets, structures, and behaviors, in order to allow assistive
technologies to convey appropriate information to persons with
disabilities. This specification provides an ontology of roles, states,
and properties that define accessible user interface elements and can be
used to improve the accessibility and interoperability of web content
and applications. These semantics are designed to allow an author to
properly convey user interface behaviors and structural information to
assistive technologies in document-level markup. This version adds
features new since [WAI-ARIA] 1.1
\[[wai-aria-1.1](#bib-wai-aria-1.1 "Accessible Rich Internet Applications (WAI-ARIA) 1.1")\] to improve interoperability with assistive
technologies to form a more consistent accessibility model for
\[[HTML](#bib-html "HTML Standard")\] and
\[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\]. This specification complements both
\[[HTML](#bib-html "HTML Standard")\] and
\[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\].

This document is part of the [WAI-ARIA] suite described in the
[[WAI-ARIA]
Overview](https://www.w3.org/WAI/standards-guidelines/aria/).

## Status of This Document

*This section describes the status of this document at the time of its
publication. A list of current [W3C] publications and the latest revision
of this technical report can be found in the [[W3C] standards and drafts
index](https://www.w3.org/TR/).*

The Accessible Rich Internet Applications Working Group seeks feedback
on any aspect of the specification. When submitting feedback, please
consider issues in the context of the companion documents. To comment,
[file an issue in the [W3C]
[ARIA] GitHub
repository](https://github.com/w3c/aria/issues/new). If this is not
feasible, send email to
[public-aria@w3.org](mailto:public-aria@w3.org?subject=Comment%20on%20WAI-ARIA%201.2)
([comment archive](https://lists.w3.org/Archives/Public/public-aria/)).
In-progress updates to the document can be viewed in the [publicly
visible editors\' draft](https://w3c.github.io/aria/).

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
3. [1. Introduction](#introduction)
 1. [1.1 Rich Internet Application
 Accessibility](#intro_ria_accessibility)
 2. [1.2 Target Audience](#target-audience)
 3. [1.3 User Agent Support](#ua-support)
 4. [1.4 Co-Evolution of [WAI-ARIA] and Host
 Languages](#co-evolution)
 5. [1.5 Authoring Practices](#authoring_practices)
 1. [1.5.1 Authoring Tools](#authoring_tools)
 2. [1.5.2 Testing Practices and
 Tools](#authoring_testing)
 6. [1.6 Assistive Technologies](#at_support)
4. [2. Important Terms](#terms)
5. [3. Conformance](#conformance)
 1. [3.1 Non-interference with the Host
 Language](#ua_noninterference)
 2. [3.2 All [WAI-ARIA] in [DOM]](#ua_dom)
 3. [3.3 Assistive Technology Notifications Communicated to Web
 Applications](#ua_domchanges)
 4. [3.4 Conformance Checkers](#conformance_checkers)
 5. [3.5 Deprecated Requirements](#deprecated)
6. [4. Using [WAI-ARIA]](#usage)
 1. [4.1 [WAI-ARIA]
 Roles](#introroles)
 2. [4.2 [WAI-ARIA] States and
 Properties](#introstates)
 3. [4.3 Managing Focus and Supporting Keyboard
 Navigation](#managingfocus)
 1. [4.3.1 Information for
 Authors](#managingfocus_authors)
 2. [4.3.2 Information for User
 Agents](#managingfocus_useragents)
7. [5. The Roles Model](#roles)
 1. [5.1 Relationships Between
 Concepts](#relationshipsconcepts)
 1. [5.1.1 Superclass Role](#superclassrole)
 2. [5.1.2 Subclass Roles](#subclassroles)
 3. [5.1.3 Related Concepts](#relatedConcept)
 4. [5.1.4 Base Concept](#baseConcept)
 2. [5.2 Characteristics of Roles](#Properties)
 1. [5.2.1 Abstract Roles](#isAbstract)
 2. [5.2.2 Required States and
 Properties](#requiredState)
 3. [5.2.3 Supported States and
 Properties](#supportedState)
 4. [5.2.4 Inherited States and
 Properties](#inheritedattributes)
 5. [5.2.5 Prohibited States and
 Properties](#prohibitedattributes)
 6. [5.2.6 Allowed Accessibility Child
 Roles](#mustContain)
 7. [5.2.7 Required Accessibility Parent Role](#scope)
 8. [5.2.8 Name From](#namecalculation)
 1. [5.2.8.1 Roles Supporting Name from
 Author](#namefromauthor)
 2. [5.2.8.2 Roles Supporting Name from
 Content](#namefromcontent)
 3. [5.2.8.3 Roles which cannot be named (Name
 prohibited)](#namefromprohibited)
 9. [5.2.9 Children
 Presentational](#childrenArePresentational)
 10. [5.2.10 Implicit Value for
 Role](#implictValueForRole)
 3. [5.3 Categorization of Roles](#roles_categorization)
 1. [5.3.1 Abstract Roles](#abstract_roles)
 2. [5.3.2 Widget Roles](#widget_roles)
 3. [5.3.3 Document Structure
 Roles](#document_structure_roles)
 4. [5.3.4 Landmark Roles](#landmark_roles)
 5. [5.3.5 Live Region Roles](#live_region_roles)
 6. [5.3.6 Window Roles](#window_roles)
 4. [5.4 Definition of Roles](#role_definitions)
8. [6. Supported States and
 Properties](#states_and_properties)
 1. [6.1 Clarification of States versus
 Properties](#statevsprop)
 2. [6.2 Characteristics of States and
 Properties](#state_prop_att)
 1. [6.2.1 Related
 Concepts](#propcharacteristic_relatedconcept)
 2. [6.2.2 Used in
 Roles](#propcharacteristic_usedinrole)
 3. [6.2.3 Inherits into
 Roles](#propcharacteristic_inheritsintoroles)
 4. [6.2.4 Value](#propcharacteristic_value)
 3. [6.3 [ARIA]
 Attributes](#aria-attributes)
 1. [6.3.1 Multi-value Attribute
 Values](#enumerated-attribute-values)
 2. [6.3.2 IDL reflection of [ARIA]
 attributes](#idl-reflection-attribute-values)
 3. [6.3.3 Operating System Accessibility [API] mapping of
 multi-value [ARIA]
 attributes](#os-aapi-attribute-mapping)
 4. [6.3.4 [ARIA] nullable
 DOMString
 Attributes](#enumerated-attribute-values-html)
 1. [6.3.4.1 Example Attribute
 Usage](#enumeration-example)
 4. [6.4 Translatable
 Attributes](#translatable-attributes)
 5. [6.5 Global States and Properties](#global_states)
 6. [6.6 Taxonomy of [WAI-ARIA] States and
 Properties](#state_prop_taxonomy)
 1. [6.6.1 Widget Attributes](#attrs_widgets)
 2. [6.6.2 Live Region Attributes](#attrs_liveregions)
 3. [6.6.3 Drag-and-Drop Attributes](#attrs_dragdrop)
 4. [6.6.4 Relationship
 Attributes](#attrs_relationships)
 7. [6.7 State change notification](#state_changes)
 8. [6.8 Definitions of States and Properties (all aria-\*
 attributes)](#state_prop_def)
9. [7. [Accessibility Tree]](#accessibility_tree)
 1. [7.1 Excluding Elements from the Accessibility
 Tree](#tree_exclusion)
 2. [7.2 Including Elements in the Accessibility
 Tree](#tree_inclusion)
 3. [7.3 Relationships in the Accessibility
 Tree](#tree_relationships)
10. [8. Implementation in Host Languages](#host_languages)
 1. [8.1 Role Attribute](#host_general_role)
 2. [8.2 State and Property
 Attributes](#host_general_attrs)
 3. [8.3 Focus Navigation](#host_general_focus)
 4. [8.4 Implicit [WAI-ARIA]
 Semantics](#implicit_semantics)
 5. [8.5 Conflicts with Host Language
 Semantics](#host_general_conflict)
 6. [8.6 State and Property Attribute
 Processing](#state_property_processing)
 1. [8.6.1 ID Reference Error
 Processing](#mapping_additional_relations_error_processing)
 7. [8.7 [CSS]
 Selectors](#document-handling_css-selectors)
11. [9. Handling Author
 Errors](#document-handling_author-errors)
 1. [9.1 Roles](#document-handling_author-errors_roles)
 2. [9.2 States and
 Properties](#document-handling_author-errors_states-properties)
 3. [9.3 Presentational Roles Conflict
 Resolution](#conflict_resolution_presentation_none)
12. [10. IDL Interface](#idl-interface)
 1. [10.1 Interface Mixin [`ARIAMixin`]{
 idl="interface mixin"
 }](#ARIAMixin)
 2. [10.2 [ARIA] Attribute
 Correspondence](#accessibilityroleandproperties-correspondence)
 1. [10.2.1 Disambiguation
 Pattern](#idl_attr_disambiguation)
 2. [10.2.2 IDL Attribute Name Notes or
 Exceptions](#idl_attr_exceptions)
 3. [10.3 Example IDL Attribute Usage](#idl_example_usage)
13. [11. Security Considerations](#security-considerations)
14. [12. Privacy Considerations](#privacy-considerations)
15. [A. Mapping [WAI-ARIA] Value types to
 languages](#typemapping)
16. [B. Change Log](#changelog)
 1. [B.1 Major feature in this
 release](#major-feature-in-this-release)
 2. [B.2 Substantive changes since [ARIA]
 1.2](#substantive-changes-since-aria-1-2)
17. [C. Acknowledgments](#acknowledgements)
 1. [C.1 [ARIA]
 WG participants at the time of
 publication](#ack_group)
 2. [C.2 Enabling funders](#ack_funders)
18. [D. References](#references)
 1. [D.1 Normative references](#normative-references)
 2. [D.2 Informative references](#informative-references)

::: header-wrapper
## 1. Introduction

*This section is non-normative.*

The goals of this specification include:

- expanding the accessibility information that can be supplied by the
 author;
- requiring that supporting host languages provide full keyboard support
 that can be implemented in a device-independent way, for example, by
 telephones, handheld devices, e-book readers, and televisions;
- improving the accessibility of dynamic content generated by scripts;
 and
- providing for interoperability with [assistive
 technologies](#assistive-technology).

[WAI-ARIA] is a
technical specification that provides a framework to improve the
accessibility and interoperability of web content and applications. This
document is primarily for developers creating custom widgets and other
web application components. Please see the [[WAI-ARIA]
Overview](https://www.w3.org/WAI/standards-guidelines/aria/) for links
to related documents for other audiences, such as [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/) that introduces developers to
the accessibility problems that [WAI-ARIA] is intended to solve, the
fundamental concepts, and the technical approach of [WAI-ARIA].

This document currently handles two aspects of
[roles](#dfn-role):
user interface functionality and structural
[relationships](#dfn-relationship). For more information and use cases, see
[[ARIA] Authoring
Practices Guide](https://www.w3.org/WAI/ARIA/apg/) for the use of roles
in making interactive content accessible.

Roles defined by this specification are designed to support the roles
used by platform [accessibility [APIs]](#dfn-accessibility-api). Declaration of these roles on elements
within dynamic web content is intended to support interoperability
between the web content and assistive technologies that utilize
[accessibility [APIs]](#dfn-accessibility-api).

The schema to support this standard has been designed to be extensible
so that custom roles can be created by extending base roles. This allows
[user
agents](https://infra.spec.whatwg.org/#user-agent) to
support at least the base role, and user agents that support the custom
role can provide enhanced access. Note that much of this could be
formalized in
\[[XMLSCHEMA11-2](#bib-xmlschema11-2 "W3C XML Schema Definition Language (XSD) 1.1 Part 2: Datatypes")\]. However, being able to define similarities
between roles, such as [baseConcepts](#baseConcept) and more descriptive
definitions, would not be available in [XSD].

[WAI-ARIA] 1.2 is a
member of the [[WAI-ARIA] 1.2
suite](https://www.w3.org/WAI/intro/aria) that defines how to expose
semantics of [WAI-ARIA] and other web content
languages to [accessibility [APIs]](#dfn-accessibility-api).

::: header-wrapper
### 1.1 Rich Internet Application Accessibility

The domain of web accessibility defines how to make web content usable
by persons with disabilities. Persons with certain types of disabilities
use [assistive
technologies](#assistive-technology) ([AT]) to interact with content. Assistive
technologies can transform the presentation of content into a format
more suitable to the user, and can allow the user to interact in
different ways. For example, the user might need to, or choose to,
interact with a slider widget via arrow keys, instead of dragging and
dropping with a mouse. In order to accomplish this effectively, the
software needs to understand the
[semantics](#dfn-semantics) of the content. Semantics is the science of meaning; in
this case, used to assign roles, states, and properties that apply to
user interface and content elements as a human would understand. For
instance, if a paragraph is semantically identified as such, assistive
technologies can interact with it as a unit separable from the rest of
the content, knowing the exact boundaries of that paragraph. An
adjustable range slider or collapsible list (a.k.a. a tree
[widget](#dfn-widget)) are more complex examples, in which various parts of
the widget have semantics that need to be properly identified for
assistive technologies to support effective interaction.

New technologies often overlook semantics required for accessibility,
and new authoring practices often misuse the intended semantics of those
technologies.
[Elements](https://dom.spec.whatwg.org/#concept-element)
that have one defined meaning in the language are used with a different
meaning intended to be understood by the user.

For example, web application developers create collapsible tree widgets
in [HTML] using [CSS] and JavaScript even though [HTML] has no semantic `tree` element. To a
non-disabled user, it might look and act like a collapsible tree widget,
but without appropriate semantics, the tree widget might not be
[perceivable](#dfn-perceivable) to, or
[operable](#dfn-operable) by, a person with a disability because assistive
technologies might not recognize the role. Similarly, web application
developers create interactive button widgets in [SVG] using JavaScript even though
[SVG] has no semantic `button`
element. To a non-disabled user, it might look and act like a button
widget, but without appropriate semantics, the button widget might not
be [perceivable](#dfn-perceivable) to, or
[operable](#dfn-operable) by, a person with a disability because assistive
technologies might not recognize the role.

The incorporation of [WAI-ARIA] is a way for an author to
provide proper semantics for custom widgets to make these widgets
accessible, usable, and interoperable with assistive technologies. This
specification identifies the types of widgets and structures that are
commonly recognized by accessibility products, by providing an
[ontology](#dfn-ontology) of corresponding [roles](#dfn-role) that can be attached to content. This
allows elements with a given role to be understood as a particular
widget or structural type regardless of any semantics inherited from the
implementing [host
language](#dfn-host-language). Roles are a common property of platform [accessibility
[APIs]](#dfn-accessibility-api) which assistive technologies use to
provide the user with effective presentation and interaction.

The Roles Model includes interaction
[widgets](#dfn-widget) and elements denoting document structure. The Roles
Model describes inheritance and details the
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
each role supports. Information about mapping of roles to accessibility
[APIs] is provided by
the [Core Accessibility [API]
Mappings](https://w3c.github.io/core-aam/)
\[[CORE-AAM-1.2](#bib-core-aam-1.2 "Core Accessibility API Mappings 1.2")\].

Roles are element types and will not change with time or user actions.
Role information is used by assistive technologies, through interaction
with the user agent, to provide normal processing of the specified
element type.

States and properties are used to declare important attributes of an
element that affect and describe interaction. They enable the [user
agent](https://infra.spec.whatwg.org/#user-agent) and
operating system to properly handle the element even when the attributes
are dynamically changed by client-side scripts. For example, alternative
input and output technology, such as screen readers and speech dictation
software, need to be able to recognize and effectively manipulate and
communicate various interaction states (e.g., disabled, checked) to the
user.

While it is possible for assistive technologies to access these
properties directly through the [Document Object
Model](https://dom.spec.whatwg.org/)
\[[DOM](#bib-dom "DOM Standard")\], the
preferred mechanism is for the user agent to map the states and
properties to the accessibility [API] of the operating system. See
the [Core Accessibility [API]
Mappings](https://w3c.github.io/core-aam/)
\[[CORE-AAM-1.2](#bib-core-aam-1.2 "Core Accessibility API Mappings 1.2")\] and the [Accessible Name and Description
Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\] for details.

[Figure
1](#fig-contractmodel "The contract model with accessibility APIs")
illustrates the relationship between user agents (e.g., browsers),
accessibility [APIs],
and assistive technologies. It describes the \"contract\" provided by
the user agent to assistive technologies, which includes typical
accessibility information found in the accessibility [API] for many of our accessible
platforms for GUIs (role, state, selection,
[event](#dfn-event)
notification,
[relationship](#dfn-relationship) information, and descriptions). The
[DOM], usually [HTML], acts as the data model and view in a
typical model-view-controller relationship, and JavaScript acts as the
controller by manipulating the style and content of the displayed data.
The user agent conveys relevant information to the operating system\'s
accessibility [API],
which can be used by any assistive technologies, such as screen readers.

![[Figure 1](#fig-contractmodel) [The contract model with
accessibility [APIs]]](img/accessibleelement.png)

For more information see [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/) for the use of roles in making
interactive content accessible.

Users of alternate input devices need [keyboard
accessible](#dfn-keyboard-accessible) content. The new semantics, when combined
with the recommended keyboard interactions provided in [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/), will allow alternate input
solutions to facilitate command and control via an alternate input
solution.

[WAI-ARIA]
introduces navigational
[landmarks](#dfn-landmark) through its Roles Model and the [XHTML] role landmarks, which can
help persons with dexterity and vision impairments by providing for
improved keyboard navigation. [WAI-ARIA] can also be used to
assist persons with cognitive learning disabilities. The additional
semantics allow authors to restructure and substitute alternative
content as needed.

[Assistive
technologies](#assistive-technology) need the ability to support alternative
inputs by getting and setting the current value of
[widget](#dfn-widget) states and properties. Assistive technologies also need
to determine what [objects](#dfn-object) are selected and manage widgets that allow
multiple selections, such as list boxes and grids.

Speech-based command and control systems can benefit from
[WAI-ARIA]
semantics like the `role` attribute to assist in conveying audio
information to the user. For example, upon encountering an element with
a role of [`menu`](https://w3c.github.io/aria/#menu)
with child elements of role
[`menuitem`](https://w3c.github.io/aria/#menuitem) each
containing text content representing a different flavor, a speech system
might state to the user, \"Select one of three choices: chocolate,
strawberry, or vanilla.\"

[WAI-ARIA] is
intended to be used as a supplement for native language semantics, not a
replacement. When the host language provides a feature that provides
equivalent accessibility to the [WAI-ARIA] feature, use the host
language feature. [WAI-ARIA] should only be used in
cases where the host language lacks the needed
[role](#dfn-role),
[state](#dfn-state),
and [property](#dfn-property) indicators. Use a host language feature
that is as similar as possible to the [WAI-ARIA] feature, then refine the
meaning by adding [WAI-ARIA]. For instance, a
multi-selectable grid could be implemented as a table, and then
[WAI-ARIA] used to
clarify that it is an interactive grid, not just a static data table.
This allows for the best possible fallback for user agents that do not
support [WAI-ARIA]
and preserves the integrity of the host language semantics.

::: header-wrapper
### 1.2 Target Audience

This specification defines the basic model for [WAI-ARIA], including roles, states,
properties, and values. It impacts several audiences:

- [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 that process content containing [WAI-ARIA] features;
- [Assistive
 technologies](#assistive-technology) that present content in special ways to
 user with disabilities;
- Authors who create content;
- Authoring tools that help authors create conforming content; and
- Conformance checkers that verify appropriate use of [WAI-ARIA].

Each conformance requirement indicates the audience to which it applies.

Although this specification is applicable to the above audiences, it is
not specifically targeted to, nor is it intended to be the sole source
of information for, any of these audiences. The following documents
provide important supporting information:

- [[ARIA] Authoring
 Practices Guide](https://www.w3.org/WAI/ARIA/apg/) addresses authoring
 recommendations for [HTML],
 and is also of interest to developers of authoring tools and
 conformance checkers.
- [Core Accessibility API Mappings
 1.2](https://www.w3.org/TR/core-aam-1.2/){matched-text="[[[CORE-AAM-1.2]]]"}
 addresses developers of [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 and [assistive
 technologies](#assistive-technology).
- [Accessible Name and Description Computation
 1.2](https://www.w3.org/TR/accname-1.2/){matched-text="[[[ACCNAME-1.2]]]"}
 also addresses developers of [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 and [assistive
 technologies](#assistive-technology).

::: header-wrapper
### 1.3 User Agent Support

[WAI-ARIA] relies
on user agent support for its features in two ways:

- Mainstream [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 use [WAI-ARIA] to
 alter how host language features are exposed to [accessibility
 [APIs]](#dfn-accessibility-api) in order to improve accessibility. The
 mechanism for this is defined in the [Core Accessibility [API]
 Mappings](https://w3c.github.io/core-aam/).
- [Assistive
 technologies](#assistive-technology) use the enhanced information available
 in an accessibility [API], or uses the
 [WAI-ARIA] markup
 directly via the [DOM], to convey
 semantic and interaction information to the user.

Aside from using [WAI-ARIA] markup to improve what is
exposed to accessibility [APIs], user agents behave as they
would natively. Assistive technologies react to the extra information in
the accessibility [API]
as they already do for the same information on non-web content. User
agents that are not assistive technologies, however, need do nothing
beyond providing appropriate updates to the accessibility [API].

The [WAI-ARIA]
specification neither requires nor forbids user agents from enhancing
native presentation and interaction behaviors on the basis of
[WAI-ARIA] markup.
Mainstream user agents might expose [WAI-ARIA] navigational landmarks
(for example, as a dialog box or through a keyboard command) with the
intention to facilitate navigation for all users. User agents are
encouraged to maximize their usefulness to users, including users
without disabilities.

[WAI-ARIA] is
intended to provide missing semantics so that the intent of the author
can be conveyed to assistive technologies. Generally, authors using
[WAI-ARIA] will
provide the appropriate presentation and interaction features. Over
time, host languages can add [WAI-ARIA] equivalents, such as new
form controls, that are implemented as standard accessible user
interface controls by the user agent. This allows authors to use them
instead of custom [WAI-ARIA] enabled user interface
components. In this case the user agent would support the native host
language feature. Developers of host languages that implement
[WAI-ARIA] are
advised to continue supporting [WAI-ARIA] semantics when they do
not adversely conflict with implicit host language semantics, as
[WAI-ARIA]
semantics more clearly reflect the intent of the author if the host
language features are inadequate to meet the author\'s needs.

::: header-wrapper
### 1.4 Co-Evolution of [WAI-ARIA] and Host Languages

[WAI-ARIA] is
intended to be used as an accessibility enhancement technology in
markup-based [host
languages](#dfn-host-language). Examples include
\[[HTML](#bib-html "HTML Standard")\] and
\[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\], which both explicitly support the use of
[ARIA].

[ARIA] roles and
properties clarify semantics to assistive technologies when authors
create new types of objects, via style and script, that are not yet
directly supported by the language of the page, because the invention of
new types of objects is faster than standardized support for them
appears in web languages.

It is not appropriate to create objects with style and script when the
host language provides a semantic element for that type of object. While
[WAI-ARIA] can
improve the accessibility of these objects, accessibility is best
provided by allowing the user agent to handle the object natively. For
example, it\'s better to use an `h1` element in [HTML] than to use the
[`heading`](https://w3c.github.io/aria/#heading) role
on a `div` element.

It is expected that, over time, host languages will evolve to provide
semantics for objects that currently can only be declared with
[WAI-ARIA]. This is
natural and desirable, as one goal of [WAI-ARIA] is to help stimulate the
emergence of more semantic and accessible markup. When native semantics
for a given feature become available, it is appropriate for authors to
use the native feature and stop using [WAI-ARIA] for that feature. Legacy
content can continue to use [WAI-ARIA], however, so the need for
user agents to support [WAI-ARIA] remains.

While specific features of [WAI-ARIA] might lose importance
over time, the general possibility of [WAI-ARIA] to add semantics to web
pages is expected to be a persistent need. Host languages might not
implement all the semantics [WAI-ARIA] provides, and various
host languages can implement different subsets of the features. New
types of objects are continually being developed, and one goal of
[WAI-ARIA] is to
provide a way to make such objects accessible, because authoring
practices often advance faster than host language standards. In this
way, [WAI-ARIA] and
host languages both evolve together but at different rates.

Some host languages exist to create semantics for features other than
the user interface. For example, [SVG] expresses the semantics behind
production of graphical objects, not of user interface components that
those objects can represent. Host languages might, by design, not
provide native semantics that map to [WAI-ARIA] features. In these cases,
[WAI-ARIA] could be
adopted as a long-term approach to add semantic information to user
interface components.

::: header-wrapper
### 1.5 Authoring Practices

::: header-wrapper
#### 1.5.1 Authoring Tools

Many of the requirements in the definitions of [WAI-ARIA]
[roles](#dfn-role),
[states](#dfn-state),
and [properties](#dfn-property) can be checked automatically during the
development process, similar to other quality control processes used for
validating code. To assist authors who are creating custom widgets,
authoring tools can compare widget roles, states, and properties to
those supported in [WAI-ARIA] as well as those
supported in related and cross-referenced roles, states, and properties.
Authoring tools can notify authors of errors in widget design patterns,
and can also prompt developers for information that cannot be determined
from context alone. For example, a scripting library can determine the
labels for the tree items in a tree view, but would need to prompt the
author to label the entire tree. To help authors visualize a logical
accessibility structure, an authoring environment might provide an
outline view of a web resource based on the [WAI-ARIA] markup.

In both [HTML] and [SVG], `tabindex` is an important way
browsers support keyboard [focus navigation](#host_general_focus) for
implementations of [WAI-ARIA]; authoring and debugging
tools can check to make sure `tabindex` values are properly set. For
example, error conditions can include cases where more than one treeitem
in a tree has a `tabindex` value greater than or equal to 0, where
`tabindex` is not set on any treeitem, or where
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
is not defined when the element with the role tree has a `tabindex`
value of greater than or equal to 0.

::: header-wrapper
#### 1.5.2 Testing Practices and Tools

The accessibility of interactive content cannot be confirmed by static
checks alone. Developers of interactive content should test for
device-independent access to
[widgets](#dfn-widget) and applications, and should verify accessibility
[API] access to all
content and changes during user interaction.

::: header-wrapper
### 1.6 Assistive Technologies

Programmatic access to accessibility semantics is essential for
assistive technologies. Most assistive technologies interact with user
agents, like other applications, through a recognized accessibility
[API]. Perceivable
objects in the user interface are exposed to assistive technologies as
accessible objects, defined by the accessibility [API] interfaces. To do this
properly, accessibility information -- role, states, properties as well
as contextual information -- needs to be accurately conveyed to the
assistive technologies through the accessibility [API]. When a state change occurs,
the user agent provides the appropriate event notification to the
accessibility [API].
Contextual information, in many host languages like [HTML], can be determined from the
[DOM] itself as it provides a
contextual tree hierarchy.

While some assistive technologies interact with these accessibility
[APIs], others might
access the content directly from the [DOM]. These technologies can restructure,
simplify, style, or reflow the content to help a different set of users.
Common use cases for these types of adaptations might be the aging
population, persons with cognitive impairments, or persons in
environments that interfere with use of their tools. For example, the
availability of regional navigational landmarks can allow for a mobile
device adaptation that shows only portions of the content at any one
time based on its semantics. This could reduce the amount of information
the user needs to process at any one time. In other situations it might
be appropriate to replace a custom user interface control with something
that is easier to navigate with a keyboard, or touch screen device.

::: header-wrapper
## 2. Important Terms

*This section is non-normative.*

While some terms are defined in place, the following definitions are
used throughout this document.

[Accessibility [API]]

: Operating systems and other platforms provide a set of interfaces
 that expose information about
 [objects](#dfn-object) and
 [events](#dfn-event) to [assistive
 technologies](#assistive-technology). Assistive technologies use these
 interfaces to get information about and interact with those
 [widgets](#dfn-widget). Examples of accessibility
 [APIs] are
 [Microsoft Active
 Accessibility](https://learn.microsoft.com/en-us/windows/win32/winauto/microsoft-active-accessibility)
 \[[MSAA](#bib-msaa "Microsoft Active Accessibility (MSAA)")\], [Microsoft User Interface
 Automation](https://learn.microsoft.com/en-us/windows/win32/winauto/entry-uiauto-win32)
 \[[UI-AUTOMATION](#bib-ui-automation "UI Automation")\], [MSAA] with [[UIA]
 Express](https://learn.microsoft.com/en-us/windows/win32/winauto/iaccessibleex)
 \[[UIA-EXPRESS](#bib-uia-express "The IAccessibleEx Interface")\], the [Mac [OS X]
 Accessibility
 Protocol](https://developer.apple.com/documentation/appkit/nsaccessibility)
 \[[AXAPI](#bib-axapi "The NSAccessibility Protocol for macOS")\], the [Linux/Unix Accessibility
 Toolkit](https://gnome.pages.gitlab.gnome.org/atk/)
 \[[ATK](#bib-atk "ATK - Accessibility Toolkit")\] and [Assistive Technology Service Provider
 Interface](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/)
 \[[AT-SPI](#bib-at-spi "Assistive Technology Service Provider Interface")\], and
 [IAccessible2](https://wiki.linuxfoundation.org/accessibility/iaccessible2/start)
 \[[IAccessible2](#bib-iaccessible2 "IAccessible2")\].

[Accessible object]

: A [node](https://dom.spec.whatwg.org/#concept-node) in the [accessibility
 tree](#dfn-accessibility-tree) of a platform
 [accessibility [API]](#dfn-accessibility-api). Accessible objects expose various
 [states](#dfn-state),
 [properties](#dfn-property), and
 [events](#dfn-event) for use by [assistive
 technologies](#assistive-technology). In the context of markup languages
 (e.g., [HTML] and
 [SVG]) in general, and of
 [WAI-ARIA] in
 particular, markup
 [elements](https://dom.spec.whatwg.org/#concept-element)
 and their
 [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 are represented as accessible objects.

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

 This definition might differ from that used in other documents.

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

[Deprecated]

: A deprecated [role](#dfn-role), [state](#dfn-state), or [property](#dfn-property) is one which has been outdated by newer
 constructs or changed circumstances, and which might be removed in
 future versions of the [WAI-ARIA] specification. [user
 agents](https://infra.spec.whatwg.org/#user-agent)
 are encouraged to continue to support items identified as deprecated
 for backward compatibility. For more information, see [Deprecated
 Requirements](https://w3c.github.io/aria/#deprecated) in
 the Conformance section.

[Defines]

: Used in an attribute description to denote that the value
 [type](#propcharacteristic_value) is an
 [integer](#valuetype_integer), [number](#valuetype_number), or
 [string](#valuetype_string).

 Related Terms:
 [Identifies](#dfn-identifies),
 [Indicates](#dfn-indicates)

[Desktop focus event]

: Event from/to the host operating system via the accessibility
 [API], notifying of
 a change of input focus.

[Event]

: A programmatic message used to communicate discrete changes in the
 [state](#dfn-state) of an [object](#dfn-object) to other objects in a computational
 system. User input to a web page is commonly mediated through
 abstract events that describe the interaction and can provide notice
 of changes to the state of a document object. In some programming
 languages, events are more commonly known as notifications.

[Expose]

: Translated to platform-specific [accessibility [APIs]](#dfn-accessibility-api) as defined in
 the [Core Accessibility [API]
 Mappings](https://w3c.github.io/core-aam/).

[Focusable]

: An element or area matching the definition of [focusable
 area](https://html.spec.whatwg.org/multipage/interaction.html#focusable-area)
 in the [HTML]
 Specification.

[Graphical Document]

: A document containing graphic representations with user-navigable
 parts. Charts, maps, diagrams, blueprints, and dashboards are
 examples of graphical documents. A graphical document is composed
 using any combination of symbols, images, text, and graphic
 primitives (shapes such as circles, points, lines, paths,
 rectangles, etc).

[Hidden]

: Indicates that the
 [element](https://dom.spec.whatwg.org/#concept-element)
 is excluded from the accessibility tree and therefore not exposed to
 accessibility [APIs].

 Related: [Excluding Elements in the Accessibility
 Tree](#tree_exclusion), [hidden from all
 users](#dfn-hide-from-all-users),
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden).

[Hidden From All Users]

: Indicates that the
 [element](https://dom.spec.whatwg.org/#concept-element)
 is not visible,
 [perceivable](#dfn-perceivable), or interactive for *any* user. Note
 that an
 [element](https://dom.spec.whatwg.org/#concept-element)
 can be [hidden](#dfn-hidden) but not [hidden from all
 users](#dfn-hide-from-all-users) by using `aria-hidden`.

 Related: [Excluding Elements in the Accessibility
 Tree](#tree_exclusion), [hidden](#dfn-hidden),
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden).

[Identifies]

: Used in an attribute description to denote that the value
 [type](#propcharacteristic_value) is an [ID
 reference](#valuetype_idref) (identifying a single element) or [ID
 reference list](#valuetype_idref_list) (identifying one or more
 elements).

 Related Terms: [Defines](#dfn-defines),
 [Indicates](#dfn-indicates)

[Indicates]

: Used in an attribute description to denote that the value
 [type](#propcharacteristic_value) is a named token or otherwise
 token-like, including the Boolean-like
 [true/false](#valuetype_true-false),
 [true/false/undefined](#valuetype_true-false-undefined), [tristate
 (true/false/mixed)](#valuetype_tristate), a single named
 [token](#valuetype_token), or a [token list](#valuetype_token_list).

 Related Terms: [Defines](#dfn-defines),
 [Identifies](#dfn-identifies)

[Keyboard Accessible]

: Accessible to the user using a keyboard or [assistive
 technologies](#assistive-technology) that mimic keyboard input, such as a
 sip and puff tube. References in this document relate to
 [[WCAG] 2.1
 Guideline 2.1: Make all functionality available from a
 keyboard](https://www.w3.org/TR/WCAG21/#keyboard-accessible)
 \[[WCAG21](#bib-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1")\].

[Landmark]

: A type of region on a page to which the user might want quick
 access. Content in such a region is different from that of other
 regions on the page and relevant to a specific user purpose, such as
 navigating, searching, perusing the primary content, etc.

[Live Region]

: Live regions are perceivable regions of a web page that are
 typically updated as a result of an external event. These regions
 are not always updated as a result of a user interaction and can
 receive these updates even when they do not have focus. Examples of
 live regions include a chat log, stock ticker, or a sport scoring
 section that updates periodically to reflect game statistics. Since
 these asynchronous areas are expected to update outside the user\'s
 area of focus, assistive technologies such as screen readers have
 either been unaware of their existence or unable to process them for
 the user. [WAI-ARIA] has provided a
 collection of properties that allow the author to identify these
 live regions and process them: aria-live, aria-relevant,
 aria-atomic, and aria-busy.

[Managed State]

: [Accessibility [API]](#dfn-accessibility-api)
 [state](#dfn-state) that is controlled by the user agent, such as focus
 and selection. These are contrasted with \"unmanaged states\" that
 are typically controlled by the author. Nevertheless, authors can
 override some managed states, such as aria-posinset and
 aria-setsize. Many managed states have corresponding [CSS] pseudo-classes, such as :focus, and
 pseudo-elements, such as ::selection, that are also updated by the
 user agent.

[Nemeth Braille]

: The Nemeth Braille Code for Mathematics is a braille code for
 encoding mathematical and scientific notation. See [Nemeth Braille
 on Wikipedia](https://en.wikipedia.org/wiki/Nemeth_Braille).

[Object]

: In the context of user interfaces, an item in the perceptual user
 experience, represented in markup languages by one or more
 [elements](https://dom.spec.whatwg.org/#concept-element),
 and rendered by [user
 agents](https://infra.spec.whatwg.org/#user-agent).

 In the context of programming, the instantiation of one or more
 classes and interfaces which define the general characteristics of
 similar objects. An object in an [accessibility [API]](#dfn-accessibility-api) can represent one or more [DOM] objects. [Accessibility [APIs]](#dfn-accessibility-api) have defined
 interfaces that are distinct from [DOM] interfaces.

[Ontology]

: A description of the characteristics of classes and how they relate
 to each other.

[Operable]

: Usable by users in ways they can control. References in this
 document relate to [[WCAG] 2.1 Principle 2:
 Content must be operable](https://www.w3.org/TR/WCAG21/#operable)
 \[[WCAG21](#bib-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1")\]. See [Keyboard
 Accessible](#dfn-keyboard-accessible).

[Perceivable]

: Presentable to users in ways they can sense. References in this
 document relate to [[WCAG] 2.1 Principle 1:
 Content must be
 perceivable](https://www.w3.org/TR/WCAG21/#perceivable)
 \[[WCAG21](#bib-wcag21 "Web Content Accessibility Guidelines (WCAG) 2.1")\].

[Property]

: [attributes](https://dom.spec.whatwg.org/#concept-attribute)
 that are essential to the nature of a given
 [object](#dfn-object), or that represent a data value associated with the
 object. A change of a property can significantly impact the meaning
 or presentation of an object. Certain properties (for example,
 [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline))
 are less likely to change than
 [states](#dfn-state),
 but note that the frequency of change difference is not a rule. A
 few properties, such as
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant),
 [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow),
 and
 [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
 are expected to change often. See [clarification of states versus
 properties](https://w3c.github.io/aria/#statevsprop).

[Relationship]

: A connection between two distinct things. Relationships can be of
 various types to indicate which
 [object](#dfn-object) labels another, controls another, etc.

[Role]

: Main indicator of type. This
 [semantic](#dfn-semantics)
 association allows tools to present and support interaction with the
 object in a manner that is consistent with user expectations about
 other objects of that type.

[Semantics]

: The meaning of something as understood by a human, defined in a way
 that computers can process a representation of an
 [object](#dfn-object), such as
 [elements](https://dom.spec.whatwg.org/#concept-element)
 and
 [attributes](https://dom.spec.whatwg.org/#concept-attribute),
 and reliably represent the object in a way that various humans will
 achieve a mutually consistent understanding of the object.

[State]

: A state is a dynamic
 [property](#dfn-property) expressing characteristics of an
 [object](#dfn-object) that can change in response to user action or
 automated processes. States do not affect the essential nature of
 the object, but represent data associated with the object or user
 interaction possibilities. See [clarification of states versus
 properties](https://w3c.github.io/aria/#statevsprop).

[Target Element]

: An element specified in a [WAI-ARIA] relation. For example,
 in ` <div aria-controls=”elem1”>`, where `“elem1”` is the ID for the
 target element.

[Unicode Braille Patterns]

: In Unicode, braille is represented in a block called Braille
 Patterns (U+2800..U+28FF). The block contains all 256 possible
 patterns of an 8-dot braille cell; this includes the complete 6-dot
 cell range which is represented by U+2800..U+283F. In all braille
 systems, the braille pattern dots-0 (U+2800) is used to represent a
 space or the lack of content; it is also called a blank Braille
 pattern. See [Braille Patterns on
 Wikipedia](https://en.wikipedia.org/wiki/Braille_Patterns).

[Widget]

: Discrete user interface [object](#dfn-object) with which the user can interact. Widgets
 range from simple objects that have one value or operation (e.g.,
 check boxes and menu items), to complex objects that contain many
 managed sub-objects (e.g., trees and grids).

::: header-wrapper
## 3. Conformance

As well as sections marked as non-normative, all authoring guidelines,
diagrams, examples, and notes in this specification are non-normative.
Everything else in this specification is normative.

The key words *MAY*, *MUST*, *MUST NOT*, *SHOULD*, and *SHOULD NOT* in
this document are to be interpreted as described in [BCP
14](https://www.rfc-editor.org/info/bcp14)
\[[RFC2119](#bib-rfc2119 "Key words for use in RFCs to Indicate Requirement Levels")\]
\[[RFC8174](#bib-rfc8174 "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words")\] when, and only when, they appear in all capitals,
as shown here.

The main content of this specification is \"normative\" and defines
requirements that impact conformance claims. Introductory material,
appendices, sections marked as \"non-normative\" and their subsections,
diagrams, examples, and notes are \"informative\" (non-normative).
Non-normative material provides advisory information to help interpret
the guidelines but does not create requirements that impact a
conformance claim.

Normative sections provide requirements that authors, user agents and
assistive technologies *MUST* follow for an implementation to conform to
this specification.

Non-normative (informative) sections provide information useful to
understanding the specification. Such sections may contain examples of
recommended practice, but it is not required to follow such
recommendations in order to conform to this specification.

::: header-wrapper
### 3.1 Non-interference with the Host Language

[WAI-ARIA]
processing by the [user
agent](https://infra.spec.whatwg.org/#user-agent) *MUST
NOT* interfere with the normal operation of the built-in features of the
host language.

If a [CSS] selector includes a
[WAI-ARIA] attribute
(e.g., [`input`][`[aria-invalid=`[`"true"`]`]`]), user agents *MUST* update the
visual display of any elements matching (or no longer matching) the
selector any time the attribute is added/changed/removed in the
[DOM]. The user agent *MAY* alter
the mapping of the host language features into an [accessibility
[API]](#dfn-accessibility-api), but the user agent *MUST NOT* alter the
[DOM] in order to remap
[WAI-ARIA] markup
into host language features.

::: header-wrapper
### 3.2 All [WAI-ARIA] in [DOM]

A conforming [user
agent](https://infra.spec.whatwg.org/#user-agent) which
implements a document object model that does not conform to the
[W3C] [DOM] specification *MUST* include the content
attribute for role and its [[WAI-ARIA] role
values](#roles_categorization), as well as the [[WAI-ARIA] States and
Properties](#states_and_properties) in the [DOM] as specified by the author, even though
processing might affect how the elements are exposed to accessibility
[APIs]. Doing so
ensures that each role attribute and all [WAI-ARIA] states and properties,
including their values, are in the document in an unmodified form so
other tools, such as assistive technologies, can access them. A
conforming [W3C] [DOM] meets this criterion.

::: header-wrapper
### 3.3 Assistive Technology Notifications Communicated to Web Applications

[Assistive
technologies](#assistive-technology), such as speech recognition systems and
alternate input devices for users with mobility impairments, require the
ability to control a web application in a device-independent way.
[WAI-ARIA]
[states](#dfn-state)
and [properties](#dfn-property) reflect the current state of rich internet
application components. The ability for assistive technologies to notify
web applications of necessary changes is essential because it allows
these alternative input solutions to control an application without
being dependent on the standard input device which the user is unable to
effectively control directly.

User agents *MUST* provide a method to notify the web application when a
change occurs to states or properties in the system accessibility
[API]. Likewise,
authors *SHOULD* update the web application accordingly when notified of
a change request from the user agent or assistive technology.

::: header-wrapper
### 3.4 Conformance Checkers

Any application or script verifying document conformance or validity
*SHOULD* include a test for all of the normative author requirements in
this specification. If testing for a given requirement, conformance
checkers *MUST* issue an error if an author \"*MUST*\" requirement
isn\'t met, and *MUST* issue a warning if an author \"*SHOULD*\"
requirement isn\'t met.

::: header-wrapper
### 3.5 Deprecated Requirements

As the technology evolves, sometimes new ways to meet a use case become
available, that work better than a feature that was previously defined.
But because of existing implementation of the older feature, that
feature cannot be removed from the conformance model without rendering
formerly conforming content non-conforming. In this case, the older
feature is marked as \"deprecated\". This indicates that the feature is
allowed in the conformance model and expected to be supported by user
agents, but it is recommended that authors do not use it for new
content. In future versions of the specification, if the feature is no
longer widely used, the feature could be removed and no longer expected
to be supported by user agents.

::: header-wrapper
## 4. Using [WAI-ARIA]

Complex web applications become inaccessible when [assistive
technologies](#assistive-technology) cannot determine the
[semantics](#dfn-semantics) behind portions of a document or when the user is
unable to effectively navigate to all parts of it in a usable way (see
[[ARIA] Authoring
Practices Guide](https://www.w3.org/WAI/ARIA/apg/)). [WAI-ARIA] divides the semantics
into [roles](#dfn-role) (the type defining a user interface element) and
[states](#dfn-state)
and [properties](#dfn-property) supported by the roles.

Authors need to associate
[elements](https://dom.spec.whatwg.org/#concept-element)
in the document to a [WAI-ARIA] role and the appropriate
states and properties (aria-\*
[attributes](https://dom.spec.whatwg.org/#concept-attribute))
during its life-cycle, unless the elements already have the appropriate
[implicit [WAI-ARIA]
semantics](#implicit_semantics) for states and properties. In these
instances the equivalent host language states and properties take
precedence to avoid a conflict while the role attribute will take
precedence over the implicit role of the host language element.

::: header-wrapper
### 4.1 [WAI-ARIA] Roles

A [WAI-ARIA]
[role](#dfn-role) is
set on an
[element](https://dom.spec.whatwg.org/#concept-element)
using a `role`
[attribute](https://dom.spec.whatwg.org/#concept-attribute),
similar to the `role` attribute defined in [Role
Attribute](https://www.w3.org/TR/role-attribute/)
\[[ROLE-ATTRIBUTE](#bib-role-attribute "Role Attribute 1.0")\].

[Example 1](#example-1)

```
<li >Open file…</li>
```

The definition of each role in the model provides the following
information :

- an informative description of the role;
- hierarchical information about related roles (e.g., a
 [`searchbox`](https://w3c.github.io/aria/#searchbox)
 is a type of
 [`textbox`](https://w3c.github.io/aria/#textbox));
- context of the role (e.g., a
 [`listitem`](https://w3c.github.io/aria/#listitem) is
 contained inside a
 [`list`](https://w3c.github.io/aria/#list));
- references to related concepts in other specifications;
- supported [states](#dfn-state) and
 [properties](#dfn-property) for each role (e.g., a
 [`checkbox`](https://w3c.github.io/aria/#checkbox)
 supports being checked via
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)).

Attaching a role gives [assistive
technologies](#assistive-technology) information about how to handle each
element. When [WAI-ARIA] roles override host
language semantics, there are no changes in the [DOM], only in the [accessibility
tree](#dfn-accessibility-tree).

User agents *MUST* use the first token in the sequence of tokens in the
`role`
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
value that matches the name of any non-abstract [WAI-ARIA]
[role](#dfn-role).
Refer to the section on [`role` attribute implementation in Host
Languages](#host_general_role) for further details.

::: header-wrapper
### 4.2 [WAI-ARIA] States and Properties

[WAI-ARIA] provides
a collection of accessibility [states](#dfn-state) and
[properties](#dfn-property) which are used to support platform
[accessibility [APIs]](#dfn-accessibility-api) on various operating system platforms.
[Assistive
technologies](#assistive-technology) can access this information through an
exposed [user
agent](https://infra.spec.whatwg.org/#user-agent)
[DOM] or through a mapping to the
platform accessibility [API]. When combined with
[roles](#dfn-role),
the user agent can supply the assistive technologies with user interface
information to convey to the user at any time. Changes in states or
properties will result in a notification to assistive technologies,
which could alert the user that a change has occurred.

In the following example, a list item (`html:li`) has been used to
create a checkable menu item, and JavaScript
[events](#dfn-event)
will capture mouse and keyboard events to toggle the value of
[`aria-checked`](https://w3c.github.io/aria/#aria-checked).
A role is used to make the behavior of this simple
[widget](#dfn-widget) known to the user agent.
[Attributes](https://dom.spec.whatwg.org/#concept-attribute) that change with user actions (such as
[`aria-checked`](https://w3c.github.io/aria/#aria-checked))
are defined in the [states and properties](#states_and_properties)
section.

[Example 2](#example-2)

```
<li aria-checked="true">Sort by Last Modified</li>
```

Some accessibility states, called *[managed
states](#dfn-managed-state)*, are controlled by the user agent. Examples of managed
state include keyboard focus and selection. Managed states often have
corresponding [CSS] pseudo-classes
(such as `:focus` and `::selection`) to define style changes. In
contrast, the states in this specification are typically controlled by
the author and are called *unmanaged states.* Some states are managed by
the user agent, such as
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
but the author can override them if the [DOM] is incomplete and would cause the user
agent calculation to be incorrect. User agents map both managed and
unmanaged states to the platform accessibility [APIs].

Most modern user agents support [[CSS] attribute
selectors](https://www.w3.org/TR/css3-selectors/#attribute-selectors)
(\[[CSS3-SELECTORS](#bib-css3-selectors "Selectors Level 3")\]), and can allow the author to create [UI] changes based on [WAI-ARIA] attribute information,
reducing the amount of scripts necessary to achieve equivalent
functionality. In the following example, a [CSS] selector is used to determine whether or
not the text is bold and an image of a check mark is shown, based on the
value of the
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
attribute.

[Example 3](#example-3)

```
[aria-checked="true"] { font-weight: bold; }
[aria-checked="true"]::before { background-image: url(checked.gif); }
```

If [CSS] is not used to toggle the
visual representation of the check mark, the author could include
additional markup and scripts to manage an image that represents whether
or not the
[`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox)
is checked.

[Example 4](#example-4)

```
<li aria-checked="true">
 <img src="checked.gif" a>
 <!-- note: additional scripts required to toggle image source -->
 Sort by Last Modified
</li>
```

::: header-wrapper
### 4.3 Managing Focus and Supporting Keyboard Navigation

When using standard [HTML]
interactive elements and simple [WAI-ARIA]
[widgets](#dfn-widget), application developers can manipulate the tab order or
associate keyboard shortcuts with elements in the document.

[WAI-ARIA] includes
a number of \"managing container\" widgets, also known as \"composite\"
widgets. When appropriate, the container is responsible for tracking the
last descendant that was active (the default is usually the first item
in the container). It is essential that a container maintain a usable
and consistent strategy when focus leaves a container and is then later
refocused. While there can be exceptions, it is recommended that when a
previously focused container is refocused, the active descendant be the
same element as the active descendant when the container was last
focused. Exceptions include cases where the contents of a container
widget have changed, and widgets like a menubar where the user expects
to always return to the first item when focus leaves the menu bar. For
example, if the second item of a tree group was the active descendant
when the user tabbed out of the tree group, then the second item of the
tree group remains the active descendant when the tree group gets focus
again. The user can also activate the container by clicking on one of
the descendants within it. When the container or its active descendant
has focus, the user can navigate through the container by pressing
additional keys, such as the arrow keys, to change the currently active
descendant. Any additional press of the main navigation key (generally
the [TAB] key) will move out of the container to the next widget.

Usable keyboard navigation in a rich internet application is different
from the tabbing paradigm among interactive elements, such as links and
form controls, in a static document. In rich internet applications, the
user tabs to significantly complex
[widgets](#dfn-widget), such as a menu or spreadsheet, and uses
the arrow keys to navigate within the widget. The changes that
[WAI-ARIA]
introduces to keyboard navigation make this enhanced accessibility
possible. In [WAI-ARIA], any element can be
keyboard focusable. In addition to host language mechanisms such as
`tabindex`,
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
provides another mechanism for keyboard operation. Most other aspects of
[WAI-ARIA] widget
development depend on keyboard navigation functioning properly.

When implementing
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
as described below, the user agent keeps the [DOM] focus on the container element or on an
input element that controls the container element. However, the user
agent communicates [desktop focus
events](#dfn-desktop-focus-event) and states to the assistive technology as
if the element referenced by
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
has focus. User agents are not expected to validate that the active
descendant is a descendant of the container element. It is the
responsibility of the user agent to ensure that keyboard events are
processed at the
[element](https://dom.spec.whatwg.org/#concept-element)
that has [DOM] focus. Any keyboard
events directed at the active descendant bubble up to the [DOM] element with focus for processing.

::: header-wrapper
#### 4.3.1 Information for Authors

If the author removes the element with focus, the author *SHOULD* move
focus to a logical element. Similarly, authors *SHOULD* not scroll the
element with focus off screen unless the user performed a scrolling
action.

Authors *SHOULD* ensure that all interactive
[elements](https://dom.spec.whatwg.org/#concept-element)
are [focusable](#dfn-focusable) and that all parts of composite widgets are either
focusable or have a documented alternative method to achieve their
function.

Authors *MUST* manage focus on the following container roles:

- [`grid`](https://w3c.github.io/aria/#grid)
- [`listbox`](https://w3c.github.io/aria/#listbox)
- [`menu`](https://w3c.github.io/aria/#menu)
- [`menubar`](https://w3c.github.io/aria/#menubar)
- [`radiogroup`](https://w3c.github.io/aria/#radiogroup)
- [`tree`](https://w3c.github.io/aria/#tree)
- [`treegrid`](https://w3c.github.io/aria/#treegrid)
- [`tablist`](https://w3c.github.io/aria/#tablist)

User agents that support [WAI-ARIA] expand the usage of host
language mechanisms such as `tabindex`, `focus`, and `blur` to allow
them on all
[elements](https://dom.spec.whatwg.org/#concept-element).
Where the host language supports it, authors *MAY* add any element such
as a `div`, `span`, or `img` to the default tab order by setting
`tabindex="0"`. In addition, any item with `tabindex` equal to a
negative integer is focusable via script or a mouse click, but is not
part of the default tab order. This is supported in both
\[[HTML](#bib-html "HTML Standard")\] and
\[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\].

Authors *MAY* use
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
to inform [assistive
technologies](#assistive-technology) which descendant of a
[`widget`](https://w3c.github.io/aria/#widget) element
is treated as having keyboard focus in the user interface if the role of
the widget element supports `aria-activedescendant`. This is often a
more convenient way of providing keyboard navigation within widgets,
such as a
[`listbox`](https://w3c.github.io/aria/#listbox), where
the widget occupies only one stop in the page [Tab] sequence and
other keys, typically arrow keys, are used to focus elements inside the
widget.

Typically, the author will use host language
[semantics](#dfn-semantics) to put the widget in the [Tab] sequence (e.g.,
`tabindex="0"` in [HTML]) and
`aria-activedescendant` to point to the ID of the currently active
descendant. The author, not the user agent, is responsible for styling
the currently active descendant to show it has keyboard focus. The
author cannot use `:`[`focus`] to style the currently
active descendant since the actual focus is on the container.

More information on managing focus can be found in the [Developing a
Keyboard Interface](https://www.w3.org/WAI/ARIA/apg/keyboard-interface)
section of the [WAI-ARIA] Authoring Practices.

::: header-wrapper
#### 4.3.2 Information for User Agents

The user agent *MUST* do the following to implement
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant):

1. Implement the host language method for keyboard navigation so that
 widgets that support `aria-activedescendant` can be included in the
 tab order.
2. For platforms that expose [desktop
 focus](#dfn-desktop-focus-event) or [accessibility [API]](#dfn-accessibility-api) focus separately from [DOM] focus, do not expose the focused
 state in the accessibility [API] for any element when it
 has [DOM] focus and also has
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 which points to a valid [ID reference](#valuetype_idref).
3. When the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute changes on an element that currently has [DOM] focus, remove the focused state from
 the previously focused object and fire an accessibility [API] [desktop focus
 event](#dfn-desktop-focus-event) on the new element referenced by
 `aria-activedescendant`. If
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 is cleared or does not point to an element in the current document,
 fire a desktop focus event for the
 [object](#dfn-object) that had the attribute change.
4. Apply the following accessibility [API] states to any element
 with an ID attribute that can be referenced by an element with both
 an
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute and has [DOM] focus.
 There are two ways an element can be referenced by
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
 One way is when it is an [accessibility
 descendant](#dfn-accessibility-descendant) of the element with
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 and the other is when it is an [accessibility
 descendant](#dfn-accessibility-descendant) of an element that is controlled by an
 element with role of
 [`combobox`](https://w3c.github.io/aria/#combobox),
 [`textbox`](https://w3c.github.io/aria/#textbox) or
 [`searchbox`](https://w3c.github.io/aria/#searchbox)
 with an
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute:
 1. [Focusable](#dfn-focusable), if the element also has a
 [WAI-ARIA]
 [role](#dfn-role). The element needs to be focusable
 because it could be referenced by the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute. Native elements that have no
 [role](#dfn-role) attribute do not need to be
 checked; their native semantics determine the focusable state.
 2. Focused, whenever the element is the target of the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute and the element with the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute has [DOM] focus.

When an assistive technology uses its platform\'s accessibility
[API] to request a
change of focus, user agents *MUST* do the following:

1. Remove the platform\'s focused state from the previously focused
 object.
2. Set the [DOM] focus:
 1. If the
 [element](https://dom.spec.whatwg.org/#concept-element) can take [DOM] focus, the [user
 agent](https://infra.spec.whatwg.org/#user-agent) *MUST* set the [DOM] focus to it.
 2. Otherwise, if the element being focused has an ID and the ID is
 referenced by the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute of an element that is focusable, the user agent *MUST*
 set [DOM] focus to the
 element that has the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute.

 ::::
 :::
 Note
 :::

 An element with an ID can be referenced when it is an
 [accessibility
 descendant](#dfn-accessibility-descendant) of a container element that has
 the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute or by a container element that is controlled by an
 element that has the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute (e.g., see
 [`combobox`](https://w3c.github.io/aria/#combobox)).
 Otherwise the
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute reference indicates an author error.
 ::::

 ::::
 :::
 Note
 :::

 The inability to set [DOM]
 focus to the containing element indicates an author error.
 ::::
 3. Otherwise, the user agent *MAY* attempt to set [DOM] focus to the child element
 itself.
3. If the element being focused has an ID and is an [accessibility
 descendant](#dfn-accessibility-descendant) of either a container element with
 both an `aria-activedescendant` attribute and has [DOM] focus, or by a container element that
 is controlled by an element with both an
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute and has [DOM] focus,
 the user agent *MUST* set the accessibility [API] focused state and fire an
 accessibility [API]
 focus [event](#dfn-event) on the element identified by the value of
 `aria-activedescendant`.

::: header-wrapper
## 5. The Roles Model

This section defines [WAI-ARIA]
[roles](#dfn-role)
and describes their characteristics and properties.

The roles, their characteristics, the states and properties they
support, and specification of how they can be used in markup, shall be
considered normative.

In order to reflect the content in the [DOM], user agents *SHOULD* map the role
attribute to the appropriate value in the implemented accessibility
[API], and user agents
*SHOULD* update the mapping when the role attribute changes.

::: header-wrapper
### 5.1 Relationships Between Concepts

The Roles Model uses the following relationships to relate
[WAI-ARIA] roles to
each other and to concepts from other specifications, such as
[HTML].

::: header-wrapper
#### 5.1.1 Superclass Role

The [role](#dfn-role)
that the current subclassed role extends in the Roles Model. This
extension causes all the states and properties of the superclass role to
propagate to the subclass role. Other than well known stable
specifications, inheritance can be restricted to items defined inside
this specification, so that external items cannot be changed and affect
inherited classes.

::: header-wrapper
#### 5.1.2 Subclass Roles

Informative list of [roles](#dfn-role) for which this role is the superclass. This is provided
to facilitate reading of the specification but adds no new information.

::: header-wrapper
#### 5.1.3 Related Concepts

Informative data about a similar or related idea from other
specifications. Concepts that are related are not necessarily identical.
Related concepts do not inherit properties from each other. Hence if the
definition of one concept changes, the properties, behavior, and
definition of its related concept is not affected.

For example, a progress bar is like a status indicator. Therefore, the
[`progressbar`](https://w3c.github.io/aria/#progressbar)
[widget](#dfn-widget) has a related concept which includes
[`status`](https://w3c.github.io/aria/#status).
However, if the definition of
[`status`](https://w3c.github.io/aria/#status) is
modified, the definition of a
[`progressbar`](https://w3c.github.io/aria/#progressbar)
is not affected.

::: header-wrapper
#### 5.1.4 Base Concept

Informative data about [objects](#dfn-object) that are considered prototypes for the
[role](#dfn-role).
Base concept is similar to type, but without inheritance of limitations
and properties. Base concepts are designed as a substitute for
inheritance for external concepts. A base concept is like a [related
concept](#relatedConcept) except that the base concept is almost
identical to the role definition.

For example, the
[`checkbox`](https://w3c.github.io/aria/#checkbox)
defined in this document has similar functionality and anticipated
behavior to a
`<input type="`[`checkbox`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-checkbox-keyword)`">`
defined in [HTML]. Therefore, a
[`checkbox`](https://w3c.github.io/aria/#checkbox) has
an \[[HTML](#bib-html "HTML Standard")\]
`checkbox` as a `baseConcept`. However, if the original
\[[HTML](#bib-html "HTML Standard")\]
checkbox baseConcept definition is modified, the definition of a
[`checkbox`](https://w3c.github.io/aria/#checkbox) in
this document will not be affected, because there is no actual
inheritance of the respective type.

::: header-wrapper
### 5.2 Characteristics of Roles

Roles are defined and described by their characteristics.
Characteristics define the structural function of a role, such as what a
role is, concepts behind it, and what instances the role can or must
contain. In the case of [widgets](#dfn-widget) this also includes how it interacts with
the [user
agent](https://infra.spec.whatwg.org/#user-agent) based
on mapping to [HTML] forms.
States and properties from [WAI-ARIA] that are supported by the
role are also indicated.

Roles define the following characteristics.

::: header-wrapper
#### 5.2.1 Abstract Roles

Abstract [roles](#dfn-role) are the foundation upon which all other
[WAI-ARIA] roles
are built. Authors *MUST NOT* use abstract roles because they are not
implemented in the [API] binding. User agents *MUST
NOT* map abstract roles to the standard role mechanism of the
accessibility [API].
Abstract roles are provided to help with the following:

1. Organize the Roles Model and provide roles with a meaning in the
 context of known concepts.
2. Streamline the addition of roles that include necessary features.

::: header-wrapper
#### 5.2.2 Required States and Properties

[States](#dfn-state)
and [properties](#dfn-property) specifically required for the
[role](#dfn-role) and
subclass roles. Authors *MUST* provide a non-empty value for required
states and properties. Authors *MUST NOT* use the value `undefined` for
required states and properties, unless `undefined` is an
explicitly-supported value of that state or property.

When an [object](#dfn-object) inherits from multiple ancestors and one ancestor
indicates that property is supported while another ancestor indicates
that it is required, the property is required in the inheriting object.

A host language attribute with the appropriate [implicit
[WAI-ARIA]
semantic](#implicit_semantics) fulfills this requirement.

::: header-wrapper
#### 5.2.3 Supported States and Properties

[States](#dfn-state)
and [properties](#dfn-property) specifically applicable to the
[role](#dfn-role) and
child roles. Authors *MAY* provide values for supported states and
properties, but need not in cases where default values are sufficient.
[user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* map all supported states and properties for the role to an
accessibility [API]. If
the state or property is undefined and it has a default value for the
role, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* expose the default value.

A host language attribute with the appropriate [implicit
[WAI-ARIA]
semantic](#implicit_semantics) fulfills this requirement.

::: header-wrapper
#### 5.2.4 Inherited States and Properties

Informative list of properties that are inherited by a
[role](#dfn-role)
from superclass roles. [States](#dfn-state) and
[properties](#dfn-property) are inherited from superclass roles in the
Roles Model, not from ancestor
[elements](https://dom.spec.whatwg.org/#concept-element)
in the [DOM] tree. These properties
are not explicitly defined on the role, as the inheritance of properties
is automatic. This information is provided to facilitate reading of the
specification. The set of supported states and properties combined with
inherited states and properties forms the full set of states and
properties supported by the role.

::: header-wrapper
#### 5.2.5 [Prohibited] States and Properties

List of states and properties that are prohibited on a
[role](#dfn-role).
Authors *MUST NOT* specify a prohibited state or property.

A host language attribute with the appropriate [implicit
[WAI-ARIA]
semantic](#implicit_semantics) would also prohibit a state or property
in this section.

::: header-wrapper
#### 5.2.6 Allowed Accessibility Child Roles

A list of roles which are allowed on an [accessibility
child](#dfn-accessibility-child) (simplified as \"child\") of the element
with this [role](#dfn-role). Authors *MUST* only add child element with allowed
roles. For example, an element with the role
[`list`](https://w3c.github.io/aria/#list) can own
child elements with the role
[`listitem`](https://w3c.github.io/aria/#listitem), but
cannot own elements with the role
[`option`](https://w3c.github.io/aria/#option).

To determine whether an element is the
[child](#dfn-accessibility-child) of an element, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* ignore any intervening elements with the role
[`generic`](https://w3c.github.io/aria/#generic) or
[`none`](https://w3c.github.io/aria/#none).

Descendants which are not children of an element ancestor are not
constrained by *allowed accessibility child roles*. For example, an
`image` is not an allowed child of a `list`, but it is a valid
descendant if it is also a descendant of the `list`\'s allowed child
`listitem`.

A role that has \'allowed accessibility child roles\' does not imply the
reverse relationship. Elements with roles in this list do not always
have to be found within elements of the given role. See [required
accessibility parent roles](#scope) for requirements about the context
where elements of a given role will be contained.

An element with a [subclass role](#subclassroles) of the \'allowed
accessibility child role\' does not fulfill this requirement. For
example, the
[`listbox`](https://w3c.github.io/aria/#listbox) role
allows a child element using the
[`option`](https://w3c.github.io/aria/#option) or
[`group`](https://w3c.github.io/aria/#group) role.
Although the
[`group`](https://w3c.github.io/aria/#group) role is
the superclass of
[`row`](https://w3c.github.io/aria/#row), adding a
child element with a role of
[`row`](https://w3c.github.io/aria/#row) will not
fulfill the requirement that
[`listbox`](https://w3c.github.io/aria/#listbox) allows
children with
[`option`](https://w3c.github.io/aria/#option) or
[`group`](https://w3c.github.io/aria/#group) roles.

An element with the appropriate [implicit [WAI-ARIA]
semantic](#implicit_semantics) fulfills this requirement.

Examples of valid ways to mark up allowed accessibility child roles
include:

1. Direct [DOM] child:

 ::::
 ::: marker
 [Example 5](#example-5)
 :::

 ```
 <div >
 <div >option text</div>
 </div>
 ```
 ::::
2. [DOM] child with generics
 intervening:

 ::::
 ::: marker
 [Example 6](#example-6)
 :::

 ```
 <div >
 <div>
 <div >option text</div>
 </div>
 </div>
 ```
 ::::
3. Direct `aria-owns` relationship:

 ::::
 ::: marker
 [Example 7](#example-7)
 :::

 ```
 <div aria-owns="id1"></div>
 <div id="id1">option text</div>
 ```
 ::::
4. `aria-owns` relationship with generics intervening:

 ::::
 ::: marker
 [Example 8](#example-8)
 :::

 ```
 <div aria-owns="id1"></div>
 <div id="id1">
 <div>
 <div >option text</div>
 </div>
 </div>
 ```
 ::::

::: header-wrapper
#### 5.2.7 Required Accessibility Parent Role

The required [accessibility
parent](#dfn-accessibility-parent) (simplified as \"parent\") role defines
the container where this [role](#dfn-role) is allowed. If a role has a required
accessibility parent, authors *MUST* ensure that an element with the
role is an [accessibility
child](#dfn-accessibility-child) of an element with the required
accessibility parent role. For example, an element with role `listitem`
is only meaningful when it is a child of an element with role `list`.

To determine whether an element has a parent with the required role,
[user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* ignore any elements with the role
[`generic`](https://w3c.github.io/aria/#generic) or
[`none`](https://w3c.github.io/aria/#none).

Also, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* ignore the role if it occurs outside the context of a required
accessibility parent role.

An element with the appropriate [implicit [WAI-ARIA]
semantic](#implicit_semantics) fulfills this requirement.

::: header-wrapper
#### 5.2.8 Name From

Determines which content contributes to the [Accessible Name and
Description Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\].

One of the following values:

1. author: name comes from values provided by the author in explicit
 markup features such as the
 [`aria-label`](https://w3c.github.io/aria/#aria-label)
 attribute, the
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 attribute, or the host language labeling mechanism, such as the
 `alt` or `title` attributes in [HTML], with [HTML] `title` attribute having the
 lowest precedence for specifying a text alternative.
2. contents: name comes from the text value of the
 [element](https://dom.spec.whatwg.org/#concept-element)
 node. Although this might be allowed in addition to \"author\" in
 some [roles](#dfn-role), this is used in content only if higher priority
 \"author\" features are not provided. Priority is defined by the
 [Accessible Name and Description
 Computation](https://w3c.github.io/accname/)
 \[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\].
3. prohibited: the element does not support name from author. Authors
 *MUST NOT* use the
 [`aria-label`](https://w3c.github.io/aria/#aria-label)
 or
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 attributes to name the element.

::: header-wrapper
##### 5.2.8.1 Roles Supporting Name from Author

- [`alert`](#alert)
- [`alertdialog`](#alertdialog)
- [`application`](#application) (name required)
- [`article`](#article)
- [`banner`](#banner)
- [`blockquote`](#blockquote)
- [`button`](#button) (name required)
- [`cell`](#cell)
- [`checkbox`](#checkbox) (name required)
- [`columnheader`](#columnheader) (name required)
- [`combobox`](#combobox) (name required)
- [`comment`](#comment)
- [`complementary`](#complementary)
- [`contentinfo`](#contentinfo)
- [`dialog`](#dialog)
- [`directory`](#directory)
- [`document`](#document)
- [`feed`](#feed)
- [`figure`](#figure)
- [`form`](#form)
- [`grid`](#grid)
- [`gridcell`](#gridcell)
- [`group`](#group)
- [`heading`](#heading) (name required)
- [`image`](#image) (name required)
- [`link`](#link) (name required)
- [`list`](#list)
- [`listbox`](#listbox) (name required)
- [`listitem`](#listitem)
- [`log`](#log)
- [`main`](#main)
- [`marquee`](#marquee)
- [`math`](#math)
- [`menu`](#menu)
- [`menubar`](#menubar)
- [`menuitem`](#menuitem) (name required)
- [`menuitemcheckbox`](#menuitemcheckbox) (name
 required)
- [`menuitemradio`](#menuitemradio) (name required)
- [`meter`](#meter) (name required)
- [`navigation`](#navigation)
- [`note`](#note)
- [`option`](#option) (name required)
- [`progressbar`](#progressbar) (name required)
- [`radio`](#radio) (name required)
- [`radiogroup`](#radiogroup)
- [`region`](#region) (name required)
- [`row`](#row)
- [`rowgroup`](#rowgroup)
- [`rowheader`](#rowheader) (name required)
- [`scrollbar`](#scrollbar)
- [`search`](#search)
- [`searchbox`](#searchbox) (name required)
- [`sectionfooter`](#sectionfooter)
- [`sectionheader`](#sectionheader)
- [`separator`](#separator)
- [`slider`](#slider) (name required)
- [`spinbutton`](#spinbutton) (name required)
- [`status`](#status)
- [`switch`](#switch) (name required)
- [`tab`](#tab) (name required)
- [`table`](#table)
- [`tablist`](#tablist)
- [`tabpanel`](#tabpanel) (name required)
- [`textbox`](#textbox) (name required)
- [`timer`](#timer)
- [`toolbar`](#toolbar)
- [`tooltip`](#tooltip)
- [`tree`](#tree) (name required)
- [`treegrid`](#treegrid) (name required)
- [`treeitem`](#treeitem) (name required)

::: header-wrapper
##### 5.2.8.2 Roles Supporting Name from Content

- [`button`](#button) (name required)
- [`cell`](#cell)
- [`checkbox`](#checkbox) (name required)
- [`columnheader`](#columnheader) (name required)
- [`comment`](#comment)
- [`gridcell`](#gridcell)
- [`heading`](#heading) (name required)
- [`link`](#link) (name required)
- [`menuitem`](#menuitem) (name required)
- [`menuitemcheckbox`](#menuitemcheckbox) (name
 required)
- [`menuitemradio`](#menuitemradio) (name required)
- [`option`](#option) (name required)
- [`radio`](#radio) (name required)
- [`row`](#row)
- [`rowheader`](#rowheader) (name required)
- [`switch`](#switch) (name required)
- [`tab`](#tab) (name required)
- [`tooltip`](#tooltip)
- [`treeitem`](#treeitem) (name required)

::: header-wrapper
##### 5.2.8.3 Roles which cannot be named (Name prohibited)

- [`caption`](#caption)
- [`code`](#code)
- [`definition`](#definition)
- [`deletion`](#deletion)
- [`emphasis`](#emphasis)
- [`generic`](#generic)
- [`insertion`](#insertion)
- [`mark`](#mark)
- [`none`](#none)
- [`paragraph`](#paragraph)
- [`strong`](#strong)
- [`subscript`](#subscript)
- [`suggestion`](#suggestion)
- [`superscript`](#superscript)
- [`term`](#term)
- [`time`](#time)

::: header-wrapper
#### 5.2.9 Children Presentational

Indicates whether [DOM] descendants
are presentational. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD NOT* expose descendants of this
[element](https://dom.spec.whatwg.org/#concept-element)
through the platform [accessibility [API]](#dfn-accessibility-api). If [user
agents](https://infra.spec.whatwg.org/#user-agent) do
not hide the descendant nodes, some information might be read twice.

Authors *MUST NOT* specify
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
on an element which has Presentational Children.

::: header-wrapper
#### 5.2.10 Implicit Value for Role

Many states and properties have default values. Occasionally, the
default value when used on a given role should be different from the
usual default. Roles that require a state or property to have a
non-standard default value indicate this in the \"Implicit Value for
Role\". This is expressed in the form \"Default for
`state or property name` is `new default value`\". Roles that define
this have the new default value for the state or property if the author
does not provide an explicit value.

::: header-wrapper
### 5.3 Categorization of Roles

To support the current user scenario, this specification categorizes
[roles](#dfn-role)
that define user interface [widgets](#dfn-widget) (sliders, tree controls, etc.) and those
that define page structure (sections, navigation, etc.). Note that some
assistive technologies provide special modes of interaction for regions
marked with role `application` or `document`.

A visual description of the relationships among roles is available in
the [[ARIA] 1.2
Class Diagram](https://www.w3.org/WAI/ARIA/1.2/class-diagram/).

Roles are categorized as follows:

1. [Abstract Roles](#abstract_roles)
2. [Widget Roles](#widget_roles)
3. [Document Structure Roles](#document_structure_roles)
4. [Landmark Roles](#landmark_roles)
5. [Live Region Roles](#live_region_roles)
6. [Window Roles](#window_roles)

::: header-wrapper
#### 5.3.1 Abstract Roles

The following [roles](#dfn-role) are used to support the [WAI-ARIA] Roles Model for the
purpose of defining general role concepts.

Abstract roles are used for the ontology. Authors *MUST NOT* use
abstract roles in content.

- [`command`](https://w3c.github.io/aria/#command)
- [`composite`](https://w3c.github.io/aria/#composite)
- [`input`](https://w3c.github.io/aria/#input)
- [`landmark`](https://w3c.github.io/aria/#landmark)
- [`range`](https://w3c.github.io/aria/#range)
- [`roletype`](https://w3c.github.io/aria/#roletype)
- [`section`](https://w3c.github.io/aria/#section)
- [`sectionhead`](https://w3c.github.io/aria/#sectionhead)
- [`select`](https://w3c.github.io/aria/#select)
- [`structure`](https://w3c.github.io/aria/#structure)
- [`widget`](https://w3c.github.io/aria/#widget)
- [`window`](https://w3c.github.io/aria/#window)

::: header-wrapper
#### 5.3.2 Widget Roles

The following roles act as standalone user interface widgets or as part
of larger, composite widgets.

- [`button`](https://w3c.github.io/aria/#button)
- [`checkbox`](https://w3c.github.io/aria/#checkbox)
- [`gridcell`](https://w3c.github.io/aria/#gridcell)
- [`link`](https://w3c.github.io/aria/#link)
- [`menuitem`](https://w3c.github.io/aria/#menuitem)
- [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox)
- [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio)
- [`option`](https://w3c.github.io/aria/#option)
- [`progressbar`](https://w3c.github.io/aria/#progressbar)
- [`radio`](https://w3c.github.io/aria/#radio)
- [`scrollbar`](https://w3c.github.io/aria/#scrollbar)
- [`searchbox`](https://w3c.github.io/aria/#searchbox)
- [`separator`](https://w3c.github.io/aria/#separator)
 (when focusable)
- [`slider`](https://w3c.github.io/aria/#slider)
- [`spinbutton`](https://w3c.github.io/aria/#spinbutton)
- [`switch`](https://w3c.github.io/aria/#switch)
- [`tab`](https://w3c.github.io/aria/#tab)
- [`tabpanel`](https://w3c.github.io/aria/#tabpanel)
- [`textbox`](https://w3c.github.io/aria/#textbox)
- [`treeitem`](https://w3c.github.io/aria/#treeitem)

The following roles act as composite user interface widgets. These roles
typically act as containers that manage other, contained widgets.

- [`combobox`](https://w3c.github.io/aria/#combobox)
- [`grid`](https://w3c.github.io/aria/#grid)
- [`listbox`](https://w3c.github.io/aria/#listbox)
- [`menu`](https://w3c.github.io/aria/#menu)
- [`menubar`](https://w3c.github.io/aria/#menubar)
- [`radiogroup`](https://w3c.github.io/aria/#radiogroup)
- [`tablist`](https://w3c.github.io/aria/#tablist)
- [`tree`](https://w3c.github.io/aria/#tree)
- [`treegrid`](https://w3c.github.io/aria/#treegrid)

::: header-wrapper
#### 5.3.3 Document Structure Roles

The following [roles](#dfn-role) describe structures that organize content in a page.
Document structures are not usually interactive.

- [`application`](https://w3c.github.io/aria/#application)
- [`article`](https://w3c.github.io/aria/#article)
- [`blockquote`](https://w3c.github.io/aria/#blockquote)
- [`caption`](https://w3c.github.io/aria/#caption)
- [`cell`](https://w3c.github.io/aria/#cell)
- [`code`](https://w3c.github.io/aria/#code)
- [`columnheader`](https://w3c.github.io/aria/#columnheader)
- [`comment`](https://w3c.github.io/aria/#comment)
- [`definition`](https://w3c.github.io/aria/#definition)
- [`deletion`](https://w3c.github.io/aria/#deletion)
- [`directory`](https://w3c.github.io/aria/#directory)
- [`document`](https://w3c.github.io/aria/#document)
- [`emphasis`](https://w3c.github.io/aria/#emphasis)
- [`feed`](https://w3c.github.io/aria/#feed)
- [`figure`](https://w3c.github.io/aria/#figure)
- [`generic`](https://w3c.github.io/aria/#generic)
- [`group`](https://w3c.github.io/aria/#group)
- [`heading`](https://w3c.github.io/aria/#heading)
- [`img`](https://w3c.github.io/aria/#img)
- [`insertion`](https://w3c.github.io/aria/#insertion)
- [`list`](https://w3c.github.io/aria/#list)
- [`listitem`](https://w3c.github.io/aria/#listitem)
- [`mark`](https://w3c.github.io/aria/#mark)
- [`math`](https://w3c.github.io/aria/#math)
- [`meter`](https://w3c.github.io/aria/#meter)
- [`none`](https://w3c.github.io/aria/#none)
- [`note`](https://w3c.github.io/aria/#note)
- [`paragraph`](https://w3c.github.io/aria/#paragraph)
- [`presentation`](https://w3c.github.io/aria/#presentation)
- [`row`](https://w3c.github.io/aria/#row)
- [`rowgroup`](https://w3c.github.io/aria/#rowgroup)
- [`rowheader`](https://w3c.github.io/aria/#rowheader)
- [`separator`](https://w3c.github.io/aria/#separator)
 (when not focusable)
- [`strong`](https://w3c.github.io/aria/#strong)
- [`subscript`](https://w3c.github.io/aria/#subscript)
- [`suggestion`](https://w3c.github.io/aria/#suggestion)
- [`superscript`](https://w3c.github.io/aria/#superscript)
- [`table`](https://w3c.github.io/aria/#table)
- [`term`](https://w3c.github.io/aria/#term)
- [`time`](https://w3c.github.io/aria/#time)
- [`toolbar`](https://w3c.github.io/aria/#toolbar)
- [`tooltip`](https://w3c.github.io/aria/#tooltip)

::: header-wrapper
#### 5.3.4 Landmark Roles

The following [roles](#dfn-role) are regions of the page intended as navigational
[landmarks](#dfn-landmark). All of these roles inherit from the `landmark` base
type and all are imported from the [Role
Attribute](https://www.w3.org/TR/role-attribute/#s_role_module_attributes)
\[[ROLE-ATTRIBUTE](#bib-role-attribute "Role Attribute 1.0")\]. The roles are included here in order to make them
clearly part of the [WAI-ARIA] Roles Model.

- [`banner`](https://w3c.github.io/aria/#banner)
- [`complementary`](https://w3c.github.io/aria/#complementary)
- [`contentinfo`](https://w3c.github.io/aria/#contentinfo)
- [`form`](https://w3c.github.io/aria/#form)
- [`main`](https://w3c.github.io/aria/#main)
- [`navigation`](https://w3c.github.io/aria/#navigation)
- [`region`](https://w3c.github.io/aria/#region)
- [`search`](https://w3c.github.io/aria/#search)

::: header-wrapper
#### 5.3.5 Live Region Roles

The following [roles](#dfn-role) are [live
regions](#dfn-live-region) and can be modified by [live region
attributes](#attrs_liveregions).

Typically, assistive technology will only convey *changes* to a live
region, not the initial contents of a live region. To ensure content in
a live region is announced, authors *SHOULD* create a rendered but empty
live region as early as possible (such as on page load), and then modify
the content of the live region when the author expects changes to be
spoken or brailled. The exception to this live region convention is
`alert`, due to system accessibility notifications events required for
the role. While an
[`alert`](https://w3c.github.io/aria/#alert) is a live
region, its content is announced by assistive technology when the alert
is rendered on the page and when the content changes.

- [`alert`](https://w3c.github.io/aria/#alert)
- [`log`](https://w3c.github.io/aria/#log)
- [`marquee`](https://w3c.github.io/aria/#marquee)
- [`status`](https://w3c.github.io/aria/#status)
- [`timer`](https://w3c.github.io/aria/#timer)

::: header-wrapper
#### 5.3.6 Window Roles

The following [roles](#dfn-role) act as windows within the browser or application.

- [`alertdialog`](https://w3c.github.io/aria/#alertdialog)
- [`dialog`](https://w3c.github.io/aria/#dialog)

::: header-wrapper
### 5.4 Definition of Roles

Below is an alphabetical list of [WAI-ARIA]
[roles](#dfn-role).

Abstract roles are used for the ontology. Authors *MUST NOT* use
abstract roles in content.

[`alert`](#alert)
: A type of [live region](#dfn-live-region) with important, and usually time-sensitive,
 information. See related
 [`alertdialog`](https://w3c.github.io/aria/#alertdialog)
 and [`status`](https://w3c.github.io/aria/#status).

[`alertdialog`](#alertdialog)
: A type of dialog that contains an alert message, where initial focus
 goes to an
 [element](https://dom.spec.whatwg.org/#concept-element)
 within the dialog. See related
 [`alert`](https://w3c.github.io/aria/#alert) and
 [`dialog`](https://w3c.github.io/aria/#dialog).

[`application`](#application)
: A
 [`structure`](https://w3c.github.io/aria/#structure)
 containing one or more [focusable](#dfn-focusable) elements requiring user input, such as keyboard or
 gesture events, that do not follow a standard interaction pattern
 supported by a
 [`widget`](https://w3c.github.io/aria/#widget)
 role.

[`article`](#article)
: A section of a page that consists of a composition that forms an
 independent part of a document, page, or site.

[`banner`](#banner)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 that contains mostly site-oriented content, rather than
 page-specific content.

[`blockquote`](#blockquote)
: A section of content that is quoted from another source.

[`button`](#button)
: An input that allows for user-triggered actions when clicked or
 pressed. See related
 [`link`](https://w3c.github.io/aria/#link).

[`caption`](#caption)
: Visible content that names, or describes a
 [`figure`](https://w3c.github.io/aria/#figure),
 [`grid`](https://w3c.github.io/aria/#grid),
 [`group`](https://w3c.github.io/aria/#group),
 [`radiogroup`](https://w3c.github.io/aria/#radiogroup),
 [`table`](https://w3c.github.io/aria/#table) or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).

[`cell`](#cell)
: A cell in a tabular container. See related
 [`gridcell`](https://w3c.github.io/aria/#gridcell).

[`checkbox`](#checkbox)
: A checkable input that has three possible values: `true`, `false`,
 or `mixed`.

[`code`](#code)
: A section whose content represents a fragment of computer code.

[`columnheader`](#columnheader)
: A cell containing header information for a column.

[`combobox`](#combobox)
: An [`input`](https://w3c.github.io/aria/#input)
 that controls another element, such as a
 [`listbox`](https://w3c.github.io/aria/#listbox) or
 [`grid`](https://w3c.github.io/aria/#grid), that
 can dynamically pop up to help the user set the value of the
 [`input`](https://w3c.github.io/aria/#input).

[`command` (abstract role)](#command)
: A form of widget that performs an action but does not receive input
 data.

[`comment`](#comment)
: A comment contains content expressing reaction to other content.

[`complementary`](#complementary)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 that is designed to be complementary to the main content that it is
 a sibling to, or a direct descendant of. The contents of a
 complementary landmark would be expected to remain meaningful if it
 were to be separated from the main content it is relevant to.

[`composite` (abstract role)](#composite)
: A [widget](#dfn-widget) that can
 contain navigable [accessibility
 descendants](#dfn-accessibility-descendant).

[`contentinfo`](#contentinfo)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 that contains information about the parent document.

[`definition`](#definition)
: A definition of a term or concept. See related
 [`term`](https://w3c.github.io/aria/#term).

[`deletion`](#deletion)
: A deletion represents content that is marked as removed, content
 that is being suggested for removal, or content that is no longer
 relevant in the context of its accompanying content. See related
 [`insertion`](https://w3c.github.io/aria/#insertion).

[`dialog`](#dialog)
: A dialog is a descendant window of the primary window of a web
 application. For [HTML]
 pages, the primary application window is the entire web document.

[`directory`](#directory)
: \[Deprecated in [ARIA] 1.2\] A list of
 references to members of a group, such as a static table of
 contents.

[`document`](#document)
: An
 [element](https://dom.spec.whatwg.org/#concept-element)
 containing content that [assistive
 technology](#assistive-technology)
 users might want to browse in a reading mode.

[`emphasis`](#emphasis)
: One or more emphasized characters. See related
 [`strong`](https://w3c.github.io/aria/#strong).

[`feed`](#feed)
: A scrollable
 [`list`](https://w3c.github.io/aria/#list) of
 [`articles`](https://w3c.github.io/aria/#article)
 where scrolling might cause
 [`articles`](https://w3c.github.io/aria/#article)
 to be added to or removed from either end of the list.

[`figure`](#figure)
: A perceivable
 [`section`](https://w3c.github.io/aria/#section) of
 content that typically contains a [graphical
 document](#dfn-graphical-document),
 images, media player, code snippets, or example text. The parts of a
 `figure` *MAY* be user-navigable.

[`form`](#form)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 region that contains a collection of items and objects that, as a
 whole, combine to create a form. See related
 [`search`](https://w3c.github.io/aria/#search).

[`generic`](#generic)
: A nameless container
 [element](https://dom.spec.whatwg.org/#concept-element)
 that has no semantic meaning on its own.

[`grid`](#grid)
: A composite
 [`widget`](https://w3c.github.io/aria/#widget)
 containing a collection of one or more rows with one or more cells
 where some or all cells in the grid are
 [focusable](#dfn-focusable) by using
 methods of two-dimensional navigation, such as directional arrow
 keys.

[`gridcell`](#gridcell)
: A [`cell`](https://w3c.github.io/aria/#cell) in a
 [`grid`](https://w3c.github.io/aria/#grid) or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).

[`group`](#group)
: A set of user interface [objects](#dfn-object) that is not intended to be included in a page
 summary or table of contents by [assistive
 technologies](#assistive-technology).

[`heading`](#heading)
: A heading for a section of the page.

[`image`](#image)
: A container for a collection of
 [elements](https://dom.spec.whatwg.org/#concept-element)
 that form an image. See synonym
 [`img`](https://w3c.github.io/aria/#img).

[`img`](#img)
: A container for a collection of
 [elements](https://dom.spec.whatwg.org/#concept-element)
 that form an image. See synonym
 [`image`](https://w3c.github.io/aria/#image).

[`input` (abstract role)](#input)
: A generic type of [widget](#dfn-widget) that allows user input.

[`insertion`](#insertion)
: An insertion contains content that is marked as added or content
 that is being suggested for addition. See related
 [`deletion`](https://w3c.github.io/aria/#deletion).

[`landmark` (abstract role)](#landmark)
: A perceivable
 [`section`](https://w3c.github.io/aria/#section)
 containing content that is relevant to a specific, author-specified
 purpose and sufficiently important that users will likely want to be
 able to navigate to the section easily and to have it listed in a
 summary of the page. Such a page summary could be generated
 dynamically by a user agent or assistive technology.

[`link`](#link)
: An interactive reference to an internal or external resource that,
 when activated, causes the user agent to navigate to that resource.
 See related
 [`button`](https://w3c.github.io/aria/#button).

[`list`](#list)
: A [`section`](https://w3c.github.io/aria/#section)
 containing
 [`listitem`](https://w3c.github.io/aria/#listitem)
 elements. See related
 [`listbox`](https://w3c.github.io/aria/#listbox).

[`listbox`](#listbox)
: A [widget](#dfn-widget) that allows
 the user to select one or more items from a list of choices. See
 related
 [`combobox`](https://w3c.github.io/aria/#combobox)
 and [`list`](https://w3c.github.io/aria/#list).

[`listitem`](#listitem)
: A single item in a list or directory.

[`log`](#log)
: A type of [live region](#dfn-live-region) where new information is added in meaningful order
 and old information can disappear. See related
 [`marquee`](https://w3c.github.io/aria/#marquee).

[`main`](#main)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 containing the main content of a document.

[`mark`](#mark)
: Content which is marked or highlighted for reference or notation
 purposes, due to the content\'s relevance in the enclosing context.

[`marquee`](#marquee)
: A type of [live region](#dfn-live-region) where non-essential information changes frequently.
 See related
 [`log`](https://w3c.github.io/aria/#log).

[`math`](#math)
: Content that represents a mathematical expression.

[`menu`](#menu)
: A type of [widget](#dfn-widget) that
 offers a list of choices to the user.

[`menubar`](#menubar)
: A presentation of
 [`menu`](https://w3c.github.io/aria/#menu) that
 usually remains visible and is usually presented horizontally.

[`menuitem`](#menuitem)
: An option in a set of choices contained by a
 [`menu`](https://w3c.github.io/aria/#menu) or
 [`menubar`](https://w3c.github.io/aria/#menubar).

[`menuitemcheckbox`](#menuitemcheckbox)
: A
 [`menuitem`](https://w3c.github.io/aria/#menuitem)
 with a checkable state whose possible values are `true`, `false`, or
 `mixed`.

[`menuitemradio`](#menuitemradio)
: A checkable
 [`menuitem`](https://w3c.github.io/aria/#menuitem)
 in a set of elements with the same role, only one of which can be
 checked at a time.

[`meter`](#meter)
: An
 [element](https://dom.spec.whatwg.org/#concept-element)
 that represents a scalar measurement within a known range, or a
 fractional value. See related
 [`progressbar`](https://w3c.github.io/aria/#progressbar).

[`navigation`](#navigation)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 containing a collection of navigational
 [elements](https://dom.spec.whatwg.org/#concept-element)
 (usually links) for navigating the document or related documents.

[`none`](#none)
: An
 [element](https://dom.spec.whatwg.org/#concept-element)
 whose implicit native role semantics will not be mapped to the
 [accessibility [API]](#dfn-accessibility-api). See synonym
 [`presentation`](https://w3c.github.io/aria/#presentation).

[`note`](#note)
: A [`section`](https://w3c.github.io/aria/#section)
 whose content represents additional information or parenthetical
 context to the primary content it supplements.

[`option`](#option)
: An item in a
 [`listbox`](https://w3c.github.io/aria/#listbox).

[`paragraph`](#paragraph)
: A paragraph of content.

[`presentation`](#presentation)
: An
 [element](https://dom.spec.whatwg.org/#concept-element)
 whose implicit native role semantics will not be mapped to the
 [accessibility [API]](#dfn-accessibility-api). See synonym
 [`none`](https://w3c.github.io/aria/#none).

[`progressbar`](#progressbar)
: An
 [element](https://dom.spec.whatwg.org/#concept-element)
 that displays the progress status for tasks that take a long time.

[`radio`](#radio)
: A checkable input in a group of elements with the same role, only
 one of which can be checked at a time.

[`radiogroup`](#radiogroup)
: A group of
 [`radio`](https://w3c.github.io/aria/#radio)
 buttons.

[`range` (abstract role)](#range)
: An element representing a range of values.

[`region`](#region)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 containing content that is relevant to a specific, author-specified
 purpose and sufficiently important that users will likely want to be
 able to navigate to the section easily and to have it listed in a
 summary of the page. Such a page summary could be generated
 dynamically by a user agent or assistive technology.

[`roletype` (abstract role)](#roletype)
: The base [role](#dfn-role) from which
 all other roles inherit.

[`row`](#row)
: A row of cells in a tabular container.

[`rowgroup`](#rowgroup)
: A structure containing one or more row elements in a tabular
 container.

[`rowheader`](#rowheader)
: A cell containing header information for a row.

[`scrollbar`](#scrollbar)
: A graphical object that controls the scrolling of content within a
 viewing area, regardless of whether the content is fully displayed
 within the viewing area.

[`search`](#search)
: A
 [`landmark`](https://w3c.github.io/aria/#landmark)
 region that contains a collection of items and objects that, as a
 whole, combine to create a search facility. See related
 [`form`](https://w3c.github.io/aria/#form) and
 [`searchbox`](https://w3c.github.io/aria/#searchbox).

[`searchbox`](#searchbox)
: A type of textbox intended for specifying search criteria. See
 related
 [`textbox`](https://w3c.github.io/aria/#textbox)
 and [`search`](https://w3c.github.io/aria/#search).

[`section` (abstract role)](#section)
: A renderable structural containment unit on a page.

[`sectionfooter`](#sectionfooter)
: A set of user interface objects and information representing
 information about its closest ancestral content group. For instance,
 a `sectionfooter` can include information about who wrote the
 specific section of content, such as an
 [`article`](https://w3c.github.io/aria/#article).
 It can contain links to related documents, copyright information or
 other indices and colophon specific to the current section of the
 page.

[`sectionhead` (abstract role)](#sectionhead)
: A structure that labels or summarizes the topic of its related
 section.

[`sectionheader`](#sectionheader)
: A set of user interface objects and information that represents a
 collection of introductory items for the element\'s closest
 ancestral content group. For instance, a `sectionheader` can include
 the heading, introductory statement and related meta data for a
 section of content, for instance a
 [`region`](https://w3c.github.io/aria/#region) or
 [`article`](https://w3c.github.io/aria/#article),
 within a web page.

[`select` (abstract role)](#select)
: A form widget that allows the user to make selections from a set of
 choices.

[`separator`](#separator)
: A divider that separates and distinguishes sections of content or
 groups of menuitems.

[`slider`](#slider)
: An input where the user selects a value from within a given range.

[`spinbutton`](#spinbutton)
: A form of
 [`range`](https://w3c.github.io/aria/#range) that
 expects the user to select from among discrete choices.

[`status`](#status)
: A type of [live region](#dfn-live-region) whose content is advisory information for the user
 but is not important enough to justify an
 [`alert`](https://w3c.github.io/aria/#alert), often
 but not necessarily presented as a status bar.

[`strong`](#strong)
: Content that is important, serious, or urgent. See related
 [`emphasis`](https://w3c.github.io/aria/#emphasis).

[`structure` (abstract role)](#structure)
: A document structural
 [element](https://dom.spec.whatwg.org/#concept-element).

[`subscript`](#subscript)
: One or more subscripted characters. See related
 [`superscript`](https://w3c.github.io/aria/#superscript).

[`suggestion`](#suggestion)
: A single proposed change to content.

[`superscript`](#superscript)
: One or more superscripted characters. See related
 [`subscript`](https://w3c.github.io/aria/#subscript).

[`switch`](#switch)
: A type of checkbox that represents on/off values, as opposed to
 checked/unchecked values. See related
 [`checkbox`](https://w3c.github.io/aria/#checkbox).

[`tab`](#tab)
: A grouping label providing a mechanism for selecting the tab content
 that is to be rendered to the user.

[`table`](#table)
: A [`section`](https://w3c.github.io/aria/#section)
 containing data arranged in rows and columns. See related
 [`grid`](https://w3c.github.io/aria/#grid).

[`tablist`](#tablist)
: A list of [`tab`](https://w3c.github.io/aria/#tab)
 [elements](https://dom.spec.whatwg.org/#concept-element),
 which are references to
 [`tabpanel`](https://w3c.github.io/aria/#tabpanel)
 elements.

[`tabpanel`](#tabpanel)
: A container for the resources associated with a
 [`tab`](https://w3c.github.io/aria/#tab), where
 each [`tab`](https://w3c.github.io/aria/#tab) is
 contained in a
 [`tablist`](https://w3c.github.io/aria/#tablist).

[`term`](#term)
: A word or phrase with an optional corresponding definition. See
 related
 [`definition`](https://w3c.github.io/aria/#definition).

[`textbox`](#textbox)
: A type of input that allows free-form text as its value.

[`time`](#time)
: An element that represents a specific point in time.

[`timer`](#timer)
: A type of [live region](#dfn-live-region) containing a numerical counter which indicates an
 amount of elapsed time from a start point, or the time remaining
 until an end point.

[`toolbar`](#toolbar)
: A collection of commonly used function buttons or controls
 represented in compact visual form.

[`tooltip`](#tooltip)
: A contextual popup that displays a description for an element.

[`tree`](#tree)
: A [`widget`](https://w3c.github.io/aria/#widget)
 that allows the user to select one or more items from a
 hierarchically organized collection.

[`treegrid`](#treegrid)
: A [`grid`](https://w3c.github.io/aria/#grid) whose
 rows can be expanded and collapsed in the same manner as for a
 [`tree`](https://w3c.github.io/aria/#tree).

[`treeitem`](#treeitem)
: An item in a
 [`tree`](https://w3c.github.io/aria/#tree).

[`widget` (abstract role)](#widget)
: An interactive component of a graphical user interface ([GUI]).

[`window` (abstract role)](#window)
: A browser or application window.

#### `alert` [role]

A type of [live region](#dfn-live-region) with important, and usually
time-sensitive, information. See related
[`alertdialog`](https://w3c.github.io/aria/#alertdialog)
and [`status`](https://w3c.github.io/aria/#status).

Alerts are used to convey messages that will be immediately important to
users. In the case of audio warnings, visibly displayed alerts provide
an accessible alternative to audible alerts for Deaf or hard-of-hearing
users. Likewise, alerts can provide an accessible alternative to the
visible alerts for blind, deaf-blind, or low-vision users, and others
with certain developmental disabilities. The `alert`
[role](#dfn-role) is
applied to the element containing the alert message.

Alert is a special type of assertive live region that is intended to
cause immediate notification for assistive technology users. If the
operating system allows, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* fire a system alert [event](#dfn-event) through the accessibility [API] when the alert is rendered.

Neither authors nor user agents are required to set or manage focus to
an alert in order for it to be processed. Since alerts are not required
to receive focus, authors *SHOULD NOT* require users to close an alert.
If an author desires focus to move to a message when it is conveyed, the
author *SHOULD* use
[`alertdialog`](https://w3c.github.io/aria/#alertdialog)
instead of `alert`.

Elements with the role `alert` have an implicit
[`aria-live`](https://w3c.github.io/aria/#aria-live)
value of `assertive`, and an implicit
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
value of `true`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`alertdialog`](https://w3c.github.io/aria/#alertdialog) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-live`](https://w3c.github.io/aria/#aria-live) is |
| | `assertive`.\ |
| | Default for [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) is `true`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `alertdialog` [role]

A type of dialog that contains an alert message, where initial focus
goes to an
[element](https://dom.spec.whatwg.org/#concept-element)
within the dialog. See related
[`alert`](https://w3c.github.io/aria/#alert) and
[`dialog`](https://w3c.github.io/aria/#dialog).

Alert dialogs are used to convey messages to alert the user. The
`alertdialog` [role](#dfn-role) goes on the
[node](https://dom.spec.whatwg.org/#concept-node) containing both the alert message and the rest of the
dialog. Authors *SHOULD* make alert dialogs modal by ensuring that,
while the `alertdialog` is shown, keyboard and mouse interactions only
operate within the dialog. See
[`aria-modal`](https://w3c.github.io/aria/#aria-modal).

Alertdialog is a special type of dialog that is intended to cause an
immediate, alert-level notification for assistive technology users. If
the operating system allows, the [user
agent](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* fire a system alert [event](#dfn-event) through the accessibility [API] when the alert dialog is
rendered.

Unlike [`alert`](https://w3c.github.io/aria/#alert),
`alertdialog` can receive a response from the user. For example, to
confirm that the user understands the alert being generated. When the
alert dialog is displayed, authors *SHOULD* set focus to an active
element within the alert dialog, such as a form control or confirmation
button. The [user
agent](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* fire a system alert [event](#dfn-event) through the accessibility [API] when the alert is created,
provided one is specified by the intended [accessibility [API]](#dfn-accessibility-api).

Authors *SHOULD* provide an accessible name for an `alertdialog`, which
can be done with the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute.

Authors *SHOULD* use
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
on an `alertdialog` to reference the alert message element in the
dialog. If they do not, an [assistive
technology](#assistive-technology) can resort to its internal recovery
mechanism to determine the contents of the alert message.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`alert`](https://w3c.github.io/aria/#alert) |
| | - [`dialog`](https://w3c.github.io/aria/#dialog) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-modal`](https://w3c.github.io/aria/#aria-modal) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `application` [role]

A [`structure`](https://w3c.github.io/aria/#structure)
containing one or more
[focusable](#dfn-focusable) elements requiring user input, such as keyboard or
gesture events, that do not follow a standard interaction pattern
supported by a
[`widget`](https://w3c.github.io/aria/#widget) role.

Some [user
agents](https://infra.spec.whatwg.org/#user-agent) and
[assistive
technologies](#assistive-technology) have a browse mode where standard input
events, such as up and down arrow key events, are intercepted and used
to control a reading cursor. This browse mode behavior prevents elements
that do not have a
[`widget`](https://w3c.github.io/aria/#widget) role
from receiving and using such keyboard and gesture events to provide
interactive functionality.

When there is a need to create an element with an interaction model that
is not supported by any of the [WAI-ARIA]
[`widget`](https://w3c.github.io/aria/#widget) roles,
authors *MAY* give that element role `application`. And, when a user
navigates into an element with role `application`, [assistive
technologies](#assistive-technology) that intercept standard input events
*SHOULD* switch to a mode that passes most or all standard input events
through to the web application.

For example, a presentation slide editor uses arrow keys to change the
positions of textbox and image elements on the slide. There are not any
[WAI-ARIA]
[`widget`](https://w3c.github.io/aria/#widget) roles
that correspond to such an interaction model so an author could give the
slide container role `application`, an
[`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription)
of \"Slide Editor\", and use
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
to provide instructions.

Because only the focusable elements contained in an `application`
element are accessible to users of some assistive technologies, authors
*MUST* use one of the following techniques to ensure all non-decorative
static text or image content inside an application is accessible:

1. Associate the content with a focusable element using
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 or
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).
2. Place the content in a focusable element that has role
 [`document`](https://w3c.github.io/aria/#document)
 or
 [`article`](https://w3c.github.io/aria/#article).
3. Manage focus of [accessibility
 descendants](#dfn-accessibility-descendant) as described in [Managing
 Focus](#managingfocus), updating the value of
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 to reference the
 [element](https://dom.spec.whatwg.org/#concept-element)
 containing the focused content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `article` [role]

A section of a page that consists of a composition that forms an
independent part of a document, page, or site.

An article is not a navigational
[landmark](#dfn-landmark), but can be nested to form a discussion where assistive
technologies could pay attention to article nesting to assist the user
in following the discussion. An article could be a forum post, a
magazine or newspaper article, a web log entry, a user-submitted
comment, or any other independent item of content. It is *independent*
in that its contents could stand alone, for example in syndication.
However, the
[element](https://dom.spec.whatwg.org/#concept-element)
is still associated with its ancestors; for instance, contact
information that applies to a parent body element still covers the
article as well. When nesting articles, the child articles represent
content that is related to the content of the parent article. For
instance, a web log entry on a site that accepts user-submitted comments
could represent the comments as articles nested within the article for
the web log entry. Author, heading, date, or other information
associated with an article does not apply to nested articles.

When the user navigates to an element assigned the role of `article`,
[assistive
technologies](#assistive-technology) that typically intercept standard keyboard
events *SHOULD* switch to document browsing mode, as opposed to passing
keyboard events through to the web application. Some assistive
technologies provide a feature allowing the user to navigate the
hierarchy of any nested `article` elements.

When an `article` is in the context of a
[`feed`](https://w3c.github.io/aria/#feed), the author
*MAY* specify values for
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`document`](https://w3c.github.io/aria/#document) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`comment`](https://w3c.github.io/aria/#comment) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`article`](https://html.spec.whatwg.org/multipage/sections.html#the-article-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `banner` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
that contains mostly site-oriented content, rather than page-specific
content.

Site-oriented content typically includes things such as the logo or
identity of the site sponsor, and a site-specific search tool. A banner
usually appears at the top of the page and typically spans the full
width.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `banner`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `banner` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role `banner`.

The author *SHOULD* mark no more than one
[element](https://dom.spec.whatwg.org/#concept-element)
on a page with the `banner` [role](#dfn-role).

Because `document` and `application` elements can be nested in the
[DOM], they can have multiple
`banner` elements as [DOM]
descendants, assuming each of those is associated with different
document nodes, either by a [DOM]
nesting (e.g.,
[`document`](https://w3c.github.io/aria/#document)
within
[`document`](https://w3c.github.io/aria/#document)) or
by use of the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`header`](https://html.spec.whatwg.org/multipage/sections.html#the-header-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `blockquote` [role]

A section of content that is quoted from another source.

+-----------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+================================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`blockquote`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-blockquote-element)`>` |
| | in [HTML] |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `button` [role]

An input that allows for user-triggered actions when clicked or pressed.
See related [`link`](https://w3c.github.io/aria/#link).

Buttons are mostly used for discrete actions. Standardizing the
appearance of buttons enhances the user\'s recognition of the
[widgets](#dfn-widget) as buttons and allows for a more compact display in
toolbars.

Buttons support the optional
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed).
Buttons with a non-empty
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
attribute are toggle buttons. When
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
is `true` the button is in a \"pressed\"
[state](#dfn-state),
when
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
is `false` it is not pressed. If the attribute is not present, the
button is a simple command button.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=====================================================================================================================+
| Superclass Role: | [`command`](https://w3c.github.io/aria/#command) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`button`](https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element)`>` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`link`](https://w3c.github.io/aria/#link) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `caption` [role]

Visible content that names, or describes a
[`figure`](https://w3c.github.io/aria/#figure),
[`grid`](https://w3c.github.io/aria/#grid),
[`group`](https://w3c.github.io/aria/#group),
[`radiogroup`](https://w3c.github.io/aria/#radiogroup),
[`table`](https://w3c.github.io/aria/#table) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

When using `caption` authors *SHOULD* ensure:

- The `caption` is a descendant of a
 [`figure`](https://w3c.github.io/aria/#figure),
 [`grid`](https://w3c.github.io/aria/#grid),
 [`group`](https://w3c.github.io/aria/#group),
 [`radiogroup`](https://w3c.github.io/aria/#radiogroup),
 [`table`](https://w3c.github.io/aria/#table), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
- The `caption` is the first non-`generic` descendant of a
 [`grid`](https://w3c.github.io/aria/#grid),
 [`group`](https://w3c.github.io/aria/#group),
 [`radiogroup`](https://w3c.github.io/aria/#radiogroup),
 [`table`](https://w3c.github.io/aria/#table) or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
- The `caption` is the first or last non-`generic` descendant of a
 [`figure`](https://w3c.github.io/aria/#figure).

If the `caption` represents an accessible name for its containing
element, authors *SHOULD* specify
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
on the containing element to reference the element with role `caption`.

[Example 9](#example-9)

```
<div aria-labelledby="cap">
 <div id="cap">
 Choose your favorite fruit
 </div>
 <!-- ... -->
```

If a `caption` contains content that serves as both a name and
description for its containing element, authors *MAY* instead specify
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
to reference an element within the `caption` that represents the
\"name\" of the containing element, and specify
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
to reference an element within the `caption` that represents the
descriptive content.

[Example 10](#example-10)

```
<div aria-labelledby="name" aria-describedby="desc">
 <div >
 <div id="name">Contest Entrants</div>
 <div id="desc">
 This table shows the total number of entrants (500) the
 contest accepted over the past four weeks.
 </div>
 </div>
 <!-- ... -->
```

If the `caption` represents a long-form description, or if the
description contains semantic elements which are important in
understanding the description, authors *MAY* instead specify
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
to reference an element within the `caption` that represents the
\"name\" of the containing element, and specify
[`aria-details`](https://w3c.github.io/aria/#aria-details)
to reference an element within the `caption` that represents the
descriptive content.

[Example 11](#example-11)

```
<div aria-labelledby="name" aria-details="details">
 <!-- figure content here, such as a complex data viz SVG -->
 <div >
 <div id="name">Sales information for 20XX</div>
 <div id="details">
 This barchart represents the total amount of sales over the course
 of five years. <a href="...">Sales information for last year</a> can
 be reviewed, or you can overlay <button aria-pressed="false">previous year</button>
 information in this graphic.
 </div>
 </div>
 <!-- ... -->
```

If a `caption` contains only a description, without a suitable text
string to serve as the accessible name for its containing element, then
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
*MAY* be used to provide an accessible name, and the `caption` *MAY* be
treated solely as descriptive content, referenced via
[`aria-details`](https://w3c.github.io/aria/#aria-details).

[Example 12](#example-12)

```
<div aria-label="Sales information" aria-details="details">
 <!-- figure content here, such as a complex data viz SVG -->
 <div id="details">
 This barchart represents the total amount of sales over the course
 of five years. <a href="...">Sales information for last year</a> can
 be reviewed, or you can overlay <button aria-pressed="false">previous year</button>
 information in this graphic.
 </div>
 <!-- ... -->
```

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - `<`[`caption`](https://html.spec.whatwg.org/multipage/tables.html#the-caption-element)`>` in [HTML] |
| | - `<`[`figcaption`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-figcaption-element)`>` |
| | in [HTML] |
| | - `<`[`legend`](https://html.spec.whatwg.org/multipage/form-elements.html#the-legend-element)`>` in |
| | [HTML] |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`figure`](https://w3c.github.io/aria/#figure) |
| Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`group`](https://w3c.github.io/aria/#group) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`table`](https://w3c.github.io/aria/#table) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `cell` [role]

A cell in a tabular container. See related
[`gridcell`](https://w3c.github.io/aria/#gridcell).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) cell are the [accessibility
children](#dfn-accessibility-child) of an element with the
[role](#dfn-role)
[`row`](https://w3c.github.io/aria/#row).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`td`](https://html.spec.whatwg.org/multipage/tables.html#the-td-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | [`row`](https://w3c.github.io/aria/#row) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) |
| | - [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext) |
| | - [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan) |
| | - [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) |
| | - [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) |
| | - [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `checkbox` [role]

A checkable input that has three possible values: `true`, `false`, or
`mixed`.

The
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
of a `checkbox` indicates whether the input is checked (`true`),
unchecked (`false`), or represents a group of
[elements](https://dom.spec.whatwg.org/#concept-element)
that have a mixture of checked and unchecked values (`mixed`). Many
checkboxes do not use the `mixed` value, and thus are effectively
boolean checkboxes.

Due to the strong native semantics of [HTML]\'s native checkbox, authors are
advised against using `aria-checked` on an `input type=checkbox`.
Rather, use the native `checked` attribute or the `indeterminate` IDL
attribute to specify the checkbox\'s \"checked\" or \"mixed\" state,
respectively.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================================================================================+
| Superclass Role: | [`input`](https://w3c.github.io/aria/#input) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`switch`](https://w3c.github.io/aria/#switch) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - `<input type="`[`checkbox`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-checkbox-keyword)`">` |
| | in [HTML] |
| | - [`option`](https://w3c.github.io/aria/#option) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `code` [role]

A section whose content represents a fragment of computer code.

The primary purpose of the code role is to inform assistive technologies
that the content is computer code and thus might require special
presentation, in particular with respect to synthesized speech. More
specifically, screen readers and other tools which provide
text-to-speech presentation of content *SHOULD* prefer full punctuation
verbosity to ensure common symbols (e.g., \"-\") are spoken.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`code`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-code-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `columnheader` [role]

A cell containing header information for a column.

`columnheader` can be used as a column header in a table or grid. It
could also be used in a pie chart to show a similar
[relationship](#dfn-relationship) in the data.

The `columnheader` establishes a relationship between it and all cells
in the corresponding column. It is the structural equivalent to an
[HTML] `th`
[element](https://dom.spec.whatwg.org/#concept-element)
with a column scope.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `columnheader` are the [accessibility
children](#dfn-accessibility-child) of an element with the role
[`row`](https://w3c.github.io/aria/#row).

Applying the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
state on a columnheader *MUST* not cause the user agent to automatically
propagate the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
state to all the cells in the corresponding column. An author *MAY*
choose to propagate selection in this manner depending on the specific
application.

While the `columnheader` role can be used in both interactive grids and
non-interactive tables, the use of
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
and
[`aria-required`](https://w3c.github.io/aria/#aria-required)
is only applicable to interactive elements. Therefore, authors *SHOULD
NOT* use
[`aria-required`](https://w3c.github.io/aria/#aria-required)
or
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
in a `columnheader` that descends from a
[`table`](https://w3c.github.io/aria/#table), and user
agents *SHOULD NOT* expose either property to [assistive
technologies](#assistive-technology) unless the `columnheader` descends from a
[`grid`](https://w3c.github.io/aria/#grid).

Because cells are organized into rows, there is not a single container
element for the column. The column is the set of
[`gridcell`](https://w3c.github.io/aria/#gridcell)
elements in a particular position within their respective
[`row`](https://w3c.github.io/aria/#row) containers.

Note[: Usage of aria-disabled]

[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
is currently supported on
[`columnheader`](https://w3c.github.io/aria/#columnheader),
in a future version the working group plans to prohibit its use on
elements with role
[`columnheader`](https://w3c.github.io/aria/#columnheader)
except when the element is in the context of a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`sectionhead`](https://w3c.github.io/aria/#sectionhead) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<th scope="`[`col`](https://html.spec.whatwg.org/multipage/tables.html#attr-th-scope-col)`">` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | [`row`](https://w3c.github.io/aria/#row) |
| Roles: | |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | [`aria-sort`](https://w3c.github.io/aria/#aria-sort) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) |
| | - [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext) |
| | - [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) (state) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) |
| | - [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) |
| | - [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) (state) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `combobox` [role]

An [`input`](https://w3c.github.io/aria/#input) that
controls another element, such as a
[`listbox`](https://w3c.github.io/aria/#listbox) or
[`grid`](https://w3c.github.io/aria/#grid), that can
dynamically pop up to help the user set the value of the
[`input`](https://w3c.github.io/aria/#input).

Editor\'s note[: Major Changes to combobox role in ARIA
1.2]

The Guidance for
[`combobox`](https://w3c.github.io/aria/#combobox) has
changed significantly in [ARIA] 1.2 due to problems with
implementation of the previous patterns. Authors and developers of User
Agents, Assistive Technologies, and Conformance Checkers are advised to
review this section carefully to understand the changes. Explanation of
the changes is available in the [[ARIA] repository
wiki](https://github.com/w3c/aria/blob/main/documentation/archive/1.2/Resolving%20ARIA%201.1%20Combobox%20Issues.md).

A `combobox` functionally combines a named input field with the ability
to assist value selection via a supplementary popup element. A
`combobox` input *MAY* be either a single-line text field that supports
editing and typing or an element that only displays the current value of
the `combobox`. If the `combobox` supports text input and provides
autocompletion behavior as described in
[`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete),
authors *MUST* set
[`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete)
on the `combobox` element to the value that corresponds to the provided
behavior.

Typically, the initial state of a `combobox` is collapsed. In the
collapsed state, only the `combobox` element and a separate, optional
popup control
[`button`](https://w3c.github.io/aria/#button) are
visible. A `combobox` is said to be expanded when both the `combobox`
element showing its current value and its associated popup element are
visible. Authors *MUST* set
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
to `true` on an element with role `combobox` when it is expanded and
`false` when it is collapsed.

Elements with the role `combobox` have an implicit
[`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
value of `listbox`. If the `combobox` popup element has a role other
than [`listbox`](https://w3c.github.io/aria/#listbox),
authors *MUST* specify an
[`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
value of [`tree`](https://w3c.github.io/aria/#tree),
[`grid`](https://w3c.github.io/aria/#grid), or
[`dialog`](https://w3c.github.io/aria/#dialog) that
corresponds to the role of its popup.

If the user interface includes an additional icon that allows the
visibility of the popup to be controlled via pointer and touch events,
authors *SHOULD* ensure that element has role
[`button`](https://w3c.github.io/aria/#button), that it
is [focusable](#dfn-focusable) but not included in the page [Tab] sequence, and
that it is not a descendant of the element with role `combobox`. In
addition, to be keyboard accessible, authors *SHOULD* provide keyboard
mechanisms for moving focus between the `combobox` element and elements
contained in the popup. For example, one common convention is that [Down
Arrow] moves focus from the input to the first focusable
descendant of the popup element. If the popup element supports
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant),
in lieu of moving focus, such keyboard mechanisms can control the value
of
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
on the `combobox` element. When a descendant of the popup element is
active, authors *MAY* set
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
on the `combobox` to a value that refers to the active element within
the popup while focus remains on the `combobox` element.

User agents *MUST* expose the value of elements with role `combobox` to
[assistive
technologies](#assistive-technology). The value of a `combobox` is represented
by one of the following:

- If the `combobox` element is a host language element that provides a
 value, such as an [HTML]
 `input` element, the value of the combobox is the value of that
 element.
- Otherwise, the value of the `combobox` is represented by its
 descendant elements and can be determined using the same method used
 to compute the name of a
 [`button`](https://w3c.github.io/aria/#button) from
 its descendant content.

[Example 13](#example-13)

```
<label id="tag_label" for="tag_combo">Tag</label>
 <input type="text" id="tag_combo"
 aria-autocomplete="list"
 aria-haspopup="listbox" aria-expanded="true"
 aria-controls="popup_listbox" aria-activedescendant="selected_option">
<ul id="popup_listbox" aria-labelledby="tag_label">
 <li >Zebra</li>
 <li id="selected_option">Zoom</li>
</ul>
```

Editor\'s note[: Validity changes combobox for ARIA 1.2]

Please review the following carefully. As a result of these changes a
combobox following the [ARIA] 1.1 combobox
specification will no longer conform with the [ARIA] specification.

The structural requirements for `combobox` defined by this version of
the specification are different from the requirements defined by
[ARIA] 1.0 and
[ARIA] 1.1:

- The [ARIA] 1.0
 specification required the input element with the `combobox` role to
 be a single-line text field and reference the popup element with
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 instead of
 [`aria-controls`](https://w3c.github.io/aria/#aria-controls).
- The [ARIA] 1.1
 specification, which was not broadly supported by assistive
 technologies, required the `combobox` to be a non-focusable element
 with two required [accessibility
 children](#dfn-accessibility-child) \-- a focusable
 [`textbox`](https://w3c.github.io/aria/#textbox) and
 a popup element controlled by the
 [`textbox`](https://w3c.github.io/aria/#textbox).
- The changes introduced in [ARIA] 1.2 improve
 interoperability with assistive technologies and enable authors to
 create presentations of combobox that more closely imitate a native
 [HTML] `select` element.

The features and behaviors of combobox implementations vary widely.
Consequently, there are many important authoring considerations. See the
[[ARIA] Authoring
Practices Guide](https://www.w3.org/WAI/ARIA/apg/) for additional
details on implementing combobox design patterns.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=====================================================================================================================+
| Superclass Role: | [`input`](https://w3c.github.io/aria/#input) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element)`>` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) is |
| | `listbox`.\ |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `command` [abstract role]

A form of widget that performs an action but does not receive input
data.

`command` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `command` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`button`](https://w3c.github.io/aria/#button) |
| | - [`link`](https://w3c.github.io/aria/#link) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `comment` [role]

A comment contains content expressing reaction to other content.

Comments can annotate any visible content, from small spans of text, to
other comments, to entire articles. Authors *SHOULD* identify the
relationships between comments and the commented content, as follows:

1. If the comment is a reply to another `comment`:
 - If all ancestor comments are available in the [DOM], make each reply `comment` a
 semantic descendant of the `comment` to which it is replying,
 either by making it a [DOM]
 descendant element or by using
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns).
 - Alternatively, if all ancestor comments are not in the [DOM], such as when comments are
 paginated, the hierarchical level *MAY* be indicated via
 [`aria-level`](https://w3c.github.io/aria/#aria-level).
 Additional group positional information *MAY* be indicated via
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
 and
 [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).
2. Otherwise, if the comment relates to other content in the page:
 - Provide
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 on the element containing the commented content with a value
 refering to the element with role `comment`.
 - If there are multiple comments related to the same commented
 content, either provide a value for
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 on the commented content that refers to each individual comment,
 or use
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 to refer to a parent container of the comments. If
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 refers to an element containing comments rather than `comment`
 elements, authors *SHOULD* assign a role of
 [`group`](https://w3c.github.io/aria/#group) or
 [`region`](https://w3c.github.io/aria/#region) to
 the referenced container.

If the author has not explicitly declared
[`aria-level`](https://w3c.github.io/aria/#aria-level),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
or
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
for a `comment` element, user agents *MUST* automatically compute the
missing values and expose them to assistive technologies.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`article`](https://w3c.github.io/aria/#article) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-level`](https://w3c.github.io/aria/#aria-level) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `complementary` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
that is designed to be complementary to the main content that it is a
sibling to, or a direct descendant of. The contents of a complementary
landmark would be expected to remain meaningful if it were to be
separated from the main content it is relevant to.

There are various types of content that would appropriately have this
[role](#dfn-role).
For example, in the case of a portal, this can include but not be
limited to show times, current weather, related articles, or stocks to
watch. If the complementary content is completely separable from the
main content, it might be appropriate to use a more general role.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `complementary`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `complementary` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role
`complementary`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`aside`](https://html.spec.whatwg.org/multipage/sections.html#the-aside-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `composite` [abstract role]

A [widget](#dfn-widget) that can contain navigable [accessibility
descendants](#dfn-accessibility-descendant).

Authors *SHOULD* ensure that a composite widget exists as a single
navigation stop within the larger navigation system of the web page.
Once the composite widget has focus, authors *SHOULD* provide a separate
navigation mechanism for users to navigate to
[elements](https://dom.spec.whatwg.org/#concept-element)
that are [accessibility
descendants](#dfn-accessibility-descendant) of the composite element.

`composite` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `composite` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`select`](https://w3c.github.io/aria/#select) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`tablist`](https://w3c.github.io/aria/#tablist) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `contentinfo` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
that contains information about the parent document.

Examples of information included in this region of the page are
copyrights and links to privacy statements.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `contentinfo`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `contentinfo` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role
`contentinfo`.

The author *SHOULD* mark no more than one
[element](https://dom.spec.whatwg.org/#concept-element)
on a page with the `contentinfo` role.

Because `document` and `application` elements can be nested in the
[DOM], they can have multiple
`contentinfo` elements as [DOM]
descendants, assuming each of those is associated with different
document nodes, either by a [DOM]
nesting (e.g.,
[`document`](https://w3c.github.io/aria/#document)
within
[`document`](https://w3c.github.io/aria/#document)) or
by use of the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
attribute.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`footer`](https://html.spec.whatwg.org/multipage/sections.html#the-footer-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `definition` [role]

A definition of a term or concept. See related
[`term`](https://w3c.github.io/aria/#term).

Authors *MUST* identify the
[element](https://dom.spec.whatwg.org/#concept-element)
being defined and assign that element a role of
[`term`](https://w3c.github.io/aria/#term).

Authors *SHOULD NOT* use the `definition` role on interactive elements
such as form controls because doing so could prevent users of assistive
technologies from interacting with those elements.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `deletion` [role]

A deletion represents content that is marked as removed, content that is
being suggested for removal, or content that is no longer relevant in
the context of its accompanying content. See related
[`insertion`](https://w3c.github.io/aria/#insertion).

Deletions are typically used to either mark differences between two
versions of content or to designate content suggested for removal in
scenarios where multiple people are revising content.

+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+====================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - `<`[`del`](https://html.spec.whatwg.org/multipage/edits.html#the-del-element)`>` in |
| | [HTML] |
| | - `<`[`s`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-s-element)`>` |
| | in [HTML] |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `dialog` [role]

A dialog is a descendant window of the primary window of a web
application. For [HTML] pages,
the primary application window is the entire web document.

Dialogs are often used to prompt the user to enter or respond to
information, or can represent content related to understanding or
modifying the content of the primary application window. A dialog that
is designed to interrupt workflow and prevent users from interacting
with the primary web application is usually modal. See related
[`alertdialog`](https://w3c.github.io/aria/#alertdialog).
A dialog that allows for the user to switch between interacting with the
content of the primary web application and the content the dialog is
usually modeless (i.e., non-modal). In lieu of using robust host
language features for marking content of the primary web application as
`inert`, authors *SHOULD* use the
[`aria-modal`](https://w3c.github.io/aria/#aria-modal)
attribute, and constrain focus to dialogs. See the [[WAI-ARIA] Authoring Practices:
Dialog (modal)
pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) for
additional details on implementing modal dialog design patterns.

Authors *SHOULD* provide an accessible name for a dialog, which can be
done with the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute.

Authors *SHOULD* ensure that all dialogs (both modal and non-modal) have
at least one [focusable](#dfn-focusable) descendant element. Authors *SHOULD* focus
an element in the modal dialog when it is displayed, and authors
*SHOULD* constrain keyboard focus to focusable elements within a modal
dialog, until dismissed.

Authors *SHOULD* provide a dialog an accessible description, with the
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
attribute, for instances where authors have set initial keyboard focus
on an element that follows content that outlines the purpose of the
dialog. Assistive technology *SHOULD* give precedence to exposing author
defined dialog accessible descriptions when a dialog is invoked and user
focus is moved to a descendant of the dialog element.

Authors are strongly encouraged to use
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby),
rather than
[`aria-description`](https://w3c.github.io/aria/#aria-description),
to provide descriptions to dialogs. While `aria-description` could be
used to provide an accessible description for a dialog, it will provide
a better and more consistent user experience to reference visible
content that can also be independently read by all users. Doing so will
help ensure important descriptive information is less likely to be
missed.

[Example 14](#example-14)

In the following example, the first text field will receive initial
focus when the dialog is rendered. As this means focus will be set
\"after\" the preceding content that provides instructions for the form
fields, an `aria-describedby` attribute is used to expose this content
as a description for the `dialog`.

[Example](#example-14-0)

```
<div aria-labelledby="h" aria-describedby="d" aria-modal="true" ...>
 <h2 id="h">Add Shipping Address</h2>
 <p id="d">By placing an order on this website, you acknowledge we will be sending you tons of junk mail for you to immediately recycle. Thanks!</p>
 <label>
 Street: <input autofocus ...>
 </label>
 ...
</div>
```

In the description of this role, the term \"web application\" does not
refer to the
[`application`](https://w3c.github.io/aria/#application)
role, which specifies specific assistive technology behaviors.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`window`](https://w3c.github.io/aria/#window) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`alertdialog`](https://w3c.github.io/aria/#alertdialog) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-modal`](https://w3c.github.io/aria/#aria-modal) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `directory` [role]

\[Deprecated in [ARIA] 1.2\] A list of
references to members of a group, such as a static table of contents.

As exposed by accessibility [APIs], the `directory`
[role](#dfn-role) is
essentially equivalent to the `list`
[role](#dfn-role).
So, using `directory` does not provide any additional benefits to
assistive technology users. Authors are advised to treat `directory` as
deprecated and to use `list`, or a host language\'s equivalent semantics
instead.

A `directory` is a static table of contents, whether linked or unlinked.
This includes tables of contents built with lists, including nested
lists. Dynamic tables of contents, however, might use a
[`tree`](https://w3c.github.io/aria/#tree) role
instead.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`list`](https://w3c.github.io/aria/#list) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `document` [role]

[element](https://dom.spec.whatwg.org/#concept-element)
containing content that [assistive
technology](#assistive-technology) users might want to browse in a reading
mode.

When [user
agent](https://infra.spec.whatwg.org/#user-agent) focus
moves to an element assigned the role of `document`, [assistive
technologies](#assistive-technology) having a reading mode for browsing static
content *MAY* switch to that reading mode and intercept standard input
events, such as Up or Down arrow keyboard events, to control the reading
cursor.

Because [assistive
technologies](#assistive-technology) that have a reading mode default to that
mode for all elements except for those with either a
[`widget`](https://w3c.github.io/aria/#widget) or
[`application`](https://w3c.github.io/aria/#application)
role, the only circumstance where the `document` role is useful for
changing assistive technology behavior is when the element with role
`document` is a [focusable](#dfn-focusable) child element of a
[`widget`](https://w3c.github.io/aria/#widget) or
[`application`](https://w3c.github.io/aria/#application).
For example, given an
[`application`](https://w3c.github.io/aria/#application)
element which contains some static rich text, the author can apply role
`document` to the element containing the text and give it a `tabindex`
of `0`. When a screen reader user presses the Tab key and places focus
on the `document` element, the user will be able to read the text with
the screen reader\'s reading cursor.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`article`](https://w3c.github.io/aria/#article) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `emphasis` [role]

One or more emphasized characters. See related
[`strong`](https://w3c.github.io/aria/#strong).

The purpose of the `emphasis` role is to stress or emphasize content. It
is not for communicating changes in typographical presentation that do
not impact the meaning of the content. Authors *SHOULD* use the
`emphasis` role only if its absence would change the meaning of the
content.

The `emphasis` role is not intended to convey importance; for that
purpose, the
[`strong`](https://w3c.github.io/aria/#strong) role is
more appropriate.

+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+====================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`em`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-em-element)`>` |
| | in [HTML] |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `feed` [role]

A scrollable [`list`](https://w3c.github.io/aria/#list)
of [`articles`](https://w3c.github.io/aria/#article)
where scrolling might cause
[`articles`](https://w3c.github.io/aria/#article) to be
added to or removed from either end of the list.

A `feed` enables users of [assistive
technologies](#assistive-technology) that have a document browse mode, such as
screen readers, to use the browse mode reading cursor to both read and
scroll through a stream of rich content that might continue scrolling
infinitely by loading more content as the user reads. In a `feed`,
[assistive
technologies](#assistive-technology) provide a web application with signals of
the user\'s reading cursor movement by moving [user
agent](https://infra.spec.whatwg.org/#user-agent)
focus, enabling the application to both add new content and visually
position content as the user browses the page. The `feed` also lets
authors inform assistive technologies when additions and removals are
occurring so assistive technologies can more reliably update their
reading view without disrupting reading or degrading performance.

For example, a `feed` could be used to present a stream of news stories
where each
[`article`](https://w3c.github.io/aria/#article)
contains a story with text, links, images, and comments as well as
widgets for sharing and commenting. As a screen reader user reads and
interacts with each story and moves the screen reader reading cursor
from story to story, each story scrolls into view and, as needed, new
stories are loaded.

A `feed` is a container element whose children have role
[`article`](https://w3c.github.io/aria/#article). When
[`articles`](https://w3c.github.io/aria/#article) are
added or removed from either or both ends of a `feed`, authors *SHOULD*
set
[`aria-busy`](https://w3c.github.io/aria/#aria-busy)
to `true` on the `feed` element before the changes are made and set it
to `false` after the changes are complete. Authors *SHOULD* avoid
inserting or removing
[`articles`](https://w3c.github.io/aria/#article) in
the middle of a `feed`. These requirements help [assistive
technologies](#assistive-technology) gracefully respond to changes in the
`feed` content that occur simultaneously with user commands to move the
reading cursor within the `feed`.

Authors *SHOULD* make each
[`article`](https://w3c.github.io/aria/#article) in a
`feed` [focusable](#dfn-focusable) and ensure that the application scrolls an
[`article`](https://w3c.github.io/aria/#article) into
view when [user
agent](https://infra.spec.whatwg.org/#user-agent) focus
is set on the
[`article`](https://w3c.github.io/aria/#article) or one
of its descendant elements. For example, in [HTML], each
[`article`](https://w3c.github.io/aria/#article)
element should have a `tabindex` value of either `-1` or `0`.

When an [assistive
technology](#assistive-technology) reading cursor moves from one
[`article`](https://w3c.github.io/aria/#article) to
another, [assistive
technologies](#assistive-technology) *SHOULD* set user agent focus on the
[`article`](https://w3c.github.io/aria/#article) that
contains the reading cursor. If the reading cursor lands on a focusable
element inside the
[`article`](https://w3c.github.io/aria/#article), the
assistive technology *MAY* set focus on that element in lieu of setting
focus on the containing
[`article`](https://w3c.github.io/aria/#article).

Because the ability to scroll to another
[`article`](https://w3c.github.io/aria/#article) with
an [assistive
technology](#assistive-technology) reading cursor depends on the presence of
another
[`article`](https://w3c.github.io/aria/#article) in the
page, authors *SHOULD* attempt to load additional
[`articles`](https://w3c.github.io/aria/#article)
before [user
agent](https://infra.spec.whatwg.org/#user-agent) focus
reaches an
[`article`](https://w3c.github.io/aria/#article) at
either end of the set of
[`articles`](https://w3c.github.io/aria/#article) that
has been loaded. Alternatively, authors *MAY* include an
[`article`](https://w3c.github.io/aria/#article) at
either or both ends of the loaded set of
[`articles`](https://w3c.github.io/aria/#article) that
includes an element, such as a
[`button`](https://w3c.github.io/aria/#button), that
lets the user request more
[`articles`](https://w3c.github.io/aria/#article) to be
loaded.

In addition to providing a brief label, authors *MAY* apply
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
to [`article`](https://w3c.github.io/aria/#article)
elements in a `feed` to suggest to screen readers which elements to
speak after the label when users navigate by
[`article`](https://w3c.github.io/aria/#article).
Screen readers *MAY* provide users with a way to quickly scan `feed`
content by speaking both the label and [accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description) when navigating by
[`article`](https://w3c.github.io/aria/#article),
enabling the user to ignore repetitive or less important elements, such
as embedded interaction widgets, that the author has left out of the
description.

Authors *SHOULD* provide keyboard commands for moving focus among
[`articles`](https://w3c.github.io/aria/#article) in a
`feed` so users who do not utilize an assistive technology that provides
[`article`](https://w3c.github.io/aria/#article)
navigation features can use the keyboard to navigate the `feed`.

If the number of articles available in a `feed` supply is static,
authors *MAY* specify
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
on [`article`](https://w3c.github.io/aria/#article)
elements in that `feed`. However, if the total number is extremely
large, indefinite, or changes often, authors *MAY* set
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
to `-1` to communicate the unknown size of the set.

See the [[ARIA]
Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) for
additional details on implementing a feed design pattern.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`list`](https://w3c.github.io/aria/#list) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | [`article`](https://w3c.github.io/aria/#article) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `figure` [role]

A perceivable
[`section`](https://w3c.github.io/aria/#section) of
content that typically contains a [graphical
document](#dfn-graphical-document), images, media player, code snippets, or
example text. The parts of a `figure` *MAY* be user-navigable.

Authors *SHOULD* provide a reference to the `figure` from the main text,
but the `figure` need not be displayed at the same location as the
referencing element. Authors *MAY* provide a `figure` a
[`caption`](https://w3c.github.io/aria/#caption) which
can include its name, descriptive text, or both. If a `caption` is
provided, and it serves as a description to the contents of the
`figure`, authors *SHOULD* associate it to the `figure` element using
[`aria-details`](https://w3c.github.io/aria/#aria-details).

Authors *MAY* provide a `figure` an accessible name using
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or use
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
to reference other text in the page to serve as the element\'s label and
accessible name.

Please refer to the
[`caption`](https://w3c.github.io/aria/#caption) role
for more information on how to associate a `figure` with its `caption`.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to figures. [User
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to figures.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`figure`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-figure-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `form` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
region that contains a collection of items and objects that, as a whole,
combine to create a form. See related
[`search`](https://w3c.github.io/aria/#search).

A form can contain a mix of host language form controls, scripted
controls, and hyperlinks. Authors are reminded to use native host
language semantics to create form controls whenever possible. If the
purpose of a form is to submit search criteria, authors *SHOULD* use the
[`search`](https://w3c.github.io/aria/#search) role
instead of the generic `form` role.

Authors *SHOULD* give each element with role `form` a brief label that
describes the purpose of the form. Authors *SHOULD* reference a visible
label with
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
if a visible label is present. Authors *SHOULD* include the label inside
of a heading whenever possible. The heading *MAY* be an instance of the
standard host language heading element or an instance of an element with
role [`heading`](https://w3c.github.io/aria/#heading).

If an author uses a script to submit a form based on a user action that
would otherwise not trigger an `onsubmit` event (for example, a form
submission triggered by the user changing a form element\'s value), the
author *SHOULD* provide the user with advance notification of the
behavior.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `form`. [User
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `form` and an accessible name as
navigational [landmarks](#dfn-landmark). [User
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role `form`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`form`](https://html.spec.whatwg.org/multipage/forms.html#the-form-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `generic` [role]

A nameless container
[element](https://dom.spec.whatwg.org/#concept-element)
that has no semantic meaning on its own.

The `generic` role is intended for use as the implicit role of generic
elements in host languages (such as [HTML] `div` or `span`), so is primarily for
implementors of user agents. Authors *SHOULD NOT* use this role in
content. Authors *MAY* use
[`presentation`](https://w3c.github.io/aria/#presentation)
or [`none`](https://w3c.github.io/aria/#none) to remove
implicit accessibility semantics, or a semantic container role such as
[`group`](https://w3c.github.io/aria/#group) to
semantically group descendants in a named container.

Like an element with role
[`presentation`](https://w3c.github.io/aria/#presentation),
an element with role `generic` can provide a limited number of
accessible states and properties for its descendants, such as
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attributes.

However, unlike elements with role `presentation`, user agents expose
`generic` elements in [accessibility [APIs]](#dfn-accessibility-api) when permitted accessibility attributes
have been specified. User agents *MAY* otherwise ignore `generic`
elements if such permitted attributes have not been specified.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [HTML] |
| | [`div`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-div-element), |
| | [HTML] |
| | [`span`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-span-element) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `grid` [role]

A composite
[`widget`](https://w3c.github.io/aria/#widget)
containing a collection of one or more rows with one or more cells where
some or all cells in the grid are
[focusable](#dfn-focusable) by using methods of two-dimensional navigation, such as
directional arrow keys.

The `grid` role does not imply a specific visual, e.g., tabular,
presentation. It describes
[relationships](#dfn-relationship) among
[elements](https://dom.spec.whatwg.org/#concept-element).
It can be used for purposes as simple as grouping a collection of
checkboxes or navigation links or as complex as creating a full-featured
spreadsheet application.

The cell elements of a `grid` have role
[`gridcell`](https://w3c.github.io/aria/#gridcell).
Authors *MAY* designate a cell as a row or column header by using either
the
[`rowheader`](https://w3c.github.io/aria/#rowheader) or
[`columnheader`](https://w3c.github.io/aria/#columnheader)
[role](#dfn-role) in
lieu of the
[`gridcell`](https://w3c.github.io/aria/#gridcell)
role. Authors *MUST* ensure elements with role
[`gridcell`](https://w3c.github.io/aria/#gridcell),
[`columnheader`](https://w3c.github.io/aria/#columnheader),
or [`rowheader`](https://w3c.github.io/aria/#rowheader)
are [accessibility
children](#dfn-accessibility-child) of elements with role
[`row`](https://w3c.github.io/aria/#row), which are in
turn are [accessibility
children](#dfn-accessibility-child) of an element with role
[`rowgroup`](https://w3c.github.io/aria/#rowgroup), or
`grid`.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants of a `grid` as described in [Managing
Focus](#managingfocus). When a user is navigating the `grid` content
with a keyboard, authors *SHOULD* set focus as follows:

- If a
 [`gridcell`](https://w3c.github.io/aria/#gridcell)
 contains a single interactive
 [`widget`](https://w3c.github.io/aria/#widget) that
 will not consume arrow key presses when it receives focus, such as a
 [`checkbox`](https://w3c.github.io/aria/#checkbox),
 [`button`](https://w3c.github.io/aria/#button), or
 [`link`](https://w3c.github.io/aria/#link), authors
 *MAY* set focus on the interactive element contained in that cell.
 This allows the contained widget to be directly operable.
- Otherwise, authors *SHOULD* ensure the element that receives focus is
 a [`gridcell`](https://w3c.github.io/aria/#gridcell),
 [`rowheader`](https://w3c.github.io/aria/#rowheader),
 or
 [`columnheader`](https://w3c.github.io/aria/#columnheader)
 element.

Authors *SHOULD* provide a mechanism for changing to an interaction or
edit mode that allows users to navigate and interact with content
contained inside a focusable cell if that focusable cell contains any of
the following:

- a widget that requires arrow keys to operate, e.g., a
 [`combobox`](https://w3c.github.io/aria/#combobox) or
 [`radiogroup`](https://w3c.github.io/aria/#radiogroup)
- multiple interactive elements
- editable content

For example, if a cell in a spreadsheet contains a
[`combobox`](https://w3c.github.io/aria/#combobox) or
editable text, the [Enter] key might be used to activate a cell
interaction or editing mode when that cell has focus so the directional
arrow keys can be used to operate the contained
[`combobox`](https://w3c.github.io/aria/#combobox) or
[`textbox`](https://w3c.github.io/aria/#textbox).
Depending on the implementation, pressing [Enter] again,
[Tab], [Escape], or another key might switch the application
back to the grid navigation mode.

Authors *MAY* use a
[`gridcell`](https://w3c.github.io/aria/#gridcell) to
display the result of a formula, which could be editable by the user. In
a spreadsheet application, for example, a
[`gridcell`](https://w3c.github.io/aria/#gridcell)
might show a value calculated from a formula until the user activates
the [`gridcell`](https://w3c.github.io/aria/#gridcell)
for editing when a
[`textbox`](https://w3c.github.io/aria/#textbox)
appears in the
[`gridcell`](https://w3c.github.io/aria/#gridcell)
containing the formula in an editable state.

If
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
is set on an element with role `grid`, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* propagate the value to all
[`gridcell`](https://w3c.github.io/aria/#gridcell)
elements that are [accessibility
descendants](#dfn-accessibility-descendant) of that `grid` and expose the value in the
accessibility [API]. An
author *MAY* override the propagated value of
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
for an individual
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element.

In a `grid` that provides cell content editing functions, if the content
of a focusable
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element is not editable, authors *MAY* set
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
to `true` on the `gridcell` element. However, the value of
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly),
whether specified for a `grid` or individual cells, only indicates
whether the content contained in cells is editable. It does not
represent availability of functions for navigating or manipulating the
`grid` itself.

An unspecified value for
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
does not imply that a `grid` or a
[`gridcell`](https://w3c.github.io/aria/#gridcell)
contains editable content. For example, if a `grid` presents a
collection of elements that are not editable, such as a collection of
[`link`](https://w3c.github.io/aria/#link) elements
representing dates in a datepicker, it is not necessary for the author
to specify a value for
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly).

Authors *MAY* indicate that a focusable
[`gridcell`](https://w3c.github.io/aria/#gridcell) is
selectable as the object of an action with the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
attribute. If the `grid` allows multiple
[`gridcell`](https://w3c.github.io/aria/#gridcell)s to
be selected, the author *SHOULD* set
[`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
to `true` on the element with role `grid`.

Since [WAI-ARIA]
can augment an element of the host language, a `grid` can reuse the
elements and attributes of a native table, such as an [HTML] `table` element. For example, if an
author applies the `grid` role to an [HTML] `table` element, the author does not
need to apply the
[`row`](https://w3c.github.io/aria/#row) and
[`gridcell`](https://w3c.github.io/aria/#gridcell)
roles to the descendant [HTML]
`tr` and `td` elements because the [user
agent](https://infra.spec.whatwg.org/#user-agent) will
automatically make the appropriate translations. When the author is
reusing a native host language table element and needs a
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element to span multiple rows or columns, the author *SHOULD* apply the
appropriate host language attributes instead of [WAI-ARIA]
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)
or
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)
properties.

Authors *SHOULD* provide an accessible name for a `grid`, which can be
done with the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute. Authors *SHOULD* reference a visible label with
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
if a visible label is present for the `grid`.

See the [[ARIA]
Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/) for
additional details on implementing grid design patterns.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`table`](https://w3c.github.io/aria/#table) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`table`](https://html.spec.whatwg.org/multipage/tables.html#the-table-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`caption`](https://w3c.github.io/aria/#caption) |
| Roles: | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`rowgroup`](https://w3c.github.io/aria/#rowgroup) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `gridcell` [role]

A [`cell`](https://w3c.github.io/aria/#cell) in a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

A `gridcell` can be [focusable](#dfn-focusable), editable, and selectable. A `gridcell`
can have [relationships](#dfn-relationship) such as
[`aria-controls`](https://w3c.github.io/aria/#aria-controls)
to address the application of functional relationships.

If an author intends a `gridcell` to have a row header, column header,
or both, and if the relevant headers cannot be determined from the
[DOM] structure, authors *SHOULD*
explicitly indicate which header cells are relevant to the `gridcell` by
applying
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
on the `gridcell` and referencing
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role)
[`rowheader`](https://w3c.github.io/aria/#rowheader) or
[`columnheader`](https://w3c.github.io/aria/#columnheader).

In a
[`treegrid`](https://w3c.github.io/aria/#treegrid),
authors *MAY* define a `gridcell` as expandable by using the
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
attribute. If the
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
attribute is provided, it applies only to the individual cell. It is not
a proxy for the container
[`row`](https://w3c.github.io/aria/#row), which also
can be expanded. The main use case for providing this attribute on a
`gridcell` is pivot table behavior.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) gridcell are [accessibility
children](#dfn-accessibility-child) of an element with the
[role](#dfn-role)
[`row`](https://w3c.github.io/aria/#row).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`td`](https://html.spec.whatwg.org/multipage/tables.html#the-td-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | [`row`](https://w3c.github.io/aria/#row) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) |
| | - [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext) |
| | - [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) |
| | - [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) |
| | - [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `group` [role]

A set of user interface [objects](#dfn-object) that is not intended to be included in a
page summary or table of contents by [assistive
technologies](#assistive-technology).

Contrast with
[`region`](https://w3c.github.io/aria/#region), which
is a grouping of user interface objects that will be included in a page
summary or table of contents.

Authors *SHOULD* use a `group` to form a logical collection of items in
a [widget](#dfn-widget), such as children in a tree widget forming a collection
of siblings in a hierarchy. However, when a `group` is used in the
context of a
[`listbox`](https://w3c.github.io/aria/#listbox), for
example, authors *MUST* limit its children to
[`option`](https://w3c.github.io/aria/#option)
elements. Therefore, proper handling of `group` by authors and assistive
technologies is determined by the context in which it is provided.

Authors *MAY* nest `group` elements. If a section is significant enough
to warrant inclusion in the web page\'s table of contents, the author
*SHOULD* assign it a [role](#dfn-role) of
[`region`](https://w3c.github.io/aria/#region) or a
[standard landmark role](#landmark_roles).

+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=========================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`select`](https://w3c.github.io/aria/#select) |
| | - [`toolbar`](https://w3c.github.io/aria/#toolbar) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`fieldset`](https://html.spec.whatwg.org/multipage/form-elements.html#the-fieldset-element)`>` |
| | in [HTML] |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `heading` [role]

A heading for a section of the page.

To ensure elements with a role of `heading` are organized into a logical
outline, authors *MUST* use the
[`aria-level`](https://w3c.github.io/aria/#aria-level)
attribute to indicate the proper nesting level.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`sectionhead`](https://w3c.github.io/aria/#sectionhead) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`h1`](https://html.spec.whatwg.org/multipage/sections.html#the-h1-element)`>`, |
| | `<`[`h2`](https://html.spec.whatwg.org/multipage/sections.html#the-h2-element)`>`, |
| | `<`[`h3`](https://html.spec.whatwg.org/multipage/sections.html#the-h3-element)`>`, |
| | `<`[`h4`](https://html.spec.whatwg.org/multipage/sections.html#the-h4-element)`>`, |
| | `<`[`h5`](https://html.spec.whatwg.org/multipage/sections.html#the-h5-element)`>`, and |
| | `<`[`h6`](https://html.spec.whatwg.org/multipage/sections.html#the-h6-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | [`aria-level`](https://w3c.github.io/aria/#aria-level) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `image` [role]

A container for a collection of
[elements](https://dom.spec.whatwg.org/#concept-element)
that form an image. See synonym
[`img`](https://w3c.github.io/aria/#img).

An `img` can contain captions and descriptive text, as well as multiple
image files that when viewed together give the impression of a single
image. An `img` represents a single graphic within a document, whether
or not it is formed by a collection of drawing
[objects](#dfn-object). In order for an element with a
[role](#dfn-role) of
`img` to be [perceivable](#dfn-perceivable), authors *MUST* provide the element with
an [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name). This can be done using the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute.

Note regarding the [ARIA] 1.3 `image` role.

The `image` role was added to [ARIA] in version 1.3 as a
synonym of the [ARIA] 1.0
[`img`](https://w3c.github.io/aria/#img) role. The
`image` role improves syntactic consistency with the names of other
roles, which are complete words or concatenations of complete words.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`img`](https://html.spec.whatwg.org/multipage/embedded-content.html#the-img-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `img` [role]

A container for a collection of
[elements](https://dom.spec.whatwg.org/#concept-element)
that form an image. See synonym
[`image`](https://w3c.github.io/aria/#image).

#### `input` [abstract role]

A generic type of [widget](#dfn-widget) that allows user input.

`input` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `input` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`radio`](https://w3c.github.io/aria/#radio) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `insertion` [role]

An insertion contains content that is marked as added or content that is
being suggested for addition. See related
[`deletion`](https://w3c.github.io/aria/#deletion).

Insertions are typically used to either mark differences between two
versions of content or to designate content suggested for addition in
scenarios where multiple people are revising content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`ins`](https://html.spec.whatwg.org/multipage/edits.html#the-ins-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `landmark` [abstract role]

A perceivable
[`section`](https://w3c.github.io/aria/#section)
containing content that is relevant to a specific, author-specified
purpose and sufficiently important that users will likely want to be
able to navigate to the section easily and to have it listed in a
summary of the page. Such a page summary could be generated dynamically
by a user agent or assistive technology.

`landmark` is an abstract role used for the ontology. Authors *MUST NOT*
use `landmark` role in content.

Authors designate the purpose of the content by assigning a role that is
a subclass of the landmark role and, when needed, by providing a brief,
descriptive label.

Elements with a role that is a subclass of the landmark role are known
as [landmark](#dfn-landmark) regions or navigational landmark regions.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to landmark regions. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to landmark regions.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`banner`](https://w3c.github.io/aria/#banner) |
| | - [`complementary`](https://w3c.github.io/aria/#complementary) |
| | - [`contentinfo`](https://w3c.github.io/aria/#contentinfo) |
| | - [`form`](https://w3c.github.io/aria/#form) |
| | - [`main`](https://w3c.github.io/aria/#main) |
| | - [`navigation`](https://w3c.github.io/aria/#navigation) |
| | - [`region`](https://w3c.github.io/aria/#region) |
| | - [`search`](https://w3c.github.io/aria/#search) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `link` [role]

An interactive reference to an internal or external resource that, when
activated, causes the user agent to navigate to that resource. See
related [`button`](https://w3c.github.io/aria/#button).

If this is a native link in the host language (such as an [HTML] anchor with an `href` value),
activating the link causes the [user
agent](https://infra.spec.whatwg.org/#user-agent) to
navigate to that resource. If this is a simulated link, the author is
responsible for managing navigation.

If pressing the link triggers an action but does not change browser
focus or page location, authors are advised to consider using the
[`button`](https://w3c.github.io/aria/#button) role
instead of the `link` role.

+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+====================================================================================================================+
| Superclass Role: | [`command`](https://w3c.github.io/aria/#command) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - `<`[`a`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element)`>` |
| | in [HTML] |
| | - `<`[`link`](https://html.spec.whatwg.org/multipage/semantics.html#the-link-element)`>` in |
| | [HTML] |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `list` [role]

A [`section`](https://w3c.github.io/aria/#section)
containing
[`listitem`](https://w3c.github.io/aria/#listitem)
elements. See related
[`listbox`](https://w3c.github.io/aria/#listbox).

Lists contain children whose [role](#dfn-role) is
[`listitem`](https://w3c.github.io/aria/#listitem).

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`directory`](https://w3c.github.io/aria/#directory) |
| | - [`feed`](https://w3c.github.io/aria/#feed) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Base Concept: | - `<`[`ol`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ol-element)`>` |
| | in [HTML] |
| | - `<`[`ul`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-ul-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | [`listitem`](https://w3c.github.io/aria/#listitem) |
| Roles: | |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `listbox` [role]

A [widget](#dfn-widget) that allows the user to select one or more items from a
list of choices. See related
[`combobox`](https://w3c.github.io/aria/#combobox) and
[`list`](https://w3c.github.io/aria/#list).

Items within the list are static and, unlike standard [HTML] `select`
[elements](https://dom.spec.whatwg.org/#concept-element),
can contain images. List boxes contain children whose
[role](#dfn-role) is
[`option`](https://w3c.github.io/aria/#option) or
elements whose [role](#dfn-role) is
[`group`](https://w3c.github.io/aria/#group) which in
turn contain children whose [role](#dfn-role) is
[`option`](https://w3c.github.io/aria/#option).

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
[`option`](https://w3c.github.io/aria/#option)
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

Elements with the role `listbox` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `vertical`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================+
| Superclass Role: | - [`select`](https://w3c.github.io/aria/#select) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - [`list`](https://w3c.github.io/aria/#list) |
| | - `<`[`select`](https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| Roles: | child](#dfn-accessibility-child) |
| | [`option`](https://w3c.github.io/aria/#option) |
| | - [`option`](https://w3c.github.io/aria/#option) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `vertical`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `listitem` [role]

A single item in a list or directory.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
whose [role](#dfn-role) is `listitem` are [accessibility
children](#dfn-accessibility-child) of an
[element](https://dom.spec.whatwg.org/#concept-element)
whose [role](#dfn-role) is
[`list`](https://w3c.github.io/aria/#list).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`li`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-li-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`directory`](https://w3c.github.io/aria/#directory) |
| Roles: | - [`list`](https://w3c.github.io/aria/#list) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `log` [role]

A type of [live region](#dfn-live-region) where new information is added in
meaningful order and old information can disappear. See related
[`marquee`](https://w3c.github.io/aria/#marquee).

Examples include chat logs, messaging history, game log, or an error
log. In contrast to other live regions, in this
[role](#dfn-role)
there is a [relationship](#dfn-relationship) between the arrival of new items in the
log and the reading order. The log contains a meaningful sequence and
new information is added only to the end of the log, not at arbitrary
points.

Elements with the role `log` have an implicit
[`aria-live`](https://w3c.github.io/aria/#aria-live)
value of `polite`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-live`](https://w3c.github.io/aria/#aria-live) is `polite`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `main` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
containing the main content of a document.

This marks the content that is directly related to or expands upon the
central topic of the document. The `main`
[role](#dfn-role) is
a non-obtrusive alternative for \"skip to main content\" links, where
the navigation option to go to the main content (or other
[landmarks](#dfn-landmark)) is provided by [assistive
technologies](#assistive-technology), or by a [user
agent](https://infra.spec.whatwg.org/#user-agent) or
browser extension, through a keyboard shortcut or [UI] feature such as a side panel or dialog.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `main`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `main` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role `main`.

The author *SHOULD* mark no more than one
[element](https://dom.spec.whatwg.org/#concept-element)
on a page with the `main` role.

Because `document` and `application` elements can be nested in the
[DOM], they can have multiple
`main` elements as [DOM]
descendants, assuming each of those is associated with different
document nodes, either by a [DOM]
nesting (e.g.,
[`document`](https://w3c.github.io/aria/#document)
within
[`document`](https://w3c.github.io/aria/#document)) or
by use of the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
attribute.

+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+====================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`main`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-main-element)`>` |
| | in [HTML] |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+--------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `mark` [role]

Content which is marked or highlighted for reference or notation
purposes, due to the content\'s relevance in the enclosing context.

Example uses for `mark` include:

- Highlighting text in a quotation which is of special interest but is
 not marked in the original source material, comparable to using a
 highlighter pen to mark passages of a print article.
- Indicating portions of the content that are relevant to the user\'s
 current activity, such as highlighting text matches found by a search
 feature.

Authors *SHOULD NOT* use `mark` for purely decorative styling such as
syntax highlighting.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`mark`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-mark-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `marquee` [role]

A type of [live region](#dfn-live-region) where non-essential information changes
frequently. See related
[`log`](https://w3c.github.io/aria/#log).

Common usages of `marquee` include stock tickers and ad banners. The
primary difference between a `marquee` and a
[`log`](https://w3c.github.io/aria/#log) is that logs
usually have a meaningful order or sequence of important content
changes.

Elements with the role `marquee` have an implicit
[`aria-live`](https://w3c.github.io/aria/#aria-live)
value of `off`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `math` [role]

Content that represents a mathematical expression.

Content with the role `math` is intended to be marked up in an
accessible format such as [[MathML]](https://www.w3.org/TR/MathML3/)
\[[MathML3](#bib-mathml3 "Mathematical Markup Language (MathML) Version 3.0 2nd Edition")\], or with another type of textual representation
such as TeX or LaTeX, which can be converted to an accessible format by
native browser implementations or a polyfill library.

While it is not ideal to use an image of a mathematical expression,
there exists a significant amount of legacy content where images are
used to represent mathematical expressions. Authors *SHOULD* ensure that
images of math are labeled by text that describes the mathematical
expression as it might be spoken.

Browsers that support native implementations of [MathML] are able to provide a more robust,
accessible math experience than can be accomplished with plain text
approximations of math. Some rendering engines have close integration
with screen readers that allow spacial touch exploration of the formula
and refreshable braille display output in the [Nemeth
Braille](#dfn-nemeth-braille) format. This level of integration is not supported with
images of mathematical formulas, even if the author provides a plain
text approximation.

At the time of this writing, some mainstream browsers do not support
[MathML] natively, and must
be retrofit using a JavaScript polyfill library. When authoring math
content, use native [MathML]
wherever possible, and test thoroughly. Use a polyfill library or
provide a fallback image with a text alternative approximation if
necessary.

::: header-wrapper
#### [MathML] Example with Embedded TeX Annotation

[Example 15](#example-15)

```
<!-- Note: Use a JavaScript polyfill library to ensure
 this renders in user agents that do not support MathML. -->
<!-- The math element has an implicit . -->
<math xmlns="http://www.w3.org/1998/Math/MathML">
 <mrow>
 <mi>x</mi>
 <mo>=</mo>
 <mfrac>
 <mrow>
 <mo form="prefix">−</mo>
 <mi>b</mi>
 <mo>±</mo>
 <msqrt>
 <msup>
 <mi>b</mi>
 <mn>2</mn>
 </msup>
 <mo>−</mo>
 <mn>4</mn>
 <mo>&#x2062;<!-- &InvisibleTimes; --></mo>
 <mi>a</mi>
 <mo>&#x2062;<!-- &InvisibleTimes; --></mo>
 <mi>c</mi>
 </msqrt>
 </mrow>
 <mrow>
 <mn>2</mn>
 <mo>&#x2062;<!-- &InvisibleTimes; --></mo>
 <mi>a</mi>
 </mrow>
 </mfrac>
 </mrow>
 <annotation encoding="TeX">
 x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}
 </annotation>
</math>
```

::: header-wrapper
#### Plain [HTML] or Polyfill [DOM] Result of the [MathML] Quadratic Formula

If a rendering engine does not support a native math format such as
[MathML], authors *MAY* use
JavaScript to downgrade the content to a format the browser can display,
such as this [HTML] image using
a data URI and plain text alternative.

[Example 16](#example-16)

```
<img src="..." a>
```

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `menu` [role]

A type of [widget](#dfn-widget) that offers a list of choices to the user.

A menu is a container, generally rendered as a popup or overlay, for a
set of menu items that can be invoked to perform an action or function.
The function is almost always closely related or directly related to the
element that the user activated to invoke the menu. Activating a menu
item both performs the associated function of the menu item, and results
in the automatic dismissal of the menu.

The `menu` [role](#dfn-role) is appropriate when a set of menu items is presented in
a manner similar to a popup menu. For instance, a menu could be used to
represent a context menu for its invoking element, or it would be used
to render sub-menus for items of a
[`menubar`](https://w3c.github.io/aria/#menubar) or
another `menu` popup.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

Elements with the role `menu` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `vertical`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`select`](https://w3c.github.io/aria/#select) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`menubar`](https://w3c.github.io/aria/#menubar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`list`](https://w3c.github.io/aria/#list) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| Roles: | child](#dfn-accessibility-child) |
| | [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `vertical`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `menubar` [role]

A presentation of
[`menu`](https://w3c.github.io/aria/#menu) that usually
remains visible and is usually presented horizontally.

The `menubar` [role](#dfn-role) is used to create a menu bar similar to those found in
Windows, Mac, and Gnome desktop applications. A menu bar is used to
create a consistent set of frequently used commands. Authors *SHOULD*
ensure that `menubar` interaction is similar to the typical menu bar
interaction in a desktop graphical user interface.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

Elements with the role `menubar` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `horizontal`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`menu`](https://w3c.github.io/aria/#menu) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`toolbar`](https://w3c.github.io/aria/#toolbar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| Roles: | child](#dfn-accessibility-child) |
| | [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `horizontal`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `menuitem` [role]

An option in a set of choices contained by a
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `menuitem` are [accessibility
children](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu),
[`menubar`](https://w3c.github.io/aria/#menubar), or an
element with role
[`group`](https://w3c.github.io/aria/#group) that is an
[accessibility
child](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).

Authors *MAY* disable a menu item with the
[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
attribute. If the menu item has its
[`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
attribute set to `true`, it indicates that the menu item can be used to
launch a sub-level menu, and authors *SHOULD* display a new sub-level
menu when the menu item is activated.

In order to identify that they are related
[widgets](#dfn-widget), authors *MUST* ensure that menu items are
[accessibility
descendants](#dfn-accessibility-descendant) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).
Authors *MAY* separate menu items into sets by use of a
[`separator`](https://w3c.github.io/aria/#separator) or
an element with an equivalent role from the native markup language.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`command`](https://w3c.github.io/aria/#command) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - [`listitem`](https://w3c.github.io/aria/#listitem) |
| | - [`option`](https://w3c.github.io/aria/#option) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`menu`](https://w3c.github.io/aria/#menu) |
| Roles: | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menubar`](https://w3c.github.io/aria/#menubar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `menuitemcheckbox` [role]

A [`menuitem`](https://w3c.github.io/aria/#menuitem)
with a checkable state whose possible values are `true`, `false`, or
`mixed`.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `menuitemcheckbox` are [accessibility
children](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu),
[`menubar`](https://w3c.github.io/aria/#menubar), or an
element with role
[`group`](https://w3c.github.io/aria/#group) that is an
[accessibility
child](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).

The
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
of a `menuitemcheckbox` indicates whether the menu item is checked
(`true`), unchecked (`false`), or represents a sub-level menu of other
menu items that have a mixture of checked and unchecked values
(`mixed`).

In order to identify that they are related
[widgets](#dfn-widget), authors *MUST* ensure that menu item checkboxes are
the [accessibility
descendants](#dfn-accessibility-descendant) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).
Authors *MAY* separate menu items into sets by use of a
[`separator`](https://w3c.github.io/aria/#separator) or
an element with an equivalent role from the native markup language.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`menu`](https://w3c.github.io/aria/#menu) |
| Roles: | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menubar`](https://w3c.github.io/aria/#menubar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) (state) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `menuitemradio` [role]

A checkable
[`menuitem`](https://w3c.github.io/aria/#menuitem) in a
set of elements with the same role, only one of which can be checked at
a time.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `menuitemradio` are [accessibility
children](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu),
[`menubar`](https://w3c.github.io/aria/#menubar), or an
element with role
[`group`](https://w3c.github.io/aria/#group) that is an
[accessibility
child](#dfn-accessibility-child) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).

Authors *SHOULD* enforce that only one `menuitemradio` in a group can be
checked at the same time. When one item in the group is checked, the
previously checked item becomes unchecked (its
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
becomes `false`).

In order to identify that they are related
[widgets](#dfn-widget), authors *MUST* ensure that menu item radios are
[accessibility
descendants](#dfn-accessibility-descendant) of an element with role
[`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar).

If a [`menu`](https://w3c.github.io/aria/#menu) or
[`menubar`](https://w3c.github.io/aria/#menubar)
contains more than one group of `menuitemradio` elements, or if the menu
contains one group and other, unrelated menu items, authors *SHOULD*
contain each set of related `menuitemradio` elements in an element using
the [`group`](https://w3c.github.io/aria/#group) role.
Authors *MAY* also delimit the group from other menu items with an
element using the
[`separator`](https://w3c.github.io/aria/#separator)
role, or an element with an equivalent role from the native markup
language.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`menu`](https://w3c.github.io/aria/#menu) |
| Roles: | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`menubar`](https://w3c.github.io/aria/#menubar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) (state) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `meter` [role]

[element](https://dom.spec.whatwg.org/#concept-element)
that represents a scalar measurement within a known range, or a
fractional value. See related
[`progressbar`](https://w3c.github.io/aria/#progressbar).

Authors *MAY* set
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
to indicate the minimum and maximum values for the `meter`. Otherwise,
their implicit values follow the same rules as
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML]:

- If `aria-valuemin` is missing or not a [number](#valuetype_number), it
 defaults to 0 (zero).
- If `aria-valuemax` is missing or not a [number](#valuetype_number), it
 defaults to 100.

The value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
*MUST NOT* fall below or exceed the computed values of `aria-valuemin`
and `aria-valuemax`, respectively.

Authors *SHOULD NOT* use the `meter` role to indicate progress; the
[`progressbar`](https://w3c.github.io/aria/#progressbar)
role exists to address that need.

Presently, there are no [WAI-ARIA] properties corresponding
to the
[`low`](https://html.spec.whatwg.org/multipage/form-elements.html#attr-meter-low),
[`optimum`](https://html.spec.whatwg.org/multipage/form-elements.html#attr-meter-optimum),
and
[`high`](https://html.spec.whatwg.org/multipage/form-elements.html#attr-meter-high)
attributes supported on the
`<`[`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element)`>`
element in [HTML]. The addition
of these properties will be considered for [ARIA] version 1.3.

+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===================================================================================================================+
| Superclass Role: | [`range`](https://w3c.github.io/aria/#range) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`meter`](https://html.spec.whatwg.org/multipage/form-elements.html#the-meter-element)`>` |
| | in [HTML] |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is `0`.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is `100`. |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `navigation` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
containing a collection of navigational
[elements](https://dom.spec.whatwg.org/#concept-element)
(usually links) for navigating the document or related documents.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `navigation`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `navigation` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role
`navigation`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`nav`](https://html.spec.whatwg.org/multipage/sections.html#the-nav-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `none` [role]

[element](https://dom.spec.whatwg.org/#concept-element)
whose implicit native role semantics will not be mapped to the
[accessibility [API]](#dfn-accessibility-api). See synonym
[`presentation`](https://w3c.github.io/aria/#presentation).

Note regarding the [ARIA] 1.1
[`none`](https://w3c.github.io/aria/#none) role.

In [ARIA] 1.1, the
working group introduced
[`none`](https://w3c.github.io/aria/#none) as a synonym
to the `presentation` role, due to author confusion surrounding the
intended meaning of the word \"presentation\" or \"presentational.\"
Many individuals erroneously consider `` to be
synonymous with `aria-hidden="true"`, and we believe ``
conveys the actual meaning more unambiguously.

The intended use is when an element is used to change the look of the
page but does not have all the functional, interactive, or structural
relevance implied by the element type, or can be used to provide for an
accessible fallback in older browsers that do not support
[WAI-ARIA].

Example use cases:

- An element whose content is completely presentational (like a spacer
 image, decorative graphic, or clearing element);
- An image that is in a container with the
 [`img`](https://w3c.github.io/aria/#img)
 [role](#dfn-role)
 and where the full text alternative is available and is marked up with
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 and (if needed)
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby);
- An element used as an additional markup \"hook\" for [CSS]; or
- A layout table and/or any of its associated rows, cells, etc.

For any element with a role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
and which is not [focusable](#dfn-focusable), the user agent *MUST NOT* expose the
implicit native semantics of the element (the role and its states and
properties) to accessibility [APIs]. However, the user agent
*MUST* expose content and descendant elements that do not have an
explicit or inherited role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation).
Thus, the
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
role causes a given element to be treated as having no role or to be
removed from the [accessibility
tree](#dfn-accessibility-tree), but does not cause the content contained
within the element to be removed from the accessibility tree.

For example, the following two markup snippets will be exposed similarly
to an accessibility [API].

[Example 17](#example-17)

```
<!-- 1. negates the implicit 'heading' role semantics but does not affect the contents, including the nested hyperlink. -->
<h1 > Sample Content <a href="...">let's go!</a> </h1>

<!-- 2. A span has an implicit 'generic' role and no other attributes important to accessibility, so only its content is exposed, including the hyperlink. -->
<span> Sample Content <a href="...">let's go!</a> </span>
```

In [HTML], the `<img>`
[element](https://dom.spec.whatwg.org/#concept-element)
is treated as a single entity regardless of the type of image file.
Consequently, using `` or `` on an
[HTML] `img` is equivalent to
using `aria-hidden="true"`. In order to make the image contents
accessible, authors can embed the object using an `<object>` or
`<iframe>`
[element](https://dom.spec.whatwg.org/#concept-element),
or use inline [SVG] code, and
follow the accessibility guidelines for the image content.

Authors *SHOULD NOT* provide a non-empty text alternative when the
`none`/`presentation` role is applied to an image.

In the following code sample, the containing
[`img`](https://w3c.github.io/aria/#img) and is
appropriately labeled by the caption paragraph. In this example the
`img` element can be marked as
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
because the role and the text alternatives are provided by the
containing element.

[Example 18](#example-18)

```
<div aria-labelledby="caption">
 <img src="example.png" a>
 <p id="caption">A visible text caption labeling the image.</p>
</div>
```

In the following code sample, because the anchor ([HTML] `a` element) is acting as the
treeitem, the list item ([HTML]
`li` element) is assigned an explicit [WAI-ARIA] role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
to override the user agent\'s implicit native semantics for list items.

[Example 19](#example-19)

```
<ul >
 <li >
 <a aria-expanded="true">An expanded tree node</a>
 </li>
 …
</ul>
```

::: header-wrapper
##### Presentational Role Inheritance

[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
role is used on an element that has implicit native semantics, meaning
that there is a default accessibility [API] role for the element. Some
elements are only complete when additional descendant elements are
provided. For example, in [HTML], table elements (matching the
[`table`](https://w3c.github.io/aria/#table) role)
require `tr` descendants (which have an implicit
[`row`](https://w3c.github.io/aria/#row)
[role](#dfn-role)),
which in turn require `th` or `td` children (the
[`columnheader`](https://w3c.github.io/aria/#columnheader)
or [`rowheader`](https://w3c.github.io/aria/#rowheader)
and [`cell`](https://w3c.github.io/aria/#cell) roles,
respectively). Similarly, lists require list item children. The
descendant elements that complete the semantics of an element are
described in [WAI-ARIA] as [Allowed Accessibility
Child Roles](#mustContain).

When an explicit or inherited role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
is applied to an element with the implicit semantic of a
[WAI-ARIA] role
that has [Allowed Accessibility Child Roles](#mustContain), in addition
to the element with the explicit role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation),
the user agent *MUST* apply an inherited role of
[`none`](https://w3c.github.io/aria/#none) to any
[accessibility
descendants](#dfn-accessibility-descendant) that do not have an explicit role defined.
Also, when an explicit or inherited role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
is applied to a host language element which has specifically allowed
children as defined by the host language specification, in addition to
the element with the explicit role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation),
the user agent *MUST* apply an inherited role of
[`none`](https://w3c.github.io/aria/#none) to any
specifically allowed children that do not have an explicit role defined.

For any element with an explicit or inherited role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
and which is not focusable, user agents *MUST* ignore role-specific
[WAI-ARIA] states
and properties for that element. For example, in [HTML], a `ul` or `ol` element with a role
of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
will have the implicit native semantics of its `li` elements removed
because the [`list`](https://w3c.github.io/aria/#list)
role to which the `ul` or `ol` corresponds has an [Allowed Accessibility
Child Role](#mustContain) of
[`listitem`](https://w3c.github.io/aria/#listitem).
Likewise, the implicit native semantics of an [HTML] `table` element\'s
`thead`/`tbody`/`tfoot`/`tr`/`th`/`td` descendants will also be removed,
because the [HTML]
specification indicates that these are required structural descendants
of the `table` element.

Only the implicit native semantics of elements that correspond to
[WAI-ARIA] [Allowed
Accessibility Child Roles](#mustContain) are removed. All other content
remains intact, including nested tables or lists, unless those elements
also have an explicit role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
specified.

For example, according to an accessibility [API], the following markup
elements might have identical or very similar role semantics (generic or
none role) and identical content.

[Example 20](#example-20)

```
<!-- 1. negates the implicit 'list' and 'listitem' role semantics but does not affect the contents. -->
<ul >
 <li> Sample Content </li>
 <li> More Sample Content </li>
</ul>

<!-- 2. There is no implicit role for "foo", so only the contents are exposed. -->
<foo>
 <foo> Sample Content </foo>
 <foo> More Sample Content </foo>
</foo>
```

There are other [WAI-ARIA] roles with specific
allowed children for which this situation is applicable (e.g., feeds and
listboxes), but tables and lists are the most common real-world cases in
which the none/presentation inheritance is likely to apply.

For any element with an explicit or inherited role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation),
user agents *MUST* apply an inherited role of
[`none`](https://w3c.github.io/aria/#none) to all
host-language-specific labeling elements for the presentational element.
For example, a `table` element with a role of
[`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
will have the implicit native semantics of its `caption` element
removed, because the caption is merely a label for the presentational
table.

Editor\'s note

Information about [resolving conflicts in the none/presentation
role](#conflict_resolution_presentation_none) has been moved to
[Handling Author Errors](#document-handling_author-errors)

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `note` [role]

A [`section`](https://w3c.github.io/aria/#section)
whose content represents additional information or parenthetical context
to the primary content it supplements.

A `note` is content provided by the author of the page or document, it
is not to be used for providing reactions or suggestions. For these
purposes, please review
[`comment`](https://w3c.github.io/aria/#comment) and
[`suggestion`](https://w3c.github.io/aria/#suggestion).

When used within the normal flow of a page\'s content, a `note` has an
implicit association with the content that it supplements. The following
example demonstrates using a `note` to call out additional information
in the natural reading order of a page:

[Example 21](#example-21)

```
<p>... the following results outline support for the tested features.</p>
<div >
 <p>Please keep in mind that at the time of publishing this page all results were accurate.</p>
 <p>If you find any variations in results, please let us know!</p>
</div>
<p>...</p>
```

In cases where an element with role
[`note`](https://w3c.github.io/aria/#note) has been
determined to need a programmatic association with the content it
supplements, authors can use one of the following mechanisms to
associate the elements:

- If the `note` contains structured or interactive content (for example,
 a link, button, list, table, etc.) use
 [`aria-details`](https://w3c.github.io/aria/#aria-details).
- If the `note` is brief and consists of static text, use
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

[Example 22](#example-22)

```
 <!-- using aria-details to reference a note containing a link -->
 ...
<button aria-details="info-note">Get Started</button>
...
<div id="info-note">
 <p>Need more information before you get started?</p>
 <p>Visit our <a href="...">product description page</a> to get all the information you need.</p>
</div>
```

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `option` [role]

An item in a
[`listbox`](https://w3c.github.io/aria/#listbox).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `option` are [accessibility
children](#dfn-accessibility-child) of an element with
[role](#dfn-role)
[`listbox`](https://w3c.github.io/aria/#listbox) or of
an element with [role](#dfn-role)
[`group`](https://w3c.github.io/aria/#group) that is
the [accessibility
child](#dfn-accessibility-child) of an element with
[role](#dfn-role)
`listbox`. Options not associated with a
[`listbox`](https://w3c.github.io/aria/#listbox) might
not be correctly mapped to an [accessibility [API]](#dfn-accessibility-api).

In certain conditions, a user agent *MAY* provide an implicit value for
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
for each [`option`](https://w3c.github.io/aria/#option)
in a [`listbox`](https://w3c.github.io/aria/#listbox),
and if it does, the user agent *MUST* ensure the following conditions
are met before providing an implicit value:

- The value of
 [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
 on the
 [`listbox`](https://w3c.github.io/aria/#listbox) is
 `false` or `undefined`.
- None of the
 [`option`](https://w3c.github.io/aria/#option)
 elements in the
 [`listbox`](https://w3c.github.io/aria/#listbox) have
 an explicitly declared value for
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 or
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked).

If a user agent provides an implicit
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
value for an
[`option`](https://w3c.github.io/aria/#option), the
value *SHOULD* be `true` if the
[`option`](https://w3c.github.io/aria/#option) has
[DOM] focus or the
[`listbox`](https://w3c.github.io/aria/#listbox) has
[DOM] focus and the
[`option`](https://w3c.github.io/aria/#option) is
referenced by
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
Otherwise, if a user agent provides an implicit
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
value for an
[`option`](https://w3c.github.io/aria/#option), the
value *SHOULD* be `false`.

Authors *SHOULD* indicate selection for
[`option`](https://w3c.github.io/aria/#option) elements
using one of the following:

- An
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 value of `true` on the selected option within a single-select
 [`listbox`](https://w3c.github.io/aria/#listbox), and
 optionally
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 values of `false` on unselected options.
- Either
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 or
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
 on all options within a multi-select
 [`listbox`](https://w3c.github.io/aria/#listbox),
 with a value of `true` on selected options, and a value of `false` on
 unselected options.

Authors *SHOULD NOT* specify both
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
and
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
on [`option`](https://w3c.github.io/aria/#option)
elements contained by the same
[`listbox`](https://w3c.github.io/aria/#listbox) except
in the extremely rare circumstances where all the following conditions
are met:

- The meaning and purpose of
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 is different from the meaning and purpose of
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
 in the user interface.
- The user interface makes the meaning and purpose of each state
 apparent.
- The user interface provides a separate method for controlling each
 state.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=====================================================================================================================+
| Superclass Role: | [`input`](https://w3c.github.io/aria/#input) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`option`](https://html.spec.whatwg.org/multipage/form-elements.html#the-option-element)`>` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`listitem`](https://w3c.github.io/aria/#listitem) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| Roles: | - [`group`](https://w3c.github.io/aria/#group) with parent |
| | [`listbox`](https://w3c.github.io/aria/#listbox) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `paragraph` [role]

A paragraph of content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`p`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-p-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `presentation` [role]

[element](https://dom.spec.whatwg.org/#concept-element)
whose implicit native role semantics will not be mapped to the
[accessibility [API]](#dfn-accessibility-api). See synonym
[`none`](https://w3c.github.io/aria/#none).

Note regarding the [ARIA] 1.1
[`none`](https://w3c.github.io/aria/#none) role.

In [ARIA] 1.1, the
working group introduced
[`none`](https://w3c.github.io/aria/#none) as the
preferred synonym to the
[`presentation`](https://w3c.github.io/aria/#presentation)
role, due to author confusion surrounding the intended meaning of the
word \"presentation\" or \"presentational.\" Many individuals
erroneously consider `` to be synonymous with
`aria-hidden="true"`, and the [ARIA] Working Group believes
`` conveys the actual meaning more unambiguously.

#### `progressbar` [role]

[element](https://dom.spec.whatwg.org/#concept-element)
that displays the progress status for tasks that take a long time.

A progressbar indicates that the user\'s request has been received and
the application is making progress toward completing the requested
action.

Authors *MAY* set
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
to indicate the minimum and maximum progress indicator values.
Otherwise, their implicit values follow the same rules as
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML]:

- If `aria-valuemin` is missing or not a [number](#valuetype_number), it
 defaults to 0 (zero).
- If `aria-valuemax` is missing or not a [number](#valuetype_number), it
 defaults to 100.

The author *SHOULD* supply a value for
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
unless the value is indeterminate, in which case the author *SHOULD*
omit the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute. Authors *SHOULD* update this value when the visual progress
indicator is updated. If the `progressbar` is describing the loading
progress of a particular region of a page, authors *SHOULD* both use
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
to reference the progressbar status, and set the
[`aria-busy`](https://w3c.github.io/aria/#aria-busy)
attribute to `true` on the region until it is finished loading. It is
not possible for the user to alter the value of a `progressbar` because
it is always read-only.

Assistive technologies generally will render the value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
as a percent of a range between the value of
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax),
unless
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
is specified.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`status`](https://w3c.github.io/aria/#status) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
| | - [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is |
| | `0`.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is |
| | `100`.\ |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `radio` [role]

A checkable input in a group of elements with the same role, only one of
which can be checked at a time.

Authors *SHOULD* ensure that
[elements](https://dom.spec.whatwg.org/#concept-element)
with role `radio` are explicitly grouped in order to indicate which ones
affect the same value. This is achieved by enclosing the radio elements
in an element with role
[`radiogroup`](https://w3c.github.io/aria/#radiogroup).
If it is not possible to make the radio buttons [DOM] children of the
[`radiogroup`](https://w3c.github.io/aria/#radiogroup),
authors *SHOULD* use the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
on the
[`radiogroup`](https://w3c.github.io/aria/#radiogroup)
element to indicate the
[relationship](#dfn-relationship) to its children.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================================+
| Superclass Role: | - [`input`](https://w3c.github.io/aria/#input) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<input type="`[`radio`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-radio-keyword)`">` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `radiogroup` [role]

A group of [`radio`](https://w3c.github.io/aria/#radio)
buttons.

A `radiogroup` is a type of
[`select`](https://w3c.github.io/aria/#select) list
that can only have a single entry checked at any one time. Authors
*SHOULD* enforce that only one radio button in a group can be checked at
the same time. When one item in the group is checked, the previously
checked item becomes unchecked (its
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
becomes `false`).

Authors *SHOULD* provide an accessible name for a `radiogroup`, which
can be done with the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute. Authors *SHOULD* reference a visible label with
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
if a visible label is present for the `radiogroup`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`select`](https://w3c.github.io/aria/#select) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`list`](https://w3c.github.io/aria/#list) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `range` [abstract role]

An element representing a range of values.

`range` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `range` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
| | - [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `region` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
containing content that is relevant to a specific, author-specified
purpose and sufficiently important that users will likely want to be
able to navigate to the section easily and to have it listed in a
summary of the page. Such a page summary could be generated dynamically
by a user agent or assistive technology.

Authors *SHOULD* limit use of the region role to sections containing
content with a purpose that is not accurately described by one of the
other [landmark roles](#landmark_roles), such as
[`main`](https://w3c.github.io/aria/#main),
[`complementary`](https://w3c.github.io/aria/#complementary),
or
[`navigation`](https://w3c.github.io/aria/#navigation).

Authors *MUST* give each element with role region a brief label that
describes the purpose of the content in the region. Authors *SHOULD*
reference a visible label with
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
if a visible label is present. Authors *SHOULD* include the label inside
of a heading whenever possible. The heading *MAY* be an instance of the
standard host language heading element or an instance of an element with
role [`heading`](https://w3c.github.io/aria/#heading).

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `region`. [User
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `region` and an accessible name as
navigational [landmarks](#dfn-landmark). [User
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role `region`.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`section`](https://html.spec.whatwg.org/multipage/sections.html#the-section-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `roletype` [abstract role]

The base [role](#dfn-role) from which all other roles inherit.

Properties of this role describe the structural and functional purpose
of [objects](#dfn-object) that are assigned this role. A role is a concept that
can be used to understand and operate instances.

`roletype` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `roletype` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`structure`](https://w3c.github.io/aria/#structure) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
| | - [`window`](https://w3c.github.io/aria/#window) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) (Except where |
| | prohibited) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | (Except where prohibited) |
| | - [`aria-busy (state)`](https://w3c.github.io/aria/#aria-busy) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current (state)`](https://w3c.github.io/aria/#aria-current) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled (state)`](https://w3c.github.io/aria/#aria-disabled) (Global use deprecated |
| | in ARIA 1.2) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) (Global use |
| | deprecated in ARIA 1.2) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed (state)`](https://w3c.github.io/aria/#aria-grabbed) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) (Global use deprecated in |
| | ARIA 1.2) |
| | - [`aria-hidden (state)`](https://w3c.github.io/aria/#aria-hidden) |
| | - [`aria-invalid (state)`](https://w3c.github.io/aria/#aria-invalid) (Global use deprecated |
| | in ARIA 1.2) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) (Except where prohibited) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) (Except where |
| | prohibited) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) (Except where |
| | prohibited) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `row` [role]

A row of cells in a tabular container.

Rows contain [`cell`](https://w3c.github.io/aria/#cell)
or [`gridcell`](https://w3c.github.io/aria/#gridcell)
[elements](https://dom.spec.whatwg.org/#concept-element),
and thus serve to organize a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

While the row role can be used in a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid), the
semantics of
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
and
[`aria-level`](https://w3c.github.io/aria/#aria-level)
are only applicable to the hierarchical structure of an interactive tree
grid. Therefore, authors *MUST NOT* apply
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded),
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
and
[`aria-level`](https://w3c.github.io/aria/#aria-level)
to a [`row`](https://w3c.github.io/aria/#row) that
descends from a
[`table`](https://w3c.github.io/aria/#table) or
[`grid`](https://w3c.github.io/aria/#grid), and user
agents *SHOULD NOT* expose any of these four properties to assistive
technologies unless the
[`row`](https://w3c.github.io/aria/#row) descends from
a [`treegrid`](https://w3c.github.io/aria/#treegrid).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `row` are [accessibility
children](#dfn-accessibility-child) of an element with the role
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid),
[`rowgroup`](https://w3c.github.io/aria/#rowgroup), or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

Note[: Usage of aria-disabled]

[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
is currently supported on
[`row`](https://w3c.github.io/aria/#row), in a future
version the working group plans to prohibit its on elements with role
[`row`](https://w3c.github.io/aria/#row) except when
the element is in the context of a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`group`](https://w3c.github.io/aria/#group) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`tr`](https://html.spec.whatwg.org/multipage/tables.html#the-tr-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`grid`](https://w3c.github.io/aria/#grid) |
| Roles: | - [`table`](https://w3c.github.io/aria/#table) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
| | - [`rowgroup`](https://w3c.github.io/aria/#rowgroup) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`cell`](https://w3c.github.io/aria/#cell) |
| Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-level`](https://w3c.github.io/aria/#aria-level) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) |
| | - [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `rowgroup` [role]

A structure containing one or more row elements in a tabular container.

The `rowgroup` role establishes a
[relationship](#dfn-relationship) with its [accessibility
children](#dfn-accessibility-child) of role
[`row`](https://w3c.github.io/aria/#row). It is a
structural equivalent to the `thead`, `tfoot`, and `tbody` elements in
an [HTML] `table`
[element](https://dom.spec.whatwg.org/#concept-element).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `rowgroup` are [accessibility
children](#dfn-accessibility-child) of an element with the role
[`grid`](https://w3c.github.io/aria/#grid),
[`table`](https://w3c.github.io/aria/#table), or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

The `rowgroup` role exists, in part, to support role symmetry in
[HTML], and allows for the
propagation of presentation inheritance on [HTML] `table` elements with an explicit
`presentation` role applied.

This role does not differentiate between types of row groups (e.g.,
`thead` vs. `tbody`), but an issue has been raised for [WAI-ARIA] 2.0.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`tbody`](https://html.spec.whatwg.org/multipage/tables.html#the-tbody-element)`>`, |
| | `<`[`tfoot`](https://html.spec.whatwg.org/multipage/tables.html#the-tfoot-element)`>` and |
| | `<`[`thead`](https://html.spec.whatwg.org/multipage/tables.html#the-thead-element)`>`in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`grid`](https://w3c.github.io/aria/#grid) |
| Roles: | - [`table`](https://w3c.github.io/aria/#table) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | [`row`](https://w3c.github.io/aria/#row) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `rowheader` [role]

A cell containing header information for a row.

The
[`rowheader`](https://w3c.github.io/aria/#rowheader)
role can be used to identify a cell as a header for a row in a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). The
rowheader establishes a
[relationship](#dfn-relationship) between it and all cells in the
corresponding row. It is a structural equivalent to setting
`scope="row"` on an [HTML] `th`
[element](https://dom.spec.whatwg.org/#concept-element).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `rowheader` are [accessibility
children](#dfn-accessibility-child) of an element with the role
[`row`](https://w3c.github.io/aria/#row).

Applying the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
state on a rowheader *MUST NOT* cause the user agent to automatically
propagate the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
state to all the cells in the corresponding row. An author *MAY* choose
to propagate selection in this manner depending on the specific
application.

While the `rowheader` role can be used in both interactive grids and
non-interactive tables, the use of
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded),
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly),
and
[`aria-required`](https://w3c.github.io/aria/#aria-required)
is only applicable to interactive elements. Therefore, authors *SHOULD
NOT* use
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded),
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly),
or
[`aria-required`](https://w3c.github.io/aria/#aria-required)
in a `rowheader` that descends from a
[`table`](https://w3c.github.io/aria/#table), and user
agents *SHOULD NOT* expose these properties to [assistive
technologies](#assistive-technology) unless the `rowheader` descends from a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

Note[: Usage of aria-disabled]

[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
is currently supported on
[`rowheader`](https://w3c.github.io/aria/#rowheader),
in a future version the working group plans to prohibit its use on
elements with role
[`rowheader`](https://w3c.github.io/aria/#rowheader)
except when the element is in the context of a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`sectionhead`](https://w3c.github.io/aria/#sectionhead) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<th scope="`[`row`](https://html.spec.whatwg.org/multipage/tables.html#attr-th-scope-row)`">` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | [`row`](https://w3c.github.io/aria/#row) |
| Roles: | |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-sort`](https://w3c.github.io/aria/#aria-sort) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) |
| | - [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext) |
| | - [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) |
| | - [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) |
| | - [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) (state) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `scrollbar` [role]

A graphical object that controls the scrolling of content within a
viewing area, regardless of whether the content is fully displayed
within the viewing area.

A scrollbar represents the current value and range of possible values
via the size of the scrollbar and position of the thumb with respect to
the visible range of the orientation (horizontal or vertical) it
controls. Its orientation represents the orientation of the scrollbar
and the scrolling effect on the viewing area controlled by the
scrollbar. It is typically possible to add to or subtract from the
current value by using directional keys such as arrow keys.

Authors *MAY* set the
[`aria-controls`](https://w3c.github.io/aria/#aria-controls)
attribute on the scrollbar element to reference the scrollable area it
controls.

Authors *MAY* set
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
to indicate the minimum and maximum thumb position. Otherwise, their
implicit values follow the same rules as
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML]:

- If `aria-valuemin` is missing or not a [number](#valuetype_number), it
 defaults to 0 (zero).
- If `aria-valuemax` is missing or not a [number](#valuetype_number), it
 defaults to 100.

Authors *MUST* set the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute to indicate the current thumb position. If aria-valuenow is
missing or has an unexpected value, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* implement the repair techniques specified in the [section
describing handling author errors in states and
properties](#authorErrorDefaultValuesTable), which are equivalent to the
repair techniques for
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML].

Elements with the role `scrollbar` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `vertical`.

Assistive technologies generally will render the value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
as a percent of a range between the value of
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax),
unless
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
is specified. It is best to set the values for
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin),
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax),
and
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
in a manner that is appropriate for this calculation.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `vertical`.\ |
| | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is |
| | `0`.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is |
| | `100`.\ |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `search` [role]

A [`landmark`](https://w3c.github.io/aria/#landmark)
region that contains a collection of items and objects that, as a whole,
combine to create a search facility. See related
[`form`](https://w3c.github.io/aria/#form) and
[`searchbox`](https://w3c.github.io/aria/#searchbox).

A search region can be a mix of host language form controls, scripted
controls, and hyperlinks.

[Assistive
technologies](#assistive-technology) *SHOULD* enable users to quickly navigate
to elements with role `search`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* treat elements with role `search` as navigational
[landmarks](#dfn-landmark). [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MAY* enable users to quickly navigate to elements with role `search`.

+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+==================================================================================================================+
| Superclass Role: | [`landmark`](https://w3c.github.io/aria/#landmark) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Base Concept: | [HTML] |
| | [`search`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-search-element) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `searchbox` [role]

A type of textbox intended for specifying search criteria. See related
[`textbox`](https://w3c.github.io/aria/#textbox) and
[`search`](https://w3c.github.io/aria/#search).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=========================================================================================================================================+
| Superclass Role: | [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<input type="`[`search`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-search-keyword)`">` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `section` [abstract role]

A renderable structural containment unit on a page.

`section` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `section` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`alert`](https://w3c.github.io/aria/#alert) |
| | - [`blockquote`](https://w3c.github.io/aria/#blockquote) |
| | - [`caption`](https://w3c.github.io/aria/#caption) |
| | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`code`](https://w3c.github.io/aria/#code) |
| | - [`definition`](https://w3c.github.io/aria/#definition) |
| | - [`deletion`](https://w3c.github.io/aria/#deletion) |
| | - [`emphasis`](https://w3c.github.io/aria/#emphasis) |
| | - [`figure`](https://w3c.github.io/aria/#figure) |
| | - [`group`](https://w3c.github.io/aria/#group) |
| | - [`image`](https://w3c.github.io/aria/#image) |
| | - [`insertion`](https://w3c.github.io/aria/#insertion) |
| | - [`landmark`](https://w3c.github.io/aria/#landmark) |
| | - [`list`](https://w3c.github.io/aria/#list) |
| | - [`listitem`](https://w3c.github.io/aria/#listitem) |
| | - [`log`](https://w3c.github.io/aria/#log) |
| | - [`mark`](https://w3c.github.io/aria/#mark) |
| | - [`marquee`](https://w3c.github.io/aria/#marquee) |
| | - [`math`](https://w3c.github.io/aria/#math) |
| | - [`note`](https://w3c.github.io/aria/#note) |
| | - [`paragraph`](https://w3c.github.io/aria/#paragraph) |
| | - [`sectionfooter`](https://w3c.github.io/aria/#sectionfooter) |
| | - [`sectionheader`](https://w3c.github.io/aria/#sectionheader) |
| | - [`status`](https://w3c.github.io/aria/#status) |
| | - [`strong`](https://w3c.github.io/aria/#strong) |
| | - [`subscript`](https://w3c.github.io/aria/#subscript) |
| | - [`suggestion`](https://w3c.github.io/aria/#suggestion) |
| | - [`superscript`](https://w3c.github.io/aria/#superscript) |
| | - [`table`](https://w3c.github.io/aria/#table) |
| | - [`tabpanel`](https://w3c.github.io/aria/#tabpanel) |
| | - [`term`](https://w3c.github.io/aria/#term) |
| | - [`time`](https://w3c.github.io/aria/#time) |
| | - [`tooltip`](https://w3c.github.io/aria/#tooltip) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `sectionfooter` [role]

A set of user interface objects and information representing information
about its closest ancestral content group. For instance, a
`sectionfooter` can include information about who wrote the specific
section of content, such as an
[`article`](https://w3c.github.io/aria/#article). It
can contain links to related documents, copyright information or other
indices and colophon specific to the current section of the page.

A `sectionfooter` does not represent information about the parent
document, or globally repeating content found across multiple pages
related to the website. For such content, the
[`contentinfo`](https://w3c.github.io/aria/#contentinfo)
role would be more appropriate.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`footer`](https://html.spec.whatwg.org/multipage/sections.html#the-footer-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `sectionhead` [abstract role]

A structure that labels or summarizes the topic of its related section.

`sectionhead` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `sectionhead` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`structure`](https://w3c.github.io/aria/#structure) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`heading`](https://w3c.github.io/aria/#heading) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `sectionheader` [role]

A set of user interface objects and information that represents a
collection of introductory items for the element\'s closest ancestral
content group. For instance, a `sectionheader` can include the heading,
introductory statement and related meta data for a section of content,
for instance a
[`region`](https://w3c.github.io/aria/#region) or
[`article`](https://w3c.github.io/aria/#article),
within a web page.

A `sectionheader` does not represent site-oriented or globally repeating
content found across multiple pages of a website. For such content, the
[`banner`](https://w3c.github.io/aria/#banner) role
would be more appropriate.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`header`](https://html.spec.whatwg.org/multipage/sections.html#the-header-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `select` [abstract role]

A form widget that allows the user to make selections from a set of
choices.

`select` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `select` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`group`](https://w3c.github.io/aria/#group) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `separator` [role]

A divider that separates and distinguishes sections of content or groups
of menuitems.

There are two types of separators: a static
[`structure`](https://w3c.github.io/aria/#structure)
that provides only a visible boundary and a
[focusable](#dfn-focusable), interactive
[`widget`](https://w3c.github.io/aria/#widget) that is
also moveable. If a `separator` is not focusable, it is revealed to
[assistive
technologies](#assistive-technology) as a static structural element. For
example, a static `separator` can be used to help visually divide two
groups of menu items in a menu or to provide a horizontal rule between
two sections of a page.

Authors *MAY* make a `separator` focusable to create a
[`widget`](https://w3c.github.io/aria/#widget) that
both provides a visible boundary between two sections of content and
enables the user to change the relative size of the sections by changing
the position of the `separator`. A variable `separator` widget can be
moved continuously within a range, whereas a fixed `separator` widget
supports only two discrete positions. Typically, a fixed `separator`
widget is used to toggle one of the sections between expanded and
collapsed states.

If the `separator` is focusable, authors *MUST* set the value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
to a [number](#valuetype_number) reflecting the current position of the
`separator` and update that value when it changes. Authors *SHOULD* also
provide the value of
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
if it is not `0` and the value of
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
if it is not `100`. If missing or not a number, the implicit values of
these attributes are as follows:

- The implicit value of `aria-valuemin` is `0`.
- The implicit value of `aria-valuemax` is `100`.

In applications where there is more than one focusable `separator`,
authors *SHOULD* provide an accessible name for each one.

Elements with the role `separator` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `horizontal`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`structure`](https://w3c.github.io/aria/#structure) (if not focusable) |
| | - [`widget`](https://w3c.github.io/aria/#widget) (if focusable) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`hr`](https://html.spec.whatwg.org/multipage/grouping-content.html#the-hr-element)`>` |
| | in [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) (if focusable) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (if focusable) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) (if focusable) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) (if focusable) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) (if focusable) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `horizontal`.\ |
| | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is `0`.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is `100`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `slider` [role]

An input where the user selects a value from within a given range.

A slider represents the current value and range of possible values via
the size of the slider and position of the thumb. It is typically
possible to add to or subtract from the current value by using
directional keys such as arrow keys.

Authors *MAY* set the
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
and
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
attributes. Otherwise, their implicit values follow the same rules as
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML]:

- If `aria-valuemin` is missing or not a [number](#valuetype_number), it
 defaults to 0 (zero).
- If `aria-valuemax` is missing or not a [number](#valuetype_number), it
 defaults to 100.

Authors *MUST* set the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute. If aria-valuenow is missing or has an unexpected value,
browsers *MAY* implement the repair techniques specified in the [section
describing handling author errors in states and
properties](#authorErrorDefaultValuesTable), which are equivalent to the
repair techniques for
`<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">`
in [HTML].

Elements with the role `slider` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `horizontal`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`input`](https://w3c.github.io/aria/#input) |
| | - [`range`](https://w3c.github.io/aria/#range) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `horizontal`.\ |
| | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is |
| | `0`.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is |
| | `100`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `spinbutton` [role]

A form of [`range`](https://w3c.github.io/aria/#range)
that expects the user to select from among discrete choices.

A `spinbutton` typically allows users to change its displayed value by
activating increment and decrement buttons that step through a set of
allowed values. Some implementations display the value in an text field
that allows editing and typing but typically limits input in ways that
help prevent invalid values.

Although a `spinbutton` is similar in appearance to many presentations
of `select`, it is advisable to use `spinbutton` when working with known
ranges (especially in the case of large ranges) as opposed to distinct
options. For example, a `spinbutton` representing a range from 1 to
1,000,000 would provide much better performance than a `select`
[widget](#dfn-widget) representing the same values.

Authors *MAY* create a `spinbutton` with [accessibility
children](#dfn-accessibility-child), but *MUST* limit those elements to a
[`textbox`](https://w3c.github.io/aria/#textbox) and/or
two [`buttons`](https://w3c.github.io/aria/#button).
Alternatively, authors *MAY* apply the
[`spinbutton`](https://w3c.github.io/aria/#spinbutton)
role to a text input and create sibling buttons to support the increment
and decrement functions.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus). When a `spinbutton`
receives focus, authors *SHOULD* ensure focus is placed on the
[`textbox`](https://w3c.github.io/aria/#textbox)
element if one is present, and on the `spinbutton` itself otherwise.
Authors *SHOULD* also ensure the [up] and [down] arrows on a
keyboard perform the increment and decrement functions and that the
increment and decrement
[`button`](https://w3c.github.io/aria/#button) elements
are *NOT* included in the primary navigation ring, e.g., the Tab ring in
[HTML].

Authors *SHOULD* set the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute when the
[`spinbutton`](https://w3c.github.io/aria/#spinbutton)
has a value. Authors *SHOULD* set the
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
attribute when there is a minimum value, and the
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
attribute when there is a maximum value.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`input`](https://w3c.github.io/aria/#input) |
| | - [`range`](https://w3c.github.io/aria/#range) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) |
| | - [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) |
| | - [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) |
| | - [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) is that there is |
| | no minimum value.\ |
| | Default for [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) is that there is |
| | no maximum value.\ |
| | Default for [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) is that there is |
| | no current value.\ |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `status` [role]

A type of [live region](#dfn-live-region) whose content is advisory information for
the user but is not important enough to justify an
[`alert`](https://w3c.github.io/aria/#alert), often but
not necessarily presented as a status bar.

Authors *SHOULD* ensure an element with role `status` does not receive
focus as a result of change in status.

Status is a form of [live
region](#dfn-live-region). If another part of the page controls what appears in
the status, authors *SHOULD* make the
[relationship](#dfn-relationship) explicit with the
[`aria-controls`](https://w3c.github.io/aria/#aria-controls)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).

[Assistive
technologies](#assistive-technology) *MAY* reserve some cells of a Braille
display to render the status.

Elements with the role `status` have an implicit
[`aria-live`](https://w3c.github.io/aria/#aria-live)
value of `polite` and an implicit
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
value of `true`.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=====================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`timer`](https://w3c.github.io/aria/#timer) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`output`](https://html.spec.whatwg.org/multipage/form-elements.html#the-output-element)`>` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-live`](https://w3c.github.io/aria/#aria-live) is `polite`.\ |
| | Default for [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) is `true`. |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `strong` [role]

Content that is important, serious, or urgent. See related
[`emphasis`](https://w3c.github.io/aria/#emphasis).

The purpose of the `strong` role is to communicate strong importance,
seriousness, or urgency. It is not for communicating changes in
typographical presentation that are not important to the meaning of the
content. Authors *SHOULD* use the `strong` role only if its absence
would change the meaning of the content.

The `strong` role is not intended to convey stress or emphasis; for that
purpose, the
[`emphasis`](https://w3c.github.io/aria/#emphasis) role
is more appropriate.

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+============================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`strong`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-strong-element)`>` |
| | in [HTML] |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `structure` [abstract role]

A document structural
[element](https://dom.spec.whatwg.org/#concept-element).

[Roles](#dfn-role)
for document structure support the accessibility of dynamic web content
by helping [assistive
technologies](#assistive-technology) determine active content versus static
document content. Structural roles by themselves do not all map to
[accessibility [APIs]](#dfn-accessibility-api), but are used to create
[widget](#dfn-widget) roles or assist content adaptation for assistive
technologies.

`structure` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `structure` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`roletype`](https://w3c.github.io/aria/#roletype) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`document`](https://w3c.github.io/aria/#document) |
| | - [`generic`](https://w3c.github.io/aria/#generic) |
| | - [`none`](https://w3c.github.io/aria/#none) |
| | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`rowgroup`](https://w3c.github.io/aria/#rowgroup) |
| | - [`section`](https://w3c.github.io/aria/#section) |
| | - [`sectionhead`](https://w3c.github.io/aria/#sectionhead) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `subscript` [role]

One or more subscripted characters. See related
[`superscript`](https://w3c.github.io/aria/#superscript).

The `subscript` role is intended to be used only to mark up
typographical conventions that have specific meanings; not for
typographical presentation for presentation\'s sake. In general, authors
*SHOULD* use this role only if the absence of the subscript would change
the meaning of the content.

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+======================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`sub`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-sub-element)`>` |
| | and |
| | `<`[`sup`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-sup-element)`>` |
| | in [HTML] |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `suggestion` [role]

A single proposed change to content.

For example, in an editing system that supports multiple users, one user
can suggest a change, and another user would be responsible for
accepting or rejecting the suggestion.

Authors *MUST* ensure that a `suggestion` contains either one
[`insertion`](https://w3c.github.io/aria/#insertion)
child or one
[`deletion`](https://w3c.github.io/aria/#deletion)
child or ensure that it contains two children where one is an
[`insertion`](https://w3c.github.io/aria/#insertion)
and the other is a
[`deletion`](https://w3c.github.io/aria/#deletion).
Authors *MUST* ensure a `suggestion` does not contain any other
children.

Authors *MAY* use
[`aria-details`](https://w3c.github.io/aria/#aria-details)
or
[`aria-description`](https://w3c.github.io/aria/#aria-description)
to associate the `suggestion` with related information such as comments,
authoring info, and time stamps.

[Example 23](#example-23)

```
<p>
 The best pet is a
 <span >
 <span >cat</span>
 <span >dog</span>
 </span>
</p>
```

When a suggestion is accepted, authors *SHOULD* remove the `suggestion`
role, indicating that the proposed revision has been made. After the
`suggestion` role is removed, child
[`insertion`](https://w3c.github.io/aria/#insertion)
and [`deletion`](https://w3c.github.io/aria/#deletion)
elements can either be retained to document the revision or replaced
with the revised content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`insertion`](https://w3c.github.io/aria/#insertion) |
| Roles: | - [`deletion`](https://w3c.github.io/aria/#deletion) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `superscript` [role]

One or more superscripted characters. See related
[`subscript`](https://w3c.github.io/aria/#subscript).

The `superscript` role is intended to be used only to mark up
typographical conventions that have specific meanings; not for
typographical presentation for presentation\'s sake. In general, authors
*SHOULD* use this role only if the absence of the superscript would
change the meaning of the content.

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+======================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`sub`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-sub-element)`>` |
| | and |
| | `<`[`sup`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-sup-element)`>` |
| | in [HTML] |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `switch` [role]

A type of checkbox that represents on/off values, as opposed to
checked/unchecked values. See related
[`checkbox`](https://w3c.github.io/aria/#checkbox).

The
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
of a `switch` indicates whether the input is on (`true`) or off
(`false`). The `mixed` value is invalid, and user agents *MUST* treat a
`mixed` value as equivalent to `false` for this role.

A `switch` provides approximately the same functionality as a `checkbox`
and toggle `button`, but makes it possible for assistive technologies to
present the widget in a fashion consistent with its on-screen
appearance.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`checkbox`](https://w3c.github.io/aria/#checkbox) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`button`](https://w3c.github.io/aria/#button) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required States and Properties: | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) (state) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `tab` [role]

A grouping label providing a mechanism for selecting the tab content
that is to be rendered to the user.

If a [`tabpanel`](https://w3c.github.io/aria/#tabpanel)
or item in a
[`tabpanel`](https://w3c.github.io/aria/#tabpanel) has
focus, the associated `tab` is the currently active tab in the
[`tablist`](https://w3c.github.io/aria/#tablist), as
defined in [Managing Focus](#managingfocus).
[`tablist`](https://w3c.github.io/aria/#tablist)
elements, which contain a set of associated
[`tab`](https://w3c.github.io/aria/#tab) elements, are
typically placed near a series of
[`tabpanel`](https://w3c.github.io/aria/#tabpanel)
elements, usually preceding it. See the [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/) for details on implementing a
tab set design pattern.

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role)
[`tab`](https://w3c.github.io/aria/#tab) are
[accessibility
children](#dfn-accessibility-child) of an element with the role
[`tablist`](https://w3c.github.io/aria/#tablist).

Authors *MUST* ensure that if a `tab` is active, a corresponding
`tabpanel` that represents the active `tab` is rendered.

Authors *SHOULD* ensure the
[`tabpanel`](https://w3c.github.io/aria/#tabpanel)
associated with the currently active tab is
[perceivable](#dfn-perceivable) to the user.

For a single-selectable
[`tablist`](https://w3c.github.io/aria/#tablist),
authors *SHOULD* [hide from all
users](#dfn-hide-from-all-users) other `tabpanel`
[elements](https://dom.spec.whatwg.org/#concept-element)
until the user selects the tab associated with that tabpanel. For a
multi-selectable
[`tablist`](https://w3c.github.io/aria/#tablist),
authors *SHOULD* ensure that the
[`tab`](https://w3c.github.io/aria/#tab) for each
visible
[`tabpanel`](https://w3c.github.io/aria/#tabpanel) has
the
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
set to `true`, and that the `tabs` associated with the remaining [hidden
from all
users](#dfn-hide-from-all-users) `tabpanel` elements have their
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
attributes set to `false`.

Authors *SHOULD* ensure that a selected tab has its
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
attribute set to `true`, that inactive tab elements have their
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
attribute set to `false`, and that the currently selected tab provides a
visual indication that it is selected.

In certain conditions, a user agent *MAY* provide an implicit value for
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
for each [`tab`](https://w3c.github.io/aria/#tab) in a
[`tablist`](https://w3c.github.io/aria/#tablist), and
if it does, the user agent *MUST* ensure the following conditions are
met before providing an implicit value:

- The value of
 [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
 on the
 [`tablist`](https://w3c.github.io/aria/#tablist) is
 `false` or `undefined`.
- None of the [`tab`](https://w3c.github.io/aria/#tab)
 elements in the
 [`tablist`](https://w3c.github.io/aria/#tablist) have
 an explicitly declared value for
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 or
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`sectionhead`](https://w3c.github.io/aria/#sectionhead) |
| | - [`widget`](https://w3c.github.io/aria/#widget) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | [`tablist`](https://w3c.github.io/aria/#tablist) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) |
| | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Children Presentational: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-selected`](https://w3c.github.io/aria/#aria-selected) is |
| | `false`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `table` [role]

A [`section`](https://w3c.github.io/aria/#section)
containing data arranged in rows and columns. See related
[`grid`](https://w3c.github.io/aria/#grid).

The `table` role is intended for tabular containers which are not
interactive. If the tabular container maintains a selection state,
provides its own two-dimensional navigation, or allows the user to
rearrange or otherwise manipulate its contents or the display thereof,
authors *SHOULD* use
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid)
instead.

Authors *SHOULD* provide an accessible name for a `table`, which can be
done with the
[`aria-label`](https://w3c.github.io/aria/#aria-label)
or
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute. Authors *SHOULD* reference a visible label with
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
if a visible label is present for the `table`.

Authors *SHOULD* prefer the use of the host language\'s semantics for
table whenever possible, such as the
`<`[`table`](https://html.spec.whatwg.org/multipage/tables.html#the-table-element)`>`
element in [HTML].

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Base Concept: | `<`[`table`](https://html.spec.whatwg.org/multipage/tables.html#the-table-element)`>` in |
| | [HTML] |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`caption`](https://w3c.github.io/aria/#caption) |
| Roles: | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`rowgroup`](https://w3c.github.io/aria/#rowgroup) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount) |
| | - [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `tablist` [role]

A list of [`tab`](https://w3c.github.io/aria/#tab)
[elements](https://dom.spec.whatwg.org/#concept-element),
which are references to
[`tabpanel`](https://w3c.github.io/aria/#tabpanel)
elements.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

For a single-selectable
[`tablist`](https://w3c.github.io/aria/#tablist),
authors *SHOULD* [hide from all
users](#dfn-hide-from-all-users) other `tabpanel`
[elements](https://dom.spec.whatwg.org/#concept-element)
until the user selects the tab associated with that tabpanel. For a
multi-selectable
[`tablist`](https://w3c.github.io/aria/#tablist),
authors *SHOULD* ensure that the
[`tab`](https://w3c.github.io/aria/#tab) for each
visible
[`tabpanel`](https://w3c.github.io/aria/#tabpanel) has
the
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
set to `true`, and that the `tabs` associated with the remaining [hidden
from all
users](#dfn-hide-from-all-users) `tabpanel` elements have their
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
attributes set to `false`.

[`tablist`](https://w3c.github.io/aria/#tablist)
elements are typically placed near, and usually preceding, a series of
[`tabpanel`](https://w3c.github.io/aria/#tabpanel)
elements. See the [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/) for details on implementing a
tab set design pattern.

Elements with the role
[`tablist`](https://w3c.github.io/aria/#tablist) have
an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `horizontal`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`composite`](https://w3c.github.io/aria/#composite) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | [`tab`](https://w3c.github.io/aria/#tab) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `horizontal`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `tabpanel` [role]

A container for the resources associated with a
[`tab`](https://w3c.github.io/aria/#tab), where each
[`tab`](https://w3c.github.io/aria/#tab) is contained
in a [`tablist`](https://w3c.github.io/aria/#tablist).

Authors *SHOULD* associate a `tabpanel`
[element](https://dom.spec.whatwg.org/#concept-element)
with its [`tab`](https://w3c.github.io/aria/#tab), by
using the
[`aria-controls`](https://w3c.github.io/aria/#aria-controls)
attribute on the tab to reference the tab panel, and/or by using the
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute on the tab panel to reference the tab.

[`tablist`](https://w3c.github.io/aria/#tablist)
elements are typically placed near, and usually preceding, a series of
[`tabpanel`](https://w3c.github.io/aria/#tabpanel)
elements. See the [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/) for details on implementing a
tab set design pattern.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `term` [role]

A word or phrase with an optional corresponding definition. See related
[`definition`](https://w3c.github.io/aria/#definition).

The `term` role is used to explicitly identify a word or phrase for
which a
[`definition`](https://w3c.github.io/aria/#definition)
has been provided by the author or is expected to be provided by the
user. If there is an existing
[`definition`](https://w3c.github.io/aria/#definition),
or a form or form control to enter a definition, authors *SHOULD* set
[`aria-details`](https://w3c.github.io/aria/#aria-details)
to point to the related element.

Authors *SHOULD NOT* use the `term` role on interactive elements such as
links because doing so could prevent users of [assistive
technologies](#assistive-technology) from interacting with those elements.

+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+======================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`dfn`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-dfn-element)`>` |
| | in [HTML] |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+----------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `textbox` [role]

A type of input that allows free-form text as its value.

If the
[`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is `true`, the [widget](#dfn-widget) accepts line breaks within the input, as in an
[HTML] `textarea`. Otherwise,
this is a simple text box. The intended use is for languages that do not
have a text input
[element](https://dom.spec.whatwg.org/#concept-element),
or cases in which an element with different
[semantics](#dfn-semantics) is repurposed as a text field.

Authors *MUST* limit the children of a textbox to non-interactive,
entirely presentational elements such as icons used to visually convey
information that is already exposed in an accessible manner. Examples
include:

- an error icon, where the containing textbox has been provided an
 [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid),
 [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage),
 or both attributes;
- an icon of a user silhouette, where the textbox is also visibly
 labeled or provided an accessible name of \"name\" or \"username\";
 and
- a graphical status indicator, such as a gauge to represent characters
 remaining, which represents dynamically updating text available
 outside of the textbox.

In most user agent implementations, the default behavior of the
[ENTER] or [RETURN] key is different between the single-line
and multi-line text fields in [HTML]. When user has focus in a single-line
`<input type="text">` element, the keystroke usually submits the form.
When user has focus in a multi-line `<textarea>` element, the keystroke
inserts a line break. The [WAI-ARIA] `textbox` role
differentiates these types of boxes with the
[`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)
attribute, so authors are advised to be aware of this distinction when
designing the field.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================================+
| Superclass Role: | [`input`](https://w3c.github.io/aria/#input) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | - `<`[`textarea`](https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element)`>` in |
| | [HTML] |
| | - `<input type="`[`text`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-text-keyword)`">` |
| | in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline) |
| | - [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `time` [role]

An element that represents a specific point in time.

At the present time, there are no [WAI-ARIA] properties corresponding
to the `datetime` attribute supported on
`<`[`time`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-time-element)`>`
in [HTML]. The addition of this
property will be considered for [ARIA] version 1.3.

Authors *SHOULD* limit text contents to a valid date- or time-related
string, or apply this future `datetime`-equivalent property to the
element which has role `time`.

[Example 24](#example-24)

Examples of valid date- or time-related strings as text contents of an
element with the `time` role:

- A valid month string: `<span >2019-11</span>`
- A valid date string: `<span >2019-11-18</span>`
- A valid yearless date string: `<span >11-18</span>`
- A valid time string: `<span >09:54:39</span>`
- A valid floating date and time string:
 `<span >2019-11-18T14:54</span>`
- A valid time-zone offset string: `<span >-08:00</span>`
- A valid global date and time string:
 `<span >2019-11-18T14:54Z</span>`
- A valid week string: `<span >2019-W47</span>`
- Four or more ASCII digits, at least one of which is not U+0030 DIGIT
 ZERO (0): `<span >0001</span>`
- A valid duration string: `<span >4h 18m 3s</span>`

+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+========================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Related Concepts: | `<`[`time`](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-time-element)`>` |
| | in [HTML] |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role in ARIA |
| | 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this role in |
| | ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Prohibited States and Properties: | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+
| Name From: | prohibited |
+-----------------------------------+------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `timer` [role]

A type of [live region](#dfn-live-region) containing a numerical counter which
indicates an amount of elapsed time from a start point, or the time
remaining until an end point.

The text contents of the timer
[object](#dfn-object) indicate the current time measurement, and are updated
as that amount changes. The timer value is not necessarily machine
parsable, but authors *SHOULD* update the text contents at fixed
intervals, except when the timer is paused or reaches an end-point.

Elements with the role `timer` have an implicit
[`aria-live`](https://w3c.github.io/aria/#aria-live)
value of `off`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`status`](https://w3c.github.io/aria/#status) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-live`](https://w3c.github.io/aria/#aria-live) is `off`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `toolbar` [role]

A collection of commonly used function buttons or controls represented
in compact visual form.

The toolbar is often a subset of functions found in a
[`menubar`](https://w3c.github.io/aria/#menubar),
designed to reduce user effort in using these functions. Authors *MUST*
supply a label on each toolbar when the application contains more than
one toolbar.

Authors *MAY* manage focus of descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

Elements with the role `toolbar` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `horizontal`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`group`](https://w3c.github.io/aria/#group) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Related Concepts: | [`menubar`](https://w3c.github.io/aria/#menubar) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `horizontal`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `tooltip` [role]

A contextual popup that displays a description for an element.

The `tooltip` typically becomes visible, after a short delay, in
response to a mouse hover, or after the [accessibility
parent](#dfn-accessibility-parent) receives keyboard focus. The use of a
[WAI-ARIA] tooltip
is a supplement to the normal tooltip behavior of the user agent.

Typical tooltip delays last from one to five seconds.

Authors *SHOULD* ensure that elements with the
[role](#dfn-role)
`tooltip` are referenced through the use of
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
before or at the time the tooltip is displayed.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`section`](https://w3c.github.io/aria/#section) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `tree` [role]

A [`widget`](https://w3c.github.io/aria/#widget) that
allows the user to select one or more items from a hierarchically
organized collection.

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

Elements with the role `tree` have an implicit
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
value of `vertical`.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | [`select`](https://w3c.github.io/aria/#select) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | [`treeitem`](https://w3c.github.io/aria/#treeitem) |
| Roles: | |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) |
| | - [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Implicit Value for Role: | Default for [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) is |
| | `vertical`. |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `treegrid` [role]

A [`grid`](https://w3c.github.io/aria/#grid) whose rows
can be expanded and collapsed in the same manner as for a
[`tree`](https://w3c.github.io/aria/#tree).

If
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
is set on an
[element](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `treegrid`, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* propagate the value to all
[`gridcell`](https://w3c.github.io/aria/#gridcell)
elements that are [accessibility
descendants](#dfn-accessibility-descendant) of the `treegrid` and expose the value in
the accessibility [API]. An author *MAY* override the
propagated value of
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
for an individual
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element.

When the
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
attribute is applied to a
[focusable](#dfn-focusable)
[`gridcell`](https://w3c.github.io/aria/#gridcell), it
indicates whether the content contained in the
[`gridcell`](https://w3c.github.io/aria/#gridcell) is
editable. The
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
attribute does not represent availability of functions for navigating or
manipulating the `treegrid` itself.

In a `treegrid` that provides content editing functions, if the content
of a focusable
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element is not editable, authors *MAY* set
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
to `true` on the
[`gridcell`](https://w3c.github.io/aria/#gridcell)
element. However, if a `treegrid` presents a collection of elements that
do not support
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly),
such as a collection of
[`link`](https://w3c.github.io/aria/#link) elements, it
is not necessary for the author to specify a value for
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly).

To be [keyboard
accessible](#dfn-keyboard-accessible), authors *SHOULD* manage focus of
descendants for all instances of this
[role](#dfn-role), as
described in [Managing Focus](#managingfocus).

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Allowed Accessibility Child | - [`caption`](https://w3c.github.io/aria/#caption) |
| Roles: | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`rowgroup`](https://w3c.github.io/aria/#rowgroup) with [accessibility |
| | child](#dfn-accessibility-child) |
| | [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) |
| | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) |
| | - [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-required`](https://w3c.github.io/aria/#aria-required) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `treeitem` [role]

An item in a
[`tree`](https://w3c.github.io/aria/#tree).

A [`treeitem`](https://w3c.github.io/aria/#treeitem)
[element](https://dom.spec.whatwg.org/#concept-element)
can contain a sub-level group of elements that can be expanded or
collapsed. An expandable collection of `treeitem` elements are enclosed
in an element with the
[`group`](https://w3c.github.io/aria/#group)
[role](#dfn-role).

Authors *MUST* ensure
[elements](https://dom.spec.whatwg.org/#concept-element)
with [role](#dfn-role) `treeitem` are [accessibility
children](#dfn-accessibility-child) of an element with role
[`tree`](https://w3c.github.io/aria/#tree) or an
element with role
[`group`](https://w3c.github.io/aria/#group) that is
the [accessibility
child](#dfn-accessibility-child) of an element with role
[`treeitem`](https://w3c.github.io/aria/#treeitem).

In certain conditions, a user agent *MAY* provide an implicit value for
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
for each
[`treeitem`](https://w3c.github.io/aria/#treeitem) in a
[`tree`](https://w3c.github.io/aria/#tree), and if it
does, the user agent *MUST* ensure the following conditions are met
before providing an implicit value:

- The value of
 [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
 on the [`tree`](https://w3c.github.io/aria/#tree) is
 `false` or `undefined`.
- None of the
 [`treeitem`](https://w3c.github.io/aria/#treeitem)
 elements in the
 [`tree`](https://w3c.github.io/aria/#tree) have an
 explicitly declared value for
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 or
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked).

If a user agent provides an implicit
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
value for a
[`treeitem`](https://w3c.github.io/aria/#treeitem), the
value *SHOULD* be `true` if the
[`treeitem`](https://w3c.github.io/aria/#treeitem) has
[DOM] focus or the
[`tree`](https://w3c.github.io/aria/#tree) has
[DOM] focus and the
[`treeitem`](https://w3c.github.io/aria/#treeitem) is
referenced by
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
Otherwise, if a user agent provides an implicit
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
value for a
[`treeitem`](https://w3c.github.io/aria/#treeitem), the
value *SHOULD* be `false`.

Authors *MAY* indicate selection for
[`treeitem`](https://w3c.github.io/aria/#treeitem)
elements using either
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
or
[`aria-checked`](https://w3c.github.io/aria/#aria-checked).
Some user interfaces indicate selection with
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
in single-select trees and with
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
in multi-select trees. Authors *SHOULD NOT* specify both
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
and
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
on [`treeitem`](https://w3c.github.io/aria/#treeitem)
elements contained by the same
[`tree`](https://w3c.github.io/aria/#tree) except in
the extremely rare circumstances where all the following conditions are
met:

- The meaning and purpose of
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
 is different from the meaning and purpose of
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
 in the user interface.
- The user interface makes the meaning and purpose of each state
 apparent.
- The user interface provides a separate method for controlling each
 state.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Superclass Role: | - [`listitem`](https://w3c.github.io/aria/#listitem) |
| | - [`option`](https://w3c.github.io/aria/#option) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Required Accessibility Parent | - [`tree`](https://w3c.github.io/aria/#tree) |
| Roles: | - [`group`](https://w3c.github.io/aria/#group) with [accessibility |
| | parent](#dfn-accessibility-parent) |
| | [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | - [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) |
| | - [`aria-level`](https://w3c.github.io/aria/#aria-level) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-checked`](https://w3c.github.io/aria/#aria-checked) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
| | - [`aria-selected`](https://w3c.github.io/aria/#aria-selected) (state) |
| | - [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Name From: | - contents |
| | - author |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Accessible Name Required: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `widget` [abstract role]

An interactive component of a graphical user interface ([GUI]).

Widgets are discrete user interface objects with which the user can
interact. Widget [roles](#dfn-role) map to standard features in [accessibility [APIs]](#dfn-accessibility-api). When the user navigates an element
assigned any of the non-abstract subclass roles of `widget`, [assistive
technologies](#assistive-technology) that typically intercept standard keyboard
events *SHOULD* switch to an application browsing mode, and pass
keyboard events through to the web application. The intent is to hint to
certain [assistive
technologies](#assistive-technology) to switch from normal browsing mode into a
mode more appropriate for interacting with a web application; some [user
agents](https://infra.spec.whatwg.org/#user-agent) have
a browse navigation mode where keys, such as up and down arrows, are
used to browse the document, and this native behavior prevents the use
of these keys by a web application.

`widget` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `widget` role in content.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`roletype`](https://w3c.github.io/aria/#roletype) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`command`](https://w3c.github.io/aria/#command) |
| | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`input`](https://w3c.github.io/aria/#input) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### `window` [abstract role]

A browser or application window.

[Elements](https://dom.spec.whatwg.org/#concept-element) with this [role](#dfn-role) have a window-like behavior in a graphical
user interface ([GUI]) context,
regardless of whether they are implemented as a native window in the
operating system, or merely as a section of the document styled to look
like a window.

`window` is an [abstract role](#isAbstract) used for the ontology.
Authors *MUST NOT* use `window` role in content.

In the description of this role, the term \"application\" does not refer
to the
[`application`](https://w3c.github.io/aria/#application)
role, which specifies specific assistive technology behaviors.

+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=================================================================================================================+
| Is Abstract: | True |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Superclass Role: | [`roletype`](https://w3c.github.io/aria/#roletype) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Subclass Roles: | - [`dialog`](https://w3c.github.io/aria/#dialog) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Supported States and Properties: | [`aria-modal`](https://w3c.github.io/aria/#aria-modal) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+
| Inherited States and Properties: | - [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) |
| | - [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) |
| | - [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) |
| | - [`aria-busy`](https://w3c.github.io/aria/#aria-busy) (state) |
| | - [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
| | - [`aria-current`](https://w3c.github.io/aria/#aria-current) (state) |
| | - [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) |
| | - [`aria-description`](https://w3c.github.io/aria/#aria-description) |
| | - [`aria-details`](https://w3c.github.io/aria/#aria-details) |
| | - [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect) |
| | - [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) **(deprecated on |
| | this role in ARIA 1.2)** |
| | - [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) |
| | - [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed) (state) |
| | - [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) **(deprecated on this role |
| | in ARIA 1.2)** |
| | - [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) (state) |
| | - [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) (state) **(deprecated on this |
| | role in ARIA 1.2)** |
| | - [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) |
| | - [`aria-label`](https://w3c.github.io/aria/#aria-label) |
| | - [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) |
| | - [`aria-live`](https://w3c.github.io/aria/#aria-live) |
| | - [`aria-owns`](https://w3c.github.io/aria/#aria-owns) |
| | - [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) |
| | - [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) |
+-----------------------------------+-----------------------------------------------------------------------------------------------------------------+

: Characteristics:

::: header-wrapper
## 6. Supported States and Properties

::: header-wrapper
### 6.1 Clarification of States versus Properties

The terms \"states\" and \"properties\" refer to similar features. Both
provide specific information about an
[object](#dfn-object), and both form part of the definition of the nature of
[roles](#dfn-role).
In this document, states and properties are both treated as
aria-prefixed markup
[attributes](https://dom.spec.whatwg.org/#concept-attribute).
However, they are maintained conceptually distinct to clarify subtle
differences in their meaning. One major difference is that the values of
properties (such as
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby))
are often less likely to change throughout the application life-cycle
than the values of states (such as
[`aria-checked`](https://w3c.github.io/aria/#aria-checked))
which might change frequently due to user interaction. Note that the
frequency of change difference is not a rule; a few properties, such as
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
are expected to change often. Because the distinction between states and
properties is of little consequence to most authors, this specification
refers to both \"states\" and \"properties\" simply as \"attributes\"
whenever possible. See the definitions of
[state](#dfn-state) and
[property](#dfn-property) for more information.

::: header-wrapper
### 6.2 Characteristics of States and Properties

States and properties have the characteristics described in the
following sections.

::: header-wrapper
#### 6.2.1 Related Concepts

Advisory information about features from this or other languages that
correspond to this [state](#dfn-state) or
[property](#dfn-property). While the correspondence might not be
exact, it is useful to help understand the intent of the state or
property.

::: header-wrapper
#### 6.2.2 Used in Roles

Advisory information about [roles](#role_definitions) that use this
[state](#dfn-state)
or [property](#dfn-property). This information is provided to help
understand the appropriate usage of the state or property. Use of a
given state or property is not defined when used on roles other than
those listed.

::: header-wrapper
#### 6.2.3 Inherits into Roles

Advisory information about [roles](#role_definitions) that inherit the
[state](#dfn-state)
or [property](#dfn-property) from an ancestor role.

::: header-wrapper
#### 6.2.4 Value

Value type of the [state](#dfn-state) or [property](#dfn-property). The value is one of the
following types:

true/false
: Value representing either `true` or `false`. The default value for
 this value type is `false` unless otherwise specified.

tristate
: Value representing `true`, `false`, `mixed`, or `undefined` values.
 The default value for this value type is `undefined` unless
 otherwise specified.

true/false/undefined
: Value representing `true`, `false`, or `undefined` (not applicable).
 The default value for this value type is `undefined` unless
 otherwise specified. For example, an element with
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
 set to `false` is not currently expanded; an element with
 [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
 set to `undefined` is not expandable.

ID reference
: Reference to the ID of another
 [element](https://dom.spec.whatwg.org/#concept-element)
 in the same document

ID reference list
: A list of one or more ID references.

integer
: A numerical value without a fractional component.

number
: Any real numerical value.

string
: Unconstrained value type.

token
: One of a limited set of allowed values. The default value is defined
 in each attribute\'s Values table, as specified in the [Attribute
 Values](#enumerated-attribute-values) section.

[token list]
: A list of one or more tokens.

These are generic types for states and properties, but do not define
specific representation. See [State and Property Attribute
Processing](#state_property_processing) for details on how these values
are expressed and handled in host languages.

::: header-wrapper
### 6.3 [ARIA] Attributes

::: header-wrapper
#### 6.3.1 Multi-value Attribute Values

When the [ARIA]
attribute definition includes a table listing the attribute\'s allowed
values, that attribute is a multi-value nullable attribute. Each value
in the table is a keyword for the attribute, mapping to a state of the
same name.

::: header-wrapper
#### 6.3.2 IDL reflection of [ARIA] attributes

All [ARIA]
attributes reflect in IDL as
[nullable](https://webidl.spec.whatwg.org/#dfn-nullable-type)
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) attributes. This includes the boolean-like
[true/false](#valuetype_true-false) type, and all other [ARIA] attributes.

Default values from the [ARIA] values tables *MUST NOT*
reflect to IDL as the [missing value
default](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#missing-value-default)
or the [invalid value
default](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#invalid-value-default)
for the attribute. On getting, a missing [ARIA] attribute will return
`null`. [ARIA]
attributes are not validated on get. If an [ARIA] value is invalid, on
getting, it will return its set value as a literal string, and will not
return an invalid value default.

::: header-wrapper
#### 6.3.3 Operating System Accessibility [API] mapping of multi-value [ARIA] attributes

Unlike IDL reflection, operating system accessibility [API] mappings of [ARIA] attributes can have
defaults. Any default values from the [ARIA] values tables are exposed
to the operating system accessibility [API] as described in [5.2.3
Supported States and Properties](#supportedState), and in [Core Accessibility API
Mappings
1.1](https://www.w3.org/TR/core-aam-1.1/){matched-text="[[[CORE-AAM]]]"}.

::: header-wrapper
#### 6.3.4 [ARIA] nullable DOMString Attributes

As noted in [A. Mapping [WAI-ARIA] Value types to
languages](#typemapping),
attributes are included in host languages, and the syntax for
representation of [WAI-ARIA] types is governed by the
host language.

The following algorithm should be used for [ARIA] nullable
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString) attributes in [HTML]:

On getting, if the corresponding content attribute is not present, then
the IDL attribute must return null, otherwise, the IDL attribute must
get the value in a transparent, case-preserving manner. On setting, if
the new value is null, the content attribute must be removed, and
otherwise, the content attribute must be set to the specified new value
in a transparent, case-preserving manner.

Note: As of [ARIA]
1.2, all [ARIA]
attributes exposed via IDL are defined as nullable
[`DOMString`](https://webidl.spec.whatwg.org/#idl-DOMString)s. This matches the current implementation of all major
rendering engines. This specification change should result in no
implementation changes; it will merely represent the current reality of
web engines. However, in a future draft, the [ARIA] Working Group intends to
change several [ARIA] attributes to
non-nullable DOMStrings, and seek implementations. The proposed change
will bring [ARIA]
into alignment with the [HTML]'s usage of [enumerated
attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#enumerated-attribute).

::: header-wrapper
##### 6.3.4.1 Example Attribute Usage

*This section is non-normative.*

[Example 25](#example-25)

[Example](#example-25-0)

```
// HTML hidden="" example (not aria-hidden="true")
// Actual boolean type; defaults to false.

// Note: Actual boolean assignment and return value.
el.hidden = true;
el.hidden; // true

// Removal of content attribute results in missing value default: boolean false.
el.removeAttribute("hidden");
el.hidden; // false
```

[Example 26](#example-26)

[Example](#example-26-0)

```
// aria-busy example
// true/false ~ boolean-like nullable string; returns null unless set

el.ariaBusy; // null

// Note: String assignment and return value.
el.ariaBusy = "true";
el.ariaBusy; // "true"

// Removal of content attribute results in missing value default: string "false".
el.removeAttribute("aria-busy");
el.ariaBusy; // null

// Assignment of invalid "busy" value. Not validated on set or get and the literal string value "busy" is returned.
el.setAttribute("aria-busy", "busy");
el.ariaBusy; // "busy"
```

[Example 27](#example-27)

[Example](#example-27-0)

```
// aria-pressed example
// Tristate ~ true/false/mixed/undefined string; null if unspecified

// no value has been defined
button.ariaPressed; // null

// A value of "true", "false", or "mixed" for aria-pressed on a button denotes a toggle button.
button.setAttribute("aria-pressed", "true"); // Content attribute assignment.
button.ariaPressed; // "true"
button.ariaPressed = "false"; // DOM property assignment.
button.ariaPressed; // "false"

// Assignment of invalid "foo" value. Not validated on set or get and the literal string value "foo" is returned.
button.ariaPressed = "foo";
button.ariaPressed; // "foo" (Note: button is no longer a toggle button.)

// Removal of content attribute results in a null value
button.removeAttribute("aria-pressed");
button.ariaPressed; // null
```

::: header-wrapper
### 6.4 Translatable Attributes

The [HTML] specification states
that other specifications can define [translatable
attributes](https://html.spec.whatwg.org/multipage/dom.html#translatable-attributes).
The language and directionality of each attribute value is the same as
the [language](https://html.spec.whatwg.org/multipage/dom.html#language)
and
[directionality](https://html.spec.whatwg.org/multipage/dom.html#the-directionality)
of the element.

To be understandable by assistive technology users, the values of the
following [states](#dfn-state) and
[properties](#dfn-property) are [translatable
attributes](https://html.spec.whatwg.org/multipage/dom.html#translatable-attributes)
and should be translated when a page is localized:

- [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
- [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription)
- [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext)
- [`aria-description`](https://w3c.github.io/aria/#aria-description)
- [`aria-label`](https://w3c.github.io/aria/#aria-label)
- [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder)
- [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription)
- [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext)
- [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)

::: header-wrapper
### 6.5 [Global] States and Properties

Some [states](#dfn-state) and
[properties](#dfn-property) are applicable to all host language
[elements](https://dom.spec.whatwg.org/#concept-element)
regardless of whether a [role](#dfn-role) is applied. The following global states
and properties are supported by all roles and by all base markup
elements unless otherwise prohibited. If a role prohibits use of any
global states or properties, those states or properties are listed as
prohibited in the characteristics table included in the section that
defines the role.

- [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
- [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
 (Except where prohibited)
- [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription)
 (Except where prohibited)
- [`aria-busy (state)`](https://w3c.github.io/aria/#aria-busy)
- [`aria-controls`](https://w3c.github.io/aria/#aria-controls)
- [`aria-current (state)`](https://w3c.github.io/aria/#aria-current)
- [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
- [`aria-description`](https://w3c.github.io/aria/#aria-description)
- [`aria-details`](https://w3c.github.io/aria/#aria-details)
- [`aria-disabled (state)`](https://w3c.github.io/aria/#aria-disabled)
 (Global use deprecated in ARIA 1.2)
- [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
- [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage)
 (Global use deprecated in ARIA 1.2)
- [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)
- [`aria-grabbed (state)`](https://w3c.github.io/aria/#aria-grabbed)
- [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
 (Global use deprecated in ARIA 1.2)
- [`aria-hidden (state)`](https://w3c.github.io/aria/#aria-hidden)
- [`aria-invalid (state)`](https://w3c.github.io/aria/#aria-invalid)
 (Global use deprecated in ARIA 1.2)
- [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts)
- [`aria-label`](https://w3c.github.io/aria/#aria-label)
 (Except where prohibited)
- [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 (Except where prohibited)
- [`aria-live`](https://w3c.github.io/aria/#aria-live)
- [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
- [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
- [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription)
 (Except where prohibited)

::: header-wrapper
### 6.6 Taxonomy of [WAI-ARIA] States and Properties

States and properties are categorized as follows:

1. [Widget Attributes](#attrs_widgets)
2. [Live Region Attributes](#attrs_liveregions)
3. [Drag-and-Drop Attributes](#attrs_dragdrop)
4. [Relationship Attributes](#attrs_relationships)

::: header-wrapper
#### 6.6.1 Widget Attributes

This section contains
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
specific to common user interface
[elements](https://dom.spec.whatwg.org/#concept-element)
found on [GUI] systems or in
rich internet applications which receive user input and process user
actions. These attributes are used to support the [widget
roles](#widget_roles).

- [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete)
- [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
- [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
- [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage)
- [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
- [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
- [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
- [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
- [`aria-label`](https://w3c.github.io/aria/#aria-label)
- [`aria-level`](https://w3c.github.io/aria/#aria-level)
- [`aria-modal`](https://w3c.github.io/aria/#aria-modal)
- [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)
- [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
- [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
- [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder)
- [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
- [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly)
- [`aria-required`](https://w3c.github.io/aria/#aria-required)
- [`aria-selected`](https://w3c.github.io/aria/#aria-selected)
- [`aria-sort`](https://w3c.github.io/aria/#aria-sort)
- [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
- [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
- [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
- [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)

Widget attributes might be mapped by a [user
agent](https://infra.spec.whatwg.org/#user-agent) to
platform [accessibility [API]](#dfn-accessibility-api) [state](#dfn-state), for access by [assistive
technologies](#assistive-technology), or they might be accessed directly from
the [DOM].

::: header-wrapper
#### 6.6.2 Live Region Attributes

This section contains
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
specific to [live regions](#dfn-live-region) in rich internet applications. These
attributes *MAY* be applied to any
[element](https://dom.spec.whatwg.org/#concept-element).
The purpose of these attributes is to indicate that content changes
might occur without the element having focus, and to provide [assistive
technologies](#assistive-technology) with information on how to process those
content updates. Some [roles](#dfn-role) specify a default value for the
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attribute specific to that role. An example of a live region is a ticker
section that lists updating stock quotes. User agents *MAY* ignore
changes triggered by direct user action on an
[element](https://dom.spec.whatwg.org/#concept-element)
inside a live region (e.g., editing the value of a text field).

- [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
- [`aria-busy`](https://w3c.github.io/aria/#aria-busy)
- [`aria-live`](https://w3c.github.io/aria/#aria-live)
- [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)

::: header-wrapper
#### 6.6.3 Drag-and-Drop Attributes

This section lists
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
which indicate information about drag-and-drop interface
[elements](https://dom.spec.whatwg.org/#concept-element),
such as draggable elements and their drop targets. Drop target
information will be rendered visually by the author and provided to
[assistive
technologies](#assistive-technology) through an alternate modality.

- [`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
- [`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed)

::: header-wrapper
#### 6.6.4 Relationship Attributes

This section lists
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
that indicate
[relationships](#dfn-relationship) or associations between
[elements](https://dom.spec.whatwg.org/#concept-element)
which cannot be readily determined from the document structure.

- [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
- [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount)
- [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
- [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext)
- [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)
- [`aria-controls`](https://w3c.github.io/aria/#aria-controls)
- [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
- [`aria-details`](https://w3c.github.io/aria/#aria-details)
- [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage)
- [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)
- [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
- [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
- [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
- [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount)
- [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
- [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext)
- [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)
- [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)

::: header-wrapper
### 6.7 State change notification

User agents *MUST* provide a way for assistive technologies to be
notified when states change, either through [DOM] attribute change
[events](#dfn-event)
or platform accessibility [API] events.

::: header-wrapper
### 6.8 Definitions of States and Properties (all aria-\* attributes)

Below is an alphabetical list of [WAI-ARIA]
[states](#dfn-state)
and [properties](#dfn-property) to be used by authors. A detailed
definition of each [WAI-ARIA] state and
[property](#dfn-property) follows this compact list.

[aria-activedescendant](#aria-activedescendant)
: [Identifies](#dfn-identifies) the
 currently active element when [DOM] focus is on a
 [`composite`](https://w3c.github.io/aria/#composite)
 widget,
 [`combobox`](https://w3c.github.io/aria/#combobox),
 [`textbox`](https://w3c.github.io/aria/#textbox),
 [`group`](https://w3c.github.io/aria/#group), or
 [`application`](https://w3c.github.io/aria/#application).

[aria-atomic](#aria-atomic)
: [Indicates](#dfn-indicates) whether
 [assistive technologies](#assistive-technology) will present all, or only parts of, the changed
 region based on the change notifications defined by the
 [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
 attribute.

[aria-autocomplete](#aria-autocomplete)
: [Indicates](#dfn-indicates) whether
 inputting text could trigger display of one or more predictions of
 the user\'s intended value for a
 [`combobox`](https://w3c.github.io/aria/#combobox),
 [`searchbox`](https://w3c.github.io/aria/#searchbox),
 or [`textbox`](https://w3c.github.io/aria/#textbox)
 and specifies how predictions would be presented if they were made.

[aria-braillelabel](#aria-braillelabel)
: [Defines](#dfn-defines) a string value
 that labels the current element, which is intended to be converted
 into Braille. See related
 [`aria-label`](https://w3c.github.io/aria/#aria-label).

[aria-brailleroledescription](#aria-brailleroledescription)
: [Defines](#dfn-defines) a
 human-readable, author-localized abbreviated description for the
 [role](#dfn-role) of an
 [element](https://dom.spec.whatwg.org/#concept-element),
 which is intended to be converted into Braille. See related
 [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription).

[aria-busy](#aria-busy)
: [Indicates](#dfn-indicates) an element
 is being modified and that assistive technologies could wait until
 the modifications are complete before exposing them to the user.

[aria-checked](#aria-checked)
: [Indicates](#dfn-indicates) the
 current \"checked\" [state](#dfn-state) of checkboxes, radio buttons, and other
 [widgets](#dfn-widget). See related
 [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
 and
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected).

[aria-colcount](#aria-colcount)
: [Defines](#dfn-defines) the total
 number of columns in a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex).

[aria-colindex](#aria-colindex)
: [Defines](#dfn-defines) an
 [element\'s](https://dom.spec.whatwg.org/#concept-element) column index or position with respect to the total
 number of columns within a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext),
 [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount),
 and
 [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan).

[aria-colindextext](#aria-colindextext)
: [Defines](#dfn-defines) a human
 readable text alternative of
 [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex).
 See related
 [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext).

[aria-colspan](#aria-colspan)
: [Defines](#dfn-defines) the number of
 columns spanned by a cell or gridcell within a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
 and
 [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan).

[aria-controls](#aria-controls)
: [Identifies](#dfn-identifies) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) whose contents or presence are controlled by the
 focused element or composite widget. See related
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 and
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns).

[aria-current](#aria-current)
: [Indicates](#dfn-indicates) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 that represents the current item within a container or set of
 related elements.

[aria-describedby](#aria-describedby)
: [Identifies](#dfn-identifies) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) that describes the [object](#dfn-object). See related
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
 and
 [`aria-description`](https://w3c.github.io/aria/#aria-description).

[aria-description](#aria-description)
: [Defines](#dfn-defines) a string value
 that describes or annotates the current element. See related
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

[aria-details](#aria-details)
: [Identifies](#dfn-identifies) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) that provide additional information related to the
 [object](#dfn-object). See related
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

[aria-disabled](#aria-disabled)
: [Indicates](#dfn-indicates) that the
 [element](https://dom.spec.whatwg.org/#concept-element)
 is [perceivable](#dfn-perceivable) but
 disabled, so it is not editable or otherwise
 [operable](#dfn-operable). See related
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
 and
 [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly).

[aria-dropeffect](#aria-dropeffect)
: \[Deprecated in [ARIA] 1.1\] Indicates what
 functions can be performed when a dragged object is released on the
 drop target.

[aria-errormessage](#aria-errormessage)
: [Identifies](#dfn-identifies) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) that provides an error message for an
 [object](#dfn-object). See related
 [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
 and
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

[aria-expanded](#aria-expanded)
: [Indicates](#dfn-indicates) whether a
 related element is expanded (shown) or collapsed (hidden).

[aria-flowto](#aria-flowto)
: [Identifies](#dfn-identifies) the next
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) in an alternate reading order of content which, at the
 user\'s discretion, allows assistive technology to override the
 general default of reading in document source order.

[aria-grabbed](#aria-grabbed)
: \[Deprecated in [ARIA] 1.1\] Indicates an
 element\'s \"grabbed\" [state](#dfn-state) in a drag-and-drop operation.

[aria-haspopup](#aria-haspopup)
: [Indicates](#dfn-indicates) the
 availability and type of interactive popup element, such as menu or
 dialog, that can be triggered by an
 [element](https://dom.spec.whatwg.org/#concept-element).

[aria-hidden](#aria-hidden)
: [Indicates](#dfn-indicates), when set
 to `true`, that an
 [element](https://dom.spec.whatwg.org/#concept-element)
 and its entire subtree are hidden from assistive technology,
 regardless of whether it is visibly rendered.

[aria-invalid](#aria-invalid)
: [Indicates](#dfn-indicates) the
 entered value does not conform to the format expected by the
 application. See related
 [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage).

[aria-keyshortcuts](#aria-keyshortcuts)
: [Defines](#dfn-defines) keyboard
 shortcuts that an author has implemented to activate or give focus
 to an element.

[aria-label](#aria-label)
: [Defines](#dfn-defines) a string value
 that labels the current element. See related
 [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby).

[aria-labelledby](#aria-labelledby)
: [Identifies](#dfn-identifies) the
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) that labels the current element. See related
 [`aria-label`](https://w3c.github.io/aria/#aria-label)
 and
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

[aria-level](#aria-level)
: [Defines](#dfn-defines) the
 hierarchical level of an
 [element](https://dom.spec.whatwg.org/#concept-element)
 within a structure.

[aria-live](#aria-live)
: [Indicates](#dfn-indicates) that an
 [element](https://dom.spec.whatwg.org/#concept-element)
 will be updated or modified, and defines the priority of updates the
 [user
 agents](https://infra.spec.whatwg.org/#user-agent),
 [assistive technologies](#assistive-technology), and user can expect from the [live
 region](#dfn-live-region).

[aria-modal](#aria-modal)
: [Indicates](#dfn-indicates) whether an
 [element](https://dom.spec.whatwg.org/#concept-element)
 is modal when displayed.

[aria-multiline](#aria-multiline)
: [Indicates](#dfn-indicates) whether a
 text box accepts multiple lines of input or only a single line.

[aria-multiselectable](#aria-multiselectable)
: [Indicates](#dfn-indicates) that the
 user can select more than one item from the current selectable
 descendants.

[aria-orientation](#aria-orientation)
: [Indicates](#dfn-indicates) whether
 the element\'s orientation is horizontal, vertical, or
 unknown/ambiguous.

[aria-owns](#aria-owns)
: [Identifies](#dfn-identifies) an
 [element](https://dom.spec.whatwg.org/#concept-element)
 (or elements) in order to define a visual, functional, or contextual
 parent/child [relationship](#dfn-relationship) between [DOM]
 elements where the [DOM]
 hierarchy cannot be used to represent the relationship. See related
 [`aria-controls`](https://w3c.github.io/aria/#aria-controls).

[aria-placeholder](#aria-placeholder)
: [Defines](#dfn-defines) a short hint
 (a word or short phrase) intended to aid the user with data entry
 when the control has no value. A hint could be a sample value or a
 brief description of the expected format.

[aria-posinset](#aria-posinset)
: [Defines](#dfn-defines) an
 [element](https://dom.spec.whatwg.org/#concept-element)\'s
 number or position in the current set of listitems or treeitems. Not
 required if all elements in the set are present in the [DOM]. See related
 [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).

[aria-pressed](#aria-pressed)
: [Indicates](#dfn-indicates) the
 current \"pressed\" [state](#dfn-state) of toggle buttons. See related
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
 and
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected).

[aria-readonly](#aria-readonly)
: Indicates that the
 [element](https://dom.spec.whatwg.org/#concept-element)
 is not editable, but is otherwise
 [operable](#dfn-operable). See related
 [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled).

[aria-relevant](#aria-relevant)
: [Indicates](#dfn-indicates) what
 notifications the user agent will trigger when the [accessibility
 tree](#dfn-accessibility-tree) within
 a live region is modified. See related
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic).

[aria-required](#aria-required)
: [Indicates](#dfn-indicates) that user
 input is required on the
 [element](https://dom.spec.whatwg.org/#concept-element)
 before a form can be submitted.

[aria-roledescription](#aria-roledescription)
: [Defines](#dfn-defines) a
 human-readable, author-localized description for the
 [role](#dfn-role) of an
 [element](https://dom.spec.whatwg.org/#concept-element).

[aria-rowcount](#aria-rowcount)
: [Defines](#dfn-defines) the total
 number of rows in a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex).

[aria-rowindex](#aria-rowindex)
: [Defines](#dfn-defines) an
 [element\'s](https://dom.spec.whatwg.org/#concept-element) row index or position with respect to the total number
 of rows within a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext),
 [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount),
 and
 [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan).

[aria-rowindextext](#aria-rowindextext)
: [Defines](#dfn-defines) a human
 readable text alternative of
 [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex).
 See related
 [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext).

[aria-rowspan](#aria-rowspan)
: [Defines](#dfn-defines) the number of
 rows spanned by a cell or gridcell within a
 [`table`](https://w3c.github.io/aria/#table),
 [`grid`](https://w3c.github.io/aria/#grid), or
 [`treegrid`](https://w3c.github.io/aria/#treegrid).
 See related
 [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
 and
 [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan).

[aria-selected](#aria-selected)
: [Indicates](#dfn-indicates) the
 current \"selected\" [state](#dfn-state) of various [widgets](#dfn-widget). See related
 [`aria-checked`](https://w3c.github.io/aria/#aria-checked)
 and
 [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed).

[aria-setsize](#aria-setsize)
: [Defines](#dfn-defines) the number of
 items in the current set of listitems or treeitems. Not required if
 all elements in the set are present in the [DOM]. See related
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset).

[aria-sort](#aria-sort)
: [Indicates](#dfn-indicates) if items
 in a table or grid are sorted in ascending or descending order.

[aria-valuemax](#aria-valuemax)
: [Defines](#dfn-defines) the maximum
 allowed value for a range [widget](#dfn-widget).

[aria-valuemin](#aria-valuemin)
: [Defines](#dfn-defines) the minimum
 allowed value for a range [widget](#dfn-widget).

[aria-valuenow](#aria-valuenow)
: [Defines](#dfn-defines) the current
 value for a range [widget](#dfn-widget). See related
 [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext).

[aria-valuetext](#aria-valuetext)
: [Defines](#dfn-defines) the human
 readable text alternative of
 [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
 for a range [widget](#dfn-widget).

#### [`aria-activedescendant` [property]]

[Identifies](#dfn-identifies) the currently active element when [DOM] focus is on a
[`composite`](https://w3c.github.io/aria/#composite)
widget,
[`combobox`](https://w3c.github.io/aria/#combobox),
[`textbox`](https://w3c.github.io/aria/#textbox),
[`group`](https://w3c.github.io/aria/#group), or
[`application`](https://w3c.github.io/aria/#application).

The `aria-activedescendant` property provides an alternative method of
managing focus for interactive elements that might contain multiple
[focusable](#dfn-focusable) descendants, such as menus, grids, and toolbars.
Instead of moving [DOM] focus among
[accessibility
descendants](#dfn-accessibility-descendant), authors *MAY* set [DOM] focus on a container
[element](https://dom.spec.whatwg.org/#concept-element)
that supports `aria-activedescendant` and then use
`aria-activedescendant` to refer to the element that is active.

Authors *MUST* ensure that one of the following two sets of conditions
is met when setting the value of `aria-activedescendant` on an element
with [DOM] focus:

1. The value of `aria-activedescendant` refers to an [accessibility
 descendant](#dfn-accessibility-descendant).
2. The element with [DOM] focus is
 a
 [`combobox`](https://w3c.github.io/aria/#combobox),
 [`textbox`](https://w3c.github.io/aria/#textbox) or
 [`searchbox`](https://w3c.github.io/aria/#searchbox)
 with
 [`aria-controls`](https://w3c.github.io/aria/#aria-controls)
 referring to an element that supports `aria-activedescendant`, and
 the value of `aria-activedescendant` refers to an [accessibility
 descendant](#dfn-accessibility-descendant) of the controlled element. For
 example, in a
 [`combobox`](https://w3c.github.io/aria/#combobox),
 focus can remain on the
 [`combobox`](https://w3c.github.io/aria/#combobox)
 while the value of `aria-activedescendant` on the
 [`combobox`](https://w3c.github.io/aria/#combobox)
 element refers to a descendant of a popup
 [`listbox`](https://w3c.github.io/aria/#listbox)
 that is controlled by the
 [`combobox`](https://w3c.github.io/aria/#combobox).

Authors *SHOULD* also ensure that the currently active descendant is
visible and in view (or scrolls into view) when focused.

+-----------------------------------+-----------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=============================================================================+
| Related Concepts: | [[SVG]](https://www.w3.org/TR/SVG2/) |
| | \[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\] and [[DOM]](https://www.w3.org/TR/dom/) |
| | \[[DOM](#bib-dom "DOM Standard")\] active |
+-----------------------------------+-----------------------------------------------------------------------------+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`group`](https://w3c.github.io/aria/#group) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Inherits into Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`select`](https://w3c.github.io/aria/#select) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`tablist`](https://w3c.github.io/aria/#tablist) |
| | - [`toolbar`](https://w3c.github.io/aria/#toolbar) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Value: | [ID reference](#valuetype_idref) |
+-----------------------------------+-----------------------------------------------------------------------------+

: Characteristics:

#### [`aria-atomic` [property]]

[Indicates](#dfn-indicates) whether [assistive
technologies](#assistive-technology) will present all, or only parts of, the
changed region based on the change notifications defined by the
[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
attribute.

Both [accessibility [APIs]](#dfn-accessibility-api) and the [Document Object
Model](https://www.w3.org/TR/dom/)
\[[DOM](#bib-dom "DOM Standard")\] provide
events to allow the assistive technologies to determine changed areas of
the document.

When the content of a [live
region](#dfn-live-region) changes, user agents *SHOULD* examine the changed
[element](https://dom.spec.whatwg.org/#concept-element)
and traverse the ancestors to find the first element with
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
set, and apply the appropriate behavior for the cases below.

1. If none of the ancestors have explicitly set
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic),
 the default is that
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
 is `false`, and assistive technologies will only present the changed
 node to the user.
2. If
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
 is explicitly set to `false`, assistive technologies will stop
 searching up the ancestor chain and present only the changed node to
 the user.
3. If
 [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
 is explicitly set to `true`, assistive technologies will present the
 entire contents of the element, including the author-defined live
 region label if one exists.

When
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic)
is `true`, assistive technologies can choose to combine several changes
and present the entire changed region at once.

 Characteristic Value
 ---------------- -------------------------------------
 Used in Roles: All elements of the base markup
 Value: [true/false](#valuetype_true-false)

 : Characteristics:

 Value Description
 ------- -----------------------------------------------------------------------------------------------------------------------------
 false Assistive technologies will present only the changed node or nodes.
 true Assistive technologies will present the entire changed region as a whole, including the author-defined label if one exists.

 : Values:

#### [`aria-autocomplete` [property]]

[Indicates](#dfn-indicates) whether inputting text could trigger display of one or
more predictions of the user\'s intended value for a
[`combobox`](https://w3c.github.io/aria/#combobox),
[`searchbox`](https://w3c.github.io/aria/#searchbox),
or [`textbox`](https://w3c.github.io/aria/#textbox) and
specifies how predictions would be presented if they were made.

The `aria-autocomplete` property describes the type of interaction model
a [`textbox`](https://w3c.github.io/aria/#textbox),
[`searchbox`](https://w3c.github.io/aria/#searchbox),
or [`combobox`](https://w3c.github.io/aria/#combobox)
employs when dynamically helping users complete text input. It
distinguishes between two models: the inline model
(`aria-autocomplete="inline"`) that presents a value completion
prediction inside the text input and the list model
(`aria-autocomplete="list"`) that presents a collection of possible
values in a separate element that pops up adjacent to the text input. It
is possible for an input to offer both models at the same time
(`aria-autocomplete="both"`).

The `aria-autocomplete` property is limited to describing predictive
behaviors of an input element. Authors *SHOULD* either omit specifying a
value for `aria-autocomplete` or set `aria-autocomplete` to `none` if an
input element provides one or more input proposals where none of the
proposals are dependent on the specific input provided by the user. For
instance, a combobox where the value of `aria-autocomplete` would be
`none` is a search field that displays suggested values by listing the 5
most recently used search terms without any filtering of the list based
on the user\'s input. Elements with a role that supports
`aria-autocomplete` have a default value for `aria-autocomplete` of
`none`.

When an inline suggestion is made as a user types in an input, suggested
text for completing the value of the field dynamically appears in the
field after the input cursor, and the suggested value is accepted as the
value of the input if the user performs an action that causes focus to
leave the field. When an element has `aria-autocomplete` set to `inline`
or `both`, authors *SHOULD* ensure that the automatically suggested
portion of the text is presented as selected text. This enables
assistive technologies to distinguish between a user\'s input and the
automatic suggestion and, in the event that the suggestion is not the
desired value, enables the user to easily delete the suggestion or
replace it by continuing to type.

If an element has `aria-autocomplete` set to `list` or `both`, authors
*MUST* ensure both of the following conditions are met:

1. The element has a value specified for
 [`aria-controls`](https://w3c.github.io/aria/#aria-controls)
 that refers to the element that contains the collection of suggested
 values.
2. The element has a value for
 [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
 that matches the role of the element that contains the collection of
 suggested values.

Some implementations of the list model require the user to perform an
action, such as moving focus to the suggestion with the [Down
Arrow] or clicking on the suggestion, in order to choose the
suggestion. In such implementations, authors *MAY* manage focus by
either using
[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
if the collection container supports it or by moving [DOM] focus to the suggestion. However, other
implementations of the list model automatically highlight one suggestion
as the selected value that will be accepted when the field loses focus,
e.g., when the user presses the [Tab] key or clicks on a different
field. If an element has `aria-autocomplete` set to `list` or `both`,
and if a suggestion is automatically selected as the user provides
input, authors *MUST* ensure all the following conditions are met:

1. The collection of suggestions is presented in an element with a role
 that supports
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
2. The value of `aria-activedescendant` set on the input field is
 dynamically adjusted to refer to the element containing the selected
 suggestion as described in the definition of
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant).
3. [DOM] focus remains on the text
 input while the suggestions are displayed.

The `aria-autocomplete` property is not intended to indicate the
presence of a completion suggestion, and authors *SHOULD NOT*
dynamically change its value in order to communicate the presence of a
suggestion. When an element has `aria-autocomplete` set to `list` or
`both`, authors *SHOULD* use the
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
state to communicate whether the element that presents the suggestion
collection is displayed.

+-----------------------------------+-------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=========================================================================+
| Used in Roles: | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+-------------------------------------------------------------------------+
| Inherits into Roles: | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+-----------------------------------+-------------------------------------------------------------------------+
| Value: | [token](#valuetype_token) |
+-----------------------------------+-------------------------------------------------------------------------+

: Characteristics:

 Value Description
 -------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 inline When a user is providing input, text suggesting one way to complete the provided input might be dynamically inserted after the caret.
 list When a user is providing input, an element containing a collection of values that could complete the provided input might be displayed.
 both When a user is providing input, an element containing a collection of values that could complete the provided input might be displayed. If displayed, one value in the collection is automatically selected, and the text needed to complete the automatically selected value appears after the caret in the input.
 **none (default)** When a user is providing input, an automatic suggestion that attempts to predict how the user intends to complete the input is not displayed.

 : Values:

#### [`aria-braillelabel` [property]]

[Defines](#dfn-defines) a string value that labels the current element, which
is intended to be converted into Braille. See related
[`aria-label`](https://w3c.github.io/aria/#aria-label).

The purpose of
[`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
is similar to that of
[`aria-label`](https://w3c.github.io/aria/#aria-label).
It provides the user with a recognizable name of the object in Braille.

The
[`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
property gives authors the ability to override how assistive
technologies localize and express the accessible name of an element in
Braille. Thus inappropriately using
[`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
might inhibit users\' ability to understand an element on braille
interfaces. Authors *SHOULD* limit use of
[`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
to instances where the name of an element when converted to Braille is
not the desired user experience.

When using `aria-braillelabel`, authors *SHOULD* also ensure that:

1. The element to which `aria-braillelabel` is applied has a valid
 accessible name.
2. The value of `aria-braillelabel` is not empty or does not contain
 only
 [whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) characters.
3. The value of `aria-braillelabel` does not contain any characters in
 [Unicode Braille
 Patterns](#dfn-unicode-braille) or consists of only characters in
 [Unicode Braille
 Patterns](#dfn-unicode-braille); the value does not only contain
 Braille Pattern dots-0.
4. The value of `aria-braillelabel` is not identical to the element\'s
 accessible name.

Authors *MUST NOT* specify `aria-braillelabel` on an element which has
an explicit or implicit [WAI-ARIA] role where
`aria-braillelabel` is [prohibited](#prohibitedattributes).

Note that [Assistive
Technologies](#assistive-technology) with braille support can convert the
accessible name to Braille. In addition, assistive technologies will be
able to customize such braille output according to user preferences.
Using only the accessible name, e.g., from content or via `aria-label`
is **almost always** the better user experience and authors are
**strongly discouraged** from using `aria-braillelabel` to replicate
`aria-label`. Instead, `aria-braillelabel` is meant to be used only if
the accessible name cannot provide an adequate braille representation,
i.e., when a specialized braille description is very different from a
text description converted to Braille. It is very important to note that
when using `aria-braillelabel`, authors are solely responsible for
localizing the attribute value so that it aligns with the document
language. In addition, authors need to design a way to clearly
communicate the use of this attribute to the user. For example, this
could be done in the product documentation. This is even more important
when the value consists of Unicode Braille Patterns because [Assistive
Technologies](#assistive-technology) will pass such content directly to the
user without applying user specific braille translations; in general,
authors are **strongly discouraged** from using Unicode Braille Patterns
in `aria-braillelabel`.

[Assistive
technologies](#assistive-technology) *SHOULD* use the value of
`aria-braillelabel` when presenting the accessible name of an element in
Braille, but *SHOULD NOT* change other functionality. For example, an
assistive technology that provides aural rendering *SHOULD* use the
accessible name.

[Assistive
technologies](#assistive-technology) *SHOULD* expose the `aria-braillelabel`
property as follows:

1. If the value of `aria-braillelabel` does not contain characters in
 [Unicode Braille
 Patterns](#dfn-unicode-braille), translate the value according to the
 user\'s preferred translation table.
2. Otherwise, pass the value to the user without translation.

The following example shows the use of `aria-braillelabel` to customize
a button\'s name in braille output.

[Example 28](#example-28)

```
<button aria-braillelabel="****">
 <img a src="images/stars.jpg">
</button>
```

In the previous example, a braille display would display \"btn
\*\*\*\*\" in Braille rather than the verbose \"btn gra 4 stars\".

 Characteristic Value
 ---------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Used in Roles: All elements of the base markup except for the following roles: [`caption`](https://w3c.github.io/aria/#caption), [`code`](https://w3c.github.io/aria/#code), [`definition`](https://w3c.github.io/aria/#definition), [`deletion`](https://w3c.github.io/aria/#deletion), [`emphasis`](https://w3c.github.io/aria/#emphasis), [`generic`](https://w3c.github.io/aria/#generic), [`insertion`](https://w3c.github.io/aria/#insertion), [`mark`](https://w3c.github.io/aria/#mark), [`none`](https://w3c.github.io/aria/#none), [`paragraph`](https://w3c.github.io/aria/#paragraph), [`strong`](https://w3c.github.io/aria/#strong), [`subscript`](https://w3c.github.io/aria/#subscript), [`suggestion`](https://w3c.github.io/aria/#suggestion), [`superscript`](https://w3c.github.io/aria/#superscript), [`term`](https://w3c.github.io/aria/#term), [`time`](https://w3c.github.io/aria/#time)
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-brailleroledescription` [property]]

[Defines](#dfn-defines) a human-readable, author-localized abbreviated
description for the [role](#dfn-role) of an
[element](https://dom.spec.whatwg.org/#concept-element),
which is intended to be converted into Braille. See related
[`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription).

Some [assistive
technologies](#assistive-technology), such as screen readers, present the role
of an element as part of the user experience. Such assistive
technologies typically localize the name of the role, and they might
customize it as well. Users of these assistive technologies depend on
the presentation of the role name, such as \"region,\" \"button,\" or
\"slider,\" for an understanding of the purpose of the element and, if
it is a widget, how to interact with it.

The `aria-brailleroledescription` property gives authors the ability to
override how [assistive
technologies](#assistive-technology) localize and express the name of a role in
Braille. Thus inappropriately using `aria-brailleroledescription` might
inhibit users\' ability to understand or interact with an element on
braille interfaces. Authors *SHOULD* limit use of
`aria-brailleroledescription` to clarifying the purpose of
non-interactive container roles like
[`group`](https://w3c.github.io/aria/#group) or
[`region`](https://w3c.github.io/aria/#region), or to
providing a *more specific* description of a
[`widget`](https://w3c.github.io/aria/#widget) in a
braille context.

Authors *MUST NOT* use `aria-brailleroledescription` without providing
`aria-roledescription`. Additionally, as with `aria-roledescription`,
authors *MUST NOT* specify `aria-brailleroledescription` on an element
which has an explicit or implicit [WAI-ARIA] role where
`aria-brailleroledescription` is [prohibited](#prohibitedattributes).

In general, `aria-brailleroledescription` is only meant to be used in
rare cases when a `aria-roledescription` is excessively verbose when
rendered in Braille.

When using `aria-brailleroledescription`, authors *SHOULD* also ensure
that:

1. The element to which `aria-brailleroledescription` is applied has a
 valid [WAI-ARIA] role or has an
 implicit [WAI-ARIA] role semantic.
2. The value of `aria-brailleroledescription` is not empty or does not
 contain only
 [whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) characters.
3. The value of `aria-brailleroledescription` does not contain any
 characters in [Unicode Braille
 Patterns](#dfn-unicode-braille) or consists of only characters in
 [Unicode Braille
 Patterns](#dfn-unicode-braille); the value does not only contain
 Braille Pattern dots-0.
4. The value of `aria-brailleroledescription` should not be identical
 to the element\'s [WAI-ARIA]
 `aria-roledescription`, [WAI-ARIA] `role` or implicit
 [WAI-ARIA] role
 semantic.

Note that [Assistive
Technologies](#assistive-technology) with braille support can convert
`aria-roledescription` content to Braille. In addition, assistive
technologies will be able to customize such braille output according to
user preferences. Using only `aria-roledescription` is **almost always**
the better user experience and authors are **strongly discouraged** from
using `aria-brailleroledescription` to replicate `aria-roledescription`.
Instead, `aria-brailleroledescription` is meant to be used only when
`aria-roledescription` cannot provide an adequate braille
representation, i.e., when a specialized braille description is very
different from a text description converted to Braille. It is very
important to note that when using `aria-brailleroledescription`, authors
are solely responsible for localizing the attribute value so that it
aligns with the document language. In addition, authors need to design a
way to clearly communicate the use of this attribute to the user. For
example, this could be done in the product documentation. This is even
more important when the value consists of Unicode Braille Patterns
because [Assistive
Technologies](#assistive-technology) will pass such content directly to the
user without applying user specific braille translations; in general,
authors are **strongly discouraged** from using Unicode Braille Patterns
in `aria-brailleroledescription`.

User agents *MUST NOT* expose the `aria-brailleroledescription` property
if any of the following conditions exist:

1. The value of `aria-brailleroledescription` is empty or contains only
 whitespace characters, which includes standard
 [whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) and the empty Braille pattern: dots-0
 (U+2800).
2. The element to which `aria-brailleroledescription` is applied has an
 explicit or implicit [WAI-ARIA] role where
 `aria-brailleroledescription` is
 [prohibited](#prohibitedattributes).
3. The element to which `aria-brailleroledescription` is applied does
 not have a valid [WAI-ARIA]
 `aria-roledescription`.

[Assistive
technologies](#assistive-technology) *SHOULD* use the value of
`aria-brailleroledescription` when presenting the role of an element in
Braille, but *SHOULD NOT* change other functionality based on the role
of an element that has a value for `aria-brailleroledescription`. For
example, an assistive technology that provides functions for navigating
to the next
[`region`](https://w3c.github.io/aria/#region) or
[`button`](https://w3c.github.io/aria/#button) *SHOULD*
allow those functions to navigate to regions and buttons that have an
`aria-brailleroledescription`.

[Assistive
technologies](#assistive-technology) *SHOULD* expose the
`aria-brailleroledescription` property as follows:

1. If the value of `aria-brailleroledescription` does not contain
 characters in [Unicode Braille
 Patterns](#dfn-unicode-braille), translate the value according to the
 user\'s preferred translation table.
2. Otherwise, pass the value to the user without translation.

The following two examples show the use of `aria-brailleroledescription`
to abbreviate the role of a repeated non-interactive \"slide\" container
in a web-based presentation application.

[Example 29](#example-29)

```
<div aria-roledescription="slide" aria-brailleroledescription="sld" id="slide" aria-labelledby="slideheading">
<h1 id="slideheading">Quarterly Report</h1>
<!-- remaining slide contents -->
</div>
```

[Example 30](#example-30)

```
<article aria-roledescription="slide" aria-brailleroledescription="sld" id="slide" aria-labelledby="slideheading">
<h1 id="slideheading">Quarterly Report</h1>
<!-- remaining slide contents -->
</div>
```

In the previous examples, a braille screen reader user would read \"sld
Quarterly Report\" rather than the more verbose \"slide Quarterly
Report.\"

 Characteristic Value
 ---------------- -----------------------------------------------------------------------------------------------------------------------------------
 Used in Roles: All elements of the base markup except for the following roles: [`generic`](https://w3c.github.io/aria/#generic)
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-busy` [state]]

[Indicates](#dfn-indicates) an element is being modified and that assistive
technologies could wait until the modifications are complete before
exposing them to the user.

The default value of `aria-busy` is `false` for all elements. When
`aria-busy` is `true` for an element, assistive technologies can ignore
changes to content that is an [accessibility
descendant](#dfn-accessibility-descendant) that element and then process all changes
made during the busy period as a single, atomic update when `aria-busy`
becomes `false`.

If it is necessary to make multiple additions, modifications, or
removals within a container element that is already either partially or
fully rendered, authors *MAY* set `aria-busy` to `true` on the container
element before the first change, and then set it to `false` when the
last change is complete. For example, if multiple changes to a [live
region](#dfn-live-region) should be spoken as a single unit of speech, authors
*MAY* set `aria-busy` to `true` while the changes are being made and
then set it to `false` when the changes are complete and ready to be
spoken.

If an element with role
[`feed`](https://w3c.github.io/aria/#feed) is marked
busy, assistive technologies might defer rendering changes that occur
inside the `feed` with the exception of user-initiated changes that
occur inside the
[`article`](https://w3c.github.io/aria/#article) that
the user is reading during the busy period.

If changes to a rendered
[`widget`](https://w3c.github.io/aria/#widget) would
create a state where the
[`widget`](https://w3c.github.io/aria/#widget) is
modifying [Allowed Accessibility Child Roles](#mustContain) during
script execution, authors *MAY* set `aria-busy` to `true` on the
[`widget`](https://w3c.github.io/aria/#widget) during
the update process. For example, if a rendered tree grid required a set
of simultaneous updates to multiple discontiguous branches, an
alternative to replacing the complete tree element with a single update
would be to mark the tree busy while each of the branches are modified.

 Characteristic Value
 ---------------- -------------------------------------
 Used in Roles: All elements of the base markup
 Value: [true/false](#valuetype_true-false)

 : Characteristics:

 Value Description
 ---------------------- ------------------------------------------------
 **false (default)**: There are no expected updates for the element.
 true The element is being updated.

 : Values:

#### [`aria-checked` [state]]

[Indicates](#dfn-indicates) the current \"checked\"
[state](#dfn-state)
of checkboxes, radio buttons, and other
[widgets](#dfn-widget). See related
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
and
[`aria-selected`](https://w3c.github.io/aria/#aria-selected).

The
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
indicates whether the
[element](https://dom.spec.whatwg.org/#concept-element)
is checked (`true`), unchecked (`false`), or represents a group of other
elements that have a mixture of checked and unchecked values (`mixed`).
Most inputs only support values of `true` and `false`, but the `mixed`
value is supported by certain tri-state inputs such as a
[`checkbox`](https://w3c.github.io/aria/#checkbox) or
[`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox).

The `mixed` value is *not* supported on
[`radio`](https://w3c.github.io/aria/#radio),
[`menuitemradio`](https://w3c.github.io/aria/#menuitemradio),
[`switch`](https://w3c.github.io/aria/#switch) or any
element that inherits from these, and [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* treat a `mixed` value as equivalent to `false` for those
[roles](#dfn-role).

Examples using the `mixed` value of tri-state inputs are covered in the
[[ARIA] Authoring
Practices Guide](https://www.w3.org/WAI/ARIA/apg/).

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Used in Roles: | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`radio`](https://w3c.github.io/aria/#radio) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [tristate](#valuetype_tristate) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 ------------------------- ----------------------------------------------------------------------------
 false The element supports being checked but is not currently checked.
 mixed Indicates a mixed mode value for a tri-state checkbox or menuitemcheckbox.
 true The element is checked.
 **undefined** (default) The element does not support being checked.

 : Values:

#### [`aria-colcount` [property]]

[Defines](#dfn-defines) the total number of columns in a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex).

If all of the columns are present in the [DOM], it is not necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the total number of columns. However, if only a
portion of the columns is present in the [DOM] at a given moment, this attribute is
needed to provide an explicit indication of the number of columns in the
full table.

Authors *MUST* set the value of
[`aria-colcount`](https://w3c.github.io/aria/#aria-colcount)
to an integer equal to the number of columns in the full table. If the
total number of columns is unknown, authors *MUST* set the value of
[`aria-colcount`](https://w3c.github.io/aria/#aria-colcount)
to `-1` to indicate that the value should not be calculated by the user
agent.

The following example shows a grid with 16 columns, of which columns 2,
3, 4, and 9 are displayed to the user.

[Example 31](#example-31)

```
<div aria-colcount="16">
 <div >
 <div >
 <span aria-colindex="2">First Name</span>
 <span aria-colindex="3">Last Name</span>
 <span aria-colindex="4">Company</span>
 <span aria-colindex="9">Phone</span>
 </div>
 </div>
 <div >
 <div >
 <span aria-colindex="2">Fred</span>
 <span aria-colindex="3">Jackson</span>
 <span aria-colindex="4">Acme, Inc.</span>
 <span aria-colindex="9">555-1234</span>
 </div>
 <div >
 <span aria-colindex="2">Sara</span>
 <span aria-colindex="3">James</span>
 <span aria-colindex="4">Acme, Inc.</span>
 <span aria-colindex="9">555-1235</span>
 </div>
 …
 </div>
</div>
```

+-----------------------------------+-----------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================+
| Used in Roles: | - [`table`](https://w3c.github.io/aria/#table) |
+-----------------------------------+-----------------------------------------------------------------------+
| Inherits into Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-----------------------------------------------------------------------+

: Characteristics:

#### [`aria-colindex` [property]]

[Defines](#dfn-defines) an
[element\'s](https://dom.spec.whatwg.org/#concept-element) column index or position with respect to the total number
of columns within a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext),
[`aria-colcount`](https://w3c.github.io/aria/#aria-colcount),
and
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan).

If all of the columns are present in the [DOM], it is not necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the column index of each cell or
[`gridcell`](https://w3c.github.io/aria/#gridcell).
However, if only a portion of the columns is present in the [DOM] at a given moment, this attribute is
needed to provide an explicit indication of the column of each cell or
gridcell with respect to the full table.

Authors *MUST* set the value for
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
to an integer greater than or equal to 1, greater than the
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
value of any previous elements within the same row, and less than or
equal to the number of columns in the full table. For a cell or gridcell
which spans multiple columns, authors *MUST* set the value of
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
to the start of the span.

If the set of columns which is present in the [DOM] is contiguous, and if there are no cells
which span more than one row or column in that set, then authors *MAY*
place
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
on each row, setting the value to the index of the first column of the
set. Otherwise, authors *SHOULD* place
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
on all of the [accessibility
children](#dfn-accessibility-child) of each row.

The following example shows a grid with 16 columns, of which columns 2
through 5 are displayed to the user. Because the set of columns is
contiguous,
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
can be placed on each row.

[Example 32](#example-32)

```
<div aria-colcount="16">
 <div >
 <div aria-colindex="2">
 <span >First Name</span>
 <span >Last Name</span>
 <span >Company</span>
 <span >Address</span>
 </div>
 </div>
 <div >
 <div aria-colindex="2">
 <span >Fred</span>
 <span >Jackson</span>
 <span >Acme, Inc.</span>
 <span >123 Broad St.</span>
 </div>
 <div aria-colindex="2">
 <span >Sara</span>
 <span >James</span>
 <span >Acme, Inc.</span>
 <span >123 Broad St.</span>
 </div>
 …
 </div>
</div>
```

The following example shows a grid with 16 columns, of which columns 2
through 5 are displayed to the user. While the set of columns is
contiguous, some of the cells span multiple rows. As a result,
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
needs to be placed on all of the [accessibility
children](#dfn-accessibility-child) of each row.

[Example 33](#example-33)

```
<div aria-colcount="16">
 <div >
 <div >
 <span aria-colindex="2">First Name</span>
 <span aria-colindex="3">Last Name</span>
 <span aria-colindex="4">Company</span>
 <span aria-colindex="5">Address</span>
 </div>
 </div>
 <div >
 <div >
 <span aria-colindex="2">Fred</span>
 <span aria-colindex="3">Jackson</span>
 <span aria-colindex="4" aria-rowspan="2">Acme, Inc.</span>
 <span aria-colindex="5" aria-rowspan="2">123 Broad St.</span>
 </div>
 <div >
 <span aria-colindex="2">Sara</span>
 <span aria-colindex="3">James</span>
 </div>
 …
 </div>
</div>
```

The following example shows a grid with 16 columns, of which columns 2,
3, 4, and 9 are displayed to the user. Because the set of columns is
non-contiguous,
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
needs to be placed on all of the [accessibility
children](#dfn-accessibility-child) of each row.

[Example 34](#example-34)

```
<div aria-colcount="16">
 <div >
 <div >
 <span aria-colindex="2">First Name</span>
 <span aria-colindex="3">Last Name</span>
 <span aria-colindex="4">Company</span>
 <span aria-colindex="9">Phone</span>
 </div>
 </div>
 <div >
 <div >
 <span aria-colindex="2">Fred</span>
 <span aria-colindex="3">Jackson</span>
 <span aria-colindex="4">Acme, Inc.</span>
 <span aria-colindex="9">555-1234</span>
 </div>
 <div >
 <span aria-colindex="2">Sara</span>
 <span aria-colindex="3">James</span>
 <span aria-colindex="4">Acme, Inc.</span>
 <span aria-colindex="9">555-1235</span>
 </div>
 …
 </div>
</div>
```

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-colindextext` [property]]

[Defines](#dfn-defines) a human readable text alternative of
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex).
See related
[`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext).

Authors *SHOULD* only use `aria-colindextext` when the provided or
calculated value of
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
is not meaningful or does not reflect the displayed index, as is the
case with spreadsheets and chess boards.

Authors *SHOULD NOT* use `aria-colindextext` as a replacement for
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
because some assistive technologies rely upon the numeric column index
for the purpose of keeping track of the user\'s position or providing
alternative table navigation.

[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex),
`aria-colindextext` is not a supported property of
[`row`](https://w3c.github.io/aria/#row) because user
agents have no way to reliably calculate `aria-colindextext` for the
purpose of exposing its value on the
[`cell`](https://w3c.github.io/aria/#cell) or
[`gridcell`](https://w3c.github.io/aria/#gridcell).

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [string](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-colspan` [property]]

[Defines](#dfn-defines) the number of columns spanned by a cell or gridcell
within a [`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-colindex`](https://w3c.github.io/aria/#aria-colindex)
and
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan).

This
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is intended for cells and gridcells which are not contained in a native
table. When defining the column span of cells or gridcells in a native
table, authors *SHOULD* use the host language\'s attribute instead of
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan).
If
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)
is used on an element for which the host language provides an equivalent
attribute, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* ignore the value of
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)
and instead expose the value of the host language\'s attribute to
[assistive
technologies](#assistive-technology).

Authors *MUST* set the value of
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan)
to an integer greater than or equal to 1 and less than the value which
would cause the cell or gridcell to overlap the next cell or gridcell in
the same row.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-controls` [property]]

[Identifies](#dfn-identifies) the
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) whose contents or presence are controlled by the focused
element or composite widget. See related
[`aria-details`](https://w3c.github.io/aria/#aria-details)
and
[`aria-owns`](https://w3c.github.io/aria/#aria-owns).

The `aria-controls` property is for referencing elements that are
modified by the user interacting with the currently focused element or
composite widget. The presence of `aria-controls` enables [assistive
technologies](#assistive-technology) to programmatically associate the
currently focused element with the element or elements it controls. For
instance, it can be used to inform users that by interacting with the
controlling element they have revealed an element or elements that were
previously in the hidden state. Or, by interacting with an element, they
caused the selection or value of a controlled element to change.

Instance where an `aria-controls` association could be made:

- Interacting with a text field or editable combobox results in the
 display of a listbox popup. Upon entering text, the associated listbox
 is filtered, or the selected option changes to match the text value
 entered by the user.
- A tree view representing a table of contents where choosing a treeitem
 updates content of a neighboring document pane.
- A series of checkboxes can each control what commodity prices are
 tracked live in a table or graph.
- An interactive element reveals associated content when selected. For
 instance, selecting a tab control reveals its associated tab panel. Or
 checking a radio button reveals additional information or form
 controls related to the chosen radio button.
- Radio buttons allow for filtering to a listing of search results.

Additionally, the `aria-controls` property supports multiple ID
references. For example, a control can be used to highlight different
instances of spelling errors. A user agent *MAY* convey to a user that
there are a number of related controlled elements (the misspellings),
allow the user to navigate to the controlled elements in sequence, or
both.

 Characteristic Value
 ---------------- --------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [ID reference list](#valuetype_idref_list)

 : Characteristics:

#### [`aria-current` [state]]

[Indicates](#dfn-indicates) the
[element](https://dom.spec.whatwg.org/#concept-element)
that represents the current item within a container or set of related
elements.

The
[`aria-current`](https://w3c.github.io/aria/#aria-current)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is a token type. Any value not included in the list of allowed values
*SHOULD* be treated by [assistive
technologies](#assistive-technology) as if the value `true` had been provided.
If the attribute is not present or its value is the empty string or
`undefined`, the default value of `false` applies and the
[`aria-current`](https://w3c.github.io/aria/#aria-current)
[state](#dfn-state)
*MUST NOT* be exposed by user agents or assistive technologies.

The
[`aria-current`](https://w3c.github.io/aria/#aria-current)
attribute is used when an element within a set of related elements is
visually styled to indicate it is the current item in the set. For
example:

- A `page` token used to indicate a page within a set of pages, where
 the element is visually styled to represent the current page.
- A `step` token used to indicate a step within a step-based process,
 where the element is visually styled to represent the current step.
- A `location` token used to indicate the element that is visually
 styled as the current component, such as within a flow chart.
- A `date` token used to indicate the current date within a calendar or
 other date collection.
- A `time` token used to indicate the current time within a timetable or
 other time collection.

Authors *SHOULD* only mark one element in a set of elements as current
with
[`aria-current`](https://w3c.github.io/aria/#aria-current).

Authors *SHOULD NOT* use the
[`aria-current`](https://w3c.github.io/aria/#aria-current)
attribute as a substitute for
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
in widgets where
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
has the same meaning. For example, in a
[`tablist`](https://w3c.github.io/aria/#tablist),
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
is used on a [`tab`](https://w3c.github.io/aria/#tab)
to indicate the currently-displayed
[`tabpanel`](https://w3c.github.io/aria/#tabpanel).

In some use cases for widgets that support
[`aria-selected`](https://w3c.github.io/aria/#aria-selected),
current and selected can have different meanings and can both be used
within the same set of elements. For example, `aria-current="page"` can
be used in a navigation
[`tree`](https://w3c.github.io/aria/#tree) to indicate
which page is currently displayed, while `aria-selected="true"`
indicates which page will be displayed if the user activates the
[`treeitem`](https://w3c.github.io/aria/#treeitem).
Furthermore, the same tree can support operating on one or more selected
pages (treeitems) by way of a context menu containing options such as
\"delete\" and \"move.\"

 Characteristic Value
 ---------------- ---------------------------------
 Used in Roles: All elements of the base markup
 Value: [token](#valuetype_token)

 : Characteristics:

 Value Description
 --------------------- -------------------------------------------------------------------
 page Represents the current page within a set of pages.
 step Represents the current step within a process.
 location Represents the current location within an environment or context.
 date Represents the current date within a collection of dates.
 time Represents the current time within a set of times.
 true Represents the current item within a set.
 **false (default)** Does not represent the current item within a set.

 : Values:

#### [`aria-describedby` [property]]

[Identifies](#dfn-identifies) the
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) that describes the
[object](#dfn-object). See related
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
and
[`aria-description`](https://w3c.github.io/aria/#aria-description).

The
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute is similar to
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
in that both reference other elements to calculate a text alternative
(an accessible name, and description, respectively). While a concise
accessible name is preferable, a description can either be concise, or
provide more verbose information.

The element or elements referenced by the aria-describedby comprise the
entire description. Include ID references to multiple elements if
necessary, or enclose a set of elements (e.g., paragraphs) with the
element referenced by the ID.

+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=============================================================================================================+
| Related Concepts: | - `<`[`label`](https://html.spec.whatwg.org/multipage/forms.html#the-label-element)`>` |
| | in [HTML] |
| | - online help |
| | - [HTML] table cell headers |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Used in Roles: | All elements of the base markup |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+
| Value: | [ID reference list](#valuetype_idref_list) |
+-----------------------------------+-------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-description` [property]]

[Defines](#dfn-defines) a string value that describes or annotates the current
element. See related
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

The
[`aria-description`](https://w3c.github.io/aria/#aria-description)
attribute is similar to
[`aria-label`](https://w3c.github.io/aria/#aria-label)
in that both provide a flat string to associate with the element (an
accessible description, and name, respectively). Unlike an accessible
name, which is generally preferred to be concise, a description can
provide more verbose information, as necessary.

The purpose of
[`aria-description`](https://w3c.github.io/aria/#aria-description)
is the same as that of
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).
It provides the user with additional descriptive text for the object.
The most common [accessibility [API]](#dfn-accessibility-api) mapping for a description is the
[accessible
description](https://www.w3.org/TR/accname-1.2/#dfn-accessible-description) property. User agents *MUST* give precedence to
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
over
[`aria-description`](https://w3c.github.io/aria/#aria-description)
when computing the accessible description property.

In cases where providing a visible description is not the desired user
experience, authors *MAY* set the accessible description of the element
using
[`aria-description`](https://w3c.github.io/aria/#aria-description).
However, if the description text is available in the [DOM], authors *SHOULD NOT* use
[`aria-description`](https://w3c.github.io/aria/#aria-description),
but should use one of the following instead:

- Authors *SHOULD* use
 [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
 when the related description or annotation elements contain a simple,
 small description that is best experienced as a flat string, rather
 than by having the user navigate to them.
- Authors *SHOULD* use
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 when the related description or annotation elements contain useful
 semantics or structure, or there is a lot of content within them,
 making it difficult to experience as a flat string. Using
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 will allow assistive technology users to visit the structured content
 and provide additional navigation commands, making it easier to
 understand the structure, or to experience the information in smaller
 pieces.

 Characteristic Value
 ------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------
 Related Concepts: [`title`](https://html.spec.whatwg.org/multipage/dom.html#attr-title) attribute in [HTML]
 Used in Roles: All elements of the base markup
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-details` [property]]

[Identifies](#dfn-identifies) the
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) that provide additional information related to the
[object](#dfn-object). See related
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

The `aria-details` property is for referencing elements that provide
more detailed information than would normally be provided via
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).
The presence of `aria-details` enables [assistive
technologies](#assistive-technology) to make users aware of the availability of
extended information and navigate to it. Authors *SHOULD* ensure that
elements referenced by `aria-details` are visible to all users.

Assistive technologies can use the role of elements referenced by the
`aria-details` property to help users understand the types of
information associated with the element. Authors *MAY* convey the type
of details associated with an element as follows:

- Comment: `aria-details` refers to an element with role
 [`comment`](https://w3c.github.io/aria/#comment).
- Definition: `aria-details` is applied to an element with role
 [`term`](https://w3c.github.io/aria/#term) and refers
 to an element with role
 [`definition`](https://w3c.github.io/aria/#definition).
- Caption: `aria-details` is applied to an element with role
 [`figure`](https://w3c.github.io/aria/#figure) and
 refers to an element with role
 [`caption`](https://w3c.github.io/aria/#caption), or
 an element within a `caption`.
- Footnote: `aria-details` refers to an element with role
 `doc-footnote`. This role is defined in
 \[[DPUB-ARIA-1.0](#bib-dpub-aria-1.0 "Digital Publishing WAI-ARIA Module 1.0")\].
- Endnote: `aria-details` refers to an element with role `doc-endnote`.
 This role is defined in
 \[[DPUB-ARIA-1.0](#bib-dpub-aria-1.0 "Digital Publishing WAI-ARIA Module 1.0")\].
- Description or general annotation: `aria-details` refers to an element
 with any other role.

Unlike elements referenced by `aria-describedby`, elements referenced by
`aria-details` are not used in the Accessible Description Computation as
defined in the [Accessible Name and Description
Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\]. Thus, the content of elements referenced by
`aria-details` are not flattened to a string when presented to assistive
technology users. This makes `aria-details` particularly useful when
converting the information to a string would cause a loss of information
or make the extended information more difficult to understand.

The `aria-details` property supports referring to multiple elements. For
example, a paragraph in a document editor might reference multiple
comments that are not related to each other. If a user agent relies on
an accessibility [API]
that does not support exposing multiple descriptive relations, the user
agent *SHOULD* expose the relationship to the first element referenced
by `aria-details`.

It is valid for an element to have both `aria-details` and a description
specified with either `aria-describedby` or `aria-description`. If a
user agent relies on an accessibility [API] that does not support
exposing multiple descriptive relations, and if an element has both
`aria-details` and
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby),
the user agent *SHOULD* expose the `aria-details` relation and the
description string computed from the
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
relationship.

A common use for `aria-details` is in digital publishing where an
extended description needs to be conveyed in a book that requires
structural markup or the embedding of other technology to provide
illustrative content. The following example demonstrates this scenario.

[Example 35](#example-35)

```
<!-- Provision of an extended description -->
<img src="pythagorean.jpg" a aria-details="det">
<details id="det">
 <summary>Example</summary>
 <p>
 The Pythagorean Theorem is a relationship in Euclidean Geometry between the three sides of
 a right triangle, where the square of the hypotenuse is the sum of the squares of the two
 opposing sides.
 </p>
 <p>
 The following drawing illustrates an application of the Pythagorean Theorem when used to
 construct a skateboard ramp.
 </p>
 <object data="skatebd-ramp.svg" type="image/svg+xml"></object>
 <p>
 In this example you will notice a skateboard ramp with a base and vertical board whose width
 is the width of the ramp. To compute how long the ramp must be, simply calculate the
 base length, square it, sum it with the square of the height of the ramp, and take the
 square root of the sum.
 </p>
</details>
```

Alternatively, `aria-details` can refer to a link to a web page having
the extended description, as shown in the following example.

[Example 36](#example-36)

```
<!-- Provision of an extended description -->
<img src="pythagorean.jpg" a aria-details="det">
<p>
 See an <a href="https://example.com/pt.html" id="det">Application of the Pythagorean Theorem</a>.
</p>
```

 Characteristic Value
 ---------------- --------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [ID reference list](#valuetype_idref_list)

 : Characteristics:

#### [`aria-disabled` [state]]

[Indicates](#dfn-indicates) that the
[element](https://dom.spec.whatwg.org/#concept-element)
is [perceivable](#dfn-perceivable) but disabled, so it is not editable or
otherwise [operable](#dfn-operable). See related
[`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
and
[`aria-readonly`](https://w3c.github.io/aria/#aria-readonly).

For example, irrelevant options in a radio group can be disabled.
Disabled elements might not receive focus from the tab order. For some
disabled elements, applications might choose not to support navigation
to descendants. In addition to setting the
[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
attribute, authors *SHOULD* change the appearance (grayed out, etc.) to
indicate that the item has been disabled.

The [state](#dfn-state) of being disabled applies to the element with
aria-disabled and all
[focusable](#dfn-focusable) descendant elements of the element on which the
[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is applied.

[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
and proper scripting can successfully disable an element with role
[`link`](https://w3c.github.io/aria/#link), fully
disabling a host language equivalent can be problematic. Authors are
advised not to use
[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
on elements that cannot be disabled through features of the host
language alone.

Note[: Usage on columnheader, rowheader and row]

[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled)
is currently supported on
[`columnheader`](https://w3c.github.io/aria/#columnheader),
[`rowheader`](https://w3c.github.io/aria/#rowheader),
and [`row`](https://w3c.github.io/aria/#row), in a
future version the working group plans to prohibit its use on elements
with any of those three roles except when they are in the context of a
[`grid`](https://w3c.github.io/aria/#grid) or
[`treegrid`](https://w3c.github.io/aria/#treegrid).

This state is being deprecated as a global state in [ARIA] 1.2. In future versions
it will only be allowed on roles where it is specifically supported.

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`button`](https://w3c.github.io/aria/#button) |
| | - [`composite`](https://w3c.github.io/aria/#composite) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`group`](https://w3c.github.io/aria/#group) |
| | - [`input`](https://w3c.github.io/aria/#input) |
| | - [`link`](https://w3c.github.io/aria/#link) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`radio`](https://w3c.github.io/aria/#radio) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`select`](https://w3c.github.io/aria/#select) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`tablist`](https://w3c.github.io/aria/#tablist) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
| | - [`toolbar`](https://w3c.github.io/aria/#toolbar) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- -----------------------------------------------------------------------------------------------------
 **false (default)** The element is enabled.
 true The element and all focusable descendants are disabled and its value cannot be changed by the user.

 : Values:

#### [`aria-dropeffect` [property]]

\[Deprecated in [ARIA] 1.1\] Indicates what
functions can be performed when a dragged object is released on the drop
target.

The `aria-dropeffect` property is expected to be replaced by a new
feature in a future version of [WAI-ARIA]. Authors are therefore
advised to treat `aria-dropeffect` as
[deprecated](#dfn-deprecated).

This [property](#dfn-property) allows assistive technologies to convey the
possible drag options available to users, including whether a pop-up
menu of choices is provided by the application. Typically, drop effect
functions can only be provided once an object has been grabbed for a
drag operation as the drop effect functions available are dependent on
the object being dragged.

More than one drop effect can be supported for a given
[element](https://dom.spec.whatwg.org/#concept-element).
Therefore, the value of this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is a space-separated set of tokens indicating the possible effects, or
`none` if there is no supported operation. In addition to setting the
[`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
attribute, authors *SHOULD* show a visual indication of potential drop
targets.

 Characteristic Value
 ---------------- -------------------------------------
 Used in Roles: All elements of the base markup
 Value: [token list](#valuetype_token_list)

 : Characteristics:

 Value Description
 -------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 copy A duplicate of the source object will be dropped into the target.
 execute A function supported by the drop target is executed, using the drag source as an input.
 link A reference or shortcut to the dragged object will be created in the target object.
 move The source object will be removed from its current location and dropped into the target.
 **none (default)** No operation can be performed; effectively cancels the drag operation if an attempt is made to drop on this object. Ignored if combined with any other token value. e.g., \'none copy\' is equivalent to a \'copy\' value.
 popup There is a popup menu or dialog that allows the user to choose one of the drag operations (copy, move, link, execute) and any other drag functionality, such as cancel.

 : Values:

#### [`aria-errormessage` [property]]

[Identifies](#dfn-identifies) the
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) that provides an error message for an
[object](#dfn-object). See related
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
and
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

The `aria-errormessage` attribute references other elements that contain
error message text. Authors *MUST* use
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
in conjunction with `aria-errormessage`.

When the value of an object is not valid,
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
is set to `true`, which indicates that the message contained by elements
referenced by `aria-errormessage` is pertinent.

When an object is in a valid state, it has either
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
set to `false` or it does not have the
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
attribute. Authors *MAY* use `aria-errormessage` on an object that is
currently valid, but only if the elements referenced by
`aria-errormessage` are [hidden from all
users](#dfn-hide-from-all-users), because the message they
contain is not pertinent.

When `aria-errormessage` is pertinent, authors *MUST* ensure the content
is not [hidden from all
users](#dfn-hide-from-all-users) so users can navigate to and
examine the error message. Similarly, when `aria-errormessage` is not
pertinent, authors *MUST* either ensure the content is [hidden from all
users](#dfn-hide-from-all-users) or remove the
`aria-errormessage` attribute or its value.

User agents *MUST NOT* expose `aria-errormessage` for an object with an
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
value of `false`.

Authors *MAY* call attention to a new error message with a live region
by modifying inserting the error message into the contents of a
existing, rendered element with a [live region
role](#live_region_roles), such as
[`alert`](https://w3c.github.io/aria/#alert). A live
region notification is appropriate when an error message is displayed to
users after they have provided an invalid value.

A typical message describes what is wrong and informs users what is
required. For example, an error message might be, "Invalid time: the
time must be between 9:00 AM and 5:00 PM." The following example code
shows markup for an initial valid state and for a subsequent invalid
state. Note the changes to
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
on the text input [object](#dfn-object), and to
[`aria-live`](https://w3c.github.io/aria/#aria-live)
on the
[element](https://dom.spec.whatwg.org/#concept-element)
containing the text of the error message:

[Example 37](#example-37)

```
<!-- Initial valid state -->
<label for="startTime"> Please enter a start time for the meeting: </label>
<input id="startTime" type="text" aria-errormessage="msgID" value="" aria-invalid="false">
<span id="msgID" ></span>

<!-- User has input an invalid value -->
<label for="startTime"> Please enter a start time for the meeting: </label>
<input id="startTime" type="text" aria-errormessage="msgID" aria-invalid="true" value="11:30 PM" >
 <span id="msgID" >Invalid time: the time must be between 9:00 AM and 5:00 PM</span>
```

This example uses `` (which includes an implicit value of
`aria-live="assertive"`) to indicate that assistive technologies will
immediately announce the error message rather than completing other
queued announcements first. This increases the likelihood that users are
aware of the error message before they move focus out of the input.

This state has been deprecated as a global state in [ARIA] 1.2. It is only supported
on [live region roles](#live_region_roles).

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [ID reference list](#valuetype_idref_list) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-expanded` [state]]

[Indicates](#dfn-indicates) whether a related element is expanded (shown) or
collapsed (hidden).

The
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
attribute is applied to a
[focusable](#dfn-focusable), interactive element that toggles visibility of content
of a different element. If the element with
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
is also a
[`treeitem`](https://w3c.github.io/aria/#treeitem) in a
[`tree`](https://w3c.github.io/aria/#tree) or a
[`row`](https://w3c.github.io/aria/#row) in a
[`treegrid`](https://w3c.github.io/aria/#treegrid),
then the author *SHOULD* ensure the element is also the [accessibility
parent](#dfn-accessibility-parent) of the content it expands and collapses.
Otherwise, the author *SHOULD* ensure the element with
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
is not the [accessibility
parent](#dfn-accessibility-parent) of the content that is expanding or
collapsing. Rather, identify that relationship between the interactive
element and the element being controlled using
[`aria-controls`](https://w3c.github.io/aria/#aria-controls).

For example,
[`aria-expanded`](https://w3c.github.io/aria/#aria-expanded)
is applied to a parent
[`treeitem`](https://w3c.github.io/aria/#treeitem) to
indicate whether its child branch of the tree is shown.

[Example 38](#example-38)

```
<ul >
 <li aria-expanded="false" aria-selected="false">
 <span>Fruits</span>
 <ul hidden>
 <li aria-selected="false">Apricot</li>
 <li aria-selected="false">Mangosteen</li>
 <li aria-selected="false">Yuzu</li>
 </ul>
 </li>
</ul>
```

Similarly, it can be applied to a
[`button`](https://w3c.github.io/aria/#button) to
control the visibility of another element and its content on the current
page.

[Example 39](#example-39)

```
<button type="button" aria-controls="mangosteen" aria-expanded="false">Mangosteen</button>
<div id="mangosteen" hidden>
 An edible fruit native to tropical lands surrounding the Indian Ocean.
</div>
```

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`button`](https://w3c.github.io/aria/#button) |
| | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`link`](https://w3c.github.io/aria/#link) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [true/false/undefined](#valuetype_true-false-undefined) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 ------------------------- --------------------------------------------------------------------------------------------
 false The grouping element this element controls or is the accessibility parent of is collapsed.
 true The grouping element this element controls or is the accessibility parent of is expanded.
 **undefined (default)** The element does not own or control a grouping element that is expandable.

 : Values:

#### [`aria-flowto` [property]]

[Identifies](#dfn-identifies) the next
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) in an alternate reading order of content which, at the
user\'s discretion, allows assistive technology to override the general
default of reading in document source order.

When
[`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)
has a single ID reference, it allows [assistive
technologies](#assistive-technology) to, at the user\'s request, forego normal
document reading order and go to the targeted
[object](#dfn-object). However, when
[`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)
is provided with multiple ID references, assistive technologies *SHOULD*
present the referenced elements as path choices.

In the case of one or more ID references, [user
agents](https://infra.spec.whatwg.org/#user-agent) or
assistive technologies *SHOULD* give the user the option of navigating
to any of the targeted elements. The name of the path can be determined
by the name of the target element of the
[`aria-flowto`](https://w3c.github.io/aria/#aria-flowto)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).
[Accessibility [APIs]](#dfn-accessibility-api) can provide named path
[relationships](#dfn-relationship).

 Characteristic Value
 ---------------- --------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [ID reference list](#valuetype_idref_list)

 : Characteristics:

#### [`aria-grabbed` [state]]

\[Deprecated in [ARIA] 1.1\] Indicates an
element\'s \"grabbed\" [state](#dfn-state) in a drag-and-drop operation.

The `aria-grabbed` state is expected to be replaced by a new feature in
a future version of [WAI-ARIA]. Authors are therefore
advised to treat `aria-grabbed` as
[deprecated](#dfn-deprecated).

Setting `aria-grabbed` to `true` indicates that the
[element](https://dom.spec.whatwg.org/#concept-element)
has been selected for dragging. Setting `aria-grabbed` to `false`
indicates that the element can be grabbed for a drag-and-drop operation,
but is not currently grabbed. If `aria-grabbed` is unspecified or set to
`undefined` (default), the element cannot be grabbed.

When
[`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed)
is set to `true`, authors *SHOULD* update the
[`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
of all potential drop targets. When an element is not grabbed (the value
is set to `false` or `undefined`, or the attribute is removed), authors
*SHOULD* revert the
[`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
attributes of the associated drop targets to `none`.

 Characteristic Value
 ---------------- ---------------------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [true/false/undefined](#valuetype_true-false-undefined)

 : Characteristics:

 Value Description
 ------------------------- ---------------------------------------------------------------
 false Indicates that the element supports being dragged.
 true Indicates that the element has been \"grabbed\" for dragging.
 **undefined (default)** Indicates that the element does not support being dragged.

 : Values:

#### [`aria-haspopup` [property]]

[Indicates](#dfn-indicates) the availability and type of interactive popup element,
such as menu or dialog, that can be triggered by an
[element](https://dom.spec.whatwg.org/#concept-element).

A popup element usually appears as a block of content that is on top of
other content. Authors *MUST* ensure that the role of the element that
serves as the container for the popup content is
[`menu`](https://w3c.github.io/aria/#menu),
[`listbox`](https://w3c.github.io/aria/#listbox),
[`tree`](https://w3c.github.io/aria/#tree),
[`grid`](https://w3c.github.io/aria/#grid), or
[`dialog`](https://w3c.github.io/aria/#dialog), and
that the value of `aria-haspopup` matches the role of the popup
container.

For the popup element to be keyboard accessible, authors *SHOULD* ensure
that the element that can trigger the popup is
[focusable](#dfn-focusable), that there is a keyboard mechanism for opening the
popup, and that the popup element manages focus of all its descendants
as described in [Managing Focus](#managingfocus).

The `aria-haspopup` property is a token type. [User
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* treat any value of `aria-haspopup` that is not included in the
list of allowed values, including the empty string, as if the value
`false` had been provided. To provide backward compatibility with
[ARIA] 1.0 content,
user agents *MUST* treat an `aria-haspopup` value of `true` as
equivalent to a value of `menu`.

[Assistive
technologies](#assistive-technology) and user agents *SHOULD NOT* expose the
`aria-haspopup` property if it has a value of `false`.

A [`tooltip`](https://w3c.github.io/aria/#tooltip) is
not considered to be a popup in this context.

`aria-haspopup` is most relevant to use when there is a visual indicator
in the element that triggers the popup. For example, many controls
styled with a downward pointing triangle, chevron, or ellipsis (three
consecutive dots) have become standard visual indicators that a popup
will display when the control is activated. If some functional
difference is relevant to display to a sighted user by means of a
different visual style, that functional difference is usually relevant
to convey to users of assistive technology. If there is no visual
indication that an element will trigger a popup, authors are advised to
consider whether use of `aria-haspopup` is necessary, and avoid using it
when it\'s not.

This property is being deprecated as a global property in [ARIA] 1.2. In future versions
it will only be allowed on roles where it is specifically supported.

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Related Concepts: | [`aria-controls`](https://w3c.github.io/aria/#aria-controls) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`button`](https://w3c.github.io/aria/#button) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`link`](https://w3c.github.io/aria/#link) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [token](#valuetype_token) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- ---------------------------------------------------------------------------------------------
 **false (default)** Indicates the element does not have a popup.
 true Indicates the popup is a [`menu`](https://w3c.github.io/aria/#menu).
 menu Indicates the popup is a [`menu`](https://w3c.github.io/aria/#menu).
 listbox Indicates the popup is a [`listbox`](https://w3c.github.io/aria/#listbox).
 tree Indicates the popup is a [`tree`](https://w3c.github.io/aria/#tree).
 grid Indicates the popup is a [`grid`](https://w3c.github.io/aria/#grid).
 dialog Indicates the popup is a [`dialog`](https://w3c.github.io/aria/#dialog).

 : Values:

#### [`aria-hidden` [state]]

[Indicates](#dfn-indicates), when set to `true`, that an
[element](https://dom.spec.whatwg.org/#concept-element)
and its entire subtree are hidden from assistive technology, regardless
of whether it is visibly rendered.

User agents determine an element\'s
[hidden](#dfn-hidden) status based on whether it is rendered, and
the rendering is usually controlled by [CSS]. For example, an element whose `display`
property is set to `none` is not rendered. An element will be [excluded
from the accessibility tree](#tree_exclusion) if it or any of its
[accessibility ancestors](#tree_relationships) are
[hidden](#dfn-hidden) or have their `aria-hidden` attribute value
set to `true`.

Authors *MUST NOT* use `aria-hidden` to hide the root element or the
host language element that
[represents](https://html.spec.whatwg.org/multipage/dom.html#represents)
or contains the contents of the primary document in view. For instance,
the `html` or `body` elements in an [HTML] document. Authors *MAY*, with
caution, use `aria-hidden` to hide visibly rendered content from
assistive technologies *only* if the act of hiding this content is
intended to improve the experience for users of assistive technologies
by removing redundant or extraneous content. Authors using `aria-hidden`
to hide visible content from screen readers *MUST* ensure that identical
or equivalent meaning and functionality is exposed to assistive
technologies.

Authors are advised to use extreme caution and consider a wide range of
disabilities when hiding visibly rendered content from assistive
technologies. For example, a sighted, dexterity-impaired individual
might use voice-controlled assistive technologies to access a visual
interface. If an author hides visible link text \"Go to checkout\" and
exposes similar, yet non-identical link text \"Check out now\" to the
accessibility [API],
the user might be unable to access the interface they perceive using
voice control software. Similar problems can also arise for screen
reader users. For example, a sighted telephone support technician might
attempt to have the blind screen reader user click the \"Go to
checkout\" link, which they might be unable to find using a type-ahead
item search (\"Go to...\"), since that text would have been hidden by
the use of the attribute.

As of [ARIA] 1.3,
[`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)`="false"`
is now synonymous with `aria-hidden="undefined"`.

The original intent for `aria-hidden="false"` was to allow user agents
to expose content that was otherwise hidden from the accessibility tree.
However, due to ambiguity in the specification and inconsistent browser
support for the `false` value, the original intent is no longer
supported.

To prevent authors erroneously hiding entire window-rendered documents
only to those using assistive technology, user agents *MUST NOT* expose
the hidden state to assistive technologies if it is specified on the
root element or the host language element that
[represents](https://html.spec.whatwg.org/multipage/dom.html#represents)
or contains the contents of the primary document in view. For instance,
the `html` or `body` elements in an [HTML] document, or the root `svg` element
if it is rendered as its own primary document in the browser window. If
authors were to specify `aria-hidden="true"` on the opening tag for an
embedded document, for instance on a `math` or `svg` embedded within an
[HTML] document, user agents
would still be expected to hide these elements from assistive
technologies.

 Characteristic Value
 ---------------- ---------------------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [true/false/undefined](#valuetype_true-false-undefined)

 : Characteristics:

 Value Description
 ------------------------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 false The element\'s [hidden](#dfn-hidden) state is determined by the user agent based on whether it is rendered. Synonym of `undefined`.
 true The element is [hidden](#dfn-hidden) from the accessibility [API].
 **undefined (default)** The element\'s [hidden](#dfn-hidden) state is determined by the user agent based on whether it is rendered.

 : Values:

#### [`aria-invalid` [state]]

[Indicates](#dfn-indicates) the entered value does not conform to the format
expected by the application. See related
[`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage).

If the value is computed to be invalid or out-of-range, the author
*SHOULD* set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
to `true`. [user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* inform the user of the error. Authors *SHOULD* provide
suggestions for corrections if they are known.

When the user attempts to submit data involving a field for which
[`aria-required`](https://w3c.github.io/aria/#aria-required)
is `true`, authors *MAY* use the
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
attribute to signal there is an error. However, if the user has not
attempted to submit the form, authors *SHOULD NOT* set the
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
attribute on required [widgets](#dfn-widget) simply because the user has not yet
entered data.

For future expansion, the
[`aria-invalid`](https://w3c.github.io/aria/#aria-invalid)
attribute is a token type. Any value not recognized in the list of
allowed values *MUST* be treated by user agents as if the value `true`
had been provided. If the attribute is not present, or its value is
`false`, or its value is the empty string, the default value of `false`
applies.

This state is being deprecated as a global state in [ARIA] 1.2. In future versions
it will only be allowed on roles where it is specifically supported.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`application`](https://w3c.github.io/aria/#application) |
| | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [token](#valuetype_token) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- ------------------------------------------------------
 grammar A grammatical error was detected.
 **false (default)** There are no detected errors in the value.
 spelling A spelling error was detected.
 true The value entered by the user has failed validation.

 : Values:

#### [`aria-keyshortcuts` [property]]

[Defines](#dfn-defines) keyboard shortcuts that an author has implemented to
activate or give focus to an element.

The value of the `aria-keyshortcuts` attribute is a space-separated list
of keyboard shortcuts that can be pressed to activate a command or
textbox widget. The keys defined in the shortcuts represent the physical
keys pressed and not the actual characters generated. Each keyboard
shortcut consists of one or more tokens delimited by the plus sign
(\"+\") representing zero or more modifier keys and exactly one
non-modifier key that must be pressed simultaneously to activate the
given shortcut.

Authors *MUST* specify modifier keys exactly according to the
[[UI] Events KeyboardEvent key
Values](https://www.w3.org/TR/uievents-key/) spec
\[[uievents-key](#bib-uievents-key "UI Events KeyboardEvent key Values")\] - for example, \"Alt\", \"Control\", \"Shift\",
\"Meta\", or \"AltGraph\". Note that Meta corresponds to the Command
key, and Alt to the Option key, on Apple computers.

The valid names for non-modifier keys are any printable character such
as \"A\", \"B\", \"1\", \"2\", \"\$\", \"Plus\" for a plus sign,
\"Space\" for the spacebar, or the names of any other non-modifier key
specified in the [[UI] Events
KeyboardEvent key Values](https://www.w3.org/TR/uievents-key/) spec
\[[uievents-key](#bib-uievents-key "UI Events KeyboardEvent key Values")\] - for example, \"Enter\", \"Tab\", \"ArrowRight\",
\"PageDown\", \"Escape\", or \"F1\". The use of \"Space\" for the
spacebar is an exception to the [[UI]
Events KeyboardEvent key Values](https://www.w3.org/TR/uievents-key/)
spec
\[[uievents-key](#bib-uievents-key "UI Events KeyboardEvent key Values")\] as the space or spacebar key is encoded as `' '`
and would be treated as a whitespace character.

Authors *MUST* ensure modifier keys come first when they are part of a
keyboard shortcut. Authors *MUST* ensure that required non-modifier keys
come last when they are part of a shortcut. The order of the modifier
keys is not otherwise significant, so \"Alt+Shift+T\" and
\"Shift+Alt+T\" are equivalent, but \"T+Shift+Alt\" is not valid because
all of the modifier keys don\'t come first, and \"Alt\" is not valid
because it doesn\'t include at least one non-modifier key.

When specifying an alphabetic key, both the uppercase and lowercase
variants are considered equivalent: \"a\" and \"A\" are the same.

When implementing keyboard shortcuts authors should consider the
keyboards they intend to support to avoid unintended results. Keyboard
designs vary significantly based on the device used and the languages
supported. For example, many modifier keys are used in conjunction with
other keys to create common punctuation symbols, create number
characters, swap keyboard sides on bilingual keyboards to switch
languages, and perform a number of other functions.

For many supported keyboards, authors can prevent conflicts by avoiding
keys other than ASCII letters, as number characters and common
punctuation often require modifiers. Here, the keyboard shortcut entered
does not equate to the key generated. For example, in French keyboard
layouts, the number characters are not available until you press the
Shift key, so a keyboard shortcut defined as \"Shift+2\" would be
ambiguous as this is how one would type the \"2\" character on a French
keyboard.

If the character used is determined by a modifier key, the author *MUST*
specify the actual key used to generate the character, that is generated
by the key, and not the resulting character. This convention enables the
assistive technology to accurately convey what keys must be used to
generate the shortcut. For example, on most U.S. English keyboards, the
percent sign \"%\" can be input by pressing Shift+5. The correct way to
specify this shortcut is \"Shift+5\". It is incorrect to specify \"%\"
or \"Shift+%\". However, note that on some international keyboards the
percent sign might be an unmodified key, in which case \"%\" and
\"Shift+%\" could be correct on those keyboards.

If the key that needs to be specified is illegal in the host language or
would cause a string to be terminated, authors *MUST* use the string
escaping sequence of the host language to specify it. For example, the
single-quote character can be encoded as \"&#39;\" in [HTML].

Examples of valid keyboard shortcuts include:

- \"A\"
- \"Shift+Space\"
- \"Control+Alt+.\"
- \"Control+Shift+&#39;\"
- \"Alt+Shift+P Control+F\"
- \"Meta+C Meta+Shift+C\"

User agents *MUST NOT* change keyboard behavior in response to the
`aria-keyshortcuts` attribute. Authors *MUST* handle scripted keyboard
events to process `aria-keyshortcuts`. The `aria-keyshortcuts` attribute
exposes the existence of these shortcuts so that assistive technologies
can communicate this information to users.

Authors *SHOULD* provide a way to expose keyboard shortcuts so that all
users can discover them, such as through the use of a tooltip. Authors
*MUST* ensure that `aria-keyshortcuts` applied to disabled elements are
unavailable.

Authors *SHOULD* avoid implementing shortcut keys that inhibit operating
system, user agent, or assistive technology functionality. This requires
the author to carefully consider both which keys to assign and the
contexts and conditions in which the keys are available to the user. For
guidance, see the keyboard shortcuts section of the [[ARIA] Authoring Practices
Guide](https://www.w3.org/WAI/ARIA/apg/).

Authors *SHOULD* consider whether the keyboard shortcut will be valid in
each language and physical keyboard layout, and consider localizing the
shortcut in languages, locales, and common hardware keyboard
configurations.

 Characteristic Value
 ------------------- ----------------------------------------------------------------------
 Related Concepts: [Keyboard shortcut](https://en.wikipedia.org/wiki/Keyboard_shortcut)
 Used in Roles: All elements of the base markup
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-label` [property]]

[Defines](#dfn-defines) a string value that labels the current element. See
related
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby).

The purpose of
[`aria-label`](https://w3c.github.io/aria/#aria-label)
is the same as that of
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby).
It provides the user with a recognizable name of the object. The most
common [accessibility [API]](#dfn-accessibility-api) mapping for a label is the [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name) property.

Most host languages provide an attribute that could be used to name the
element (e.g., the
[`title`](https://html.spec.whatwg.org/multipage/dom.html#attr-title)
attribute in [HTML]), yet this
could present a browser tooltip. In the cases where [DOM] content or a tooltip is undesirable,
authors *MAY* set the accessible name of the element using
[`aria-label`](https://w3c.github.io/aria/#aria-label),
if the element does not [prohibit](#prohibitedattributes) use of the
attribute. If the label text is available in the [DOM] (i.e., typically visible text content),
authors *SHOULD* use
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
and *SHOULD NOT* use
[`aria-label`](https://w3c.github.io/aria/#aria-label).
There might be instances where the name of an element cannot be
determined programmatically from the [DOM], and there are cases where referencing
[DOM] content is not the desired
user experience. Authors *MUST NOT* specify `aria-label` on an element
which has an explicit or implicit [WAI-ARIA] role where `aria-label` is
[prohibited](#prohibitedattributes). As required by the [Accessible Name
and Description Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\], user agents give precedence to
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
over
[`aria-label`](https://w3c.github.io/aria/#aria-label)
when computing the accessible name property.

 Characteristic Value
 ---------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Used in Roles: All elements of the base markup except for the following roles: [`caption`](https://w3c.github.io/aria/#caption), [`code`](https://w3c.github.io/aria/#code), [`definition`](https://w3c.github.io/aria/#definition), [`deletion`](https://w3c.github.io/aria/#deletion), [`emphasis`](https://w3c.github.io/aria/#emphasis), [`generic`](https://w3c.github.io/aria/#generic), [`insertion`](https://w3c.github.io/aria/#insertion), [`mark`](https://w3c.github.io/aria/#mark), [`none`](https://w3c.github.io/aria/#none), [`paragraph`](https://w3c.github.io/aria/#paragraph), [`strong`](https://w3c.github.io/aria/#strong), [`subscript`](https://w3c.github.io/aria/#subscript), [`suggestion`](https://w3c.github.io/aria/#suggestion), [`superscript`](https://w3c.github.io/aria/#superscript), [`term`](https://w3c.github.io/aria/#term), [`time`](https://w3c.github.io/aria/#time)
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-labelledby` [property]]

[Identifies](#dfn-identifies) the
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) that labels the current element. See related
[`aria-label`](https://w3c.github.io/aria/#aria-label)
and
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby).

The purpose of
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
is the same as that of
[`aria-label`](https://w3c.github.io/aria/#aria-label).
It provides the user with a recognizable name of the object. The most
common [accessibility [API]](#dfn-accessibility-api) mapping for a label is the [accessible
name](https://www.w3.org/TR/accname-1.2/#dfn-accessible-name) property.

If the interface is such that it is not possible to have a visible label
on the screen, authors *SHOULD* use
[`aria-label`](https://w3c.github.io/aria/#aria-label)
and *SHOULD NOT* use
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby).
Authors *MUST NOT* specify `aria-labelledby` on an element which has an
explicit or implicit [WAI-ARIA] role where
`aria-labelledby` is [prohibited](#prohibitedattributes). As required by
the [Accessible Name and Description
Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\], user agents give precedence to
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
over
[`aria-label`](https://w3c.github.io/aria/#aria-label)
when computing the accessible name property.

The
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
attribute is similar to
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
in that both reference other elements to calculate a text alternative
(an accessible name, and description, respectively). While a concise
accessible name is preferable, a description can either be concise, or
provide more verbose information.

The expected spelling of this property in [U.S.] English is \"labeledby.\" However, the
[accessibility [API]](#dfn-accessibility-api) features to which this property is mapped
have established the \"labelledby\" spelling. This property is spelled
that way to match the convention and minimize the difficulty for
developers.

 Characteristic Value
 ------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Related Concepts: `<`[`label`](https://html.spec.whatwg.org/multipage/forms.html#the-label-element)`>` in [HTML]
 Used in Roles: All elements of the base markup except for the following roles: [`caption`](https://w3c.github.io/aria/#caption), [`code`](https://w3c.github.io/aria/#code), [`definition`](https://w3c.github.io/aria/#definition), [`deletion`](https://w3c.github.io/aria/#deletion), [`emphasis`](https://w3c.github.io/aria/#emphasis), [`generic`](https://w3c.github.io/aria/#generic), [`insertion`](https://w3c.github.io/aria/#insertion), [`mark`](https://w3c.github.io/aria/#mark), [`none`](https://w3c.github.io/aria/#none), [`paragraph`](https://w3c.github.io/aria/#paragraph), [`strong`](https://w3c.github.io/aria/#strong), [`subscript`](https://w3c.github.io/aria/#subscript), [`suggestion`](https://w3c.github.io/aria/#suggestion), [`superscript`](https://w3c.github.io/aria/#superscript), [`term`](https://w3c.github.io/aria/#term), [`time`](https://w3c.github.io/aria/#time)
 Value: [ID reference list](#valuetype_idref_list)

 : Characteristics:

#### [`aria-level` [property]]

[Defines](#dfn-defines) the hierarchical level of an
[element](https://dom.spec.whatwg.org/#concept-element)
within a structure.

This can be applied inside trees to tree items, to headings inside a
document, to nested grids, nested tablists and to other structural items
that might appear inside a container or participate in an ownership
hierarchy. The value for
[`aria-level`](https://w3c.github.io/aria/#aria-level)
is an integer greater than or equal to 1.

Levels increase with depth. If the [DOM] ancestry does not accurately represent
the level, authors *SHOULD* explicitly define the
[`aria-level`](https://w3c.github.io/aria/#aria-level)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).

This attribute is applied to elements that act as leaf nodes within the
orientation of the set, for example, on elements with role
[`treeitem`](https://w3c.github.io/aria/#treeitem)
rather than elements with role
[`group`](https://w3c.github.io/aria/#group). This
means that multiple elements in a set can have the same value for this
attribute. Although it would be less repetitive to provide a single
value on the container, restricting this to leaf nodes ensures that
there is a single way for [assistive
technologies](#assistive-technology) to use the attribute.

If the [DOM] ancestry accurately
represents the level, the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
calculate the level of an item from the document structure. This
attribute can be used to provide an explicit indication of the level
when that is not possible to calculate from the document structure or
the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
attribute. User agent support for automatic calculation of level might
vary; authors *SHOULD* test with [user
agents](https://infra.spec.whatwg.org/#user-agent) and
assistive technologies to determine whether this attribute is needed. If
the author intends for the user agent to calculate the level, the author
*SHOULD* omit this attribute.

In the case of a
[`treegrid`](https://w3c.github.io/aria/#treegrid),
[`aria-level`](https://w3c.github.io/aria/#aria-level)
is supported on elements with the role
[`row`](https://w3c.github.io/aria/#row), not elements
with role
[`gridcell`](https://w3c.github.io/aria/#gridcell). At
first glance, this might seem inconsistent with the application of
[`aria-level`](https://w3c.github.io/aria/#aria-level)
on [`treeitem`](https://w3c.github.io/aria/#treeitem)
elements, but it is consistent in that the
[`row`](https://w3c.github.io/aria/#row) acts as the
leaf node within the vertical orientation of the
[`grid`](https://w3c.github.io/aria/#grid), whereas the
[`gridcell`](https://w3c.github.io/aria/#gridcell) is a
leaf node within the horizontal orientation of each
[`row`](https://w3c.github.io/aria/#row). Level is not
supported on sets of cells within rows, so the
[`aria-level`](https://w3c.github.io/aria/#aria-level)
attribute is applied to the element with the role
[`row`](https://w3c.github.io/aria/#row).

On elements with role
[`heading`](https://w3c.github.io/aria/#heading),
values for
[`aria-level`](https://w3c.github.io/aria/#aria-level)
above 6 can create difficulties for users. Also, at the time of this
writing, most combinations of user agents and assistive technologies
only support
[`aria-level`](https://w3c.github.io/aria/#aria-level)
integers 1-9 on headings.

+-----------------------------------+-----------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================+
| Used in Roles: | - [`comment`](https://w3c.github.io/aria/#comment) |
| | - [`heading`](https://w3c.github.io/aria/#heading) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+-----------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-----------------------------------------------------------------------+

: Characteristics:

#### [`aria-live` [property]]

[Indicates](#dfn-indicates) that an
[element](https://dom.spec.whatwg.org/#concept-element)
will be updated or modified, and defines the priority of updates the
[user
agents](https://infra.spec.whatwg.org/#user-agent),
[assistive
technologies](#assistive-technology), and user can expect from the [live
region](#dfn-live-region).

The values of this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
are expressed in degrees of importance. When regions are specified as
`polite`, assistive technologies will notify users of updates but
generally do not interrupt the current task, and updates take low
priority. When regions are specified as `assertive`, assistive
technologies will immediately notify the user of relevant modifications
to the live region, and could potentially clear the speech queue of
previous updates.

Priority levels (`none`, `polite`, `assertive`) act as an ordering
mechanism for updates and serve as a recommendation to user agents or
assistive technologies. The value can be overridden by user agents,
assistive technologies, or the user. For example, if assistive
technologies can determine that a change occurred in response to a key
press or a mouse click, the assistive technologies might present that
change immediately even if the value of the
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attribute states otherwise.

Since different users have different needs, it is up to the user to
tweak their assistive technologies\' response to a live region.
Assistive technologies might choose to implement increasing and
decreasing levels of granularity so that the user can exercise control
over queues and interruptions.

When the [property](#dfn-property) is not set on an
[object](#dfn-object) that needs to send updates, the priority level is the
value of the nearest ancestor that sets the
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attribute.

The
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attribute is the primary determination for the order of presentation of
changes to live regions. Implementations will also consider the default
level of priority in a [role](#dfn-role) when the
[`aria-live`](https://w3c.github.io/aria/#aria-live)
attribute is not set in the ancestor chain (e.g.,
[`log`](https://w3c.github.io/aria/#log) changes are
`polite` by default). Modifications to live regions which are
`assertive` will be presented immediately, followed by `polite` items.
User agents or assistive technologies can choose to clear queued changes
when an assertive change occurs. (e.g., changes in an assertive region
can remove all currently queued changes)

When live regions are marked as `polite`, assistive technologies
*SHOULD* announce updates at the next graceful opportunity, such as at
the end of speaking the current sentence or when the user pauses typing.
When live regions are marked as `assertive`, assistive technologies
*SHOULD* immediately notify the user of modifications to the live
region. Because an interruption might disorient users or cause them to
not complete their current task, authors *SHOULD NOT* use the
`assertive` value unless the interruption is imperative.

Typically, assistive technology will only convey *changes* to a live
region, not the initial contents of a live region. To ensure content in
a live region is announced, authors *SHOULD* create a rendered but empty
live region as early as possible (such as on page load), and then modify
the content of the live region when the author expects changes to be
spoken or brailled. The exception to this live region convention is
`alert`, due to system accessibility notifications events required for
the role. While an
[`alert`](https://w3c.github.io/aria/#alert) is a live
region, its content is announced by assistive technology when the alert
is rendered on the page and when the content changes.

 Characteristic Value
 ---------------- ---------------------------------
 Used in Roles: All elements of the base markup
 Value: [token](#valuetype_token)

 : Characteristics:

 Value Description
 ------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 assertive Indicates that updates to the region have the highest priority and should be presented the user immediately.
 **off (default)** Indicates that updates to the region should not be presented to the user unless the user is currently focused on that region.
 polite Indicates that updates to the region should be presented at the next graceful opportunity, such as at the end of speaking the current sentence or when the user pauses typing.

 : Values:

#### [`aria-modal` [property]]

[Indicates](#dfn-indicates) whether an
[element](https://dom.spec.whatwg.org/#concept-element)
is modal when displayed.

The
[`aria-modal`](https://w3c.github.io/aria/#aria-modal)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is used to indicate that the presence of a \"modal\" element precludes
usage of other content on the page. For example, when a modal dialog is
displayed, it is expected that the user\'s interaction is limited to the
contents of the dialog, until the modal dialog loses focus or is no
longer displayed.

When a modal element is displayed, assistive technologies *SHOULD*
navigate to the element unless focus has explicitly been set elsewhere.
Some assistive technologies limit navigation to the modal element\'s
contents. If focus moves to an element outside the modal element,
assistive technologies *SHOULD NOT* limit navigation to the modal
element.

When a modal element is displayed, authors *MUST* ensure the interface
can be controlled using only descendants of the modal element. In other
words, if a modal dialog has a close button, the button should be a
descendant of the dialog. When a modal element is displayed, authors
*SHOULD* mark all other contents as inert (such as \"inert subtrees\" in
[HTML]) if the ability to do so
exists in the host language.

+-----------------------------------+-----------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=============================================================================+
| Used in Roles: | - [`window`](https://w3c.github.io/aria/#window) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Inherits into Roles: | - [`alertdialog`](https://w3c.github.io/aria/#alertdialog) |
| | - [`dialog`](https://w3c.github.io/aria/#dialog) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+-----------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- -----------------------
 **false (default)** Element is not modal.
 true Element is modal.

 : Values:

#### [`aria-multiline` [property]]

[Indicates](#dfn-indicates) whether a text box accepts multiple lines of input or
only a single line.

In most user agent implementations, the default behavior of the
[ENTER] or [RETURN] key is different between the single-line
and multi-line text fields in [HTML]. When user has focus in a single-line
`<input type="text">` element, the keystroke usually submits the form.
When user has focus in a multi-line `<textarea>` element, the keystroke
inserts a line break. The [WAI-ARIA] `textbox` role
differentiates these types of boxes with the
[`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)
attribute, so authors are advised to be aware of this distinction when
designing the field.

+-----------------------------------+-------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=========================================================================+
| Used in Roles: | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+-------------------------------------------------------------------------+
| Inherits into Roles: | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+-----------------------------------+-------------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+-------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- ---------------------------------
 **false (default)** This is a single-line text box.
 true This is a multi-line text box.

 : Values:

#### [`aria-multiselectable` [property]]

[Indicates](#dfn-indicates) that the user can select more than one item from the
current selectable descendants.

Authors *SHOULD* ensure that selected descendants have the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
set to `true`, and selectable descendants that are not selected have the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
attribute set to `false`. Authors *SHOULD NOT* use the
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
attribute on descendants that are not selectable.

Lists and trees are examples of roles that might allow users to select
more than one item at a time.

+-----------------------------------+-----------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================+
| Used in Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`tablist`](https://w3c.github.io/aria/#tablist) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+-----------------------------------------------------------------------+
| Inherits into Roles: | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+-----------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- -------------------------------------------------------------
 **false (default)** Only one item can be selected.
 true More than one item in the widget can be selected at a time.

 : Values:

#### [`aria-orientation` [property]]

[Indicates](#dfn-indicates) whether the element\'s orientation is horizontal,
vertical, or unknown/ambiguous.

In [ARIA] 1.1, the
default value for
[`aria-orientation`](https://w3c.github.io/aria/#aria-orientation)
changed from `horizontal` to `undefined`. Implicit defaults are defined
on some roles (e.g.,
[`slider`](https://w3c.github.io/aria/#slider) defaults
to horizontal;
[`scrollbar`](https://w3c.github.io/aria/#scrollbar)
defaults to vertical) but remain undefined on roles where an expected
default orientation is ambiguous (e.g.,
[`radiogroup`](https://w3c.github.io/aria/#radiogroup)).

+-----------------------------------+---------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===========================================================================+
| Used in Roles: | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`select`](https://w3c.github.io/aria/#select) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`tablist`](https://w3c.github.io/aria/#tablist) |
| | - [`toolbar`](https://w3c.github.io/aria/#toolbar) |
+-----------------------------------+---------------------------------------------------------------------------+
| Inherits into Roles: | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`menu`](https://w3c.github.io/aria/#menu) |
| | - [`menubar`](https://w3c.github.io/aria/#menubar) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+---------------------------------------------------------------------------+
| Value: | [token](#valuetype_token) |
+-----------------------------------+---------------------------------------------------------------------------+

: Characteristics:

 Value Description
 ------------------------- --------------------------------------------------
 horizontal The element is oriented horizontally.
 **undefined (default)** The element\'s orientation is unknown/ambiguous.
 vertical The element is oriented vertically.

 : Values:

#### [`aria-owns` [property]]

[Identifies](#dfn-identifies) an
[element](https://dom.spec.whatwg.org/#concept-element)
(or elements) in order to define a visual, functional, or contextual
parent/child
[relationship](#dfn-relationship) between [DOM] elements where the [DOM] hierarchy cannot be used to represent the
relationship. See related
[`aria-controls`](https://w3c.github.io/aria/#aria-controls).

The value of the
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is a space-separated ID reference list that references one or more
elements in the document by ID. The reason for adding
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
is to expose a parent/child contextual relationship to [assistive
technologies](#assistive-technology) that is otherwise impossible to infer from
the [DOM].

If an element has both
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
and [DOM] children then the order
of the child elements with respect to the parent/child relationship is
the [DOM] children first, then the
elements referenced in
[`aria-owns`](https://w3c.github.io/aria/#aria-owns).
If the author intends that the [DOM] children are not first, then list the
[DOM] children in
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
in the desired order. Authors *SHOULD NOT* use
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
as a replacement for the [DOM]
hierarchy. If the relationship is represented in the [DOM], do not use
[`aria-owns`](https://w3c.github.io/aria/#aria-owns).

Authors *MUST* ensure that an element\'s ID is not specified in more
than one other element\'s
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
attribute at any time. In other words, an element can have only one
explicit owner. Authors *MUST NOT* create circular references with
[`aria-owns`](https://w3c.github.io/aria/#aria-owns).
In the case of authoring error with
[`aria-owns`](https://w3c.github.io/aria/#aria-owns),
the user agent *MAY* ignore some
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
element references in order to build a consistent model of the content.

Authors *MUST NOT* specify
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
on an element which has [Presentational
Children](#childrenArePresentational).

[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
is resolved in the order it is encountered in the [DOM]. Every element referenced by
[`aria-owns`](https://w3c.github.io/aria/#aria-owns)
will determine its [exposure to the accessibility tree](#tree_exclusion)
after its change in ownership is resolved. However:

- User agents *MUST NOT* resolve
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 when it is set on an element that has been [excluded from the
 accessibility tree](#tree_exclusion).
- User agents *MUST NOT* resolve
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 when it references an element that is, or has a [DOM] ancestor that is, [hidden from all
 users](#dfn-hide-from-all-users).

In the following example, "(opens in a new window)" is [included in the
accessibility tree](#tree_inclusion) by virtue of its changed ownership.

[Example 40](#example-40)

```
<a href="https://www.w3.org/" target="_blank" aria-owns="new-window-warning">
 World Wide Web Consortium
</a>
<div aria-hidden="true">
 <span id="new-window-warning"> (opens in a new window)</span>
</div>
```

In the following example, "(opens in a new window)" remains [excluded
from the accessibility tree](#tree_exclusion) since its [DOM] ancestor is [hidden from all
users](#dfn-hide-from-all-users) in host language terms.

[Example 41](#example-41)

```
<a href="https://www.w3.org/" aria-owns="new-window-warning">
 World Wide Web Consortium
</a>
<div hidden>
 <span id="new-window-warning"> (opens in a new window)</span>
</div>
```

In the following example, `<div id="instructions">` and its text content
remain exposed and unmoved [in the accessibility tree](#tree_inclusion)
since the would-be accessibility parent element with `aria-owns` is
[hidden from all
users](#dfn-hide-from-all-users).

[Example 42](#example-42)

```
<div hidden aria-owns="instructions">
 ...
</div>
...
<div id="instructions">
 Instructions go here...
</div>
```

 Characteristic Value
 ---------------- --------------------------------------------
 Used in Roles: All elements of the base markup
 Value: [ID reference list](#valuetype_idref_list)

 : Characteristics:

#### [`aria-placeholder` [property]]

[Defines](#dfn-defines) a short hint (a word or short phrase) intended to aid
the user with data entry when the control has no value. A hint could be
a sample value or a brief description of the expected format.

Authors *SHOULD NOT* use
[`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder)
instead of a label as their purposes are different: The label indicates
what kind of information is expected. The placeholder text is a hint
about the expected value. See related
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)
and
[`aria-label`](https://w3c.github.io/aria/#aria-label).

Authors *SHOULD* present this hint to the user by displaying the hint
text at any time the control\'s value is the empty string. This includes
cases where the control first receives focus, and when users remove a
previously-entered value.

As is the case with the related
[`placeholder`](https://html.spec.whatwg.org/multipage/input.html#attr-input-placeholder)
attribute in [HTML], use of
placeholder text as a replacement for a displayed label can reduce the
accessibility and usability of the control for a range of users
including older users and users with cognitive, mobility, fine motor
skill or vision impairments. While the hint given by the control\'s
label is shown at all times, the short hint given in the placeholder
attribute is only shown before the user enters a value. Furthermore,
placeholder text might be mistaken for a pre-filled value, and as
commonly implemented the default color of the placeholder text provides
insufficient contrast and the lack of a separate visible label reduces
the size of the hit region available for setting focus on the control.

The following examples do not use the [HTML] `label` element as it cannot be used
to label [HTML] elements with
`contenteditable`.

The following example shows a
[`searchbox`](https://w3c.github.io/aria/#searchbox) in
which the user has entered a value:

[Example 43](#example-43)

```
<span id="label">Birthday:</span>
<div contenteditable aria-labelledby="label" aria-placeholder="MM-DD-YYYY">03-14-1879</div>
```

The following example shows the same
[`searchbox`](https://w3c.github.io/aria/#searchbox) in
which the user has not yet entered a value or has removed a
previously-entered value:

[Example 44](#example-44)

```
<span id="label">Birthday:</span>
<div contenteditable aria-labelledby="label" aria-placeholder="MM-DD-YYYY">MM-DD-YYYY</div>
```

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=====================================================================================================================+
| Related Concepts: | [`placeholder`](https://html.spec.whatwg.org/multipage/input.html#attr-input-placeholder) |
| | attribute in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+
| Value: | [string](#valuetype_string) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-posinset` [property]]

[Defines](#dfn-defines) an
[element](https://dom.spec.whatwg.org/#concept-element)\'s
number or position in the current set of listitems or treeitems. Not
required if all elements in the set are present in the [DOM]. See related
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).

If all items in a set are present in the document structure, it is not
necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute),
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the set size and position for each item.
However, if only a portion of the set is present in the document
structure at a given moment, this
[property](#dfn-property) is needed to provide an explicit indication
of an element\'s position.

The following example shows items 5 through 8 in a set of 16.

[Example 45](#example-45)

```
<h2 id="label_fruit"> Available Fruit </h2>
<ul aria-labelledby="label_fruit">
 <li aria-setsize="16" aria-posinset="5"> apples </li>
 <li aria-setsize="16" aria-posinset="6"> bananas </li>
 <li aria-setsize="16" aria-posinset="7"> cantaloupes </li>
 <li aria-setsize="16" aria-posinset="8"> dates </li>
</ul>
```

When specifying
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
authors *MUST* specify a value that is an integer greater than or equal
to 1, and less than or equal to the size of the set when that size is
known. If authors specify
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset),
authors *MUST* also specify a value for
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize).

When specifying `aria-posinset` on a
[`menuitem`](https://w3c.github.io/aria/#menuitem),
[`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox),
or
[`menuitemradio`](https://w3c.github.io/aria/#menuitemradio),
authors *SHOULD* set the value of `aria-posinset` with respect to the
total number of items in the
[`menu`](https://w3c.github.io/aria/#menu), excluding
any separators.

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Used in Roles: | - [`article`](https://w3c.github.io/aria/#article) |
| | - [`comment`](https://w3c.github.io/aria/#comment) |
| | - [`listitem`](https://w3c.github.io/aria/#listitem) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`radio`](https://w3c.github.io/aria/#radio) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`comment`](https://w3c.github.io/aria/#comment) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-pressed` [state]]

[Indicates](#dfn-indicates) the current \"pressed\"
[state](#dfn-state)
of toggle buttons. See related
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
and
[`aria-selected`](https://w3c.github.io/aria/#aria-selected).

Toggle buttons require a full press-and-release cycle to change their
value. Activating it once changes the value to `true`, and activating it
another time changes the value back to `false`. A value of `mixed` means
that the values of more than one item controlled by the button do not
all share the same value. If the
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is not present, the button is not a toggle button.

The
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed)
attribute is similar but not identical to the
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
attribute. Operating systems support `pressed` on buttons and `checked`
on checkboxes.

+-----------------------------------+-------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===================================================================+
| Used in Roles: | - [`button`](https://w3c.github.io/aria/#button) |
+-----------------------------------+-------------------------------------------------------------------+
| Value: | [tristate](#valuetype_tristate) |
+-----------------------------------+-------------------------------------------------------------------+

: Characteristics:

 Value Description
 ------------------------- ------------------------------------------------------------------
 false The element supports being pressed but is not currently pressed.
 mixed Indicates a mixed mode value for a tri-state toggle button.
 true The element is pressed.
 **undefined (default)** The element does not support being pressed.

 : Values:

#### [`aria-readonly` [property]]

Indicates that the
[element](https://dom.spec.whatwg.org/#concept-element)
is not editable, but is otherwise
[operable](#dfn-operable). See related
[`aria-disabled`](https://w3c.github.io/aria/#aria-disabled).

This means the user can read but not set the value of the
[widget](#dfn-widget). Readonly elements are relevant to the user, and
authors *SHOULD NOT* restrict navigation to the element or its
[focusable](#dfn-focusable) descendants. Other actions such as copying the value of
the element are also supported. This is in contrast to disabled
elements, to which applications might not allow user navigation to
descendants.

Examples include:

- A form element which represents a constant.
- Row or column headers in a spreadsheet grid.
- The result of a calculation such as a shopping cart total.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================================================+
| Related Concepts: | [`readonly`](https://html.spec.whatwg.org/multipage/input.html#attr-input-readonly) |
| | attribute in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- --------------------------------------------------
 **false (default)** The user can set the value of the element.
 true The user cannot change the value of the element.

 : Values:

#### [`aria-relevant` [property]]

[Indicates](#dfn-indicates) what notifications the user agent will trigger when the
[accessibility
tree](#dfn-accessibility-tree) within a live region is modified. See
related
[`aria-atomic`](https://w3c.github.io/aria/#aria-atomic).

The
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is represented as a space-separated list of the following values:
`additions`, `removals`, `text`; or a single catch-all value `all`.

This is used to describe
[semantically](#dfn-semantics) meaningful changes, as opposed to merely presentational
ones. For example, nodes that are removed from the top of a log are
merely removed for purposes of creating room for other entries, and the
removal of them does not have meaning. However, in the case of a buddy
list, removal of a buddy name indicates that they are no longer online,
and this is a meaningful [event](#dfn-event). In that case
[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
will be set to `all`. When the
[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
attribute is not provided, the default value, `additions text`,
indicates that text modifications and node additions are relevant, but
that node removals are irrelevant.

[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
values of removals or all are to be used sparingly. Assistive
technologies only need to be informed of content removal when its
removal represents an important change, such as a buddy leaving a chat
room.

Text removals should only be considered relevant if one of the specified
values is \'removals\' or \'all\'. For example, for a text change from
\'foo\' to \'bar\' in a live region with a default
[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
value, the text addition (\'bar\') would be spoken, but the text removal
(\'foo\') would not.

[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
is an optional attribute of live regions. This is a suggestion to
[assistive
technologies](#assistive-technology), but assistive technologies are not
required to present changes of all the relevant types.

When
[`aria-relevant`](https://w3c.github.io/aria/#aria-relevant)
is not defined, an element\'s value is inherited from the nearest
ancestor with a defined value. Although the value is a [token
list](#valuetype_token_list), inherited values are not additive; the
value provided on a descendant element completely overrides any
inherited value from an ancestor element.

When text changes are denoted as relevant, user agents *MUST* monitor
any descendant node change that affects the [Accessible Name and
Description Computation](https://w3c.github.io/accname/)
\[[ACCNAME-1.2](#bib-accname-1.2 "Accessible Name and Description Computation 1.2")\] of the live region as if the accessible name were
determined from contents ([nameFrom: contents](#namecalculation)). For
example, a text change would be triggered if the [HTML] `alt` attribute of a contained image
changed. However, no change would be triggered if there was a text
change to a node outside the live region, even if that node was
referenced (via
[`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby))
by an element contained in the live region.

 Characteristic Value
 ---------------- -------------------------------------
 Used in Roles: All elements of the base markup
 Value: [token list](#valuetype_token_list)

 : Characteristics:

 Value Description
 ------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 additions Element nodes are added to the [accessibility tree](#dfn-accessibility-tree) within the live region.
 **additions text (default)** Equivalent to the combination of values, \"additions text\".
 all Equivalent to the combination of all values, \"additions removals text\".
 removals Text content, a text alternative, or an element node within the live region is removed from the [accessibility tree](#dfn-accessibility-tree).
 text Text content or a text alternative is added to any descendant in the [accessibility tree](#dfn-accessibility-tree) of the live region.

 : Values:

#### [`aria-required` [property]]

[Indicates](#dfn-indicates) that user input is required on the
[element](https://dom.spec.whatwg.org/#concept-element)
before a form can be submitted.

For example, if the user needs to fill in an address field, the author
will need to set the field\'s
[`aria-required`](https://w3c.github.io/aria/#aria-required)
attribute to `true`.

The fact that the element is required is often presented visually (such
as a sign or symbol after the
[widget](#dfn-widget)). Using the
[`aria-required`](https://w3c.github.io/aria/#aria-required)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
allows the author to explicitly convey to [assistive
technologies](#assistive-technology) that an element is required.

Unless an exactly equivalent native attribute is available, host
languages *SHOULD* allow authors to use the
[`aria-required`](https://w3c.github.io/aria/#aria-required)
attribute on host language form elements that require input or selection
by the user.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================================================+
| Related Concepts: | [`required`](https://html.spec.whatwg.org/multipage/input.html#attr-input-required) |
| | attribute in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`checkbox`](https://w3c.github.io/aria/#checkbox) |
| | - [`combobox`](https://w3c.github.io/aria/#combobox) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`listbox`](https://w3c.github.io/aria/#listbox) |
| | - [`radiogroup`](https://w3c.github.io/aria/#radiogroup) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
| | - [`textbox`](https://w3c.github.io/aria/#textbox) |
| | - [`tree`](https://w3c.github.io/aria/#tree) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`searchbox`](https://w3c.github.io/aria/#searchbox) |
| | - [`switch`](https://w3c.github.io/aria/#switch) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+
| Value: | [true/false](#valuetype_true-false) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 --------------------- -----------------------------------------------------------------------
 **false (default)** User input is not necessary to submit the form.
 true Users need to provide input on an element before a form is submitted.

 : Values:

#### [`aria-roledescription` [property]]

[Defines](#dfn-defines) a human-readable, author-localized description for the
[role](#dfn-role) of
an
[element](https://dom.spec.whatwg.org/#concept-element).

Some [assistive
technologies](#assistive-technology), such as screen readers, present the role
of an element as part of the user experience. Such assistive
technologies typically localize the name of the role, and they might
customize it as well. Users of these assistive technologies depend on
the presentation of the role name, such as \"region,\" \"button,\" or
\"slider,\" for an understanding of the purpose of the element and, if
it is a widget, how to interact with it.

The `aria-roledescription` property gives authors the ability to
override how assistive technologies localize and express the name of a
role. Thus inappropriately using `aria-roledescription` might inhibit
users\' ability to understand or interact with an element. Authors
*SHOULD* limit use of `aria-roledescription` to clarifying the purpose
of non-interactive container roles like
[`group`](https://w3c.github.io/aria/#group) or
[`region`](https://w3c.github.io/aria/#region), or to
providing a *more specific* description of a
[`widget`](https://w3c.github.io/aria/#widget).

When using `aria-roledescription`, authors *SHOULD* also ensure that:

1. The element to which `aria-roledescription` is applied has a valid
 [WAI-ARIA] role
 or has an implicit [WAI-ARIA] role semantic.
2. The value of `aria-roledescription` is not empty or does not contain
 only
 [whitespace](https://infra.spec.whatwg.org/#ascii-whitespace) characters.

Depending on the assistive technology, user verbosity settings, or other
factors, certain elements\' role descriptions might not be conveyed. If
specifying `aria-roledescription` on such elements, then the custom role
descriptions might also not be conveyed by these assistive technologies.

Additionally, authors *MUST NOT* specify `aria-roledescription` on an
element which has an explicit or implicit [WAI-ARIA] role where
`aria-roledescription` is [prohibited](#prohibitedattributes).

User agents *MUST NOT* expose the `aria-roledescription` property if any
of the following conditions exist:

1. The element to which `aria-roledescription` is applied has an
 explicit or implicit [WAI-ARIA] role where
 `aria-roledescription` is [prohibited](#prohibitedattributes).
2. The value of `aria-roledescription` is undefined or the empty
 string.

[Assistive
technologies](#assistive-technology) *SHOULD* use the value of
`aria-roledescription` when presenting the role of an element, but
*SHOULD NOT* change other functionality based on the role of an element
that has a value for `aria-roledescription`. For example, an assistive
technology that provides functions for navigating to the next
[`region`](https://w3c.github.io/aria/#region) or
[`button`](https://w3c.github.io/aria/#button) *SHOULD*
allow those functions to navigate to regions and buttons that have an
`aria-roledescription`.

The following two examples show the use of `aria-roledescription` to
indicate that a non-interactive container is a \"slide\" in a web-based
presentation application.

[Example 46](#example-46)

```
<div aria-roledescription="slide" id="slide" aria-labelledby="slideheading">
<h1 id="slideheading">Quarterly Report</h1>
<!-- remaining slide contents -->
</div>
```

[Example 47](#example-47)

```
<article aria-roledescription="slide" id="slide" aria-labelledby="slideheading">
<h1 id="slideheading">Quarterly Report</h1>
<!-- remaining slide contents -->
</article>
```

In the previous examples, a screen reader user might hear \"Quarterly
Report, slide\" rather than the more vague \"Quarterly Report, article\"
or \"Quarterly Report, group.\"

 Characteristic Value
 ---------------- -----------------------------------------------------------------------------------------------------------------------------------
 Used in Roles: All elements of the base markup except for the following roles: [`generic`](https://w3c.github.io/aria/#generic)
 Value: [string](#valuetype_string)

 : Characteristics:

#### [`aria-rowcount` [property]]

[Defines](#dfn-defines) the total number of rows in a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex).

If all of the rows are present in the [DOM], it is not necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the total number of rows. However, if only a
portion of the rows is present in the [DOM] at a given moment, this attribute is
needed to provide an explicit indication of the number of rows in the
full table.

Authors *MUST* set the value of
[`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount)
to an integer equal to the number of rows in the full table. If the
total number of rows is unknown, authors *MUST* set the value of
[`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount)
to `-1` to indicate that the value should not be calculated by the user
agent.

The following example shows a grid with 2000 rows, of which the first
row and rows 100 through 102 are displayed to the user.

[Example 48](#example-48)

```
<div aria-rowcount="2000">
 <div >
 <div aria-rowindex="1">
 <span >First Name</span>
 <span >Last Name</span>
 <span >Company</span>
 <span >Phone</span>
 </div>
 </div>
 <div >
 <div aria-rowindex="100">
 <span >Fred</span>
 <span >Jackson</span>
 <span >Acme, Inc.</span>
 <span >555-1234</span>
 </div>
 <div aria-rowindex="101">
 <span >Sara</span>
 <span >James</span>
 <span >Acme, Inc.</span>
 <span >555-1235</span>
 </div>
 <div aria-rowindex="102">
 <span >Taylor</span>
 <span >Johnson</span>
 <span >Acme, Inc.</span>
 <span >555-1236</span>
 </div>
 </div>
</div>
```

+-----------------------------------+-----------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================+
| Used in Roles: | - [`table`](https://w3c.github.io/aria/#table) |
+-----------------------------------+-----------------------------------------------------------------------+
| Inherits into Roles: | - [`grid`](https://w3c.github.io/aria/#grid) |
| | - [`treegrid`](https://w3c.github.io/aria/#treegrid) |
+-----------------------------------+-----------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-----------------------------------------------------------------------+

: Characteristics:

#### [`aria-rowindex` [property]]

[Defines](#dfn-defines) an
[element\'s](https://dom.spec.whatwg.org/#concept-element) row index or position with respect to the total number of
rows within a
[`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext),
[`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount),
and
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan).

If all of the rows are present in the [DOM], it is not necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the index of each row. However, if only a
portion of the rows is present in the [DOM] at a given moment, this attribute is
needed to provide an explicit indication of each row\'s position with
respect to the full table.

Authors *MUST* set the value for
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
to an integer greater than or equal to 1, greater than the
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
value of any previous rows, and less than or equal to the number of rows
in the full table. For a cell or gridcell which spans multiple rows,
authors *MUST* set the value of
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
to the start of the span.

Authors *SHOULD* place
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
on each row. Authors *MAY* also place
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
on all of the [accessibility
children](#dfn-accessibility-child) of each row.

The following example shows a grid with 2000 rows, of which the first
row and rows 100 through 102 are displayed to the user.

[Example 49](#example-49)

```
<div aria-rowcount="2000">
 <div >
 <div aria-rowindex="1">
 <span >First Name</span>
 <span >Last Name</span>
 <span >Company</span>
 <span >Phone</span>
 </div>
 </div>
 <div >
 <div aria-rowindex="100">
 <span >Fred</span>
 <span >Jackson</span>
 <span >Acme, Inc.</span>
 <span >555-1234</span>
 </div>
 <div aria-rowindex="101">
 <span >Sara</span>
 <span >James</span>
 <span >Acme, Inc.</span>
 <span >555-1235</span>
 </div>
 <div aria-rowindex="102">
 <span >Taylor</span>
 <span >Johnson</span>
 <span >Acme, Inc.</span>
 <span >555-1236</span>
 </div>
 </div>
</div>
```

The following example shows the grid from the previous example with
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
also placed on all of the [accessibility
children](#dfn-accessibility-child) of each row.

[Example 50](#example-50)

```
<div aria-rowcount="2000">
 <div >
 <div aria-rowindex="1">
 <span aria-rowindex="1">First Name</span>
 <span aria-rowindex="1">Last Name</span>
 <span aria-rowindex="1">Company</span>
 <span aria-rowindex="1">Phone</span>
 </div>
 </div>
 <div >
 <div aria-rowindex="100">
 <span aria-rowindex="100">Fred</span>
 <span aria-rowindex="100">Jackson</span>
 <span aria-rowindex="100">Acme, Inc.</span>
 <span aria-rowindex="100">555-1234</span>
 </div>
 <div aria-rowindex="101">
 <span aria-rowindex="101">Sara</span>
 <span aria-rowindex="101">James</span>
 <span aria-rowindex="101">Acme, Inc.</span>
 <span aria-rowindex="101">555-1235</span>
 </div>
 <div aria-rowindex="102">
 <span aria-rowindex="102">Taylor</span>
 <span aria-rowindex="102">Johnson</span>
 <span aria-rowindex="102">Acme, Inc.</span>
 <span aria-rowindex="102">555-1236</span>
 </div>
 </div>
</div>
```

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-rowindextext` [property]]

[Defines](#dfn-defines) a human readable text alternative of
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex).
See related
[`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext).

Authors *SHOULD* only use `aria-rowindextext` when the provided or
calculated value of
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
is not meaningful or does not reflect the displayed index, as can be
seen in the game Battleship.

Authors *SHOULD NOT* use `aria-rowindextext` as a replacement for
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
because some assistive technologies rely upon the numeric row index for
the purpose of keeping track of the user\'s position or providing
alternative table navigation.

Authors *SHOULD* place `aria-rowindextext` on each row. Authors *MAY*
also place `aria-rowindextext` on all of the [accessibility
children](#dfn-accessibility-child) of each row.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
| | - [`row`](https://w3c.github.io/aria/#row) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [string](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-rowspan` [property]]

[Defines](#dfn-defines) the number of rows spanned by a cell or gridcell within
a [`table`](https://w3c.github.io/aria/#table),
[`grid`](https://w3c.github.io/aria/#grid), or
[`treegrid`](https://w3c.github.io/aria/#treegrid). See
related
[`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex)
and
[`aria-colspan`](https://w3c.github.io/aria/#aria-colspan).

This
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is intended for cells and gridcells which are not contained in a native
table. When defining the row span of cells or gridcells in a native
table, authors *SHOULD* use the host language\'s attribute instead of
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan).
If
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)
is used on an element for which the host language provides an equivalent
attribute, [user
agents](https://infra.spec.whatwg.org/#user-agent)
*MUST* ignore the value of
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)
and instead expose the value of the host language\'s attribute to
[assistive
technologies](#assistive-technology).

Authors *MUST* set the value of
[`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan)
to an integer greater than or equal to 0 and less than the value which
would cause the cell or gridcell to overlap the next cell or gridcell in
the same column. Setting the value to 0 indicates that the cell or
gridcell is to span all the remaining rows in the row group.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`cell`](https://w3c.github.io/aria/#cell) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-selected` [state]]

[Indicates](#dfn-indicates) the current \"selected\"
[state](#dfn-state)
of various [widgets](#dfn-widget). See related
[`aria-checked`](https://w3c.github.io/aria/#aria-checked)
and
[`aria-pressed`](https://w3c.github.io/aria/#aria-pressed).

This
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
is used to indicate which elements within single-selection and
multiple-selection
[`composite`](https://w3c.github.io/aria/#composite)
widgets are selected.

The [`option`](https://w3c.github.io/aria/#option),
[`tab`](https://w3c.github.io/aria/#tab), and
[`treeitem`](https://w3c.github.io/aria/#treeitem)
roles permit user agents to provide an implicit value for
[`aria-selected`](https://w3c.github.io/aria/#aria-selected)
when specified conditions are met. User agents *MUST NOT* provide an
implicit value for aria-selected in any other circumstance.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`gridcell`](https://w3c.github.io/aria/#gridcell) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Inherits into Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [true/false/undefined](#valuetype_true-false-undefined) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 ------------------------- -----------------------------------------
 false The selectable element is not selected.
 true The selectable element is selected.
 **undefined (default)** The element is not selectable.

 : Values:

#### [`aria-setsize` [property]]

[Defines](#dfn-defines) the number of items in the current set of listitems or
treeitems. Not required if all elements in the set are present in the
[DOM]. See related
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset).

This [property](#dfn-property) is marked on the members of a set, not the
container element that collects the members of the set. To orient the
user by saying an element is \"item X out of Y,\" the [assistive
technologies](#assistive-technology) would use X equal to the
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
and Y equal to the `aria-setsize` attribute.

If all items up to the current item in a set are present in the document
structure, it is not necessary to set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute),
as the [user
agent](https://infra.spec.whatwg.org/#user-agent) can
automatically calculate the position for these items. However, if all
previous items in the set are not present in the document structure at a
given moment, the author *MUST* set this
[attribute](https://dom.spec.whatwg.org/#concept-attribute)to
provide an explicit indication of an element\'s position.

When specifying `aria-setsize`, authors *MUST* set the value to an
integer equal to the number of items in the set. If the total number of
items is unknown, authors *SHOULD* set the value of `aria-setsize` to
`-1`.

When specifying `aria-setsize` on a
[`menuitem`](https://w3c.github.io/aria/#menuitem),
[`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox),
or
[`menuitemradio`](https://w3c.github.io/aria/#menuitemradio),
authors *SHOULD* set the value of `aria-setsize` based on the total
number of items in the
[`menu`](https://w3c.github.io/aria/#menu), excluding
any separators.

The following example shows items 5 through 8 in a set of 16.

[Example 51](#example-51)

```
<h2 id="label_fruit"> Available Fruit </h2>
<ul aria-labelledby="label_fruit">
 <li aria-setsize="16" aria-posinset="5"> apples </li>
 <li aria-setsize="16" aria-posinset="6"> bananas </li>
 <li aria-setsize="16" aria-posinset="7"> cantaloupes </li>
 <li aria-setsize="16" aria-posinset="8"> dates </li>
</ul>
```

The following example shows items 5 through 8 in a set whose total size
is unknown.

[Example 52](#example-52)

```
<h2 id="label_fruit"> Available Fruit </h2>
<ul aria-labelledby="label_fruit">
 <li aria-setsize="-1" aria-posinset="5"> apples </li>
 <li aria-setsize="-1" aria-posinset="6"> bananas </li>
 <li aria-setsize="-1" aria-posinset="7"> cantaloupes </li>
 <li aria-setsize="-1" aria-posinset="8"> dates </li>
</ul>
```

+-----------------------------------+---------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================+
| Used in Roles: | - [`article`](https://w3c.github.io/aria/#article) |
| | - [`comment`](https://w3c.github.io/aria/#comment) |
| | - [`listitem`](https://w3c.github.io/aria/#listitem) |
| | - [`menuitem`](https://w3c.github.io/aria/#menuitem) |
| | - [`option`](https://w3c.github.io/aria/#option) |
| | - [`radio`](https://w3c.github.io/aria/#radio) |
| | - [`row`](https://w3c.github.io/aria/#row) |
| | - [`tab`](https://w3c.github.io/aria/#tab) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`comment`](https://w3c.github.io/aria/#comment) |
| | - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) |
| | - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) |
| | - [`treeitem`](https://w3c.github.io/aria/#treeitem) |
+-----------------------------------+---------------------------------------------------------------------------------------+
| Value: | [integer](#valuetype_integer) |
+-----------------------------------+---------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-sort` [property]]

[Indicates](#dfn-indicates) if items in a table or grid are sorted in ascending or
descending order.

Authors *SHOULD* only apply this
[property](#dfn-property) to table headers or grid headers. If the
property is not provided, there is no defined sort order. For each table
or grid, authors *SHOULD* apply
[`aria-sort`](https://w3c.github.io/aria/#aria-sort)
to only one header at a time.

+-----------------------------------+-------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+===============================================================================+
| Used in Roles: | - [`columnheader`](https://w3c.github.io/aria/#columnheader) |
| | - [`rowheader`](https://w3c.github.io/aria/#rowheader) |
+-----------------------------------+-------------------------------------------------------------------------------+
| Value: | [token](#valuetype_token) |
+-----------------------------------+-------------------------------------------------------------------------------+

: Characteristics:

 Value Description
 -------------------- -----------------------------------------------------------------------
 ascending Items are sorted in ascending order.
 descending Items are sorted in descending order.
 **none (default)** There is no defined sort applied.
 other A sort algorithm other than ascending or descending has been applied.

 : Values:

#### [`aria-valuemax` [property]]

[Defines](#dfn-defines) the maximum allowed value for a range
[widget](#dfn-widget).

Authors *MUST* ensure the value of
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
is greater than or equal to the value of
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin).
If the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
has a known maximum and minimum, the author *SHOULD* provide properties
for
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
and
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin).

A range widget starts with a given value, which can be increased until
reaching the maximum value, defined by this
[property](#dfn-property). Declaring the minimum and maximum values
allows assistive technology to convey the size of the range to users.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================================+
| Related Concepts: | `<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">` |
| | element [`max`](https://html.spec.whatwg.org/multipage/input.html#attr-input-max) attribute in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Value: | [number](#valuetype_number) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-valuemin` [property]]

[Defines](#dfn-defines) the minimum allowed value for a range
[widget](#dfn-widget).

Authors *MUST* ensure the value of
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
is less than or equal to the value of
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax).
If the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
has a known maximum and minimum, the author *SHOULD* provide properties
for
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
and
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin).

A range widget starts with a given value, which can be decreased until
reaching the minimum value, defined by this
[property](#dfn-property). Declaring the minimum and maximum values
allows assistive technology to convey the size of the range to users.

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================================+
| Related Concepts: | `<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">` |
| | element [`min`](https://html.spec.whatwg.org/multipage/input.html#attr-input-min) attribute in [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Value: | [number](#valuetype_number) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-valuenow` [property]]

[Defines](#dfn-defines) the current value for a range
[widget](#dfn-widget). See related
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext).

This property is used, for example, on a range widget such as a slider
or progress bar.

If the current value is not known (for example, an indeterminate
progress bar), the author *SHOULD NOT* set the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
[attribute](https://dom.spec.whatwg.org/#concept-attribute).
If the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute is absent, no information is implied about the current value.
If the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
has a known maximum and minimum, the author *SHOULD* provide properties
for
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
and
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin).

The value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
is a decimal number. If the range is a set of numeric values, then
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
is one of those values. For example, if the range is \[0, 1\], a valid
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
is 0.5. A value outside the range, such as -2.5 or 1.1, is invalid.

For
[`progressbar`](https://w3c.github.io/aria/#progressbar)
elements and
[`scrollbar`](https://w3c.github.io/aria/#scrollbar)
elements, assistive technologies *SHOULD* render the value to users as a
percent, calculated as a position on the range from
[`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin)
to
[`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax)
if both are defined, otherwise the actual value with a percent
indicator. For elements with role
[`slider`](https://w3c.github.io/aria/#slider) and
[`spinbutton`](https://w3c.github.io/aria/#spinbutton),
assistive technologies *SHOULD* render the actual value to users.

When the rendered value cannot be accurately represented as a number,
authors *SHOULD* use the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
attribute in conjunction with
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
to provide a user-friendly representation of the range\'s current value.
For example, a slider might have rendered values of `small`, `medium`,
and `large`. In this case, the values of
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
would be one of the strings: `small`, `medium`, or `large`.

[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
is specified, assistive technologies render that instead of the value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow).

+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=======================================================================================================================================+
| Related Concepts: | `<input type="`[`range`](https://html.spec.whatwg.org/multipage/input.html#attr-input-type-range-keyword)`">` |
| | element [`value`](https://html.spec.whatwg.org/multipage/input.html#attr-input-value) attribute in |
| | [HTML] |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Used in Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Inherits into Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+
| Value: | [number](#valuetype_number) |
+-----------------------------------+---------------------------------------------------------------------------------------------------------------------------------------+

: Characteristics:

#### [`aria-valuetext` [property]]

[Defines](#dfn-defines) the human readable text alternative of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
for a range [widget](#dfn-widget).

This property is used, for example, on a range widget such as a slider
or progress bar.

If the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
attribute is set, authors *SHOULD* also set the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute, unless that value is unknown (for example, on an
indeterminate
[`progressbar`](https://w3c.github.io/aria/#progressbar)).

Authors *SHOULD* only set the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
attribute when the rendered value cannot be meaningfully represented as
a number. For example, a slider might have rendered values of `small`,
`medium`, and `large`. In this case, the values of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
could range from 1 through 3, which indicate the position of each value
in the value space, but the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
would be one of the strings: `small`, `medium`, or `large`. If the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
attribute is absent, the [assistive
technologies](#assistive-technology) will rely solely on the
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow)
attribute for the current value.

If
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
is specified, assistive technologies *SHOULD* render that value instead
of the value of
[`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow).

+-----------------------------------+-----------------------------------------------------------------------------+
| Characteristic | Value |
+===================================+=============================================================================+
| Used in Roles: | - [`range`](https://w3c.github.io/aria/#range) |
| | - [`separator`](https://w3c.github.io/aria/#separator) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Inherits into Roles: | - [`meter`](https://w3c.github.io/aria/#meter) |
| | - [`progressbar`](https://w3c.github.io/aria/#progressbar) |
| | - [`scrollbar`](https://w3c.github.io/aria/#scrollbar) |
| | - [`slider`](https://w3c.github.io/aria/#slider) |
| | - [`spinbutton`](https://w3c.github.io/aria/#spinbutton) |
+-----------------------------------+-----------------------------------------------------------------------------+
| Value: | [string](#valuetype_string) |
+-----------------------------------+-----------------------------------------------------------------------------+

: Characteristics:

::: header-wrapper
## 7. [Accessibility Tree]

The [accessibility
tree](#dfn-accessibility-tree) and the [DOM] tree are parallel structures. The
[accessibility
tree](#dfn-accessibility-tree) includes the user
interface objects of the [user
agent](https://infra.spec.whatwg.org/#user-agent) and
the objects of the document. [Accessible
objects](#dfn-accessible-object) are created in the accessibility tree for
every [DOM] element that should be
exposed to an [assistive
technology](#assistive-technology), either because it might fire an
accessibility [event](#dfn-event) or because it has a
[property](#dfn-property),
[relationship](#dfn-relationship) or feature which needs to be exposed.

::: header-wrapper
### 7.1 Excluding Elements from the Accessibility Tree

The following
[elements](https://dom.spec.whatwg.org/#concept-element)
are not exposed via the [accessibility [API]](#dfn-accessibility-api) and user agents *MUST NOT* include them in
the [accessibility
tree](#dfn-accessibility-tree):

- Elements, including their descendent elements, that have host language
 semantics specifying that the element is not displayed, such as
 [CSS] `display:none`,
 `visibility:hidden`, or the [HTML] `hidden` attribute.
- Elements with
 [`none`](https://w3c.github.io/aria/#none) or
 [`presentation`](https://w3c.github.io/aria/#presentation)
 as the first role in the role attribute. However, their exclusion is
 conditional. In addition, the element\'s descendants and text content
 are generally included. These exceptions and conditions are documented
 in the [presentation (role)](#presentation) section.

If not already excluded from the accessibility tree per the above rules,
user agents *SHOULD NOT* include the following elements in the
accessibility tree:

- Elements, including their descendants, that have
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
 set to `true`. In other words, `aria-hidden="true"` on a parent
 overrides `aria-hidden="false"` on descendants.

- Any descendants of elements that have the characteristic \"[Children
 Presentational: True](#childrenArePresentational)\" unless the
 descendant is not allowed to be presentational because it meets one of
 the conditions for exception described in [Presentational Roles
 Conflict Resolution](#conflict_resolution_presentation_none). However,
 the text content of any excluded descendants is included.

 Elements with the following roles have the characteristic \"Children
 Presentational: True\":

 - [`button`](https://w3c.github.io/aria/#button)
 - [`checkbox`](https://w3c.github.io/aria/#checkbox)
 - [`img`](https://w3c.github.io/aria/#img)
 - [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox)
 - [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio)
 - [`meter`](https://w3c.github.io/aria/#meter)
 - [`option`](https://w3c.github.io/aria/#option)
 - [`progressbar`](https://w3c.github.io/aria/#progressbar)
 - [`radio`](https://w3c.github.io/aria/#radio)
 - [`scrollbar`](https://w3c.github.io/aria/#scrollbar)
 - [`separator`](https://w3c.github.io/aria/#separator)
 - [`slider`](https://w3c.github.io/aria/#slider)
 - [`switch`](https://w3c.github.io/aria/#switch)
 - [`tab`](https://w3c.github.io/aria/#tab)

::: header-wrapper
### 7.2 Including Elements in the Accessibility Tree

If not excluded from the accessibility tree per the rules above in
[Excluding Elements in the Accessibility Tree](#tree_exclusion), user
agents *MUST* provide an [accessible
object](#dfn-accessible-object) in the [accessibility
tree](#dfn-accessibility-tree) for [DOM]
[elements](https://dom.spec.whatwg.org/#concept-element)
that meet any of the following criteria:

- Elements that are not [hidden](#dfn-hidden) and can fire an
 [accessibility [API]](#dfn-accessibility-api)
 [event](#dfn-event), including:
 - Elements that are currently focused, even if the element or one of
 its ancestor elements has its
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
 attribute set to `true`.
 - Elements that are a valid target of an
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 attribute.
- Elements that have an explicit role or a global [WAI-ARIA] attribute and do not
 have
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden)
 set to `true`. (See [Excluding Elements in the Accessibility
 Tree](#tree_exclusion) for additional guidance on
 [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden).)
- Elements that are not [hidden](#dfn-hidden) and have an ID that is
 referenced by another element via a [WAI-ARIA] property.

 ::::
 :::
 Note
 :::

 Text equivalents for [hidden](#dfn-hidden) referenced objects can still
 be used in the [name and description
 computation](https://w3c.github.io/accname/#mapping_additional_nd)
 even when not included in the accessibility tree.
 ::::

::: header-wrapper
### 7.3 Relationships in the Accessibility Tree

The following terms are used to describe relationships between
[DOM] elements.

The [accessibility children] of a [DOM] element are all of the children of that
element\'s corresponding [accessible
object](#dfn-accessible-object) in the [accessibility
tree](#dfn-accessibility-tree). In terms of the [DOM], that includes the following (with
exclusions listed blow):

- The [DOM] children of the
 [element](https://dom.spec.whatwg.org/#concept-element).
- All [DOM] descendants of the
 [element](https://dom.spec.whatwg.org/#concept-element)
 with only elements of role
 [`generic`](https://w3c.github.io/aria/#generic) or
 [`none`](https://w3c.github.io/aria/#none)
 intervening.
- All [DOM] elements specified via
 an
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 relationship to the element.
- All [DOM] descendants of an
 element with role
 [`generic`](https://w3c.github.io/aria/#generic) or
 [`none`](https://w3c.github.io/aria/#none) specified
 via
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 with only elements of role
 [`generic`](https://w3c.github.io/aria/#generic) or
 [`none`](https://w3c.github.io/aria/#none)
 intervening.

And excludes the following:

- All [DOM] elements that have no
 corresponding [accessible
 object](#dfn-accessible-object) because they have been [excluded from
 the accessibility tree](#tree_exclusion).
- All [DOM] elements whose
 corresponding [accessible
 object](#dfn-accessible-object) have been reparented in the
 [accessibility
 tree](#dfn-accessibility-tree) via
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns).

In the following example, the
[`list`](https://w3c.github.io/aria/#list) element has
four accessibility children:

[Example 53](#example-53)

```
<div aria-owns="child3 child4">
 <div >Accessibility Child 1</div>
 <div>
 <div >Accessibility Child 2</div>
 </div>
</div>
<div id="child3" >Accessibility Child 3</div>
<div id="child4">
 <div >Accessibility Child 4</div>
</div>
```

In the following example, the first
[`list`](https://w3c.github.io/aria/#list) element has
no accessibility children, where as the second
[`list`](https://w3c.github.io/aria/#list) element has
one accessibility child, specifically the
[`listitem`](https://w3c.github.io/aria/#listitem) with
ID value \"reparented\".

[Example 54](#example-54)

```
<div >
 <div aria-hidden="true">Excluded element</div>
 <div id="reparented">Reparented element</div>
</div>
<div aria-owns="reparented"></div>
```

The [accessibility descendants] of a [DOM] element are all [DOM] elements which correspond to descendants
of the corresponding [accessible
object](#dfn-accessible-object) in the [accessibility
tree](#dfn-accessibility-tree).

The [accessibility parent] of a [DOM] element is the parent of the
corresponding [accessible
object](#dfn-accessible-object) in the [accessibility
tree](#dfn-accessibility-tree). In terms of the [DOM], the accessibility parent is one of the
following:

- The [DOM] parent of the
 [element](https://dom.spec.whatwg.org/#concept-element).
- The [DOM] ancestor of the
 [element](https://dom.spec.whatwg.org/#concept-element)
 with only elements of role
 [`generic`](https://w3c.github.io/aria/#generic) or
 [`none`](https://w3c.github.io/aria/#none)
 intervening.
- A [DOM] element with
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 set to the [DOM] ID of the
 [DOM] element in question.
- A [DOM] element with
 [`aria-owns`](https://w3c.github.io/aria/#aria-owns)
 set to the [DOM] ID of an
 ancestor of the [DOM] element in
 question, with only elements of role
 [`generic`](https://w3c.github.io/aria/#generic) or
 [`none`](https://w3c.github.io/aria/#none)
 intervening.

The following four examples all contain a
[`listitem`](https://w3c.github.io/aria/#listitem)
element with an accessibility parent of role
[`list`](https://w3c.github.io/aria/#list):

[Example 55](#example-55)

```
<div >
 <div >The "list" is my accessibility parent.</div>
</div>
```

[Example 56](#example-56)

```
<div >
 <div>
 <div >The "list" is my accessibility parent.</div>
 </div>
</div>
```

[Example 57](#example-57)

```
<div aria-owns="child"></div>
<div id="child" >The "list" is my accessibility parent.</div>
```

[Example 58](#example-58)

```
<div aria-owns="child"></div>
<div id="child">
 <div >The "list" is my accessibility parent.</div>
</div>
```

::: header-wrapper
## 8. Implementation in Host Languages

The [roles](#dfn-role), [state](#dfn-state), and
[properties](#dfn-property) defined in this specification do not form a
complete web language or format. They are intended to be used in the
context of a [host
language](#dfn-host-language). This section discusses how host languages are to
implement [WAI-ARIA], to ensure that the
markup specified here will integrate smoothly and effectively with the
host language markup.

A [host language] is a markup-based language in which [ARIA] can be used as an
accessibility enhancement technology. Examples include
\[[HTML](#bib-html "HTML Standard")\] and
\[[SVG2](#bib-svg2 "Scalable Vector Graphics (SVG) 2")\], which both explicitly support the use of
[ARIA].

Although markup languages look alike superficially, they do not share
language definition infrastructure. To accommodate differences in
language-building approaches, the requirements are both general and
modularization-specific. While allowing for differences in how the
specifications are written, the intent is to maintain consistency in how
the [WAI-ARIA]
information looks to authors and how it is manipulated in the
[DOM] by scripts.

[WAI-ARIA] roles,
states, and properties are implemented as
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
of
[elements](https://dom.spec.whatwg.org/#concept-element).
Roles are applied by placing their names among the tokens appearing in
the value of a host-language-provided `role` attribute. States and
properties each get their own attribute, with values as defined for each
particular state or property in this specification. The name of the
attribute is the aria-prefixed name of the state or property.

::: header-wrapper
### 8.1 Role Attribute

An implementing host language will provide a
[`role`](#dfn-role)
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
with the following characteristics:

- The attribute value *MUST* allow a [token
 list](#dfn-token-list) as the value;
- The appearance of the name literal of any concrete [WAI-ARIA]
 [role](#dfn-role)
 as one of these tokens *MUST NOT* in and of itself make the attribute
 value illegal in the host-language syntax; and
- The first name literal of a non-abstract [WAI-ARIA] role in the list of
 tokens in the role attribute defines the role according to which the
 user agent *MUST* process the element. User Agent processing for roles
 is defined in the [Core Accessibility [API]
 Mappings](https://w3c.github.io/core-aam/)
 \[[CORE-AAM-1.2](#bib-core-aam-1.2 "Core Accessibility API Mappings 1.2")\].

::: header-wrapper
### 8.2 State and Property Attributes

An implementing host language *MUST* allow
[attributes](https://dom.spec.whatwg.org/#concept-attribute)
with the following characteristics:

- The attribute name is the name of any state or property identified in
 the [Supported States and Properties](#states_and_properties) section,
 such as
 [`aria-busy`](https://w3c.github.io/aria/#aria-busy),
 [`aria-selected`](https://w3c.github.io/aria/#aria-selected),
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant),
 [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext);
- The syntax does **NOT** prevent the attribute from appearing anywhere
 that it is applicable, as specified in this specification;
- When these attributes appear in a document instance, the attributes
 will be processed as defined in this specification.

Host languages that support [XML
Namespaces](https://www.w3.org/TR/2006/REC-xml-names-20060816/)
\[[XML-NAMES](#bib-xml-names "Namespaces in XML 1.0 (Third Edition)")\] ***MAY*** require that [WAI-ARIA] attributes be used with a
namespace. In this case, the namespace for [WAI-ARIA] state and property
attributes ***MUST*** be `http://www.w3.org/ns/wai-aria/`. To use
[WAI-ARIA] in host
languages that do not explicitly describe support for it, authors
***SHOULD*** use this namespace as well, if the host language supports
namespaces and there is expectation that user agents will recognize the
[WAI-ARIA]
namespace. The namespace prefix is not defined by this specification but
generally is expected to be \"`aria`\".

The [WAI-ARIA]
state and property attributes have a naming convention such that they
all begin with the string \"`aria-`\". This is *not* a namespace prefix,
it is a part of the state or property name. Therefore, when using
[WAI-ARIA] states
and properties with namespace prefixes, the complete attribute name will
be like \"`aria:aria-foo`\".

Some host languages do not use namespaces with [WAI-ARIA] state and property
attributes, either because the host language does not support namespaces
or because the designers wish to incorporate [WAI-ARIA] into the core feature
set. In these host languages, the namespace name for these attributes
has no value. The names of these attributes do not have a prefix offset
by a colon; in the terms of namespaces they are unprefixed attribute
names. The ECMAScript binding of the [DOM] interface `getAttributeNS` for example,
treats the empty string (`""`) as representing this condition, so that
both `getAttribute("aria-busy")` and `getAttributeNS("", "aria-busy")`
access the same
[`aria-busy`](https://w3c.github.io/aria/#aria-busy)
attribute in the [DOM].

According to the requirements of this section, some user agents
recognize [WAI-ARIA] state and property
attributes *with* namespaces, some *without* namespaces, and some might
recognize both. Authors are advised to be aware of which form is
supported for the host language they are using. Unless the host language
and supporting user agents explicitly indicate that the namespace is
required, authors are advised to use the attribute without namespaces.
Even user agents that support namespaces generally do not publish
namespaced [WAI-ARIA] states and properties to
accessibility [APIs].
In particular, current implementations of [HTML], including [XHTML], do not support this
namespace.

::: header-wrapper
### 8.3 Focus Navigation

An implementing host language *MUST* provide support for the author to
make all interactive elements
[focusable](#dfn-focusable), that is, any renderable or event-receiving elements.
An implementing host language *MUST* provide a facility to allow authors
to define whether these focusable, interactive elements appear in the
default tab navigation order. The `tabindex`
[attribute](https://dom.spec.whatwg.org/#concept-attribute)
in [HTML] is an example of one
implementation.

::: header-wrapper
### 8.4 Implicit [WAI-ARIA] Semantics

[WAI-ARIA] is
designed to provide [semantic](#dfn-semantics) information about objects when host
languages lack native semantics for the object. [WAI-ARIA] is designed, however, to
provide additional semantics for many host languages. Furthermore, host
languages over time can evolve and provide new native features that
correspond to [WAI-ARIA] features. Therefore, there
are many situations in which [WAI-ARIA] semantics are redundant
with host language semantics.

These host language features can be viewed as having \"implicit
[WAI-ARIA]
semantics\". User agent processing of features with implicit
[WAI-ARIA]
semantics would be similar to the processing for the [WAI-ARIA] feature. The processing
might not be identical because of lexical differences between the host
language feature and the [WAI-ARIA] feature, but generally
the user agent would expose the same information to the accessibility
[API]. Features with
implicit [WAI-ARIA]
semantics satisfy [WAI-ARIA] structural requirements
such as Required Accessibility Parent Roles, Allowed Accessibility Child
Roles, required states and properties, etc. and do not require explicit
[WAI-ARIA]
semantics to be provided. On elements with implicit [WAI-ARIA] roles, authors can also
use [WAI-ARIA]
states and properties supported by those roles *without* requiring
explicit indication of the [WAI-ARIA] role.

For example, if an element with the functionality already exists, such
as a checkbox or radio button, use the native semantics of the host
language. [WAI-ARIA] markup is only intended
to be used to enhance the native semantics (e.g., indicating that the
element is required with
[`aria-required`](https://w3c.github.io/aria/#aria-required)),
or to change the semantics to a different purpose from the standard
functionality of the element.

Implicit [WAI-ARIA]
semantics affect the conflict resolution procedures in the following
section, Conflicts with Host Language Semantics. Therefore, implicit
[WAI-ARIA]
semantics need to be defined in a normative specification, such as the
host language specification or the [Core Accessibility [API]
Mappings](https://w3c.github.io/core-aam/).

::: header-wrapper
### 8.5 Conflicts with Host Language Semantics

[WAI-ARIA] roles,
states, and properties are intended to add
[semantic](#dfn-semantics) information when native host language elements with
these semantics are not available, and are generally used on elements
that have no native semantics of their own. They can also be used on
elements that have similar but non-identical semantics (for example, a
nested list could be used to represent a tree structure). This method
can be part of a fallback strategy for older browsers that have no
[WAI-ARIA]
implementation, or because native presentation of the repurposed element
reduces the amount of style and/or script needed. Except for the cases
outlined below, user agents *MUST* always use the [WAI-ARIA] semantics to define how
it exposes the element to accessibility [APIs], rather than using the host
language semantics.

In addition to these normal situations in which [WAI-ARIA] is expected to override
native semantics, there are elements that are inappropriate to override
with [WAI-ARIA].
This could be because identical host language semantics exist, so
[WAI-ARIA] is not
needed, or because semantics from [WAI-ARIA] directly conflict with
host language semantics. When a feature in the host language with
identical role semantics and values is available, and the author has no
compelling reason to avoid using the host language feature, authors
*SHOULD* use the host language features rather than repurpose other
elements with [WAI-ARIA].

Host languages can have features that have implicit [WAI-ARIA] semantics corresponding
to roles. When a [WAI-ARIA] role is provided, user
agents *MUST* use the semantic of the [WAI-ARIA] role for processing, not
the native semantic, unless the role requires [WAI-ARIA] states and properties
whose attributes are explicitly forbidden on the native element by the
host language. Values for roles do not conflict in the same way as
values for states and properties (for example, the [HTML] \'checked\' attribute and the
\'aria-checked\' attribute could have conflicting values), and authors
are expected to have valid reason to provide a [WAI-ARIA] role even on elements
that would not normally be repurposed.

When [WAI-ARIA]
states and properties correspond to host language features that have the
same [implicit [WAI-ARIA]
semantic](#implicit_semantics), it can be particularly problematic to
use the [WAI-ARIA]
feature. If the [WAI-ARIA] feature and the host
language feature are both provided but their values are not kept in
sync, user agents and assistive technologies cannot know which value to
use. Therefore, to prevent providing conflicting states and properties
to assistive technologies, host languages *MUST* explicitly declare
where the use of [WAI-ARIA] attributes on each host
language element conflicts with native features for that element. When a
host language declares a [WAI-ARIA] attribute to be in direct
semantic conflict with a native feature for a given element, user agents
*MUST* ignore the [WAI-ARIA] attribute and instead use
the host language feature with the same implicit semantic.

Host languages *MAY* document features that cannot be overridden with
[WAI-ARIA] (these
are called \"strong native semantics\"). These can be features that have
implicit [WAI-ARIA]
semantics, as well as features where the processing would be uncertain
if the semantics were changed with [WAI-ARIA]. Conformance checkers
*MAY* signal an error or warning when a [WAI-ARIA] role is used on elements
with strong native semantics, but as described above, user agents *MUST*
still use the value of the semantic of the [WAI-ARIA] role when exposing the
element to accessibility [APIs] unless the native host
language semantic is permanently presentational.

The opportunity for host languages to create exceptions to the
[WAI-ARIA] override
of native features is meant to avoid potential author errors or problems
with intrinsic processing of host language features. Author errors could
happen when a host language and [WAI-ARIA] provide similar but not
identical features, where it might not be clear how changing one but not
the other affects the accessibility [API]. Intrinsic processing refers
to the way a feature is processed, beyond simple rendering and exposure
to the Accessibility [API], that cannot reasonably be
changed in response to an [ARIA] feature, and would lead
to unpredictable results were [ARIA] allowed. In these
situations, there is good reason for host languages to limit the scope
of [WAI-ARIA].
However, this provision does not give blanket permission for host
languages to forbid the use of [WAI-ARIA] simply by documenting,
feature by feature, that it cannot be used. Host languages should create
restrictions on the use of [ARIA] only when it is critical
to effective processing of content.

Certain [ARIA]
features are critical to building a complete model in the accessibility
[API]. Such features
are not expected to conflict with native host language semantics (though
they can complement them). Therefore, host languages *MUST NOT* declare
strong native semantics that prevent use of the following [ARIA] features:

- [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
- [`aria-description`](https://w3c.github.io/aria/#aria-description)
- [`aria-label`](https://w3c.github.io/aria/#aria-label)
- [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby)

::: header-wrapper
### 8.6 State and Property Attribute Processing

State and property attributes are included in host languages, and
therefore syntax for representation of their value types is governed by
the host language. For each of the value types defined in
[Value](#propcharacteristic_value), an appropriate value type from the
host language is used. Recommended correspondences between
[WAI-ARIA] value
types and various host language value types are listed in [Mapping
[WAI-ARIA] Value
types to languages](#typemapping). This is a non-normative mapping in
order to accommodate new host languages supporting [WAI-ARIA].

The list value types---ID reference list and token list---allow more
than one value of the given type to be provided. The values are
separated by delimiter characters recognized by the host language for
list attributes, such as space characters, commas, etc. Some languages
might require a specific, single delimiter, while others might allow
various delimiters.

Global states and properties are supported on any element in the host
language. However, authors *MUST* only use non-global states and
properties on elements with a role supporting the state or property;
either defined as an explicit [WAI-ARIA] role, or as defined by
the host language implicit [WAI-ARIA] semantic matching an
appropriate [WAI-ARIA] role. When a role
attribute is added to an element, the
[semantics](#dfn-semantics) and behavior of the element, including support for
[WAI-ARIA] states
and properties, are augmented or overridden by the role behavior. User
agents ***MUST*** ignore non-global states and properties used on an
element without a role supporting the state or property; either defined
as an explicit [WAI-ARIA] role, or as defined by the
host language [WAI-ARIA] semantic matching an
appropriate [WAI-ARIA] role. For example, the
[`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
attribute can be used on a
[`progressbar`](https://w3c.github.io/aria/#progressbar).

[WAI-ARIA] roles
have associated states and properties that are qualified as
\"supported\" or \"required\". An example of a property *supported* by
the [combobox](https://w3c.github.io/aria/#combobox)
role is
[aria-autocomplete](https://w3c.github.io/aria/#aria-autocomplete).
The property is designated \"supported\" in this case because a given
`combobox` might or might not implement auto completion. In contrast,
the `combobox` role *requires* the
[aria-expanded](https://w3c.github.io/aria/#aria-expanded)
state in order to indicate that it is expandable. Comboboxes have a
controlled popup element, such as a `listbox`, that is either open or
closed. If the `listbox` is open, the `combobox` is in its expanded
state; otherwise it is collapsed.

When [WAI-ARIA]
roles are used, *supported* states and properties that are not present
in the [DOM] are treated according
to their default value. Keeping with the `combobox` example, a missing
`aria-autocomplete` attribute is equivalent to
`aria-autocomplete="none"`, meaning the `combobox` does not offer auto
completion.

However, *required* states and properties that are absent are an author
error. Missing required states and properties are processed as detailed
at [Handling Author Errors](#document-handling_author-errors).

Elements that have implicit [WAI-ARIA] semantics support the full
set of [WAI-ARIA]
states and properties supported by the corresponding role. Therefore,
authors *MAY* omit the role when setting states and properties. The role
is only needed when the implicit [WAI-ARIA] role of the element needs
to be changed.

Sometimes states and properties are present in the [DOM] but have a zero-length string (\"\") as
their value. Authors *MAY* specify a zero-length string (\"\") for any
supported (but not required) state or property. User agents *SHOULD*
treat state and property attributes with a value of \"\" the same as
they treat an absent attribute. For supported states and properties,
this corresponds to the default value, but if it is a required
attribute, it signals an author error and is processed as detailed at
[Handling Author Errors](#document-handling_author-errors).

::: header-wrapper
#### 8.6.1 ID Reference Error Processing

[user
agents](https://infra.spec.whatwg.org/#user-agent)
*SHOULD* ignore ID references that do not match the ID of another
[element](https://dom.spec.whatwg.org/#concept-element)
in the same document.

It is the author\'s responsibility to ensure that IDs are unique. If
more than one element has the same ID, the user agent *SHOULD* use the
first element found with the given ID. The behavior will be the same as
`getElementById`.

If the same element is specified multiple times in a single
[WAI-ARIA]
relation, user agents *SHOULD* return multiple pointers to the same
[element](https://dom.spec.whatwg.org/#concept-element).

[`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
is defined as referencing only a single ID reference. Any
`aria-activedescendant` value that does not match an existing ID
reference exactly is an author error and will not match any element in
the [DOM].

::: header-wrapper
### 8.7 [CSS] Selectors

This section might be removed in a future version.

Support for
[attribute](https://dom.spec.whatwg.org/#concept-attribute) selectors *MUST* include [WAI-ARIA] attributes. For example,
`.fooMenuItem[aria-haspopup="true"]` would select all
[elements](https://dom.spec.whatwg.org/#concept-element)
with class `fooMenuItem`, and [WAI-ARIA] property
[`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup)
with value of `true`. The presentation *MUST* be updated for dynamic
changes to [WAI-ARIA] attributes. This allows
authors to match styling with [WAI-ARIA]
[semantics](#dfn-semantics).

::: header-wrapper
## 9. Handling Author Errors

::: header-wrapper
### 9.1 Roles

User agents are expected to perform validation of [WAI-ARIA]
[roles](#dfn-role).

As stated in the [Definition of Roles](#role_definitions) section, it is
considered an authoring error to use [abstract roles](#abstract_roles)
in content. User agents *MUST NOT* map abstract roles via the standard
role mechanism of the accessibility [API].

If the `role` attribute contains no tokens matching the name of a
non-abstract [WAI-ARIA] role, the user agent
*MUST* treat the element as if no [role](#dfn-role) had been provided. For example,
`<table >` should be exposed in the same way as `<table>` and
`<input type="text" >` in the same way as
`<input type="text">`.

Certain landmark roles require names from authors. In situations where
an author has not specified names for these landmarks, it is considered
an authoring error. The user agent *MUST* treat such elements as if no
[role](#dfn-role) had
been provided. If a valid fallback role had been specified, or if the
element had an implicit [ARIA] role, then user agents
would continue to expose that role, instead. Instances of such roles are
as follows:

- [`form`](https://w3c.github.io/aria/#form)
- [`region`](https://w3c.github.io/aria/#region)

::: header-wrapper
### 9.2 States and Properties

In general, [user
agents](https://infra.spec.whatwg.org/#user-agent) do
not do much validation of [WAI-ARIA]
[properties](#dfn-property). User agents *MAY* do some minor validation
on request and enforce things like
[`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
being within 1 and
[`aria-setsize`](https://w3c.github.io/aria/#aria-setsize),
inclusive. User agents are not responsible for logical validation, such
as the following:

1. Circular references created by relations, such as specifying that
 two
 [elements](https://dom.spec.whatwg.org/#concept-element)
 own each other.
2. Correct usage with regard to [DOM] tree structure, such as an
 [element](https://dom.spec.whatwg.org/#concept-element)
 being owned by more than one other element.
3. Elements with [WAI-ARIA]
 [roles](#dfn-role) correctly implement the behavior of the specified
 role. For example, user agents do not verify that an element with a
 role of
 [`checkbox`](https://w3c.github.io/aria/#checkbox)
 actually behaves like a checkbox.
4. Elements that do not correctly observe required child / parent role
 relationships or that appear elsewhere than in their required
 parent.
5. Determining whether
 [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant)
 actually points to an [accessibility
 descendant](#dfn-accessibility-descendant) of the container widget.
6. Determining implicit values of
 [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize)
 and
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
 when they are specified on some but not all the elements of the set.

If the author specifies a non-numeric value for a decimal or integer
value type, the user agent *SHOULD* do the following:

- When asked for the string version of the property, return the string
 if specified by the author.
- When asked for the numeric version:
 - Follow the guidance in the [Fallback values for missing required
 attributes](#authorErrorDefaultValuesTable) table below, if
 applicable.
 - Otherwise, return a fallback value of 0.0 for decimal value types
 and 0 for integer value types.

If a [WAI-ARIA]
property contains an unknown or disallowed value, the user agent
*SHOULD* expose to platform [accessibility [APIs]](#dfn-accessibility-api) as follows:

- When exposing as a platform accessibility [API] attribute, expose the
 unknown value --- do not vet it against possible values.
- When exposing as a platform [API] Boolean state:
 - For values of \"\" (empty string), \"undefined\" or no
 [attribute](https://dom.spec.whatwg.org/#concept-attribute)
 present:
 - Follow the guidance in the [Fallback values for missing required
 attributes](#authorErrorDefaultValuesTable) table below, if
 applicable.
 - Otherwise, treat as false.
 - Treat any other value as true.
- Otherwise, ignore the value and treat the property as not present.

In [UIA], the user agent might
leave the corresponding property set to \"unsupported.\"

User agents *MUST NOT* expose [WAI-ARIA] attributes that reference
unresolved IDs. For example:

- When the state or property has only one ID reference that cannot be
 resolved, treat as if the state or property is not present.
- When the state or property has a list of ID references, ignore any
 that can\'t be resolved. If none in the list can be resolved, treat as
 if the state or property is not present.

If a required [WAI-ARIA] attribute for a given role
is missing, user agents *SHOULD* process the attribute as if the values
given in the following table were provided.

 [WAI-ARIA] role Required Attribute Fallback value
 -------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [`checkbox`](https://w3c.github.io/aria/#checkbox) [`aria-checked`](https://w3c.github.io/aria/#aria-checked) `false`
 [`combobox`](https://w3c.github.io/aria/#combobox) [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) `false`
 [`heading`](https://w3c.github.io/aria/#heading) [`aria-level`](https://w3c.github.io/aria/#aria-level) `2`
 [`menuitemcheckbox`](https://w3c.github.io/aria/#menuitemcheckbox) [`aria-checked`](https://w3c.github.io/aria/#aria-checked) `false`
 [`menuitemradio`](https://w3c.github.io/aria/#menuitemradio) [`aria-checked`](https://w3c.github.io/aria/#aria-checked) `false`
 [`radio`](https://w3c.github.io/aria/#radio) [`aria-checked`](https://w3c.github.io/aria/#aria-checked) `false`
 [`scrollbar`](https://w3c.github.io/aria/#scrollbar) [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) If missing or not a [number](#valuetype_number),`(aria-valuemax - aria-valuemin) / 2`. If present but less than `aria-valuemin`, the value of `aria-valuemin`. If present but greater than `aria-valuemax`, the value of `aria-valuemax`.
 [`separator`](https://w3c.github.io/aria/#separator) (if focusable) [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) If missing or not a [number](#valuetype_number),`(aria-valuemax - aria-valuemin) / 2`. If present but less than `aria-valuemin`, the value of `aria-valuemin`. If present but greater than `aria-valuemax`, the value of `aria-valuemax`.
 [`slider`](https://w3c.github.io/aria/#slider) [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) If missing or not a [number](#valuetype_number),`(aria-valuemax - aria-valuemin) / 2`. If present but less than `aria-valuemin`, the value of `aria-valuemin`. If present but greater than `aria-valuemax`, the value of `aria-valuemax`.
 [`switch`](https://w3c.github.io/aria/#switch) [`aria-checked`](https://w3c.github.io/aria/#aria-checked) `false`
 [`meter`](https://w3c.github.io/aria/#meter) [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) A value matching the implicit or explicitly set `aria-valuemin`.

 : Fallback values for missing required attributes

Implicit values for non-required states and properties appear in the
characteristics table for each role. These are not considered fallback
values so are not included here.

::: header-wrapper
### 9.3 Presentational Roles Conflict Resolution

There are a number of ways presentational role conflicts are resolved.

User agents *MUST NOT* expose
[elements](https://dom.spec.whatwg.org/#concept-element)
having explicit or inherited presentational role in the accessibility
tree, with these exceptions:

- If an element is [focusable](#dfn-focusable), user agents *MUST* ignore the
 [`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
 role and expose the element with its implicit role, in order to ensure
 that the element is [operable](#dfn-operable).
- If an [allowed child element](#mustContain) has an explicit
 non-presentational role, user agents *MUST* ignore an inherited
 presentational role and expose the element with its explicit role. If
 the action of exposing the explicit role causes the accessibility tree
 to be malformed, the expected results are undefined.
- If an element has [global](#dfn-global) [WAI-ARIA] states or properties,
 user agents *MUST* ignore the
 [`none`](https://w3c.github.io/aria/#none)/[`presentation`](https://w3c.github.io/aria/#presentation)
 role and instead expose the element\'s implicit role. However, if an
 element has only non-global, role-specific [WAI-ARIA] states or properties,
 the element *MUST NOT* be exposed unless the presentational role is
 inherited and an explicit non-presentational role is applied.

Some [global](#dfn-global) [WAI-ARIA] states and properties are
[prohibited](#dfn-prohibited) on certain roles. These states and properties are still
considered global for the purposes of Presentational Role Conflict
resolution.

For example,
[`aria-describedby`](https://w3c.github.io/aria/#aria-describedby)
is a global attribute and would always be applied;
[`aria-level`](https://w3c.github.io/aria/#aria-level)
is not a global attribute and would therefore only apply if the element
was not in a presentational state.

[Example 59](#example-59)

```
<!-- 1. is ignored due to the global aria-describedby property. -->
<h1 aria-describedby="comment-1"> Sample Content </h1>
<!-- 2. negates both the implicit 'heading' and the non-global aria-level. -->
<h1 aria-> Sample Content </h1>
```

Authors *MUST NOT* use
[`presentation`](https://w3c.github.io/aria/#presentation)
and [`none`](https://w3c.github.io/aria/#none) on
elements where user agents will ignore that role because it conflicts
with one of the above items.

::: header-wrapper
## 10. IDL Interface

Conforming user agents *MUST* implement the following IDL interface.

::: header-wrapper
### 10.1 Interface Mixin [`ARIAMixin`]

```
WebIDLinterface mixin ARIAMixin {
 [CEReactions, Reflect] attribute DOMString? role;
 [CEReactions, Reflect="aria-activedescendant"] attribute Element? ariaActiveDescendantElement;
 [CEReactions, Reflect="aria-atomic"] attribute DOMString? ariaAtomic;
 [CEReactions, Reflect="aria-autocomplete"] attribute DOMString? ariaAutoComplete;
 [CEReactions, Reflect="aria-braillelabel"] attribute DOMString? ariaBrailleLabel;
 [CEReactions, Reflect="aria-brailleroledescription"] attribute DOMString? ariaBrailleRoleDescription;
 [CEReactions, Reflect="aria-busy"] attribute DOMString? ariaBusy;
 [CEReactions, Reflect="aria-checked"] attribute DOMString? ariaChecked;
 [CEReactions, Reflect="aria-colcount"] attribute DOMString? ariaColCount;
 [CEReactions, Reflect="aria-colindex"] attribute DOMString? ariaColIndex;
 [CEReactions, Reflect="aria-colindextext"] attribute DOMString? ariaColIndexText;
 [CEReactions, Reflect="aria-colspan"] attribute DOMString? ariaColSpan;
 [CEReactions, Reflect="aria-controls"] attribute FrozenArray<Element>? ariaControlsElements;
 [CEReactions, Reflect="aria-current"] attribute DOMString? ariaCurrent;
 [CEReactions, Reflect="aria-describedby"] attribute FrozenArray<Element>? ariaDescribedByElements;
 [CEReactions, Reflect="aria-description"] attribute DOMString? ariaDescription;
 [CEReactions, Reflect="aria-details"] attribute FrozenArray<Element>? ariaDetailsElements;
 [CEReactions, Reflect="aria-disabled"] attribute DOMString? ariaDisabled;
 [CEReactions, Reflect="aria-errormessage"] attribute FrozenArray<Element>? ariaErrorMessageElements;
 [CEReactions, Reflect="aria-expanded"] attribute DOMString? ariaExpanded;
 [CEReactions, Reflect="aria-flowto"] attribute FrozenArray<Element>? ariaFlowToElements;
 [CEReactions, Reflect="aria-haspopup"] attribute DOMString? ariaHasPopup;
 [CEReactions, Reflect="aria-hidden"] attribute DOMString? ariaHidden;
 [CEReactions, Reflect="aria-invalid"] attribute DOMString? ariaInvalid;
 [CEReactions, Reflect="aria-keyshortcuts"] attribute DOMString? ariaKeyShortcuts;
 [CEReactions, Reflect="aria-label"] attribute DOMString? ariaLabel;
 [CEReactions, Reflect="aria-labelledby"] attribute FrozenArray<Element>? ariaLabelledByElements;
 [CEReactions, Reflect="aria-level"] attribute DOMString? ariaLevel;
 [CEReactions, Reflect="aria-live"] attribute DOMString? ariaLive;
 [CEReactions, Reflect="aria-modal"] attribute DOMString? ariaModal;
 [CEReactions, Reflect="aria-multiline"] attribute DOMString? ariaMultiLine;
 [CEReactions, Reflect="aria-multiselectable"] attribute DOMString? ariaMultiSelectable;
 [CEReactions, Reflect="aria-orientation"] attribute DOMString? ariaOrientation;
 [CEReactions, Reflect="aria-owns"] attribute FrozenArray<Element>? ariaOwnsElements;
 [CEReactions, Reflect="aria-placeholder"] attribute DOMString? ariaPlaceholder;
 [CEReactions, Reflect="aria-posinset"] attribute DOMString? ariaPosInSet;
 [CEReactions, Reflect="aria-pressed"] attribute DOMString? ariaPressed;
 [CEReactions, Reflect="aria-readonly"] attribute DOMString? ariaReadOnly;
 [CEReactions, Reflect="aria-relevant"] attribute DOMString? ariaRelevant;
 [CEReactions, Reflect="aria-required"] attribute DOMString? ariaRequired;
 [CEReactions, Reflect="aria-roledescription"] attribute DOMString? ariaRoleDescription;
 [CEReactions, Reflect="aria-rowcount"] attribute DOMString? ariaRowCount;
 [CEReactions, Reflect="aria-rowindex"] attribute DOMString? ariaRowIndex;
 [CEReactions, Reflect="aria-rowindextext"] attribute DOMString? ariaRowIndexText;
 [CEReactions, Reflect="aria-rowspan"] attribute DOMString? ariaRowSpan;
 [CEReactions, Reflect="aria-selected"] attribute DOMString? ariaSelected;
 [CEReactions, Reflect="aria-setsize"] attribute DOMString? ariaSetSize;
 [CEReactions, Reflect="aria-sort"] attribute DOMString? ariaSort;
 [CEReactions, Reflect="aria-valuemax"] attribute DOMString? ariaValueMax;
 [CEReactions, Reflect="aria-valuemin"] attribute DOMString? ariaValueMin;
 [CEReactions, Reflect="aria-valuenow"] attribute DOMString? ariaValueNow;
 [CEReactions, Reflect="aria-valuetext"] attribute DOMString? ariaValueText;
 };
 Element includes ARIAMixin;
```

::: header-wrapper
### 10.2 [ARIA] Attribute Correspondence

The following table provides a correspondence between IDL attribute
names and content attribute names, for use by `ARIAMixin`. It also lists
their correspondence to value type for informative purposes.

 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------
 IDL Attribute Reflected [ARIA] Content Attribute Value type (non-normative)
 [`role`] [role](#introroles) [token list](#valuetype_token_list)
 [`ariaActiveDescendantElement`] [`aria-activedescendant`](https://w3c.github.io/aria/#aria-activedescendant) [ID reference list](#valuetype_idref_list)
 [`ariaAtomic`] [`aria-atomic`](https://w3c.github.io/aria/#aria-atomic) [true/false](#valuetype_true-false)
 [`ariaAutoComplete`] [`aria-autocomplete`](https://w3c.github.io/aria/#aria-autocomplete) [token](#valuetype_token)
 [`ariaBrailleLabel`] [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel) [string](#valuetype_string)
 [`ariaBrailleRoleDescription`] [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription) [string](#valuetype_string)
 [`ariaBusy`] [`aria-busy`](https://w3c.github.io/aria/#aria-busy) [true/false](#valuetype_true-false)
 [`ariaChecked`] [`aria-checked`](https://w3c.github.io/aria/#aria-checked) [tristate](#valuetype_tristate)
 [`ariaColCount`] [`aria-colcount`](https://w3c.github.io/aria/#aria-colcount) [integer](#valuetype_integer)
 [`ariaColIndex`] [`aria-colindex`](https://w3c.github.io/aria/#aria-colindex) [integer](#valuetype_integer)
 [`ariaColIndexText`] [`aria-colindextext`](https://w3c.github.io/aria/#aria-colindextext) [string](#valuetype_string)
 [`ariaColSpan`] [`aria-colspan`](https://w3c.github.io/aria/#aria-colspan) [integer](#valuetype_integer)
 [`ariaControlsElements`] [`aria-controls`](https://w3c.github.io/aria/#aria-controls) [ID reference list](#valuetype_idref_list)
 [`ariaCurrent`] [`aria-current`](https://w3c.github.io/aria/#aria-current) [token](#valuetype_token)
 [`ariaDescribedByElements`] [`aria-describedby`](https://w3c.github.io/aria/#aria-describedby) [ID reference list](#valuetype_idref_list)
 [`ariaDescription`] [`aria-description`](https://w3c.github.io/aria/#aria-description) [string](#valuetype_string)
 [`ariaDetailsElements`] [`aria-details`](https://w3c.github.io/aria/#aria-details) [ID reference list](#valuetype_idref_list)
 [`ariaDisabled`] [`aria-disabled`](https://w3c.github.io/aria/#aria-disabled) [true/false](#valuetype_true-false)
 [`ariaErrorMessageElements`] [`aria-errormessage`](https://w3c.github.io/aria/#aria-errormessage) [ID reference list](#valuetype_idref_list)
 [`ariaExpanded`] [`aria-expanded`](https://w3c.github.io/aria/#aria-expanded) [true/false/undefined](#valuetype_true-false-undefined)
 [`ariaFlowToElements`] [`aria-flowto`](https://w3c.github.io/aria/#aria-flowto) [ID reference list](#valuetype_idref_list)
 [`ariaHasPopup`] [`aria-haspopup`](https://w3c.github.io/aria/#aria-haspopup) [token](#valuetype_token)
 [`ariaHidden`] [`aria-hidden`](https://w3c.github.io/aria/#aria-hidden) [true/false/undefined](#valuetype_true-false-undefined)
 [`ariaInvalid`] [`aria-invalid`](https://w3c.github.io/aria/#aria-invalid) [token](#valuetype_token)
 [`ariaKeyShortcuts`] [`aria-keyshortcuts`](https://w3c.github.io/aria/#aria-keyshortcuts) [string](#valuetype_string)
 [`ariaLabel`] [`aria-label`](https://w3c.github.io/aria/#aria-label) [string](#valuetype_string)
 [`ariaLabelledByElements`] [`aria-labelledby`](https://w3c.github.io/aria/#aria-labelledby) [ID reference list](#valuetype_idref_list)
 [`ariaLevel`] [`aria-level`](https://w3c.github.io/aria/#aria-level) [integer](#valuetype_integer)
 [`ariaLive`] [`aria-live`](https://w3c.github.io/aria/#aria-live) [token](#valuetype_token)
 [`ariaModal`] [`aria-modal`](https://w3c.github.io/aria/#aria-modal) [true/false](#valuetype_true-false)
 [`ariaMultiLine`] [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline) [true/false](#valuetype_true-false)
 [`ariaMultiSelectable`] [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable) [true/false](#valuetype_true-false)
 [`ariaOrientation`] [`aria-orientation`](https://w3c.github.io/aria/#aria-orientation) [token](#valuetype_token)
 [`ariaOwnsElements`] [`aria-owns`](https://w3c.github.io/aria/#aria-owns) [ID reference list](#valuetype_idref_list)
 [`ariaPlaceholder`] [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder) [string](#valuetype_string)
 [`ariaPosInSet`] [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset) [integer](#valuetype_integer)
 [`ariaPressed`] [`aria-pressed`](https://w3c.github.io/aria/#aria-pressed) [tristate](#valuetype_tristate)
 [`ariaReadOnly`] [`aria-readonly`](https://w3c.github.io/aria/#aria-readonly) [true/false](#valuetype_true-false)
 [`ariaRelevant`] [`aria-relevant`](https://w3c.github.io/aria/#aria-relevant) [token list](#valuetype_token_list)
 [`ariaRequired`] [`aria-required`](https://w3c.github.io/aria/#aria-required) [true/false](#valuetype_true-false)
 [`ariaRoleDescription`] [`aria-roledescription`](https://w3c.github.io/aria/#aria-roledescription) [string](#valuetype_string)
 [`ariaRowCount`] [`aria-rowcount`](https://w3c.github.io/aria/#aria-rowcount) [integer](#valuetype_integer)
 [`ariaRowIndex`] [`aria-rowindex`](https://w3c.github.io/aria/#aria-rowindex) [integer](#valuetype_integer)
 [`ariaRowIndexText`] [`aria-rowindextext`](https://w3c.github.io/aria/#aria-rowindextext) [string](#valuetype_string)
 [`ariaRowSpan`] [`aria-rowspan`](https://w3c.github.io/aria/#aria-rowspan) [integer](#valuetype_integer)
 [`ariaSelected`] [`aria-selected`](https://w3c.github.io/aria/#aria-selected) [true/false/undefined](#valuetype_true-false-undefined)
 [`ariaSetSize`] [`aria-setsize`](https://w3c.github.io/aria/#aria-setsize) [integer](#valuetype_integer)
 [`ariaSort`] [`aria-sort`](https://w3c.github.io/aria/#aria-sort) [token](#valuetype_token)
 [`ariaValueMax`] [`aria-valuemax`](https://w3c.github.io/aria/#aria-valuemax) [number](#valuetype_number)
 [`ariaValueMin`] [`aria-valuemin`](https://w3c.github.io/aria/#aria-valuemin) [number](#valuetype_number)
 [`ariaValueNow`] [`aria-valuenow`](https://w3c.github.io/aria/#aria-valuenow) [number](#valuetype_number)
 [`ariaValueText`] [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext) [string](#valuetype_string)
 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------------------------------------------------------------------------------------------- ---------------------------------------------------------

Note: Attributes
[`aria-dropeffect`](https://w3c.github.io/aria/#aria-dropeffect)
and
[`aria-grabbed`](https://w3c.github.io/aria/#aria-grabbed)
were deprecated in [ARIA] 1.1 and do not have
corresponding IDL attributes.

::: header-wrapper
#### 10.2.1 Disambiguation Pattern

*This section is non-normative.*

Though specification authors can make exceptions to this pattern, the
following rules were used to disambiguate names and case of the IDL
attributes listed above.

- Any attribute name referencing concepts that are combinations of two
 or more words (such as \"value text\") becomes a camel-cased IDL
 attribute capitalizing each word boundary. For example,
 [`aria-valuetext`](https://w3c.github.io/aria/#aria-valuetext)
 becomes `ariaValueText` with both the V and T capitalized.
- Likewise, any attribute name referencing concepts that can be
 hyphenated (such as \"multi-selectable\") becomes a camel-cased IDL
 attribute capitalizing each hyphenation boundary. For example, the
 only valid spelling for \"multi-selectable\" is hyphenated, so
 [`aria-multiselectable`](https://w3c.github.io/aria/#aria-multiselectable)
 becomes `ariaMultiSelectable` with both the M and S capitalized.
- When trusted dictionary sources list both hyphenated or non-hyphenated
 spellings (e.g., \"multi-line\" and \"multiline\" are both valid
 spellings) use the hyphenated version and apply the hyphenation rule
 above. For example,
 [`aria-multiline`](https://w3c.github.io/aria/#aria-multiline)
 becomes `ariaMultiLine` with both the M and L capitalized.
- If all trusted dictionary sources list a single spelling of a compound
 word with no spaces or hyphens, only the first letter of the term is
 capitalized. For example, neither "place-holder" nor "place holder"
 are considered valid spellings of the term "placeholder," so
 [`aria-placeholder`](https://w3c.github.io/aria/#aria-placeholder)
 becomes `ariaPlaceholder` with only the P capitalized.
- There are currently no acronym-based [ARIA] attributes, but if
 future attributes include acronym usage, attempt to match existing
 [DOM] conventions (e.g., ID
 becomes Id).

::: header-wrapper
#### 10.2.2 IDL Attribute Name Notes or Exceptions

*This section is non-normative.*

Any notes or exceptions for specific attribute names will be listed
here.

- `ariaPosInSet`: The
 [`aria-posinset`](https://w3c.github.io/aria/#aria-posinset)
 attribute refers to an item\'s position in a set (two words: \"in
 set\") rather than the \"inset\" of an item from the beginning of the
 collection. Therefore the IDL attribute name is `ariaPosInSet` with
 the P, I, and second S capitalized, *not* `ariaPosInset`.

::: header-wrapper
### 10.3 Example IDL Attribute Usage

*This section is non-normative.*

The primary purpose of [ARIA] IDL attribute reflection
is to ease JavaScript-based manipulation of values. The following
examples demonstrate its usage.

[Example 60](#example-60)

[Example](#example-60-0)

```
<div id="inaccessibleButton">
 <!-- Use semantic markup instead. This is just a retrofit example. -->
</div>
```

[Example](#example-60-1)

```
// Get a reference to the element.
let el = document.getElementById('inaccessibleButton');
el.tabIndex = 0; // Make it focusable.

// Set the role and label.
el.role = "button";
el.ariaLabel = "Edit";

// Get the role and label.
el.role; // Returns "button"
el.ariaLabel; // Returns "Edit"

// These are interchangeable with the more verbose setAttribute and getAttribute methods.
el.setAttribute("role", "button");
el.setAttribute("aria-label", "Edit");
el.getAttribute("role"); // Returns "button"
el.getAttribute("aria-label"); // Returns "Edit"

// Changes via either interface are reflected by the other.
el.setAttribute("aria-label", "Delete");
el.ariaLabel; // Returns "Delete"
el.ariaLabel = "Publish";
el.getAttribute("aria-label"); // Returns "Publish"
```

::: header-wrapper
## 11. Security Considerations

*This section is non-normative.*

This specification introduces no new security considerations.

::: header-wrapper
## 12. Privacy Considerations

*This section is non-normative.*

In accordance with [Web Platform Design
Principles](https://www.w3.org/TR/design-principles/#do-not-expose-use-of-assistive-tech),
this specification provides no programmatic interface to determine if
information is being used by Assistive Technologies. However, this
specification does allow an author to present different information to
users of Assistive Technologies from the information available to users
who do not use Assistive Technologies. This is possible using many
features of the [ARIA] specification, just as
this is possible using many other parts of the web technology stack.
This content disparity could be abused to perform [active
fingerprinting](https://www.w3.org/TR/fingerprinting-guidance/#active-0)
of users of Assistive Technologies.

::: header-wrapper
## A. Mapping [WAI-ARIA] Value types to languages

*This section is non-normative.*

The [HTML] column of the table
below is advisory. Guidance on use of [WAI-ARIA] state and properties in
[HTML] is provided in [Document
conformance requirements for use of [ARIA] attributes in
[HTML]](https://www.w3.org/TR/html-aria/#docconformance)
(\[[HTML-ARIA](#bib-html-aria "ARIA in HTML")\]).

The suggested mappings for true/false values in [HTML] use [Keyword and enumerated
attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#keywords-and-enumerated-attributes)
with allowed values of `true` and `false`, instead of using the
[HTML] boolean value type.

The table below provides recommended mappings between [WAI-ARIA] state and property types
and attribute types from [HTML
Standard](https://html.spec.whatwg.org/multipage/){matched-text="[[[HTML]]]"}
and [W3C XML Schema Definition Language (XSD) 1.1 Part 2:
Datatypes](https://www.w3.org/TR/xmlschema11-2/){matched-text="[[[XMLSCHEMA11-2]]]"}.

Languages not listed below might have appropriate value types defined in
the language. If they do not, we recommend XML Schema Datatypes for
general purpose XML languages. Documents using DTDs instead of schemas
will not be able to validate automatically and require additional
processing on [WAI-ARIA] attributes.

 --------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 [WAI-ARIA] type [HTML] XML Schema
 true/false [Keyword and enumerated attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#keywords-and-enumerated-attributes) with allowed values of \"true\" and \"false\" [boolean](https://www.w3.org/TR/xmlschema11-2/#boolean)
 true/false/undefined [Keyword and enumerated attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#keywords-and-enumerated-attributes) with allowed values of `true`, `false`, and `undefined` [NMTOKEN](https://www.w3.org/TR/xmlschema11-2/#NMTOKEN) with an [enumeration constraint](https://www.w3.org/TR/xmlschema11-2/#NMTOKEN) allowing values of `true`, `false`, and `undefined`
 tristate [Keyword and enumerated attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#keywords-and-enumerated-attributes) with allowed values of \"true\", \"false\", and \"mixed\" [NMTOKEN](https://www.w3.org/TR/xmlschema11-2/#NMTOKEN) with an [enumeration constraint](https://www.w3.org/TR/xmlschema11-2/#NMTOKEN) allowing values of \"true\", \"false\", and \"mixed\"
 number [Floating-point numbers](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#floating-point-numbers) [decimal](https://www.w3.org/TR/xmlschema11-2/#decimal)
 integer [Non-negative integer](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#floating-point-numbers) [integer](https://www.w3.org/TR/xmlschema11-2/#integer)
 token [Keyword and enumerated attributes](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#keywords-and-enumerated-attributes) [NMTOKEN](https://www.w3.org/TR/xmlschema11-2/#NMTOKEN) with an [enumeration constraint](https://www.w3.org/TR/xmlschema11-2/#dt-enumeration) allowing values listed in the state or property definition
 token list [Space-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#space-separated-tokens) [NMTOKENS](https://www.w3.org/TR/xmlschema11-2/#NMTOKENS) with an [enumeration constraint](https://www.w3.org/TR/xmlschema11-2/#dt-enumeration) allowing values listed in the state or property definition
 ID reference The value of a defined [id attribute](https://html.spec.whatwg.org/multipage/dom.html#the-id-attribute) on another element [IDREF](https://www.w3.org/TR/xmlschema11-2/#IDREF)
 ID reference list The value of one or more defined [id attributes](https://html.spec.whatwg.org/multipage/dom.html#the-id-attribute) on other element(s), represented as [Space-separated tokens](https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#space-separated-tokens) [IDREFS](https://www.w3.org/TR/xmlschema11-2/#IDREFS)
 string No value constraints [string](https://www.w3.org/TR/xmlschema11-2/#string)
 --------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

::: header-wrapper
## B. Change Log

::: header-wrapper
### B.1 Major feature in this release

- 11-Mar-2020: Add
 [`aria-braillelabel`](https://w3c.github.io/aria/#aria-braillelabel)
- 13-Feb-2020: Role
 [`suggestion`](https://w3c.github.io/aria/#suggestion)
 added
- 11-Feb-2020: Update
 [`aria-details`](https://w3c.github.io/aria/#aria-details)
 to allow multiple IDrefs
- 11-Feb-2020: Role
 [`comment`](https://w3c.github.io/aria/#comment)
 added
- 16-Jan-2020: Add
 [`aria-description`](https://w3c.github.io/aria/#aria-description)
- 15-Jan-2020: Role
 [`mark`](https://w3c.github.io/aria/#mark): Added
- 14-Oct-2019: Add
 [`aria-brailleroledescription`](https://w3c.github.io/aria/#aria-brailleroledescription)

::: header-wrapper
### B.2 Substantive changes since [ARIA] 1.2

- [Fix link to definition of accessibility
 child](https://github.com/w3c/aria/commit/4d3fefe)
- [interop-accessibilty repo
 rename](https://github.com/w3c/aria/commit/5bd87f4)
 ([#2077](https://github.com/w3c/aria/pull/2077))
- [Add statemment about translating in
 keyshortcuts](https://github.com/w3c/aria/commit/0486a98)
 ([#2041](https://github.com/w3c/aria/pull/2041))
- [Clarify that user agents should not expose
 aria-haspopup=false](https://github.com/w3c/aria/commit/9b2a146)
 ([#2030](https://github.com/w3c/aria/pull/2030))
- [Add accessibility web stack and tests
 diagrams](https://github.com/w3c/aria/commit/ff9b9c3)
 ([#2009](https://github.com/w3c/aria/pull/2009))
- [Makes aria-braillelabel prohibited whereever aria-label is
 prohibited...](https://github.com/w3c/aria/commit/ef1ad85)
- [\"cell\" and \"treegrid\" roles are the only ones without any
 reference t...](https://github.com/w3c/aria/commit/122fad6)
- [Updated the characteristics table of \"caption\"
 role](https://github.com/w3c/aria/commit/411bd50)
 ([#1975](https://github.com/w3c/aria/pull/1975))
- [Clarification for exposure of generic
 elements](https://github.com/w3c/aria/commit/dc19188)
 ([#1949](https://github.com/w3c/aria/pull/1949))
- [Distinction between none and
 generic](https://github.com/w3c/aria/commit/051ed84)
 ([#1959](https://github.com/w3c/aria/pull/1959))
- [fix/1939 swap presentation/none
 roles](https://github.com/w3c/aria/commit/cd6b483)
 ([#1945](https://github.com/w3c/aria/pull/1945))
- [aria-atomic has no
 default](https://github.com/w3c/aria/commit/7205d35)
 ([#1894](https://github.com/w3c/aria/pull/1894))
- [Update required owned elements and required context
 role](https://github.com/w3c/aria/commit/232ae78)
 ([#1454](https://github.com/w3c/aria/pull/1454))
- [aria-errormessage is hidden or removed when not
 pertinent](https://github.com/w3c/aria/commit/11902fc)
 ([#1588](https://github.com/w3c/aria/pull/1588))
- [Add search role's base concept pointing to [HTML] spec. Fix
 #1898](https://github.com/w3c/aria/commit/c77c2c4)
 ([#1900](https://github.com/w3c/aria/pull/1900))
- [role=note fleshed out a
 little.](https://github.com/w3c/aria/commit/abbef89)
 ([#1639](https://github.com/w3c/aria/pull/1639))
- [fix(aria-level): update to specify only level
 1-6](https://github.com/w3c/aria/commit/af84654)
 ([#1873](https://github.com/w3c/aria/pull/1873))
- [Change aria-errormessage to ID reference
 list](https://github.com/w3c/aria/commit/11c8909)
 ([#1802](https://github.com/w3c/aria/pull/1802))
- [fix: Permit UA to ignore user-triggered changes inside live regions
 (...](https://github.com/w3c/aria/commit/a31260e)
- [Are all constraints
 inherited?](https://github.com/w3c/aria/commit/7314996)
 ([#1815](https://github.com/w3c/aria/pull/1815))
- [Allude to other widgets that allow group in group role definition
 (#1...](https://github.com/w3c/aria/commit/bcf44d1)
- [update figure role](https://github.com/w3c/aria/commit/c625cb7)
 ([#1705](https://github.com/w3c/aria/pull/1705))
- [Add accessibility tree
 definition](https://github.com/w3c/aria/commit/2617046)
 ([#1784](https://github.com/w3c/aria/pull/1784))
- [remove overly prescriptive distinctions from aria-current values.
 (#1...](https://github.com/w3c/aria/commit/72063a0)
- [proposed rewording for the complementary
 landmark](https://github.com/w3c/aria/commit/8ef7dde)
 ([#1698](https://github.com/w3c/aria/pull/1698))
- [fix(reword): use \'on a page\' instead of \'within any document or
 appli...](https://github.com/w3c/aria/commit/d925596)
- [add \[CEReactions\] to
 IDL.](https://github.com/w3c/aria/commit/483334d)
 ([#1766](https://github.com/w3c/aria/pull/1766))
- [Resolving user agent must not statement and whitespace
 defs](https://github.com/w3c/aria/commit/82bd83f)
 ([#1778](https://github.com/w3c/aria/pull/1778))
- [Revised complementary definition re: [DOM]
 hierarchy](https://github.com/w3c/aria/commit/ece14a1)
 ([#1779](https://github.com/w3c/aria/pull/1779))
- [Fix for \"name required\" for tab at 5.2.8.4 and
 5.2.8.5](https://github.com/w3c/aria/commit/7a56f40)
 ([#1771](https://github.com/w3c/aria/pull/1771))
- [Clarify description for
 aria-keyshortcuts](https://github.com/w3c/aria/commit/6d46a9a)
 ([#1713](https://github.com/w3c/aria/pull/1713))
- [Resolves #978, add back [ARIA] element reflection
 IDL](https://github.com/w3c/aria/commit/060b878)
 ([#1755](https://github.com/w3c/aria/pull/1755))
- [add note to
 aria-roledescription](https://github.com/w3c/aria/commit/9cb71e9)
 ([#1666](https://github.com/w3c/aria/pull/1666))
- [include mention of
 figure/caption](https://github.com/w3c/aria/commit/2ece5c5)
 ([#1704](https://github.com/w3c/aria/pull/1704))
- [Replace irrelevant ariaDescribedBy example with
 ariaValueText](https://github.com/w3c/aria/commit/f215561)
 ([#1729](https://github.com/w3c/aria/pull/1729))
- [revise caption
 definition](https://github.com/w3c/aria/commit/2d2d341)
 ([#1703](https://github.com/w3c/aria/pull/1703))
- [added a label to the combobox listbox
 example](https://github.com/w3c/aria/commit/43b6a45)
 ([#1728](https://github.com/w3c/aria/pull/1728))
- [Update authoring requirement for aria-selected on
 options](https://github.com/w3c/aria/commit/51e0073)
 ([#1719](https://github.com/w3c/aria/pull/1719))
- [Handling Author Errors: form & region
 roles](https://github.com/w3c/aria/commit/47db8e8)
 ([#1683](https://github.com/w3c/aria/pull/1683))
- [add lang clarification to translatable attributes
 section.](https://github.com/w3c/aria/commit/e138d5c)
 ([#1690](https://github.com/w3c/aria/pull/1690))
- [abstract roles remove \'name
 from\'](https://github.com/w3c/aria/commit/157d711)
 ([#1667](https://github.com/w3c/aria/pull/1667))
- [Fix: add aria-level as supported on
 treeitem](https://github.com/w3c/aria/commit/3aed0e2)
 ([#1676](https://github.com/w3c/aria/pull/1676))
- [progressbar: clarify
 described-by](https://github.com/w3c/aria/commit/e1d9d12)
 ([#1671](https://github.com/w3c/aria/pull/1671))
- [Update aria sort value descriptions to include \"row\" fixes
 #1614](https://github.com/w3c/aria/commit/b710565)
 ([#1616](https://github.com/w3c/aria/pull/1616))
- [Change aria-keyshortcuts initial keyword from Indicates to Defines.
 R...](https://github.com/w3c/aria/commit/028bbbb)
- [Add note to checkbox def](https://github.com/w3c/aria/commit/9653692)
 ([#1657](https://github.com/w3c/aria/pull/1657))
- [removed references to
 \<range\>](https://github.com/w3c/aria/commit/1e0383a)
 ([#1652](https://github.com/w3c/aria/pull/1652))
- [updates to IDL section per discussion in
 #1598](https://github.com/w3c/aria/commit/bd03476)
 ([#1633](https://github.com/w3c/aria/pull/1633))
- [Update IDL and enumerated attribute
 section](https://github.com/w3c/aria/commit/0d06a71)
 ([#1611](https://github.com/w3c/aria/pull/1611))
- [Revisions to accessible name
 required](https://github.com/w3c/aria/commit/b41a010)
 ([#1477](https://github.com/w3c/aria/pull/1477))
- [Remove aria-level attribute from
 listitem](https://github.com/w3c/aria/commit/7f72832)
 ([#1484](https://github.com/w3c/aria/pull/1484))
- [rewording of how a \_name\_ (not necessarily a "label" - so changed
 tha...](https://github.com/w3c/aria/commit/912ff77)
- [Change containing to owning in Required Owned
 Elements.](https://github.com/w3c/aria/commit/627b3a6)
 ([#1438](https://github.com/w3c/aria/pull/1438))
- [Revert new labeling
 mechanisms](https://github.com/w3c/aria/commit/103dec9)
 ([#1491](https://github.com/w3c/aria/pull/1491))
- [Add and link attribute terms: Defines, Identifies, and Indicates.
 (#1...](https://github.com/w3c/aria/commit/f4c6669)
- [Add role=image as synonym for
 role=img](https://github.com/w3c/aria/commit/d75a248)
 ([#1370](https://github.com/w3c/aria/pull/1370))
- [add local abstract role usage warnings. fixes
 #1428](https://github.com/w3c/aria/commit/3ebb415)
 ([#1445](https://github.com/w3c/aria/pull/1445))
- [clarify \"current
 element\"](https://github.com/w3c/aria/commit/e482b6f)
 ([#1460](https://github.com/w3c/aria/pull/1460))
- [prohibit name from time
 role](https://github.com/w3c/aria/commit/8c597bf)
 ([#1464](https://github.com/w3c/aria/pull/1464))
- [update bullet 3 of name
 calc](https://github.com/w3c/aria/commit/e68a7ff)
 ([#1475](https://github.com/w3c/aria/pull/1475))
- [Updated aria-setsize and aria-posinset to clarify usage for authors
 (...](https://github.com/w3c/aria/commit/c908c7f)
- [Assistive tech *SHOULD* provide landmark navigation\... user agents
 *MAY* ...](https://github.com/w3c/aria/commit/8fa8068)
- [Adds sentence about group
 role](https://github.com/w3c/aria/commit/327a22f)
 ([#1422](https://github.com/w3c/aria/pull/1422))
- [Use \"containing/contained by\" wording instead of arrow
 abbreviations ...](https://github.com/w3c/aria/commit/ce5d37d)
- [resolves #1407 by changing example in aria-brailleroledescription
 (#1...](https://github.com/w3c/aria/commit/c38c9af)
- [resolves #1394, remove misleading note about [AT] modifying attrs
 direc...](https://github.com/w3c/aria/commit/3dc85aa)
- [Fix remaining instance of confusing role=\"none presentation\" note
 (#1...](https://github.com/w3c/aria/commit/4c3484b)
- [Move section on presentation role conflicts to "Handling Author
 Error...](https://github.com/w3c/aria/commit/4f387e3)
- [Implicit values for required properties section needs
 revising](https://github.com/w3c/aria/commit/b35ecf9)
 ([#1414](https://github.com/w3c/aria/pull/1414))
- [aria-expanded requirement needs to be the same for tab and tablist
 (#...](https://github.com/w3c/aria/commit/0218c25)
- [Listbox and tree: clarify requirements for selected and
 checked](https://github.com/w3c/aria/commit/fc6b7fb)
 ([#1340](https://github.com/w3c/aria/pull/1340))
- [Tighten up Required Context Role:
 group](https://github.com/w3c/aria/commit/c803925)
 ([#1359](https://github.com/w3c/aria/pull/1359))
- [term/definition should use aria-details instead of aria-labelledby
 (#...](https://github.com/w3c/aria/commit/e496a4d)
- [Add a conditional on when aria-controls is
 needed](https://github.com/w3c/aria/commit/48ad8d4)
 ([#1335](https://github.com/w3c/aria/pull/1335))
- [make menuitemradio subclass menuitem, require
 aria-checked](https://github.com/w3c/aria/commit/257b0e1)
 ([#1354](https://github.com/w3c/aria/pull/1354))
- [Stricter language for authors using
 aria-owns](https://github.com/w3c/aria/commit/78ab6b6)
 ([#1351](https://github.com/w3c/aria/pull/1351))
- [improve wording for braille
 patterns](https://github.com/w3c/aria/commit/42417ce)
 ([#1287](https://github.com/w3c/aria/pull/1287))
- [aria-braille properties: improve authoring
 note](https://github.com/w3c/aria/commit/fc91e55)
 ([#1291](https://github.com/w3c/aria/pull/1291))
- [remove name required from
 marquee](https://github.com/w3c/aria/commit/586af31)
 ([#1342](https://github.com/w3c/aria/pull/1342))
- [Generalize AccessibilityRole/AriaAttributes
 IDL](https://github.com/w3c/aria/commit/02fee23)
 ([#984](https://github.com/w3c/aria/pull/984))
- [Add editor note for label
 role](https://github.com/w3c/aria/commit/d781656)
- [Issue 1151: updated document to use the terms owned and container
 for...](https://github.com/w3c/aria/commit/26cb23d)
- [Fix list structure for required owners in
 `suggestion`](https://github.com/w3c/aria/commit/48282a0)
 ([#1293](https://github.com/w3c/aria/pull/1293))
- [Clarify wording in \"Including Elements in the Accessibility Tree\"
 sec...](https://github.com/w3c/aria/commit/37ca124)
- [Make fallback value for separator aria-valuenow consistent with
 scrol...](https://github.com/w3c/aria/commit/9c73b5b)
- [feat: aria-braillelabel](https://github.com/w3c/aria/commit/99763b0)
 ([#923](https://github.com/w3c/aria/pull/923))
- [brailleroledescription
 update](https://github.com/w3c/aria/commit/db5a8c5)
 ([#1097](https://github.com/w3c/aria/pull/1097))
- [Remove superfluous authoring requirement to specify aria-multiline
 (#...](https://github.com/w3c/aria/commit/76474e5)
- [Add suggestion role](https://github.com/w3c/aria/commit/2a047fd)
 ([#1134](https://github.com/w3c/aria/pull/1134))
- [clarify that modal requires an accessible
 name](https://github.com/w3c/aria/commit/dfe62bf)
 ([#1180](https://github.com/w3c/aria/pull/1180))
- [Correct mistake in aria-description pointed out in issue
 1186.](https://github.com/w3c/aria/commit/8420961)
 ([#1193](https://github.com/w3c/aria/pull/1193))
- [Update aria-details](https://github.com/w3c/aria/commit/e8b2274)
 ([#1136](https://github.com/w3c/aria/pull/1136))
- [Add comment role](https://github.com/w3c/aria/commit/eed0ef0)
 ([#1135](https://github.com/w3c/aria/pull/1135))
- [Add aria-description](https://github.com/w3c/aria/commit/f262087)
 ([#1137](https://github.com/w3c/aria/pull/1137))
- [Add mark role](https://github.com/w3c/aria/commit/b3017b3)
 ([#1133](https://github.com/w3c/aria/pull/1133))

::: header-wrapper
## C. Acknowledgments

*This section is non-normative.*

The following people contributed to the development of this document.

- [Aaron Leventhal](https://github.com/aleventhal)
- [Adam Page](https://github.com/adampage)
- [Adrian Roselli](https://github.com/aardrian)
- [Alex Lloyd](https://github.com/AlexLloyd0)
- [Alexander Surkov](https://github.com/asurkov)
- [Amelia Bellamy-Royds](https://github.com/AmeliaBR)
- [Andrea N. Cardona](https://github.com/andreancardona)
- [Anne van Kesteren](https://github.com/annevk)
- [Anne-Gaelle Colom](https://github.com/agcolom)
- [Ariella Gilmore](https://github.com/ariellalgilmore)
- [Benjamin Beaudry](https://github.com/benbeaudry)
- [Boaz](https://github.com/boazsender)
- [Bogdan Brinza](https://github.com/boggydigital)
- [bpmcneilly](https://github.com/bpmcneilly)
- [Brennan Young](https://github.com/brennanyoung)
- [Bryan Garaventa](https://github.com/accdc)
- [Carolyn MacLeod](https://github.com/carmacleod)
- [chlane](https://github.com/chlane)
- [Chris Lilley](https://github.com/svgeesus)
- [Clay Miller](https://github.com/smockle)
- [Craig Morten](https://github.com/jlp-craigmorten)
- [Cynthia Shelly](https://github.com/cyns)
- [D.A. Kahn](https://github.com/dakahn)
- [Dan Bjorge](https://github.com/dbjorge)
- [Dan Clark](https://github.com/dandclark)
- [Denis Ah-Kang](https://github.com/deniak)
- [Domenic Denicola](https://github.com/domenic)
- [Dominique Hazael-Massieux](https://github.com/dontcallmedom)
- [einSelbst](https://github.com/einSelbst)
- [Epigenetic](https://github.com/Epigenetic)
- [Estelle Weyl](https://github.com/estelle)
- [Francis Storr](https://github.com/fstrr)
- [Frédéric Wang](https://github.com/fred-wang)
- [Games for Girls](https://github.com/design1online)
- [Giacomo Petri](https://github.com/giacomo-petri)
- [Harris Schneiderman](https://github.com/schne324)
- [Innovimax](https://github.com/innovimax)
- [Isaac Durazo](https://github.com/isaacdurazo)
- [Ivan Herman](https://github.com/iherman)
- [Jacobo Aragunde Pérez](https://github.com/jaragunde)
- [Jacques Newman](https://github.com/janewman)
- [JaEun Jemma Ku](https://github.com/a11ydoer)
- [James Craig](https://github.com/cookiecrook)
- [Jason Kiss](https://github.com/jasonkiss)
- [JAWS-test](https://github.com/JAWS-test)
- [JAWS-test2](https://github.com/JAWS-test2)
- [joanmarie](https://github.com/joanmarie)
- [Johanna](https://github.com/Johanna-hub)
- [Jon Gunderson](https://github.com/jongund)
- [Jory Cunningham](https://github.com/jorycunningham)
- [Joseph Scheuhammer](https://github.com/klown)
- [Josh Salazar](https://github.com/SalazarJosh)
- [Kagami Sascha Rosylight](https://github.com/saschanaz)
- [Kasper Isager Dalsgarð](https://github.com/kasperisager)
- [katez](https://github.com/KateZhaoTR)
- [Keith Cirkel](https://github.com/keithamus)
- [Laurence Lewis](https://github.com/LaurenceRLewis)
- [Léonie Watson](https://github.com/LJWatson)
- [Luke Warlow](https://github.com/lukewarlow)
- [Manuel Rego](https://github.com/mrego)
- [Marcos Cáceres](https://github.com/marcoscaceres)
- [Marek Lewandowski](https://github.com/mlewand)
- [MarioB](https://github.com/MarioBatusic)
- [Matt Garrish](https://github.com/mattgarrish)
- [Matt King](https://github.com/mcking65)
- [Melanie Richards](https://github.com/melanierichards)
- [Melanie Sumner](https://github.com/MelSumner)
- [Nick Schonning](https://github.com/nschonni)
- [Nicolás Alvarez](https://github.com/nicolas17)
- [Nolan Lawson](https://github.com/nolanlawson)
- [Oisín Nolan](https://github.com/OisinNolan)
- [Patrick H. Lauke](https://github.com/patrickhlauke)
- [Philippe Le Hegaret](https://github.com/plehegar)
- [Prayag Verma](https://github.com/prayagverma)
- [R Brown](https://github.com/ricksbrown)
- [Rahim Abdi](https://github.com/rahimabdi)
- [Richard Schwerdtfeger](https://github.com/richschwer)
- [Rondinelly](https://github.com/Rondinelly)
- [Sarah Higley](https://github.com/smhigley)
- [Sayan Sivakumaran](https://github.com/sivakusayan)
- [Scott O\'Hara](https://github.com/scottaohara)
- [Sebastian \"Sebbie\" Silbermann](https://github.com/eps1lon)
- [Sebastien Stettler](https://github.com/billybonks)
- [Shane McCarron](https://github.com/halindrome)
- [Shota FUJI](https://github.com/pocka)
- [Sid Vishnoi](https://github.com/sidvishnoi)
- [sideshowbarker](https://github.com/sideshowbarker)
- [Simon Pieters](https://github.com/zcorpan)
- [Siraj Khan](https://github.com/sirajrkhan)
- [Stephane Deschamps](https://github.com/notabene)
- [Steve Faulkner](https://github.com/stevefaulkner)
- [Thibaud Colas](https://github.com/thibaudcolas)
- [Tim Weißenfels](https://github.com/tim-we)
- [TST_Zak](https://github.com/zakkinsey)
- [Tyler Wilcock](https://github.com/twilco)
- [Tzviya](https://github.com/TzviyaSiegman)
- [Valerie Young](https://github.com/spectranaut)
- [Vikas Parashar](https://github.com/vikas-parashar)
- [Vyacheslav Aristov](https://github.com/aristov)
- [Wilco Fiers](https://github.com/WilcoFiers)
- [WilliamTennisNFCU](https://github.com/WilliamTennisNFCU)
- [Xiaoqian Wu](https://github.com/siusin)
- [Yummy_Bacon5](https://github.com/YummyBacon5)
- [Yves Lafon](https://github.com/ylafon)

::: header-wrapper
### C.1 [ARIA] WG participants at the time of publication

- Rahim Abdi (Apple Inc.)
- NAVYA AGARWAL (Adobe)
- Mario Batušić (Fabasoft)
- Benjamin Beaudry (Microsoft Corporation)
- Curt Bellew (Oracle Corporation)
- Zoë Bijl (W3C Invited Experts)
- Gautier Chomel (EDRLab)
- Aleksandar Cindrikj (Netcetera)
- Keith Cirkel (Mozilla Foundation)
- Daniel Clark (Microsoft Corporation)
- James Craig (Apple Inc.)
- Chris Cuellar (Bocoup)
- Hidde de Vries (Logius)
- Joanmarie Diggs (Igalia)
- Howard Edwards (Bocoup)
- Tamsin Ewing (W3C)
- Mayuri Faldu (Navy Federal Credit Union)
- Betsy Fanning (PDF Association)
- Steve Faulkner (TetraLogical Services Ltd)
- Jaunita Flessas (Navy Federal Credit Union)
- Jane Fulton (Cisco)
- Bryan Garaventa (W3C Invited Experts)
- Rashmi Garimella (Google LLC)
- Matt Garrish (DAISY Consortium)
- Doug Geoffray (Microsoft Corporation)
- Ariella Gilmore (IBM Corporation)
- Taylore Givens (Microsoft Corporation)
- Shirisha Gubba (Google LLC)
- Eloisa Guerrero (Rakuten Group, Inc.)
- Jon Gunderson (University of Illinois)
- Oliver Habersetzer (SAP SE)
- Theo Hale (Microsoft Corporation)
- Sunny Hardasani (Adobe)
- Matthew Hardy (Adobe)
- Chris Harrelson (Google LLC)
- Peter Heumader (Fabasoft)
- Sarah Higley (Microsoft Corporation)
- Hans Hillen (TPGi)
- Isabel Holdsworth (TPGi)
- Stanley Hon (Microsoft Corporation)
- Michael Jackson (Microsoft Corporation)
- Jilin Jiang (Ant Group Co., Ltd.)
- Duff Johnson (PDF Association)
- Summer Jones (Thomson Reuters Corp.)
- Yuki Kamahori (Cybozu)
- William Kilian (Kilian Codes LLC)
- Matthew King (Meta)
- Zachary Kinsey (TargetStream Technologies)
- Daisuke Kobayashi (Cybozu)
- Greta Krafsig (The Washington Post)
- Peter Krautzberger (krautzource UG)
- Nina Krauß (SAP SE)
- JaEun Jemma Ku (University of Illinois)
- Joe Lamyman (TetraLogical Services Ltd)
- Charles LaPierre (Benetech)
- Philip Lazarevic (Level Access)
- Leo Lee (Microsoft Corporation)
- Aaron Leventhal (Google LLC)
- Brett Lewis (TPGi)
- Andy Luhrs (Microsoft Corporation)
- Sazzad Mahamud (Google LLC)
- Alison Maher (Microsoft Corporation)
- Gurpreet Kaur Mangera (Rakuten Group, Inc.)
- Mark McCarthy (University of Illinois)
- Eduardo Meza Etienne (Navy Federal Credit Union)
- Clay Miller (Microsoft Corporation)
- Hirotaka Minamida (Cybozu)
- Daniel Montalvo (W3C)
- Baldino Morelli (UsableNet)
- Jacques Newman (Microsoft Corporation)
- James Nurthen (Adobe)
- Scott O\'Hara (Microsoft Corporation)
- Lola Odelola (W3C Invited Experts)
- Neil Osman (Evinced Inc.)
- Yusuke Oyama (Cybozu)
- Adam Page (Hilton)
- Michael Pennisi (Bocoup)
- Giacomo Petri (UsableNet)
- Noah Praskins (TPGi)
- Daniel Pöll (Fabasoft)
- Lucas Radaelli (Google LLC)
- Paul Rayius (Allyant)
- Adrian Roselli (W3C Invited Experts)
- Marco Sabidussi (UsableNet)
- Trisha Salas (Level Access)
- Stefan Schnabel (SAP SE)
- Harris Schneiderman (Deque Systems, Inc.)
- Raymond Schwartz (Navy Federal Credit Union)
- Cynthia Shelly (W3C Invited Experts)
- Tzviya Siegman (W3C)
- Arturo Silva (The Washington Post)
- Avneesh Singh (DAISY Consortium)
- Michael\[tm\] Smith (sideshowbarker) (W3C)
- Francis Storr (Intel Corporation)
- Jennifer Strickland (MITRE Corporation)
- Nobukiyo Sugisaki (Cybozu)
- Melanie Sumner (IBM Corporation)
- Alexander Surkov (Igalia)
- James Teh (Mozilla Foundation)
- Jocelyn Tran (Google LLC)

::: header-wrapper
### C.2 Enabling funders

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
## D. References

::: header-wrapper
### D.1 Normative references

\[ACCNAME-1.2\]
: [Accessible Name and Description Computation
 1.2](https://www.w3.org/TR/accname-1.2/). Bryan Garaventa; Melanie
 Sumner. W3C. 23 October 2025. W3C Working Draft. URL:
 <https://www.w3.org/TR/accname-1.2/>

\[CORE-AAM\]
: [Core Accessibility API Mappings
 1.1](https://www.w3.org/TR/core-aam-1.1/). Joanmarie Diggs; Joseph
 Scheuhammer; Richard Schwerdtfeger; Michael Cooper; Andi
 Snow-Weaver; Aaron Leventhal. W3C. 14 December 2017. W3C
 Recommendation. URL: <https://www.w3.org/TR/core-aam-1.1/>

\[CORE-AAM-1.2\]
: [Core Accessibility API Mappings
 1.2](https://www.w3.org/TR/core-aam-1.2/). Valerie Young; Cynthia
 Shelly. W3C. 23 October 2025. CRD. URL:
 <https://www.w3.org/TR/core-aam-1.2/>

\[CSS3-SELECTORS\]
: [Selectors Level 3](https://www.w3.org/TR/selectors-3/). Tantek
 Çelik; Elika Etemad; Daniel Glazman; Ian Hickson; Peter Linss; John
 Williams. W3C. 6 November 2018. W3C Recommendation. URL:
 <https://www.w3.org/TR/selectors-3/>

\[DOM\]
: [DOM Standard](https://dom.spec.whatwg.org/). Anne van Kesteren.
 WHATWG. Living Standard. URL: <https://dom.spec.whatwg.org/>

\[DPUB-ARIA-1.0\]
: [Digital Publishing WAI-ARIA Module
 1.0](https://www.w3.org/TR/dpub-aria-1.0/). Matt Garrish; Tzviya
 Siegman; Markus Gylling; Shane McCarron. W3C. 14 December 2017. W3C
 Recommendation. URL: <https://www.w3.org/TR/dpub-aria-1.0/>

\[HTML\]
: [HTML Standard](https://html.spec.whatwg.org/multipage/). Anne van
 Kesteren; Domenic Denicola; Dominic Farolino; Ian Hickson; Philip
 Jägenstedt; Simon Pieters. WHATWG. Living Standard. URL:
 <https://html.spec.whatwg.org/multipage/>

\[infra\]
: [Infra Standard](https://infra.spec.whatwg.org/). Anne van Kesteren;
 Domenic Denicola. WHATWG. Living Standard. URL:
 <https://infra.spec.whatwg.org/>

\[MathML3\]
: [Mathematical Markup Language (MathML) Version 3.0 2nd
 Edition](https://www.w3.org/TR/MathML3/). David Carlisle; Patrick D
 F Ion; Robert R Miner. W3C. 10 April 2014. W3C Recommendation. URL:
 <https://www.w3.org/TR/MathML3/>

\[RFC2119\]
: [Key words for use in RFCs to Indicate Requirement
 Levels](https://www.rfc-editor.org/rfc/rfc2119). S. Bradner. IETF.
 March 1997. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc2119>

\[RFC8174\]
: [Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
 Words](https://www.rfc-editor.org/rfc/rfc8174). B. Leiba. IETF.
 May 2017. Best Current Practice. URL:
 <https://www.rfc-editor.org/rfc/rfc8174>

\[ROLE-ATTRIBUTE\]
: [Role Attribute 1.0](https://www.w3.org/TR/role-attribute/). Shane
 McCarron et al. W3C. 28 March 2013. W3C Recommendation. URL:
 <https://www.w3.org/TR/role-attribute/>

\[SVG2\]
: [Scalable Vector Graphics (SVG) 2](https://www.w3.org/TR/SVG2/).
 Amelia Bellamy-Royds; Bogdan Brinza; Chris Lilley; Dirk Schulze;
 David Storey; Eric Willigers. W3C. 4 October 2018. W3C Candidate
 Recommendation. URL: <https://www.w3.org/TR/SVG2/>

\[uievents-key\]
: [UI Events KeyboardEvent key
 Values](https://www.w3.org/TR/uievents-key/). Travis Leithead; Gary
 Kacmarcik. W3C. 22 April 2025. W3C Recommendation. URL:
 <https://www.w3.org/TR/uievents-key/>

\[WEBIDL\]
: [Web IDL Standard](https://webidl.spec.whatwg.org/). Edgar Chen;
 Timothy Gu. WHATWG. Living Standard. URL:
 <https://webidl.spec.whatwg.org/>

\[XML-NAMES\]
: [Namespaces in XML 1.0 (Third
 Edition)](https://www.w3.org/TR/xml-names/). Tim Bray; Dave
 Hollander; Andrew Layman; Richard Tobin; Henry Thompson et al. W3C.
 8 December 2009. W3C Recommendation. URL:
 <https://www.w3.org/TR/xml-names/>

::: header-wrapper
### D.2 Informative references

\[AT-SPI\]
: [Assistive Technology Service Provider
 Interface](https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/).
 The GNOME Project. URL:
 <https://gnome.pages.gitlab.gnome.org/at-spi2-core/libatspi/>

\[ATK\]
: [ATK - Accessibility
 Toolkit](https://developer.gnome.org/atk/stable/). The GNOME
 Project. URL: <https://developer.gnome.org/atk/stable/>

\[AXAPI\]
: [The NSAccessibility Protocol for
 macOS](https://developer.apple.com/documentation/appkit/nsaccessibility).
 Apple, Inc. URL:
 <https://developer.apple.com/documentation/appkit/nsaccessibility>

\[design-principles\]
: [Web Platform Design
 Principles](https://www.w3.org/TR/design-principles/). Martin
 Thomson; Jeffrey Yasskin. W3C. 22 October 2025. W3C Working Group
 Note. URL: <https://www.w3.org/TR/design-principles/>

\[fingerprinting-guidance\]
: [Mitigating Browser Fingerprinting in Web
 Specifications](https://www.w3.org/TR/fingerprinting-guidance/).
 Nick Doty; Tom Ritter. W3C. 25 September 2025. W3C Working Group
 Note. URL: <https://www.w3.org/TR/fingerprinting-guidance/>

\[HTML-ARIA\]
: [ARIA in HTML](https://www.w3.org/TR/html-aria/). Scott O\'Hara;
 Patrick Lauke. W3C. 5 August 2025. W3C Recommendation. URL:
 <https://www.w3.org/TR/html-aria/>

\[IAccessible2\]
: [IAccessible2](https://wiki.linuxfoundation.org/accessibility/iaccessible2/).
 Linux Foundation. URL:
 <https://wiki.linuxfoundation.org/accessibility/iaccessible2/>

\[MSAA\]
: [Microsoft Active Accessibility
 (MSAA)](https://docs.microsoft.com/en-us/windows/win32/winauto/microsoft-active-accessibility).
 Microsoft Corporation. URL:
 <https://docs.microsoft.com/en-us/windows/win32/winauto/microsoft-active-accessibility>

\[UI-AUTOMATION\]
: [UI
 Automation](https://docs.microsoft.com/en-us/windows/win32/winauto/ui-automation-specification).
 Microsoft Corporation. URL:
 <https://docs.microsoft.com/en-us/windows/win32/winauto/ui-automation-specification>

\[UIA-EXPRESS\]
: [The IAccessibleEx
 Interface](https://docs.microsoft.com/en-us/windows/win32/winauto/iaccessibleex).
 Microsoft Corporation. URL:
 <https://docs.microsoft.com/en-us/windows/win32/winauto/iaccessibleex>

\[wai-aria-1.1\]
: [Accessible Rich Internet Applications (WAI-ARIA)
 1.1](https://www.w3.org/TR/wai-aria-1.1/). Joanmarie Diggs; Shane
 McCarron; Michael Cooper; Richard Schwerdtfeger; James Craig. W3C.
 14 December 2017. W3C Recommendation. URL:
 <https://www.w3.org/TR/wai-aria-1.1/>

\[WCAG21\]
: [Web Content Accessibility Guidelines (WCAG)
 2.1](https://www.w3.org/TR/WCAG21/). Michael Cooper; Andrew
 Kirkpatrick; Joshue O\'Connor; Alastair Campbell. W3C. 6 May 2025.
 W3C Recommendation. URL: <https://www.w3.org/TR/WCAG21/>

\[XMLSCHEMA11-2\]
: [W3C XML Schema Definition Language (XSD) 1.1 Part 2:
 Datatypes](https://www.w3.org/TR/xmlschema11-2/). David Peterson;
 Sandy Gao; Ashok Malhotra; Michael Sperberg-McQueen; Henry Thompson;
 Paul V. Biron et al. W3C. 5 April 2012. W3C Recommendation. URL:
 <https://www.w3.org/TR/xmlschema11-2/>

[[↑]](#title)

[Permalink](#dfn-accessibility-api)
[exported]

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-dfn-accessibility-api-1 "§ 1. Introduction")
 [(2)](#ref-for-dfn-accessibility-api-2 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-api-3 "Reference 3")
- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-accessibility-api-4 "§ 1.1 Rich Internet Application Accessibility")
- [§ 1.3 User Agent
 Support](#ref-for-dfn-accessibility-api-5 "§ 1.3 User Agent Support")
- [§ 2. Important
 Terms](#ref-for-dfn-accessibility-api-6 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-accessibility-api-7 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-api-8 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-api-9 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-api-10 "Reference 5")
- [§ 3.1 Non-interference with the Host
 Language](#ref-for-dfn-accessibility-api-11 "§ 3.1 Non-interference with the Host Language")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-accessibility-api-12 "§ 4.2 WAI-ARIA States and Properties")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-accessibility-api-13 "§ 4.3.2 Information for User Agents")
- [§ 5.2.9 Children
 Presentational](#ref-for-dfn-accessibility-api-14 "§ 5.2.9 Children Presentational")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-accessibility-api-15 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-accessibility-api-16 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-api-17 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-api-18 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-api-19 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-api-20 "Reference 6")
 [(7)](#ref-for-dfn-accessibility-api-21 "Reference 7")
- [§ 6.6.1 Widget
 Attributes](#ref-for-dfn-accessibility-api-22 "§ 6.6.1 Widget Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-accessibility-api-23 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-accessibility-api-24 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-api-25 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-api-26 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-api-27 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-api-28 "Reference 6")
- [§ 7.1 Excluding Elements from the Accessibility
 Tree](#ref-for-dfn-accessibility-api-29 "§ 7.1 Excluding Elements from the Accessibility Tree")
- [§ 7.2 Including Elements in the Accessibility
 Tree](#ref-for-dfn-accessibility-api-30 "§ 7.2 Including Elements in the Accessibility Tree")
- [§ 9.2 States and
 Properties](#ref-for-dfn-accessibility-api-31 "§ 9.2 States and Properties")

[Permalink](#dfn-accessible-object)
[exported]

**Referenced in:**

- [§ 7. Accessibility
 Tree](#ref-for-dfn-accessible-object-1 "§ 7. Accessibility Tree")
- [§ 7.2 Including Elements in the Accessibility
 Tree](#ref-for-dfn-accessible-object-2 "§ 7.2 Including Elements in the Accessibility Tree")
- [§ 7.3 Relationships in the Accessibility
 Tree](#ref-for-dfn-accessible-object-3 "§ 7.3 Relationships in the Accessibility Tree")
 [(2)](#ref-for-dfn-accessible-object-4 "Reference 2")
 [(3)](#ref-for-dfn-accessible-object-5 "Reference 3")
 [(4)](#ref-for-dfn-accessible-object-6 "Reference 4")
 [(5)](#ref-for-dfn-accessible-object-7 "Reference 5")

[Permalink](#assistive-technology)
[exported]

**Referenced in:**

- [§ 1.
 Introduction](#ref-for-assistive-technology-1 "§ 1. Introduction")
- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-assistive-technology-2 "§ 1.1 Rich Internet Application Accessibility")
 [(2)](#ref-for-assistive-technology-3 "Reference 2")
- [§ 1.2 Target
 Audience](#ref-for-assistive-technology-4 "§ 1.2 Target Audience")
 [(2)](#ref-for-assistive-technology-5 "Reference 2")
 [(3)](#ref-for-assistive-technology-6 "Reference 3")
- [§ 1.3 User Agent
 Support](#ref-for-assistive-technology-7 "§ 1.3 User Agent Support")
- [§ 2. Important
 Terms](#ref-for-assistive-technology-8 "§ 2. Important Terms")
 [(2)](#ref-for-assistive-technology-9 "Reference 2")
 [(3)](#ref-for-assistive-technology-10 "Reference 3")
- [§ 3.3 Assistive Technology Notifications Communicated to Web
 Applications](#ref-for-assistive-technology-11 "§ 3.3 Assistive Technology Notifications Communicated to Web Applications")
- [§ 4. Using
 WAI-ARIA](#ref-for-assistive-technology-12 "§ 4. Using WAI-ARIA")
- [§ 4.1 WAI-ARIA
 Roles](#ref-for-assistive-technology-13 "§ 4.1 WAI-ARIA Roles")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-assistive-technology-14 "§ 4.2 WAI-ARIA States and Properties")
- [§ 4.3.1 Information for
 Authors](#ref-for-assistive-technology-15 "§ 4.3.1 Information for Authors")
- [§ 5.4 Definition of
 Roles](#ref-for-assistive-technology-16 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-assistive-technology-17 "Reference 2")
 [(3)](#ref-for-assistive-technology-18 "Reference 3")
 [(4)](#ref-for-assistive-technology-19 "Reference 4")
 [(5)](#ref-for-assistive-technology-20 "Reference 5")
 [(6)](#ref-for-assistive-technology-21 "Reference 6")
 [(7)](#ref-for-assistive-technology-22 "Reference 7")
 [(8)](#ref-for-assistive-technology-23 "Reference 8")
 [(9)](#ref-for-assistive-technology-24 "Reference 9")
 [(10)](#ref-for-assistive-technology-25 "Reference 10")
 [(11)](#ref-for-assistive-technology-26 "Reference 11")
 [(12)](#ref-for-assistive-technology-27 "Reference 12")
 [(13)](#ref-for-assistive-technology-28 "Reference 13")
 [(14)](#ref-for-assistive-technology-29 "Reference 14")
 [(15)](#ref-for-assistive-technology-30 "Reference 15")
 [(16)](#ref-for-assistive-technology-31 "Reference 16")
 [(17)](#ref-for-assistive-technology-32 "Reference 17")
 [(18)](#ref-for-assistive-technology-33 "Reference 18")
 [(19)](#ref-for-assistive-technology-34 "Reference 19")
 [(20)](#ref-for-assistive-technology-35 "Reference 20")
 [(21)](#ref-for-assistive-technology-36 "Reference 21")
 [(22)](#ref-for-assistive-technology-37 "Reference 22")
 [(23)](#ref-for-assistive-technology-38 "Reference 23")
 [(24)](#ref-for-assistive-technology-39 "Reference 24")
 [(25)](#ref-for-assistive-technology-40 "Reference 25")
 [(26)](#ref-for-assistive-technology-41 "Reference 26")
 [(27)](#ref-for-assistive-technology-42 "Reference 27")
 [(28)](#ref-for-assistive-technology-43 "Reference 28")
 [(29)](#ref-for-assistive-technology-44 "Reference 29")
 [(30)](#ref-for-assistive-technology-45 "Reference 30")
 [(31)](#ref-for-assistive-technology-46 "Reference 31")
 [(32)](#ref-for-assistive-technology-47 "Reference 32")
 [(33)](#ref-for-assistive-technology-48 "Reference 33")
 [(34)](#ref-for-assistive-technology-49 "Reference 34")
- [§ 6.6.1 Widget
 Attributes](#ref-for-assistive-technology-50 "§ 6.6.1 Widget Attributes")
- [§ 6.6.2 Live Region
 Attributes](#ref-for-assistive-technology-51 "§ 6.6.2 Live Region Attributes")
- [§ 6.6.3 Drag-and-Drop
 Attributes](#ref-for-assistive-technology-52 "§ 6.6.3 Drag-and-Drop Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-assistive-technology-53 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-assistive-technology-54 "Reference 2")
 [(3)](#ref-for-assistive-technology-55 "Reference 3")
 [(4)](#ref-for-assistive-technology-56 "Reference 4")
 [(5)](#ref-for-assistive-technology-57 "Reference 5")
 [(6)](#ref-for-assistive-technology-58 "Reference 6")
 [(7)](#ref-for-assistive-technology-59 "Reference 7")
 [(8)](#ref-for-assistive-technology-60 "Reference 8")
 [(9)](#ref-for-assistive-technology-61 "Reference 9")
 [(10)](#ref-for-assistive-technology-62 "Reference 10")
 [(11)](#ref-for-assistive-technology-63 "Reference 11")
 [(12)](#ref-for-assistive-technology-64 "Reference 12")
 [(13)](#ref-for-assistive-technology-65 "Reference 13")
 [(14)](#ref-for-assistive-technology-66 "Reference 14")
 [(15)](#ref-for-assistive-technology-67 "Reference 15")
 [(16)](#ref-for-assistive-technology-68 "Reference 16")
 [(17)](#ref-for-assistive-technology-69 "Reference 17")
 [(18)](#ref-for-assistive-technology-70 "Reference 18")
 [(19)](#ref-for-assistive-technology-71 "Reference 19")
 [(20)](#ref-for-assistive-technology-72 "Reference 20")
 [(21)](#ref-for-assistive-technology-73 "Reference 21")
 [(22)](#ref-for-assistive-technology-74 "Reference 22")
 [(23)](#ref-for-assistive-technology-75 "Reference 23")
 [(24)](#ref-for-assistive-technology-76 "Reference 24")
 [(25)](#ref-for-assistive-technology-77 "Reference 25")
 [(26)](#ref-for-assistive-technology-78 "Reference 26")
 [(27)](#ref-for-assistive-technology-79 "Reference 27")
- [§ 7. Accessibility
 Tree](#ref-for-assistive-technology-80 "§ 7. Accessibility Tree")

[Permalink](#dfn-deprecated)

**Referenced in:**

- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-deprecated-1 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-deprecated-2 "Reference 2")

[Permalink](#dfn-defines)

**Referenced in:**

- [§ 2. Important Terms](#ref-for-dfn-defines-1 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-defines-2 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-defines-3 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-defines-4 "Reference 2")
 [(3)](#ref-for-dfn-defines-5 "Reference 3")
 [(4)](#ref-for-dfn-defines-6 "Reference 4")
 [(5)](#ref-for-dfn-defines-7 "Reference 5")
 [(6)](#ref-for-dfn-defines-8 "Reference 6")
 [(7)](#ref-for-dfn-defines-9 "Reference 7")
 [(8)](#ref-for-dfn-defines-10 "Reference 8")
 [(9)](#ref-for-dfn-defines-11 "Reference 9")
 [(10)](#ref-for-dfn-defines-12 "Reference 10")
 [(11)](#ref-for-dfn-defines-13 "Reference 11")
 [(12)](#ref-for-dfn-defines-14 "Reference 12")
 [(13)](#ref-for-dfn-defines-15 "Reference 13")
 [(14)](#ref-for-dfn-defines-16 "Reference 14")
 [(15)](#ref-for-dfn-defines-17 "Reference 15")
 [(16)](#ref-for-dfn-defines-18 "Reference 16")
 [(17)](#ref-for-dfn-defines-19 "Reference 17")
 [(18)](#ref-for-dfn-defines-20 "Reference 18")
 [(19)](#ref-for-dfn-defines-21 "Reference 19")
 [(20)](#ref-for-dfn-defines-22 "Reference 20")
 [(21)](#ref-for-dfn-defines-23 "Reference 21")
 [(22)](#ref-for-dfn-defines-24 "Reference 22")

[Permalink](#dfn-desktop-focus-event)

**Referenced in:**

- [§ 4.3 Managing Focus and Supporting Keyboard
 Navigation](#ref-for-dfn-desktop-focus-event-1 "§ 4.3 Managing Focus and Supporting Keyboard Navigation")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-desktop-focus-event-2 "§ 4.3.2 Information for User Agents")
 [(2)](#ref-for-dfn-desktop-focus-event-3 "Reference 2")

[Permalink](#dfn-event)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-event-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 2. Important Terms](#ref-for-dfn-event-2 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-event-3 "Reference 2")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-event-4 "§ 4.2 WAI-ARIA States and Properties")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-event-5 "§ 4.3.2 Information for User Agents")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-event-6 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-event-7 "Reference 2")
 [(3)](#ref-for-dfn-event-8 "Reference 3")
- [§ 6.7 State change
 notification](#ref-for-dfn-event-9 "§ 6.7 State change notification")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-event-10 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
- [§ 7. Accessibility
 Tree](#ref-for-dfn-event-11 "§ 7. Accessibility Tree")
- [§ 7.2 Including Elements in the Accessibility
 Tree](#ref-for-dfn-event-12 "§ 7.2 Including Elements in the Accessibility Tree")

[Permalink](#dfn-expose)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-focusable)

**Referenced in:**

- [§ 4.3.1 Information for
 Authors](#ref-for-dfn-focusable-1 "§ 4.3.1 Information for Authors")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-focusable-2 "§ 4.3.2 Information for User Agents")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-focusable-3 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-focusable-4 "Reference 2")
 [(3)](#ref-for-dfn-focusable-5 "Reference 3")
 [(4)](#ref-for-dfn-focusable-6 "Reference 4")
 [(5)](#ref-for-dfn-focusable-7 "Reference 5")
 [(6)](#ref-for-dfn-focusable-8 "Reference 6")
 [(7)](#ref-for-dfn-focusable-9 "Reference 7")
 [(8)](#ref-for-dfn-focusable-10 "Reference 8")
 [(9)](#ref-for-dfn-focusable-11 "Reference 9")
 [(10)](#ref-for-dfn-focusable-12 "Reference 10")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-focusable-13 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-focusable-14 "Reference 2")
 [(3)](#ref-for-dfn-focusable-15 "Reference 3")
 [(4)](#ref-for-dfn-focusable-16 "Reference 4")
 [(5)](#ref-for-dfn-focusable-17 "Reference 5")
- [§ 8.3 Focus
 Navigation](#ref-for-dfn-focusable-18 "§ 8.3 Focus Navigation")
- [§ 9.3 Presentational Roles Conflict
 Resolution](#ref-for-dfn-focusable-19 "§ 9.3 Presentational Roles Conflict Resolution")

[Permalink](#dfn-graphical-document)

**Referenced in:**

- [§ 5.4 Definition of
 Roles](#ref-for-dfn-graphical-document-1 "§ 5.4 Definition of Roles")

[Permalink](#dfn-hidden)
[exported]

**Referenced in:**

- [§ 2. Important Terms](#ref-for-dfn-hidden-1 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-hidden-2 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-hidden-3 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-hidden-4 "Reference 2")
 [(3)](#ref-for-dfn-hidden-5 "Reference 3")
 [(4)](#ref-for-dfn-hidden-6 "Reference 4")
 [(5)](#ref-for-dfn-hidden-7 "Reference 5")
- [§ 7.2 Including Elements in the Accessibility
 Tree](#ref-for-dfn-hidden-8 "§ 7.2 Including Elements in the Accessibility Tree")
 [(2)](#ref-for-dfn-hidden-9 "Reference 2")
 [(3)](#ref-for-dfn-hidden-10 "Reference 3")

[Permalink](#dfn-hide-from-all-users)
[exported]

**Referenced in:**

- [§ 2. Important
 Terms](#ref-for-dfn-hide-from-all-users-1 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-hide-from-all-users-2 "Reference 2")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-hide-from-all-users-3 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-hide-from-all-users-4 "Reference 2")
 [(3)](#ref-for-dfn-hide-from-all-users-5 "Reference 3")
 [(4)](#ref-for-dfn-hide-from-all-users-6 "Reference 4")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-hide-from-all-users-7 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-hide-from-all-users-8 "Reference 2")
 [(3)](#ref-for-dfn-hide-from-all-users-9 "Reference 3")
 [(4)](#ref-for-dfn-hide-from-all-users-10 "Reference 4")
 [(5)](#ref-for-dfn-hide-from-all-users-11 "Reference 5")
 [(6)](#ref-for-dfn-hide-from-all-users-12 "Reference 6")

[Permalink](#dfn-identifies)

**Referenced in:**

- [§ 2. Important
 Terms](#ref-for-dfn-identifies-1 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-identifies-2 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-identifies-3 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-identifies-4 "Reference 2")
 [(3)](#ref-for-dfn-identifies-5 "Reference 3")
 [(4)](#ref-for-dfn-identifies-6 "Reference 4")
 [(5)](#ref-for-dfn-identifies-7 "Reference 5")
 [(6)](#ref-for-dfn-identifies-8 "Reference 6")
 [(7)](#ref-for-dfn-identifies-9 "Reference 7")
 [(8)](#ref-for-dfn-identifies-10 "Reference 8")

[Permalink](#dfn-indicates)

**Referenced in:**

- [§ 2. Important
 Terms](#ref-for-dfn-indicates-1 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-indicates-2 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-indicates-3 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-indicates-4 "Reference 2")
 [(3)](#ref-for-dfn-indicates-5 "Reference 3")
 [(4)](#ref-for-dfn-indicates-6 "Reference 4")
 [(5)](#ref-for-dfn-indicates-7 "Reference 5")
 [(6)](#ref-for-dfn-indicates-8 "Reference 6")
 [(7)](#ref-for-dfn-indicates-9 "Reference 7")
 [(8)](#ref-for-dfn-indicates-10 "Reference 8")
 [(9)](#ref-for-dfn-indicates-11 "Reference 9")
 [(10)](#ref-for-dfn-indicates-12 "Reference 10")
 [(11)](#ref-for-dfn-indicates-13 "Reference 11")
 [(12)](#ref-for-dfn-indicates-14 "Reference 12")
 [(13)](#ref-for-dfn-indicates-15 "Reference 13")
 [(14)](#ref-for-dfn-indicates-16 "Reference 14")
 [(15)](#ref-for-dfn-indicates-17 "Reference 15")
 [(16)](#ref-for-dfn-indicates-18 "Reference 16")
 [(17)](#ref-for-dfn-indicates-19 "Reference 17")
 [(18)](#ref-for-dfn-indicates-20 "Reference 18")
 [(19)](#ref-for-dfn-indicates-21 "Reference 19")
 [(20)](#ref-for-dfn-indicates-22 "Reference 20")

[Permalink](#dfn-keyboard-accessible)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-keyboard-accessible-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 2. Important
 Terms](#ref-for-dfn-keyboard-accessible-2 "§ 2. Important Terms")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-keyboard-accessible-3 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-keyboard-accessible-4 "Reference 2")
 [(3)](#ref-for-dfn-keyboard-accessible-5 "Reference 3")
 [(4)](#ref-for-dfn-keyboard-accessible-6 "Reference 4")
 [(5)](#ref-for-dfn-keyboard-accessible-7 "Reference 5")
 [(6)](#ref-for-dfn-keyboard-accessible-8 "Reference 6")
 [(7)](#ref-for-dfn-keyboard-accessible-9 "Reference 7")
 [(8)](#ref-for-dfn-keyboard-accessible-10 "Reference 8")

[Permalink](#dfn-landmark)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-landmark-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 5.3.4 Landmark
 Roles](#ref-for-dfn-landmark-2 "§ 5.3.4 Landmark Roles")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-landmark-3 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-landmark-4 "Reference 2")
 [(3)](#ref-for-dfn-landmark-5 "Reference 3")
 [(4)](#ref-for-dfn-landmark-6 "Reference 4")
 [(5)](#ref-for-dfn-landmark-7 "Reference 5")
 [(6)](#ref-for-dfn-landmark-8 "Reference 6")
 [(7)](#ref-for-dfn-landmark-9 "Reference 7")
 [(8)](#ref-for-dfn-landmark-10 "Reference 8")
 [(9)](#ref-for-dfn-landmark-11 "Reference 9")
 [(10)](#ref-for-dfn-landmark-12 "Reference 10")
 [(11)](#ref-for-dfn-landmark-13 "Reference 11")

[Permalink](#dfn-live-region)
[exported]

**Referenced in:**

- [§ 5.3.5 Live Region
 Roles](#ref-for-dfn-live-region-1 "§ 5.3.5 Live Region Roles")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-live-region-2 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-live-region-3 "Reference 2")
 [(3)](#ref-for-dfn-live-region-4 "Reference 3")
 [(4)](#ref-for-dfn-live-region-5 "Reference 4")
 [(5)](#ref-for-dfn-live-region-6 "Reference 5")
 [(6)](#ref-for-dfn-live-region-7 "Reference 6")
- [§ 6.6.2 Live Region
 Attributes](#ref-for-dfn-live-region-8 "§ 6.6.2 Live Region Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-live-region-9 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-live-region-10 "Reference 2")
 [(3)](#ref-for-dfn-live-region-11 "Reference 3")

[Permalink](#dfn-managed-state)
[exported]

**Referenced in:**

- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-managed-state-1 "§ 4.2 WAI-ARIA States and Properties")

[Permalink](#dfn-nemeth-braille)

**Referenced in:**

- [§ 5.4 Definition of
 Roles](#ref-for-dfn-nemeth-braille-1 "§ 5.4 Definition of Roles")

[Permalink](#dfn-object)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-object-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 2. Important Terms](#ref-for-dfn-object-2 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-object-3 "Reference 2")
 [(3)](#ref-for-dfn-object-4 "Reference 3")
 [(4)](#ref-for-dfn-object-5 "Reference 4")
 [(5)](#ref-for-dfn-object-6 "Reference 5")
 [(6)](#ref-for-dfn-object-7 "Reference 6")
 [(7)](#ref-for-dfn-object-8 "Reference 7")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-object-9 "§ 4.3.2 Information for User Agents")
- [§ 5.1.4 Base Concept](#ref-for-dfn-object-10 "§ 5.1.4 Base Concept")
- [§ 5.2.2 Required States and
 Properties](#ref-for-dfn-object-11 "§ 5.2.2 Required States and Properties")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-object-12 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-object-13 "Reference 2")
 [(3)](#ref-for-dfn-object-14 "Reference 3")
 [(4)](#ref-for-dfn-object-15 "Reference 4")
- [§ 6.1 Clarification of States versus
 Properties](#ref-for-dfn-object-16 "§ 6.1 Clarification of States versus Properties")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-object-17 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-object-18 "Reference 2")
 [(3)](#ref-for-dfn-object-19 "Reference 3")
 [(4)](#ref-for-dfn-object-20 "Reference 4")
 [(5)](#ref-for-dfn-object-21 "Reference 5")
 [(6)](#ref-for-dfn-object-22 "Reference 6")

[Permalink](#dfn-ontology)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-ontology-1 "§ 1.1 Rich Internet Application Accessibility")

[Permalink](#dfn-operable)

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-operable-1 "§ 1.1 Rich Internet Application Accessibility")
 [(2)](#ref-for-dfn-operable-2 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-operable-3 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-operable-4 "Reference 2")
- [§ 9.3 Presentational Roles Conflict
 Resolution](#ref-for-dfn-operable-5 "§ 9.3 Presentational Roles Conflict Resolution")

[Permalink](#dfn-perceivable)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-perceivable-1 "§ 1.1 Rich Internet Application Accessibility")
 [(2)](#ref-for-dfn-perceivable-2 "Reference 2")
- [§ 2. Important
 Terms](#ref-for-dfn-perceivable-3 "§ 2. Important Terms")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-perceivable-4 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-perceivable-5 "Reference 2")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-perceivable-6 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")

[Permalink](#dfn-property)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-property-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 1.5.1 Authoring
 Tools](#ref-for-dfn-property-2 "§ 1.5.1 Authoring Tools")
- [§ 2. Important Terms](#ref-for-dfn-property-3 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-property-4 "Reference 2")
 [(3)](#ref-for-dfn-property-5 "Reference 3")
- [§ 3.3 Assistive Technology Notifications Communicated to Web
 Applications](#ref-for-dfn-property-6 "§ 3.3 Assistive Technology Notifications Communicated to Web Applications")
- [§ 4. Using WAI-ARIA](#ref-for-dfn-property-7 "§ 4. Using WAI-ARIA")
- [§ 4.1 WAI-ARIA Roles](#ref-for-dfn-property-8 "§ 4.1 WAI-ARIA Roles")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-property-9 "§ 4.2 WAI-ARIA States and Properties")
- [§ 5.2.2 Required States and
 Properties](#ref-for-dfn-property-10 "§ 5.2.2 Required States and Properties")
- [§ 5.2.3 Supported States and
 Properties](#ref-for-dfn-property-11 "§ 5.2.3 Supported States and Properties")
- [§ 5.2.4 Inherited States and
 Properties](#ref-for-dfn-property-12 "§ 5.2.4 Inherited States and Properties")
- [§ 6.1 Clarification of States versus
 Properties](#ref-for-dfn-property-13 "§ 6.1 Clarification of States versus Properties")
- [§ 6.2.1 Related
 Concepts](#ref-for-dfn-property-14 "§ 6.2.1 Related Concepts")
- [§ 6.2.2 Used in
 Roles](#ref-for-dfn-property-15 "§ 6.2.2 Used in Roles")
- [§ 6.2.3 Inherits into
 Roles](#ref-for-dfn-property-16 "§ 6.2.3 Inherits into Roles")
- [§ 6.2.4 Value](#ref-for-dfn-property-17 "§ 6.2.4 Value")
- [§ 6.4 Translatable
 Attributes](#ref-for-dfn-property-18 "§ 6.4 Translatable Attributes")
- [§ 6.5 Global States and
 Properties](#ref-for-dfn-property-19 "§ 6.5 Global States and Properties")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-property-20 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-property-21 "Reference 2")
 [(3)](#ref-for-dfn-property-22 "Reference 3")
 [(4)](#ref-for-dfn-property-23 "Reference 4")
 [(5)](#ref-for-dfn-property-24 "Reference 5")
 [(6)](#ref-for-dfn-property-25 "Reference 6")
 [(7)](#ref-for-dfn-property-26 "Reference 7")
 [(8)](#ref-for-dfn-property-27 "Reference 8")
 [(9)](#ref-for-dfn-property-28 "Reference 9")
- [§ 7. Accessibility
 Tree](#ref-for-dfn-property-29 "§ 7. Accessibility Tree")
- [§ 8. Implementation in Host
 Languages](#ref-for-dfn-property-30 "§ 8. Implementation in Host Languages")
- [§ 9.2 States and
 Properties](#ref-for-dfn-property-31 "§ 9.2 States and Properties")

[Permalink](#dfn-relationship)
[exported]

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-relationship-1 "§ 1. Introduction")
- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-relationship-2 "§ 1.1 Rich Internet Application Accessibility")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-relationship-3 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-relationship-4 "Reference 2")
 [(3)](#ref-for-dfn-relationship-5 "Reference 3")
 [(4)](#ref-for-dfn-relationship-6 "Reference 4")
 [(5)](#ref-for-dfn-relationship-7 "Reference 5")
 [(6)](#ref-for-dfn-relationship-8 "Reference 6")
 [(7)](#ref-for-dfn-relationship-9 "Reference 7")
 [(8)](#ref-for-dfn-relationship-10 "Reference 8")
- [§ 6.6.4 Relationship
 Attributes](#ref-for-dfn-relationship-11 "§ 6.6.4 Relationship Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-relationship-12 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-relationship-13 "Reference 2")
- [§ 7. Accessibility
 Tree](#ref-for-dfn-relationship-14 "§ 7. Accessibility Tree")

[Permalink](#dfn-role)
[exported]

**Referenced in:**

- [§ 1. Introduction](#ref-for-dfn-role-1 "§ 1. Introduction")
- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-role-2 "§ 1.1 Rich Internet Application Accessibility")
 [(2)](#ref-for-dfn-role-3 "Reference 2")
- [§ 1.5.1 Authoring
 Tools](#ref-for-dfn-role-4 "§ 1.5.1 Authoring Tools")
- [§ 2. Important Terms](#ref-for-dfn-role-5 "§ 2. Important Terms")
- [§ 4. Using WAI-ARIA](#ref-for-dfn-role-6 "§ 4. Using WAI-ARIA")
- [§ 4.1 WAI-ARIA Roles](#ref-for-dfn-role-7 "§ 4.1 WAI-ARIA Roles")
 [(2)](#ref-for-dfn-role-8 "Reference 2")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-role-9 "§ 4.2 WAI-ARIA States and Properties")
- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-role-10 "§ 4.3.2 Information for User Agents")
 [(2)](#ref-for-dfn-role-11 "Reference 2")
- [§ 5. The Roles Model](#ref-for-dfn-role-12 "§ 5. The Roles Model")
- [§ 5.1.1 Superclass
 Role](#ref-for-dfn-role-13 "§ 5.1.1 Superclass Role")
- [§ 5.1.2 Subclass
 Roles](#ref-for-dfn-role-14 "§ 5.1.2 Subclass Roles")
- [§ 5.1.4 Base Concept](#ref-for-dfn-role-15 "§ 5.1.4 Base Concept")
- [§ 5.2.1 Abstract
 Roles](#ref-for-dfn-role-16 "§ 5.2.1 Abstract Roles")
- [§ 5.2.2 Required States and
 Properties](#ref-for-dfn-role-17 "§ 5.2.2 Required States and Properties")
- [§ 5.2.3 Supported States and
 Properties](#ref-for-dfn-role-18 "§ 5.2.3 Supported States and Properties")
- [§ 5.2.4 Inherited States and
 Properties](#ref-for-dfn-role-19 "§ 5.2.4 Inherited States and Properties")
- [§ 5.2.5 Prohibited States and
 Properties](#ref-for-dfn-role-20 "§ 5.2.5 Prohibited States and Properties")
- [§ 5.2.6 Allowed Accessibility Child
 Roles](#ref-for-dfn-role-21 "§ 5.2.6 Allowed Accessibility Child Roles")
- [§ 5.2.7 Required Accessibility Parent
 Role](#ref-for-dfn-role-22 "§ 5.2.7 Required Accessibility Parent Role")
- [§ 5.2.8 Name From](#ref-for-dfn-role-23 "§ 5.2.8 Name From")
- [§ 5.3 Categorization of
 Roles](#ref-for-dfn-role-24 "§ 5.3 Categorization of Roles")
- [§ 5.3.1 Abstract
 Roles](#ref-for-dfn-role-25 "§ 5.3.1 Abstract Roles")
- [§ 5.3.3 Document Structure
 Roles](#ref-for-dfn-role-26 "§ 5.3.3 Document Structure Roles")
- [§ 5.3.4 Landmark
 Roles](#ref-for-dfn-role-27 "§ 5.3.4 Landmark Roles")
- [§ 5.3.5 Live Region
 Roles](#ref-for-dfn-role-28 "§ 5.3.5 Live Region Roles")
- [§ 5.3.6 Window Roles](#ref-for-dfn-role-29 "§ 5.3.6 Window Roles")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-role-30 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-role-31 "Reference 2")
 [(3)](#ref-for-dfn-role-32 "Reference 3")
 [(4)](#ref-for-dfn-role-33 "Reference 4")
 [(5)](#ref-for-dfn-role-34 "Reference 5")
 [(6)](#ref-for-dfn-role-35 "Reference 6")
 [(7)](#ref-for-dfn-role-36 "Reference 7")
 [(8)](#ref-for-dfn-role-37 "Reference 8")
 [(9)](#ref-for-dfn-role-38 "Reference 9")
 [(10)](#ref-for-dfn-role-39 "Reference 10")
 [(11)](#ref-for-dfn-role-40 "Reference 11")
 [(12)](#ref-for-dfn-role-41 "Reference 12")
 [(13)](#ref-for-dfn-role-42 "Reference 13")
 [(14)](#ref-for-dfn-role-43 "Reference 14")
 [(15)](#ref-for-dfn-role-44 "Reference 15")
 [(16)](#ref-for-dfn-role-45 "Reference 16")
 [(17)](#ref-for-dfn-role-46 "Reference 17")
 [(18)](#ref-for-dfn-role-47 "Reference 18")
 [(19)](#ref-for-dfn-role-48 "Reference 19")
 [(20)](#ref-for-dfn-role-49 "Reference 20")
 [(21)](#ref-for-dfn-role-50 "Reference 21")
 [(22)](#ref-for-dfn-role-51 "Reference 22")
 [(23)](#ref-for-dfn-role-52 "Reference 23")
 [(24)](#ref-for-dfn-role-53 "Reference 24")
 [(25)](#ref-for-dfn-role-54 "Reference 25")
 [(26)](#ref-for-dfn-role-55 "Reference 26")
 [(27)](#ref-for-dfn-role-56 "Reference 27")
 [(28)](#ref-for-dfn-role-57 "Reference 28")
 [(29)](#ref-for-dfn-role-58 "Reference 29")
 [(30)](#ref-for-dfn-role-59 "Reference 30")
 [(31)](#ref-for-dfn-role-60 "Reference 31")
 [(32)](#ref-for-dfn-role-61 "Reference 32")
 [(33)](#ref-for-dfn-role-62 "Reference 33")
 [(34)](#ref-for-dfn-role-63 "Reference 34")
 [(35)](#ref-for-dfn-role-64 "Reference 35")
 [(36)](#ref-for-dfn-role-65 "Reference 36")
 [(37)](#ref-for-dfn-role-66 "Reference 37")
 [(38)](#ref-for-dfn-role-67 "Reference 38")
 [(39)](#ref-for-dfn-role-68 "Reference 39")
 [(40)](#ref-for-dfn-role-69 "Reference 40")
 [(41)](#ref-for-dfn-role-70 "Reference 41")
 [(42)](#ref-for-dfn-role-71 "Reference 42")
 [(43)](#ref-for-dfn-role-72 "Reference 43")
 [(44)](#ref-for-dfn-role-73 "Reference 44")
 [(45)](#ref-for-dfn-role-74 "Reference 45")
 [(46)](#ref-for-dfn-role-75 "Reference 46")
 [(47)](#ref-for-dfn-role-76 "Reference 47")
 [(48)](#ref-for-dfn-role-77 "Reference 48")
 [(49)](#ref-for-dfn-role-78 "Reference 49")
 [(50)](#ref-for-dfn-role-79 "Reference 50")
 [(51)](#ref-for-dfn-role-80 "Reference 51")
 [(52)](#ref-for-dfn-role-81 "Reference 52")
 [(53)](#ref-for-dfn-role-82 "Reference 53")
 [(54)](#ref-for-dfn-role-83 "Reference 54")
 [(55)](#ref-for-dfn-role-84 "Reference 55")
- [§ 6.1 Clarification of States versus
 Properties](#ref-for-dfn-role-85 "§ 6.1 Clarification of States versus Properties")
- [§ 6.5 Global States and
 Properties](#ref-for-dfn-role-86 "§ 6.5 Global States and Properties")
- [§ 6.6.2 Live Region
 Attributes](#ref-for-dfn-role-87 "§ 6.6.2 Live Region Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-role-88 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-role-89 "Reference 2")
 [(3)](#ref-for-dfn-role-90 "Reference 3")
 [(4)](#ref-for-dfn-role-91 "Reference 4")
- [§ 8. Implementation in Host
 Languages](#ref-for-dfn-role-92 "§ 8. Implementation in Host Languages")
- [§ 8.1 Role Attribute](#ref-for-dfn-role-93 "§ 8.1 Role Attribute")
 [(2)](#ref-for-dfn-role-94 "Reference 2")
- [§ 9.1 Roles](#ref-for-dfn-role-95 "§ 9.1 Roles")
 [(2)](#ref-for-dfn-role-96 "Reference 2")
 [(3)](#ref-for-dfn-role-97 "Reference 3")
- [§ 9.2 States and
 Properties](#ref-for-dfn-role-98 "§ 9.2 States and Properties")

[Permalink](#dfn-semantics)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-semantics-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 2. Important
 Terms](#ref-for-dfn-semantics-2 "§ 2. Important Terms")
- [§ 4. Using WAI-ARIA](#ref-for-dfn-semantics-3 "§ 4. Using WAI-ARIA")
- [§ 4.3.1 Information for
 Authors](#ref-for-dfn-semantics-4 "§ 4.3.1 Information for Authors")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-semantics-5 "§ 5.4 Definition of Roles")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-semantics-6 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
- [§ 8.4 Implicit WAI-ARIA
 Semantics](#ref-for-dfn-semantics-7 "§ 8.4 Implicit WAI-ARIA Semantics")
- [§ 8.5 Conflicts with Host Language
 Semantics](#ref-for-dfn-semantics-8 "§ 8.5 Conflicts with Host Language Semantics")
- [§ 8.6 State and Property Attribute
 Processing](#ref-for-dfn-semantics-9 "§ 8.6 State and Property Attribute Processing")
- [§ 8.7 CSS Selectors](#ref-for-dfn-semantics-10 "§ 8.7 CSS Selectors")

[Permalink](#dfn-state)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-state-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 1.5.1 Authoring
 Tools](#ref-for-dfn-state-2 "§ 1.5.1 Authoring Tools")
- [§ 2. Important Terms](#ref-for-dfn-state-3 "§ 2. Important Terms")
 [(2)](#ref-for-dfn-state-4 "Reference 2")
 [(3)](#ref-for-dfn-state-5 "Reference 3")
 [(4)](#ref-for-dfn-state-6 "Reference 4")
 [(5)](#ref-for-dfn-state-7 "Reference 5")
- [§ 3.3 Assistive Technology Notifications Communicated to Web
 Applications](#ref-for-dfn-state-8 "§ 3.3 Assistive Technology Notifications Communicated to Web Applications")
- [§ 4. Using WAI-ARIA](#ref-for-dfn-state-9 "§ 4. Using WAI-ARIA")
- [§ 4.1 WAI-ARIA Roles](#ref-for-dfn-state-10 "§ 4.1 WAI-ARIA Roles")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-state-11 "§ 4.2 WAI-ARIA States and Properties")
- [§ 5.2.2 Required States and
 Properties](#ref-for-dfn-state-12 "§ 5.2.2 Required States and Properties")
- [§ 5.2.3 Supported States and
 Properties](#ref-for-dfn-state-13 "§ 5.2.3 Supported States and Properties")
- [§ 5.2.4 Inherited States and
 Properties](#ref-for-dfn-state-14 "§ 5.2.4 Inherited States and Properties")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-state-15 "§ 5.4 Definition of Roles")
- [§ 6.1 Clarification of States versus
 Properties](#ref-for-dfn-state-16 "§ 6.1 Clarification of States versus Properties")
- [§ 6.2.1 Related
 Concepts](#ref-for-dfn-state-17 "§ 6.2.1 Related Concepts")
- [§ 6.2.2 Used in Roles](#ref-for-dfn-state-18 "§ 6.2.2 Used in Roles")
- [§ 6.2.3 Inherits into
 Roles](#ref-for-dfn-state-19 "§ 6.2.3 Inherits into Roles")
- [§ 6.2.4 Value](#ref-for-dfn-state-20 "§ 6.2.4 Value")
- [§ 6.4 Translatable
 Attributes](#ref-for-dfn-state-21 "§ 6.4 Translatable Attributes")
- [§ 6.5 Global States and
 Properties](#ref-for-dfn-state-22 "§ 6.5 Global States and Properties")
- [§ 6.6.1 Widget
 Attributes](#ref-for-dfn-state-23 "§ 6.6.1 Widget Attributes")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-state-24 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-state-25 "Reference 2")
 [(3)](#ref-for-dfn-state-26 "Reference 3")
 [(4)](#ref-for-dfn-state-27 "Reference 4")
 [(5)](#ref-for-dfn-state-28 "Reference 5")
 [(6)](#ref-for-dfn-state-29 "Reference 6")
 [(7)](#ref-for-dfn-state-30 "Reference 7")
- [§ 8. Implementation in Host
 Languages](#ref-for-dfn-state-31 "§ 8. Implementation in Host Languages")

[Permalink](#dfn-target-element)

**Referenced in:**

- Not referenced in this document.

[Permalink](#dfn-unicode-braille)

**Referenced in:**

- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-unicode-braille-1 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-unicode-braille-2 "Reference 2")
 [(3)](#ref-for-dfn-unicode-braille-3 "Reference 3")
 [(4)](#ref-for-dfn-unicode-braille-4 "Reference 4")
 [(5)](#ref-for-dfn-unicode-braille-5 "Reference 5")
 [(6)](#ref-for-dfn-unicode-braille-6 "Reference 6")

[Permalink](#dfn-widget)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-widget-1 "§ 1.1 Rich Internet Application Accessibility")
 [(2)](#ref-for-dfn-widget-2 "Reference 2")
 [(3)](#ref-for-dfn-widget-3 "Reference 3")
- [§ 1.5.2 Testing Practices and
 Tools](#ref-for-dfn-widget-4 "§ 1.5.2 Testing Practices and Tools")
- [§ 2. Important Terms](#ref-for-dfn-widget-5 "§ 2. Important Terms")
- [§ 4.2 WAI-ARIA States and
 Properties](#ref-for-dfn-widget-6 "§ 4.2 WAI-ARIA States and Properties")
- [§ 4.3 Managing Focus and Supporting Keyboard
 Navigation](#ref-for-dfn-widget-7 "§ 4.3 Managing Focus and Supporting Keyboard Navigation")
 [(2)](#ref-for-dfn-widget-8 "Reference 2")
- [§ 5.1.3 Related
 Concepts](#ref-for-dfn-widget-9 "§ 5.1.3 Related Concepts")
- [§ 5.2 Characteristics of
 Roles](#ref-for-dfn-widget-10 "§ 5.2 Characteristics of Roles")
- [§ 5.3 Categorization of
 Roles](#ref-for-dfn-widget-11 "§ 5.3 Categorization of Roles")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-widget-12 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-widget-13 "Reference 2")
 [(3)](#ref-for-dfn-widget-14 "Reference 3")
 [(4)](#ref-for-dfn-widget-15 "Reference 4")
 [(5)](#ref-for-dfn-widget-16 "Reference 5")
 [(6)](#ref-for-dfn-widget-17 "Reference 6")
 [(7)](#ref-for-dfn-widget-18 "Reference 7")
 [(8)](#ref-for-dfn-widget-19 "Reference 8")
 [(9)](#ref-for-dfn-widget-20 "Reference 9")
 [(10)](#ref-for-dfn-widget-21 "Reference 10")
 [(11)](#ref-for-dfn-widget-22 "Reference 11")
 [(12)](#ref-for-dfn-widget-23 "Reference 12")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-widget-24 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-widget-25 "Reference 2")
 [(3)](#ref-for-dfn-widget-26 "Reference 3")
 [(4)](#ref-for-dfn-widget-27 "Reference 4")
 [(5)](#ref-for-dfn-widget-28 "Reference 5")
 [(6)](#ref-for-dfn-widget-29 "Reference 6")
 [(7)](#ref-for-dfn-widget-30 "Reference 7")
 [(8)](#ref-for-dfn-widget-31 "Reference 8")
 [(9)](#ref-for-dfn-widget-32 "Reference 9")

[Permalink](#dfn-prohibited)

**Referenced in:**

- [§ 9.3 Presentational Roles Conflict
 Resolution](#ref-for-dfn-prohibited-1 "§ 9.3 Presentational Roles Conflict Resolution")

[Permalink](#dfn-token-list)

**Referenced in:**

- [§ 8.1 Role
 Attribute](#ref-for-dfn-token-list-1 "§ 8.1 Role Attribute")

[Permalink](#dfn-global)

**Referenced in:**

- [§ 9.3 Presentational Roles Conflict
 Resolution](#ref-for-dfn-global-1 "§ 9.3 Presentational Roles Conflict Resolution")
 [(2)](#ref-for-dfn-global-2 "Reference 2")

[Permalink](#dfn-accessibility-tree)
[exported]

**Referenced in:**

- [§ 2. Important
 Terms](#ref-for-dfn-accessibility-tree-1 "§ 2. Important Terms")
- [§ 4.1 WAI-ARIA
 Roles](#ref-for-dfn-accessibility-tree-2 "§ 4.1 WAI-ARIA Roles")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-accessibility-tree-3 "§ 5.4 Definition of Roles")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-accessibility-tree-4 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-accessibility-tree-5 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-tree-6 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-tree-7 "Reference 4")
- [§ 7. Accessibility
 Tree](#ref-for-dfn-accessibility-tree-8 "§ 7. Accessibility Tree")
 [(2)](#ref-for-dfn-accessibility-tree-9 "Reference 2")
- [§ 7.1 Excluding Elements from the Accessibility
 Tree](#ref-for-dfn-accessibility-tree-10 "§ 7.1 Excluding Elements from the Accessibility Tree")
- [§ 7.2 Including Elements in the Accessibility
 Tree](#ref-for-dfn-accessibility-tree-11 "§ 7.2 Including Elements in the Accessibility Tree")
- [§ 7.3 Relationships in the Accessibility
 Tree](#ref-for-dfn-accessibility-tree-12 "§ 7.3 Relationships in the Accessibility Tree")
 [(2)](#ref-for-dfn-accessibility-tree-13 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-tree-14 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-tree-15 "Reference 4")

[Permalink](#dfn-accessibility-child)
[exported]

**Referenced in:**

- [§ 5.2.6 Allowed Accessibility Child
 Roles](#ref-for-dfn-accessibility-child-1 "§ 5.2.6 Allowed Accessibility Child Roles")
 [(2)](#ref-for-dfn-accessibility-child-2 "Reference 2")
- [§ 5.2.7 Required Accessibility Parent
 Role](#ref-for-dfn-accessibility-child-3 "§ 5.2.7 Required Accessibility Parent Role")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-accessibility-child-4 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-accessibility-child-5 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-child-6 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-child-7 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-child-8 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-child-9 "Reference 6")
 [(7)](#ref-for-dfn-accessibility-child-10 "Reference 7")
 [(8)](#ref-for-dfn-accessibility-child-11 "Reference 8")
 [(9)](#ref-for-dfn-accessibility-child-12 "Reference 9")
 [(10)](#ref-for-dfn-accessibility-child-13 "Reference 10")
 [(11)](#ref-for-dfn-accessibility-child-14 "Reference 11")
 [(12)](#ref-for-dfn-accessibility-child-15 "Reference 12")
 [(13)](#ref-for-dfn-accessibility-child-16 "Reference 13")
 [(14)](#ref-for-dfn-accessibility-child-17 "Reference 14")
 [(15)](#ref-for-dfn-accessibility-child-18 "Reference 15")
 [(16)](#ref-for-dfn-accessibility-child-19 "Reference 16")
 [(17)](#ref-for-dfn-accessibility-child-20 "Reference 17")
 [(18)](#ref-for-dfn-accessibility-child-21 "Reference 18")
 [(19)](#ref-for-dfn-accessibility-child-22 "Reference 19")
 [(20)](#ref-for-dfn-accessibility-child-23 "Reference 20")
 [(21)](#ref-for-dfn-accessibility-child-24 "Reference 21")
 [(22)](#ref-for-dfn-accessibility-child-25 "Reference 22")
 [(23)](#ref-for-dfn-accessibility-child-26 "Reference 23")
 [(24)](#ref-for-dfn-accessibility-child-27 "Reference 24")
 [(25)](#ref-for-dfn-accessibility-child-28 "Reference 25")
 [(26)](#ref-for-dfn-accessibility-child-29 "Reference 26")
 [(27)](#ref-for-dfn-accessibility-child-30 "Reference 27")
 [(28)](#ref-for-dfn-accessibility-child-31 "Reference 28")
 [(29)](#ref-for-dfn-accessibility-child-32 "Reference 29")
 [(30)](#ref-for-dfn-accessibility-child-33 "Reference 30")
 [(31)](#ref-for-dfn-accessibility-child-34 "Reference 31")
 [(32)](#ref-for-dfn-accessibility-child-35 "Reference 32")
 [(33)](#ref-for-dfn-accessibility-child-36 "Reference 33")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-accessibility-child-37 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-accessibility-child-38 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-child-39 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-child-40 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-child-41 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-child-42 "Reference 6")

[Permalink](#dfn-accessibility-descendant)
[exported]

**Referenced in:**

- [§ 4.3.2 Information for User
 Agents](#ref-for-dfn-accessibility-descendant-1 "§ 4.3.2 Information for User Agents")
 [(2)](#ref-for-dfn-accessibility-descendant-2 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-descendant-3 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-descendant-4 "Reference 4")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-accessibility-descendant-5 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-accessibility-descendant-6 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-descendant-7 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-descendant-8 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-descendant-9 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-descendant-10 "Reference 6")
 [(7)](#ref-for-dfn-accessibility-descendant-11 "Reference 7")
 [(8)](#ref-for-dfn-accessibility-descendant-12 "Reference 8")
 [(9)](#ref-for-dfn-accessibility-descendant-13 "Reference 9")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-accessibility-descendant-14 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-accessibility-descendant-15 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-descendant-16 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-descendant-17 "Reference 4")
- [§ 9.2 States and
 Properties](#ref-for-dfn-accessibility-descendant-18 "§ 9.2 States and Properties")

[Permalink](#dfn-accessibility-parent)
[exported]

**Referenced in:**

- [§ 5.2.7 Required Accessibility Parent
 Role](#ref-for-dfn-accessibility-parent-1 "§ 5.2.7 Required Accessibility Parent Role")
- [§ 5.4 Definition of
 Roles](#ref-for-dfn-accessibility-parent-2 "§ 5.4 Definition of Roles")
 [(2)](#ref-for-dfn-accessibility-parent-3 "Reference 2")
 [(3)](#ref-for-dfn-accessibility-parent-4 "Reference 3")
 [(4)](#ref-for-dfn-accessibility-parent-5 "Reference 4")
 [(5)](#ref-for-dfn-accessibility-parent-6 "Reference 5")
 [(6)](#ref-for-dfn-accessibility-parent-7 "Reference 6")
 [(7)](#ref-for-dfn-accessibility-parent-8 "Reference 7")
 [(8)](#ref-for-dfn-accessibility-parent-9 "Reference 8")
- [§ 6.8 Definitions of States and Properties (all aria-\*
 attributes)](#ref-for-dfn-accessibility-parent-10 "§ 6.8 Definitions of States and Properties (all aria-* attributes)")
 [(2)](#ref-for-dfn-accessibility-parent-11 "Reference 2")

[Permalink](#dfn-host-language)
[exported]

**Referenced in:**

- [§ 1.1 Rich Internet Application
 Accessibility](#ref-for-dfn-host-language-1 "§ 1.1 Rich Internet Application Accessibility")
- [§ 1.4 Co-Evolution of WAI-ARIA and Host
 Languages](#ref-for-dfn-host-language-2 "§ 1.4 Co-Evolution of WAI-ARIA and Host Languages")
- [§ 8. Implementation in Host
 Languages](#ref-for-dfn-host-language-3 "§ 8. Implementation in Host Languages")

[Permalink](#dom-ariamixin)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-1 "§ 10.1 Interface Mixin ARIAMixin")
 [(2)](#ref-for-dom-ariamixin-2 "Reference 2")

[Permalink](#dom-ariamixin-role)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-role-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaactivedescendantelement)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaactivedescendantelement-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaatomic)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaatomic-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaautocomplete)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaautocomplete-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariabraillelabel)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariabraillelabel-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariabrailleroledescription)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariabrailleroledescription-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariabusy)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariabusy-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariachecked)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariachecked-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacolcount)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacolcount-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacolindex)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacolindex-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacolindextext)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacolindextext-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacolspan)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacolspan-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacontrolselements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacontrolselements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariacurrent)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariacurrent-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariadescribedbyelements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariadescribedbyelements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariadescription)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariadescription-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariadetailselements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariadetailselements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariadisabled)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariadisabled-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaerrormessageelements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaerrormessageelements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaexpanded)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaexpanded-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaflowtoelements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaflowtoelements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariahaspopup)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariahaspopup-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariahidden)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariahidden-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariainvalid)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariainvalid-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariakeyshortcuts)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariakeyshortcuts-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-arialabel)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-arialabel-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-arialabelledbyelements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-arialabelledbyelements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-arialevel)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-arialevel-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-arialive)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-arialive-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariamodal)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariamodal-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariamultiline)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariamultiline-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariamultiselectable)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariamultiselectable-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaorientation)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaorientation-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaownselements)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaownselements-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaplaceholder)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaplaceholder-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaposinset)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaposinset-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariapressed)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariapressed-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariareadonly)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariareadonly-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarelevant)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarelevant-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarequired)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarequired-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaroledescription)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaroledescription-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarowcount)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarowcount-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarowindex)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarowindex-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarowindextext)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarowindextext-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariarowspan)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariarowspan-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariaselected)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariaselected-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariasetsize)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariasetsize-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariasort)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariasort-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariavaluemax)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariavaluemax-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariavaluemin)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariavaluemin-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariavaluenow)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariavaluenow-1 "§ 10.1 Interface Mixin ARIAMixin")

[Permalink](#dom-ariamixin-ariavaluetext)
[exported]
[IDL](#webidl-316093145 "Jump to IDL declaration")

**Referenced in:**

- [§ 10.1 Interface Mixin
 ARIAMixin](#ref-for-dom-ariamixin-ariavaluetext-1 "§ 10.1 Interface Mixin ARIAMixin")
