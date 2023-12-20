if Config.framework == 'qb' then
    -- Variables
    local menuID

    -- Functions
    local function teardownMenu()
        if menuID and GetResourceState('qb-radialmenu') == "started" then
            exports['qb-radialmenu']:RemoveOption(menuID)
        end
    end

    function CreateMenu(inCab, isFast)
        if GetResourceState('qb-radialmenu') ~= "started" then return end
        teardownMenu()

        local menu = {
            id = 'taxi',
            title = 'Taxi',
            icon = 'taxi',
            items = {
                {
                    id = 'taxicancel',
                    title = 'Cancel / stop here',
                    icon = 'phone-slash',
                    type = 'client',
                    event = 'citra-taxi:client:cancelTaxi',
                    shouldClose = true,
                },
            }
        }

        if inCab then
            table.insert(menu.items, {
                id = 'taxidestination',
                title = 'Set destination',
                icon = 'map',
                type = 'client',
                event = 'citra-taxi:client:setDestination',
                shouldClose = true,
            })
            if isFast then
                table.insert(menu.items, {
                    id = 'taxisslowdown',
                    title = 'Slow down',
                    icon = 'wind',
                    type = 'client',
                    event = 'citra-taxi:client:speedDown',
                    shouldClose = true,
                })
            else
                table.insert(menu.items, {
                    id = 'taxispeedup',
                    title = 'Hurry up!',
                    icon = 'wind',
                    type = 'client',
                    event = 'citra-taxi:client:speedUp',
                    shouldClose = true,
                })
            end
        else
            table.insert(menu.items, {
                id = 'taxicall',
                title = 'Call a taxi',
                icon = 'phone',
                type = 'client',
                event = 'citra-taxi:client:callTaxi',
                shouldClose = true,
            })
        end

        menuID = exports['qb-radialmenu']:AddOption(menu)
    end

    -- Initial setup
    AddEventHandler('playerSpawned', function(_)
        CreateMenu()
    end)

    AddEventHandler('onResourceStart', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            CreateMenu()
        end
    end)

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            teardownMenu()
        end
    end)
end