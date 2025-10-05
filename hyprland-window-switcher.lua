--[[
    Hyprland Window Switcher for OBS Studio
    ----------------------------------------
    Creates multiple PipeWire sources (one per window)
    and switches visibility based on the active Hyprland window.
    
    Author: tommerty
    License: MIT
    Version: 1.0
    ----------------------------------------
]]

obs = obslua

-- Settings
local scene_name = ""
local update_interval_ms = 500
local window_sources = {}  -- Map of window_class -> source_name
local last_window_class = ""
local timer_active = false
local source_prefix = "auto_"
local debug_logging = false  -- Toggle for window class discovery logging

-- Description
function script_description()
    return [[<h1>Hyprland Window Switcher</h1>
<p>A simple lua script that controls PipeWire sources and switches between them based on the active window.</p>
<p><b>Setup:</b></p>
<ol>
    <li>Create a PipeWire screen capture source for each window you want to track</li>
    <li>Name them with the prefix "auto_" followed by the window class (e.g., "auto_com.mitchellh.ghostty")</li>
    <li>Select the scene containing these sources</li>
    <li>The script will show/hide sources automatically based on the active window</li>
</ol>
<p><b>Window Classes:</b> Use 'hyprctl activewindow' to find window classes</p>]]
end

-- Get active window class
function get_active_window_class()
    local handle = io.popen("hyprctl activewindow 2>&1")
    if not handle then 
        return nil
    end
    
    local output = handle:read("*a")
    handle:close()
    
    -- Match class field - only capture until end of line, not everything after
    local class = output:match("class:%s*([^\n\r]+)")
    if class then
        -- Trim whitespace
        class = class:match("^%s*(.-)%s*$")
        return class
    end
    
    return nil
end

