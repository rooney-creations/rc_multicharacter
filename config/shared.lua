Config = Config or {}

Config.Shared = {
    -- 'auto' (recommended) | 'qbox' | 'qbcore' | 'esx'
    framework = 'auto',

    -- Server display name for logs and messages
    serverName = 'Server',

    -- Default fallback spawn location (used for new characters or missing saved position)
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),

    -- ox_lib notification position: 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left'
    notifyPosition = 'top-right',

    -- Character prefix used for ESX multi-slot identifiers (e.g. char1:licensehash)
    esxPrefix = 'char',

    -- Enables /relog command for players to switch characters cleanly (cooldown protected)
    enableRelogCommand = true,
    relogCooldownSeconds = 15,

    -- Enables /logout (admin) and /deletechar, /setslots, /remslots commands
    enableAdminCommands = true,

    -- Character height bounds (shared between registration dialog and server validation)
    defaultHeight = 175,
    minHeight = 120,
    maxHeight = 220,

    -- Whether players can delete their own characters (enforced on both client UI and server)
    enableDeleteButton = true,

    -- Starter items given when creating a brand-new character
    -- metadata can be a table or a function(source, frameworkType) -> table?
    starterItems = {
        { name = 'phone', amount = 1 },
        {
            name = 'id_card',
            amount = 1,
            metadata = function(source, fw)
                if fw == 'qbox' and GetResourceState('qbx_idcard') == 'started' then
                    local ok, meta = pcall(function()
                        return exports.qbx_idcard:GetMetaLicense(source, { 'id_card' })
                    end)
                    if ok and meta then return meta end
                end
                return nil
            end,
        },
        {
            name = 'driver_license',
            amount = 1,
            metadata = function(source, fw)
                if fw == 'qbox' and GetResourceState('qbx_idcard') == 'started' then
                    local ok, meta = pcall(function()
                        return exports.qbx_idcard:GetMetaLicense(source, { 'driver_license' })
                    end)
                    if ok and meta then return meta end
                end
                return nil
            end,
        },
    },
}
