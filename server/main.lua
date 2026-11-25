local inFlight = {}
local relogCooldowns = {}

local function trimString(str)
    if type(str) ~= 'string' then return nil end
    return str:gsub('^%s+', ''):gsub('%s+$', '')
end

local function hasProfanity(str)
    local words = Config.Server.profanityWords or {}
    local lower = str:lower()
    if words[lower] then return true end

    local parts = { string.strsplit(' ', lower) }
    if #parts > 5 then return true end
    for i = 1, #parts do
        if words[parts[i]] then return true end
    end
    return false
end

local function sanitizeNewCharInfo(data)
    if type(data) ~= 'table' then return nil end

    local MAX_TEXT = 50
    local MAX_BACKSTORY = 1000

    local function cleanText(value, maxLen)
        local trimmed = trimString(value)
        if not trimmed or trimmed == '' or #trimmed > maxLen then
            return nil
        end
        return trimmed
    end

    local firstname = cleanText(data.firstname, MAX_TEXT)
    local lastname = cleanText(data.lastname, MAX_TEXT)
    local nationality = cleanText(data.nationality, MAX_TEXT)
    local birthdate = cleanText(data.birthdate, MAX_TEXT)
    local gender = tonumber(data.gender)

    if not firstname or not lastname or not nationality or not birthdate or not gender then
        return nil
    end

    if hasProfanity(firstname) or hasProfanity(lastname) or hasProfanity(nationality) then
        return nil
    end

    gender = math.floor(gender)
    if gender ~= 0 and gender ~= 1 then
        return nil
    end

    local height = tonumber(data.height)
    if height then
        height = math.floor(math.max(Config.Client.minHeight or 120, math.min(Config.Client.maxHeight or 220, height)))
    else
        height = Config.Client.defaultHeight or 175
    end

    local backstory = cleanText(data.backstory, MAX_BACKSTORY) or 'placeholder backstory'
    local cid = tonumber(data.cid)

    return {
        firstname = firstname,
        lastname = lastname,
        nationality = nationality,
        birthdate = birthdate,
        gender = gender,
        height = height,
        backstory = backstory,
        cid = cid and math.floor(cid) or nil,
    }
end

