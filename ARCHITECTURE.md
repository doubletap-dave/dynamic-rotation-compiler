# Dynamic Rotation Compiler - Architecture Documentation

## Module Loading System

### Global Variable Requirements

All modules and helper files that need to be accessed by other parts of the addon MUST be declared as global variables (without `local` keyword).

**Current Global Modules:**
- `Storage` - Persistent storage module (DynamicRotationCompiler/Modules/Storage.lua)
- `RotationEngine` - Rotation execution engine (DynamicRotationCompiler/Modules/RotationEngine.lua)
- `UI` - UI management module (DynamicRotationCompiler/Modules/UI.lua)
- `UIWindows` - Window definitions (DynamicRotationCompiler/Modules/UIWindows.lua)
- `UISettings` - Settings window definitions (DynamicRotationCompiler/Modules/UISettings.lua)

**Core Globals:**
- `DRC` - Main addon object (created by Ace3)
- `DRC_ModuleInterface` - Module interface template
- `DRC_CreateModule()` - Module factory function
- `DRC_ValidateModule()` - Module validation function

### File Loading Order (from .toc)

1. **Libraries** (LibStub, CallbackHandler, Ace3 framework, json.lua)
2. **Core/ModuleInterface.lua** - Defines module system
3. **Core/JSONUtil.lua** - JSON utilities (currently unused)
4. **Core/Core.lua** - Main addon initialization
5. **Modules/Storage.lua** - Storage module
6. **Modules/RotationEngine.lua** - Rotation engine
7. **Modules/UI.lua** - UI module
8. **Modules/UIWindows.lua** - Window definitions
9. **Modules/UISettings.lua** - Settings definitions

### Module Registration Flow

1. Each module file loads and creates a global variable
2. `Core.lua` calls `OnInitialize()` which calls `RegisterModules()`
3. `RegisterModules()` checks for global variables and registers them
4. Modules are initialized in dependency order
5. Modules are enabled after all initialization completes

### Common Pitfalls

❌ **WRONG:**
```lua
local MyModule = DRC_CreateModule({...})
return MyModule
```

✅ **CORRECT:**
```lua
MyModule = DRC_CreateModule({...})
return MyModule
```

### Module Dependencies

- `Storage` - No dependencies
- `RotationEngine` - Depends on `Storage`
- `UI` - Depends on `Storage`, `RotationEngine`
- `UIWindows` - Helper for `UI` (not a module)
- `UISettings` - Helper for `UI` (not a module)

### Verification Checklist

When adding new modules or helper files:

- [ ] Is the variable declared as global (no `local` keyword)?
- [ ] Is the file listed in the .toc in the correct order?
- [ ] If it's a module, is it registered in `Core.lua:RegisterModules()`?
- [ ] If it's a helper, is it accessed by the correct global name?
- [ ] Does it have all required dependencies loaded before it?
- [ ] Are there any syntax errors? (run getDiagnostics)

### Debugging Module Loading

Add these commands to check module status:
- `/drc modules` - List all registered modules
- `/drc status` - Show addon initialization status
- `/reload` - Reload UI to test changes

Check the chat log for:
- "Registering [Module] module..." - Module found and being registered
- "Error: [Module] module not found" - Global variable not set
- "[Module] module initialized" - Module initialized successfully
- "[Module] module enabled" - Module enabled successfully
