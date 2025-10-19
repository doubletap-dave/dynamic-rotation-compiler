# Dynamic Rotation Compiler (DRC)

A World of Warcraft addon for compiling and executing dynamic ability rotations with intelligent sequencing and conditional logic.

## 🎮 Features

- **Modular Architecture**: Clean separation of concerns with plugin-based design
- **Profile Support**: Multiple rotation profiles with AceDB integration
- **JSON Import/Export**: Share rotations with JSON serialization
- **Event System**: Inter-module communication via event broadcasting
- **Data Migration**: Automatic schema versioning and migration
- **Blizzard Compliant**: Follows all ToS rules with secure execution patterns

## 📦 Installation

1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or type `/reload` in-game

## 🚀 Usage

### Commands

- `/drc` - Show help and available commands
- `/drc modules` - List registered modules
- `/drc status` - Show addon status

## 🏗️ Development Status

### ✅ Completed
- Core addon framework with module registry
- JSON library integration with error handling
- Storage module with AceDB and profile support
- Data persistence and migration system

### 🚧 In Progress
- Rotation execution engine
- User interface with AceGUI
- Secure button management
- Import/Export functionality

## 🛠️ Development

### Project Structure

```
DynamicRotationCompiler/
├── DynamicRotationCompiler.toc # Addon manifest
├── Core/                        # Core framework
│   ├── Core.lua                 # Module registry
│   ├── ModuleInterface.lua      # Module contracts
│   └── JSONUtil.lua             # JSON utilities
├── Modules/                     # Feature modules
│   └── Storage.lua              # Data persistence
└── Libs/                        # Third-party libraries
    ├── Ace3/                    # Ace3 framework
    └── json.lua                 # JSON library
```

### Adding a Module

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

## 📋 Requirements

- World of Warcraft (Retail, 11.0.2+)
- Ace3 libraries
- LibStub
- CallbackHandler-1.0

## 📄 License

See LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 Roadmap

See [tasks.md](.kiro/specs/dynamic-rotation-compiler/tasks.md) for the complete implementation plan.
