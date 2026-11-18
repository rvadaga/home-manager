# markdown and Mermaid previews

Shared CSS gives Markdown previews Fira Sans prose at 15 px, diagram labels at
14 px, semibold flowchart labels, smaller edge labels and rounded boxes. Code
keeps the editor's monospace font. The light and dark palettes follow the saved
desktop appearance: white or `#1e1e1e` surfaces with blue accents.

## VS Code

Home Manager installs a local stylesheet extension using the supported
`markdown.previewStyles` contribution. It has no executable code and adds no
renderer. This lets local styles load in ordinary Markdown previews without
changing their security policy or fetching a stylesheet from the network.

Use VS Code 1.121 or newer and its built-in Mermaid renderer. The extension
defaults `markdown-mermaid.lightModeTheme` and `markdown-mermaid.darkModeTheme`
to `vscode`, and `mermaidChart.markdownPreview.enabled` to `false`; explicit user
settings take precedence. Mermaid Chart's other features remain available.
Disable the redundant Markdown Preview Mermaid Support extension
when the built-in renderer is enabled. The old `markdown-mermaid.fontFamily`
setting is not supported by the built-in renderer.

The preview-only CSS variables supply the font and colors before Mermaid lays
out a diagram. Workspace settings and custom styles remain user-controlled.
Profiles inheriting default extensions receive this style; independent profiles
can install the same VSIX separately. Settings Sync is left unchanged.

## IntelliJ IDEA

In Languages & Frameworks → Markdown → Custom CSS, enable **CSS rules** and
paste the contents of `~/.config/editor-preview/jetbrains-dark.css` or
`jetbrains-light.css`. Use the dark file for a dark IDE theme. Leave **Load from**
disabled: current versions reject stylesheets outside the project, including
managed files in the Nix store. Inline rules need no external font service.
Keep any existing custom CSS unless combining it is intentional. IntelliJ
stores custom CSS per project; File → New Projects Setup → Settings for New
Projects can set the same default without rewriting existing projects.
After changing the managed CSS, paste the updated contents into each opted-in
project and the new-project default. The IDE owns these settings while running.

The installed Mermaid plugin only exposes a theme selector. CSS can match
labels, colors and corners, but does not expose the desktop app's layout hook
for minimum node height, padding or spacing. Node bounds remain computed by the
renderer. CSS must never force a final SVG box to a size that clips its label.
Sequence geometry may differ because its text measurements use renderer
configuration independently of preview CSS.

## checking a change

Open `~/.config/editor-preview/fixture.md` in the real Markdown preview. Check
headings, prose, tables, code, a flowchart, a sequence diagram and both long-label
cases. Narrow the preview and check that diagrams can scroll. Inspect the
rendered text, not just settings values. Refresh only the preview when needed;
there is no reason to restart an editor with unsaved work.

The 14/13 px flowchart typography and 16 px corners come from the installed
desktop renderer. Prose line-height 1.6 retains VS Code's existing preview
convention; it is not a claim of exact parity. The 60 px minimum height used by
the desktop renderer is intentionally not simulated after SVG layout.
