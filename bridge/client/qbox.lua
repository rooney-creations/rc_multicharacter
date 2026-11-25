Bridge = Bridge or {}
Bridge.ClientAdapters = Bridge.ClientAdapters or {}

local QBoxClient = {}

function QBoxClient.ApplyPreviewSkin(previewData, ped, helpers)
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
    local decoded = type(previewData.skin) == 'string' and json.decode(previewData.skin) or previewData.skin

    if decoded then
        if GetResourceState('illenium-appearance') == 'started' then
            pcall(function() exports['illenium-appearance']:setPedAppearance(currentPed, decoded) end)
        elseif GetResourceState('fivem-appearance') == 'started' then
            pcall(function() exports['fivem-appearance']:setPedAppearance(currentPed, decoded) end)
        elseif GetResourceState('qb-clothing') == 'started' then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', decoded, currentPed)
        end
    end

    SetModelAsNoLongerNeeded(previewData.model)
end

local function triggerLoadedEvents()
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    if GetResourceState('qb-houses') == 'started' or GetResourceState('qbx_houses') == 'started' then
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    end
    if GetResourceState('qb-apartments') == 'started' or GetResourceState('qbx_apartments') == 'started' then
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    end
    if GetResourceState('qb-weathersync') == 'started' then
        TriggerEvent('qb-weathersync:client:EnableSync')
    end
end

local function applyGenderDefaultModel(gender)
    local model = tonumber(gender) == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`
    if pcall(lib.requestModel, model, Config.Client.loadingModelsTimeout or 30000) then
        SetPlayerModel(cache.playerId, model)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetPedDefaultComponentVariation(ped)
        end
        SetModelAsNoLongerNeeded(model)
    end
end

local function openCharacterCreator(gender)
    if GetResourceState('illenium-appearance') == 'started' or GetResourceState('qb-clothing') == 'started' then
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    elseif GetResourceState('fivem-appearance') == 'started' then
        applyGenderDefaultModel(gender)
        pcall(function()
            exports['fivem-appearance']:startPlayerCustomization(function(appearance)
                if appearance then
                    TriggerServerEvent('fivem-appearance:server:saveAppearance', appearance)
                end
            end)
        end)
    else
        applyGenderDefaultModel(gender)
    end
end

function QBoxClient.SpawnExistingCharacter(character, loadResult, helpers)
    if not Config.Client.skipSpawnSelection then
        if GetResourceState('qbx_apartments') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.EndTutorialSession()
            TriggerEvent('apartments:client:setupSpawnUI', character.citizenid)
            return
        elseif GetResourceState('qbx_spawn') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.EndTutorialSession()
            TriggerEvent('qb-spawn:client:setupSpawns', character.citizenid)
            TriggerEvent('qb-spawn:client:openUI', true)
            return
        end
    end

    local okData, pData = pcall(function()
        return exports.qbx_core:GetPlayerData()
    end)
    local coords = (okData and pData and pData.position) or (loadResult and loadResult.position) or character.position or Config.Shared.defaultSpawn

    helpers.SpawnAt(coords, triggerLoadedEvents)
end

function QBoxClient.SpawnNewCharacter(newData, helpers)
    local gender = newData and newData.charinfo and newData.charinfo.gender
    if Config.Client.startingApartment then
        if GetResourceState('qbx_apartments') == 'started' or GetResourceState('qb-apartments') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.EndTutorialSession()
            TriggerEvent('apartments:client:setupSpawnUI', newData)
            return
        elseif GetResourceState('qbx_spawn') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.SpawnAt(Config.Shared.defaultSpawn, function()
                triggerLoadedEvents()
                openCharacterCreator(gender)
            end)
            return
        end
    end

    helpers.SpawnAt(Config.Shared.defaultSpawn, function()
        triggerLoadedEvents()
        openCharacterCreator(gender)
    end)
end

function QBoxClient.RegisterLogoutListener(openMenuFn)
    RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
        if Bridge.Framework.GetType() ~= 'qbox' then return end
        openMenuFn()
    end)
end

Bridge.ClientAdapters.qbox = QBoxClient
