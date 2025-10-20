--[[
    UISettings.lua
    
    Settings and configuration panel for the addon.
    Integrates with Blizzard Interface Options and provides profile management.
]]

local ADDON_NAME = "DRC"

UISettings = {}

--[[
    Settings Window Definition
]]

UISettings.SettingsWindow = {
    name = "settings",
    title = "DRC Settings",
    width = 700,
    height = 500,
    
    layout = function(window, ui, storage, rotationEngine)
        local settings = storage:GetAPI().GetAllSettings()
        local currentProfile = storage:GetAPI().GetCurrentProfile()
        local profiles = storage:GetAPI().GetProfiles()
        
        -- Form data
        local formData = {
            enableSounds = settings.enableSounds or true,
            debugMode = settings.debugMode or false,
            defaultKeybind = settings.defaultKeybind or "",
            uiScale = settings.uiScale or 1.0
        }
        
        return {
            type = "container",
            layout = "vertical",
            children = {
                -- Header
                {
                    type = "heading",
                    text = "Settings",
                    size = "large"
                },
                
                -- Tabs
                {
                    type = "tabGroup",
                    fill = true,
                    tabs = {
                        -- General Settings Tab
                        {
                            name = "general",
                            title = "General",
                            content = UISettings:CreateGeneralTab(formData, storage)
                        },
                        
                        -- Profile Management Tab
                        {
                            name = "profiles",
                            title = "Profiles",
                            content = UISettings:CreateProfilesTab(currentProfile, profiles, storage, ui)
                        },
                        
                        -- Keybindings Tab
                        {
                            name = "keybindings",
                            title = "Keybindings",
                            content = UISettings:CreateKeybindingsTab(storage)
                        },
                        
                        -- About Tab
                        {
                            name = "about",
                            title = "About",
                            content = UISettings:CreateAboutTab()
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
                            text = "Save",
                            primary = true,
                            onClick = function()
                                UISettings:SaveSettings(storage, formData)
                                ui:CloseWindow("settings")
                            end
                        },
                        {
                            type = "button",
                            text = "Cancel",
                            onClick = function()
                                ui:CloseWindow("settings")
                            end
                        }
                    }
                }
            }
        }
    end
}

--[[
    Tab Content Creators
]]

function UISettings:CreateGeneralTab(formData, storage)
    return {
        type = "scrollFrame",
        fill = true,
        children = {
            {
                type = "heading",
                text = "General Settings",
                size = "medium"
            },
            
            {
                type = "checkBox",
                label = "Enable sound effects",
                value = formData.enableSounds,
                tooltip = "Play sound effects for rotation events",
                onChange = function(value)
                    formData.enableSounds = value
                end
            },
            
            {
                type = "checkBox",
                label = "Debug mode",
                value = formData.debugMode,
                tooltip = "Enable debug logging and additional information",
                onChange = function(value)
                    formData.debugMode = value
                end
            },
            
            {
                type = "slider",
                label = "UI Scale",
                value = formData.uiScale,
                min = 0.5,
                max = 2.0,
                step = 0.1,
                tooltip = "Adjust the scale of addon windows",
                onChange = function(value)
                    formData.uiScale = value
                end
            },
            
            {
                type = "heading",
                text = "Rotation Execution",
                size = "medium"
            },
            
            {
                type = "label",
                text = "Configure how rotations are executed:",
                wrap = true
            },
            
            {
                type = "checkBox",
                label = "Show execution feedback",
                value = true,
                tooltip = "Display messages when rotation steps execute",
                onChange = function(value)
                    -- Store in settings
                end
            },
            
            {
                type = "checkBox",
                label = "Highlight current step",
                value = true,
                tooltip = "Highlight the current step in rotation list",
                onChange = function(value)
                    -- Store in settings
                end
            }
        }
    }
end

