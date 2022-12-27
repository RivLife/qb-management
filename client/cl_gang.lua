local QBCore = exports['qb-core']:GetCoreObject()
local PlayerGang = QBCore.Functions.GetPlayerData().gang
local shownGangMenu = false
local DynamicMenuItems = {}

-- UTIL
local function CloseMenuFull()
    lib.hideContext()
    lib.hideTextUI()
    shownGangMenu = false
end

local function AddGangMenuItem(data, id)
    local menuID = id or #DynamicMenuItems + 1
    DynamicMenuItems[menuID] = deepcopy(data)
    return menuID
end

exports("AddGangMenuItem", AddGangMenuItem)

local function RemoveGangMenuItem(id)
    DynamicMenuItems[id] = nil
end

exports("RemoveGangMenuItem", RemoveGangMenuItem)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    PlayerGang = QBCore.Functions.GetPlayerData().gang
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerGang = QBCore.Functions.GetPlayerData().gang
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    PlayerGang = GangInfo
end)

RegisterNetEvent('qb-gangmenu:client:Stash', function()
    exports.ox_inventory:openInventory('stash', 'gang_' .. PlayerGang.name)
end)

RegisterNetEvent('qb-gangmenu:client:Warbobe', function()
    TriggerEvent('qb-clothing:client:openOutfitMenu')
end)

RegisterNetEvent('qb-gangmenu:client:OpenMenu', function()
    if not PlayerGang.name or not PlayerGang.isboss then return end

    shownGangMenu = true

    local gangMenu = {
        {
            title = 'Gestion des effectifs',
            icon = 'fa-solid fa-list',
            description = 'Gérer les membres',
            event = 'qb-gangmenu:client:ManageGang'
        },
        {
            title = 'Recruter',
            icon = 'fa-solid fa-hand-holding',
            description = 'Recruter une personne',
            event = 'qb-gangmenu:client:HireMembers'
        },
        {
            title = 'Accès stockage',
            icon = 'fa-solid fa-box-open',
            description = 'Accéder au stockage',
            event = 'qb-gangmenu:client:Stash'
        },
        {
            title = 'Outfits',
            icon = 'fa-solid fa-shirt',
            description = 'Change Clothes',
            event = 'qb-gangmenu:client:Warbobe'
        },
        {
            title = 'Gestion des fonds',
            icon = 'fa-solid fa-sack-dollar',
            description = 'Vérifiez votre trésorerie',
            event = 'qb-gangmenu:client:SocietyMenu'
        }
    }

    for _, v in pairs(DynamicMenuItems) do
        gangMenu[#gangMenu + 1] = v
    end

    lib.registerContext({
        id = 'qb_management_open_gangMenu',
        title = "Gestion - " .. string.upper(PlayerGang.label),
        options = gangMenu
    })

    lib.showContext('qb_management_open_gangMenu')
end)

RegisterNetEvent('qb-gangmenu:client:ManageGang', function()
    local GangMembersMenu = {}

    QBCore.Functions.TriggerCallback('qb-gangmenu:server:GetEmployees', function(cb)
        for _, v in pairs(cb) do
            GangMembersMenu[#GangMembersMenu + 1] = {
                title = v.name,
                description = v.grade.name,
                event = 'qb-gangmenu:lient:ManageMember',
                args = {
                    player = v,
                    work = PlayerGang
                }
            }
        end

        GangMembersMenu[#GangMembersMenu + 1] = {
            title = "Retour",
            icon = 'fa-solid fa-angle-left',
            event = 'qb-gangmenu:client:OpenMenu'
        }

        lib.registerContext({
            id = 'qb_management_open_gangManage',
            title = "Gestion des membres - " .. string.upper(PlayerGang.label),
            options = GangMembersMenu
        })

        lib.showContext('qb_management_open_gangManage')
    end, PlayerGang.name)
end)

RegisterNetEvent('qb-gangmenu:lient:ManageMember', function(data)
    local MemberMenu = {}

    for k, v in pairs(QBCore.Shared.Gangs[data.work.name].grades) do
        MemberMenu[#MemberMenu + 1] = {
            title = v.name,
            description = "Grade: " .. k,
            serverEvent = 'qb-gangmenu:server:GradeUpdate',
            args = {
                cid = data.player.empSource,
                grade = tonumber(k),
                gradename = v.name
            }
        }
    end

    MemberMenu[#MemberMenu + 1] = {
        title = "Licencier",
        icon = 'fa-solid fa-user-large-slash',
        serverEvent = 'qb-gangmenu:server:FireMember',
        args = data.player.empSource
    }

    MemberMenu[#MemberMenu + 1] = {
        title = "Retour",
        icon = 'fa-solid fa-angle-left',
        event = 'qb-gangmenu:client:ManageGang'
    }

    lib.registerContext({
        id = 'qb_management_open_gangMember',
        title = "Gérer " .. data.player.name .. " - " .. string.upper(PlayerGang.label),
        options = MemberMenu
    })

    lib.showContext('qb_management_open_gangMember')
end)

RegisterNetEvent('qb-gangmenu:client:HireMembers', function()
    local HireMembersMenu = {}

    QBCore.Functions.TriggerCallback('qb-gangmenu:getplayers', function(players)
        for _, v in pairs(players) do
            if v and v ~= cache.playerId then
                HireMembersMenu[#HireMembersMenu + 1] = {
                    title = v.name,
                    description = "ID: " .. v.citizenid .. " - ID: " .. v.sourceplayer,
                    serverEvent = 'qb-gangmenu:server:HireMember',
                    args = v.sourceplayer
                }
            end
        end

        HireMembersMenu[#HireMembersMenu + 1] = {
            title = "Retour",
            icon = 'fa-solid fa-angle-left',
            event = 'qb-gangmenu:client:OpenMenu'
        }

        lib.registerContext({
            id = 'qb_management_open_gangHire',
            title = "Recrutement - " .. string.upper(PlayerGang.label),
            options = HireMembersMenu
        })

        lib.showContext('qb_management_open_gangHire')
    end)
end)

RegisterNetEvent('qb-gangmenu:client:SocietyMenu', function()
    QBCore.Functions.TriggerCallback('qb-gangmenu:server:GetAccount', function(amount)
        local SocietyMenu = {
            {
                title = "Dépôt",
                icon = 'fa-solid fa-money-bill-transfer',
                description = "Déposer de l'argent",
                event = 'qb-gangmenu:client:SocietyDeposit',
                args = comma_value(amount)
            },
            {
                title = "Retrait",
                icon = 'fa-solid fa-money-bill-transfer',
                description = "Retier de l'argent",
                event = 'qb-gangmenu:client:SocietyWithdraw',
                args = comma_value(amount)
            },
            {
                title = "Retour",
                icon = 'fa-solid fa-angle-left',
                event = 'qb-gangmenu:client:OpenMenu'
            }
        }

        lib.registerContext({
            id = 'qb_management_open_gangSociety',
            title = "Coffre: $" .. comma_value(amount) .. " - " .. string.upper(PlayerGang.label),
            options = SocietyMenu
        })

        lib.showContext('qb_management_open_gangSociety')
    end, PlayerGang.name)
end)

RegisterNetEvent('qb-gangmenu:client:SocietyDeposit', function(money)
    local deposit = lib.inputDialog("Déposer de l'argent", {
        {
            type = 'number',
            label = "Argent disponible",
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

    TriggerServerEvent('qb-gangmenu:server:depositMoney', depositAmount)
end)

RegisterNetEvent('qb-gangmenu:client:SocietyWithdraw', function(money)
    local withdraw = lib.inputDialog("Déposer de l'argent", {
        {
            type = 'input',
            label = "Argent disponible",
            disabled = true,
            default = money
        },
        {
            type = 'input',
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

    TriggerServerEvent('qb-gangmenu:server:withdrawMoney', withdrawAmount)
end)

-- MAIN THREAD
CreateThread(function()
    if Config.UseTarget then
        for gang, zones in pairs(Config.GangMenuZones) do
            for i = 1, #zones do
                local data = zones[i]
                exports.ox_target:addBoxZone({
                    coords = data.coords,
                    size = data.size,
                    rotation = data.rotation,
                    options = {
                        {
                            name = 'gang_menu',
                            event = 'qb-gangmenu:client:OpenMenu',
                            icon = "fa-solid fa-right-to-bracket",
                            label = "Gestion",
                            canInteract = function()
                                return gang == PlayerGang.name and PlayerGang.isboss
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
            local nearGangmenu = false
            wait = 1000

            if PlayerGang then
                wait = 100
                for k, v in pairs(Config.GangMenus) do
                    for _, coords in pairs(v) do
                        if k == PlayerGang.name and PlayerGang.isboss then
                            if #(pos - coords) <= 1.5 then
                                nearGangmenu = true

                                if not shownGangMenu then
                                    lib.showTextUI("[E] - Open Gang Management")
                                    shownGangMenu = true
                                end

                                wait = 0

                                if IsControlJustReleased(0, 38) then
                                    lib.hideTextUI()
                                    TriggerEvent('qb-gangmenu:client:OpenMenu')
                                end
                            end
                        end
                    end
                end

                if not nearGangmenu then
                    wait = 1000
                    if shownGangMenu then
                        CloseMenuFull()
                        shownGangMenu = false
                    end
                end
            end

            Wait(wait)
        end
    end
end)
