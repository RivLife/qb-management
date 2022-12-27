local QBCore = exports['qb-core']:GetCoreObject()
local GangAccounts = {}

local function GetGangAccount(account)
	return GangAccounts[account] or 0
end

exports('GetGangAccount', GetGangAccount)

local function AddGangMoney(account, amount)
	if not GangAccounts[account] then
		GangAccounts[account] = 0
	end

	GangAccounts[account] = GangAccounts[account] + amount
	MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount', {
		['job_name'] = account,
		['amount'] = GangAccounts[account],
		['type'] = 'gang'
	})
end

exports('AddGangMoney', AddGangMoney)

local function RemoveGangMoney(account, amount)
	local isRemoved = false
	if amount > 0 then
		if not GangAccounts[account] then
			GangAccounts[account] = 0
		end

		if GangAccounts[account] >= amount then
			GangAccounts[account] = GangAccounts[account] - amount
			isRemoved = true
		end

		MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = ?', { GangAccounts[account], account, 'gang' })
	end
	return isRemoved
end

exports('RemoveGangMoney', RemoveGangMoney)

MySQL.ready(function ()
	local gangmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = ?', {'gang'})
	if not gangmenu then return end

	for i = 1, #gangmenu do
		local v = gangmenu[i]
		GangAccounts[v.job_name] = v.amount
	end
end)

RegisterNetEvent("qb-gangmenu:server:withdrawMoney", function(amount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'withdrawMoney Exploiting') return end

	local gang = Player.PlayerData.gang.name
	if RemoveGangMoney(gang, amount) then
		Player.Functions.AddMoney("cash", amount, 'Gang menu withdraw')
		TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Withdraw Money', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully withdrew $' .. amount .. ' (' .. gang .. ')', false)
		TriggerClientEvent('QBCore:Notify', src, "Vous avez retiré : $" ..amount, "success")
	else
		TriggerClientEvent('QBCore:Notify', src, "Vous n’avez pas assez d’argent sur le compte!", "error")
	end

	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

RegisterNetEvent("qb-gangmenu:server:depositMoney", function(amount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'depositMoney Exploiting') return end

	if Player.Functions.RemoveMoney("cash", amount) then
		local gang = Player.PlayerData.gang.name
		AddGangMoney(gang, amount)
		TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Deposit Money', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully deposited $' .. amount .. ' (' .. gang .. ')', false)
		TriggerClientEvent('QBCore:Notify', src, "Vous avez déposé: $" ..amount, "success")
	else
		TriggerClientEvent('QBCore:Notify', src, "Vous n’avez pas assez d’argent à ajouter!", "error")
	end

	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

QBCore.Functions.CreateCallback('qb-gangmenu:server:GetAccount', function(_, cb, gangName)
	cb(GetGangAccount(gangName))
end)

-- Get Employees
QBCore.Functions.CreateCallback('qb-gangmenu:server:GetEmployees', function(source, cb, gangname)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'GetEmployees Exploiting') return end

	local employees = {}
	local players = MySQL.query.await("SELECT * FROM `players` WHERE `gang` LIKE '%".. gangname .."%'", {})
	if players then
		for _, value in pairs(players) do
			local isOnline = QBCore.Functions.GetPlayerByCitizenId(value.citizenid)

			if isOnline then
				employees[#employees + 1] = {
				empSource = isOnline.PlayerData.citizenid,
				grade = isOnline.PlayerData.gang.grade,
				isboss = isOnline.PlayerData.gang.isboss,
				name = '🟢' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
				}
			else
				employees[#employees + 1] = {
				empSource = value.citizenid,
				grade =  json.decode(value.gang).grade,
				isboss = json.decode(value.gang).isboss,
				name = '❌' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
				}
			end
		end
	end
	cb(employees)
end)