function UISettings:CreateProfilesTab(currentProfile, profiles, storage, ui)
    return {
        type = "scrollFrame",
        fill = true,
        children = {
            {
                type = "heading",
                text = "Profile Management",
                size = "medium"
            },
            
            {
                type = "label",
                text = "Profiles allow you to maintain different rotation sets for different characters or situations.",
                wrap = true
            },
            
            {
                type = "label",
                text = "Current Profile: " .. currentProfile,
                color = {0.2, 0.8, 0.2, 1}
            },
            
            {
                type = "heading",
                text = "Available Profiles",
                size = "small"
            },
            
            {
                type = "profileList",
                profiles = profiles,
                currentProfile = currentProfile,
                onSelect = function(profileName)
                    storage:GetAPI().SetProfile(profileName)
                    DRC:Print("Switched to profile: " .. profileName)
                    -- Refresh settings window
                    ui:CloseWindow("settings")
                    ui:OpenWindow("settings")
                end,
                onCopy = function(profileName)
                    UISettings:ShowCopyProfileDialog(ui, storage, profileName)
                end,
                onDelete = function(profileName)
                    UISettings:ShowDeleteProfileDialog(ui, storage, profileName)
                end,
                onReset = function(profileName)
                    UISettings:ShowResetProfileDialog(ui, storage, profileName)
                end
            },
            
            {
                type = "container",
                layout = "horizontal",
                children = {
                    {
                        type = "button",
                        text = "New Profile",
                        onClick = function()
                            UISettings:ShowNewProfileDialog(ui, storage)
                        end
                    },
                    {
                        type = "button",
                        text = "Copy Current",
                        onClick = function()
                            UISettings:ShowCopyProfileDialog(ui, storage, currentProfile)
                        end
                    },
                    {
                        type = "button",
                        text = "Reset Current",
                        onClick = function()
                            UISettings:ShowResetProfileDialog(ui, storage, currentProfile)
                        end
                    }
                }
            }
        }
    }
end

function UISettings:CreateKeybindingsTab(storage)
    return {
        type = "scrollFrame",
        fill = true,
        children = {
            {
                type = "heading",
                text = "Keybindings",
                size = "medium"
            },
            
            {
                type = "label",
                text = "Configure keybindings for quick access to addon features.",
                wrap = true
            },
            
            {
                type = "keybinding",
                label = "Toggle Main Window",
                binding = "CLICK DRCMainButton:LeftButton",
                tooltip = "Keybinding to open/close the main window",
                onChange = function(binding)
                    -- Store keybinding
                end
            },
            
            {
                type = "keybinding",
                label = "Execute Current Rotation",
                binding = "",
                tooltip = "Keybinding to execute the next step of the active rotation",
                onChange = function(binding)
                    -- Store keybinding
                end
            },
            
            {
                type = "label",
                text = "Note: Keybindings can also be configured in the standard Blizzard Keybindings interface under 'AddOns'.",
                wrap = true,
                color = {0.7, 0.7, 0.7, 1}
            }
        }
    }
end

function UISettings:CreateAboutTab()
    return {
        type = "scrollFrame",
        fill = true,
        children = {
            {
                type = "heading",
                text = "Dynamic Rotation Compiler",
                size = "large"
            },
            
            {
                type = "label",
                text = "Version 1.0.0",
                align = "center"
            },
            
            {
                type = "label",
                text = "A modern World of Warcraft addon for creating and executing complex ability rotations.",
                wrap = true,
                align = "center"
            },
            
            {
                type = "heading",
                text = "Features",
                size = "medium"
            },
            
            {
                type = "label",
                text = "• Create custom rotations with macro commands\n" ..
                       "• Execute rotations with single button presses\n" ..
                       "• Import and export rotations to share with others\n" ..
                       "• Profile support for multiple characters\n" ..
                       "• Blizzard ToS compliant execution\n" ..
                       "• Modular plugin architecture",
                wrap = true
            },
            
            {
                type = "heading",
                text = "Credits",
                size = "medium"
            },
            
            {
                type = "label",
                text = "Developed by the DRC Development Team\n\n" ..
                       "Built with:\n" ..
                       "• Ace3 Framework\n" ..
                       "• json.lua by rxi\n" ..
                       "• LibStub",
                wrap = true
            },
            
            {
                type = "heading",
                text = "Support",
                size = "medium"
            },
            
            {
                type = "label",
                text = "For help and support, use the /drc help command or visit the addon page.",
                wrap = true
            }
        }
    }
end

--[[
    Settings Operations
]]

