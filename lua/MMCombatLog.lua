Script.Load("lua/MM.lua")

if Server then
	MM.kCombatEvents = {}

	-- MM.LogEvent
	function MM.LogEvent(event)
		if MM.kDebug then
			MM.Log("LogEvent " .. json.encode(event))
		end

		table.insert(MM.kCombatEvents, event)
	end

	local function GetUpgradeAttribsString(ent)

	    local out = ""

	    if HasMixin( ent, "Upgradable" ) then

	        local ups = ent:GetUpgradeList()

	        for i = 1,#ups do
	            out = out .. TechIdToUpgradeCode(ups[i])
	        end
	    end

	    if ent:isa("Marine") then
	        out = out .. string.format("W%dA%d", ent:GetWeaponLevel(), ent:GetArmorLevel() )
	    end

	    return out

	end

	-- OnEntityKilled
	local originalOnEntityKilled = NS2Gamerules.OnEntityKilled
	function NS2Gamerules:OnEntityKilled(target, attacker, weapon, point, direction)
	    originalOnEntityKilled(self, target, attacker, weapon, point, direction)

	    -- Don't log kills until round has started and if we have an attacker, target, and weapon
	    if not MM.kRoundStarted and not attacker or not target or not weapon then
	        return
	    end

        local targetWeapon = "None"
        
        if target.GetActiveWeapon and target:GetActiveWeapon() then
            targetWeapon = target:GetActiveWeapon():GetClassName()
        end

	    local targetId = (target:isa("Player") and Server.GetClientById(target:GetClientIndex()):GetUserId()) or -1
	    local attackerId = (attacker:isa("Player") and Server.GetClientById(attacker:GetClientIndex()):GetUserId()) or -1
        local attackerTeamType = ((HasMixin(attacker, "Team") and attacker:GetTeamType()) or kNeutralTeamType)

        MM.LogEvent({
        	type = "kill",
        	time = Shared.GetGMTString(false),
            attackerClass = attacker:GetClassName(),
            attackerTeam = attackerTeamType,
            attackerWeapon = weapon:GetClassName(),
            attackerAttrs = GetUpgradeAttribsString(attacker),
        	attacker = attackerId,
        	target = targetId,
            targetClass = target:GetClassName(),
            targetTeam = target:GetTeamType(),
            targetWeapon = targetWeapon,
            targetAttrs = GetUpgradeAttribsString(target),
        })
	end

	-- LogJoinTeam
	function MM.LogJoinTeam(steamid, teamNumber)
		MM.LogEvent({
			type = "join_team",
        	time = Shared.GetGMTString(false),
			steamid = steamid,
			team = teamNumber
		})
	end

	-- LogPlayerConnected
	function MM.LogPlayerConnected(steamid)
		MM.LogEvent({
			type = "player_connected",
        	time = Shared.GetGMTString(false),
        	steamid = steamid,
			team = teamNumber
		})
	end

	-- LogPlayerDisconnected
	function MM.LogPlayerDisconnected(steamid)
		MM.LogEvent({
			type = "player_disconnected",
			steamid = steamid,
			team = teamNumber
		})
	end

	-- LogMatchStart
	function MM.LogRoundStart(round)
	    MM.LogEvent({
	    	type = "start_round",
	        time = Shared.GetGMTString(false),
	        round = round,
	        map = Shared.GetMapName(),
	    })
	end

	-- LogEndMatch
	function MM.LogRoundEnd(round, winningTeamNumber)
		MM.LogEvent({
			type = "end_round",
            time = Shared.GetGMTString(false),
            round = round,
            winner = winningTeamNumber
        })
	end
end