-- Grade Change
RegisterNetEvent('qb-gangmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(data.cid)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'GradeUpdate Exploiting') return end
	if data.grade > Player.PlayerData.gang.grade.level then TriggerClientEvent('QBCore:Notify', src, "Vous ne pouvez pas promouvoir à ce grade", "error") return end

	if Employee then
		if Employee.Functions.SetGang(Player.PlayerData.gang.name, data.grade) then
			TriggerClientEvent('QBCore:Notify', src, "Promu avec succès!", "success")
			TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, "Vous avez été promo en tant que " ..data.gradename..".", "success")
		else
			TriggerClientEvent('QBCore:Notify', src, "Le grade n'existe pas.", "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', src, "Citoyen hors ligne", "error")
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Fire Member
RegisterNetEvent('qb-gangmenu:server:FireMember', function(target)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(target)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'FireEmployee Exploiting') return end

	if Employee then
		if target ~= Player.PlayerData.citizenid then
			if Employee.PlayerData.gang.grade.level > Player.PlayerData.gang.grade.level then TriggerClientEvent('QBCore:Notify', src, "You cannot fire this citizen!", "error") return end
			if Employee.Functions.SetGang("none", '0') then
				TriggerEvent("qb-log:server:CreateLog", "gangmenu", "Gang Fire", "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
				TriggerClientEvent('QBCore:Notify', src, "Membre exclu!", "success")
				TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source , "Vous avez été exclu", "error")
			else
				TriggerClientEvent('QBCore:Notify', src, "Error.", "error")
			end
		else
			TriggerClientEvent('QBCore:Notify', src, "Vous ne pouvez pas vous exclure vous même", "error")
		end
	else
		local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', {target})
		if player[1] then
			Employee = player[1]
			Employee.gang = json.decode(Employee.gang)
			if Employee.gang.grade.level > Player.PlayerData.job.grade.level then TriggerClientEvent('QBCore:Notify', src, "Vous ne pouvez pas exclure cette personne", "error") return end
			local gang = {}
			gang.name = "none"
			gang.label = "Aucune affiliation"
			gang.payment = 0
			gang.onduty = true
			gang.isboss = false
			gang.grade = {}
			gang.grade.name = nil
			gang.grade.level = 0
			MySQL.update('UPDATE players SET gang = ? WHERE citizenid = ?', {json.encode(gang), target})
			TriggerClientEvent('QBCore:Notify', src, "Membre exclu", "success")
			TriggerEvent("qb-log:server:CreateLog", "gangmenu", "Gang Fire", "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
		else
			TriggerClientEvent('QBCore:Notify', src, "Citoyen hors ligne.", "error")
		end
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Recruit Player
RegisterNetEvent('qb-gangmenu:server:HireMember', function(recruit)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Target = QBCore.Functions.GetPlayer(recruit)

	if not Player.PlayerData.gang.isboss then ExploitBan(src, 'HireEmployee Exploiting') return end

	if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
		TriggerClientEvent('QBCore:Notify', src, "Vous avez recruter " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. " en tant que " .. Player.PlayerData.gang.label .. "", "success")
		TriggerClientEvent('QBCore:Notify', Target.PlayerData.source , "Vous avez été recruter en tant que " .. Player.PlayerData.gang.label .. "", "success")
		TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Recruit', 'yellow', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. ' successfully recruited ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Get closest player sv
QBCore.Functions.CreateCallback('qb-gangmenu:getplayers', function(source, cb)
	local src = source
	local players = {}
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	for _, v in pairs(QBCore.Functions.GetPlayers()) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		if PlayerPed ~= targetped and dist < 10 then
			local ped = QBCore.Functions.GetPlayer(v)
			players[#players + 1] = {
				id = v,
				coords = GetEntityCoords(targetped),
				name = ped.PlayerData.charinfo.firstname .. " " .. ped.PlayerData.charinfo.lastname,
				citizenid = ped.PlayerData.citizenid,
				sources = GetPlayerPed(ped.PlayerData.source),
				sourceplayer = ped.PlayerData.source
			}
		end
	end

	table.sort(players, function(a, b)
		return a.name < b.name
	end)

	cb(players)
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName ~= 'ox_inventory' and resourceName ~= GetCurrentResourceName() then return end

	local data = Config.UseTarget and Config.GangMenuZones or Config.GangMenus
	for k in pairs(data) do
		exports.ox_inventory:RegisterStash('gang_' .. k, "Stash: " .. k, 100, 4000000, false)
	end
end)
