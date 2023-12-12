-- Variables
local QBCore = exports['qb-core']:GetCoreObject()

-- Commands
QBCore.Commands.Add('taxi', 'Call a taxi', {}, false, function(source, _, _)
    TriggerClientEvent('citra-taxi:client:callOrCancelTaxi', source)
end, 'user')

QBCore.Commands.Add('taxigo', 'Get taxi to go to waypoint', {}, false, function(source, _, _)
    TriggerClientEvent('citra-taxi:client:setDestination', source)
end, 'user')

-- Events
RegisterNetEvent('citra-taxi:server:payFare', function(time)
    local src = source
    local fare = math.ceil(Config.Fare.base + (Config.Fare.tick * (time / Config.Fare.tickTime)))

    if fare > 0 then
        local Player = QBCore.Functions.GetPlayer(src)
        Player.Functions.RemoveMoney('cash', fare, 'Taxi fare')
        TriggerClientEvent('QBCore:Notify', src, 'Fare of $' .. fare + 0.00 .. ' paid')
    end
end)
