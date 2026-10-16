<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->

# How to write documentation

Write in Simplified Technical English (ASD-STE100) and American English. Put the main point first. Run `make docs-check` before you commit.

## Rules that the tool checks

`make docs-check` runs `tools/doc_lint.mojo` on `README.md`, `CONTRIBUTING.md` and every page in `docs/wiki/`. It prints one line for each problem. It fails when it finds one or more problems.

- **Sentence length.** A sentence has 25 words or fewer. A sentence ends at a full stop, a question mark or an exclamation mark that comes before a space or the end of the text.
- **Paragraph length.** A paragraph has 6 sentences or fewer. A list item has no sentence limit, but each of its sentences has the word limit.
- **Must and can.** The words "should", "may" and "might" are not permitted. Use "must" for a requirement and "can" for a possibility.
- **American spelling.** The tool has a list of about 80 British spellings, with the American spelling for each. Examples of the American forms are "color", "behavior", "license", "analyze" and "optimize".
- **Wiki links.** Each link to a wiki page must name a page that exists in `docs/wiki/`. Each anchor must name a heading that exists on that page.

## What the tool does not check

The tool skips code blocks, tables, headings, badges and HTML comments. It also skips lines that start with `<` or `---`. In a sentence, inline code counts as one word, and a link target does not count.

The tool cannot check every rule. You must also obey these rules:

- Write one instruction in each sentence.
- Use the active voice.
- Use one word for one meaning. Do not change the word for a thing in one page.
- Put the main point first, in each page and in each section.
- Keep the Diátaxis types apart, as the next section tells.

## Diátaxis types

Each page has one type. Do not mix the types in one page.

- A **tutorial** teaches. It takes a new user through one complete task.
- A **how-to guide** solves one task for a user who knows the basics. Its title starts with "How to".
- A **reference** states facts: the API, the options, the limits. It does not teach.
- An **explanation** tells why. It gives the reasons for a design.

## Links

Link to a wiki page from a wiki page with the page name only, such as `[Language](Language)`. Add an anchor for a heading, such as `Language#lexer`.

Link to a wiki page from `README.md` or `CONTRIBUTING.md` with the full URL. The URL starts with `https://github.com/SethKitchen/MojoGraphQL/wiki/`. The tool checks both forms.

An anchor is the GitHub slug of the heading. Write the heading in lowercase, remove the punctuation, and change each space to a hyphen. When two headings have the same slug, the second gets `-1`, the third `-2`.

## File header

Start each Markdown file with the copyright comment:

```markdown
<!--
Copyright (c) 2026 Seth Kitchen, PE
SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
-->
```

## Fix a problem

Each problem line starts with the file and the line number of the paragraph. Make the sentence shorter, or split the paragraph. Change "should" to "must" or to "can". Write the American spelling that the tool gives.
