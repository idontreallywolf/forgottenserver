--------------------------------------------------------------------------------
---------------------------------- # CONFIG # ----------------------------------
--------------------------------------------------------------------------------
local WaveEvent = {
	MONSTERS = {
		HP_INCREMENT  = 1.05, -- +5%
		DMG_INCREMENT = 1.05, -- +5%

		HP_DECREMENT  = 0.9,  -- -10%
		DMG_DECREMENT = 0.95, -- -5%

		INITIAL_COUNT = 5,

		monsterList = {
			'rat','snake','orc','rotworm','troll','slime','skeleton','orc warrior','wyvern',
			'carrion worm','cyclops','cyclops drone','orc shaman','orc spearman','vampire',
			'orc warlord','orc berserker','dragon','fire elemental','energy elemental','wyrm',
			'cyclops smith','plaguesmith'
		}
	},

	MAX_WAVES = 10,
	NEXT_WAVE_DELAY = 10 * 1000, -- seconds

	finalBoss = 'zugurosh',
	mobsPerPlayer =  2,

	STATE_CLOSED  = -1,
	STATE_STARTED =  1,
	STATE_WAITING =  2,

	STATE_STORAGE      = 101192,
	WAVE_ROUND_STORAGE = 101193,
	LAST_PLAYER_AMOUNT = 101194,

	-- How long players will be waiting in the waiting room.
	waitingTime      = 1 * 10 * 1000, -- 10secs
	minReqPlayers    = 1,

	Arena = {
		TOP_LEFT     = Position(47, 399, 7),
		BOTTOM_RIGHT = Position(61, 409, 7)
	},

	WaitingRoom = {
		TOP_LEFT     = Position(52, 395, 7),
		BOTTOM_RIGHT = Position(55, 397, 7)
	}
}

--------------------------------------------------------------------------------
-------------------------------- # TALKACTION # --------------------------------
--------------------------------------------------------------------------------
local ta = TalkAction('!joinwave')
function ta.onSay(player, words, param)
	local waveEventState = Game.getStorageValue(WaveEvent.STATE_STORAGE)
	if not waveEventState or waveEventState == WaveEvent.STATE_CLOSED then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, 'The event hasn\'t started.')
		return false
	end

	if waveEventState == WaveEvent.STATE_STARTED then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, 'You are late. Catch the train next time.')
		return false
	end

	if player:getZone() ~= ZONE_PROTECTION then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, 'Go to a safe zone first.')
		return false
	end

	player:teleportTo(Position(
		math.random(WaveEvent.WaitingRoom.TOP_LEFT.x, WaveEvent.WaitingRoom.BOTTOM_RIGHT.x),
		math.random(WaveEvent.WaitingRoom.TOP_LEFT.y, WaveEvent.WaitingRoom.BOTTOM_RIGHT.y),
		WaveEvent.WaitingRoom.TOP_LEFT.z
	))

	Game.broadcastMessage(
		creature:getName() .. ' has joined the wave event. ('.. playersFound ..'/'.. WaveEvent.minReqPlayers ..')',
		MESSAGE_STATUS_CONSOLE_BLUE
	)
	return false
end
ta:separator(' ')
ta:register()

--------------------------------------------------------------------------------
-------------------------------- # GLOBALEVENT # -------------------------------
--------------------------------------------------------------------------------
local function isInEvent(player)
	local playerPos = player:getPosition()
	if  (playerPos.x >= WaveEvent.Arena.TOP_LEFT.x and playerPos.x <= WaveEvent.Arena.BOTTOM_RIGHT.x)
	and (playerPos.y >= WaveEvent.Arena.TOP_LEFT.y and playerPos.y <= WaveEvent.Arena.BOTTOM_RIGHT.y) then
		return true
	end
	return false
end

local function secondsToReadable(s)
	local minutes = math.floor(math.mod(s,3600)/60)
	local seconds = math.floor(math.mod(s,60))
	return (minutes > 0 and (minutes .. ' minutes ') or '') ..
		   (seconds > 0 and (seconds .. ' seconds')  or '')
