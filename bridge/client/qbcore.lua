Bridge = Bridge or {}
Bridge.ClientAdapters = Bridge.ClientAdapters or {}

local QBCoreClient = {}

function QBCoreClient.ApplyPreviewSkin(previewData, ped, helpers)
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
    if DoesEntityExist(currentPed) then
        SetPedDefaultComponentVariation(currentPed)
    end
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
    -- On QBCore, QBCore:Server:OnPlayerLoaded automatically emits QBCore:Client:OnPlayerLoaded back to the client
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    if GetResourceState('qb-houses') == 'started' then
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    end
    if GetResourceState('qb-apartments') == 'started' then
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

function QBCoreClient.SpawnExistingCharacter(character, loadResult, helpers)
    if not Config.Client.skipSpawnSelection then
        if GetResourceState('qb-apartments') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.EndTutorialSession()
            TriggerEvent('apartments:client:setupSpawnUI', character)
            return
        elseif GetResourceState('qb-spawn') == 'started' then
            helpers.DestroyPreviewCam()
            helpers.EndTutorialSession()
            TriggerEvent('qb-spawn:client:setupSpawns', character, false, nil)
            TriggerEvent('qb-spawn:client:openUI', true)
            return
        end
    end

    local coords = (loadResult and loadResult.position) or character.position or Config.Shared.defaultSpawn
    local inside = loadResult and loadResult.inside

    helpers.SpawnAt(coords, function()
        if inside and inside.house and GetResourceState('qb-houses') == 'started' then
            TriggerEvent('qb-houses:client:LastLocationHouse', inside.house)
        elseif inside and inside.apartment and inside.apartment.apartmentType and inside.apartment.apartmentId and GetResourceState('qb-apartments') == 'started' then
            TriggerEvent('qb-apartments:client:LastLocationHouse', inside.apartment.apartmentType, inside.apartment.apartmentId)
        end
        triggerLoadedEvents()
    end)
end

function QBCoreClient.SpawnNewCharacter(newData, helpers)
    local gender = newData and newData.charinfo and newData.charinfo.gender
    if Config.Client.startingApartment and GetResourceState('qb-apartments') == 'started' then
        helpers.DestroyPreviewCam()
        helpers.EndTutorialSession()
        TriggerEvent('apartments:client:setupSpawnUI', newData)
        return
    end

    helpers.SpawnAt(Config.Shared.defaultSpawn, function()
        triggerLoadedEvents()
        openCharacterCreator(gender)
    end)
end

function QBCoreClient.RegisterLogoutListener(openMenuFn)
    RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
        if Bridge.Framework.GetType() ~= 'qbcore' then return end
        openMenuFn()
    end)
end

Bridge.ClientAdapters.qbcore = QBCoreClient
