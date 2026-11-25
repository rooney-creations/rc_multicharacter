fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rc_multicharacter'
author 'RC Engineering'
description 'Universal Qbox-based Multicharacter powered by ox_lib with automatic QBox, QBCore, and ESX Legacy bridge & SQL compatibility'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'bridge/framework.lua',
}

client_scripts {
    'config/client.lua',
    'bridge/client/qbox.lua',
    'bridge/client/qbcore.lua',
    'bridge/client/esx.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/database.lua',
    'bridge/server/qbox.lua',
    'bridge/server/qbcore.lua',
    'bridge/server/esx.lua',
    'server/main.lua',
}

files {
    'config/shared.lua',
    'config/client.lua',
    'data/nationalities.lua',
    'locales/*.json',
}

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
}

provide 'esx_multicharacter'
provide 'qb-multicharacter'
