-- Variables
local radialmenu = require 'client.radialmenu'
local config = require 'shared.config'
local blip

-- Functions
local function getVehNodeType(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end

local function getStoppingLocation(coords)
    local _, nCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    return nCoords
end

local function getStartingLocation(coords)
    local dist, vector, nNode, heading, nType = 0, vector3(0, 0, 0), math.random(10, 20), 0, 66

    while dist < config.minSpawnDist or nType == 66 or nType == 64 do
        nNode += math.random(10, 20)
        _, vector, heading = GetNthClosestVehicleNodeFavourDirection(coords.x, coords.y, coords.z,
            coords.x, coords.y, coords.z, nNode, 0, 4194304, 0)
        nType = getVehNodeType(vector)
        dist = #(coords - vector)
        if dist >= 200.0 then break end
        Wait(1)
    end

    return vector4(vector.x, vector.y, vector.z, heading)
end

local function wanderOff(veh)
    local driver = NetworkGetEntityFromNetworkId(Entity(veh).state.citra_taxi_driver)
    ClearPedTasksImmediately(driver)
    SetPedIntoVehicle(driver, veh, -1)
    SetVehicleDoorsShut(veh, false)
    TaskVehicleDriveWander(driver, veh, 20.0, config.drivingStyles.normal.style)
    SetPedKeepTask(driver, true)
    SetEntityAsNoLongerNeeded(driver)
    SetEntityAsNoLongerNeeded(veh)

    if blip then blip = blip:delete() end
end

local function taxiCheckThread(taxi)
    CreateThread(function()
        local init, closeSpeech = true, false
        local style = Entity(taxi).state.citra_taxi_style
        local taxiCoords = GetEntityCoords(taxi)
        local flags = getVehNodeType(taxiCoords)
        local dest = Entity(taxi).state.citra_taxi_dest
        while Entity(taxi).state.citra_taxi_ready do
            local driver = NetworkGetEntityFromNetworkId(Entity(taxi).state.citra_taxi_driver)
            taxiCoords = GetEntityCoords(taxi)
            local newFlags = getVehNodeType(taxiCoords)
            if #(dest - taxiCoords) < 20.0 then
                if LocalPlayer.state.citra_taxi_inTaxi and not closeSpeech then
                    PlayPedAmbientSpeechNative(driver, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
                    closeSpeech = true
                elseif not Entity(taxi).state.citra_taxi_arrived then
                    StartVehicleHorn(taxi, 5000, joaat("NORMAL"), false)
                    Entity(taxi).state:set('citra_taxi_arrived', true, true)
                end
            end
            if init or style ~= Entity(taxi).state.citra_taxi_style or dest ~= Entity(taxi).state.citra_taxi_dest or newFlags ~= flags then
                if dest ~= Entity(taxi).state.citra_taxi_dest then closeSpeech = false init = true end
                style, dest, flags = Entity(taxi).state.citra_taxi_style, Entity(taxi).state.citra_taxi_dest, newFlags
                local speed = (config.speedLimitZones[flags] or (init and 40.0 or 0.0)) * style.speedMult
                if speed > 0.0 then
                    TaskVehicleDriveToCoordLongrange(driver, taxi, dest.x, dest.y, dest.z, speed * 0.44704, style.style, 10.0)
                    SetPedKeepTask(driver, true)
                    SetDriverAggressiveness(driver, style.aggressiveness)
                end
                init = false
            end
            Wait(1000)
        end
    end)
end

local function spawnTaxi(data)
    if LocalPlayer.state.citra_taxi_inTaxi then return end
    data = data.data or data -- Workaround for qb-radialmenu
    local plyCoords = GetEntityCoords(cache.ped)
    data.startingLocation = getStartingLocation(plyCoords)
    data.stoppingLocation = getStoppingLocation(plyCoords)
    TriggerScreenblurFadeIn(250)
    Wait(250)
    SetFocusPosAndVel(data.startingLocation.x, data.startingLocation.y, data.startingLocation.z, 0, 0, 0)
    lib.callback('citra-taxi:server:spawnTaxi', false, function(taxiNetId)
        LocalPlayer.state:set('citra_taxi_waitingTaxi', taxiNetId, true)
        while not NetworkDoesEntityExistWithNetworkId(taxiNetId) do Wait(10) end
        local taxi = NetworkGetEntityFromNetworkId(taxiNetId)
        while not Entity(taxi).state.citra_taxi_driver do Wait(10) end
        local driverNetId = Entity(taxi).state.citra_taxi_driver
        while not NetworkDoesEntityExistWithNetworkId(driverNetId) do Wait(10) end
        local driver = NetworkGetEntityFromNetworkId(driverNetId)

        SetVehicleEngineOn(taxi, true, true, false)
        SetHornEnabled(taxi, true)
        SetVehicleFuelLevel(taxi, 100.0)
        DecorSetFloat(taxi, '_FUEL_LEVEL', 100.0) -- Legacy fuel support
        SetVehicleDoorLatched(taxi, -1, true, true, true)
        SetVehicleAutoRepairDisabled(taxi, false)
        SetEntityAsMissionEntity(taxi, true, true)
        for extra, enabled in pairs(data.extras) do
            ---@diagnostic disable-next-line: param-type-mismatch
            SetVehicleExtra(taxi, extra, enabled and 0 or 1)
        end

        SetAmbientVoiceName(driver, data.driver.voice)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetDriverAbility(driver, 1.0)
        SetEntityAsMissionEntity(driver, true, true)
        TriggerScreenblurFadeOut(200)
        SetFocusEntity(cache.ped)

        bridge.framework:notify('Taxi is on the way', 'success')

        Entity(taxi).state:set('citra_taxi_ready', true, true)

        blip = bridge.util.blip({
            entity = taxi,
            sprite = 198,
            colour = 5,
            display = 2,
            flash = true,
            flashtime = 750,
            label = 'Taxi',
        })

        while not Entity(taxi).state.citra_taxi_ready do Wait(100) end
        CreateThread(function()
            while not LocalPlayer.state.citra_taxi_inTaxi and Entity(taxi).state.citra_taxi_ready do
                if not DoesEntityExist(taxi) then
                    bridge.framework:notify("Your taxi took another call. Another one is on the way.", 'primary')
                    Entity(taxi).state:set('citra_taxi_ready', false, true)
                    TriggerServerEvent('citra-taxi:server:resetTaxi', taxiNetId, data)
                    break
                elseif not IsPedInVehicle(driver, taxi, true) then
                    SetPedIntoVehicle(driver, taxi, -1)
                end
                Wait(1000)
            end
        end)

        radialmenu:create(taxi)
        taxiCheckThread(taxi)
    end, data)
end

-- Statebag Handler
---@diagnostic disable-next-line: param-type-mismatch
local SBHandler = AddStateBagChangeHandler(nil, nil, function(bagName, key, value)
    if key == 'citra_taxi_ready' then
        if not value then
            wanderOff(GetEntityFromStateBagName(bagName))
        end
    elseif (key == 'citra_taxi_style' or key == 'citra_taxi_dest') and LocalPlayer.state.citra_taxi_inTaxi then
        local taxi = NetworkGetEntityFromNetworkId(LocalPlayer.state.citra_taxi_inTaxi)
        local driver = NetworkGetEntityFromNetworkId(Entity(taxi).state.citra_taxi_driver)
        if taxi == GetEntityFromStateBagName(bagName) then
            if key == 'citra_taxi_style' then
                if value == config.drivingStyles.rush then
                    PlayPedAmbientSpeechNative(driver, 'TAXID_SPEED_UP', "SPEECH_PARAMS_FORCE_NORMAL")
                else
                    PlayPedAmbientSpeechNative(driver, 'TAXID_BEGIN_JOURNEY', "SPEECH_PARAMS_FORCE_NORMAL")
                end
                Wait(10)
                radialmenu:create(taxi)
            elseif key == 'citra_taxi_dest' then
                SetVehicleDoorsShut(taxi, false)
                PlayPedAmbientSpeechNative(driver, 'TAXID_CHANGE_DEST', "SPEECH_PARAMS_FORCE_NORMAL")
            end
        end
    elseif key == 'citra_taxi_inTaxi' and GetPlayerFromStateBagName(bagName) == PlayerId() then
        radialmenu:create(value)
        if value then blip:toggleFlash() end
    end
end)

-- Keybinds & cache triggers
lib.addKeybind({
    name = 'taxienterexit',
    description = 'Enter / Exit a Taxi',
    defaultKey = 'F',
    onReleased = function()
        if LocalPlayer.state.citra_taxi_inTaxi then
            local taxi = NetworkGetEntityFromNetworkId(LocalPlayer.state.citra_taxi_inTaxi)
            TriggerServerEvent('citra-taxi:server:payFare')
            for i = 2, 3 do SetVehicleDoorOpen(taxi, i, false, true) end
            TaskLeaveVehicle(cache.ped, taxi, 1)
        else
            Wait(10)
            local veh = GetVehiclePedIsTryingToEnter(cache.ped)
            if veh == 0 or not veh or not Entity(veh).state.citra_taxi_isTaxi then return end
            ClearPedTasks(cache.ped)
            for i = 2, 1, -1 do
                if IsVehicleSeatFree(veh, i) then
                    TaskEnterVehicle(cache.ped, veh, 5000, i, 1.0, 1, 0)
                    return
                end
            end
            bridge.framework:notify("There are no free seats. You'll have to grab another cab!", 'error', 7000)
        end
    end,
})

lib.onCache('vehicle', function(veh)
    if cache.vehicle and Entity(cache.vehicle).state.citra_taxi_isTaxi then
        LocalPlayer.state:set('citra_taxi_inTaxi', nil, true)
    elseif veh and Entity(veh).state.citra_taxi_isTaxi then
        LocalPlayer.state:set('citra_taxi_inTaxi', NetworkGetNetworkIdFromEntity(veh), true)
        LocalPlayer.state:set('citra_taxi_waitingTaxi', nil, true)
        PlayPedAmbientSpeechNative(NetworkGetEntityFromNetworkId(Entity(veh).state.citra_taxi_driver),
            "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
        Wait(10)
        radialmenu:create(veh)
    end
end)

-- Callbacks
lib.callback.register('citra-taxi:client:getWaypoint', function()
    local waypoint = GetFirstBlipInfoId(8)

    if DoesBlipExist(waypoint) then
        return getStoppingLocation(GetBlipCoords(waypoint))
    end
end)

-- Events
RegisterNetEvent('citra-taxi:client:callTaxi', spawnTaxi)

RegisterNetEvent('citra-taxi:client:cancelTaxi', function()
    if not (LocalPlayer.state.citra_taxi_inTaxi or LocalPlayer.state.citra_taxi_waitingTaxi) then return end
    local taxi = NetworkGetEntityFromNetworkId(LocalPlayer.state.citra_taxi_inTaxi or LocalPlayer.state.citra_taxi_waitingTaxi)
    if not cache.vehicle then LocalPlayer.state:set('citra_taxi_inTaxi', nil, true) end
    if LocalPlayer.state.citra_taxi_inTaxi then
        Entity(taxi).state:set('citra_taxi_dest', getStoppingLocation(GetEntityCoords(cache.ped)), true)
    else
        LocalPlayer.state:set('citra_taxi_waitingTaxi', nil, true)
        Entity(taxi).state:set('citra_taxi_ready', false, true)
    end
end)

RegisterNetEvent('citra-taxi:client:alertPolice', function(taxiNetId)
    local taxi = NetworkGetEntityFromNetworkId(taxiNetId)
    local driver = NetworkGetEntityFromNetworkId(Entity(taxi).state.citra_taxi_driver)
    PlayPedAmbientSpeechNative(driver, "TAXID_RUN_AWAY", "SPEECH_PARAMS_FORCE_NORMAL")

    bridge.dispatch:policeAlert(nil, {
        title = 'Taxi Fare Theft',
        coords = GetEntityCoords(cache.ped),
        icon = 'fas fa-taxi',
        msg = 'Someone just skipped on their cab fare!',
        player = {
            showGender = true,
        },
        blip = {
            sprite = 198,
            colour = 1,
            scale = 1.0,
            length = 5,
            flashes = true,
        },
    })

    if blip then blip = blip:delete() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveStateBagChangeHandler(SBHandler)
    radialmenu:teardown()
end)

radialmenu:create()
