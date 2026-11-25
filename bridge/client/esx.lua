Bridge = Bridge or {}
Bridge.ClientAdapters = Bridge.ClientAdapters or {}

local ESXClient = {}
local awaitingLoad = false
local activeHelpers = nil

function ESXClient.SetAwaitingLoad(state, helpers)
    awaitingLoad = state == true
    if helpers then
        activeHelpers = helpers
    end
end

function ESXClient.ApplyPreviewSkin(previewData, _, helpers)
    if not previewData or not previewData.model or not previewData.skin then
        helpers.RandomPed()
        return
    end

    local okLoad = pcall(lib.requestModel, previewData.model, Config.Client.loadingModelsTimeout or 30000)
    if not okLoad then
        helpers.RandomPed()
        return
    end

    SetPlayerModel(cache.playerId, previewData.model)
    local currentPed = PlayerPedId()

    if previewData.mode == 'appearance' then
        if GetResourceState('illenium-appearance') == 'started' then
            pcall(function() exports['illenium-appearance']:setPedAppearance(currentPed, previewData.skin) end)
        elseif GetResourceState('fivem-appearance') == 'started' then
            pcall(function() exports['fivem-appearance']:setPedAppearance(currentPed, previewData.skin) end)
        end
    elseif previewData.mode == 'skinchanger' then
        if GetResourceState('skinchanger') == 'started' then
            TriggerEvent('skinchanger:loadSkin', previewData.skin)
        end
    end

    SetModelAsNoLongerNeeded(previewData.model)
end

local function spawnEsxPedAt(coords, cb)
    local x = tonumber(coords.x) or Config.Shared.defaultSpawn.x
    local y = tonumber(coords.y) or Config.Shared.defaultSpawn.y
    local z = tonumber(coords.z) or Config.Shared.defaultSpawn.z
    local heading = tonumber(coords.heading or coords.w) or Config.Shared.defaultSpawn.w

    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, true)
    SetEntityHeading(ped, heading)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(25)
    end

    NetworkResurrectLocalPlayer(x, y, z, heading, 0, true)
    ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(cache.playerId, true, 0)
    TriggerEvent('playerSpawned', { x = x, y = y, z = z, heading = heading })

    if cb then cb() end
end

local function applyGenderDefaultModel(sexInt)
    local model = sexInt == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
    if pcall(lib.requestModel, model, Config.Client.loadingModelsTimeout or 30000) then
        SetPlayerModel(cache.playerId, model)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetPedDefaultComponentVariation(ped)
        end
        SetModelAsNoLongerNeeded(model)
    end
end

local function openEsxSkinCreator(xPlayer)
    local isFemale = (xPlayer and (xPlayer.sex == 'f' or xPlayer.sex == 'F' or (xPlayer.variables and (xPlayer.variables.sex == 'f' or xPlayer.variables.sex == 'F')))) and true or false
    local sexInt = isFemale and 1 or 0

    if GetResourceState('esx_skin') == 'started' then
        if GetResourceState('skinchanger') == 'started' then
            local p = promise.new()
            TriggerEvent('skinchanger:loadSkin', { sex = sexInt }, function()
                p:resolve(true)
            end)
            SetTimeout(2000, function() if p.state == 0 then p:resolve(false) end end)
            Citizen.Await(p)
        end
        TriggerEvent('esx_skin:openSaveableMenu')
    elseif GetResourceState('illenium-appearance') == 'started' then
        applyGenderDefaultModel(sexInt)
        pcall(function()
            exports['illenium-appearance']:startPlayerCustomization(function(appearance)
                if appearance then
                    TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
                end
            end)
        end)
    elseif GetResourceState('fivem-appearance') == 'started' then
        applyGenderDefaultModel(sexInt)
        pcall(function()
            exports['fivem-appearance']:startPlayerCustomization(function(appearance)
                if appearance then
                    TriggerServerEvent('fivem-appearance:server:saveAppearance', appearance)
                end
            end)
        end)
    else
        applyGenderDefaultModel(sexInt)
    end
end

local function applyEsxExistingSkin(skin, xPlayer)
    if type(skin) == 'table' and (skin.model or skin.components or skin.headBlend) then
        local model = skin.model or ((xPlayer and (xPlayer.sex == 'f' or xPlayer.sex == 'F')) and `mp_f_freemode_01` or `mp_m_freemode_01`)
        if pcall(lib.requestModel, model, Config.Client.loadingModelsTimeout or 30000) then
            SetPlayerModel(cache.playerId, type(model) == 'number' and model or joaat(model))
            SetModelAsNoLongerNeeded(model)
        end
        local ped = PlayerPedId()
        if GetResourceState('illenium-appearance') == 'started' then
            pcall(function() exports['illenium-appearance']:setPedAppearance(ped, skin) end)
        elseif GetResourceState('fivem-appearance') == 'started' then
            pcall(function() exports['fivem-appearance']:setPedAppearance(ped, skin) end)
        end
        return
    end

    if GetResourceState('skinchanger') == 'started' and type(skin) == 'table' then
        local p = promise.new()
        TriggerEvent('skinchanger:loadSkin', skin, function()
            p:resolve(true)
        end)
        SetTimeout(2500, function() if p.state == 0 then p:resolve(false) end end)
        Citizen.Await(p)
    end
end

RegisterNetEvent('esx:playerLoaded', function(xPlayer, isNew, skin)
    if Bridge.Framework.GetType() ~= 'esx' or not awaitingLoad then
        return
    end
    awaitingLoad = false

    CreateThread(function()
        if activeHelpers then
            activeHelpers.DestroyPreviewCam()
            activeHelpers.EndTutorialSession()
        else
            if NetworkIsInTutorialSession() then
                NetworkEndTutorialSession()
            end
            DisplayRadar(true)
        end

        DoScreenFadeOut(250)
        Wait(250)

        local spawnCoords = Config.Shared.defaultSpawn
        if not isNew and xPlayer and xPlayer.coords and xPlayer.coords.x then
            spawnCoords = xPlayer.coords
        end

        if not isNew and skin then
            applyEsxExistingSkin(skin, xPlayer)
        end

        spawnEsxPedAt(spawnCoords, function()
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            TriggerEvent('esx:loadingScreenOff')

            DoScreenFadeIn(500)
            TriggerServerEvent('esx:onPlayerSpawn')
            TriggerEvent('esx:onPlayerSpawn')
            TriggerEvent('esx:restoreLoadout')

            if isNew then
                Wait(250)
                openEsxSkinCreator(xPlayer)
            end
        end)
    end)
end)

function ESXClient.SpawnExistingCharacter(_, _, helpers)
    activeHelpers = helpers
    -- esx:playerLoaded event handles camera teardown, skin restore, and spawn
end

function ESXClient.SpawnNewCharacter(_, helpers)
    activeHelpers = helpers
    -- esx:playerLoaded event handles camera teardown, default spawn, and skin creator
end

function ESXClient.RegisterLogoutListener(openMenuFn)
    RegisterNetEvent('esx:onPlayerLogout', function()
        if Bridge.Framework.GetType() ~= 'esx' then return end
        if GetResourceState('esx_skin') == 'started' then
            TriggerEvent('esx_skin:resetFirstSpawn')
        end
        Wait(350)
        openMenuFn()
    end)
end

Bridge.ClientAdapters.esx = ESXClient
