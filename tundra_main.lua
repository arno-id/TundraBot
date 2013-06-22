local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic         = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands     = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib     = {}
object.metadata     = {}
object.behaviorLib     = {}
object.skills         = {}

--ANIMALS
object.unitFlying = nil
object.unitCoeurl = nil
object.unitNecroMelee = nil
object.unitNecroRanged = nil
 

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
    = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho(object:GetName()..' loading tundra_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  Bot Constant Definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Tundra'


--   item buy order. internal names  
behaviorLib.StartingItems  = {'Item_RunesOfTheBlight', 'Item_MinorTotem', 'Item_MinorTotem', 'Item_ManaBattery'}
behaviorLib.LaneItems  = {'Item_Marchers',  'Item_MysticVestments', 'Item_PowerSupply' }
behaviorLib.MidItems  = { 'Item_Steamboots', 'Item_Summon', 'Item_SolsBulwark',  'Item_MagicArmor2'}
behaviorLib.LateItems  = {'Item_DaemonicBreastplate', 'Item_Dawnbringer' }

--Skills:
	--Info: https://www.heroesofnewerth.com/heroes/view/160/Tundra#hero
	--Q PiercingShards
	--W CallofWinter (animals)
	--E ColdShoulder
	--R Avalanche
-- Skillbuild table, 0=Q, 1=W, 2=E, 3=R, 4=Attri
object.tSkills = {
    0, 2, 0, 1, 0,
    3, 0, 1, 1, 1, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}


-- These are bonus agression points if a skill/item is available for use
object.nPiercingShardsUp = 15
object.nCallofWinterUp = 5 
object.nColdShoulderUp = 15
object.nAvalancheUp = 30

-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nPiercingShardsUse = 15
object.nCallofWinterUse = 5
object.nColdShoulderUse = 10
object.nAvalancheUse = 50


--These are thresholds of aggression the bot must reach to use these abilities
object.nPiercingShardsThreshold = 35
object.nCallofWinterThreshold = 15
object.nColdShoulderThreshold = 30
object.nAvalancheThreshold = 85


--####################################################################
--####################################################################
--#                                                                 ##
--#   Bot Function Overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     Skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(1)
        skills.abilE = unitSelf:GetAbility(2)
        skills.abilR = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
    end
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end   
   
    local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()

    for i = nLev, nLev+nLevPts do
        unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
    end
end


--brrowed from kairus101 
local function positionOffset(pos, angle, distance) --this is used by minions to form a ring around people.
        tmp = Vector3.Create(cos(angle)*distance,sin(angle)*distance)
        return tmp+pos
end

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)
	
	-- here comes the animal control
	local botBrain=self
	local vecUnitSelf = core.unitSelf:GetPosition() 
	unitFlying = nil
	unitCoeurl = nil
	unitNecroMelee = nil
	unitNecroRanged = nil
	if core.localUnits["AllyUnits"] ~= nil then	
		local tAllies = core.CopyTable(core.localUnits["AllyUnits"])
			for index, unit in pairs(tAllies) do
				if unit and unit:IsValid() then
		
				local unitType = unit:GetTypeName()
				if unitType  == "Pet_Tundra_Ability2_Flying"  then
					unitFlying = unit
					
					--invisibility if possible
					local skill1 = unitFlying:GetAbility(0) --invisibility
					if skill1 ~= nil and skill1:CanActivate() then 
						core.OrderAbility(botBrain, skill1)
					end
					  
					--local bInTowerRange = core.NumberElements(core.GetTowersThreateningUnit(unitFlying)) > 0
					-- are we in a towers range? - currently disabled, the bird just patrols
					--if not bInTowerRange then
						--[[
								--positions help: https://forums.heroesofnewerth.com/showthread.php?480683-WORKING-Ward-Placement-Snippet-%28-WardSpots-coords%29&p=15560684&viewfull=1#post15560684
								thanks fane_maciuca for collecting the positions
						]]--
						local unitFlyingPos = unitFlying:GetPosition()
						local VecPointOne = nil
						local VecPointTwo = nil

						if core.tMyLane.sLaneName == 'top' and unitFlying:GetBehavior() == nil then
							 VecPointOne = Vector3.Create(6017.0605,10072.7637) -- Top rune
							 VecPointTwo = Vector3.Create(5013.7031,12865.3242) -- Top pull
						elseif core.tMyLane.sLaneName == 'middle' and unitFlying:GetBehavior() == nil then
							 VecPointOne = Vector3.Create(10829.2061,5088.8584) -- Bot rune
							 VecPointTwo = vecUnitSelf
						elseif core.tMyLane.sLaneName == 'bottom'  and unitFlying:GetBehavior() == nil  then
							 VecPointOne = Vector3.Create(10829.2061,5088.8584) -- Bot rune
							 VecPointTwo =   Vector3.Create(13423.2822,2856.9995) --Bot jungle
						end
						
						if VecPointOne ~= nil and VecPointTwo ~= nil then
							if Vector3.Distance2DSq(unitFlyingPos,VecPointOne) > Vector3.Distance2DSq(unitFlyingPos,VecPointTwo) then
								core.OrderMoveToPos(botBrain, unitFlying, VecPointOne)
							else
								core.OrderMoveToPos(botBrain, unitFlying, VecPointTwo)
							end
						end
					 
					--end
				
				end
				if  unitType=="Pet_Tundra_Ability2_Ranged" then --Coeurl
					unitCoeurl = unit
					local unitCoeurlPos = unitCoeurl:GetPosition()
					 
					--if unitCoeurl:GetBehavior() == nil then
						local nDistance = Vector3.Distance2DSq(unitCoeurlPos,vecUnitSelf)
						 if nDistance > 200*200 and nDistance < 500*500 then
							--nothing do to, he should be in the right position
						else 
							core.OrderMoveToPos(botBrain, unitCoeurl, positionOffset(vecUnitSelf,-90,350))
						end
					--end
				end
				
				if unitType == "Pet_NecroMelee" then 
					unitNecroMelee = unit
					local unitNecroMeleePos = unitNecroMelee:GetPosition()
					--if unitNecroMelee:GetBehavior() == nil then
						local nDistance = Vector3.Distance2DSq(unitNecroMeleePos,vecUnitSelf)
						if nDistance > 200*200 and nDistance < 500*500 then
							--nothing do to, he should be in the right position
						else 
							core.OrderMoveToPos(botBrain, unitNecroMelee, positionOffset(vecUnitSelf,0,250))
						end

					--end
				end
				
				if  unitType =="Pet_NecroRanged" then 
					unitNecroRanged = unit
					local unitNecroRangedPos = unitNecroRanged:GetPosition()
					--if unitNecroRanged:GetBehavior() == nil then
						local nDistance = Vector3.Distance2DSq(unitNecroRangedPos,vecUnitSelf)
						if nDistance > 200*200 and nDistance < 500*500 then
							--nothing do to, he should be in the right position
						else 
							core.OrderMoveToPos(botBrain, unitNecroRanged, positionOffset(vecUnitSelf,90,250))
						end
					--end
				end
				
				
			end
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride




----------------------------------------------

--            OncombatEvent Override        --
-- Use to check for Infilictors (fe. Buffs) --
----------------------------------------------
-- @param: EventData
-- @return: none 
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)

    local nAddBonus = 0

    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Tundra1" then
            nAddBonus = nAddBonus + object.nPiercingShardsUse
        elseif EventData.InflictorName == "Ability_Tundra2" then
            nAddBonus = nAddBonus + object.nCallofWinterUse        
		elseif EventData.InflictorName == "Ability_Tundra3" then
            nAddBonus = nAddBonus + object.nColdShoulderUse
        elseif EventData.InflictorName == "Ability_Tundra4" then
            nAddBonus = nAddBonus + object.nAvalancheUse
        end
	end
	
   if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride


----------------------------------
--  RetreatFromThreat Override
----------------------------------
object.nRetreatStealthThreshold = 50

--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes
function funcRetreatFromThreatExecuteOverride(botBrain)
	
	--powersupply is good for escape
	local unitSelf = core.unitSelf
	if itemPowerSupply and itemPowerSupply:CanActivate() then
		if  unitSelf:GetHealth() ~= unitSelf:GetMaxHealth() then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemPowerSupply)
		end
	end
	
		--if we have animals, make them hit the attackers. the dog slows so it will help a lot 
	if unitCoeurl ~= nil or unitNecroMelee ~= nil or unitNecroRanged ~= nil then 
		local vecUnitSelf = unitSelf:GetPosition()
		local dClosestUnitDist = 5000
		local unitClosest = nil
		local dCurrentDist = nil
		local tTargets = core.localUnits["EnemyHeroes"]
		 		for key, hero in pairs(tTargets) do
						dCurrentDist = Vector3.Distance2DSq(vecUnitSelf, hero:GetPosition())
					if  dCurrentDist < dClosestUnitDist then
						unitClosest = hero
						dClosestUnitDist = dCurrentDist
					end
				end
				
			if dClosestUnitDist ~= 5000 then
				if unitCoeurl ~= nil then
					core.OrderAttackClamp(botBrain, unitCoeurl, unitClosest)
				end
				if unitNecroMelee ~= nil then
					core.OrderAttackClamp(botBrain, unitNecroMelee, unitClosest)
				end
				if  unitNecroRanged ~= nil then
					core.OrderAttackClamp(botBrain, unitNecroRanged, unitClosest)
				end
			end
	end
	
	
		return object.RetreatFromThreatExecuteOld(botBrain)
	

end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride




------------------------------------------------------
--            CustomHarassUtility Override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)

    local nUtil = 0
    
    if skills.abilQ:CanActivate() then
        nUtil = nUtil + object.nPiercingShardsUp
    end

    if skills.abilW:CanActivate() then
        nUtil = nUtil + object.nCallofWinterUp
    end

    if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nColdShoulderUp
    end

	if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nAvalancheUp
    end
	
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemPowerSupply ~= nil and not core.itemPowerSupply:IsValid() then
		core.itemPowerSupply = nil
	end
	if core.itemPuzzleBox ~= nil and not core.itemPuzzleBox:IsValid() then
		core.itemPuzzleBox = nil
	end

	if bUpdated then
		--only update if we need to
		if core.itemPuzzleBox and core.itemPowerSupply then
			return
		end
		
	 
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemPuzzleBox == nil and curItem:GetName() == "Item_Summon" then
					core.itemPuzzleBox = core.WrapInTable(curItem)

				elseif core.itemPowerSupply == nil and ( curItem:GetName() == "Item_PowerSupply" or curItem:GetName() == "Item_ManaBattery") then
					--they will be fine. i will use then when they have charges and the hero needs hp/mana. so the number of the charges is unnecessary to store
					core.itemPowerSupply = core.WrapInTable(curItem)
				end
			end
		end
	end
	
	
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

-- magic immunity
local function IsMagicImmune(unit)
  local states = { "State_Item3E",
                   "State_Predator_Ability2",
                   "State_Jereziah_Ability2",
                   "State_Rampage_Ability1_Self",
                   "State_Rhapsody_Ability4_Buff",
                   "State_Hiro_Ability1" }

  for _, state in ipairs(states) do
	if unit:HasState(state) then return true end
  end
  return false
end

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)  --Target is invalid, move on to the next behavior
    end
    
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bActionTaken = false

	--Mana/Hp is good in action
	local itemPowerSupply = core.itemPowerSupply
	if itemPowerSupply and itemPowerSupply:CanActivate() then
		if unitSelf:GetMana() ~= unitSelf:GetMaxMana() or unitSelf:GetHealth() ~= unitSelf:GetMaxHealth() then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemPowerSupply)
		end
	end
		
 	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
		local bTargetIsMagicImmune = IsMagicImmune(unitTarget)
        local abilColdShoulder = skills.abilW
		local abilAvalanche = skills.abilR
		
		-- Ult stun
        if not bActionTaken and not bTargetVuln  and not bTargetIsMagicImmune then            
            if abilAvalanche:CanActivate() and nLastHarassUtility > object.nAvalancheThreshold then
				local nAvalancheRange = abilAvalanche:GetRange()
				if nTargetDistanceSq < (nAvalancheRange*nAvalancheRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilAvalanche, unitTarget)
				else
                    bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end 
        end
 
    end

	  -- abilColdShoulder
    if core.CanSeeUnit(botBrain, unitTarget) then
        local abilColdShoulder = skills.abilE
        if not bActionTaken then  
            if abilColdShoulder:CanActivate() and nLastHarassUtility > botBrain.nColdShoulderThreshold then
                local nRange = abilColdShoulder:GetRange()
				--need some distance, else it's just a waste of mana
                if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > (200*200)  then
        		    bActionTaken = core.OrderAbilityEntity(botBrain, abilColdShoulder, unitTarget)
                else
                    --bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end
        end  
    end  

     -- PiercingShards
	 -- they have 1300 range. let's not cast when the hero is more than 1100 away
    if not bActionTaken then
		--if core.CanSeeUnit(botBrain, unitTarget) then
			local abilPiercingShards = skills.abilQ
			if abilPiercingShards:CanActivate() and nLastHarassUtility > botBrain.nPiercingShardsThreshold then
				local nRange = abilPiercingShards:GetRange() 
				
				if nTargetDistanceSq < ((nRange - 200)*(nRange - 200)) then
					-- we need a bigger range now, so let's calculate a bit
					--vecTargetPosition is the target, who is in the desired range
					 local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
					local vecAbilityTarget = vecMyPosition + vecToward * nRange
					bActionTaken = core.OrderAbilityPosition(botBrain, abilPiercingShards,vecAbilityTarget)
				else
					--bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
				end
			end
		--end
    end 

	--Spawning the puzzlebox and skill
		if not bActionTaken and core.itemPuzzleBox ~= nil then
			local itemPuzzleBox = core.itemPuzzleBox
			if itemPuzzleBox and itemPuzzleBox:CanActivate() then
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemPuzzleBox)
			end
		end
	
		if not bActionTaken then
			local abilCallofWinter = skills.abilW
				if abilCallofWinter:CanActivate() and unitFlying == nil and unitCoeurl == nil then
						bActionTaken = core.OrderAbility(botBrain, abilCallofWinter)
				end
		end  

	--Unit control	
		if unitCoeurl ~= nil then
			core.OrderAttackClamp(botBrain, unitCoeurl, unitTarget)
		end
		
		if unitNecroMelee ~= nil then
			core.OrderAttackClamp(botBrain, unitNecroMelee, unitTarget)
		end

		if unitNecroRanged ~= nil then
			core.OrderAttackClamp(botBrain, unitNecroRanged, unitTarget)
		end
    
    if not bActionTaken then
        return object.harassExecuteOld(botBrain) 
    end 
end



-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride