Bridge = Bridge or {}
Bridge.ServerAdapters = Bridge.ServerAdapters or {}

local QBox = {}

local function convertPosition(rawPos)
    local pos = DB.SafeDecodeJson(rawPos, nil)
    local defaultSpawn = (Config and Config.Shared and Config.Shared.defaultSpawn) or vec4(-540.58, -212.02, 37.65, 208.88)
    if not pos or not pos.x or not pos.y or not pos.z then
        return vec4(defaultSpawn.x, defaultSpawn.y, defaultSpawn.z, defaultSpawn.w)
    end
    return vec4(tonumber(pos.x) or defaultSpawn.x, tonumber(pos.y) or defaultSpawn.y, tonumber(pos.z) or defaultSpawn.z, tonumber(pos.w) or defaultSpawn.w)
end

function QBox.GetIdentifiers(source)
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local license = GetPlayerIdentifierByType(source, 'license')
    return {
        license2 = license2,
        license = license,
        primary = license2 or license,
        list = { license2, license },
    }
end

function QBox.GetAllowedSlots(source)
    local ids = QBox.GetIdentifiers(source)
    local dbSlots = DB.GetSlotOverride(ids.list)
    if dbSlots then return dbSlots end

    local srv = Config and Config.Server or {}
    local defaultSlots = srv.defaultNumberOfCharacters or 3
    local overrides = srv.playersNumberOfCharacters or {}
    if ids.license2 and overrides[ids.license2] then
        return tonumber(overrides[ids.license2]) or defaultSlots
    end
    if ids.license and overrides[ids.license] then
        return tonumber(overrides[ids.license]) or defaultSlots
    end
    return defaultSlots
end

function QBox.GetCharacters(source)
    local ids = QBox.GetIdentifiers(source)
    local whereClause, params = DB.BuildLicenseWhere(ids.license2, ids.license)
    if not whereClause then return {}, QBox.GetAllowedSlots(source) end

    DB.NormalizeCids(ids.license2, ids.license)

    local hasLastLoggedOut = DB.ColumnExists('players', 'last_logged_out')
    local selectCols = hasLastLoggedOut
        and 'citizenid, cid, charinfo, money, job, gang, position, metadata, UNIX_TIMESTAMP(last_logged_out) AS lastLoggedOutUnix'
        or 'citizenid, cid, charinfo, money, job, gang, position, metadata, UNIX_TIMESTAMP(last_updated) AS lastLoggedOutUnix'

    local ok, rows = pcall(
        MySQL.query.await,
        ('SELECT %s FROM players WHERE %s ORDER BY cid ASC'):format(selectCols, whereClause),
        params
    )

    if not ok or type(rows) ~= 'table' then
        lib.print.error(('[rc_multicharacter:qbox] Failed fetching characters: %s'):format(tostring(rows)))
        return {}, QBox.GetAllowedSlots(source)
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
            cid = tonumber(row.cid) or tonumber(charinfo.cid) or i,
            charinfo = charinfo,
            money = {
                bank = tonumber(money.bank) or 0,
                cash = tonumber(money.cash) or 0,
            },
            job = job,
            gang = gang,
            position = convertPosition(row.position),
            metadata = metadata,
            lastLoggedOut = row.lastLoggedOutUnix,
        }
    end

    return chars, QBox.GetAllowedSlots(source)
end

