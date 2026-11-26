Bridge = Bridge or {}
Bridge.Framework = Bridge.Framework or {}
Bridge.ServerAdapters = Bridge.ServerAdapters or {}
Bridge.ClientAdapters = Bridge.ClientAdapters or {}

local isServer = IsDuplicityVersion()
local detectedType = nil
local coreObject = nil

local function normalizeForcedFramework(val)
    if type(val) ~= 'string' then return 'auto' end
    local lower = val:lower()
    if lower == 'qbx' or lower == 'qbx_core' or lower == 'qbox' then
        return 'qbox'
    elseif lower == 'qb' or lower == 'qb-core' or lower == 'qbcore' then
        return 'qbcore'
    elseif lower == 'esx' or lower == 'es_extended' then
        return 'esx'
    end
    return 'auto'
end

local function isResourceActive(resName, includeStarting)
    local state = GetResourceState(resName)
    if state == 'started' then return true end
    if includeStarting and state == 'starting' then return true end
    return false
end

local function resolveCoreObject(fw)
    if fw == 'qbox' then
        local ok, obj = pcall(function()
            return exports.qbx_core
        end)
        return ok and obj or nil
    elseif fw == 'qbcore' then
        local ok, obj = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        return ok and obj or nil
    elseif fw == 'esx' then
        local ok, obj = pcall(function()
            return exports.es_extended:getSharedObject()
        end)
        if ok and obj then return obj end
        local rawEsx = rawget(_G, 'ESX')
        if rawEsx then return rawEsx end
        return nil
    end
    return nil
end

function Bridge.Framework.Detect(includeStarting)
    if detectedType and coreObject then
        return detectedType
    end

    local forced = normalizeForcedFramework(Config and Config.Shared and Config.Shared.framework or 'auto')

    -- Check qbx_core FIRST because qbx_core provides 'qb-core'
    if (forced == 'auto' or forced == 'qbox') and isResourceActive('qbx_core', includeStarting) then
        detectedType = 'qbox'
        coreObject = resolveCoreObject('qbox')
        return detectedType
    end

    if (forced == 'auto' or forced == 'qbcore') and isResourceActive('qb-core', includeStarting) then
        detectedType = 'qbcore'
        coreObject = resolveCoreObject('qbcore')
        return detectedType
    end

    if (forced == 'auto' or forced == 'esx') and isResourceActive('es_extended', includeStarting) then
        detectedType = 'esx'
        coreObject = resolveCoreObject('esx')
        return detectedType
    end

    return nil
end

function Bridge.Framework.WaitForDetection(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 15000)
    while true do
        local fw = Bridge.Framework.Detect(false)
        if fw and (fw == 'qbox' or coreObject ~= nil) then
            return fw
        end
        if GetGameTimer() >= deadline then
            return Bridge.Framework.Detect(true)
        end
        Wait(100)
    end
end

function Bridge.Framework.GetType()
    return detectedType or Bridge.Framework.Detect(false)
end

function Bridge.Framework.GetCore()
    local fw = Bridge.Framework.GetType()
    if fw and not coreObject then
        coreObject = resolveCoreObject(fw)
    end
    return coreObject
end

function Bridge.Framework.GetAdapter()
    local fw = Bridge.Framework.GetType()
    if not fw then return nil end
    if isServer then
        return Bridge.ServerAdapters[fw]
    end
    return Bridge.ClientAdapters[fw]
end

function Bridge.Framework.Notify(sourceOrMsg, msgOrType, typeOrDuration, durationOrNil)
    if isServer then
        local src = sourceOrMsg
        local msg = msgOrType
        local notifyType = typeOrDuration or 'inform'
        local duration = durationOrNil or 5000
        if not src or src == 0 then return end
        TriggerClientEvent('ox_lib:notify', src, {
            description = tostring(msg or ''),
            type = notifyType,
            duration = duration,
            position = (Config and Config.Shared and Config.Shared.notifyPosition) or 'top-right',
        })
    else
        local msg = sourceOrMsg
        local notifyType = msgOrType or 'inform'
        local duration = typeOrDuration or 5000
        lib.notify({
            description = tostring(msg or ''),
            type = notifyType,
            duration = duration,
            position = (Config and Config.Shared and Config.Shared.notifyPosition) or 'top-right',
        })
    end
end

function Bridge.Framework.IsAdmin(source)
    if not isServer then return false end
    local src = tonumber(source)
    if not src or src <= 0 then return true end

    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'rc_multicharacter.admin') or IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'group.god') then
        return true
    end

    local fw = Bridge.Framework.GetType()
    local core = Bridge.Framework.GetCore()
    if fw == 'qbox' then
        local ok, res = pcall(function()
            return exports.qbx_core:HasPermission(src, { 'god', 'admin', 'mod' })
        end)
        if ok and res then return true end
    elseif fw == 'qbcore' and core and core.Functions and core.Functions.HasPermission then
        if core.Functions.HasPermission(src, 'god') or core.Functions.HasPermission(src, 'admin') then
            return true
        end
    elseif fw == 'esx' and core and core.GetPlayerFromId then
        local xPlayer = core.GetPlayerFromId(src)
        if xPlayer and xPlayer.getGroup then
            local grp = tostring(xPlayer.getGroup()):lower()
            if grp == 'admin' or grp == 'superadmin' or grp == 'owner' or grp == 'god' then
                return true
            end
        end
    end

    return false
end