function UISettings:SaveSettings(storage, formData)
    local api = storage:GetAPI()
    
    api.SetSetting("enableSounds", formData.enableSounds)
    api.SetSetting("debugMode", formData.debugMode)
    api.SetSetting("defaultKeybind", formData.defaultKeybind)
    api.SetSetting("uiScale", formData.uiScale)
    
    DRC:Print("Settings saved successfully")
end

--[[
    Profile Dialogs
]]

function UISettings:ShowNewProfileDialog(ui, storage)
    local profileName = ""
    
    local dialog = {
        name = "newProfile",
        title = "Create New Profile",
        width = 400,
        height = 200,
        layout = function(window, ui, storage, rotationEngine)
            return {
                type = "container",
                layout = "vertical",
                children = {
                    {
                        type = "label",
                        text = "Enter a name for the new profile:",
                        wrap = true
                    },
                    {
                        type = "editBox",
                        label = "Profile Name",
                        value = "",
                        required = true,
                        onChange = function(value)
                            profileName = value
                        end
                    },
                    {
                        type = "container",
                        layout = "horizontal",
                        children = {
                            {
                                type = "button",
                                text = "Create",
                                primary = true,
                                onClick = function()
                                    if profileName and profileName:trim() ~= "" then
                                        if storage:GetAPI().CreateProfile(profileName) then
                                            DRC:Print("Profile created: " .. profileName)
                                            ui:CloseWindow("newProfile")
                                            -- Refresh settings window
                                            if ui:IsWindowOpen("settings") then
                                                ui:CloseWindow("settings")
                                                ui:OpenWindow("settings")
                                            end
                                        else
                                            DRC:PrintError("Failed to create profile")
                                        end
                                    else
                                        DRC:PrintError("Profile name is required")
                                    end
                                end
                            },
                            {
                                type = "button",
                                text = "Cancel",
                                onClick = function()
                                    ui:CloseWindow("newProfile")
                                end
                            }
                        }
                    }
                }
            }
        end
    }
    
    ui:RegisterWindow("newProfile", dialog)
    ui:OpenWindow("newProfile")
end

function UISettings:ShowCopyProfileDialog(ui, storage, sourceProfile)
    local targetName = sourceProfile .. " Copy"
    
    local dialog = {
        name = "copyProfile",
        title = "Copy Profile",
        width = 400,
        height = 200,
        layout = function(window, ui, storage, rotationEngine)
            return {
                type = "container",
                layout = "vertical",
                children = {
                    {
                        type = "label",
                        text = "Enter a name for the copied profile:",
                        wrap = true
                    },
                    {
                        type = "editBox",
                        label = "New Profile Name",
                        value = targetName,
                        required = true,
                        onChange = function(value)
                            targetName = value
                        end
                    },
                    {
                        type = "container",
                        layout = "horizontal",
                        children = {
                            {
                                type = "button",
                                text = "Copy",
                                primary = true,
                                onClick = function()
                                    if targetName and targetName:trim() ~= "" then
                                        if storage:GetAPI().CopyProfile(sourceProfile, targetName) then
                                            DRC:Print("Profile copied to: " .. targetName)
                                            ui:CloseWindow("copyProfile")
                                            -- Refresh settings window
                                            if ui:IsWindowOpen("settings") then
                                                ui:CloseWindow("settings")
                                                ui:OpenWindow("settings")
                                            end
                                        else
                                            DRC:PrintError("Failed to copy profile")
                                        end
                                    else
                                        DRC:PrintError("Profile name is required")
                                    end
                                end
                            },
                            {
                                type = "button",
                                text = "Cancel",
                                onClick = function()
                                    ui:CloseWindow("copyProfile")
                                end
                            }
                        }
                    }
                }
            }
        end
    }
    
    ui:RegisterWindow("copyProfile", dialog)
    ui:OpenWindow("copyProfile")
end

