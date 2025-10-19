# Libraries Directory

This directory should contain the required third-party libraries for the addon.

## Required Libraries

### LibStub
- **Purpose**: Library loader and version management
- **Source**: https://www.wowace.com/projects/libstub
- **Location**: `Libs/LibStub/LibStub.lua`

### CallbackHandler-1.0
- **Purpose**: Event callback management
- **Source**: https://www.wowace.com/projects/callbackhandler
- **Location**: `Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`

### Ace3 Framework
- **Purpose**: Addon development framework
- **Source**: https://www.wowace.com/projects/ace3
- **Location**: `Libs/AceAddon-3.0/`, `Libs/AceEvent-3.0/`, etc.

Required Ace3 libraries:
- AceAddon-3.0 - Core addon structure
- AceEvent-3.0 - Event handling
- AceTimer-3.0 - Timer management
- AceDB-3.0 - Database and SavedVariables
- AceConsole-3.0 - Chat commands
- AceGUI-3.0 - UI widgets
- AceConfig-3.0 - Configuration system
- AceConfigDialog-3.0 - Config dialogs

### json.lua
- **Purpose**: JSON serialization/deserialization
- **Source**: https://github.com/rxi/json.lua
- **Location**: `Libs/json.lua`

## Installation

1. Download each library from the sources above
2. Extract to the appropriate subdirectory in `Libs/`
3. Ensure the file paths match those in `MacroSequencer.toc`

## Notes

- These libraries are not included in the repository to respect their individual licenses
- Always use the latest stable versions compatible with your WoW client version
- LibStub and CallbackHandler are typically bundled with Ace3 downloads
