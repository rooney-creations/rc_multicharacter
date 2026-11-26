local previewCam = nil
local menuOpen = false
local isBusy = false
local previewToken = 0
local menuSessionToken = 0

local DEFAULT_PREVIEW_LOCATION = {
    pedCoords = vec4(969.25, 72.61, 116.18, 276.55),
    camCoords = vec4(972.2, 72.9, 116.68, 97.27),
}

local function getRandomLocation()
    local locs = Config and Config.Client and Config.Client.locations
    if type(locs) == 'table' and #locs > 0 then
        return locs[math.random(1, #locs)]
    end
    return DEFAULT_PREVIEW_LOCATION
end

local randomLocation = getRandomLocation()

local randomPeds = {
    {
        model = `mp_m_freemode_01`,
        headOverlays = {
            beard = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            complexion = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            bodyBlemishes = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            blush = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            lipstick = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            blemishes = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            eyebrows = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            makeUp = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            sunDamage = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            moleAndFreckles = { color = 0, style = 0, secondColor = 0, opacity = 0 },
            chestHair = { color = 0, style = 0, secondColor = 0, opacity = 1 },
            ageing = { color = 0, style = 0, secondColor = 0, opacity = 1 },
        },
        components = {
            { texture = 0, drawable = 0, component_id = 0 },
            { texture = 0, drawable = 0, component_id = 1 },
            { texture = 0, drawable = 0, component_id = 2 },
            { texture = 0, drawable = 0, component_id = 5 },
            { texture = 0, drawable = 0, component_id = 7 },
            { texture = 0, drawable = 0, component_id = 9 },
            { texture = 0, drawable = 0, component_id = 10 },
            { texture = 0, drawable = 15, component_id = 11 },
            { texture = 0, drawable = 15, component_id = 8 },
            { texture = 0, drawable = 15, component_id = 3 },
            { texture = 0, drawable = 34, component_id = 6 },
            { texture = 0, drawable = 61, component_id = 4 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 },
            { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 },
            { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        }
    },
    {
        model = `mp_f_freemode_01`,
        headBlend = {
            shapeMix = 0.3,
            skinFirst = 0,
            shapeFirst = 31,
            skinSecond = 0,
            shapeSecond = 0,
            skinMix = 0,
            thirdMix = 0,
            shapeThird = 0,
            skinThird = 0,
        },
        hair = {
            color = 0,
            style = 15,
            texture = 0,
            highlight = 0,
        },
        headOverlays = {
            chestHair = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            bodyBlemishes = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            beard = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            lipstick = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            complexion = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            blemishes = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            moleAndFreckles = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            makeUp = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            ageing = { secondColor = 0, opacity = 1, color = 0, style = 0 },
            eyebrows = { secondColor = 0, opacity = 1, color = 0, style = 0 },
            blush = { secondColor = 0, opacity = 0, color = 0, style = 0 },
            sunDamage = { secondColor = 0, opacity = 0, color = 0, style = 0 },
        },
        components = {
            { drawable = 0, component_id = 0, texture = 0 },
            { drawable = 0, component_id = 1, texture = 0 },
            { drawable = 0, component_id = 2, texture = 0 },
            { drawable = 0, component_id = 5, texture = 0 },
            { drawable = 0, component_id = 7, texture = 0 },
            { drawable = 0, component_id = 9, texture = 0 },
            { drawable = 0, component_id = 10, texture = 0 },
            { drawable = 15, component_id = 3, texture = 0 },
            { drawable = 15, component_id = 11, texture = 3 },
            { drawable = 14, component_id = 8, texture = 0 },
            { drawable = 15, component_id = 4, texture = 3 },
            { drawable = 35, component_id = 6, texture = 0 },
        },
        props = {
            { prop_id = 0, drawable = -1, texture = -1 },
            { prop_id = 1, drawable = -1, texture = -1 },
            { prop_id = 2, drawable = -1, texture = -1 },
            { prop_id = 6, drawable = -1, texture = -1 },
            { prop_id = 7, drawable = -1, texture = -1 },
        }
    }
}

local nationalities = {}
if Config.Client.limitNationalities then
    local nationalityList = lib.load('data.nationalities')
    if type(nationalityList) == 'table' then
        for i = 1, #nationalityList do
            nationalities[#nationalities + 1] = { value = nationalityList[i] }
        end
    end
end

local function applyNativeFallbackAppearance(pedHandle, preset)
    if preset.headBlend then
        SetPedHeadBlendData(
            pedHandle,
            preset.headBlend.shapeFirst or 0,
            preset.headBlend.shapeSecond or 0,
            preset.headBlend.shapeThird or 0,
            preset.headBlend.skinFirst or 0,
            preset.headBlend.skinSecond or 0,
            preset.headBlend.skinThird or 0,
            preset.headBlend.shapeMix or 0.0,
            preset.headBlend.skinMix or 0.0,
            preset.headBlend.thirdMix or 0.0,
            false
        )
    else
        SetPedDefaultComponentVariation(pedHandle)
    end

    if type(preset.components) == 'table' then
        for i = 1, #preset.components do
            local comp = preset.components[i]
            SetPedComponentVariation(pedHandle, comp.component_id, comp.drawable, comp.texture, 0)
        end
    end

    if type(preset.props) == 'table' then
        for i = 1, #preset.props do
            local prop = preset.props[i]
            if prop.drawable == -1 then
                ClearPedProp(pedHandle, prop.prop_id)
            else
                SetPedPropIndex(pedHandle, prop.prop_id, prop.drawable, prop.texture, true)
            end
        end
    end
end

local function placePreviewPedOnGround(unfreezeNow)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local loc = randomLocation and randomLocation.pedCoords or DEFAULT_PREVIEW_LOCATION.pedCoords
    local x, y, z, heading = loc.x, loc.y, loc.z, loc.w

    RequestCollisionAtCoord(x, y, z)
    local interior = GetInteriorAtCoords(x, y, z)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        LoadInterior(interior)
    end

    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, heading)

    local colDeadline = GetGameTimer() + 4000
    while (not HasCollisionLoadedAroundEntity(ped) or (interior ~= 0 and not IsInteriorReady(interior))) and GetGameTimer() < colDeadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(20)
    end

    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.5, false)
    if foundGround and math.abs(groundZ - z) <= 3.0 then
        SetEntityCoords(ped, x, y, groundZ, false, false, false, false)
        SetEntityHeading(ped, heading)
    end

    SetEntityCollision(ped, true, true)
    if unfreezeNow then
        FreezeEntityPosition(ped, false)
        ClearPedTasksImmediately(ped)
    else
        FreezeEntityPosition(ped, true)
    end
end

local function setupPreviewCam()
    placePreviewPedOnGround(true)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(1.0)

    previewCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        randomLocation.camCoords.x,
        randomLocation.camCoords.y,
        randomLocation.camCoords.z,
        -6.0,
        0.0,
        randomLocation.camCoords.w,
        40.0,
        false,
        0
    )
    SetCamActive(previewCam, true)
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 0.4)
    SetCamFarDof(previewCam, 1.8)
    SetCamDofStrength(previewCam, 0.7)
    RenderScriptCams(true, false, 1, true, true)
    DoScreenFadeIn(1000)

    CreateThread(function()
        while previewCam and DoesCamExist(previewCam) do
            SetUseHiDof()
            -- Keep preview ped standing naturally on the ground without walking off-frame
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            Wait(0)
        end
    end)
end

local function destroyPreviewCam()
    if not previewCam then return end

    SetTimecycleModifier('default')
    if DoesCamExist(previewCam) then
        SetCamActive(previewCam, false)
        DestroyCam(previewCam, true)
    end
    RenderScriptCams(false, false, 1, true, true)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
    previewCam = nil
end

local function endTutorialSession()
    if NetworkIsInTutorialSession() then
        NetworkEndTutorialSession()
        local timeout = GetGameTimer() + 3000
        while NetworkIsInTutorialSession() and GetGameTimer() < timeout do
            Wait(10)
        end
    end
    SetEntityInvincible(PlayerPedId(), false)
end

local function randomPed()
    local pedPreset = randomPeds[math.random(1, #randomPeds)]
    local timeoutMs = (Config and Config.Client and Config.Client.loadingModelsTimeout) or 30000
    local okModel = pcall(lib.requestModel, pedPreset.model, timeoutMs)
    if not okModel then return end

    SetPlayerModel(cache.playerId, pedPreset.model)
    local pedHandle = PlayerPedId()
    if DoesEntityExist(pedHandle) then
        SetPedDefaultComponentVariation(pedHandle)
    end

    if GetResourceState('illenium-appearance') == 'started' then
        pcall(function() exports['illenium-appearance']:setPedAppearance(pedHandle, pedPreset) end)
    elseif GetResourceState('fivem-appearance') == 'started' then
        pcall(function() exports['fivem-appearance']:setPedAppearance(pedHandle, pedPreset) end)
    else
        applyNativeFallbackAppearance(pedHandle, pedPreset)
    end

    SetModelAsNoLongerNeeded(pedPreset.model)
end

local helpers = {
    RandomPed = randomPed,
    DestroyPreviewCam = destroyPreviewCam,
    EndTutorialSession = endTutorialSession,
}

local function previewPed(charId)
    previewToken = previewToken + 1
    local myToken = previewToken

    if not charId then
        randomPed()
        if previewCam then
            placePreviewPedOnGround(true)
        end
        return
    end

    local previewData = lib.callback.await('rc_multicharacter:server:getPreviewPedData', false, charId)
    if not menuOpen or myToken ~= previewToken then
        return
    end

    local adapter = Bridge.Framework.GetAdapter()
    if previewData and adapter and adapter.ApplyPreviewSkin then
        adapter.ApplyPreviewSkin(previewData, PlayerPedId(), helpers)
    else
        randomPed()
    end

    if menuOpen and previewCam then
        placePreviewPedOnGround(true)
    end
end

local function spawnAt(coords, afterSpawnCb)
    DoScreenFadeOut(500)
    local fadeOutTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeOutTimeout do
        Wait(10)
    end

    destroyPreviewCam()
    endTutorialSession()

    local x = tonumber(coords.x) or Config.Shared.defaultSpawn.x
    local y = tonumber(coords.y) or Config.Shared.defaultSpawn.y
    local z = tonumber(coords.z) or Config.Shared.defaultSpawn.z
    local heading = tonumber(coords.w or coords.heading) or Config.Shared.defaultSpawn.w

    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    local colTimeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colTimeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(20)
    end

    local spawnedByManager = false
    if GetResourceState('spawnmanager') == 'started' then
        spawnedByManager = pcall(function()
            exports.spawnmanager:spawnPlayer({
                x = x,
                y = y,
                z = z,
                heading = heading,
            })
        end)
    end

    if not spawnedByManager then
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, true)
        SetEntityHeading(ped, heading)
        NetworkResurrectLocalPlayer(x, y, z, heading, 0, true)
        ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
    end

    if afterSpawnCb then
        afterSpawnCb()
    end

    DoScreenFadeIn(500)
    local fadeInTimeout = GetGameTimer() + 3000
    while not IsScreenFadedIn() and GetGameTimer() < fadeInTimeout do
        Wait(10)
    end
end

helpers.SpawnAt = spawnAt

local function characterDialog(fw)
    local nationalityOption = Config.Client.limitNationalities and #nationalities > 0 and {
        type = 'select',
        required = true,
        icon = 'user-shield',
        label = locale('info.nationality'),
        default = 'American',
        searchable = true,
        options = nationalities,
    } or {
        type = 'input',
        required = true,
        icon = 'user-shield',
        label = locale('info.nationality'),
        placeholder = 'American',
    }

    local fields = {
        {
            type = 'input',
            required = true,
            icon = 'user-pen',
            label = locale('info.first_name'),
            placeholder = 'Hank',
        },
        {
            type = 'input',
            required = true,
            icon = 'user-pen',
            label = locale('info.last_name'),
            placeholder = 'Jordan',
        },
        nationalityOption,
        {
            type = 'select',
            required = true,
            icon = 'circle-user',
            label = locale('info.gender'),
            placeholder = locale('info.select_gender'),
            options = {
                { value = locale('info.char_male') },
                { value = locale('info.char_female') },
            },
        },
        {
            type = 'date',
            required = true,
            icon = 'calendar-days',
            label = locale('info.birth_date'),
            format = Config.Client.dateFormat or 'YYYY-MM-DD',
            returnString = true,
            min = Config.Client.dateMin or '1900-01-01',
            max = Config.Client.dateMax or '2006-12-31',
            default = Config.Client.dateMax or '2006-12-31',
        },
    }

    if fw == 'esx' and Config.Client.askHeightOnEsx then
        fields[#fields + 1] = {
            type = 'number',
            required = true,
            icon = 'ruler-vertical',
            label = locale('info.height'),
            default = Config.Client.defaultHeight or 175,
            min = Config.Client.minHeight or 120,
            max = Config.Client.maxHeight or 220,
        }
    end

    return lib.inputDialog(locale('info.character_registration_title'), fields)
