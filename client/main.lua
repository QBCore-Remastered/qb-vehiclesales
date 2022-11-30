local QBCore = exports['qb-core']:GetCoreObject()
local Zone = nil
local TextShown = false
local AcitveZone = {}
local CurrentVehicle = {}
local SpawnZone = {}
local EntityZones = {}
local occasionVehicles = {}
local listen = false

-- Functions
local function spawnOccasionsVehicles(vehicles)
    if Zone then
        local oSlot = Config.Zones[Zone].VehicleSpots

        if not occasionVehicles[Zone] then
            occasionVehicles[Zone] = {}
        end

        if vehicles then
            for i = 1, #vehicles, 1 do
                local model = joaat(vehicles[i].model)

                lib.requestModel(model)

                occasionVehicles[Zone][i] = {
                    car = CreateVehicle(model, oSlot[i].x, oSlot[i].y, oSlot[i].z, false, false),
                    loc = vec3(oSlot[i].x, oSlot[i].y, oSlot[i].z),
                    price = vehicles[i].price,
                    owner = vehicles[i].seller,
                    model = vehicles[i].model,
                    plate = vehicles[i].plate,
                    oid = vehicles[i].occasionid,
                    desc = vehicles[i].description,
                    mods = vehicles[i].mods
                }

                QBCore.Functions.SetVehicleProperties(occasionVehicles[Zone][i].car, json.decode(occasionVehicles[Zone][i].mods))

                SetModelAsNoLongerNeeded(model)
                SetVehicleOnGroundProperly(occasionVehicles[Zone][i].car)
                SetEntityInvincible(occasionVehicles[Zone][i].car,true)
                SetEntityHeading(occasionVehicles[Zone][i].car, oSlot[i].w)
                SetVehicleDoorsLocked(occasionVehicles[Zone][i].car, 3)
                SetVehicleNumberPlateText(occasionVehicles[Zone][i].car, occasionVehicles[Zone][i].oid)
                FreezeEntityPosition(occasionVehicles[Zone][i].car, true)

                if Config.UseTarget then
                    if not EntityZones then
                        EntityZones = {}
                    end

                    local networkId = NetworkGetNetworkIdFromEntity(occasionVehicles[Zone][i].car)

                    EntityZones[i] = networkId

                    exports.ox_target:addEntity(networkId, {
                        {
                            name = 'qb-vehiclesales:vehicle-' .. i,
                            icon = "fas fa-car",
                            label = Lang:t("menu.view_contract"),
                            distance = 2.0,
                            onSelect = function(_)
                                TriggerEvent("qb-vehiclesales:client:OpenContract", i)
                            end
                        }
                    })
                end
            end
        end
    end
end

local function despawnOccasionsVehicles()
    if not Zone then
        return
    end

    local oSlot = Config.Zones[Zone].VehicleSpots

    for i = 1, #oSlot, 1 do
        local loc = oSlot[i]
        local oldVehicle = GetClosestVehicle(loc.x, loc.y, loc.z, 1.3, 0, 70)

        if oldVehicle then
            QBCore.Functions.DeleteVehicle(oldVehicle)
        end

        if Config.UseTarget then
            exports.ox_target:removeZone(EntityZones[i])
        else
            exports.ox_target:removeEntity(EntityZones[i], 'qb-vehiclesales:vehicle-' .. i)
        end
    end

    EntityZones = {}
end

local function openSellContract(bool)
    local pData = QBCore.Functions.GetPlayerData()

    SetNuiFocus(bool, bool)
    SendNUIMessage({
        action = "sellVehicle",
        showTakeBackOption = false,
        bizName = Config.Zones[Zone].BusinessName,
        sellerData = {
            firstname = pData.charinfo.firstname,
            lastname = pData.charinfo.lastname,
            account = pData.charinfo.account,
            phone = pData.charinfo.phone
        },
        plate = QBCore.Functions.GetPlate(GetVehiclePedIsUsing(cache.ped))
    })
end

