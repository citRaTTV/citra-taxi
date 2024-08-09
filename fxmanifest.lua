fx_version 'cerulean'
game 'gta5'

author 'citRa'
description 'Simple taxi script'
version '2.0.0'
lua54 'yes'

dependencies {
    'citra_bridge',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@citra_bridge/main.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'shared/config.lua',
    'client/radialmenu.lua',
}
