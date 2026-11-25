DB = DB or {}

local ready = false
local connected = false
local schemaCache = {
    tables = {},
    columns = {},
}

local function isSafeSqlIdentifier(name)
    return type(name) == 'string' and name:match('^[%w_]+$') ~= nil
end

function DB.IsAvailable()
    return GetResourceState('oxmysql') == 'started' and MySQL ~= nil
end

function DB.IsReady()
    return ready and connected and DB.IsAvailable()
end

function DB.AwaitReady(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 15000)
    while not DB.IsReady() do
        if GetGameTimer() >= deadline then
            return false
        end
        Wait(100)
    end
    return true
end

function DB.SafeDecodeJson(raw, fallback)
    if type(raw) == 'table' then
        return raw
    end
    if type(raw) ~= 'string' or raw == '' then
        return fallback
    end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        return decoded
    end
    return fallback
end

function DB.TableExists(tableName, bypassCache)
    if not isSafeSqlIdentifier(tableName) or not DB.IsAvailable() then
        return false
    end
    if not bypassCache and schemaCache.tables[tableName] ~= nil then
        return schemaCache.tables[tableName]
    end
    local ok, count = pcall(
        MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { tableName }
    )
    local exists = ok and tonumber(count) and tonumber(count) > 0 or false
    schemaCache.tables[tableName] = exists
    return exists
end

function DB.ColumnExists(tableName, columnName, bypassCache)
    if not isSafeSqlIdentifier(tableName) or not isSafeSqlIdentifier(columnName) or not DB.IsAvailable() then
        return false
    end
    local cacheKey = tableName .. '.' .. columnName
    if not bypassCache and schemaCache.columns[cacheKey] ~= nil then
        return schemaCache.columns[cacheKey]
    end
    local ok, count = pcall(
        MySQL.scalar.await,
        'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tableName, columnName }
    )
    local exists = ok and tonumber(count) and tonumber(count) > 0 or false
    schemaCache.columns[cacheKey] = exists
    return exists
end