function QBox.GetPreviewSkin(source, charId)
    if type(charId) ~= 'string' or charId == '' then return nil end

    -- Ownership check before leaking another player's skin
    local ids = QBox.GetIdentifiers(source)
    local ownerOk, ownerRow = pcall(MySQL.single.await, 'SELECT license FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not ownerOk or not ownerRow then return nil end
    if ownerRow.license ~= ids.license2 and ownerRow.license ~= ids.license then
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

function QBox.LoadCharacter(source, charId)
    if type(charId) ~= 'string' or charId == '' then
        return { success = false, error = 'invalid_character' }
    end

    local ids = QBox.GetIdentifiers(source)
    local okRow, row = pcall(MySQL.single.await, 'SELECT license, position FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not okRow or not row then
        return { success = false, error = 'character_not_found' }
    end

    if row.license ~= ids.license2 and row.license ~= ids.license then
        return { success = false, error = 'exploit_ownership' }
    end

    local okLogin, success = pcall(function()
        return exports.qbx_core:Login(source, charId)
    end)

    if not okLogin or not success then
        return { success = false, error = 'login_failed' }
    end

    lib.print.info(('[rc_multicharacter:qbox] %s (Citizen ID: %s | ID: %s) loaded!'):format(GetPlayerName(source) or 'Player', charId, source))
    return {
        success = true,
        citizenid = charId,
        position = convertPosition(row.position),
    }
end

local function giveStarterItems(source)
    if not (Config and Config.Server and Config.Server.giveStarterItems) then return end
    if GetResourceState('ox_inventory') ~= 'started' then return end

    local deadline = GetGameTimer() + 5000
    while not exports.ox_inventory:GetInventory(source) do
        if GetGameTimer() >= deadline then
            lib.print.warn(('[rc_multicharacter:qbox] Timed out waiting for ox_inventory on source %s'):format(source))
            return
        end
        Wait(100)
    end

    local items = (Config and Config.Shared and Config.Shared.starterItems) or {}
    for i = 1, #items do
        local item = items[i]
        local meta = nil
        if type(item.metadata) == 'function' then
            local okMeta, res = pcall(item.metadata, source, 'qbox')
            if okMeta then meta = res end
        elseif type(item.metadata) == 'table' then
            meta = item.metadata
        end
        pcall(function()
            exports.ox_inventory:AddItem(source, item.name, item.amount or 1, meta)
        end)
    end
end

function QBox.CreateCharacter(source, charinfo)
    local existing, maxSlots = QBox.GetCharacters(source)
    if #existing >= maxSlots then
        return { success = false, error = 'max_slots_reached' }
    end

    local usedSlots = {}
    for i = 1, #existing do
        usedSlots[tonumber(existing[i].cid) or i] = true
    end

    local nextCid = nil
    local requestedCid = tonumber(charinfo.cid)
    if requestedCid and requestedCid >= 1 and requestedCid <= maxSlots and not usedSlots[requestedCid] then
        nextCid = math.floor(requestedCid)
    else
        for s = 1, maxSlots do
            if not usedSlots[s] then
                nextCid = s
                break
            end
        end
    end
    if not nextCid then
        return { success = false, error = 'max_slots_reached' }
    end

    local sanitized = {
        firstname = charinfo.firstname,
        lastname = charinfo.lastname,
        nationality = charinfo.nationality,
        birthdate = charinfo.birthdate,
        gender = charinfo.gender,
        backstory = charinfo.backstory or 'placeholder backstory',
        cid = nextCid,
    }

    local newData = { charinfo = sanitized }
    local okLogin, success = pcall(function()
        return exports.qbx_core:Login(source, nil, newData)
    end)

    if not okLogin or not success then
        return { success = false, error = 'create_failed' }
    end

    giveStarterItems(source)

    local player = exports.qbx_core:GetPlayer(source)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid or nil

    lib.print.info(('[rc_multicharacter:qbox] %s created a new character (%s)'):format(GetPlayerName(source) or 'Player', citizenid or 'unknown'))
    return {
        success = true,
        character = {
            citizenid = citizenid,
            cid = nextCid,
            charinfo = sanitized,
        },
    }
end

function QBox.DeleteCharacter(source, charId)
    if type(charId) ~= 'string' or charId == '' then
        return { success = false, error = 'invalid_character' }
    end

    local ids = QBox.GetIdentifiers(source)
    local okRow, row = pcall(MySQL.single.await, 'SELECT license FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not okRow or not row then
        return { success = false, error = 'character_not_found' }
    end

    if row.license ~= ids.license2 and row.license ~= ids.license then
        return { success = false, error = 'exploit_ownership' }
    end

    local qboxTables = (Config and Config.Server and Config.Server.characterDataTables and Config.Server.characterDataTables.qbox) or { { 'players', 'citizenid' } }
    local deleted = DB.SafeDeleteByTables(qboxTables, charId)
    if deleted then
        TriggerEvent('qbx_core:server:characterDeleted', charId)
    end

    return { success = deleted }
end

function QBox.ForceDeleteCharacter(charId)
    if type(charId) ~= 'string' or charId == '' then return false end
    local okRow, row = pcall(MySQL.single.await, 'SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { charId })
    if not okRow or not row then
        return false
    end

    local okP, player = pcall(function()
        return exports.qbx_core:GetPlayerByCitizenId(charId)
    end)
    if okP and player and player.PlayerData and player.PlayerData.source then
        DropPlayer(tostring(player.PlayerData.source), 'An admin deleted the character which you are currently using')
    end

    local qboxTables = (Config and Config.Server and Config.Server.characterDataTables and Config.Server.characterDataTables.qbox) or { { 'players', 'citizenid' } }
    local deleted = DB.SafeDeleteByTables(qboxTables, charId)
    if deleted then
        TriggerEvent('qbx_core:server:characterDeleted', charId)
    end
    return deleted
end

function QBox.Logout(source)
    local ok = pcall(function()
        exports.qbx_core:Logout(source)
    end)
    return ok
end

function QBox.IsPlayerLoaded(source)
    local ok, player = pcall(function()
        return exports.qbx_core:GetPlayer(source)
    end)
    return ok and player ~= nil
end

function QBox.CheckStartupDiagnostics()
    local clientCfg = LoadResourceFile('qbx_core', 'config/client.lua')
    if clientCfg and clientCfg:match('useExternalCharacters%s*=%s*false') then
        lib.print.warn('[rc_multicharacter] qbx_core/config/client.lua still has `useExternalCharacters = false`! Set it to `true` to prevent Qbox built-in character menu collision.')
    end
end

Bridge.ServerAdapters.qbox = QBox
