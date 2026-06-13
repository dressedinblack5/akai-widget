# akai-widget

A compact AI chat widget for the KDE Plasma 6 desktop, powered by [Opencode](https://github.com/sst/opencode).

- Multi-turn conversations with history injection across sessions
- Pin-to-top (window stays above others, persisted across sessions)
- Auto-starts the Opencode server on widget load with retry
- Multiple AI model providers (Opencode, Ollama, Google, GitHub Copilot, Horde)
- Smart model selection — prefers providers with API keys configured, falls back to known working models
- Model guard — prevents sending with no model selected, showing a clear error instead of a stuck spinner
- Fast-fail poller — detects silent model failures and recovers in 15s (down from 60s)
- Smart scroll-to-bottom on new messages
- Persistent chat history and model selection
- Manage the Opencode server process from the widget panel
- Resizable popup with configurable dimensions
- Keyboard shortcuts (Ctrl+N for new chat)

## Install

```bash
./install.sh
```

Right-click panel > Add Widgets > AKAI Widget

Or test with `plasmoidviewer -a akai-widget`

## Requirements

- KDE Plasma 6
- Qt 6 with QtQuick
- [Opencode CLI](https://github.com/sst/opencode) in PATH
- CMake 3.16+ with Extra CMake Modules (ECM)
