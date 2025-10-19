# Dynamic Rotation Compiler (DRC)

A World of Warcraft addon for compiling and executing dynamic ability rotations with intelligent sequencing and conditional logic.

## Project Structure

```
DynamicRotationCompiler/
├── DynamicRotationCompiler.toc # Addon manifest and load order
├── Core/                        # Core addon framework
│   ├── ModuleInterface.lua      # Module interface contract
│   ├── JSONUtil.lua             # JSON serialization utilities
│   └── Core.lua                 # Core module registry and lifecycle
├── Modules/                     # Feature modules
│   ├── Storage.lua              # Data persistence with AceDB
│   ├── RotationEngine.lua       # Rotation execution logic (planned)
│   ├── UI.lua                   # User interface components (planned)
│   ├── Security.lua             # Secure button management (planned)
│   └── ImportExport.lua         # Import/export functionality (planned)
└── Libs/                        # Third-party libraries
    ├── LibStub/                 # Library loader
    ├── CallbackHandler-1.0/     # Callback management
    ├── Ace3/                    # Ace3 framework libraries
    │   ├── AceAddon-3.0/
    │   ├── AceEvent-3.0/
    │   ├── AceTimer-3.0/
    │   ├── AceDB-3.0/
    │   ├── AceConsole-3.0/
    │   ├── AceGUI-3.0/
    │   ├── AceConfig-3.0/
    │   └── AceConfigDialog-3.0/
    └── json.lua                 # JSON serialization library
```

## Module Architecture

The addon uses a plugin-based architecture where each module:
- Implements the `ModuleInterface` contract
- Declares dependencies on other modules
- Communicates via events through the core registry
- Can be loaded/unloaded independently

### Module Interface

All modules must implement:
- `Initialize(core)` - Setup with core reference
- `Enable()` - Start module operations
- `Disable()` - Stop and cleanup
- `GetAPI()` - Return public interface
- `GetDependencies()` - List required modules
- `GetMetadata()` - Return module info

## Installation

1. Download required libraries (Ace3, LibStub, CallbackHandler, json.lua)
2. Place them in the `Libs/` directory
3. Copy the `DynamicRotationCompiler` folder to your WoW `Interface/AddOns/` directory
4. Restart WoW or reload UI

## Commands

- `/drc` - Show help and available commands
- `/drc modules` - List registered modules
- `/drc status` - Show addon status

## Development

### Adding a New Module

1. Create module file in `Modules/` directory
2. Implement the `ModuleInterface` contract
3. Register module in `Core.lua` or via initialization
4. Add to `.toc` file load order

### Example Module

```lua
local MyModule = DRC_CreateModule({
    name = "MyModule",
    version = "1.0.0",
    description = "Example module"
})

function MyModule:Initialize(core)
    self.core = core
    self._initialized = true
    return true
end

function MyModule:Enable()
    self._enabled = true
    return true
end

function MyModule:Disable()
    self._enabled = false
    return true
end

function MyModule:GetAPI()
    return {
        DoSomething = function() end
    }
end

function MyModule:GetDependencies()
    return {} -- No dependencies
end

-- Register the module
DRC:RegisterModule("MyModule", MyModule)
```

## Features

- **Modular Architecture**: Clean separation of concerns with plugin-based design
- **Profile Support**: Multiple rotation profiles with AceDB integration
- **JSON Import/Export**: Share rotations with JSON serialization
- **Event System**: Inter-module communication via event broadcasting
- **Data Migration**: Automatic schema versioning and migration

## Requirements

- World of Warcraft (Retail, tested on 11.0.2)
- Ace3 libraries
- LibStub
- CallbackHandler-1.0
- json.lua (rxi/json.lua)

## License

See LICENSE file for details.
