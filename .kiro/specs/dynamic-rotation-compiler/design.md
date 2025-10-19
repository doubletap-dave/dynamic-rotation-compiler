# Design Document

## Overview

The Dynamic Rotation Compiler is a modern World of Warcraft addon that provides an intuitive interface for creating, managing, and executing complex rotations. The addon leverages the Ace3 framework for robust UI components, data management, and configuration handling while maintaining strict compliance with Blizzard's Terms of Service through secure execution patterns.

The system operates on a "one button press, one action" principle, using Blizzard's secure button framework to ensure all protected actions are player-initiated. Rotations are stored in human-readable JSON format, making them easy to share, backup, and potentially integrate with external tools.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WoW Client Environment                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   UI Layer      │  │  Rotation       │  │   Storage    │ │
│  │   (AceGUI)      │  │  Engine         │  │   (AceDB)    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│           │                     │                   │        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Core Addon Framework (Ace3)              │ │
│  └─────────────────────────────────────────────────────────┘ │
│           │                     │                   │        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Event         │  │  Secure Button  │  │   JSON       │ │
│  │   Handler       │  │  Manager        │  │   Parser     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                 Blizzard WoW API Layer                      │
└─────────────────────────────────────────────────────────────┘
```

### Modular Plugin Architecture

The addon uses a highly modular, plugin-based architecture where each module is self-contained and communicates through well-defined interfaces. This allows for easy replacement, testing, and extension of individual components without affecting the entire system.

**Core Modules:**
- **Core Module**: Lightweight bootstrap and module registry
- **UI Module**: Pluggable interface components with swappable backends
- **Rotation Engine**: Isolated execution logic with configurable handlers
- **Storage Module**: Abstracted persistence layer with multiple backend support
- **Security Module**: Standalone compliance and secure execution management
- **Import/Export Module**: Independent serialization with format plugins

**Module Communication:**
- Event-driven messaging system using Ace3 events
- Dependency injection for loose coupling
- Interface contracts for module interoperability
- Hot-swappable components for development and testing

## Components and Interfaces

### Core Module Registry

```lua
-- Lightweight core that manages module lifecycle
DRC = LibStub("AceAddon-3.0"):NewAddon("DRC", 
    "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Module registry for plugin management
DRC.modules = {}
DRC.interfaces = {}
```

**Responsibilities:**
- Module registration and dependency resolution
- Interface contract enforcement
- Event bus for inter-module communication
- Graceful error handling and module isolation

**Key Methods:**
- `RegisterModule(name, module, dependencies)`: Register a new module
- `GetModule(name)`: Retrieve module instance with interface validation
- `BroadcastEvent(event, data)`: Send events to subscribed modules
- `UnloadModule(name)`: Safely remove module without breaking others

**Module Interface Contract:**
```lua
ModuleInterface = {
    Initialize = function(self, core) end,  -- Setup module
    Enable = function(self) end,           -- Start module operations
    Disable = function(self) end,          -- Stop and cleanup
    GetAPI = function(self) end,           -- Return public interface
    GetDependencies = function(self) end   -- List required modules
}
```

### Rotation Engine Component

**Responsibilities:**
- Manage Rotation execution state
- Configure secure buttons for combat-safe execution
- Handle Rotation advancement and looping
- Validate macro commands and syntax

**Key Data Structures:**
```lua
Rotation = {
    id = "unique_Rotation_id",
    name = "Rotation Display Name",
    commands = {
        "/cast Spell1",
        "/cast Spell2", 
        "/use Item Name"
    },
    currentStep = 1,
    enabled = true,
    metadata = {
        class = "WARRIOR",
        spec = "Protection",
        created = timestamp,
        modified = timestamp
    }
}
```

**Key Methods:**
- `CreateRotation(name, commands)`: Create new Rotation with validation
- `ExecuteNextStep(RotationId)`: Advance and execute next command
- `ConfigureSecureButtons()`: Set up secure button attributes
- `ValidateCommand(command)`: Check macro syntax validity

### UI Module Component

**Responsibilities:**
- Main interface using AceGUI-3.0 widgets
- Configuration panel integration with Blizzard Interface Options
- Rotation creation, editing, and management dialogs
- Real-time validation feedback

**Key Interface Elements:**
- **Main Window**: Rotation list with create/edit/delete actions
- **Rotation Editor**: Multi-line text input with syntax highlighting
- **Import/Export Dialog**: Text area for sharing Rotations
- **Settings Panel**: Addon configuration options

**Integration Points:**
- Uses `AceGUI-3.0` for consistent widget styling
- Integrates with `AceConfig-3.0` for options panel
- Leverages `AceConfigDialog-3.0` for Blizzard Interface Options

### Storage Module Component

**Responsibilities:**
- Persist Rotations using AceDB-3.0 with profile support
- JSON serialization/deserialization of Rotation data
- Profile management (per-character, global, custom profiles)
- Data migration and version compatibility

**Database Structure:**
```lua
database = {
    profile = {
        Rotations = {
            ["Rotation_id"] = Rotation,
            -- ... more Rotations
        },
        settings = {
            defaultProfile = "Default",
            enableSounds = true,
            debugMode = false
        }
    }
}
```

**Key Methods:**
- `SaveRotation(Rotation)`: Persist Rotation to database
- `LoadRotations()`: Retrieve all Rotations for current profile
- `ExportRotation(RotationId)`: Generate JSON export string
- `ImportRotation(jsonString)`: Parse and validate imported Rotation

### Security Module Component

**Responsibilities:**
- Manage secure button creation and configuration
- Ensure Blizzard API compliance
- Handle combat state changes
- Prevent taint and protected function violations

**Secure Button Management:**
```lua
-- Create secure buttons for each Rotation step
secureButton = CreateFrame("Button", "DRC_Button_" .. RotationId, 
    nil, "SecureActionButtonTemplate")
secureButton:SetAttribute("type", "macro")
secureButton:SetAttribute("macrotext", command)
```

**Compliance Measures:**
- All secure button attributes set outside of combat
- No dynamic macro modification during combat
- One action per button press enforcement
- Proper event handling for combat state changes

## Data Models

### Rotation Data Model

```json
{
  "id": "warrior_protection_rotation_001",
  "name": "Protection Warrior Basic Rotation",
  "commands": [
    "/cast Shield Slam",
    "/cast Thunder Clap", 
    "/cast Revenge",
    "/cast Shield Block"
  ],
  "metadata": {
    "class": "WARRIOR",
    "spec": "Protection", 
    "version": "1.0",
    "created": "2025-01-15T10:30:00Z",
    "modified": "2025-01-15T10:30:00Z",
    "author": "PlayerName",
    "description": "Basic threat rotation for dungeon tanking"
  },
  "settings": {
    "enabled": true,
    "loopOnComplete": true,
    "resetOnCombatEnd": false
  }
}
```

### Profile Data Model

```json
{
  "profileName": "Main Character",
  "Rotations": {
    "Rotation_id_1": { /* Rotation object */ },
    "Rotation_id_2": { /* Rotation object */ }
  },
  "globalSettings": {
    "enableSounds": true,
    "debugMode": false,
    "defaultKeybind": "F1",
    "uiScale": 1.0
  }
}
```

### Export/Import Data Model

```json
{
  "formatVersion": "1.0",
  "exportDate": "2025-01-15T10:30:00Z",
  "Rotations": [
    { /* Rotation object */ }
  ],
  "metadata": {
    "exportedBy": "DRC v1.0",
    "totalRotations": 1
  }
}
```

## Error Handling

### Validation Errors
- **Syntax Validation**: Check macro commands against WoW macro syntax rules
- **Spell/Item Validation**: Verify spells and items exist and are available
- **Length Validation**: Ensure Rotations don't exceed practical limits

### Runtime Errors
- **Combat State Errors**: Handle attempts to modify Rotations during combat
- **Secure Button Errors**: Catch and log taint or protected function violations
- **Database Errors**: Handle SavedVariables corruption or migration issues

### User Feedback
- **Error Messages**: Clear, actionable error descriptions with line numbers
- **Warning Dialogs**: Confirmation for destructive actions (delete Rotation)
- **Status Indicators**: Visual feedback for Rotation execution state

## Testing Strategy

### Unit Testing Approach
- **Rotation Validation**: Test macro command parsing and validation logic
- **JSON Serialization**: Verify data integrity through save/load cycles
- **State Management**: Test Rotation advancement and reset functionality

### Integration Testing
- **Ace3 Integration**: Verify proper framework initialization and event handling
- **UI Component Testing**: Test dialog creation and user interaction flows
- **Database Operations**: Test profile switching and data persistence

### Compliance Testing
- **Security Validation**: Verify no protected functions called inappropriately
- **Combat State Testing**: Ensure proper behavior during combat transitions
- **Taint Prevention**: Test for UI taint issues with various addon combinations

### Performance Testing
- **Memory Usage**: Monitor addon memory footprint with large Rotation collections
- **Execution Speed**: Measure Rotation execution latency and button response
- **Database Performance**: Test load times with extensive Rotation libraries

## Implementation Notes

### JSON Library Integration
The addon will use the lightweight `json.lua` library (rxi/json.lua) for serialization:
- Pure Lua implementation compatible with WoW's Lua 5.1 environment
- Fast performance suitable for real-time operations
- Proper error handling with descriptive messages
- Small footprint (~9kb, 280 lines of code)

### Ace3 Framework Usage
- **AceAddon-3.0**: Core addon structure and lifecycle management
- **AceDB-3.0**: SavedVariables management with profile support
- **AceGUI-3.0**: UI widget library for consistent interface elements
- **AceConfig-3.0**: Configuration system integration
- **AceConsole-3.0**: Chat command registration and output
- **AceEvent-3.0**: Event registration and handling

### Security Considerations
- All Rotation modifications must occur outside combat
- Secure buttons configured with pre-determined attributes
- No dynamic evaluation of user input during protected execution
- Proper cleanup of secure buttons on addon disable/reload

### Modular Development Benefits

**Hot-Swappable Components:**
- UI backends can be switched (AceGUI → StdUi → Custom) without core changes
- Storage backends support multiple formats (JSON → YAML → Binary)
- Rotation engines can be replaced for different execution strategies
- Security modules can be updated independently for new Blizzard API changes

**Development Workflow:**
- Individual modules can be developed and tested in isolation
- Mock interfaces allow testing without full addon environment
- Modules can be disabled/enabled at runtime for debugging
- New features added as separate modules without touching core code

**Plugin Architecture:**
```lua
-- Example: Adding a new UI theme as a plugin
DRC:RegisterModule("UITheme_ElvUI", {
    Initialize = function(self, core)
        self.ui = core:GetModule("UI")
        self.ui:RegisterTheme("elvui", self:GetThemeDefinition())
    end,
    GetDependencies = function() return {"UI"} end
})
```

**Interface Contracts:**
- Each module exposes a well-defined API
- Interfaces are versioned for backward compatibility
- Dependency injection prevents tight coupling
- Event system allows loose communication between modules
