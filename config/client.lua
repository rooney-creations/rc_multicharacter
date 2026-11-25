Config = Config or {}

Config.Client = {
    -- Waiting time (ms) for ox_lib model loading before timing out
    loadingModelsTimeout = 30000,

    -- Whether to open starting apartment selection for new characters (if apartment/spawn resource is running)
    startingApartment = true,

    -- If true, skips spawn selection menus for existing characters and spawns directly at last location
    skipSpawnSelection = false,

    -- Registration date picker configuration (Qbox default format)
    dateFormat = 'YYYY-MM-DD',
    dateMin = '1900-01-01',
    dateMax = '2006-12-31',

    -- Default character height (cm) used when saving ESX identity rows (ESX users.height)
    defaultHeight = 175,
    -- If true on ESX, prompts for height in registration dialog
    askHeightOnEsx = false,
    minHeight = 120,
    maxHeight = 220,

    -- If true, restricts nationality to data/nationalities.lua searchable dropdown
    limitNationalities = true,

    -- Lowercased blocked words for character registration inputs
    profanityWords = {
        ['bad word'] = true,
    },

    -- Spawn/camera locations for multicharacter preview (chosen randomly from qbx_core defaults)
    locations = {
        {
            pedCoords = vec4(969.25, 72.61, 116.18, 276.55),
            camCoords = vec4(972.2, 72.9, 116.68, 97.27),
        },
        {
            pedCoords = vec4(1104.49, 195.9, -49.44, 44.22),
            camCoords = vec4(1102.29, 198.14, -48.86, 225.07),
        },
        {
            pedCoords = vec4(-2163.87, 1134.51, -24.37, 310.05),
            camCoords = vec4(-2161.7, 1136.4, -23.77, 131.52),
        },
        {
            pedCoords = vec4(-996.71, -68.07, -99.0, 57.61),
            camCoords = vec4(-999.90, -66.30, -98.45, 241.68),
        },
        {
            pedCoords = vec4(-1023.45, -418.42, 67.66, 205.69),
            camCoords = vec4(-1021.8, -421.7, 68.14, 27.11),
        },
        {
            pedCoords = vec4(2265.27, 2925.02, -84.8, 267.77),
            camCoords = vec4(2268.24, 2925.02, -84.36, 90.88),
        },
        {
            pedCoords = vec4(-1004.5, -478.51, 50.03, 28.19),
            camCoords = vec4(-1006.36, -476.19, 50.50, 210.38),
        },
    },
}
