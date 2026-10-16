-- Noclip Collision Toggle 1.1.0
local VERSION = '1.1.0'
local changed
local scripts = debug.getinfo(1, 'S').source:sub(2):match('^(.*)[/\\]main.lua$')
local camera = dofile(scripts .. '/camera.lua')
local function valid(object) return object and object:IsValid() end
local function readStatus()
    local file = assert(io.open(scripts .. '/NoclipCollisionToggle-status.txt', 'r'))
    local text = file:read('*a'); file:close()
    return text
end
local function loadNative(name)
    return assert(package.loadlib(scripts .. '/NoclipCollisionToggleNative.dll', name))
end
local initialize = loadNative('luaopen_noclipcollisiontoggle')
local refresh = loadNative('luaopen_noclipcollisiontoggle_refresh')
local inspect = loadNative('luaopen_noclipcollisiontoggle_inspect')
initialize()
assert(readStatus():match('^ACTIVE:'), readStatus())

local function selectMovement(movement)
    local file = assert(io.open(scripts .. '/NoclipCollisionToggle-session.txt', 'w'))
    file:write(movement and string.format('%x', movement:GetAddress()) or '0')
    file:close()
    refresh()
    local status = readStatus()
    assert(status:match('^ACTIVE:'), status)
end

local function restore()
    selectMovement(nil)
    camera.restore()
    if not changed then return end
    if valid(changed.actor) then
        changed.actor:SetActorEnableCollision(changed.actorEnabled)
        assert(changed.actor:GetActorEnableCollision() == changed.actorEnabled)
    end
    if valid(changed.capsule) then
        changed.capsule:SetCollisionEnabled(changed.mode)
        assert(changed.capsule:GetCollisionEnabled() == changed.mode)
    end
    changed = nil
end

local function player()
    local characterClass = StaticFindObject('/Script/Astro.AstroCharacter')
    assert(valid(characterClass), 'Character class is unavailable.')
    for _, controller in ipairs(FindAllOf('PlayerController') or {}) do
        if valid(controller) and controller:IsLocalPlayerController() then
            local pawn = controller.Pawn
            assert(valid(pawn) and pawn:IsA(characterClass), 'Exit the vehicle and control your character first.')
            assert(not pawn.Driving, 'Exit the vehicle first.')
            assert(valid(pawn.CapsuleComponent), 'Player capsule is unavailable.')
            assert(valid(pawn.AstroMovementComponent), 'Player movement component is unavailable.')
            return pawn, controller
        end
    end
    error('Load a save first.')
end

local function disable()
    local pawn, controller = player()
    local capsule = pawn.CapsuleComponent
    if not changed or not valid(changed.actor) or changed.actor:GetAddress() ~= pawn:GetAddress() then
        restore()
        changed = {actor=pawn, capsule=capsule,
            actorEnabled=pawn:GetActorEnableCollision(), mode=capsule:GetCollisionEnabled()}
    end
    selectMovement(pawn.AstroMovementComponent)
    pawn:SetActorEnableCollision(false)
    capsule:SetCollisionEnabled(0)
    assert(not pawn:GetActorEnableCollision() and capsule:GetCollisionEnabled() == 0,
        'The game did not accept the collision change.')
    camera.disable(controller)
end

RegisterConsoleCommandHandler('noclip', function(_, parameters, output)
    local action = parameters[1] and parameters[1]:lower()
    if #parameters == 1 and action == 'status' then
        local _, result = pcall(function()
            inspect()
            local status = readStatus()
            assert(status:match('^ACTIVE:'), status)
            local state = status:match('Noclip (%a+)')
            assert(state == 'on' or state == 'off', status)
            return 'Noclip: ' .. state:upper() .. (state == 'on' and '. Use EVA or creative flight mode.' or '')
        end)
        output:Log(tostring(result) .. '\n')
        return true
    end
    if #parameters ~= 1 or (action ~= 'on' and action ~= 'off') then
        output:Log('Usage: noclip on | off | status. Default off.\n')
        return true
    end
    local ok, err = pcall(action == 'on' and disable or restore)
    local message = ok and (action == 'on' and 'Noclip enabled. Use EVA or creative flight mode.' or 'Noclip disabled.') or tostring(err)
    output:Log(message .. '\n')
    print('[Noclip Collision Toggle ' .. VERSION .. '] ' .. message .. '\n')
    return true
end)
print('[Noclip Collision Toggle ' .. VERSION .. '] Ready. Noclip starts off.\n')
