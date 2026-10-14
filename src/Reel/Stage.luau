--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

export type Core = {
    names: () -> { string },
    get: (name: string) -> boolean,
    set: (name: string, enabled: boolean) -> (),
}

export type Options = {
    screens: Instance?,
    world: Instance?,
    keep: { string }?,
    core: (Core | false)?,
}

local Stage = {}

local Topbar = "Topbar"

local robloxCore: Core = {
    names = function()
        local names = { Topbar }
        for _, item in Enum.CoreGuiType:GetEnumItems() do
            if item ~= Enum.CoreGuiType.All then
                table.insert(names, item.Name)
            end
        end
        return names
    end,
    get = function(name)
        if name == Topbar then
            local ok, enabled = pcall(StarterGui.GetCore, StarterGui, "TopbarEnabled")
            return not ok or enabled ~= false
        end
        return StarterGui:GetCoreGuiEnabled((Enum.CoreGuiType :: any)[name])
    end,
    set = function(name, enabled)
        if name == Topbar then
            pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", enabled)
            return
        end
        StarterGui:SetCoreGuiEnabled((Enum.CoreGuiType :: any)[name], enabled)
    end,
}

local function defaultScreens(): Instance?
    local player = Players.LocalPlayer
    return if player then player:FindFirstChildOfClass("PlayerGui") else nil
end

local function defaultCore(): Core?
    return if RunService:IsClient() then robloxCore else nil
end

local function kept(gui: Instance, root: Instance, keep: { [string]: boolean }): boolean
    local at: Instance? = gui
    while at and at ~= root do
        if keep[at.Name] then
            return true
        end
        at = at.Parent
    end
    return false
end

function Stage.clear(options: Options?): () -> ()
    local given: Options = options or {}
    local keep: { [string]: boolean } = {}
    local names: { string } = given.keep or {}
    for _, name in names do
        keep[name] = true
    end

    local wanted: { [LayerCollector]: boolean } = {}
    local connections: { RBXScriptConnection } = {}

    local function hide(gui: Instance, root: Instance)
        if not gui:IsA("LayerCollector") or wanted[gui] ~= nil or kept(gui, root, keep) then
            return
        end
        wanted[gui] = gui.Enabled
        gui.Enabled = false
        table.insert(
            connections,
            gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if gui.Enabled then
                    wanted[gui] = true
                    gui.Enabled = false
                end
            end)
        )
    end

    local function watch(root: Instance?)
        if not root then
            return
        end
        for _, gui in root:GetDescendants() do
            hide(gui, root)
        end
        table.insert(
            connections,
            root.DescendantAdded:Connect(function(gui)
                hide(gui, root)
            end)
        )
    end

    watch(if given.screens ~= nil then given.screens else defaultScreens())
    watch(given.world)

    local core: Core? = if given.core == false
        then nil
        elseif given.core then given.core :: Core
        else defaultCore()
    local coreWas: { [string]: boolean } = {}
    if core then
        for _, name in core.names() do
            coreWas[name] = core.get(name)
            core.set(name, false)
        end
    end

    local restored = false
    return function()
        if restored then
            return
        end
        restored = true
        for _, connection in connections do
            connection:Disconnect()
        end
        for gui, enabled in wanted do
            if gui.Parent then
                gui.Enabled = enabled
            end
        end
        if core then
            for name, enabled in coreWas do
                core.set(name, enabled)
            end
        end
    end
end

return Stage
