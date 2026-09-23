# Markdown Guide

A quick reference for everything Markly understands. Each section shows the syntax first, then what it becomes. Open the preview (⌥⌘P) side by side and scroll — it follows along.

## Headings

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6

Use one `#` for the title of a note and `##` for its sections. Deeper levels are for sub-sections; most notes never need more than three.

## Emphasis

```markdown
**bold**, *italic*, ***both***, ~~strikethrough~~ and ==highlight==
```

**bold**, *italic*, ***both***, ~~strikethrough~~ and ==highlight==

Underscores work too: __bold__ and _italic_. Markly recognises either style, but sticking to one keeps a note tidy.

## Paragraphs and line breaks

A paragraph is one or more lines of text separated from the next paragraph by a blank line. Lines that follow each other directly are joined into a single paragraph in the preview, which is handy when you like to write one sentence per line.

This sentence starts a new paragraph because there's a blank line above it.

Long paragraphs wrap at the editor width you choose in the editor panel. Try making the editor narrower or wider while you read this: a comfortable line is somewhere between fifty and seventy-five characters, which is why the default width isn't the full window.

## Lists

### Bulleted

```markdown
- Apples
- Oranges
    - Blood oranges
    - Navel oranges
- Pears
```

- Apples
- Oranges
    - Blood oranges
    - Navel oranges
- Pears

### Numbered

```markdown
1. Preheat the oven
2. Mix the dry ingredients
3. Add the wet ingredients
4. Bake for 25 minutes
```

1. Preheat the oven
2. Mix the dry ingredients
3. Add the wet ingredients
4. Bake for 25 minutes

The numbers don't have to be right — Markdown renumbers them — but Markly keeps them in order as you press Return anyway.

### Tasks

```markdown
- [x] Write the outline
- [ ] Draft the introduction
- [ ] Ask for feedback
```

- [x] Write the outline
- [ ] Draft the introduction
- [ ] Ask for feedback

Click a box in the editor to tick it.

## Links and images

```markdown
[Link text](https://example.com)
[Another note](Projects/Roadmap.md)
![Alt text](images/markly.png)
```

[Link text](https://example.com) · [Another note](Projects/Roadmap.md)

![Alt text](images/markly.png)

An image on a line of its own is drawn right in the editor. Choose small, medium or full width — or turn previews off — with the image tile in the editor panel. Relative paths are resolved from the note's folder, so keep images in an `images` folder next to your notes.

## Quotes

```markdown
> The best way to predict the future is to invent it.
> — Alan Kay
```

> The best way to predict the future is to invent it.
> — Alan Kay

## Code

Inline: wrap code in backticks, like `let x = 42`.

Blocks: fence them with three backticks and name the language for colouring in the preview.

```javascript
const notes = await fetch("/api/notes").then((r) => r.json());
for (const note of notes) {
  console.log(`${note.title} — ${note.words} words`);
}
```

```json
{
  "name": "Markly",
  "platform": "macOS 26",
  "license": "MIT"
}
```

```css
.note {
  max-width: 720px;
  margin: 0 auto;
  line-height: 1.6;
}
```

## Tables

```markdown
| Planet  | Moons | Day length |
| ------- | ----: | ---------- |
| Mercury |     0 | 59 days    |
| Earth   |     1 | 24 hours   |
| Mars    |     2 | 24.6 hours |
```

| Planet  | Moons | Day length  |
| ------- | ----: | ----------- |
| Mercury |     0 | 59 days     |
| Venus   |     0 | 243 days    |
| Earth   |     1 | 24 hours    |
| Mars    |     2 | 24.6 hours  |
| Jupiter |    95 | 9.9 hours   |
| Saturn  |   146 | 10.7 hours  |
| Uranus  |    28 | 17.2 hours  |
| Neptune |    16 | 16.1 hours  |

A colon on the right of the divider (`----:`) right-aligns a column.

## Math

Inline math goes between single dollar signs: `$a^2 + b^2 = c^2$` becomes $a^2 + b^2 = c^2$.

Display math goes between double dollar signs on their own lines:

$$
\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \cdot \mathbf{B} &= 0 \\
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned}
$$

Math is typeset with KaTeX in the preview. If you turn off network scripts in Settings › Privacy, the preview shows the source instead.

## Horizontal rules

Three dashes on their own line draw a divider:

---

Use them to separate parts of a long note, or to mark a change of topic.

## Escaping

Put a backslash in front of a character to show it literally: \*not italic\*, \# not a heading, \`not code\`.

## Tips

1. **Hide or show syntax.** The syntax control in the editor panel switches between *Show*, *Auto* (visible only on the line you're editing) and *Hide*.
2. **Change the typeface.** Sans, serif or mono — the *Aa* tile cycles through them.
3. **Find in the note.** ⌘F opens the find bar; ⌘G jumps to the next match.
4. **Filter the sidebar.** ⇧⌘L filters notes by name across every folder.
5. **Export.** File › Export as HTML or PDF, or print with ⌘P.

That's all of Markdown you'll need day to day.
