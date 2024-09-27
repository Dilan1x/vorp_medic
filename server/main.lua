local Core                  = exports.vorp_core:GetCore()
local Inv                   = exports.vorp_inventory
local T <const>             = Translation.Langs[Config.Lang]
local JobsToAlert <const>   = {}
local PlayersAlerts <const> = {}

local function registerStorage(prefix, name, limit)
    local isInvRegstered <const> = Inv:isCustomInventoryRegistered(prefix)
    if not isInvRegstered then
        local data <const> = {
            id = prefix,
            name = name,
            limit = limit,
            acceptWeapons = true,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
            webhook = "" --Add webhook Url here

        }
        Inv:registerInventory(data)
    end
end

local function hasJob(user)
    local Character <const> = user.getUsedCharacter
    return Config.MedicJobs[Character.job]
end

local function isOnDuty(source)
    return Player(source).state.isMedicDuty
end

local function isPlayerNear(source, target)
    local sourcePos <const> = GetEntityCoords(GetPlayerPed(source))
    local targetPos <const> = GetEntityCoords(GetPlayerPed(target))
    local distance <const> = #(sourcePos - targetPos)
    return distance <= 5
end

local function openDoctorMenu(source)
    local user <const> = Core.getUser(source)
    if not user then return end

    if not hasJob(user) then
        return Core.NotifyObjective(source, T.Jobs.YouAreNotADoctor, 5000)
    end
    TriggerClientEvent('vorp_medic:Client:OpenMedicMenu', source)
end

local function getClosestPlayer(source)
    local players <const> = GetPlayers()
    local ent <const> = GetPlayerPed(source)
    local doctorCoords <const> = GetEntityCoords(ent)

    for index, value in ipairs(players) do
        if value ~= source then
            local targetCoords <const> = GetEntityCoords(GetPlayerPed(value))
            local distance <const> = #(doctorCoords - targetCoords)
            if distance <= 3.0 then
                return value
            end
        end
    end
    return nil
end


--* OPEN STORAGE
RegisterNetEvent("vorp_medic:Server:OpenStorage", function(key)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    if not hasJob(User) then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotADoctor, 5000)
    end

    if not isOnDuty(_source) then
        return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000)
    end

    local prefix = "vorp_medic_storage_" .. key
    if Config.ShareStorage then
        prefix = "vorp_medic_storage"
    end

    local storageName <const> = Config.Storage[key].Name
    local storageLimit <const> = Config.Storage[key].Limit
    registerStorage(prefix, storageName, storageLimit)
    Inv:openInventory(_source, prefix)
end)

--* CLEANUP
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for key, value in pairs(Config.Storage) do
        local prefix = "vorp_medic_storage_" .. key
        if Config.ShareStorage then
            prefix = "vorp_medic_storage"
        end
        Inv:removeInventory(prefix)
    end

    local players <const> = GetPlayers()
    for i = 1, #players do
        local _source <const> = players[i]
        Player(_source).state:set('isMedicDuty', nil, true)
    end
end)

--* REGISTER STORAGE
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for key, value in pairs(Config.Storage) do
        local prefix = "vorp_medic_storage_" .. key
        if Config.ShareStorage then
            prefix = "vorp_medic_storage"
        end
        registerStorage(prefix, value.Name, value.Limit)
    end
    if Config.DevMode then
        TriggerClientEvent("chat:addSuggestion", -1, "/" .. Config.DoctorMenuCommand, T.Menu.OpenDoctorMenu, {})
        RegisterCommand(Config.DoctorMenuCommand, openDoctorMenu, false)
    end
end)

-- vorpCharSelect
AddEventHandler("vorp:SelectedCharacter", function(source, char)
    if not Config.MedicJobs[char.job] then return end
    -- add chat suggestion
    TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.DoctorMenuCommand, T.Menu.OpenDoctorMenu, {})
    RegisterCommand(Config.DoctorMenuCommand, openDoctorMenu, false)
end)

--* HIRE PLAYER
RegisterNetEvent("vorp_medic:server:hirePlayer", function(id, job)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    if not hasJob(User) then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotADoctor, 5000)
    end

    local label <const> = Config.JobLabels[job]
    if not label then return print(T.Jobs.Nojoblabel) end

    local target <const> = id
    local targetUser <const> = Core.getUser(target)
    if not targetUser then return Core.NotifyObjective(_source, T.Player.NoPlayerFound, 5000) end

    local targetCharacter <const> = targetUser.getUsedCharacter
    local targetJob <const> = targetCharacter.job
    if job == targetJob then
        return Core.NotifyObjective(_source, T.Player.PlayeAlreadyHired .. label, 5000)
    end

    if not isPlayerNear(_source, target) then
        return Core.NotifyObjective(_source, T.Player.NotNear, 5000)
    end

    targetCharacter.setJob(job, true)
    targetCharacter.setJobLabel(label, true)

    Core.NotifyObjective(target, T.Player.HireedPlayer .. label, 5000)
    Core.NotifyObjective(_source, T.Menu.HirePlayer, 5000)

    TriggerClientEvent("chat:addSuggestion", _source, "/" .. Config.DoctorMenuCommand, T.Menu.OpenDoctorMenu, {})
    RegisterCommand(Config.DoctorMenuCommand, openDoctorMenu, false)

    TriggerClientEvent("vorp_medic:Client:JobUpdate", target)
end)

--* FIRE PLAYER
RegisterNetEvent("vorp_medic:server:firePlayer", function(id)
    local _source <const> = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    if not hasJob(user) then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotADoctor, 5000)
    end

    local target <const> = id
    local targetUser <const> = Core.getUser(target)
    if not targetUser then return Core.NotifyObjective(_source, T.Player.NoPlayerFound, 5000) end

    local targetCharacter <const> = targetUser.getUsedCharacter
    local targetJob <const> = targetCharacter.job
    if not Config.MedicJobs[targetJob] then
        return Core.NotifyObjective(_source, T.Player.CantFirenotHired, 5000)
    end

    targetCharacter.setJob("unemployed", true)
    targetCharacter.setJobLabel("Unemployed", true)

    Core.NotifyObjective(target, T.Player.BeenFireed, 5000)
    Core.NotifyObjective(_source, T.Player.FiredPlayer, 5000)

    if isOnDuty(target) then
        Player(target).state:set('isMedicDuty', nil, true)
    end

    TriggerClientEvent("vorp_medic:Client:JobUpdate", target)
end)



--* CHECK IF PLAYER IS ON DUTY
Core.Callback.Register("vorp_medic:server:checkDuty", function(source, CB, args)
    local user <const> = Core.getUser(source)
    if not user then return end

    if not hasJob(user) then
        return CB(false)
    end

    if not isOnDuty(source) then
        if not JobsToAlert[source] then
            JobsToAlert[source] = true
        end
        Player(source).state:set('isMedicDuty', true, true)
        return CB(true)
    end

    if JobsToAlert[source] then
        JobsToAlert[source] = nil
    end
    Player(source).state:set('isMedicDuty', false, true)
    return CB(false)
end)



--* ON PLAYER JOB CHANGE
AddEventHandler("vorp:playerJobChange", function(source, new, old)
    if not Config.MedicJobs[new] then return end
    TriggerClientEvent("vorp_medic:Client:JobUpdate", source)
end)

CreateThread(function()
    for key, value in pairs(Config.Items) do
        Inv:registerUsableItem(key, function()
            local _source <const> = source
            local user <const> = Core.getUser(_source)
            if not user then return end

            if not hasJob(user) then
                return Core.NotifyObjective(_source, T.Jobs.YouAreNotADoctor, 5000)
            end

            if not isOnDuty(_source) then
                return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000)
            end

            local hasItem <const> = Inv:getItem(_source, key)
            if not hasItem then return end

            local item <const> = key

            Inv:subItem(_source, key, 1)
            if value.revive then
                local closestPlayer <const> = getClosestPlayer(_source)
                if not closestPlayer then return Core.NotifyObjective(_source, T.Player.NoPlayerFoundToRevive, 5000) end 
                Core.Player.Revive(tonumber(closestPlayer))
                TriggerClientEvent("vorp_medic:Client:ReviveAnim", _source)
            else
                local closestPlayer <const> = getClosestPlayer(_source)
                if not closestPlayer then return Core.NotifyObjective(_source, T.Player.NoPlayerFoundToRevive, 5000) end 
                TriggerClientEvent("vorp_medic:Client:HealAnim", _source)
                TriggerClientEvent("vorp_medic:Client:HealPlayer", tonumber(closestPlayer), value.health, value.stamina)
            end
        end)
    end
end)

--* ALERTS

local function isDoctorOnCall(source)
    if not next(PlayersAlerts) then return false, 0 end

    for key, value in pairs(PlayersAlerts) do
        if value == source then
            return true, value
        end
    end
    return false, 0
end

local function getPlayerFromCall(source)
    for key, value in pairs(PlayersAlerts) do
        if value == source then
            return key
        end
    end
    return 0
end

RegisterCommand("alertDoctor", function(source, args)
    if PlayersAlerts[source] then
        return Core.NotifyObjective(source, T.Error.AlreadyAlertedDoctors, 5000) 
    end

    if not next(JobsToAlert) then
        return Core.NotifyObjective(source, T.Error.NoDoctorsAvailable, 5000) 
    end

    if Config.AllowOnlyDeadToAlert then
        local Character = Core.getUser(source).getUsedCharacter
        local dead      = Character.isdead
        if not dead then return Core.NotifyObjective(source, T.Error.NotDeadCantAlert, 5000) 
        end
    end

    local sourcePlayer <const> = GetPlayerPed(source)
    local sourceCoords <const> = GetEntityCoords(sourcePlayer)
    local closestDistance      = math.huge
    local closestDoctor        = nil

    for key, _ in pairs(JobsToAlert) do
        local player <const> = GetPlayerPed(key)
        local playerCoords <const> = GetEntityCoords(player)
        local distance <const> = #(sourceCoords - playerCoords)
        local isOnCall <const>, _ <const> = isDoctorOnCall(key)
        if not isOnCall then
            if distance < closestDistance then
                closestDistance = distance
                closestDoctor = key
            end
        end
    end

    if not closestDoctor then
        return Core.NotifyObjective(source, T.Error.NoDoctorsAvailable, 5000) 
    end

    Core.NotifyObjective(closestDoctor, T.Alert.PlayerNeedsHelp, 5000) 
    TriggerClientEvent("vorp_medic:Client:AlertDoctor", closestDoctor, sourceCoords)
    Core.NotifyObjective(source, T.Alert.DoctorsAlerted, 5000) 
    PlayersAlerts[source] = closestDoctor
end, false)

--cancel alert for players
RegisterCommand("cancelalert", function(source, args)
    if not PlayersAlerts[source] then
        return Core.NotifyObjective(source, T.Error.NoAlertToCancel, 5000) 
    end

    local isOnCall <const>, doctor <const> = isDoctorOnCall(source)
    if isOnCall and doctor > 0 then
        TriggerClientEvent("vorp_medic:Client:RemoveBlip", doctor)
        Core.NotifyObjective(doctor, T.Alert.AlertCanceledByPlayer, 5000) 
    end

    PlayersAlerts[source] = nil
    Core.NotifyObjective(source, T.Alert.AlertCanceled, 5000) 
end, false)


-- for doctors to finish alert
RegisterCommand("finishAlert", function(source, args)
    local _source <const> = source

    local hasJobs <const> = hasJob(Core.getUser(_source))
    if not hasJobs then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotADoctor, 5000) 
    end

    local isDuty <const> = isOnDuty(_source)
    if not isDuty then
        return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000) 
    end

    local isOnCall <const>, doctor <const> = isDoctorOnCall(_source)
    if isOnCall and doctor > 0 then
        TriggerClientEvent("vorp_medic:Client:RemoveBlip", _source)
        Core.NotifyObjective(_source, T.Alert.AlertCanceled, 5000) 
    else
        Core.NotifyObjective(_source, T.Error.NotOnCall, 5000) 
    end

    local player <const> = getPlayerFromCall(_source)
    if player > 0 then
        Core.NotifyObjective(player, T.Alert.AlertCanceledByDoctor, 5000) 
        PlayersAlerts[player] = nil
    end
end, false)


--* ON PLAYER DROP
AddEventHandler("playerDropped", function()
    local _source = source

    if Player(_source).state.isMedicDuty then
        Player(_source).state:set('isMedicDuty', nil, true)
    end

    if JobsToAlert[_source] then
        JobsToAlert[_source] = nil
    end

    local isOnCall <const>, doctor <const> = isDoctorOnCall(_source)
    if isOnCall and doctor > 0 then
        TriggerClientEvent("vorp_medic:Client:RemoveBlip", doctor)
        Core.NotifyObjective(doctor, T.Alert.PlayerDisconnectedAlertCanceled, 5000) 
    end

    if PlayersAlerts[_source] then
        PlayersAlerts[_source] = nil
    end
end)