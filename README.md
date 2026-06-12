# akai-widget

A compact AI chat widget for the KDE Plasma 6 desktop, powered by Opencode.

- SSE streaming responses
- Multiple AI model providers (OpenCode, Ollama, Google, GitHub Copilot, Horde)
- Persistent chat history and model selection
- Manage the Opencode server process from the widget panel
- Resizable popup, dark theme, keyboard shortcuts

## Install

```bash
./install.sh
```

Right-click panel > Add Widgets > AKAI Widget

Or test with `plasmoidviewer -a akai-widget`

## Requirements

- KDE Plasma 6
- Qt 6
- [Opencode](https://github.com/frectonz/opencode) CLI
- CMake 3.16+ with ECM