end

local function handleMonsterCreation(m, applyBuffs, debuff)
	local mType = MonsterType(m)
	if not mType then
		return print('[Warning - WaveEvent::spawnMonsters] Unknown monster type ' .. m)
	end

	local mPos = Position(
		math.random(WaveEvent.Arena.TOP_LEFT.x, WaveEvent.Arena.BOTTOM_RIGHT.x),
		math.random(WaveEvent.Arena.TOP_LEFT.y, WaveEvent.Arena.BOTTOM_RIGHT.y),
		WaveEvent.Arena.TOP_LEFT.z
	)

	local monster = Game.createMonster(m, mPos)
	if not monster then
		return print('[Warning - WaveEvent::spawnMonsters] Could not create monster ' .. m)
	end

	if not applyBuffs then
		return mPos:sendMagicEffect(CONST_ME_TELEPORT)
	end

	if debuff then
		monster:setMaxHealth(monster:getMaxHealth() * WaveEvent.MONSTERS.HP_DECREMENT)
	else
		monster:setMaxHealth(monster:getMaxHealth() * WaveEvent.MONSTERS.HP_INCREMENT)
	end

	monster:setHealth(monster:getMaxHealth())
	mPos:sendMagicEffect(CONST_ME_TELEPORT)
end

local function initWave(wave_n, debuff)
	if n > WaveEvent.MAX_WAVES then
		print('MAX WAVES.')
		return
	end

	if not debuff then
		debuff = false
	end

	local monsterCount = (wave_n * 2) + WaveEvent.MONSTERS.INITIAL_COUNT
	local applyBuffs = true
	if wave_n == 1 then
		applyBuffs = false
	end

	for i = 1, monsterCount do
		local m = WaveEvent.MONSTERS.monsterList[math.random(1, #WaveEvent.MONSTERS.monsterList)]
		handleMonsterCreation(m, applyBuffs, debuff)
	end
end

local function teleportPlayersToArena()
	local playersFound = 0
	local z = WaveEvent.WaitingRoom.TOP_LEFT.z

	for x = WaveEvent.WaitingRoom.TOP_LEFT.x, WaveEvent.WaitingRoom.BOTTOM_RIGHT.x do
		for y = WaveEvent.WaitingRoom.TOP_LEFT.y, WaveEvent.WaitingRoom.BOTTOM_RIGHT.y do
			local tile = Tile(x, y, z)
			local tileCreatures = tile:getCreatures()

			if tileCreatures then
				for _, creature in pairs(tileCreatures) do
					creature:teleportTo(Position(
						math.random(WaveEvent.Arena.TOP_LEFT.x, WaveEvent.Arena.BOTTOM_RIGHT.x),
						math.random(WaveEvent.Arena.TOP_LEFT.y, WaveEvent.Arena.BOTTOM_RIGHT.y),
						WaveEvent.Arena.TOP_LEFT.z
					))

					playersFound = playersFound + 1
				end
			end
		end
	end

	if playersFound == 0 then
		Game.broadcastMessage('[WaveEvent] Nobody joined the wave event. Closing.', MESSAGE_STATUS_CONSOLE_BLUE)
		Game.setStorageValue(WaveEvent.STATE_STORAGE, WaveEvent.STATE_CLOSED)
		return
	end

	if playersFound < WaveEvent.minReqPlayers then
		Game.broadcastMessage('[WaveEvent] Not enough players. Closing.', MESSAGE_STATUS_CONSOLE_BLUE)
		Game.setStorageValue(WaveEvent.STATE_STORAGE, WaveEvent.STATE_CLOSED)
		return
	end

	Game.setStorageValue(WaveEvent.STATE_STORAGE, WaveEvent.STATE_STARTED)
	Game.broadcastMessage(
		'[WaveEvent] Starting with ' .. playersFound .. ' player'
			.. (playersFound > 1 and 's' or '')
			.. '. Good luck!',
			MESSAGE_STATUS_CONSOLE_BLUE
	)

	Game.setStorageValue(WaveEvent.WAVE_ROUND_STORAGE, 1)
	Game.setStorageValue(WaveEvent.LAST_PLAYER_AMOUNT, playersFound)
	initWave(1)
end

local ge = GlobalEvent('WaveEvent')
function ge.onTime(interval)
	local eventState = Game.getStorageValue(WaveEvent.STATE_STORAGE)
	if eventState == WaveEvent.STATE_STARTED
	or eventState == WaveEvent.STATE_WAITING then
		print('[Error - WaveEvent::onTime] Event state not closed. StorageKey -> '.. WaveEvent.STATE_STORAGE)
		return true
	end

	Game.broadcastMessage(
		'WaveEvent has started. You have '
			.. secondsToReadable(WaveEvent.waitingTime)
			.. ' to join. !joinwave',
		MESSAGE_STATUS_CONSOLE_BLUE
	)

	Game.setStorageValue(WaveEvent.STATE_STORAGE, WaveEvent.STATE_WAITING)
	addEvent(teleportPlayersToArena, WaveEvent.waitingTime)
end
ge:time('21:17:00')
ge:register()

--------------------------------------------------------------------------------
-------------------------------- # CREATURESCRIPT # ----------------------------
--------------------------------------------------------------------------------
local cs = CreatureScript('WaveEventPrepareDeath')
function cs.onPrepareDeath(player, killer)
	if Game.getStorageValue(WaveEvent.STATE_STORAGE) == WaveEvent.STATE_CLOSED then
		return true
	end
	if isInEvent(player) then
		player:teleportTo(player:getTown():getTemplePosition())
		Game.broadcastMessage('[WaveEvent] ' .. player:getName() .. ' was killed by a monster.')
		return false
	end
	return true
end
cs:register()


local function ordinal_number(n)
	local ordinal, digit = {"st", "nd", "rd"}, string.sub(n, -1)
	if  tonumber(digit)  >  0
	and tonumber(digit)  <= 3
	and string.sub(n,-2) ~= 11
	and string.sub(n,-2) ~= 12
	and string.sub(n,-2) ~= 13 then
		return n .. ordinal[tonumber(digit)]
	else
		return n .. "th"
	end
end

local csx = CreatureScript('WaveEventMonsterDeath')
function csx.onKill(player, target)
	if Game.getStorageValue(WaveEvent.STATE_STORAGE) == WaveEvent.STATE_CLOSED then
		return true
	end

	if isInEvent(player) then
		local monstersFound = 0
		local playersFound = 0
		local z = WaveEvent.Arena.TOP_LEFT.z
		for x = WaveEvent.Arena.TOP_LEFT.x, WaveEvent.Arena.BOTTOM_RIGHT.x do
			for y = WaveEvent.Arena.TOP_LEFT.y, WaveEvent.Arena.BOTTOM_RIGHT.y do
				local tile = Tile(x,y,z)
				local topCreature = tile:getTopCreature()
				if topCreature then					
					if topCreature:isMonster() then
						monstersFound = monstersFound + 1
					elseif topCreature:isPlayer() then
						playersFound = playersFound + 1
					end
				end
			end
		end

		if count == 0 then
			local n = Game.getStorageValue(WaveEvent.WAVE_ROUND_STORAGE)
			Game.broadcastMessage(
				ordinal_number(n)
				..' wave has been cleared. Prepare for next wave. ('
					.. secondsToReadable(WaveEvent.NEXT_WAVE_DELAY / 1000)
				.. ')'
			)

			local lastPlayerAmount = Game.getStorageValue(WaveEvent.LAST_PLAYER_AMOUNT)
			Game.setStorageValue(WaveEvent.LAST_PLAYER_AMOUNT, playersFound)
			addEvent(
				initWave,
				WaveEvent.NEXT_WAVE_DELAY, n+1,
				(lastPlayerAmount > playersFound and true) or false
			)
		end
	end
	return true
end
csx:register()