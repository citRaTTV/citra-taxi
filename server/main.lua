local config = require 'shared.config'
local taxis = {}

-- Functions
local function taxiGo(source)
    if Player(source).state.citra_taxi_inTaxi then
        lib.callback('citra-taxi:client:getWaypoint', source, function(waypoint)
            if not waypoint then return end
            local taxi = NetworkGetEntityFromNetworkId(Player(source).state.citra_taxi_inTaxi)
            Entity(taxi).state:set('citra_taxi_dest', waypoint, true)
        end)
    end
end

local function taxiFast(source)
    if Player(source).state.citra_taxi_inTaxi then
        local taxi = NetworkGetEntityFromNetworkId(Player(source).state.citra_taxi_inTaxi)
        Entity(taxi).state:set('citra_taxi_style', config.drivingStyles.rush, true)
    end
end

local function taxiSlow(source)
    if Player(source).state.citra_taxi_inTaxi then
        local taxi = NetworkGetEntityFromNetworkId(Player(source).state.citra_taxi_inTaxi)
        Entity(taxi).state:set('citra_taxi_style', config.drivingStyles.normal, true)
    end
end

---@diagnostic disable-next-line: param-type-mismatch
local SBHandler = AddStateBagChangeHandler('citra_taxi_inTaxi', nil, function(bagName, key, value)
    if value then
        local taxi = NetworkGetEntityFromNetworkId(value)
        Entity(taxi).state:set('citra_taxi_start', os.time(), true)
    end
end)

-- Exports
exports('taxiGo', taxiGo)
exports('taxiFast', taxiFast)
exports('taxiSlow', taxiSlow)

-- Commands
lib.addCommand('taxi', {
    help = 'Call / stop a taxi',
}, function(source, args, _)
    if Player(source).state.citra_taxi_inTaxi then
        TriggerClientEvent('citra-taxi:client:cancelTaxi', source)
    else
        TriggerClientEvent('citra-taxi:client:callTaxi', source, config.tiers[args[1]] or config.tiers.cab)
    end
end)

lib.addCommand('taxigo', {
    help = 'Get taxi to go to waypoint',
}, taxiGo)

lib.addCommand('taxifast', {
    help = 'Tell driver to speed up',
}, taxiFast)

lib.addCommand('taxislow', {
    help = 'Tell driver to slow down',
}, taxiSlow)

-- Callbacks
lib.callback.register('citra-taxi:server:spawnTaxi', function(source, data)
    lib.print.debug(data)
    local taxi = CreateVehicleServerSetter(data.models[math.random(#data.models)], 'automobile', data.startingLocation.x,
        data.startingLocation.y, data.startingLocation.z, data.startingLocation.w)
    while not DoesEntityExist(taxi) do Wait(10) end
    Entity(taxi).state:set('citra_taxi_isTaxi', true, true)
    Entity(taxi).state:set('citra_taxi_dest', data.stoppingLocation, true)
    Entity(taxi).state:set('citra_taxi_style', config.drivingStyles.normal, true)
    Entity(taxi).state:set('citra_taxi_fare', data.fare)
    Entity(taxi).state:set('ignoreLocks', true, true)

    local driver = CreatePed(1, data.driver.model, data.startingLocation.x, data.startingLocation.y,
        data.startingLocation.z, data.startingLocation.w, true, true)
    while not DoesEntityExist(driver) do Wait(10) end
    Entity(driver).state:set('citra_taxi_isDriver', true, true)
    Entity(taxi).state:set('citra_taxi_driver', NetworkGetNetworkIdFromEntity(driver), true)

    SetPedIntoVehicle(driver, taxi, -1)
    taxis[#taxis+1] = { taxi = taxi, driver = driver }
    return NetworkGetNetworkIdFromEntity(taxi)
end)

-- Events
RegisterNetEvent('citra-taxi:server:speedDown', function()
    taxiSlow(source)
end)

RegisterNetEvent('citra-taxi:server:speedUp', function()
    taxiFast(source)
end)

RegisterNetEvent('citra-taxi:server:go', function()
    taxiGo(source)
end)

RegisterNetEvent('citra-taxi:server:resetTaxi', function(taxiNetId, data)
    local src = source
    local taxi = NetworkGetEntityFromNetworkId(taxiNetId)
    for i = 1, #taxis do
        if taxis[i].taxi == taxi then
            DeleteEntity(taxis[i].taxi)
            DeleteEntity(taxis[i].driver)
            taxis[i] = nil
            break
        end
    end
    TriggerClientEvent('citra-taxi:client:callTaxi', src, data)
end)

RegisterNetEvent('citra-taxi:server:payFare', function()
    local src = source
    local taxi = NetworkGetEntityFromNetworkId(Player(src).state.citra_taxi_inTaxi)
    if not (taxi and DoesEntityExist(taxi)) then return end
    local rates = Entity(taxi).state.citra_taxi_fare
    local fare = math.ceil(rates.base + (rates.tick * (
        (os.time() - Entity(taxi).state.citra_taxi_start) / rates.tickTime)))

    if fare > 0 then
        if bridge.framework:removeMoney(src, 'cash', fare, 'Taxi fare') or not config.noPayAlert then
            bridge.framework:notify(src, ('Fare of $%0.2f paid'):format(fare), 'success')
            Wait(3000)
        elseif config.noPayAlert then
            TriggerClientEvent('citra-taxi:client:alertPolice', src, Player(src).state.citra_taxi_inTaxi)
        end
    end
    Entity(taxi).state:set('citra_taxi_ready', false, true)
    for i = 1, #taxis do
        if taxi == taxis[i].taxi then
            taxis[i] = nil
            break
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    lib.versionCheck('citRaTTV/citra-taxi')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveStateBagChangeHandler(SBHandler)
    for i = 1, #taxis do DeleteEntity(taxis[i].taxi) DeleteEntity(taxis[i].driver) end
end)
