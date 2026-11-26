Bridge = Bridge or {}
Bridge.ServerAdapters = Bridge.ServerAdapters or {}

local ESXAdapter = {}
local pendingCreations = {}

local function getCore()
    return Bridge.Framework.GetCore()
end

local function getPrefix()
    return (Config.Shared and Config.Shared.esxPrefix) or 'char'
end

local function awaitEsxJobs(ESX)
    if not ESX then return {} end
    local jobs = (ESX.GetJobs and ESX.GetJobs()) or ESX.Jobs or {}
    local deadline = GetGameTimer() + 8000
    while not next(jobs) and GetGameTimer() < deadline do
        Wait(100)
        jobs = (ESX.GetJobs and ESX.GetJobs()) or ESX.Jobs or {}
    end
    return jobs
end

local function convertPosition(rawPos)
    local pos = DB.SafeDecodeJson(rawPos, nil)
    local defaultSpawn = Config.Shared.defaultSpawn
    if not pos or not pos.x or not pos.y or not pos.z then
        return vec4(defaultSpawn.x, defaultSpawn.y, defaultSpawn.z, defaultSpawn.w)
    end
    return vec4(tonumber(pos.x) or defaultSpawn.x, tonumber(pos.y) or defaultSpawn.y, tonumber(pos.z) or defaultSpawn.z, tonumber(pos.heading or pos.w) or defaultSpawn.w)
end

function ESXAdapter.GetIdentifiers(source)
    local ESX = getCore()
    local rawId = nil
    if ESX and ESX.GetIdentifier then
        local ok, id = pcall(ESX.GetIdentifier, source)
        if ok and type(id) == 'string' and id ~= '' then
            rawId = id
        end
    end

    if not rawId then
        local idType = 'license'
        if ESX and ESX.GetConfig then
            local okCfg, cfg = pcall(ESX.GetConfig, 'Identifier')
            if okCfg and type(cfg) == 'string' and cfg ~= '' then
                idType = cfg
            end
        end
        local full = GetPlayerIdentifierByType(source, idType) or GetPlayerIdentifierByType(source, 'license') or GetPlayerIdentifierByType(source, 'license2')
        if full then
            rawId = full:gsub('^[^:]+:', '')
        end
    end

    local licenseFull = GetPlayerIdentifierByType(source, 'license')
    local license2Full = GetPlayerIdentifierByType(source, 'license2')
    return {
        raw = rawId,
        primary = rawId,
        list = { rawId, licenseFull, license2Full },
    }
end

function ESXAdapter.GetAllowedSlots(source)
    local ids = ESXAdapter.GetIdentifiers(source)
    local dbSlots = DB.GetSlotOverride(ids.list)
    if dbSlots then return dbSlots end

    local overrides = Config.Server.playersNumberOfCharacters or {}
    for i = 1, #ids.list do
        local k = ids.list[i]
        if k and overrides[k] then
            return tonumber(overrides[k]) or Config.Server.defaultNumberOfCharacters
        end
    end
    return Config.Server.defaultNumberOfCharacters or 3
end

