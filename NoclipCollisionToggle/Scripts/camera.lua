local targets = {
    SurfaceSlopePitchModifierComponent = true,
    YawCollisionAvoidanceModifierComponent = true,
    SimpleCollisionModifierComponent = true,
}
local originals = {}
local rigs = {}
local controller
local cameraClass

local function valid(object) return object and object:IsValid() end
local function apply(rig)
    if not valid(controller) or not valid(rig) then return end
    local owner = rig.OwningController
    if not valid(owner) or owner:GetAddress() ~= controller:GetAddress() then return end
    local rigKey = tostring(rig:GetAddress())
    local saved = rigs[rigKey]
    if not saved or not valid(saved.rig) then
        rigs[rigKey] = {
            rig = rig,
            radius = rig.CollisionRadius,
            forceZoom = rig.bForceManualZoomInwardWhenColliding,
            avoidOnSwap = rig.bShouldAvoidCollisionWhenSwappingRigActor,
        }
    end
    -- Radius 0 turns off the rig's collision check.
    rig.CollisionRadius = 0
    rig.bForceManualZoomInwardWhenColliding = false
    rig.bShouldAvoidCollisionWhenSwappingRigActor = false
    rig.Modifiers:ForEach(function(_, value)
        local ok, modifier = pcall(function() return value:get() end)
        if not ok then modifier = value end
        if not valid(modifier) then return end
        local name = modifier:GetClass():GetFName():ToString()
        if not targets[name] then return end
        local key = tostring(modifier:GetAddress())
        local entry = originals[key]
        if not entry or not valid(entry.modifier) then
            originals[key] = {modifier=modifier, enabled=modifier.bEnabled}
        end
        modifier.bEnabled = false
    end)
end

local function restore()
    controller = nil
    for key, entry in pairs(rigs) do
        if valid(entry.rig) then
            entry.rig.CollisionRadius = entry.radius
            entry.rig.bForceManualZoomInwardWhenColliding = entry.forceZoom
            entry.rig.bShouldAvoidCollisionWhenSwappingRigActor = entry.avoidOnSwap
        end
        rigs[key] = nil
    end
    for key, entry in pairs(originals) do
        if valid(entry.modifier) then entry.modifier.bEnabled = entry.enabled end
        originals[key] = nil
    end
end

local function disable(playerController)
    if valid(controller) and controller:GetAddress() ~= playerController:GetAddress() then restore() end
    controller = playerController
    -- Find cameras when the command runs.
    for _, rig in ipairs(FindAllOf('CameraRigActor') or {}) do apply(rig) end
end

local function count()
    local result = 0
    for _, entry in pairs(originals) do
        if valid(entry.modifier) then result = result + 1 end
    end
    return result
end

RegisterBeginPlayPostHook(function(context)
    if not valid(controller) then return end
    local rig = context:get()
    if not valid(cameraClass) then cameraClass = StaticFindObject('/Script/Astro.CameraRigActor') end
    if not valid(rig) or not valid(cameraClass) or not rig:IsA(cameraClass) then return end
    local ok, err = pcall(apply, rig)
    if not ok then print('[Noclip Collision Toggle] Camera update failed: ' .. tostring(err) .. '\n') end
end)

local function rigCount()
    local result = 0
    for _, entry in pairs(rigs) do
        if valid(entry.rig) then result = result + 1 end
    end
    return result
end

return {disable=disable, restore=restore, count=count, rigCount=rigCount}
