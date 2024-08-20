local config = require 'shared.config'

---@class RadialMenu : OxClass
local RadialMenu = lib.class('RadialMenu')

function RadialMenu:constructor()
    self.menuid = nil
end

function RadialMenu:isStarted()
    return GetResourceState('qb-radialmenu') == "started"
end

function RadialMenu:teardown()
    if not self:isStarted() then return end
    if self.menuid then exports['qb-radialmenu']:RemoveOption(self.menuid) end
end

function RadialMenu:create(taxi)
    if not self:isStarted() then return end
    self:teardown()

    local menu = {
        id = 'taxi',
        title = 'Taxi',
        icon = 'taxi',
        items = {}
    }

    if taxi then
        menu.items[#menu.items + 1] = {
            id = 'taxicancel',
            title = 'Cancel cab',
            icon = 'phone-slash',
            type = 'client',
            event = 'citra-taxi:client:cancelTaxi',
            shouldClose = true,
        }
        if cache.vehicle == taxi then
            menu.items[#menu.items + 1] = {
                id = 'taxidestination',
                title = 'Set destination',
                icon = 'map',
                type = 'server',
                event = 'citra-taxi:server:go',
                shouldClose = true,
            }
            if Entity(taxi).state.citra_taxi_style?.style == config.drivingStyles.rush.style then
                menu.items[#menu.items + 1] = {
                    id = 'taxisslowdown',
                    title = 'Slow down',
                    icon = 'wind',
                    type = 'server',
                    event = 'citra-taxi:server:speedDown',
                    shouldClose = true,
                }
            else
                menu.items[#menu.items + 1] = {
                    id = 'taxispeedup',
                    title = 'Hurry up!',
                    icon = 'wind',
                    type = 'server',
                    event = 'citra-taxi:server:speedUp',
                    shouldClose = true,
                }
            end
        end
    else
        for carType, data in pairs(config.tiers) do
            menu.items[#menu.items + 1] = {
                id = 'calltaxi' .. carType,
                title = 'Call a ' .. data.label,
                icon = 'phone',
                type = 'client',
                event = 'citra-taxi:client:callTaxi',
                shouldClose = true,
                data = data,
            }
        end
    end

    self.menuid = exports['qb-radialmenu']:AddOption(menu)
end

return RadialMenu