local function openBuyContract(sellerData, vehicleData)
    local pData = QBCore.Functions.GetPlayerData()

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "buyVehicle",
        showTakeBackOption = sellerData.charinfo.firstname == pData.charinfo.firstname and sellerData.charinfo.lastname == pData.charinfo.lastname,
        bizName = Config.Zones[Zone].BusinessName,
        sellerData = {
            firstname = sellerData.charinfo.firstname,
            lastname = sellerData.charinfo.lastname,
            account = sellerData.charinfo.account,
            phone = sellerData.charinfo.phone
        },
        vehicleData = {
            desc = vehicleData.desc,
            price = vehicleData.price
        },
        plate = vehicleData.plate
    })
end

local function sellVehicleWait(price)
    DoScreenFadeOut(250)
    Wait(250)

    QBCore.Functions.DeleteVehicle(cache.vehicle)

    Wait(1500)
    DoScreenFadeIn(250)

    QBCore.Functions.Notify(Lang:t('success.car_up_for_sale', { value = price }), 'success')

    PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
end

local function SellData(data, model)
    QBCore.Functions.TriggerCallback("qb-vehiclesales:server:CheckModelName", function(DataReturning)
        local vehicleData = {}

        vehicleData.ent = GetVehiclePedIsUsing(cache.ped)
        vehicleData.model = DataReturning
        vehicleData.plate = model
        vehicleData.mods = QBCore.Functions.GetVehicleProperties(vehicleData.ent)
        vehicleData.desc = data.desc

        TriggerServerEvent('qb-occasions:server:sellVehicle', data.price, vehicleData)

        sellVehicleWait(data.price)
    end, model)
end

local function Listen4Control(spot) -- Uses this to listen for controls to open various menus.
    listen = true

    CreateThread(function()
        while listen do
            if IsControlJustReleased(0, 38) then -- E
                if spot then
                    TriggerEvent('qb-vehiclesales:client:OpenContract', spot)
                else
                    if IsPedInAnyVehicle(cache.ped, false) then
                        listen = false

                        TriggerEvent('qb-occasions:client:MainMenu')
                    else
                        QBCore.Functions.Notify(Lang:t("error.not_in_veh"), "error", 4500)
                    end
                end
            end

            Wait(0)
        end
    end)
end

---- ** Main Zone Functions ** ----
local function CreateZones()
    for k, v in pairs(Config.Zones) do
        AcitveZone[k] = lib.zones.poly({
            points = v.zone,
            thickness = 14,
            onEnter = function(_)
                if Zone ~= k then
                    Zone = k

                    QBCore.Functions.TriggerCallback('qb-occasions:server:getVehicles', function(vehicles)
                        despawnOccasionsVehicles()
                        spawnOccasionsVehicles(vehicles)
                    end)
                end
            end,
            onExit = function(_)
                despawnOccasionsVehicles()

                Zone = nil
            end
        })
    end
end

local function DeleteZones()
    for k in pairs(Config.Zones) do
        SpawnZone[k]:remove()
    end

    for k in pairs(AcitveZone) do
        AcitveZone[k]:remove()
    end

    AcitveZone = {}
end

local function IsCarSpawned(Car)
    local bool = false

    if occasionVehicles then
        for k in pairs(occasionVehicles[Zone]) do
            if k == Car then
                bool = true
                break
            end
        end
    end

    return bool
end

-- NUI Callbacks
RegisterNUICallback('sellVehicle', function(data, cb)
    local plate = QBCore.Functions.GetPlate(GetVehiclePedIsUsing(cache.ped)) -- Getting the plate and sending to the function

    SellData(data, plate)

    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)

    cb('ok')
end)

RegisterNUICallback('buyVehicle', function(_, cb)
    TriggerServerEvent('qb-occasions:server:buyVehicle', CurrentVehicle)

    cb('ok')
end)

RegisterNUICallback('takeVehicleBack', function(_, cb)
    TriggerServerEvent('qb-occasions:server:ReturnVehicle', CurrentVehicle)

    cb('ok')
end)

