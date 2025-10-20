--[[
    UIWindows.lua
    
    Window definitions for the UI module.
    Implements rotation management interface with list view, editor, and dialogs.
]]

local ADDON_NAME = "DRC"

-- Window definitions will be registered with the UI module
local UIWindows = {}

--[[
    Main Window - Rotation List View
]]

UIWindows.MainWindow = {
    name = "main",
    title = "Dynamic Rotation Compiler",
    width = 600,
    height = 400,
    
    -- Layout function creates the window content
    layout = function(window, ui, storage, rotationEngine)
        local rotations = storage:GetAPI().GetAllRotations()
        
        -- Create rotation list
        local rotationList = {}
        for id, rotation in pairs(rotations) do
            table.insert(rotationList, {
                id = id,
                name = rotation.name,
                commandCount = #rotation.commands,
                enabled = rotation.settings and rotation.settings.enabled or true,
                class = rotation.metadata and rotation.metadata.class or "Unknown",
                spec = rotation.metadata and rotation.metadata.spec or "Unknown"
            })
        end
        
        -- Sort by name
        table.sort(rotationList, function(a, b)
            return a.name < b.name
        end)
        
        return {
            type = "container",
            layout = "vertical",
            children = {
                -- Header
                {
                    type = "heading",
                    text = "Rotations",
                    size = "large"
                },
                
                -- Toolbar
                {
                    type = "container",
                    layout = "horizontal",
                    children = {
                        {
                            type = "button",
                            text = "New Rotation",
                            onClick = function()
                                ui:ShowRotationEditor()
                            end
                        },
                        {
                            type = "button",
                            text = "Import",
                            onClick = function()
                                ui:ShowImportDialog()
                            end
                        },
                        {
                            type = "button",
                            text = "Export All",
                            onClick = function()
                                ui:ShowExportDialog()
                            end
                        },
                        {
                            type = "button",
                            text = "Settings",
                            onClick = function()
                                ui:ShowSettings()
                            end
                        }
                    }
                },
                
                -- Rotation list
                {
                    type = "scrollFrame",
                    fill = true,
                    children = {
                        {
                            type = "rotationList",
                            rotations = rotationList,
                            onEdit = function(rotationId)
                                ui:ShowRotationEditor(rotationId)
                            end,
                            onDelete = function(rotationId)
                                UIWindows:ShowDeleteConfirmation(ui, storage, rotationId)
                            end,
                            onToggle = function(rotationId, enabled)
                                local rotation = storage:GetAPI().LoadRotation(rotationId)
                                if rotation then
                                    if not rotation.settings then
                                        rotation.settings = {}
                                    end
                                    rotation.settings.enabled = enabled
                                    storage:GetAPI().SaveRotation(rotation)
                                end
                            end,
                            onExecute = function(rotationId)
                                local api = rotationEngine:GetAPI()
                                api.ExecuteNextStep(rotationId)
                            end
                        }
                    }
                },
                
                -- Status bar
                {
                    type = "label",
                    text = string.format("%d rotation(s) loaded", #rotationList),
                    align = "center"
                }
            }
        }
    end
}

--[[
    Rotation Editor Window
]]

UIWindows.RotationEditor = {
    name = "rotationEditor",
    title = "Rotation Editor",
    width = 700,
    height = 500,
    
    layout = function(window, ui, storage, rotationEngine)
        local rotationId = window.options.rotationId
        local rotation = nil
        local isNew = true
        
        if rotationId then
            rotation = storage:GetAPI().LoadRotation(rotationId)
            isNew = false
        end
        
        -- Initialize form data
        local formData = {
            name = rotation and rotation.name or "",
            commands = rotation and table.concat(rotation.commands, "\n") or "",
            class = rotation and rotation.metadata and rotation.metadata.class or "",
            spec = rotation and rotation.metadata and rotation.metadata.spec or "",
            description = rotation and rotation.metadata and rotation.metadata.description or "",
            loopOnComplete = rotation and rotation.settings and rotation.settings.loopOnComplete or true,
            resetOnCombatEnd = rotation and rotation.settings and rotation.settings.resetOnCombatEnd or false
        }
        
        return {
            type = "container",
            layout = "vertical",
            children = {
                -- Header
                {
                    type = "heading",
                    text = isNew and "Create New Rotation" or "Edit Rotation",
                    size = "large"
                },
                
                -- Form
                {
                    type = "scrollFrame",
                    fill = true,
                    children = {
                        -- Name field
                        {
                            type = "editBox",
                            label = "Rotation Name",
                            value = formData.name,
                            required = true,
                            onChange = function(value)
                                formData.name = value
                            end
                        },
                        
                        -- Class and Spec
                        {
                            type = "container",
                            layout = "horizontal",
                            children = {
                                {
                                    type = "editBox",
                                    label = "Class",
                                    value = formData.class,
                                    width = 0.5,
                                    onChange = function(value)
                                        formData.class = value
                                    end
                                },
                                {
                                    type = "editBox",
                                    label = "Spec",
                                    value = formData.spec,
                                    width = 0.5,
                                    onChange = function(value)
                                        formData.spec = value
                                    end
                                }
                            }
                        },
                        
                        -- Description
                        {
                            type = "editBox",
                            label = "Description",
                            value = formData.description,
                            multiline = false,
                            onChange = function(value)
                                formData.description = value
                            end
                        },
                        
                        -- Commands editor
                        {
                            type = "multiLineEditBox",
                            label = "Commands (one per line)",
                            value = formData.commands,
                            required = true,
                            height = 200,
                            font = "mono",
                            onChange = function(value)
                                formData.commands = value
                                -- Validate commands in real-time
                                UIWindows:ValidateCommands(value, window)
                            end,
                            onValidate = function(value)
                                return UIWindows:ValidateCommands(value, window)
                            end
                        },
                        
                        -- Validation feedback area
                        {
                            type = "label",
                            id = "validationFeedback",
                            text = "",
                            color = {1, 1, 1, 1}
                        },
                        
                        -- Settings
                        {
                            type = "heading",
                            text = "Settings",
                            size = "medium"
                        },
                        
                        {
                            type = "checkBox",
                            label = "Loop on complete",
                            value = formData.loopOnComplete,
                            onChange = function(value)
                                formData.loopOnComplete = value
                            end
                        },
                        
                        {
                            type = "checkBox",
                            label = "Reset on combat end",
                            value = formData.resetOnCombatEnd,
                            onChange = function(value)
                                formData.resetOnCombatEnd = value
                            end
                        }
                    }
                },
                
                -- Action buttons
                {
                    type = "container",
                    layout = "horizontal",
                    children = {
                        {
                            type = "button",
                            text = isNew and "Create" or "Save",
                            primary = true,
                            onClick = function()
                                UIWindows:SaveRotation(ui, storage, formData, rotationId, isNew)
                            end
                        },
                        {
                            type = "button",
                            text = "Cancel",
                            onClick = function()
                                ui:CloseWindow("rotationEditor")
                            end
                        }
                    }
                }
            }
        }
    end
}

--[[
    Import Dialog
]]

UIWindows.ImportDialog = {
    name = "import",
    title = "Import Rotation",
    width = 600,
    height = 400,
    
    layout = function(window, ui, storage, rotationEngine)
        local importData = ""
        
        return {
            type = "container",
            layout = "vertical",
            children = {
                {
                    type = "heading",
                    text = "Import Rotation",
                    size = "large"
                },
                
                {
                    type = "label",
                    text = "Paste the rotation import string below:",
                    wrap = true
                },
                
                {
                    type = "multiLineEditBox",
                    label = "Import String",
                    value = "",
                    height = 250,
                    font = "mono",
                    onChange = function(value)
                        importData = value
                    end
                },
                
                {
                    type = "label",
                    id = "importFeedback",
                    text = "",
                    color = {1, 1, 1, 1}
                },
                
                {
                    type = "container",
                    layout = "horizontal",
                    children = {
                        {
                            type = "button",
                            text = "Import",
                            primary = true,
                            onClick = function()
                                UIWindows:ImportRotation(ui, storage, importData, window)
                            end
                        },
                        {
                            type = "button",
                            text = "Cancel",
                            onClick = function()
                                ui:CloseWindow("import")
                            end
                        }
                    }
                }
            }
        }
    end
}

--[[
    Export Dialog
]]

UIWindows.ExportDialog = {
    name = "export",
    title = "Export Rotation",
    width = 600,
    height = 400,
    
    layout = function(window, ui, storage, rotationEngine)
        local rotationId = window.options.rotationId
        local exportString = ""
        local exportType = "single"
        
        -- Generate export string
        if rotationId then
            local success, result = storage:GetAPI().ExportRotation(rotationId)
            if success then
                exportString = result
            else
                exportString = "Error: " .. result
            end
        else
            local success, result = storage:GetAPI().ExportAllRotations()
            if success then
                exportString = result
                exportType = "all"
            else
                exportString = "Error: " .. result
            end
        end
        
        return {
            type = "container",
            layout = "vertical",
            children = {
                {
                    type = "heading",
                    text = exportType == "single" and "Export Rotation" or "Export All Rotations",
                    size = "large"
                },
                
                {
                    type = "label",
                    text = "Copy the export string below to share your rotation(s):",
                    wrap = true
                },
                
                {
                    type = "multiLineEditBox",
                    label = "Export String",
                    value = exportString,
                    height = 250,
                    font = "mono",
                    readOnly = true
                },
                
                {
                    type = "container",
                    layout = "horizontal",
                    children = {
                        {
                            type = "button",
                            text = "Close",
                            onClick = function()
                                ui:CloseWindow("export")
                            end
                        }
                    }
                }
            }
        }
    end
}

--[[
    Helper Functions
]]

-- Validate macro commands
function UIWindows:ValidateCommands(commandsText, window)
    if not commandsText or commandsText:trim() == "" then
        self:UpdateValidationFeedback(window, "Commands are required", "error")
        return false, "Commands are required"
    end
    
    local commands = {}
    for line in commandsText:gmatch("[^\r\n]+") do
        local trimmed = line:trim()
        if trimmed ~= "" then
            table.insert(commands, trimmed)
        end
    end
    
    if #commands == 0 then
        self:UpdateValidationFeedback(window, "At least one command is required", "error")
        return false, "At least one command is required"
    end
    
    -- Validate each command
    for i, command in ipairs(commands) do
        if not command:match("^/") then
            local msg = string.format("Line %d: Commands must start with '/'", i)
            self:UpdateValidationFeedback(window, msg, "error")
            return false, msg
        end
        
        -- Basic macro command validation
        local validCommands = {
            "/cast", "/use", "/target", "/assist", "/focus",
            "/stopcasting", "/startattack", "/stopattack",
            "/castsequence", "/castrandom"
        }
        
        local isValid = false
        for _, validCmd in ipairs(validCommands) do
            if command:lower():match("^" .. validCmd:lower()) then
                isValid = true
                break
            end
        end
        
        if not isValid then
            local msg = string.format("Line %d: Unknown or unsupported command", i)
            self:UpdateValidationFeedback(window, msg, "warning")
        end
    end
    
    self:UpdateValidationFeedback(window, string.format("✓ %d valid command(s)", #commands), "success")
    return true
end

-- Update validation feedback in window
function UIWindows:UpdateValidationFeedback(window, message, type)
    -- This would update the validation feedback widget
    -- Implementation depends on the UI backend
    if window.validationCallback then
        window.validationCallback(message, type)
    end
end

-- Save rotation from editor
function UIWindows:SaveRotation(ui, storage, formData, rotationId, isNew)
    -- Validate name
    if not formData.name or formData.name:trim() == "" then
        DRC:PrintError("Rotation name is required")
        return
    end
    
    -- Validate commands
    if not formData.commands or formData.commands:trim() == "" then
        DRC:PrintError("At least one command is required")
        return
    end
    
    -- Parse commands
    local commands = {}
    for line in formData.commands:gmatch("[^\r\n]+") do
        local trimmed = line:trim()
        if trimmed ~= "" then
            table.insert(commands, trimmed)
        end
    end
    
    if #commands == 0 then
        DRC:PrintError("At least one command is required")
        return
    end
    
    -- Create rotation object
    local rotation = {
        id = rotationId,
        name = formData.name:trim(),
        commands = commands,
        metadata = {
            class = formData.class:trim(),
            spec = formData.spec:trim(),
            description = formData.description:trim(),
            version = "1.0",
            author = UnitName("player"),
            created = isNew and time() or nil,
            modified = time()
        },
        settings = {
            enabled = true,
            loopOnComplete = formData.loopOnComplete,
            resetOnCombatEnd = formData.resetOnCombatEnd
        }
    }
    
    -- Save rotation
    local success, err = storage:GetAPI().SaveRotation(rotation)
    if success then
        DRC:Print(isNew and "Rotation created successfully" or "Rotation saved successfully")
        ui:CloseWindow("rotationEditor")
        
        -- Refresh main window if open
        if ui:IsWindowOpen("main") then
            ui:CloseWindow("main")
            ui:OpenWindow("main")
        end
    else
        DRC:PrintError("Failed to save rotation: " .. (err or "Unknown error"))
    end
end

-- Import rotation
function UIWindows:ImportRotation(ui, storage, importData, window)
    if not importData or importData:trim() == "" then
        self:UpdateValidationFeedback(window, "Import string is required", "error")
        return
    end
    
    local success, result = storage:GetAPI().ImportRotation(importData)
    if success then
        DRC:Print("Rotation imported successfully: " .. result.name)
        ui:CloseWindow("import")
        
        -- Refresh main window if open
        if ui:IsWindowOpen("main") then
            ui:CloseWindow("main")
            ui:OpenWindow("main")
        end
    else
        self:UpdateValidationFeedback(window, "Import failed: " .. result, "error")
        DRC:PrintError("Failed to import rotation: " .. result)
    end
end

-- Show delete confirmation dialog
function UIWindows:ShowDeleteConfirmation(ui, storage, rotationId)
    local rotation = storage:GetAPI().LoadRotation(rotationId)
    if not rotation then
        return
    end
    
    -- Create confirmation dialog
    local dialog = {
        name = "deleteConfirm_" .. rotationId,
        title = "Confirm Delete",
        width = 400,
        height = 150,
        layout = function(window, ui, storage, rotationEngine)
            return {
                type = "container",
                layout = "vertical",
                children = {
                    {
                        type = "label",
                        text = string.format("Are you sure you want to delete '%s'?", rotation.name),
                        wrap = true
                    },
                    {
                        type = "label",
                        text = "This action cannot be undone.",
                        color = {1, 0.5, 0.5, 1}
                    },
                    {
                        type = "container",
                        layout = "horizontal",
                        children = {
                            {
                                type = "button",
                                text = "Delete",
                                primary = true,
                                onClick = function()
                                    if storage:GetAPI().DeleteRotation(rotationId) then
                                        DRC:Print("Rotation deleted: " .. rotation.name)
                                        ui:CloseWindow("deleteConfirm_" .. rotationId)
                                        
                                        -- Refresh main window
                                        if ui:IsWindowOpen("main") then
                                            ui:CloseWindow("main")
                                            ui:OpenWindow("main")
                                        end
                                    else
                                        DRC:PrintError("Failed to delete rotation")
                                    end
                                end
                            },
                            {
                                type = "button",
                                text = "Cancel",
                                onClick = function()
                                    ui:CloseWindow("deleteConfirm_" .. rotationId)
                                end
                            }
                        }
                    }
                }
            }
        end
    }
    
    -- Register and open dialog
    ui:RegisterWindow(dialog.name, dialog)
    ui:OpenWindow(dialog.name)
end

-- Register all windows with UI module
function UIWindows:RegisterAll(ui)
    ui:RegisterWindow("main", self.MainWindow)
    ui:RegisterWindow("rotationEditor", self.RotationEditor)
    ui:RegisterWindow("import", self.ImportDialog)
    ui:RegisterWindow("export", self.ExportDialog)
end

return UIWindows