local function ensureColumn(tableName, columnName, definition)
    if not DB.TableExists(tableName, true) then
        return false
    end
    if DB.ColumnExists(tableName, columnName, true) then
        return true
    end
    if not isSafeSqlIdentifier(tableName) or not isSafeSqlIdentifier(columnName) then
        return false
    end
    local ok, err = pcall(
        MySQL.query.await,
        ('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition)
    )
    if not ok then
        lib.print.warn(('[rc_multicharacter] Could not add column %s.%s: %s'):format(tableName, columnName, tostring(err)))
        return false
    end
    schemaCache.columns[tableName .. '.' .. columnName] = true
    return true
end

local function ensureSlotsTable()
    local ok, err = pcall(MySQL.query.await, [[
        CREATE TABLE IF NOT EXISTS `rc_multicharacter_slots` (
            `identifier` VARCHAR(100) NOT NULL,
            `slots` INT(11) NOT NULL DEFAULT 3,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    if not ok then
        lib.print.error(('[rc_multicharacter] Failed ensuring rc_multicharacter_slots: %s'):format(tostring(err)))
        return false
    end
    schemaCache.tables['rc_multicharacter_slots'] = true
    return true
end

function DB.EnsureFrameworkSchema(fw)
    if not DB.IsAvailable() then
        return false
    end

    ensureSlotsTable()

    if Config.Server.autoMigrateSchema == false then
        return true
    end

    if fw == 'qbox' then
        if not DB.TableExists('players', true) then
            lib.print.warn('[rc_multicharacter] Table `players` not found. Please import sql/qbox.sql!')
        else
            ensureColumn('players', 'userId', 'INT UNSIGNED DEFAULT NULL AFTER `id`')
            ensureColumn('players', 'last_logged_out', 'TIMESTAMP NULL DEFAULT NULL AFTER `last_updated`')
        end
        if not DB.TableExists('playerskins', true) then
            pcall(MySQL.query.await, [[
                CREATE TABLE IF NOT EXISTS `playerskins` (
                    `id` INT(11) NOT NULL AUTO_INCREMENT,
                    `citizenid` VARCHAR(255) NOT NULL,
                    `model` VARCHAR(255) NOT NULL,
                    `skin` TEXT NOT NULL,
                    `active` TINYINT(4) NOT NULL DEFAULT 1,
                    PRIMARY KEY (`id`),
                    KEY `citizenid` (`citizenid`),
                    KEY `active` (`active`)
                ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]])
            schemaCache.tables['playerskins'] = true
        end
    elseif fw == 'qbcore' then
        if not DB.TableExists('players', true) then
            lib.print.warn('[rc_multicharacter] Table `players` not found. Please import sql/qbcore.sql!')
        end
        if not DB.TableExists('playerskins', true) then
            pcall(MySQL.query.await, [[
                CREATE TABLE IF NOT EXISTS `playerskins` (
                    `id` INT(11) NOT NULL AUTO_INCREMENT,
                    `citizenid` VARCHAR(255) NOT NULL,
                    `model` VARCHAR(255) NOT NULL,
                    `skin` TEXT NOT NULL,
                    `active` TINYINT(4) NOT NULL DEFAULT 1,
                    PRIMARY KEY (`id`),
                    KEY `citizenid` (`citizenid`),
                    KEY `active` (`active`)
                ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]])
            schemaCache.tables['playerskins'] = true
        end
    elseif fw == 'esx' then
        if not DB.TableExists('users', true) then
            lib.print.warn('[rc_multicharacter] Table `users` not found. Please import sql/esx.sql!')
        else
            ensureColumn('users', 'firstname', 'VARCHAR(50) NULL DEFAULT NULL')
            ensureColumn('users', 'lastname', 'VARCHAR(50) NULL DEFAULT NULL')
            ensureColumn('users', 'dateofbirth', 'VARCHAR(20) NULL DEFAULT NULL')
            ensureColumn('users', 'sex', 'VARCHAR(10) NULL DEFAULT NULL')
            ensureColumn('users', 'height', 'INT NULL DEFAULT 175')
            ensureColumn('users', 'nationality', 'VARCHAR(60) NULL DEFAULT NULL')
            ensureColumn('users', 'skin', 'LONGTEXT NULL DEFAULT NULL')
            ensureColumn('users', 'disabled', 'TINYINT(1) NULL DEFAULT 0')

            local okLen, idCol = pcall(MySQL.single.await, [[
                SELECT CHARACTER_MAXIMUM_LENGTH AS maxLen
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'identifier'
                LIMIT 1
            ]])
            if okLen and idCol and tonumber(idCol.maxLen) and tonumber(idCol.maxLen) < 60 then
                local okWiden, widenErr = pcall(MySQL.query.await, 'ALTER TABLE `users` MODIFY COLUMN `identifier` VARCHAR(60) NOT NULL')
                if not okWiden then
                    lib.print.warn(('[rc_multicharacter] Could not widen users.identifier: %s'):format(tostring(widenErr)))
                end
            end
        end
    end

    return true
end

function DB.BuildLicenseWhere(license2, license)
    local clauses = {}
    local params = {}
    if type(license2) == 'string' and license2 ~= '' then
        clauses[#clauses + 1] = 'license = ?'
        params[#params + 1] = license2
    end
    if type(license) == 'string' and license ~= '' and license ~= license2 then
        clauses[#clauses + 1] = 'license = ?'
        params[#params + 1] = license
    end
    if #clauses == 0 then
        return nil, nil
    end
    return table.concat(clauses, ' OR '), params
end

function DB.NormalizeCids(license2, license)
    local whereClause, params = DB.BuildLicenseWhere(license2, license)
    if not whereClause then return end

    local ok, rows = pcall(
        MySQL.query.await,
        ('SELECT id, citizenid, cid, charinfo FROM players WHERE %s ORDER BY id ASC'):format(whereClause),
        params
    )
    if not ok or type(rows) ~= 'table' or #rows == 0 then
        return
    end

    local updates = {}
    for i = 1, #rows do
        if tonumber(rows[i].cid) ~= i then
            local charinfo = DB.SafeDecodeJson(rows[i].charinfo, {})
            charinfo.cid = i
            updates[#updates + 1] = {
                query = 'UPDATE players SET cid = ?, charinfo = ? WHERE citizenid = ?',
                values = { i, json.encode(charinfo), rows[i].citizenid }
            }
        end
    end

    if #updates > 0 then
        local txOk, txErr = pcall(MySQL.transaction.await, updates)
        if not txOk then
            lib.print.warn(('[rc_multicharacter] normalizeCids transaction failed: %s'):format(tostring(txErr)))
        end
    end
end

function DB.GetSlotOverride(identifiers)
    if type(identifiers) ~= 'table' then return nil end

    local cleanIds = {}
    for i = 1, #identifiers do
        local id = identifiers[i]
        if type(id) == 'string' and id ~= '' then
            cleanIds[#cleanIds + 1] = id
        end
    end
    if #cleanIds == 0 then return nil end

    local placeholders = {}
    for i = 1, #cleanIds do
        placeholders[i] = '?'
    end
    local inClause = table.concat(placeholders, ', ')

    if DB.TableExists('rc_multicharacter_slots') then
        local ok, row = pcall(
            MySQL.single.await,
            ('SELECT slots FROM rc_multicharacter_slots WHERE identifier IN (%s) LIMIT 1'):format(inClause),
            cleanIds
        )
        if ok and row and tonumber(row.slots) then
            return math.max(1, math.min(50, math.floor(tonumber(row.slots))))
        end
    end

    if DB.TableExists('multicharacter_slots') then
        local ok, row = pcall(
            MySQL.single.await,
            ('SELECT slots FROM multicharacter_slots WHERE identifier IN (%s) LIMIT 1'):format(inClause),
            cleanIds
        )
        if ok and row and tonumber(row.slots) then
            return math.max(1, math.min(50, math.floor(tonumber(row.slots))))
        end
    end

    return nil
end

function DB.SetSlotOverride(identifier, slots)
    if type(identifier) ~= 'string' or identifier == '' then return false end
    local count = tonumber(slots)
    if not count then return false end
    count = math.max(1, math.min(50, math.floor(count)))
    ensureSlotsTable()
    local ok, err = pcall(
        MySQL.insert.await,
        'INSERT INTO `rc_multicharacter_slots` (`identifier`, `slots`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `slots` = VALUES(`slots`)',
        { identifier, count }
    )
    if not ok then
        lib.print.error(('[rc_multicharacter] SetSlotOverride failed: %s'):format(tostring(err)))
        return false
    end
    return true
end

function DB.RemoveSlotOverride(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return false end
    if not DB.TableExists('rc_multicharacter_slots') then return false end
    local ok, affected = pcall(
        MySQL.update.await,
        'DELETE FROM `rc_multicharacter_slots` WHERE `identifier` = ?',
        { identifier }
    )
    return ok and (tonumber(affected) or 0) > 0
end

function DB.DiscoverEsxCharacterTables()
    local tables = {}
    local seen = {}

    if type(Config.Server.characterDataTables.esx) == 'table' then
        for i = 1, #Config.Server.characterDataTables.esx do
            local pair = Config.Server.characterDataTables.esx[i]
            local tbl, col = pair[1], pair[2]
            if isSafeSqlIdentifier(tbl) and isSafeSqlIdentifier(col) and DB.ColumnExists(tbl, col, true) then
                local key = tbl .. '.' .. col
                if not seen[key] and tbl ~= 'users' then
                    seen[key] = true
                    tables[#tables + 1] = { tbl, col }
                end
            end
        end
    end

    local ok, cols = pcall(MySQL.query.await, [[
        SELECT c.TABLE_NAME AS tableName, c.COLUMN_NAME AS columnName
        FROM information_schema.COLUMNS c
        INNER JOIN information_schema.TABLES t
            ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
        WHERE c.TABLE_SCHEMA = DATABASE()
          AND t.TABLE_TYPE = 'BASE TABLE'
          AND c.DATA_TYPE = 'varchar'
          AND c.COLUMN_NAME IN ('identifier', 'owner')
          AND c.TABLE_NAME NOT IN ('users', 'rc_multicharacter_slots', 'multicharacter_slots')
        ORDER BY c.TABLE_NAME ASC, c.COLUMN_NAME ASC
    ]])

    if ok and type(cols) == 'table' then
        for i = 1, #cols do
            local tbl = cols[i].tableName
            local col = cols[i].columnName
            if isSafeSqlIdentifier(tbl) and isSafeSqlIdentifier(col) then
                local key = tbl .. '.' .. col
                if not seen[key] then
                    seen[key] = true
                    tables[#tables + 1] = { tbl, col }
                end
            end
        end
    end

    if DB.ColumnExists('users', 'identifier', true) then
        tables[#tables + 1] = { 'users', 'identifier' }
    end

    return tables
end

function DB.SafeDeleteByTables(tableList, targetValue)
    if type(tableList) ~= 'table' or type(targetValue) ~= 'string' or targetValue == '' then
        return false
    end

    local queries = {}
    for i = 1, #tableList do
        local entry = tableList[i]
        local tableName = entry[1]
        local columnName = entry[2]
        if isSafeSqlIdentifier(tableName) and isSafeSqlIdentifier(columnName) and DB.ColumnExists(tableName, columnName) then
            queries[#queries + 1] = {
                query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(tableName, columnName),
                values = { targetValue }
            }
        end
    end

    if #queries == 0 then
        return false
    end

    local ok, result = pcall(MySQL.transaction.await, queries)
    if not ok then
        lib.print.error(('[rc_multicharacter] Character deletion SQL error: %s'):format(tostring(result)))
        return false
    end

    return not not result
end

CreateThread(function()
    if not DB.IsAvailable() then
        lib.print.error('[rc_multicharacter] oxmysql is not started!')
        return
    end

    MySQL.ready(function()
        connected = true
        local fw = Bridge.Framework.WaitForDetection(10000)
        if not fw then
            lib.print.error('[rc_multicharacter] No supported framework detected (qbx_core, qb-core, es_extended).')
            ready = true
            return
        end

        DB.EnsureFrameworkSchema(fw)
        ready = true
        lib.print.info(('[rc_multicharacter] Database schema verified for framework: %s'):format(fw))
    end)
end)