-- Events
RegisterNetEvent('qb-occasions:client:BuyFinished', function(vehdata)
    local vehmods = json.decode(vehdata.mods)

    DoScreenFadeOut(250)
    Wait(500)

    QBCore.Functions.SpawnVehicle(vehdata.model, function(veh)
        SetVehicleNumberPlateText(veh, vehdata.plate)
        SetEntityHeading(veh, Config.Zones[Zone].BuyVehicle.w)
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        SetVehicleFuelLevel(veh, 100.0)

        QBCore.Functions.Notify(Lang:t('success.vehicle_bought'), "success", 2500)

        TriggerEvent("vehiclekeys:client:SetOwner", vehdata.plate)

        SetVehicleEngineOn(veh, true, true)

        Wait(500)

        QBCore.Functions.SetVehicleProperties(veh, vehmods)
    end, Config.Zones[Zone].BuyVehicle, true)

    Wait(500)
    DoScreenFadeIn(250)

    CurrentVehicle = {}
end)

RegisterNetEvent('qb-occasions:client:SellBackCar', function()
    if IsPedInAnyVehicle(cache.ped, false) then
        local vehicleData = {}

        vehicleData.model = GetEntityModel(cache.vehicle)
        vehicleData.plate = GetVehicleNumberPlateText(cache.vehicle)

        QBCore.Functions.TriggerCallback('qb-garage:server:checkVehicleOwner', function(owned, balance)
            if owned then
                if balance < 1 then
                    TriggerServerEvent('qb-occasions:server:sellVehicleBack', vehicleData)

                    QBCore.Functions.DeleteVehicle(cache.vehicle)
                else
                    QBCore.Functions.Notify(Lang:t('error.finish_payments'), 'error', 3500)
                end
            else
                QBCore.Functions.Notify(Lang:t('error.not_your_vehicle'), 'error', 3500)
            end
        end, vehicleData.plate)
    else
        QBCore.Functions.Notify(Lang:t("error.not_in_veh"), "error", 4500)
    end
end)

RegisterNetEvent('qb-occasions:client:ReturnOwnedVehicle', function(vehdata)
    local vehmods = json.decode(vehdata.mods)

    DoScreenFadeOut(250)
    Wait(500)

    QBCore.Functions.SpawnVehicle(vehdata.model, function(veh)
        SetVehicleNumberPlateText(veh, vehdata.plate)
        SetEntityHeading(veh, Config.Zones[Zone].BuyVehicle.w)
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        SetVehicleFuelLevel(veh, 100.0)

        QBCore.Functions.Notify(Lang:t('info.vehicle_returned'))

        TriggerEvent("vehiclekeys:client:SetOwner", vehdata.plate)

        SetVehicleEngineOn(veh, true, true)

        Wait(500)

        QBCore.Functions.SetVehicleProperties(veh, vehmods)
    end, Config.Zones[Zone].BuyVehicle, true)

    Wait(500)
    DoScreenFadeIn(250)

    CurrentVehicle = {}
end)

RegisterNetEvent('qb-occasion:client:refreshVehicles', function()
    if Zone then
        QBCore.Functions.TriggerCallback('qb-occasions:server:getVehicles', function(vehicles)
            despawnOccasionsVehicles()
            spawnOccasionsVehicles(vehicles)
        end)
    end
end)

RegisterNetEvent('qb-vehiclesales:client:SellVehicle', function()
    local VehiclePlate = QBCore.Functions.GetPlate(cache.vehicle)

    QBCore.Functions.TriggerCallback('qb-garage:server:checkVehicleOwner', function(owned, balance)
        if owned then
            if balance < 1 then
                QBCore.Functions.TriggerCallback('qb-occasions:server:getVehicles', function(vehicles)
                    if not vehicles or #vehicles < #Config.Zones[Zone].VehicleSpots then
                        openSellContract(true)
                    else
                        QBCore.Functions.Notify(Lang:t('error.no_space_on_lot'), 'error', 3500)
                    end
                end)
            else
                QBCore.Functions.Notify(Lang:t('error.finish_payments'), 'error', 3500)
            end
        else
            QBCore.Functions.Notify(Lang:t('error.not_your_vehicle'), 'error', 3500)
        end
    end, VehiclePlate)
end)