function UISettings:ShowDeleteProfileDialog(ui, storage, profileName)
    local currentProfile = storage:GetAPI().GetCurrentProfile()
    
    if profileName == currentProfile then
        DRC:PrintError("Cannot delete the current profile. Switch to another profile first.")
        return
    end
    
    local dialog = {
        name = "deleteProfile",
        title = "Delete Profile",
        width = 400,
        height = 150,
        layout = function(window, ui, storage, rotationEngine)
            return {
                type = "container",
                layout = "vertical",
                children = {
                    {
                        type = "label",
                        text = string.format("Are you sure you want to delete profile '%s'?", profileName),
                        wrap = true
                    },
                    {
                        type = "label",
                        text = "This action cannot be undone. All rotations in this profile will be lost.",
                        color = {1, 0.5, 0.5, 1},
                        wrap = true
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
                                    if storage:GetAPI().DeleteProfile(profileName) then
                                        DRC:Print("Profile deleted: " .. profileName)
                                        ui:CloseWindow("deleteProfile")
                                        -- Refresh settings window
                                        if ui:IsWindowOpen("settings") then
                                            ui:CloseWindow("settings")
                                            ui:OpenWindow("settings")
                                        end
                                    else
                                        DRC:PrintError("Failed to delete profile")
                                    end
                                end
                            },
                            {
                                type = "button",
                                text = "Cancel",
                                onClick = function()
                                    ui:CloseWindow("deleteProfile")
                                end
                            }
                        }
                    }
                }
            }
        end
    }
    
    ui:RegisterWindow("deleteProfile", dialog)
    ui:OpenWindow("deleteProfile")
end

function UISettings:ShowResetProfileDialog(ui, storage, profileName)
    local dialog = {
        name = "resetProfile",
        title = "Reset Profile",
        width = 400,
        height = 150,
        layout = function(window, ui, storage, rotationEngine)
            return {
                type = "container",
                layout = "vertical",
                children = {
                    {
                        type = "label",
                        text = string.format("Are you sure you want to reset profile '%s' to defaults?", profileName),
                        wrap = true
                    },
                    {
                        type = "label",
                        text = "This action cannot be undone. All rotations and settings will be lost.",
                        color = {1, 0.5, 0.5, 1},
                        wrap = true
                    },
                    {
                        type = "container",
                        layout = "horizontal",
                        children = {
                            {
                                type = "button",
                                text = "Reset",
                                primary = true,
                                onClick = function()
                                    if storage:GetAPI().ResetProfile() then
                                        DRC:Print("Profile reset: " .. profileName)
                                        ui:CloseWindow("resetProfile")
                                        -- Refresh settings window
                                        if ui:IsWindowOpen("settings") then
                                            ui:CloseWindow("settings")
                                            ui:OpenWindow("settings")
                                        end
                                    else
                                        DRC:PrintError("Failed to reset profile")
                                    end
                                end
                            },
                            {
                                type = "button",
                                text = "Cancel",
                                onClick = function()
                                    ui:CloseWindow("resetProfile")
                                end
                            }
                        }
                    }
                }
            }
        end
    }
    
    ui:RegisterWindow("resetProfile", dialog)
    ui:OpenWindow("resetProfile")
end

--[[
    Blizzard Interface Options Integration
]]

function UISettings:CreateBlizzardOptionsPanel(storage, ui)
    -- Create options panel for Blizzard Interface Options
    local panel = CreateFrame("Frame", "DRCOptionsPanel", UIParent)
    panel.name = "Dynamic Rotation Compiler"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Dynamic Rotation Compiler")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure addon settings and manage rotation profiles.")
    desc:SetJustifyH("LEFT")
    
    -- Open Settings Button
    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openButton:SetSize(200, 25)
    openButton:SetText("Open Settings Window")
    openButton:SetScript("OnClick", function()
        ui:ShowSettings()
    end)
    
    -- Version info
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("BOTTOMLEFT", 16, 16)
    version:SetText("Version 1.0.0")
    version:SetTextColor(0.5, 0.5, 0.5, 1)
    
    -- Add to Blizzard Interface Options
    -- Note: This uses the old API, may need updating for newer WoW versions
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory then
        -- New API for 10.0+
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    end
    
    return panel
end

-- Register settings window
function UISettings:RegisterAll(ui, storage)
    ui:RegisterWindow("settings", self.SettingsWindow)
    
    -- Create Blizzard options panel
    self:CreateBlizzardOptionsPanel(storage, ui)
end

return UISettings
