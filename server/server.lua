RegisterNetEvent('spooner:init')
RegisterNetEvent('spooner:toggle')
RegisterNetEvent('spooner:openDatabaseMenu')
RegisterNetEvent('spooner:openSaveDbMenu')
RegisterNetEvent('spooner:requestServerPeds')

local ServerPedsCache = nil
local LastServerPedsScan = 0
local ServerPedsScanCacheTtl = 60

local PedNamePatterns = {
	'^cs_',
	'^mp_',
	'^player_',
	'^a_c_',
	'^a_m_',
	'^a_f_',
	'^u_m_',
	'^u_f_',
	'^g_m_',
	'^g_f_',
	'^s_m_',
	'^s_f_',
	'^re_',
	'^rc_',
	'^ninfa_',
}

local DefaultPedResourcePathHints = {
	'[peds]',
	'peds',
	'ped',
	'metapeds',
	'custompeds',
	'custom-peds',
	'personagens',
	'personagem',
	'characters',
	'character',
	'npcs',
	'npc',
}

local DefaultPedScanDirectories = {
	'stream',
	'data_files',
	'data',
	'metapeds',
}

local function LooksLikePedName(name)
	if type(name) ~= 'string' then return false end

	local lower = name:lower()
	for _, pattern in ipairs(PedNamePatterns) do
		if lower:match(pattern) then return true end
	end

	return false
end

local function LooksLikePedAssetName(name)
	if type(name) ~= 'string' then return false end

	local lower = name:lower()
	return lower:match('_[fm]s%d_') ~= nil
		or lower:match('_ff%d_') ~= nil
		or lower:match('_fr%d_') ~= nil
		or lower:match('_mr%d_') ~= nil
		or lower:match('_c%d_') ~= nil
		or lower:match('_merge') ~= nil
		or lower:find('_hair_', 1, true) ~= nil
		or lower:find('_head_', 1, true) ~= nil
		or lower:find('_boot_', 1, true) ~= nil
		or lower:find('_boots_', 1, true) ~= nil
		or lower:find('_shirt_', 1, true) ~= nil
		or lower:find('_skirt_', 1, true) ~= nil
		or lower:find('_coat_', 1, true) ~= nil
		or lower:find('_pants_', 1, true) ~= nil
		or lower:find('_pant_', 1, true) ~= nil
		or lower:find('_vest_', 1, true) ~= nil
		or lower:find('_glove', 1, true) ~= nil
		or lower:find('_hat_', 1, true) ~= nil
		or lower:find('_nude_', 1, true) ~= nil
		or lower:find('_teeth_', 1, true) ~= nil
		or lower:find('_eyes_', 1, true) ~= nil
		or lower:find('_eyebrow', 1, true) ~= nil
		or lower:find('_eyelash', 1, true) ~= nil
		or lower:find('_makeup_', 1, true) ~= nil
		or lower:find('_apron_', 1, true) ~= nil
		or lower:find('_accs_', 1, true) ~= nil
end

local function GetConfiguredList(configKey, fallback)
	if Config and type(Config[configKey]) == 'table' then
		return Config[configKey]
	end

	return fallback
end

local function PathHasPedHint(path)
	if type(path) ~= 'string' or path == '' then return false end

	local normalized = path:gsub('\\', '/'):lower()
	for _, hint in ipairs(GetConfiguredList('PedResourcePathHints', DefaultPedResourcePathHints)) do
		if type(hint) == 'string' and hint ~= '' then
			local cleanHint = hint:gsub('\\', '/'):lower()
			local escaped = cleanHint:gsub('([^%w])', '%%%1')
			if normalized:match('(^|/)' .. escaped .. '(/|$)') then
				return true
			end
		end
	end

	return false
end

local function LooksLikePedResource(resourceName)
	if type(resourceName) ~= 'string' or resourceName == '' then return false end

	if LooksLikePedName(resourceName) then return true end

	if GetResourcePath then
		local path = GetResourcePath(resourceName)
		if type(path) == 'string' and path ~= '' then
			if PathHasPedHint(path) then
				return true
			end
		end
	end

	return false
end

