# Promptly

Promptly keeps a tiny floating “P” bubble on top of every screen so you can refine prompts without losing focus. Paste a draft, click **Improve**, and receive a cleaned version ready for ChatGPT, Claude, or any other model. The app is built with Swift + AppKit and uses Google **Gemini** for rewriting prompts.

---

## Features

- **Floating bubble HUD** – always on top, draggable, snaps to edges, and toggles the chat panel.
- **Chat-style prompt improver** – editable input/output, **Improve** + **Copy** buttons, and optional auto-copy.
- **Prompt styles** – built-in options (`Default`, `Concise`, `Detailed`, `Code Helper`) plus a Manage Styles window for custom presets with Gemini-assisted description polishing.
- **History** – quick dropdown of the last 10 prompt/output pairs that restores input, output, and style.
- **Menu bar integration** – status bar item mirrors the bubble toggle.
- **Resizable & persistent** – chat panel remembers its size across runs.

---

## Requirements

- Recent macOS release.
- Xcode 15+ (project created with 15.1 / Swift 5.10 toolchain).
- Google **Gemini API key** (create via Google AI Studio or Google Cloud).

---

## Getting Started

1. **Clone or fork**

   ```bash
   git clone https://github.com/venaxin/Promptly.git
   cd Promptly
   ```
2. **Open the project**

   Open `Promptly.xcodeproj` in Xcode.
3. **Configure the Gemini key**

   - Create a non-shared scheme: _Product → Scheme → Manage Schemes…_, select `Promptly`, uncheck **Shared**.
   - Add the environment variable: _Product → Scheme → Edit Scheme… → Run → Arguments_, then under **Environment Variables** add`GEMINI_API_KEY = <your-key>` and check it.
   - Never commit secrets—rotate the key if you do.
4. **Build & run**

   - Select the `Promptly` scheme.
   - Hit **⌘R**. You should see the floating bubble plus a status-bar icon.

---

## Using Promptly

### Floating bubble

- Drag anywhere to move; release to snap to the nearest edge.
- Works across desktops, fullscreen apps, and normal windows.
- Clicking toggles the chat panel.

### Chat panel workflow

1. Paste or type your prompt in the top text view.
2. Choose a style (or create your own).
3. Optionally enable **Auto-copy after Improve**.
4. Click **Improve** to call Gemini.
5. Read or copy the rewritten prompt from the bottom text view.

### Styles & Manage Styles

- The style dropdown drives how Gemini rewrites prompts.
- Click **Manage** to open the style editor:
  - Add/remove styles (built-in `Default` is protected).
  - Edit the name/description.
  - Use **Improve description** to get a Gemini suggestion.
  - Swap between original/improved text, then **Save style**.
- Styles persist via `UserDefaults`.

### History

- The history popup stores the latest 10 runs.
- Selecting an entry restores the input, output, and style so you can iterate quickly.

### Resizing & preferences

- Chat/Manage windows are resizable with sensible minimums.
- Promptly remembers the last chat panel size.
- Feel free to customize colors, fonts, bubble size, or even swap the backend in `GeminiClient.swift`.

---

## Notes on API usage

- All requests are sent over HTTPS to Gemini.
- Keep your API key secret (env vars or private schemes).
- Rotate any key that ever leaks.

---

## Contributing

- Fork the repo, tweak the bundle ID if needed, and follow the setup steps.
- Useful contributions: better error handling, more built-in styles, keyboard shortcuts, or a preferences window.
- Open issues/PRs on GitHub.

---

## License

MIT License.

Promptly is a compact HUD for rewriting prompts with styles, history, and auto-copy so you can iterate without breaking flow.
