Config = Config or {}

Config.Server = {
    -- Default maximum character slots per player across all frameworks
    defaultNumberOfCharacters = 3,

    -- Per-identifier character slot overrides (supports license2:, license:, or raw ESX identifier)
    -- Also overridable dynamically at runtime via /setslots and /remslots (stored in rc_multicharacter_slots)
    playersNumberOfCharacters = {
        ['license2:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = 5,
    },

    -- Automatically create missing columns/tables on MySQL.ready
    autoMigrateSchema = true,

    -- Give starter items defined in Config.Shared.starterItems on new character creation
    giveStarterItems = true,

    -- Optional Discord webhook URL for join/delete/anticheat audit logs
    logging = {
        webhook = nil,
    },

    -- Server-side profanity list (mirrored from client for server-authoritative validation)
    profanityWords = {
        ['bad word'] = true,
    },

    -- Tables cleaned when a character is deleted (existence is verified via information_schema before execution)
    characterDataTables = {
        qbox = {
            { 'properties', 'owner' },
            { 'bank_accounts_new', 'id' },
            { 'playerskins', 'citizenid' },
            { 'player_mails', 'citizenid' },
            { 'player_outfits', 'citizenid' },
            { 'player_vehicles', 'citizenid' },
            { 'player_groups', 'citizenid' },
            { 'npwd_calls', 'identifier' },
            { 'npwd_darkchat_channel_members', 'user_identifier' },
            { 'npwd_marketplace_listings', 'identifier' },
            { 'npwd_messages_participants', 'participant' },
            { 'npwd_notes', 'identifier' },
            { 'npwd_phone_contacts', 'identifier' },
            { 'npwd_phone_gallery', 'identifier' },
            { 'npwd_twitter_profiles', 'identifier' },
            { 'npwd_match_profiles', 'identifier' },
            { 'players', 'citizenid' },
        },
        qbcore = {
            { 'apartments', 'citizenid' },
            { 'bank_accounts', 'citizenid' },
            { 'crypto_transactions', 'citizenid' },
            { 'phone_invoices', 'citizenid' },
            { 'phone_messages', 'citizenid' },
            { 'playerskins', 'citizenid' },
            { 'player_contacts', 'citizenid' },
            { 'player_houses', 'citizenid' },
            { 'player_mails', 'citizenid' },
            { 'player_outfits', 'citizenid' },
            { 'player_vehicles', 'citizenid' },
            { 'players', 'citizenid' },
        },
        esx = {
            -- In addition to these, server/database.lua auto-discovers any base table with `identifier` or `owner` columns
            { 'owned_vehicles', 'owner' },
            { 'addon_account_data', 'owner' },
            { 'addon_inventory_items', 'owner' },
            { 'datastore_data', 'owner' },
            { 'billing', 'identifier' },
            { 'user_licenses', 'owner' },
            { 'users', 'identifier' },
        },
    },
}