local function sendWebhook(eventTitle, message, color)
    local webhook = Config.Server.logging and Config.Server.logging.webhook
    if type(webhook) ~= 'string' or webhook == '' then return end

    local colorMap = {
        green = 5763719,
        red = 15548997,
        white = 16777215,
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode({
        username = 'rc_multicharacter',
        embeds = {
            {
                title = eventTitle,
                description = message,
                color = colorMap[color] or 3447003,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

local function getActiveAdapter()
    local fw = Bridge.Framework.GetType() or Bridge.Framework.WaitForDetection(10000)
    if not fw then return nil, nil end
    return Bridge.ServerAdapters[fw], fw
end

lib.callback.register('rc_multicharacter:server:getCharacters', function(source)
    if not DB.AwaitReady(15000) then
        return {}, Config.Server.defaultNumberOfCharacters or 3, false
    end

    local adapter = getActiveAdapter()
    if not adapter then
        return {}, Config.Server.defaultNumberOfCharacters or 3, false
    end

    local chars, maxSlots = adapter.GetCharacters(source)
    return chars or {}, maxSlots or (Config.Server.defaultNumberOfCharacters or 3), true
end)

lib.callback.register('rc_multicharacter:server:getPreviewPedData', function(source, charId)
    if not DB.IsReady() then return nil end
    local adapter = getActiveAdapter()
    if not adapter then return nil end

    return adapter.GetPreviewSkin(source, charId)
end)

lib.callback.register('rc_multicharacter:server:loadCharacter', function(source, charId)
    if inFlight[source] then
        return { success = false, error = 'busy' }
    end
    if not DB.AwaitReady(10000) then
        return { success = false, error = 'database_not_ready' }
    end

    local adapter, fw = getActiveAdapter()
    if not adapter then
        return { success = false, error = 'framework_unavailable' }
    end

    if adapter.IsPlayerLoaded(source) then
        return { success = false, error = 'already_loaded' }
    end

    inFlight[source] = true
    local ok, result = pcall(adapter.LoadCharacter, source, charId)
    inFlight[source] = nil

    if not ok then
        lib.print.error(('[rc_multicharacter] LoadCharacter error (%s): %s'):format(fw or 'unknown', tostring(result)))
        return { success = false, error = 'internal_error' }
    end

    if result and result.error == 'exploit_ownership' then
        sendWebhook('Anti-Cheat', ('**%s** (ID: %s) attempted unauthorized character load: `%s`'):format(GetPlayerName(source) or 'Unknown', source, tostring(charId)), 'white')
        DropPlayer(tostring(source), locale('error.exploit_dropped'))
        return result
    end

    if result and result.success then
        sendWebhook('Character Loaded', ('**%s** (ID: %s | Framework: %s) loaded `%s`'):format(GetPlayerName(source) or 'Unknown', source, fw, tostring(charId)), 'green')
    end

    return result
end)

lib.callback.register('rc_multicharacter:server:createCharacter', function(source, data)
    if inFlight[source] then
        return { success = false, error = 'busy' }
    end
    if not DB.AwaitReady(10000) then
        return { success = false, error = 'database_not_ready' }
    end

    local adapter, fw = getActiveAdapter()
    if not adapter then
        return { success = false, error = 'framework_unavailable' }
    end

    if adapter.IsPlayerLoaded(source) then
        return { success = false, error = 'already_loaded' }
    end

    local sanitized = sanitizeNewCharInfo(data)
    if not sanitized then
        return { success = false, error = 'invalid_data' }
    end

    inFlight[source] = true
    local ok, result = pcall(adapter.CreateCharacter, source, sanitized)
    inFlight[source] = nil

    if not ok then
        lib.print.error(('[rc_multicharacter] CreateCharacter error (%s): %s'):format(fw or 'unknown', tostring(result)))
        return { success = false, error = 'internal_error' }
    end

    if result and result.success then
        sendWebhook('Character Created', ('**%s** (ID: %s | Framework: %s) created `%s %s`'):format(GetPlayerName(source) or 'Unknown', source, fw, sanitized.firstname, sanitized.lastname), 'green')
    end

    return result
end)

lib.callback.register('rc_multicharacter:server:deleteCharacter', function(source, charId)
    if not Config.Shared.enableDeleteButton then
        return { success = false, error = 'delete_disabled' }
    end
    if inFlight[source] then
        return { success = false, error = 'busy' }
    end
    if not DB.AwaitReady(10000) then
        return { success = false, error = 'database_not_ready' }
    end

    local adapter, fw = getActiveAdapter()
    if not adapter then
        return { success = false, error = 'framework_unavailable' }
    end

    inFlight[source] = true
    local ok, result = pcall(adapter.DeleteCharacter, source, charId)
    inFlight[source] = nil

    if not ok then
        lib.print.error(('[rc_multicharacter] DeleteCharacter error (%s): %s'):format(fw or 'unknown', tostring(result)))
        return { success = false, error = 'internal_error' }
    end

    if result and result.error == 'exploit_ownership' then
        sendWebhook('Anti-Cheat', ('**%s** (ID: %s) attempted unauthorized character delete: `%s`'):format(GetPlayerName(source) or 'Unknown', source, tostring(charId)), 'white')
        DropPlayer(tostring(source), locale('error.exploit_dropped'))
        return result
    end

    if result and result.success then
        sendWebhook('Character Deleted', ('**%s** (ID: %s | Framework: %s) deleted `%s`'):format(GetPlayerName(source) or 'Unknown', source, fw, tostring(charId)), 'red')
    end

    return result
end)

lib.callback.register('rc_multicharacter:server:relog', function(source)
    if not Config.Shared.enableRelogCommand then
        return { success = false, error = 'disabled' }
    end

    local now = os.time()
    local cooldown = tonumber(Config.Shared.relogCooldownSeconds) or 15
    if relogCooldowns[source] and (now - relogCooldowns[source]) < cooldown then
        return { success = false, error = 'relog_cooldown' }
    end

    local adapter = getActiveAdapter()
    if not adapter or not adapter.IsPlayerLoaded(source) then
        return { success = false, error = 'relog_unavailable' }
    end

    relogCooldowns[source] = now
    local ok = adapter.Logout(source)
    return { success = ok }
end)

AddEventHandler('playerDropped', function()
    local src = source
    inFlight[src] = nil
    relogCooldowns[src] = nil
    local adapter = Bridge.Framework.GetAdapter()
    if adapter and adapter.OnPlayerDropped then
        adapter.OnPlayerDropped(src)
    end
end)

-- Unified Admin & Player Commands
if Config.Shared.enableAdminCommands then
    lib.addCommand('logout', {
        help = locale('info.logout_command_help'),
        params = {
            { name = 'id', help = locale('info.deletechar_command_arg_player_id'), type = 'playerId', optional = true },
        },
        restricted = 'group.admin',
    }, function(source, args)
        if not Bridge.Framework.IsAdmin(source) then
            Bridge.Framework.Notify(source, locale('error.no_permission'), 'error')
            return
        end

        local target = args.id or source
        local adapter = getActiveAdapter()
        if not adapter or not adapter.IsPlayerLoaded(target) then
            Bridge.Framework.Notify(source, locale('error.not_online'), 'error')
            return
        end

        adapter.Logout(target)
    end)

    lib.addCommand('deletechar', {
        help = locale('info.deletechar_command_help'),
        params = {
            { name = 'target', help = locale('info.deletechar_command_arg_player_id'), type = 'string' },
        },
        restricted = 'group.admin',
    }, function(source, args)
        if not Bridge.Framework.IsAdmin(source) then
            Bridge.Framework.Notify(source, locale('error.no_permission'), 'error')
            return
        end

        local adapter, fw = getActiveAdapter()
        if not adapter then return end

        local targetId = args.target
        local numericId = tonumber(targetId)
        if numericId and fw ~= 'esx' then
            local core = Bridge.Framework.GetCore()
            local p = nil
            if fw == 'qbox' then
                p = exports.qbx_core:GetPlayer(numericId)
            elseif fw == 'qbcore' and core and core.Functions then
                p = core.Functions.GetPlayer(numericId)
            end
            if p and p.PlayerData and p.PlayerData.citizenid then
                targetId = p.PlayerData.citizenid
            end
        elseif numericId and fw == 'esx' then
            local core = Bridge.Framework.GetCore()
            local xP = core and core.GetPlayerFromId and core.GetPlayerFromId(numericId)
            if xP and xP.identifier then
                targetId = xP.identifier
            end
        end

        local ok = adapter.ForceDeleteCharacter(targetId)
        if source ~= 0 then
            Bridge.Framework.Notify(source, ok and locale('success.character_deleted_id', targetId) or locale('error.character_delete_failed'), ok and 'success' or 'error')
        else
            lib.print.info(('ForceDeleteCharacter(%s): %s'):format(tostring(targetId), tostring(ok)))
        end
    end)

    lib.addCommand('setslots', {
        help = locale('info.setslots_command_help'),
        params = {
            { name = 'identifier', help = locale('info.identifier_arg'), type = 'string' },
            { name = 'slots', help = locale('info.slots_arg'), type = 'number' },
        },
        restricted = 'group.admin',
    }, function(source, args)
        if not Bridge.Framework.IsAdmin(source) then
            Bridge.Framework.Notify(source, locale('error.no_permission'), 'error')
            return
        end

        local ok = DB.SetSlotOverride(args.identifier, args.slots)
        if source ~= 0 then
            Bridge.Framework.Notify(source, ok and locale('success.slots_set', args.identifier, args.slots) or locale('error.character_delete_failed'), ok and 'success' or 'error')
        else
            lib.print.info(('Set slots for %s to %s: %s'):format(args.identifier, tostring(args.slots), tostring(ok)))
        end
    end)

    lib.addCommand('remslots', {
        help = locale('info.remslots_command_help'),
        params = {
            { name = 'identifier', help = locale('info.identifier_arg'), type = 'string' },
        },
        restricted = 'group.admin',
    }, function(source, args)
        if not Bridge.Framework.IsAdmin(source) then
            Bridge.Framework.Notify(source, locale('error.no_permission'), 'error')
            return
        end

        local ok = DB.RemoveSlotOverride(args.identifier)
        if source ~= 0 then
            Bridge.Framework.Notify(source, ok and locale('success.slots_removed', args.identifier) or locale('error.not_online'), ok and 'success' or 'error')
        else
            lib.print.info(('Removed slots override for %s: %s'):format(args.identifier, tostring(ok)))
        end
    end)
end

-- Startup Checks & Diagnostics
CreateThread(function()
    if GetResourceState('ox_lib') ~= 'started' then
        lib.print.error('[rc_multicharacter] ox_lib is required and must be started before rc_multicharacter!')
        return
    end

    if lib.checkDependency and not lib.checkDependency('ox_lib', '3.14.0') then
        lib.print.warn('[rc_multicharacter] ox_lib 3.14.0+ is recommended for full UI & callback support.')
    end

    local fw = Bridge.Framework.WaitForDetection(12000)
    if not fw then
        lib.print.error('[rc_multicharacter] Could not detect QBox (qbx_core), QBCore (qb-core), or ESX (es_extended)!')
        return
    end

    lib.print.info(('[rc_multicharacter] Active framework detected: %s'):format(fw:upper()))
    local adapter = Bridge.ServerAdapters[fw]
    if adapter and adapter.CheckStartupDiagnostics then
        adapter.CheckStartupDiagnostics()
    end
end)