RegisterNetEvent('qb-vehiclesales:client:OpenContract', function(Contract)
    CurrentVehicle = occasionVehicles[Zone][Contract]

    if CurrentVehicle then
        QBCore.Functions.TriggerCallback('qb-occasions:server:getSellerInformation', function(info)
            if info then
                info.charinfo = json.decode(info.charinfo)
            else
                info = {}
                info.charinfo = {
                    firstname = Lang:t('charinfo.firstname'),
                    lastname = Lang:t('charinfo.lastname'),
                    account = Lang:t('charinfo.account'),
                    phone = Lang:t('charinfo.phone')
                }
            end

            openBuyContract(info, CurrentVehicle)
        end, CurrentVehicle.owner)
    else
        QBCore.Functions.Notify(Lang:t("error.not_for_sale"), 'error', 7500)
    end
end)

RegisterNetEvent('qb-occasions:client:MainMenu', function()
    lib.registerContext({
        id = 'open_occasionsMain',
        title = Config.Zones[Zone].BusinessName,
        options = {
            {
                title = Lang:t("menu.sell_vehicle"),
                icon = "fa-solid fa-money-bill",
                description = Lang:t("menu.sell_vehicle_help"),
                event = 'qb-vehiclesales:client:SellVehicle'
            },
            {
                title = Lang:t("menu.sell_back"),
                icon = "fa-solid fa-warehouse",
                description = Lang:t("menu.sell_back_help"),
                event = 'qb-occasions:client:SellBackCar'
            }
        }
    })
    lib.showContext('open_occasionsMain')
end)

-- Threads
CreateThread(function()
    for _, cars in pairs(Config.Zones) do
        local OccasionBlip = AddBlipForCoord(cars.SellVehicle.x, cars.SellVehicle.y, cars.SellVehicle.z)

        SetBlipSprite(OccasionBlip, 326)
        SetBlipDisplay(OccasionBlip, 4)
        SetBlipScale(OccasionBlip, 0.75)
        SetBlipAsShortRange(OccasionBlip, true)
        SetBlipColour(OccasionBlip, 3)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Lang:t('info.used_vehicle_lot'))
        EndTextCommandSetBlipName(OccasionBlip)
    end
end)

CreateThread(function()
    for k, cars in pairs(Config.Zones) do
        SpawnZone[k] = lib.zones.sphere({
            coords = cars.SellVehicle,
            radius = 3.0,
            onEnter = function(_)
                if IsPedInAnyVehicle(cache.ped, false) then
                    lib.showTextUI(Lang:t("menu.interaction"))

                    TextShown = true

                    Listen4Control()
                end
            end,
            onExit = function(_)
                listen = false

                if TextShown then
                    TextShown = false

                    lib.hideTextUI()
                end
            end
        })

        if not Config.UseTarget then
            for k2, v in pairs(Config.Zones[k].VehicleSpots) do
                lib.zones.box({
                    coords = v,
                    size = vec3(5, 5, 5),
                    rotation = 0.0,
                    onEnter = function(_)
                        if IsCarSpawned(k2) then
                            lib.showTextUI(Lang:t("menu.view_contract_int"))

                            TextShown = true

                            Listen4Control(k2)
                        end
                    end,
                    onExit = function(_)
                        listen = false

                        if TextShown then
                            TextShown = false

                            lib.hideTextUI()
                        end
                    end
                })
            end
        end
    end
end)

---- ** Mostly just to ensure you can restart resources live without issues, also improves the code slightly. ** ----
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateZones()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DeleteZones()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CreateZones()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    DeleteZones()
    despawnOccasionsVehicles()
end)