-- Find all sources matching the prefix in the scene
function find_window_sources()
    window_sources = {}
    
    if scene_name == "" then
        return
    end
    
    local scene_source = obs.obs_get_source_by_name(scene_name)
    if not scene_source then
        return
    end
    
    local scene = obs.obs_scene_from_source(scene_source)
    if not scene then
        obs.obs_source_release(scene_source)
        return
    end
    
    local scene_items = obs.obs_scene_enum_items(scene)
    if scene_items then
        for _, item in ipairs(scene_items) do
            local source = obs.obs_sceneitem_get_source(item)
            local name = obs.obs_source_get_name(source)
            
            -- Check if source name starts with our prefix
            if name:sub(1, #source_prefix) == source_prefix then
                local window_class = name:sub(#source_prefix + 1)
                window_sources[window_class] = name
                obs.script_log(obs.LOG_INFO, string.format("Found window source: %s -> %s", window_class, name))
            end
        end
        obs.sceneitem_list_release(scene_items)
    end
    
    obs.obs_source_release(scene_source)
end

-- Set visibility of a source in the scene
function set_source_visibility(source_name, visible)
    if scene_name == "" then
        return false
    end
    
    local scene_source = obs.obs_get_source_by_name(scene_name)
    if not scene_source then
        return false
    end
    
    local scene = obs.obs_scene_from_source(scene_source)
    if not scene then
        obs.obs_source_release(scene_source)
        return false
    end
    
    local source = obs.obs_get_source_by_name(source_name)
    if not source then
        obs.obs_source_release(scene_source)
        return false
    end
    
    local scene_item = obs.obs_scene_find_source(scene, source_name)
    if scene_item then
        obs.obs_sceneitem_set_visible(scene_item, visible)
    end
    
    obs.obs_source_release(source)
    obs.obs_source_release(scene_source)
    
    return scene_item ~= nil
end

-- Timer callback
function check_active_window()
    local window_class = get_active_window_class()
    
    if not window_class or window_class == last_window_class then
        return
    end
    
    -- Debug logging mode - just show window classes as you switch
    if debug_logging then
        obs.script_log(obs.LOG_INFO, string.format("Window class: %s", window_class))
        last_window_class = window_class
        return
    end
    
    -- Normal operation mode
    -- Hide the previous window's source
    if last_window_class ~= "" and window_sources[last_window_class] then
        set_source_visibility(window_sources[last_window_class], false)
        obs.script_log(obs.LOG_INFO, string.format("Hiding: %s", window_sources[last_window_class]))
    end
    
    -- Show the new window's source
    if window_sources[window_class] then
        set_source_visibility(window_sources[window_class], true)
        obs.script_log(obs.LOG_INFO, string.format("✓ Active window: %s → Showing: %s", window_class, window_sources[window_class]))
        last_window_class = window_class
    else
        -- Window class detected but no source configured
        obs.script_log(obs.LOG_INFO, string.format("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
        obs.script_log(obs.LOG_INFO, string.format("📋 WINDOW CLASS DETECTED: %s", window_class))
        obs.script_log(obs.LOG_INFO, string.format("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
        obs.script_log(obs.LOG_INFO, string.format("To capture this window:"))
        obs.script_log(obs.LOG_INFO, string.format("  1. Create a new 'Screen Capture (PipeWire)' source"))
        obs.script_log(obs.LOG_INFO, string.format("  2. Name it: auto_%s", window_class))
        obs.script_log(obs.LOG_INFO, string.format("  3. Select this window in the picker dialog"))
        obs.script_log(obs.LOG_INFO, string.format("  4. Click 'Refresh Window Sources' in script settings"))
        obs.script_log(obs.LOG_INFO, string.format("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
        last_window_class = ""
    end
end

-- Start timer
function start_timer()
    if timer_active then
        return
    end
    
    find_window_sources()
    obs.timer_add(check_active_window, update_interval_ms)
    timer_active = true
    obs.script_log(obs.LOG_INFO, "Window switcher started")
end

-- Stop timer
function stop_timer()
    if not timer_active then
        return
    end
    
    obs.timer_remove(check_active_window)
    timer_active = false
    obs.script_log(obs.LOG_INFO, "Window switcher stopped")
end

-- Script properties
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Scene selection
    local scene_list = obs.obs_properties_add_list(
        props,
        "scene",
        "Scene with Window Sources",
        obs.OBS_COMBO_TYPE_EDITABLE,
        obs.OBS_COMBO_FORMAT_STRING
    )
    
    -- Populate scenes
    local scenes = obs.obs_frontend_get_scenes()
    if scenes then
        for _, scene_source in ipairs(scenes) do
            local name = obs.obs_source_get_name(scene_source)
            obs.obs_property_list_add_string(scene_list, name, name)
        end
        obs.source_list_release(scenes)
    end
    
    -- Update interval
    obs.obs_properties_add_int(
        props,
        "update_interval",
        "Update Interval (ms)",
        100,
        5000,
        50
    )
    
    -- Source prefix
    obs.obs_properties_add_text(
        props,
        "source_prefix",
        "Source Name Prefix",
        obs.OBS_TEXT_DEFAULT
    )
    
    -- Refresh sources button
    obs.obs_properties_add_button(
        props,
        "refresh_button",
        "Refresh Window Sources",
        function()
            find_window_sources()
            local count = 0
            for _ in pairs(window_sources) do count = count + 1 end
            obs.script_log(obs.LOG_INFO, string.format("Found %d window sources", count))
            return true
        end
    )
    
    -- Window class discovery toggle
    obs.obs_properties_add_button(
        props,
        "toggle_logging",
        debug_logging and "🟢 Stop Window Class Logging" or "⚪ Start Window Class Logging",
        function(props, prop)
            debug_logging = not debug_logging
            if debug_logging then
                obs.script_log(obs.LOG_INFO, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                obs.script_log(obs.LOG_INFO, "🔍 Window Class Discovery Mode: ON")
                obs.script_log(obs.LOG_INFO, "Switch between windows to see their classes")
                obs.script_log(obs.LOG_INFO, "Click the button again to stop logging")
                obs.script_log(obs.LOG_INFO, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                last_window_class = ""  -- Reset to log first window
                -- Start timer if not running
                if not timer_active then
                    obs.timer_add(check_active_window, update_interval_ms)
                    timer_active = true
                end
            else
                obs.script_log(obs.LOG_INFO, "🔍 Window Class Discovery Mode: OFF")
                -- If no scene configured, stop timer when logging stops
                if scene_name == "" and timer_active then
                    obs.timer_remove(check_active_window)
                    timer_active = false
                end
            end
            -- Update button text
            obs.obs_property_set_description(prop, debug_logging and "🟢 Stop Window Class Logging" or "⚪ Start Window Class Logging")
            return true
        end
    )
    
    return props
end

-- Update settings
function script_update(settings)
    scene_name = obs.obs_data_get_string(settings, "scene")
    update_interval_ms = obs.obs_data_get_int(settings, "update_interval")
    source_prefix = obs.obs_data_get_string(settings, "source_prefix")
    
    if timer_active then
        stop_timer()
    end
    
    if scene_name ~= "" then
        start_timer()
    end
end

-- Defaults
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "update_interval", 500)
    obs.obs_data_set_default_string(settings, "source_prefix", "auto_")
    obs.obs_data_set_default_bool(settings, "debug_logging", false)
end

-- Load
function script_load(settings)
    obs.script_log(obs.LOG_INFO, "Hyprland Window Switcher loaded")
end

-- Unload
function script_unload()
    stop_timer()
    obs.script_log(obs.LOG_INFO, "Hyprland Window Switcher unloaded")
end
