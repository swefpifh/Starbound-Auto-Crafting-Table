
require "/scripts/vec2.lua" -- for world text
--[[
Incubator Crafting
- 1-3 input item(s) and 1-9 output item(s)
- same items do not stack in the output
]]

function init()
	-- set up values
	self.recipes = root.assetJson(config.getParameter("recipePath")).recipes -- this will error if the path is not valid
	--sb.logInfo("%s", self.recipes) --testing
	
	self.inputSlots = {{nil, 0}, {nil, 0}, {nil, 0}} -- 3 input slots
	self.outputSlots = {{nil, 0}, {nil, 0}, {nil, 0},{nil, 0}, {nil, 0}, {nil, 0},{nil, 0}, {nil, 0}, {nil, 0}} -- 9 output slots
	
	self.timer = 0 -- current time to craft
	
	self.consumedItems = false -- whether it already consumed the current recipe items
	self.pickedRecipe = nil -- the recipe match
end

function update(dt)
	-- update handles the timer as well as setting values
	if self.pickedRecipe~=nil and self.timer > 0 then
		self.timer = self.timer - dt
		--changeText("timeText", ("%s Minutes"):format(self.timer)) UNUSED: objects cannot access ScriptPane globals and therefore cannot change interface text
	end

    local contents = world.containerItems(entity.id())
	
	-- loop through contents and fill internal tables
	sb.logInfo("%s,", #contents)
	if countElements(contents) > 0 then
		--sb.logInfo("")sb.logInfo("")
		--sb.logInfo("%s", self.inputSlots)
		--sb.logInfo("")sb.logInfo("")
		for i=0, 11, 1 do -- offset-based functions start from 0 instead of 1 unlike the rest of lua
			if i <= 2 then --input slots
				sb.logInfo("inputSlots: %s", i)
				self.inputSlots[i] =  world.containerItemAt(entity.id(), i)--contents[i]
			else -- output slots
				self.outputSlots[i] = world.containerItemAt(entity.id(), i)--contents[i]
			end
		end
	else
		self.inputSlots = {}
		self.outputSlots = {}
	end
	--sb.logInfo("%s", self.debugItemChoice) --testsing
	--append = (self.pickedRecipe~=nil and self.debugItemChoice) or "none"
	world.debugText("Timer:"..tostring(self.timer), vec2.add(object.position(), {1, 2}), "red")
	
	sb.logInfo("inputs: %s, #: %s", self.inputSlots, countElements(self.inputSlots))
	
	if countElements(contents) > 0 and self.pickedRecipe == nil then -- only check for a recipe if not currently crafting one
		recipesCheck()
	end
	if self.pickedRecipe ~= nil then -- currently crafting
		recipesSpawn() -- continue to call this to update when timer reaches 0
	end
end

-- helper functions

-- find the matching item recipe keyName (in this case, itemName)
function findKey(tbl, wanted)
	for k, v in pairs(tbl) do
		if k == wanted then
			return true
		end
	end
	return false
end

-- workaround for # operator on dictionaries
function countElements(table)
    local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

-- deepcopy table to prevent original table to be modified (defining a table in a new variable does not create a new table)
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

-- up the table index by 1 as recipesSpawn Consumption loop seems to skip over index 0 alltogether - to fix this, simply increase index by 1
function shiftTableIndex(otbl,inc) 
	local tbl = otbl
	for i = 0, #tbl+(inc-1) do
		--if i <= inc-1 then tbl[i] = nil end
		tbl[i] = otbl[i-inc]
	end
	return tbl
end
function shiftNumericIndexesUp(table)
    local newTable = {}

    -- Shift numeric indexes up by 1 in the new table
    for key, value in pairs(table) do
        if type(key) == "number" then
            newTable[key + 1] = value
        else
            newTable[key] = value
        end
    end

    return newTable
end


--Recipes section
function recipesCheck()

	
	-- iterate through recipes until a match was found
	for _, v in ipairs(self.recipes) do
		local inputSlots = deepCopy(self.inputSlots)
	
		local requiredInput = {}
		local validItems = {}
		local validRecipe = true
		
		-- iterate through recipe input items to check for a match
		for idx, r in pairs(v) do 
			if string.find(idx, "input") and countElements(r) > 0 then -- make sure we are only adding input items (that have something in them)
				table.insert(requiredInput, r) -- insert required input items
			end
		end
		--sb.logInfo("------------------------------------")
		--sb.logInfo("iterating through required input") 
		
		-- if input table is empty (somehow), invalid
		if countElements(requiredInput) == 0 then
			validRecipe = false
		end
		
		--shoutout to ChatGPT for releasing me from 7 hours of pain
		-- Iterate through required input and compare with current input
		for i, r in ipairs(requiredInput) do
			--sb.logInfo("%s, %s", i, #requiredInput)
			--local h=countElements(r)
			--sb.logInfo("items required: %s", r)
			--sb.logInfo("# of required: %s", h)
			--sb.logInfo("current recipe: %s", (h==1 and "only one input item") or "multiple input items")
			local itemAccepted = false
			--sb.logInfo("---------------------------------")
			--sb.logInfo("%s", inputSlots)
			--sb.logInfo("---------------------------------")
		
			for idx, v in pairs(inputSlots) do
				if not itemAccepted then -- Check if the current item is already accepted
					if countElements(r) == 1 then -- Only one input item accepted
						--sb.logInfo("required:%s, given:%s, %s", r, v.name, v.count)
						if findKey(r, v.name) and r[v.name][1] <= v.count then
							--sb.logInfo("Item accepted: %s, %s, %s", r, v.name, v.count)
							itemAccepted = true
							if r[v.name][1] < v.count then
								v.count = v.count - r[v.name][1] -- Only some items would be consumed, permit rescanning
							else
								inputSlots[idx] = nil -- All items would be consumed, prevent rescanning
							end
		
							-- Add to a list to exclude this item when purging excess items in the valid recipe
							table.insert(validItems, v)
						end
					elseif countElements(r) > 1 then -- Multiple input items accepted
						for key, count in pairs(r) do
							if not itemAccepted then -- Check if the current item is already accepted
								--sb.logInfo("required:%s, %s, given:%s, %s", key, count, v.name, v.count)
								--sb.logInfo("---------")
								if key == v.name and count[1] <= v.count then
									--sb.logInfo("Item accepted: %s, %s, %s, %s", key, count, v.name, v.count)
									itemAccepted = true
									inputSlots[idx] = nil -- Remove this item to prevent it from being re-scanned
		
									if count[1] < v.count then
										v.count = v.count - r[v.name][1] -- Only some items would be consumed, permit rescanning
									else
										inputSlots[idx] = nil -- All items would be consumed, prevent rescanning
									end
		
									-- Add to a list to exclude this item when purging excess items in the valid recipe
									table.insert(validItems, v)
								end
							end
						end
					end
				end
			end
		
			if not itemAccepted then
				--sb.logInfo("Item not accepted: %s", r)
				validRecipe = false
				break -- Exit if the current item is not accepted
			end
		end

		-- my code - recipe order must match for a valid recipe to be found, above GPT code fixed this (and i dont even know what it did)
		--[[ iterate through required input and compare with current input
		for i, r in ipairs(requiredInput) do -- r == table of item and quantity
			sb.logInfo("%s, %s", i, #requiredInput)
			local h=countElements(r)
			sb.logInfo("items required: %s", r)
			sb.logInfo("# of required: %s", h)
			sb.logInfo("current recipe: %s", (h==1 and "only one input item") or "multiple input items")
			local itemAccepted = false
			sb.logInfo("---------------------------------")
			sb.logInfo("%s", inputSlots)
			sb.logInfo("---------------------------------")
			for idx, v in pairs(inputSlots) do
				sb.logInfo("-------------")
				if countElements(r) == 1 then -- only one input item accepted
					sb.logInfo("required:%s, given:%s, %s", r, v.name, v.count)
					if findKey(r, v.name) and r[v.name][1] <= v.count then
						sb.logInfo("item accepted")
						itemAccepted = true
						if r[v.name][1] < v.count then
							v.count = v.count - r[v.name][1] -- only some items would be consumed, permit rescanning
						else
							inputSlots[idx] = nil -- all items would be consumed, therefore prevent rescanning
						end
						
						-- add to a list to be able to exclude this item when purging excess items in the valid recipe
						table.insert(validItems, v)
						break
					end
				elseif countElements(r) > 1 then -- multiple input items accepted
					for key, count in pairs(r) do
						sb.logInfo("required:%s, %s, given:%s, %s", key, count, v.name, v.count)
						sb.logInfo("---------")
						if key == v.name and count[1] <= v.count then
							sb.logInfo("item accepted")
							itemAccepted = true
							
							if count[1] <= v.count then
								v.count = v.count - r[v.name][1] -- only some items would be consumed, permit rescanning
							else
								inputSlots[idx] = nil -- all items would be consumed, therefore prevent rescanning
							end
							
							-- add to a list to be able to exclude this item when purging excess items in the valid recipe
							table.insert(validItems, v)
							break
						end
					end

					if itemAccepted then break end -- break if the previous loop broke
				end
			end
			
			if not itemAccepted then
				sb.logInfo("item not accepted")
				sb.logInfo("-------------")
				validRecipe = false
			elseif i == #requiredInput and validRecipe then -- if we reached the end of the recipe, and all items match, it is a valid recipe
				validRecipe = true
				sb.logInfo("items all accepted, valid recipe :3!!!")
				break -- exit out of the requiredInput loop as we have found a match
			else
				itemAccepted = false
			end
		end]]
		
		if validRecipe then
			-- purge items in the recipe that werent found in the container (so we can consume them easier later)
			local purgedRecipe = deepCopy(v)
			for i, r in pairs(purgedRecipe) do
				if type(tostring(i)) == "string" then
					if i:find("input") then -- if this is a table of input items...
						
						if countElements(r)>1 then -- if multi-input...
							--sb.logInfo("recipe: %s", r)
							for rItem, count in pairs(r) do -- recipe
								--sb.logInfo("%s, %s", rItem, count)
								local isValid = false
								for _, item in pairs(validItems) do -- accepted items
									--sb.logInfo("item: %s, %s", item.name, item.count)
									if item.name == rItem and item.count >= count[1] then
										--sb.logInfo("valid item")
										isValid = true
										break
									end
								end
								
								if not isValid then
									r[rItem] = nil -- remove items that werent detected
								else
									break
								end
							end
						end
						
					end
				end
			end
			self.pickedRecipe = purgedRecipe
			--sb.logInfo("Purged Rec: %s", purgedRecipe)
			self.timer = v.time
			recipesSpawn()
			break -- stop the recipe search
		end
	end
	
end

function recipesSpawn()
	--sb.logInfo("spawning recipe output")
	
	-- Clear items the recipe consumes and leave excess
	if not self.consumedItems then
		local inputSlots = shiftNumericIndexesUp(self.inputSlots) -- remove index 0 as it seems to be bullied by the below code
		--sb.logInfo("inputSLOTS CURRENT: %s", inputSlots)
		for i, r in pairs(self.pickedRecipe) do
			if type(tostring(i)) == "string" and i:find("input") then
				--sb.logInfo("r:%s", r)
				for item, amount in pairs(r) do
					--sb.logInfo("new recipe item iteration")
					--sb.logInfo("Input item: %s, %s required", item, amount[2])
					
					for j, v in pairs(inputSlots) do
						--sb.logInfo("j: %s, inputSlot: %s", j, v)
						--local v = self.inputSlots[j]
						
						--sb.logInfo("%s, %s", v, self.inputSlots)
						if v.name == item and v.count >= amount[2] then
							--sb.logInfo("(%s) Name match: %s, Count match: %s", item, v.name == item, v.count >= amount[2])
							--sb.logInfo("Consuming %s %s at slot %s", amount[2], item, j)
							world.containerTakeNumItemsAt(entity.id(), j-1, amount[2])
							
							break -- Exit the loop after consuming the required amount
						end
					end
				end
			end
		end
	
		self.consumedItems = true
	end

	
	
	--sb.logInfo("waiting for timer...")
	if self.timer <= 0 then --if enough time has passed
		--sb.logInfo("%s", self.inputSlots)
		self.timer = 0
		idx = 3 -- NOTE: containerPutItemsAt uses OFFSET --- INDEX starts at 0, so start at 3 to skip over input slots
		for _, v in pairs(self.pickedRecipe.outputs) do
			local craftingChance = math.random(1, 100) -- 1-100 percentage chance for a craft
			if craftingChance <= v.chance then
				
				-- attempt to put into existing stacks - NOTE: MAY STACK INTO EXCESS INPUT SLOTS, but realistically shouldn't be an issue as recipes normally shouldn't produce items used in an input (because you can set it to not consume that item)
				local leftover = {name = v.item[1], count = v.item[2], parameters = {}}
				for i = 3, 11, 1 do -- slots 0, 1, 2 are inputs
					if leftover then
						leftover = world.containerPutItemsAt(entity.id(), leftover, i)
					else
						break
					end
				end
				
				if leftover~=nil then -- stacking didn't work, drop the items
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

-- Running on LUA 1984.0.0 - Ignoring index 0 since forever