local function parseCharSlot(identifier, rawId)
    if type(identifier) ~= 'string' or type(rawId) ~= 'string' then return nil end
    local prefix = getPrefix()
    local expectedSuffix = ':' .. rawId
    if identifier:sub(-#expectedSuffix) ~= expectedSuffix then
        return nil
    end
    local slotStr = identifier:sub(#prefix + 1, #identifier - #expectedSuffix)
    if identifier:sub(1, #prefix) ~= prefix then
        return nil
    end
    local slot = tonumber(slotStr)
    if not slot or slot < 1 or slot ~= math.floor(slot) then
        return nil
    end
    return slot
end

function ESXAdapter.GetCharacters(source)
    local ESX = getCore()
    local ids = ESXAdapter.GetIdentifiers(source)
    local maxSlots = ESXAdapter.GetAllowedSlots(source)
    if not ids.raw then return {}, maxSlots end

    -- Ensure any in-flight esx:playerLogout save finishes clearing ESX.Players[source]
    if ESX and ESX.GetPlayerFromId then
        local waitDeadline = GetGameTimer() + 3000
        while ESX.GetPlayerFromId(source) and GetGameTimer() < waitDeadline do
            Wait(50)
        end
    end

    local jobs = awaitEsxJobs(ESX)
    local prefix = getPrefix()

    local placeholders = {}
    local targetIds = {}
    for i = 1, maxSlots do
        placeholders[i] = '?'
        targetIds[i] = ('%s%d:%s'):format(prefix, i, ids.raw)
    end

    local hasSsn = DB.ColumnExists('users', 'ssn')
    local hasNationality = DB.ColumnExists('users', 'nationality')
    local hasDisabled = DB.ColumnExists('users', 'disabled')
    local hasMetadata = DB.ColumnExists('users', 'metadata')

    local cols = {
        'identifier',
        'accounts',
        'job',
        'job_grade',
        'firstname',
        'lastname',
        'dateofbirth',
        'sex',
        'height',
        'position',
    }
    if hasSsn then cols[#cols + 1] = 'ssn' end
    if hasNationality then cols[#cols + 1] = 'nationality' end
    if hasDisabled then cols[#cols + 1] = 'disabled' end
    if hasMetadata then cols[#cols + 1] = 'metadata' end

    local query = ('SELECT %s FROM users WHERE identifier IN (%s)'):format(
        table.concat(cols, ', '),
        table.concat(placeholders, ', ')
    )

    local ok, rows = pcall(MySQL.query.await, query, targetIds)
    if not ok or type(rows) ~= 'table' then
        lib.print.error(('[rc_multicharacter:esx] Failed fetching characters: %s'):format(tostring(rows)))
        return {}, maxSlots
    end

    local chars = {}
    for i = 1, #rows do
        local row = rows[i]
        local slot = parseCharSlot(row.identifier, ids.raw)
        if slot then
            local accounts = DB.SafeDecodeJson(row.accounts, {})
            local metadata = DB.SafeDecodeJson(row.metadata, {})
            local jobName = row.job or 'unemployed'
            local gradeKey = tostring(row.job_grade or 0)
            local jobLabel = jobName
            local gradeLabel = gradeKey

            local jobObj = jobs and jobs[jobName]
            if jobObj then
                jobLabel = jobObj.label or jobName
                local gObj = jobObj.grades and (jobObj.grades[gradeKey] or jobObj.grades[tonumber(gradeKey)])
                if gObj then
                    gradeLabel = gObj.label or gObj.name or gradeKey
                end
            end

            local genderNum = (row.sex == 'f' or row.sex == 'F' or tonumber(row.sex) == 1) and 1 or 0
            local disabledFlag = row.disabled == true or row.disabled == 1 or row.disabled == '1'

            chars[#chars + 1] = {
                id = row.identifier,
                citizenid = row.ssn or ('SLOT-' .. slot),
                cid = slot,
                disabled = disabledFlag,
                charinfo = {
                    firstname = row.firstname or 'Unknown',
                    lastname = row.lastname or ('Character #' .. slot),
                    birthdate = row.dateofbirth or '01/01/2000',
                    gender = genderNum,
                    nationality = row.nationality or metadata.nationality or 'N/A',
                    phone = metadata.phone_number or metadata.phone or 'N/A',
                    account = row.ssn or ('CHAR-' .. slot),
                },
                money = {
                    bank = tonumber(accounts.bank) or 0,
                    cash = tonumber(accounts.money) or 0,
                },
                job = {
                    name = jobName,
                    label = jobLabel,
                    grade = {
                        name = gradeLabel,
                        level = tonumber(row.job_grade) or 0,
                    },
                },
                gang = nil,
                position = convertPosition(row.position),
                metadata = metadata,
            }
        end
    end

    table.sort(chars, function(a, b)
        return a.cid < b.cid
    end)

    return chars, maxSlots
end

function ESXAdapter.GetPreviewSkin(source, charId)
    local ids = ESXAdapter.GetIdentifiers(source)
    local slot = parseCharSlot(charId, ids.raw)
    if not slot then return nil end

    if not DB.ColumnExists('users', 'skin') then return nil end
    local ok, row = pcall(MySQL.single.await, 'SELECT skin, sex FROM users WHERE identifier = ? LIMIT 1', { charId })
    if not ok or not row then return nil end

    local skinData = DB.SafeDecodeJson(row.skin, nil)
    if not skinData then return nil end

    if skinData.model or skinData.components or skinData.headBlend then
        local defaultModel = (row.sex == 'f' or row.sex == 'F') and 'mp_f_freemode_01' or 'mp_m_freemode_01'
        local modelHash = type(skinData.model) == 'number' and skinData.model or joaat(skinData.model or defaultModel)
        return {
            mode = 'appearance',
            model = modelHash,
            skin = skinData,
        }
    end

    local isFemale = tonumber(skinData.sex) == 1 or row.sex == 'f' or row.sex == 'F'
    return {
        mode = 'skinchanger',
        model = isFemale and `mp_f_freemode_01` or `mp_m_freemode_01`,
        skin = skinData,
    }
end

function ESXAdapter.LoadCharacter(source, charId)
    local ESX = getCore()
    if not ESX then return { success = false, error = 'core_unavailable' } end

    local ids = ESXAdapter.GetIdentifiers(source)
    local maxSlots = ESXAdapter.GetAllowedSlots(source)
    local slot = parseCharSlot(charId, ids.raw)
    if not slot or slot > maxSlots then
        return { success = false, error = 'exploit_ownership' }
    end

    local hasDisabled = DB.ColumnExists('users', 'disabled')
    local query = hasDisabled
        and 'SELECT identifier, disabled FROM users WHERE identifier = ? LIMIT 1'
        or 'SELECT identifier FROM users WHERE identifier = ? LIMIT 1'

    local okRow, row = pcall(MySQL.single.await, query, { charId })
    if not okRow or not row then
        return { success = false, error = 'character_not_found' }
    end

    if hasDisabled and (row.disabled == true or row.disabled == 1 or row.disabled == '1') then
        return { success = false, error = 'character_disabled' }
    end

    if ESX.GetPlayerFromIdentifier and ESX.GetPlayerFromIdentifier(charId) then
        return { success = false, error = 'already_loaded' }
    end

    if ESX.GetPlayerFromId and ESX.GetPlayerFromId(source) then
        return { success = false, error = 'already_loaded' }
    end

    SetPlayerRoutingBucket(source, 0)
    local charTag = ('%s%d'):format(getPrefix(), slot)
    TriggerEvent('esx:onPlayerJoined', source, charTag)

    local deadline = GetGameTimer() + 10000
    while not (ESX.GetPlayerFromId and ESX.GetPlayerFromId(source)) and GetGameTimer() < deadline do
        Wait(50)
    end

    if not (ESX.GetPlayerFromId and ESX.GetPlayerFromId(source)) then
        return { success = false, error = 'login_timeout' }
    end

    lib.print.info(('[rc_multicharacter:esx] %s (Identifier: %s | ID: %s) loaded!'):format(GetPlayerName(source) or 'Player', charId, source))
    return { success = true, citizenid = charId }
end

local function giveStarterItems(source, xPlayer)
    if not Config.Server.giveStarterItems then return end
    local items = Config.Shared.starterItems or {}
    local useOxInv = GetResourceState('ox_inventory') == 'started'

    if useOxInv then
        local deadline = GetGameTimer() + 5000
        while not exports.ox_inventory:GetInventory(source) do
            if GetGameTimer() >= deadline then break end
            Wait(100)
        end
    end

    for i = 1, #items do
        local item = items[i]
        if useOxInv then
            local meta = type(item.metadata) == 'table' and item.metadata or nil
            pcall(function()
                exports.ox_inventory:AddItem(source, item.name, item.amount or 1, meta)
            end)
        elseif xPlayer and xPlayer.addInventoryItem then
            pcall(xPlayer.addInventoryItem, item.name, item.amount or 1)
        end
    end
end

function ESXAdapter.CreateCharacter(source, charinfo)
    local ESX = getCore()
    if not ESX then return { success = false, error = 'core_unavailable' } end

    local ids = ESXAdapter.GetIdentifiers(source)
    if not ids.raw then return { success = false, error = 'no_identifier' } end

    local existing, maxSlots = ESXAdapter.GetCharacters(source)
    if #existing >= maxSlots then
        return { success = false, error = 'max_slots_reached' }
    end

    local usedSlots = {}
    for i = 1, #existing do
        usedSlots[existing[i].cid] = true
    end

    local targetSlot = nil
    local requestedCid = tonumber(charinfo.cid)
    if requestedCid and requestedCid >= 1 and requestedCid <= maxSlots and not usedSlots[requestedCid] then
        targetSlot = math.floor(requestedCid)
    else
        for s = 1, maxSlots do
            if not usedSlots[s] then
                targetSlot = s
                break
            end
        end
    end

    if not targetSlot then
        return { success = false, error = 'max_slots_reached' }
    end

    local prefix = getPrefix()
    local charTag = ('%s%d'):format(prefix, targetSlot)
    local fullIdentifier = ('%s:%s'):format(charTag, ids.raw)

    local esxData = {
        firstname = charinfo.firstname,
        lastname = charinfo.lastname,
        dateofbirth = charinfo.birthdate,
        sex = charinfo.gender == 0 and 'm' or 'f',
        height = tonumber(charinfo.height) or (Config.Shared and Config.Shared.defaultHeight) or 175,
    }

    pendingCreations[source] = {
        identifier = fullIdentifier,
        nationality = charinfo.nationality,
    }

    SetPlayerRoutingBucket(source, 0)
    TriggerEvent('esx:onPlayerJoined', source, charTag, esxData)

    local deadline = GetGameTimer() + 10000
    local xPlayer = nil
    while GetGameTimer() < deadline do
        xPlayer = ESX.GetPlayerFromId and ESX.GetPlayerFromId(source)
        if xPlayer then break end
        Wait(50)
    end

    pendingCreations[source] = nil

    if not xPlayer then
        return { success = false, error = 'create_timeout' }
    end

    if charinfo.nationality and charinfo.nationality ~= '' then
        if DB.ColumnExists('users', 'nationality') then
            pcall(MySQL.update.await, 'UPDATE users SET nationality = ? WHERE identifier = ?', { charinfo.nationality, fullIdentifier })
        end
        if xPlayer.setMeta then
            pcall(xPlayer.setMeta, 'nationality', charinfo.nationality)
        end
    end

    giveStarterItems(source, xPlayer)

    lib.print.info(('[rc_multicharacter:esx] %s created a new character (%s)'):format(GetPlayerName(source) or 'Player', fullIdentifier))
    return {
        success = true,
        character = {
            citizenid = fullIdentifier,
            cid = targetSlot,
            charinfo = charinfo,
        },
    }
end

function ESXAdapter.DeleteCharacter(source, charId)
    local ids = ESXAdapter.GetIdentifiers(source)
    local maxSlots = ESXAdapter.GetAllowedSlots(source)
    local slot = parseCharSlot(charId, ids.raw)
    if not slot or slot > maxSlots then
        return { success = false, error = 'exploit_ownership' }
    end

    local tables = DB.DiscoverEsxCharacterTables()
    local deleted = DB.SafeDeleteByTables(tables, charId)
    return { success = deleted }
end

function ESXAdapter.ForceDeleteCharacter(charId)
    if type(charId) ~= 'string' or charId == '' then return false end
    local ESX = getCore()
    if ESX and ESX.GetPlayerFromIdentifier then
        local xPlayer = ESX.GetPlayerFromIdentifier(charId)
        if xPlayer and xPlayer.source then
            DropPlayer(xPlayer.source, 'An admin deleted the character which you are currently using')
        end
    end
    local tables = DB.DiscoverEsxCharacterTables()
    return DB.SafeDeleteByTables(tables, charId)
end

function ESXAdapter.Logout(source)
    local ESX = getCore()
    if not ESX or not ESX.GetPlayerFromId or not ESX.GetPlayerFromId(source) then
        return false
    end

    local done = promise.new()
    TriggerEvent('esx:playerLogout', source, function()
        done:resolve(true)
    end)

    SetTimeout(8000, function()
        if done.state == 0 then
            done:resolve(false)
        end
    end)

    return Citizen.Await(done)
end

function ESXAdapter.IsPlayerLoaded(source)
    local ESX = getCore()
    if not ESX or not ESX.GetPlayerFromId then return false end
    return ESX.GetPlayerFromId(source) ~= nil
end

function ESXAdapter.OnPlayerDropped(source)
    pendingCreations[source] = nil
end

function ESXAdapter.CheckStartupDiagnostics()
    local ESX = getCore()
    if ESX and ESX.GetConfig then
        local ok, cfg = pcall(ESX.GetConfig)
        if ok and cfg and cfg.Multichar == false then
            lib.print.error('[rc_multicharacter] ESX Config.Multichar is FALSE! Ensure `provide "esx_multicharacter"` is active and no conflicting es_extended config overrides it.')
        end
    end
end

-- When Config.Multichar is true, es_extended disables its own playerConnecting check.
-- Guard identifiers cleanly so connecting players never hang without a license.
CreateThread(function()
    local fw = Bridge.Framework.WaitForDetection(10000)
    if fw ~= 'esx' then return end

    AddEventHandler('playerConnecting', function(_, _, deferrals)
        local src = source
        local ESX = getCore()
        if not ESX or not ESX.GetConfig then return end
        local okCfg, cfg = pcall(ESX.GetConfig)
        if not okCfg or not cfg or not cfg.Multichar then return end

        deferrals.defer()
        Wait(0)

        if not DB.AwaitReady(10000) then
            return deferrals.done('[rc_multicharacter] Database connection is not ready yet. Please retry.')
        end

        local okId, identifier = pcall(ESX.GetIdentifier, src)
        if not okId or not identifier or identifier == '' then
            return deferrals.done('[rc_multicharacter] Unable to retrieve your Rockstar/player identifier.')
        end

        local okDbg, esxCfg = pcall(ESX.GetConfig)
        local debugMode = okDbg and esxCfg and esxCfg.EnableDebug == true
        if not debugMode and ESX.GetExtendedPlayers then
            local suffix = ':' .. identifier
            local activePlayers = ESX.GetExtendedPlayers()
            for i = 1, #activePlayers do
                local xP = activePlayers[i]
                if xP and type(xP.identifier) == 'string' and xP.identifier:sub(-#suffix) == suffix then
                    local existingSrc = tonumber(xP.source)
                    if existingSrc and GetPlayerPing(existingSrc) > 0 then
                        return deferrals.done(('[rc_multicharacter] Your identifier (%s) is already active on the server.'):format(identifier))
                    elseif existingSrc then
                        deferrals.update('[rc_multicharacter] Cleaning stale character session...')
                        TriggerEvent('esx:onPlayerDropped', existingSrc, 'rc_multicharacter_stale_cleanup')
                        Wait(250)
                    end
                end
            end
        end

        deferrals.done()
    end)
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local pending = pendingCreations[playerId]
    if not pending then return end
    pendingCreations[playerId] = nil
    if pending.nationality and pending.nationality ~= '' and xPlayer and xPlayer.setMeta then
        pcall(xPlayer.setMeta, 'nationality', pending.nationality)
    end
end)

Bridge.ServerAdapters.esx = ESXAdapter
