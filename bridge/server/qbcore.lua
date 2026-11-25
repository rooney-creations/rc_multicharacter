Bridge = Bridge or {}
Bridge.ServerAdapters = Bridge.ServerAdapters or {}

local QBCoreAdapter = {}

local function getCore()
    return Bridge.Framework.GetCore()
end

local function convertPosition(rawPos)
    local pos = DB.SafeDecodeJson(rawPos, nil)
    local defaultSpawn = Config.Shared.defaultSpawn
    if not pos or not pos.x or not pos.y or not pos.z then
        return vec4(defaultSpawn.x, defaultSpawn.y, defaultSpawn.z, defaultSpawn.w)
    end
    return vec4(tonumber(pos.x) or defaultSpawn.x, tonumber(pos.y) or defaultSpawn.y, tonumber(pos.z) or defaultSpawn.z, tonumber(pos.w) or defaultSpawn.w)
end

function QBCoreAdapter.GetIdentifiers(source)
    local QBCore = getCore()
    local license = nil
    if QBCore and QBCore.Functions and QBCore.Functions.GetIdentifier then
        license = QBCore.Functions.GetIdentifier(source, 'license')
    end
    license = license or GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    return {
        license = license,
        license2 = license2,
        primary = license or license2,
        list = { license, license2 },
    }
end

function QBCoreAdapter.GetAllowedSlots(source)
    local ids = QBCoreAdapter.GetIdentifiers(source)
    local dbSlots = DB.GetSlotOverride(ids.list)
    if dbSlots then return dbSlots end

    local overrides = Config.Server.playersNumberOfCharacters or {}
    if ids.license and overrides[ids.license] then
        return tonumber(overrides[ids.license]) or Config.Server.defaultNumberOfCharacters
    end
    if ids.license2 and overrides[ids.license2] then
        return tonumber(overrides[ids.license2]) or Config.Server.defaultNumberOfCharacters
    end
    return Config.Server.defaultNumberOfCharacters or 3
end

function QBCoreAdapter.GetCharacters(source)
    local ids = QBCoreAdapter.GetIdentifiers(source)
    if not ids.license then return {}, QBCoreAdapter.GetAllowedSlots(source) end

    DB.NormalizeCids(ids.license, nil)

    local ok, rows = pcall(
        MySQL.query.await,
        'SELECT citizenid, cid, license, name, charinfo, money, job, gang, position, metadata, UNIX_TIMESTAMP(last_updated) AS lastUpdatedUnix FROM players WHERE license = ? ORDER BY cid ASC',
        { ids.license }
    )

    if not ok or type(rows) ~= 'table' then
        lib.print.error(('[rc_multicharacter:qbcore] Failed fetching characters: %s'):format(tostring(rows)))
        return {}, QBCoreAdapter.GetAllowedSlots(source)
    end

    local chars = {}
    for i = 1, #rows do
        local row = rows[i]
        local charinfo = DB.SafeDecodeJson(row.charinfo, {})
        local money = DB.SafeDecodeJson(row.money, {})
        local job = DB.SafeDecodeJson(row.job, nil)
        local gang = DB.SafeDecodeJson(row.gang, nil)
        local metadata = DB.SafeDecodeJson(row.metadata, {})

        chars[#chars + 1] = {
            id = row.citizenid,
            citizenid = row.citizenid,
            cid = tonumber(charinfo.cid) or tonumber(row.cid) or i,
            charinfo = charinfo,
            money = {
                bank = tonumber(money.bank) or 0,
                cash = tonumber(money.cash) or 0,
            },
            job = job,
            gang = gang,
            position = convertPosition(row.position),
            metadata = metadata,
            lastLoggedOut = row.lastUpdatedUnix,
        }
    end

    return chars, QBCoreAdapter.GetAllowedSlots(source)
end

