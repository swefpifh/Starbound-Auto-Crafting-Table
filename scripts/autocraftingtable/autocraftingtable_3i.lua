require "/scripts/vec2.lua" -- for world text

function init()
	self.recipes = root.assetJson(config.getParameter("recipePath")).recipes
	self.inputSlots = {{nil, 0}, {nil, 0}, {nil, 0}}
	self.outputSlots = {{nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}, {nil, 0}}
	self.timer = 0
	self.consumedItems = false
	self.pickedRecipe = nil
	
	animator.setAnimationState("actTableSprite", "idle") -- Set initial animation state to idle
end

function update(dt)
	local PBarDisplay = config.getParameter("progressbardisplay")
	if self.pickedRecipe ~= nil and self.timer > 0 and PBarDisplay == 1 then
		self.timer = self.timer - dt		
		local progressPercent = math.floor((1 - self.timer / self.pickedRecipe.time) * 100)
		local progressBarTXT = config.getParameter("progressbartitle")
		object.say(progressBarTXT .. " " .. progressPercent .. "%")
		
		animator.setAnimationState("actTableSprite", "working") -- Set animation state to working if recipe is in progress
	elseif self.pickedRecipe ~= nil and self.timer > 0 and PBarDisplay == 0 then
		self.timer = self.timer - dt		
		animator.setAnimationState("actTableSprite", "working") -- Set animation state to working if recipe is in progress
	else
		self.timer = self.timer - dt
		animator.setAnimationState("actTableSprite", "idle") -- Set animation state to idle if no recipe is in progress
	end

	local contents = world.containerItems(entity.id())
	if countElements(contents) > 0 then
		for i=0, 11, 1 do
			if i <= 2 then
				self.inputSlots[i] =  world.containerItemAt(entity.id(), i)
			else
				self.outputSlots[i] = world.containerItemAt(entity.id(), i)
			end
		end
	else
		self.inputSlots = {}
		self.outputSlots = {}
	end

	if countElements(contents) > 0 and self.pickedRecipe == nil then
		recipesCheck()
	end
	if self.pickedRecipe ~= nil then
		recipesSpawn()
	end
end

function recipesCheck()
	for _, v in ipairs(self.recipes) do
		local inputSlots = deepCopy(self.inputSlots)
		local requiredInput = {}
		local validItems = {}
		local validRecipe = true

		for idx, r in pairs(v) do 
			if string.find(idx, "input") and countElements(r) > 0 then
				table.insert(requiredInput, r)
			end
		end

		if countElements(requiredInput) == 0 then
			validRecipe = false
		end

		for i, r in ipairs(requiredInput) do
			local itemAccepted = false
		
			for idx, v in pairs(inputSlots) do
				if not itemAccepted then
					if countElements(r) == 1 then
						if findKey(r, v.name) and r[v.name][1] <= v.count then
							itemAccepted = true
							if r[v.name][1] < v.count then
								v.count = v.count - r[v.name][1]
							else
								inputSlots[idx] = nil
							end
		
							table.insert(validItems, v)
						end
					elseif countElements(r) > 1 then
						for key, count in pairs(r) do
							if not itemAccepted then
								if key == v.name and count[1] <= v.count then
									itemAccepted = true
									inputSlots[idx] = nil
		
									if count[1] < v.count then
										v.count = v.count - r[v.name][1]
									else
										inputSlots[idx] = nil
									end
		
									table.insert(validItems, v)
								end
							end
						end
					end
				end
			end
		
			if not itemAccepted then
				validRecipe = false
				break
			end
		end

		if validRecipe then
			local purgedRecipe = deepCopy(v)
			for i, r in pairs(purgedRecipe) do
				if type(tostring(i)) == "string" then
					if i:find("input") then
						
						if countElements(r) > 1 then
							for rItem, count in pairs(r) do
								local isValid = false
								for _, item in pairs(validItems) do
									if item.name == rItem and item.count >= count[1] then
										isValid = true
										break
									end
								end
								
								if not isValid then
									r[rItem] = nil
								else
									break
								end
							end
						end
						
					end
				end
			end
			self.pickedRecipe = purgedRecipe
			self.timer = v.time
			recipesSpawn()
			break
		end
	end
end

function recipesSpawn()
	if not self.consumedItems then
		local inputSlots = shiftNumericIndexesUp(self.inputSlots)
		for i, r in pairs(self.pickedRecipe) do
			if type(tostring(i)) == "string" and i:find("input") then
				for item, amount in pairs(r) do
					
					for j, v in pairs(inputSlots) do
						if v.name == item and v.count >= amount[2] then
							world.containerTakeNumItemsAt(entity.id(), j-1, amount[2])
							break
						end
					end
				end
			end
		end
	
		self.consumedItems = true
	end

	if self.timer <= 0 then
		self.timer = 0
		idx = 3
		for _, v in pairs(self.pickedRecipe.outputs) do
			local craftingChance = math.random(1, 100)
			if craftingChance <= v.chance then
				local leftover = {name = v.item[1], count = v.item[2], parameters = {}}
				for i = 3, 11, 1 do
					if leftover then
						leftover = world.containerPutItemsAt(entity.id(), leftover, i)
					else
						break
					end
				end
				
				if leftover ~= nil then
					for _, v in pairs(leftover) do
						world.spawnItem(v, entity.position())
					end
				end
			end
		end
		
		self.pickedRecipe = nil
		self.consumedItems = false
	end
end

function countElements(table)
    local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

function findKey(tbl, wanted)
	for k, v in pairs(tbl) do
		if k == wanted then
			return true
		end
	end
	return false
end

function deepCopy(original)
    local copy

    if type(original) == 'table' then
        copy = {}
        for key, value in pairs(original) do
            copy[key] = deepCopy(value)
        end
    else
        copy = original
    end

    return copy
end

function shiftNumericIndexesUp(table)
    local newTable = {}

    for key, value in pairs(table) do
        if type(key) == "number" then
            newTable[key + 1] = value
        else
            newTable[key] = value
        end
    end

    return newTable
end
