local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = QBCore.Functions.GetPlayerData().job
local shownBossMenu = false
local DynamicMenuItems = {}

-- UTIL
local function CloseMenuFull()
    lib.hideContext()
    lib.hideTextUI()
    shownBossMenu = false
end

local function AddBossMenuItem(data, id)
    local menuID = id or #DynamicMenuItems + 1
    DynamicMenuItems[menuID] = deepcopy(data)
    return menuID
end

exports("AddBossMenuItem", AddBossMenuItem)

local function RemoveBossMenuItem(id)
    DynamicMenuItems[id] = nil
end

exports("RemoveBossMenuItem", RemoveBossMenuItem)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    PlayerJob = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

RegisterNetEvent('qb-bossmenu:client:OpenMenu', function()
    if not PlayerJob.name or not PlayerJob.isboss then return end

    local bossMenu = {
        {
            title = "Gérer les employés",
            description = "Vérifiez votre liste d’employés",
            icon = 'fa-solid fa-list',
            event = 'qb-bossmenu:client:employeelist'
        },
        {
            title = "Embaucher des employés",
            description = "Embaucher des civils à proximité",
            icon = 'fa-solid fa-hand-holding',
            event = 'qb-bossmenu:client:HireMenu'
        },
        {
            title = "Accès au stockage",
            description = "Accéder au stockage",
            icon = 'fa-solid fa-box-open',
            event = 'qb-bossmenu:client:Stash'
        },
        {
            title = "Tenues",
            description = "Voir les tenues sauvegardées",
            icon = 'fa-solid fa-shirt',
            event = 'qb-bossmenu:client:Wardrobe'
        },
        {
            title = "Gestion des fonds",
            description = "Vérifiez les fonds de votre entreprise",
            icon = 'fa-solid fa-sack-dollar',
            event = 'qb-bossmenu:client:SocietyMenu'
        }
    }

    for _, v in pairs(DynamicMenuItems) do
        bossMenu[#bossMenu + 1] = v
    end

    lib.registerContext({
        id = 'qb_management_open_bossMenu',
        title = "Gestion - " .. string.upper(PlayerJob.label),
        options = bossMenu
    })
    lib.showContext('qb_management_open_bossMenu')
end)

RegisterNetEvent('qb-bossmenu:client:employeelist', function()
    local EmployeesMenu = {}

    QBCore.Functions.TriggerCallback('qb-bossmenu:server:GetEmployees', function(cb)
        for _, v in pairs(cb) do
            EmployeesMenu[#EmployeesMenu + 1] = {
                title = v.name,
                description = v.grade.name,
                event = 'qb-bossmenu:client:ManageEmployee',
                args = {
                    player = v,
                    work = PlayerJob
                }
            }
        end

        EmployeesMenu[#EmployeesMenu + 1] = {
            title = "Retour",
            icon = 'fa-solid fa-angle-left',
            event = 'qb-bossmenu:client:OpenMenu'
        }

        lib.registerContext({
            id = 'qb_management_open_bossManage',
            title = "Gestion employés - " .. string.upper(PlayerJob.label),
            options = EmployeesMenu
        })

        lib.showContext('qb_management_open_bossManage')
    end, PlayerJob.name)
end)

RegisterNetEvent('qb-bossmenu:client:ManageEmployee', function(data)
    local EmployeeMenu = {}

    for k, v in pairs(QBCore.Shared.Jobs[data.work.name].grades) do
        EmployeeMenu[#EmployeeMenu + 1] = {
            title = v.name,
            description = "Grade: " .. k,
            serverEvent = 'qb-bossmenu:server:GradeUpdate',
            args = {
                cid = data.player.empSource,
                grade = tonumber(k),
                gradename = v.name
            }
        }
    end

    EmployeeMenu[#EmployeeMenu + 1] = {
        title = "Licencier un employé",
        icon = 'fa-solid fa-user-large-slash',
        serverEvent = 'qb-bossmenu:server:FireEmployee',
        args = data.player.empSource
    }

    EmployeeMenu[#EmployeeMenu + 1] = {
        title = "Retour",
        icon = 'fa-solid fa-angle-left',
        event = 'qb-bossmenu:client:OpenMenu'
    }

    lib.registerContext({
        id = 'qb_management_open_bossMember',
        title = "Gérer " .. data.player.name .. " - " .. string.upper(PlayerJob.label),
        options = EmployeeMenu
    })

    lib.showContext('qb_management_open_bossMember')
end)

RegisterNetEvent('qb-bossmenu:client:Stash', function()
    exports.ox_inventory:openInventory('stash', 'boss_' .. PlayerJob.name)
end)

RegisterNetEvent('qb-bossmenu:client:Wardrobe', function()
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('qb-bossmenu:client:HireMenu', function()
    local HireMenu = {}

    QBCore.Functions.TriggerCallback('qb-bossmenu:getplayers', function(players)
        for _, v in pairs(players) do
            if v and v ~= cache.playerId then
                HireMenu[#HireMenu + 1] = {
                    title = v.name,
                    description = "ID: " .. v.citizenid .. " - ID: " .. v.sourceplayer,
                    serverEvent = 'qb-bossmenu:server:HireEmployee',
                    args = v.sourceplayer
                }
            end
        end

        HireMenu[#HireMenu + 1] = {
            title = "Retour",
            icon = 'fa-solid fa-angle-left',
            event = 'qb-bossmenu:client:OpenMenu'
        }

        lib.registerContext({
            id = 'qb_management_open_bossHire',
            title = "Embaucher - " .. string.upper(PlayerJob.label),
            options = HireMenu
        })

        lib.showContext('qb_management_open_bossHire')
    end)
end)

RegisterNetEvent('qb-bossmenu:client:SocietyMenu', function()
    QBCore.Functions.TriggerCallback('qb-bossmenu:server:GetAccount', function(amount)
        local SocietyMenu = {
            {
                title = "Dépôt",
                icon = 'fa-solid fa-money-bill-transfer',
                description = "Déposer des fonds sur le compte",
                event = 'qb-bossmenu:client:SocetyDeposit',
                args = comma_value(amount)
            },
            {
                title = "Retrait",
                icon = 'fa-solid fa-money-bill-transfer',
                description = "Retirer des fonds du compte",
                event = 'qb-bossmenu:client:SocetyWithDraw',
                args = comma_value(amount)
            },
            {
                title = "Return",
                icon = 'fa-solid fa-angle-left',
                event = 'qb-bossmenu:client:OpenMenu'
            }
        }

        lib.registerContext({
            id = 'qb_management_open_bossSociety',
            title = "Balance: $" .. comma_value(amount) .. " - " .. string.upper(PlayerJob.label),
            options = SocietyMenu
        })

        lib.showContext('qb_management_open_bossSociety')
    end, PlayerJob.name)
end)

RegisterNetEvent('qb-bossmenu:client:SocetyDeposit', function(money)
    local deposit = lib.inputDialog('Déposer des fonds', {
        {
            type = 'input',
            label = "Balance disponible",
            disabled = true,
            default = money
        },
        {
            type = 'number',
            label = "Montant"
        }
    })

    if not deposit then
        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    if not deposit[2] then
        lib.notify({
            description = 'La valeur du montant est manquante!',
            type = 'error'
        })

        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    local depositAmount = tonumber(deposit[2])

    if depositAmount <= 0 then
        lib.notify({
            description = 'Le montant doit être supérieur à zéro!',
            type = 'error'
        })

        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    TriggerServerEvent('qb-bossmenu:server:depositMoney', depositAmount)
end)

RegisterNetEvent('qb-bossmenu:client:SocetyWithDraw', function(money)
    local withdraw = lib.inputDialog("Retirer des fonds", {
        {
            type = 'input',
            label = "Balance disponible",
            disabled = true,
            default = money
        },
        {
            type = 'number',
            label = "Montant"
        }
    })

    if not withdraw then
        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    if not withdraw[2] then
        lib.notify({
            description = 'La valeur du montant est manquante!',
            type = 'error'
        })

        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    local withdrawAmount = tonumber(withdraw[2])

    if withdrawAmount > tonumber(money) then
        lib.notify({
            description = 'Vous ne pouvez pas retirer cette somme d’argent!',
            type = 'error'
        })

        TriggerEvent('qb-gangmenu:client:SocietyMenu')
        return
    end

    TriggerServerEvent('qb-bossmenu:server:withdrawMoney', withdrawAmount)
end)

-- MAIN THREAD
CreateThread(function()
    if Config.UseTarget then
        for job, zones in pairs(Config.BossMenuZones) do
            for i = 1, #zones do
                local data = zones[i]
                exports.ox_target:addBoxZone({
                    coords = data.coords,
                    size = data.size,
                    rotation = data.rotation,
                    options = {
                        {
                            name = 'boss_menu',
                            event = 'qb-bossmenu:client:OpenMenu',
                            icon = "fa-solid fa-right-to-bracket",
                            label = "Gestion entreprise",
                            canInteract = function()
                                return job == PlayerJob.name and PlayerJob.isboss
                            end
                        }
                    }
                })
            end
        end
    else
        local wait
        while true do
            local pos = GetEntityCoords(cache.ped)
            local nearBossmenu = false
            wait = 1000

            if PlayerJob then
                wait = 100
                for k, v in pairs(Config.BossMenus) do
                    for _, coords in pairs(v) do
                        if k == PlayerJob.name and PlayerJob.isboss then
                            if #(pos - coords) <= 1.5 then
                                nearBossmenu = true

                                if not shownBossMenu then
                                    lib.showTextUI("[E] - Open Job Management")
                                    shownBossMenu = true
                                end

                                wait = 0

                                if IsControlJustReleased(0, 38) then
                                    lib.hideTextUI()
                                    TriggerEvent('qb-bossmenu:client:OpenMenu')
                                end
                            end
                        end
                    end
                end

                if not nearBossmenu then
                    wait = 1000
                    if shownBossMenu then
                        CloseMenuFull()
                        shownBossMenu = false
                    end
                end
            end

            Wait(wait)
        end
    end
end)