function QBCoreAdapter.GetPreviewSkin(source, charId)
    if type(charId) ~= 'string' or charId == '' then return nil end

    local ids = QBCoreAdapter.GetIdentifiers(source)
    local ownerOk, ownerRow = pcall(MySQL.single.await, 'SELECT license FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not ownerOk or not ownerRow or ownerRow.license ~= ids.license then
        return nil
    end

    if not DB.TableExists('playerskins') then return nil end
    local ok, ped = pcall(MySQL.single.await, 'SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { charId })
    if not ok or not ped or not ped.model or not ped.skin then return nil end

    local modelHash = tonumber(ped.model) or joaat(ped.model)
    return {
        mode = 'appearance',
        model = modelHash,
        skin = ped.skin,
    }
end

function QBCoreAdapter.LoadCharacter(source, charId)
    local QBCore = getCore()
    if not QBCore or not QBCore.Player or type(charId) ~= 'string' or charId == '' then
        return { success = false, error = 'invalid_character' }
    end

    local ids = QBCoreAdapter.GetIdentifiers(source)
    local okRow, row = pcall(MySQL.single.await, 'SELECT license, position, charinfo, metadata FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not okRow or not row then
        return { success = false, error = 'character_not_found' }
    end

    if row.license ~= ids.license then
        return { success = false, error = 'exploit_ownership' }
    end

    local okLogin, success = pcall(QBCore.Player.Login, source, charId)
    if not okLogin or not success then
        return { success = false, error = 'login_failed' }
    end

    local deadline = GetGameTimer() + 5000
    while not QBCore.Players[source] and GetGameTimer() < deadline do
        Wait(50)
    end

    if QBCore.Commands and QBCore.Commands.Refresh then
        pcall(QBCore.Commands.Refresh, source)
    end

    local metadata = DB.SafeDecodeJson(row.metadata, {})
    lib.print.info(('[rc_multicharacter:qbcore] %s (Citizen ID: %s | ID: %s) loaded!'):format(GetPlayerName(source) or 'Player', charId, source))
    return {
        success = true,
        citizenid = charId,
        position = convertPosition(row.position),
        charinfo = DB.SafeDecodeJson(row.charinfo, {}),
        inside = metadata.inside,
    }
end

local function giveStarterItems(source, QBCore)
    if not Config.Server.giveStarterItems then return end
    local Player = QBCore.Functions and QBCore.Functions.GetPlayer and QBCore.Functions.GetPlayer(source)
    if not Player then return end

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
        local info = {}
        if item.name == 'id_card' and Player.PlayerData and Player.PlayerData.charinfo then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif item.name == 'driver_license' and Player.PlayerData and Player.PlayerData.charinfo then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = 'Class C Driver License'
        elseif type(item.metadata) == 'table' then
            info = item.metadata
        end

        if useOxInv then
            pcall(function()
                exports.ox_inventory:AddItem(source, item.name, item.amount or 1, next(info) and info or nil)
            end)
        elseif GetResourceState('qb-inventory') == 'started' then
            pcall(function()
                exports['qb-inventory']:AddItem(source, item.name, item.amount or 1, false, info, 'rc_multicharacter:giveStarterItems')
            end)
        elseif Player.Functions and Player.Functions.AddItem then
            pcall(Player.Functions.AddItem, item.name, item.amount or 1, false, info)
        end
    end
end

function QBCoreAdapter.CreateCharacter(source, charinfo)
    local QBCore = getCore()
    if not QBCore or not QBCore.Player then
        return { success = false, error = 'core_unavailable' }
    end

    local existing, maxSlots = QBCoreAdapter.GetCharacters(source)
    if #existing >= maxSlots then
        return { success = false, error = 'max_slots_reached' }
    end

    local lastChar = existing[#existing]
    local nextCid = (lastChar and tonumber(lastChar.cid) or #existing) + 1

    local sanitized = {
        firstname = charinfo.firstname,
        lastname = charinfo.lastname,
        nationality = charinfo.nationality,
        birthdate = charinfo.birthdate,
        gender = charinfo.gender,
        backstory = charinfo.backstory or 'placeholder backstory',
        cid = nextCid,
    }

    local newData = {
        cid = nextCid,
        charinfo = sanitized,
    }

    local okLogin, success = pcall(QBCore.Player.Login, source, false, newData)
    if not okLogin or not success then
        return { success = false, error = 'create_failed' }
    end

    local deadline = GetGameTimer() + 5000
    while not QBCore.Players[source] and GetGameTimer() < deadline do
        Wait(50)
    end

    if QBCore.Commands and QBCore.Commands.Refresh then
        pcall(QBCore.Commands.Refresh, source)
    end

    giveStarterItems(source, QBCore)

    local player = QBCore.Players[source]
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid or nil

    lib.print.info(('[rc_multicharacter:qbcore] %s created a new character (%s)'):format(GetPlayerName(source) or 'Player', citizenid or 'unknown'))
    return {
        success = true,
        character = {
            citizenid = citizenid,
            cid = nextCid,
            charinfo = sanitized,
        },
    }
end

function QBCoreAdapter.DeleteCharacter(source, charId)
    if type(charId) ~= 'string' or charId == '' then
        return { success = false, error = 'invalid_character' }
    end

    local ids = QBCoreAdapter.GetIdentifiers(source)
    local okRow, row = pcall(MySQL.single.await, 'SELECT license FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not okRow or not row then
        return { success = false, error = 'character_not_found' }
    end

    if row.license ~= ids.license then
        return { success = false, error = 'exploit_ownership' }
    end

    local deleted = DB.SafeDeleteByTables(Config.Server.characterDataTables.qbcore, charId)
    return { success = deleted }
end

function QBCoreAdapter.ForceDeleteCharacter(charId)
    local QBCore = getCore()
    if not QBCore or not QBCore.Player or not QBCore.Player.ForceDeleteCharacter then return false end
    local ok = pcall(QBCore.Player.ForceDeleteCharacter, charId)
    return ok
end

function QBCoreAdapter.Logout(source)
    local QBCore = getCore()
    if not QBCore or not QBCore.Player or not QBCore.Player.Logout then return false end
    local ok = pcall(QBCore.Player.Logout, source)
    if ok then
        TriggerClientEvent('rc_multicharacter:client:openMenu', source)
    end
    return ok
end

function QBCoreAdapter.IsPlayerLoaded(source)
    local QBCore = getCore()
    return QBCore ~= nil and QBCore.Players ~= nil and QBCore.Players[source] ~= nil
end

function QBCoreAdapter.CheckStartupDiagnostics()
    -- qb-multicharacter is overridden via fxmanifest provide, warn if someone still has an explicit duplicate folder started under another name
end

Bridge.ServerAdapters.qbcore = QBCoreAdapter
