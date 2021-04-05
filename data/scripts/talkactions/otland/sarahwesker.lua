local config = {
	spiralSpeed = 100,
	maxRadius   = 7
}

local function directionCheck(startPosition, position, topEdge, bottomEdge, leftEdge, rightEdge, dirX, dirY)
	if startPosition.y == position.y and ((position.x == leftEdge) or (position.x == rightEdge)) then
		dirX = dirX * -1
	end

	if startPosition.x == position.x and ((position.y == topEdge) or (position.y == bottomEdge)) then
		dirY = dirY * -1
	end

	position.x = position.x + dirX
	position.y = position.y + dirY
	return dirX, dirY
end

local function startSpiral(radius, round_n, position, startPosition, dirX, dirY, n_count, isFirst)
	if radius >= config.maxRadius then return end
	position:sendMagicEffect(CONST_ME_FIREAREA)

	if isFirst then
		position.x = position.x + dirX
		position.y = position.y + dirY
		addEvent(
			startSpiral, config.spiralSpeed, radius, round_n,
			position, startPosition, dirX, dirY, n_count+1, false
		)
		return
	end

	local topEdge    = (startPosition.y - radius)
	local bottomEdge = (startPosition.y + radius)
	local leftEdge   = (startPosition.x - radius)
	local rightEdge  = (startPosition.x + radius)

	if n_count == math.pow(round_n, 2) then
		position.x = position.x + dirX
		position.y = position.y + dirY

		local dX = math.abs(startPosition.x - position.x)
		local dY = math.abs(startPosition.y - position.y)

		if dX > dY then 
			dirX = dirX * -1
		elseif dY > dX then
			dirY = dirY * -1
		end

		addEvent(
			startSpiral, config.spiralSpeed, radius + 2, round_n + 2,
			position, startPosition, dirX, dirY, n_count+1, false
		)
		return
	end

	dirX, dirY = directionCheck(startPosition, position, topEdge, bottomEdge, leftEdge, rightEdge, dirX, dirY)
	addEvent(
		startSpiral, config.spiralSpeed, radius, round_n,
		position, startPosition, dirX, dirY, n_count+1, false
	)
end

local talkaction = TalkAction('!spiral')
function talkaction.onSay(player, words, param)
	local playerPos = player:getPosition()
	local startPosition = Position(playerPos.x, playerPos.y, playerPos.z)
	playerPos:getNextPosition(player:getDirection())

	local position = Position(playerPos.x, playerPos.y, playerPos.z)

	local radius = 1

	local dirX = (position.x < startPosition.x and 1) or -1
	local dirY = (position.y < startPosition.y and 1) or -1

	startSpiral(radius, 2, position, startPosition, dirX, dirY, 0, true)
	return false
end

talkaction:separator(" ")
talkaction:register()
--[[

		4 16 36 64

		16 -  4 = 12
		36 - 16 = 20
		64 - 36 = 28
]]