local function NormalizePedCandidate(name)
	if type(name) ~= 'string' then return nil end

	local normalized = name:gsub('\\', '/'):match('^%s*(.-)%s*$') or ''
	if normalized == '' then return nil end
	if normalized:find('*', 1, true) or normalized:find('?', 1, true) then return nil end

	normalized = normalized:match('([^/]+)$') or normalized
	normalized = normalized:gsub('%.ymt%.pso%.xml$', '')
		:gsub('%.ymt%.xml$', '')
		:gsub('%.xml$', '')
		:gsub('%.ymt$', '')
		:gsub('%.yft$', '')
		:gsub('%.ydd$', '')
		:gsub('%.ytd$', '')
		:lower()

	if normalized == ''
		or normalized == 'fxmanifest'
		or normalized == '__resource'
		or normalized == 'metapeds'
		or normalized == 'expression_sets' then
		return nil
	end

	if not normalized:match('^[a-z0-9_]+$') then return nil end

	return normalized
end

local function AddPedCandidate(list, seen, name)
	local normalized = NormalizePedCandidate(name)
	if not normalized or seen[normalized] then return false end

	seen[normalized] = true
	table.insert(list, normalized)
	return true
end

local function ExtractPedNamesFromResourceFile(list, seen, resName, fileName)
	if type(fileName) ~= 'string' or fileName == '' then return end
	if fileName:find('*', 1, true) or fileName:find('?', 1, true) then return end
	if not fileName:lower():match('%.ymt$') then return end

	local content = LoadResourceFile(resName, fileName)
	if type(content) ~= 'string' or content == '' then return end

	for token in content:gmatch('[A-Za-z0-9_]+') do
		local normalized = NormalizePedCandidate(token)
		if normalized and LooksLikePedName(normalized) and not LooksLikePedAssetName(normalized) then
			AddPedCandidate(list, seen, normalized)
		end
	end
end

local function AddPedFilesFromResource(list, seen, resName)
	if type(resName) ~= 'string' or resName == '' then return end

	local isPedResource = LooksLikePedResource(resName)
	local normalizedResourceName = NormalizePedCandidate(resName)
	if normalizedResourceName
		and LooksLikePedName(normalizedResourceName)
		and not LooksLikePedAssetName(normalizedResourceName) then
		AddPedCandidate(list, seen, normalizedResourceName)
	end

	local function addFromPath(path)
		if type(path) ~= 'string' then return end

		local lower = path:lower()
		if not lower:match('%.ymt$') then return end

		local candidate = NormalizePedCandidate(path)
		if candidate
			and (isPedResource or LooksLikePedName(candidate))
			and not LooksLikePedAssetName(candidate) then
			AddPedCandidate(list, seen, candidate)
		end

		ExtractPedNamesFromResourceFile(list, seen, resName, path)
	end

	for _, key in ipairs({ 'files', 'file', 'data_file', 'data_file_extra' }) do
		local count = GetNumResourceMetadata(resName, key) or 0
		for i = 0, count - 1 do
			addFromPath(GetResourceMetadata(resName, key, i))
		end
	end

	ExtractPedNamesFromResourceFile(list, seen, resName, 'data_files/metapeds.ymt')

	if GetResourcePath and io and io.popen then
		local resPath = GetResourcePath(resName)
		if type(resPath) == 'string' and resPath ~= '' then
			local basePath = resPath:gsub('/', '\\')
			for _, dirName in ipairs(GetConfiguredList('PedScanDirectories', DefaultPedScanDirectories)) do
				if type(dirName) == 'string' and dirName ~= '' and not dirName:find('%.%.', 1, true) then
					local scanDir = basePath .. '\\' .. dirName:gsub('/', '\\')
					local escapedScanDir = scanDir:gsub("'", "''")
					local cmd = ([[powershell -NoProfile -Command "if (Test-Path -LiteralPath '%s') { Get-ChildItem -LiteralPath '%s' -Recurse -File | Where-Object { $_.Extension -ieq '.ymt' } | ForEach-Object { $_.Name } }"]]):format(escapedScanDir, escapedScanDir)
					local proc = io.popen(cmd)
					if proc then
						for fileName in proc:lines() do
							addFromPath(fileName)
						end
						proc:close()
					end
				end
			end
		end
	end
end