end

local function checkStrings(dialog, input)
    local str = dialog[input]
    if type(str) ~= 'string' then return false end
    local trimmed = str:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed == '' then return false end

    local profanity = Config.Client.profanityWords or {}
    if profanity[trimmed:lower()] then return false end

    local split = { string.strsplit(' ', trimmed) }
    if #split > 5 then return false end

    for i = 1, #split do
        if profanity[split[i]:lower()] then
            return false
        end
    end

    return true
end

local function capString(str)
    if type(str) ~= 'string' then return '' end
    return str:gsub('^%s+', ''):gsub('%s+$', ''):gsub("(%w)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local chooseCharacter

local function createCharacter(cid)
    if isBusy then return false end
    previewPed()

    local fw = Bridge.Framework.GetType()
    local adapter = Bridge.Framework.GetAdapter()

    ::retryDialog::
    local dialog = characterDialog(fw)
    if not dialog then return false end

    for input = 1, 3 do
        if not checkStrings(dialog, input) then
            Bridge.Framework.Notify(locale('error.no_match_character_registration'), 'error', 8000)
            goto retryDialog
        end
    end

    isBusy = true
    previewToken = previewToken + 1
    DoScreenFadeOut(150)

    if fw == 'esx' and adapter and adapter.SetAwaitingLoad then
        adapter.SetAwaitingLoad(true, helpers)
    end

    local defHeight = (Config and Config.Shared and Config.Shared.defaultHeight) or (Config and Config.Client and Config.Client.defaultHeight) or 175
    local result = lib.callback.await('rc_multicharacter:server:createCharacter', false, {
        firstname = capString(dialog[1]),
        lastname = capString(dialog[2]),
        nationality = capString(dialog[3]),
        gender = dialog[4] == locale('info.char_male') and 0 or 1,
        birthdate = dialog[5],
        height = dialog[6] or defHeight,
        cid = cid,
    })

    if not result or not result.success then
        if fw == 'esx' and adapter and adapter.SetAwaitingLoad then
            adapter.SetAwaitingLoad(false)
        end
        isBusy = false
        DoScreenFadeIn(250)
        Bridge.Framework.Notify(locale('error.character_create_failed'), 'error')
        return false
    end

    menuOpen = false
    isBusy = false

    if adapter and adapter.SpawnNewCharacter then
        adapter.SpawnNewCharacter(result.character, helpers)
    else
        spawnAt(Config.Shared.defaultSpawn)
    end

    return true
end

chooseCharacter = function()
    if menuOpen then return end
    menuOpen = true
    isBusy = false
    menuSessionToken = menuSessionToken + 1
    local myMenuToken = menuSessionToken

    local fw = Bridge.Framework.WaitForDetection(15000)
    if not fw then
        menuOpen = false
        lib.print.error('[rc_multicharacter] Could not detect active framework on client!')
        return
    end

    local characters, amount, dbReady = lib.callback.await('rc_multicharacter:server:getCharacters', false)
    if not dbReady then
        Bridge.Framework.Notify(locale('error.database_not_ready'), 'warning')
    end

    characters = type(characters) == 'table' and characters or {}
    amount = tonumber(amount) or 3
    if #characters > amount then
        amount = #characters
    end

    -- Map dense array by cid slot to avoid msgpack sparse-array truncation and out-of-range hiding
    local slotted = {}
    local overflow = {}
    local firstCharId = nil
    for i = 1, #characters do
        local ch = characters[i]
        if ch then
            local slot = tonumber(ch.cid)
            if slot and slot >= 1 and slot <= amount and not slotted[slot] then
                slotted[slot] = ch
            else
                overflow[#overflow + 1] = ch
            end
            if not firstCharId then
                firstCharId = ch.id
            end
        end
    end
    for i = 1, #overflow do
        for s = 1, amount do
            if not slotted[s] then
                slotted[s] = overflow[i]
                break
            end
        end
    end

    previewPed(firstCharId)

    randomLocation = getRandomLocation()
    SetFollowPedCamViewMode(2)
    DisplayRadar(false)

    DoScreenFadeOut(500)
    local fadeTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do
        Wait(10)
    end

    Wait(350)
    placePreviewPedOnGround(false)

    NetworkStartSoloTutorialSession()
    local tutTimeout = GetGameTimer() + 5000
    while not NetworkIsInTutorialSession() and GetGameTimer() < tutTimeout do
        Wait(10)
    end

    -- Invincibility watchdog while in character selection
    CreateThread(function()
        while myMenuToken == menuSessionToken and (menuOpen or NetworkIsInTutorialSession()) do
            local curPed = PlayerPedId()
            if DoesEntityExist(curPed) then
                SetEntityInvincible(curPed, true)
            end
            Wait(250)
        end
        if myMenuToken == menuSessionToken then
            local curPed = PlayerPedId()
            if DoesEntityExist(curPed) then
                SetEntityInvincible(curPed, false)
            end
        end
    end)

    Wait(1000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    setupPreviewCam()

    local options = {}
    for i = 1, amount do
        local character = slotted[i]
        local charinfo = character and character.charinfo
        local fullName = charinfo and ('%s %s'):format(charinfo.firstname or 'Unknown', charinfo.lastname or '') or 'Unknown'

        local meta = nil
        if character and charinfo then
            meta = {
                Name = fullName,
                Gender = charinfo.gender == 0 and locale('info.char_male') or locale('info.char_female'),
                Birthdate = charinfo.birthdate or 'N/A',
                Nationality = charinfo.nationality or 'N/A',
                ['Account Number'] = charinfo.account or character.citizenid or 'N/A',
                Bank = lib.math.groupdigits(character.money and character.money.bank or 0),
                Cash = lib.math.groupdigits(character.money and character.money.cash or 0),
                Job = (character.job and character.job.label) or 'Unemployed',
                ['Job Grade'] = (character.job and character.job.grade and character.job.grade.name) or 'None',
            }
            if character.gang then
                meta.Gang = character.gang.label or 'None'
                meta['Gang Grade'] = (character.gang.grade and character.gang.grade.name) or 'None'
            end
            if charinfo.phone and charinfo.phone ~= 'N/A' then
                meta['Phone Number'] = charinfo.phone
            end
        end

        options[i] = {
            title = character and ('%s - %s'):format(fullName, character.citizenid or ('Slot #' .. i)) or locale('info.multichar_new_character', i),
            description = character and character.disabled and locale('error.character_disabled') or nil,
            metadata = meta,
            icon = character and (character.disabled and 'ban' or 'user') or 'user-plus',
            disabled = character and character.disabled == true or false,
            onSelect = function()
                if isBusy then return end
                if character then
                    lib.showContext('rc_multichar_character_' .. i)
                    previewPed(character.id)
                else
                    local success = createCharacter(i)
                    if success then return end
                    previewPed(firstCharId)
                    lib.showContext('rc_multichar_characters')
                end
            end
        }

        if character and not character.disabled then
            local charSubOptions = {
                {
                    title = locale('info.play'),
                    description = locale('info.play_description', fullName),
                    icon = 'play',
                    onSelect = function()
                        if isBusy then return end
                        isBusy = true
                        previewToken = previewToken + 1
                        DoScreenFadeOut(150)

                        local adapter = Bridge.Framework.GetAdapter()
                        if fw == 'esx' and adapter and adapter.SetAwaitingLoad then
                            adapter.SetAwaitingLoad(true, helpers)
                        end

                        local loadRes = lib.callback.await('rc_multicharacter:server:loadCharacter', false, character.id)
                        if not loadRes or not loadRes.success then
                            if fw == 'esx' and adapter and adapter.SetAwaitingLoad then
                                adapter.SetAwaitingLoad(false)
                            end
                            isBusy = false
                            DoScreenFadeIn(250)
                            local errKey = loadRes and loadRes.error == 'character_disabled' and 'error.character_disabled' or 'error.character_load_failed'
                            Bridge.Framework.Notify(locale(errKey), 'error')
                            lib.showContext('rc_multichar_character_' .. i)
                            return
                        end

                        menuOpen = false
                        isBusy = false

                        if adapter and adapter.SpawnExistingCharacter then
                            adapter.SpawnExistingCharacter(character, loadRes, helpers)
                        else
                            spawnAt(character.position or Config.Shared.defaultSpawn)
                        end
                    end
                }
            }

            if Config.Shared.enableDeleteButton then
                charSubOptions[#charSubOptions + 1] = {
                    title = locale('info.delete_character'),
                    description = locale('info.delete_character_description', fullName),
                    icon = 'trash',
                    onSelect = function()
                        if isBusy then return end
                        local alert = lib.alertDialog({
                            header = locale('info.delete_character'),
                            content = locale('info.confirm_delete'),
                            centered = true,
                            cancel = true,
                        })
                        if alert == 'confirm' then
                            isBusy = true
                            previewToken = previewToken + 1
                            local delRes = lib.callback.await('rc_multicharacter:server:deleteCharacter', false, character.id)
                            local ok = delRes and delRes.success == true
                            Bridge.Framework.Notify(ok and locale('success.character_deleted') or locale('error.character_delete_failed'), ok and 'success' or 'error')
                            isBusy = false
                            menuOpen = false
                            destroyPreviewCam()
                            chooseCharacter()
                        else
                            lib.showContext('rc_multichar_character_' .. i)
                        end
                    end
                }
            end

            lib.registerContext({
                id = 'rc_multichar_character_' .. i,
                title = ('%s - %s'):format(fullName, character.citizenid or ('Slot #' .. i)),
                canClose = false,
                menu = 'rc_multichar_characters',
                options = charSubOptions,
            })
        end
    end

    lib.registerContext({
        id = 'rc_multichar_characters',
        title = locale('info.multichar_title'),
        canClose = false,
        options = options,
    })

    SetTimecycleModifier('default')
    lib.showContext('rc_multichar_characters')
end

RegisterNetEvent('rc_multicharacter:client:openMenu', function()
    if menuOpen then return end
    chooseCharacter()
end)

if Config.Shared.enableRelogCommand then
    RegisterCommand('relog', function()
        if menuOpen or isBusy then return end
        local res = lib.callback.await('rc_multicharacter:server:relog', false)
        if not res or not res.success then
            local msgKey = (res and res.error == 'relog_cooldown') and 'error.relog_cooldown' or 'error.relog_unavailable'
            Bridge.Framework.Notify(locale(msgKey), 'error')
        end
    end, false)
end

-- Bootstrap session start and logout listeners
CreateThread(function()
    local fw = Bridge.Framework.WaitForDetection(15000)
    if not fw then return end

    local adapter = Bridge.ClientAdapters[fw]
    if adapter and adapter.RegisterLogoutListener then
        adapter.RegisterLogoutListener(function()
            if not menuOpen then
                chooseCharacter()
            end
        end)
    end

    while true do
        Wait(100)
        if NetworkIsSessionStarted() then
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)
            chooseCharacter()
            break
        end
    end
end)

-- Deterministic cleanup on resource stop to prevent camera, tutorial session, or menu soft-locks
AddEventHandler('onResourceStop', function(resName)
    if GetCurrentResourceName() ~= resName then return end

    menuOpen = false
    isBusy = false

    pcall(function()
        if lib.getOpenContextMenu and lib.getOpenContextMenu() then
            lib.hideContext(false)
        end
    end)
    pcall(function()
        if lib.closeInputDialog then lib.closeInputDialog() end
    end)
    pcall(function()
        if lib.closeAlertDialog then lib.closeAlertDialog() end
    end)

    destroyPreviewCam()
    endTutorialSession()

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
    end
    DisplayRadar(true)
    SetTimecycleModifier('default')
    if IsScreenFadedOut() then
        DoScreenFadeIn(0)
    end
end)
