local config = {
	-- Don't change ( unless you know what you're doing )
	TILE_CUSTOMATTR_KEY = "snakeScore",

	-- Where players will be kicked after finishing the game.
	KICKPLAYER_POS  = Position(201, 390, 7),

	-- Where players will steer the snake.
	CONTROL_POS     = Position(213, 391, 6),

	-- Snake room corner positions
	TOP_LEFT        = Position(205, 385, 7),
	BOTTOM_RIGHT    = Position(219, 395, 7),

	SNAKE_SPAWN_POS = Position(212, 390, 7),

	FOOD_ID  = 2674,
	SNAKE_ID = 463,

	-- How long the snake will be at start
	SNAKE_START_SCORE = 3,

	SPEED_START = 600, -- 0.6s

	-- How much faster the snake will get..
	-- ..after consuming 'food' object. ( milliseconds )
	SPEED_INCREMENT = 100, -- 0.1s

	-- ActionId to be used on enter tile
	TILE_ACTION_ID = 12345,

	-- How long a player should wait before they can play again
	PLAYER_PLAY_STORAGE = 191214,
	PLAYER_PLAY_DELAY = 10 -- 10 seconds
}

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function handleSnakeTile(position, score)
	local tile = Tile(position)
	if not tile:getGround() then
		return print("[Warning - snake::handleSnakeTile] Ground not found.")
	end

	local tailScore = tile:getGround():getCustomAttribute(config.TILE_CUSTOMATTR_KEY)
	local snakeObject = tile:getItemById(config.SNAKE_ID)
	if not tailScore or tailScore == 0 then
		if snakeObject then
			snakeObject:remove()
		end
		return
	end

	tile:getGround():setCustomAttribute(config.TILE_CUSTOMATTR_KEY, tailScore - 1)
	if (tailScore - 1) == 0 and snakeObject then
		snakeObject:remove()
	end
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function moveSnake(nextHeadPosition, score)
	if not Game.createItem(config.SNAKE_ID, 1, nextHeadPosition) then
		print('[Error - snake::moveSnake] Could not create item snake.')
		return
	end

	local tile = Tile(nextHeadPosition)
	tile:getGround():setCustomAttribute(config.TILE_CUSTOMATTR_KEY, score + 1)

	local z = config.TOP_LEFT.z
	for y = config.TOP_LEFT.y, config.BOTTOM_RIGHT.y do
		for x = config.TOP_LEFT.x, config.BOTTOM_RIGHT.x do
			handleSnakeTile(Position(x, y, z), score)
		end
	end
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function showScore(player, score)
	local text = "Snake Score: " .. score
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE, text)
	player:setStorageValue(config.PLAYER_PLAY_STORAGE, config.PLAYER_PLAY_DELAY + os.time())
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function placeFood()
	Game.createItem(config.FOOD_ID, 1, Position(
		math.random(config.TOP_LEFT.x, config.BOTTOM_RIGHT.x),
		math.random(config.TOP_LEFT.y, config.BOTTOM_RIGHT.y),
		config.TOP_LEFT.z
	))
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function isFood(position)
	local tile = Tile(position)
	if not tile then return true end

	local foodObject = tile:getItemById(config.FOOD_ID)
	if foodObject then
		foodObject:remove()
		placeFood()
		return true
	end
	return false
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function isSnakeTail(position)
	local tile = Tile(position)
	if not tile then return true end

	local snakeObject = tile:getItemById(config.SNAKE_ID)
	if snakeObject then
		return true
	end
	return false
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function isWall(position)
	if (position.x < config.TOP_LEFT.x)
	or (position.x > config.BOTTOM_RIGHT.x)
	or (position.y < config.TOP_LEFT.y)
	or (position.y > config.BOTTOM_RIGHT.y) then
		return true
	end
	return false
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function createSnake()
	local tile = Tile(config.SNAKE_SPAWN_POS)
	if not tile then
		return print("[Error - snake::createSnake] Tile not found")
	end

	local ground = tile:getGround()
	if not ground then
		return print("[Error - snake::createSnake] Ground not found.")
	end

	ground:setCustomAttribute(config.TILE_CUSTOMATTR_KEY, config.SNAKE_START_SCORE)
	Game.createItem(config.SNAKE_ID, 1, config.SNAKE_SPAWN_POS)
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function positionToReadable(position)
	return "(".. position.x .." / ".. position.y .." / ".. position.z ..")"
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function clearTile(position)
	local tile = Tile(position)
	if not tile then
		return print("[Warning - snake::clearSnakeArea] Tile not found " .. positionToReadable(position))
	end

	local tileItems = tile:getItems()
	if tileItems then
		for _, item in pairs(tileItems) do
			item:remove()
		end
	end

	-- Maybe there's a sneaky GM? xD
	local creature = tile:getTopCreature(position)
	if creature then
		creature:teleportTo(config.KICKPLAYER_POS)
	end

	tile:getGround():removeCustomAttribute(config.TILE_CUSTOMATTR_KEY)
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function clearSnakeArea()
	local z = config.TOP_LEFT.z
	for y = config.TOP_LEFT.y, config.BOTTOM_RIGHT.y do
		for x = config.TOP_LEFT.x, config.BOTTOM_RIGHT.x do
			clearTile(Position(x, y, z))
		end
	end
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function gameLoop(player, score, speed, headPosition)
	player = Player(player)
	if (not player) or (not Tile(config.CONTROL_POS):getTopCreature()) then
		return print('[Error - snake::gameLoop] Player not found.')
	end

	local direction  = player:getDirection()

	headPosition:getNextPosition(direction)
	if isWall(headPosition) or isSnakeTail(headPosition) then
		showScore(player, score)
		player:teleportTo(config.KICKPLAYER_POS)
		clearSnakeArea()
		return
	end

	local foundFood = false
	if isFood(headPosition) then
		foundFood = true
		score = score + 1
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, 'score: ' .. score)
	end

	moveSnake(headPosition, score)

	if foundFood then
		speed = speed - config.SPEED_INCREMENT
		if speed <= 100 then
			speed = 100
		end
	end

	addEvent(gameLoop, speed, player:getId(), score, speed, headPosition)
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local function init(player)
	clearSnakeArea()
	placeFood()
	createSnake()
	player:teleportTo(config.CONTROL_POS)

	local headPosition = Position(
		config.SNAKE_SPAWN_POS.x,
		config.SNAKE_SPAWN_POS.y,
		config.SNAKE_SPAWN_POS.z
	)

	gameLoop(player:getId(), config.SNAKE_START_SCORE, config.SPEED_START, headPosition)
end

-- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ## -- ##

local snakeEnter = MoveEvent("snakeEnter")
snakeEnter:type('stepin')
function snakeEnter.onStepIn(player, item, position, fromPosition)
	local controlTile = Tile(config.CONTROL_POS)
	if controlTile and controlTile:getTopCreature() then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, 'The game is currently occupied. Try again later.')
		player:teleportTo(fromPosition)
		fromPosition:sendMagicEffect(CONST_ME_POFF)
		return true
	end

	local lastPlayed = player:getStorageValue(config.PLAYER_PLAY_STORAGE)
	if lastPlayed > os.time() then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, 'You need to wait ' .. (lastPlayed - os.time()) .. ' seconds.')
		player:teleportTo(fromPosition)
		fromPosition:sendMagicEffect(CONST_ME_POFF)
		return true
	end

	init(player)
	return true
end
snakeEnter:aid(config.TILE_ACTION_ID)
snakeEnter:register()