local function ScanServerPeds(force)
	local now = os.time()
	if not force and ServerPedsCache and (now - LastServerPedsScan) < ServerPedsScanCacheTtl then
		return ServerPedsCache
	end

	local peds = {}
	local seen = {}

	if Config then
		for _, cfgKey in ipairs({ 'CustomPeds', 'ServerPeds', 'ExtraPeds' }) do
			local cfgPeds = Config[cfgKey]
			if type(cfgPeds) == 'table' then
				for _, pedName in ipairs(cfgPeds) do
					AddPedCandidate(peds, seen, pedName)
				end
			end
		end
	end

	local numResources = GetNumResources and GetNumResources() or 0
	for i = 0, numResources - 1 do
		local resName = GetResourceByFindIndex(i)
		if resName and GetResourceState(resName) == 'started' then
			AddPedFilesFromResource(peds, seen, resName)
		end
	end

	table.sort(peds)
	ServerPedsCache = peds
	LastServerPedsScan = now

	print(('^2[spooni_spooner]^7 Detectados %d peds/metapeds dos resources ativos.'):format(#peds))
	return peds
end

AddEventHandler('spooner:init', function()
	local permissions = {}

	if IsPlayerAceAllowed(source, 'spooner.noEntityLimit') then
		permissions.maxEntities = nil
	else
		permissions.maxEntities = Config.MaxEntities
	end

	permissions.spawn = {}
	permissions.spawn.ped = IsPlayerAceAllowed(source, 'spooner.spawn.ped')
	permissions.spawn.vehicle = IsPlayerAceAllowed(source, 'spooner.spawn.vehicle')
	permissions.spawn.object = IsPlayerAceAllowed(source, 'spooner.spawn.object')
	permissions.spawn.propset = IsPlayerAceAllowed(source, 'spooner.spawn.propset')
	permissions.spawn.pickup = IsPlayerAceAllowed(source, 'spooner.spawn.pickup')
	permissions.spawn.byName = IsPlayerAceAllowed(source, 'spooner.spawn.byName')
	permissions.spawn.spooni = IsPlayerAceAllowed(source, 'spooner.spawn.spooni')

	permissions.delete = {}
	permissions.delete.own = {}
	permissions.delete.own.networked = IsPlayerAceAllowed(source, 'spooner.delete.own.networked')
	permissions.delete.own.nonNetworked = IsPlayerAceAllowed(source, 'spooner.delete.own.nonNetworked')
	permissions.delete.other = {}
	permissions.delete.other.networked = IsPlayerAceAllowed(source, 'spooner.delete.other.networked')
	permissions.delete.other.nonNetworked = IsPlayerAceAllowed(source, 'spooner.delete.other.nonNetworked')

	permissions.modify = {}
	permissions.modify.own = {}
	permissions.modify.own.networked = IsPlayerAceAllowed(source, 'spooner.modify.own.networked')
	permissions.modify.own.nonNetworked = IsPlayerAceAllowed(source, 'spooner.modify.own.nonNetworked')
	permissions.modify.other = {}
	permissions.modify.other.networked = IsPlayerAceAllowed(source, 'spooner.modify.other.networked')
	permissions.modify.other.nonNetworked = IsPlayerAceAllowed(source, 'spooner.modify.other.nonNetworked')

	permissions.properties = {}
	permissions.properties.freeze = IsPlayerAceAllowed(source, 'spooner.properties.freeze')
	permissions.properties.position = IsPlayerAceAllowed(source, 'spooner.properties.position')
	permissions.properties.rotation = IsPlayerAceAllowed(source, 'spooner.properties.rotation')
	permissions.properties.goTo = IsPlayerAceAllowed(source, 'spooner.properties.goTo')
	permissions.properties.health = IsPlayerAceAllowed(source, 'spooner.properties.health')
	permissions.properties.invincible = IsPlayerAceAllowed(source, 'spooner.properties.invincible')
	permissions.properties.visible = IsPlayerAceAllowed(source, 'spooner.properties.visible')
	permissions.properties.gravity = IsPlayerAceAllowed(source, 'spooner.properties.gravity')
	permissions.properties.collision = IsPlayerAceAllowed(source, 'spooner.properties.collision')
	permissions.properties.clone = IsPlayerAceAllowed(source, 'spooner.properties.clone')
	permissions.properties.attachments = IsPlayerAceAllowed(source, 'spooner.properties.attachments')
	permissions.properties.lights = IsPlayerAceAllowed(source, 'spooner.properties.lights')
	permissions.properties.registerAsNetworked = IsPlayerAceAllowed(source, 'spooner.properties.registerAsNetworked')
	permissions.properties.focus = IsPlayerAceAllowed(source, 'spooner.properties.focus')

	permissions.properties.ped = {}
	permissions.properties.ped.changeModel = IsPlayerAceAllowed(source, 'spooner.properties.ped.changeModel')
	permissions.properties.ped.outfit = IsPlayerAceAllowed(source, 'spooner.properties.ped.outfit')
	permissions.properties.ped.group = IsPlayerAceAllowed(source, 'spooner.properties.ped.group')
	permissions.properties.ped.scenario = IsPlayerAceAllowed(source, 'spooner.properties.ped.scenario')
	permissions.properties.ped.animation = IsPlayerAceAllowed(source, 'spooner.properties.ped.animation')
	permissions.properties.ped.clearTasks = IsPlayerAceAllowed(source, 'spooner.properties.ped.clearTasks')
	permissions.properties.ped.weapon = IsPlayerAceAllowed(source, 'spooner.properties.ped.weapon')
	permissions.properties.ped.mount = IsPlayerAceAllowed(source, 'spooner.properties.ped.mount')
	permissions.properties.ped.enterVehicle = IsPlayerAceAllowed(source, 'spooner.properties.ped.enterVehicle')
	permissions.properties.ped.resurrect = IsPlayerAceAllowed(source, 'spooner.properties.ped.resurrect')
	permissions.properties.ped.ai = IsPlayerAceAllowed(source, 'spooner.properties.ped.ai')
	permissions.properties.ped.knockOffProps = IsPlayerAceAllowed(source, 'spooner.properties.ped.knockOffProps')
	permissions.properties.ped.walkStyle = IsPlayerAceAllowed(source, 'spooner.properties.ped.walkStyle')
	permissions.properties.ped.clone = IsPlayerAceAllowed(source, 'spooner.properties.ped.clone')
	permissions.properties.ped.cloneToTarget = IsPlayerAceAllowed(source, 'spooner.properties.ped.cloneToTarget')
	permissions.properties.ped.lookAtEntity = IsPlayerAceAllowed(source, 'spooner.properties.ped.lookAtEntity')
	permissions.properties.ped.clean = IsPlayerAceAllowed(source, 'spooner.properties.ped.clean')
	permissions.properties.ped.scale = IsPlayerAceAllowed(source, 'spooner.properties.ped.scale')
	permissions.properties.ped.configFlags = IsPlayerAceAllowed(source, 'spooner.properties.ped.configFlags')
	permissions.properties.ped.goToWaypoint = IsPlayerAceAllowed(source, 'spooner.properties.ped.goToWaypoint')
	permissions.properties.ped.goToEntity = IsPlayerAceAllowed(source, 'spooner.properties.ped.goToEntity')
	permissions.properties.ped.attack = IsPlayerAceAllowed(source, 'spooner.properties.ped.attack')

	permissions.properties.vehicle = {}
	permissions.properties.vehicle.repair = IsPlayerAceAllowed(source, 'spooner.properties.vehicle.repair')
	permissions.properties.vehicle.getin = IsPlayerAceAllowed(source, 'spooner.properties.vehicle.getin')
	permissions.properties.vehicle.engine = IsPlayerAceAllowed(source, 'spooner.properties.vehicle.engine')
	permissions.properties.vehicle.lights = IsPlayerAceAllowed(source, 'spooner.properties.vehicle.lights')

	TriggerClientEvent('spooner:init', source, permissions)
end)

AddEventHandler('spooner:toggle', function()
	if IsPlayerAceAllowed(source, 'spooner.view') then
		TriggerClientEvent('spooner:toggle', source)
	end
end)

AddEventHandler('spooner:openDatabaseMenu', function()
	if IsPlayerAceAllowed(source, 'spooner.view') then
		TriggerClientEvent('spooner:openDatabaseMenu', source)
	end
end)

AddEventHandler('spooner:openSaveDbMenu', function()
	if IsPlayerAceAllowed(source, 'spooner.view') then
		TriggerClientEvent('spooner:openSaveDbMenu', source)
	end
end)

AddEventHandler('spooner:requestServerPeds', function()
	if IsPlayerAceAllowed(source, 'spooner.view') then
		TriggerClientEvent('spooner:receiveServerPeds', source, ScanServerPeds(false))
	end
end)

RegisterCommand('spooner_refresh_perms', function(source, args, raw)
	TriggerClientEvent('spooner:refreshPermissions', -1)
end, true)

RegisterCommand('spooner_rescan_peds', function(source)
	if source ~= 0 then return end

	ServerPedsCache = nil
	local peds = ScanServerPeds(true)
	TriggerClientEvent('spooner:receiveServerPeds', -1, peds)
end, false)

CreateThread(function()
	Wait(5000)
	ScanServerPeds(false)
end)
