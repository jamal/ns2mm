Script.Load("lua/Class.lua")
Script.Load("lua/Server.lua")
Script.Load("lua/MM.lua")
Script.Load("lua/MMCombatLog.lua")

MM.kUpdateTime = 0

local configFileName = "MMServerConfig.json"
local defaultConfig = {
    token = null
}
WriteDefaultConfigFile(configFileName, defaultConfig)

local config = LoadConfigFile(configFileName) or defaultConfig

function MM.GetPlayer(steamid)
    local p = MM.kPlayers[steamid]
    if p == nil then
        return nil
    end
    
    return p
end
    
function MM.GetPlayerTeam(steamid)
    local p = MM.GetPlayer(steamid)
    if p == nil then
        return p
    end
    
    return p:GetTeam()
end

-- Get the player team for the current round
function MM.GetRoundTeam(team)
    if MM.kCurrentRound == 1 then
        return team
    else
        if team == 1 then
            return 2
        else
            return 1
        end
    end
end

function MM.MovePlayerToTeam(player)
    if player ~= nil then
        local team = MM.GetRoundTeam(player:GetTeam())
        
        MM.Log("Moving player " .. tostring(player.steamid) .. " to team " .. tostring(team) .. " for round " .. MM.kCurrentRound)
        
        if team == 1 then
            Server.ClientCommand(player:GetClient():GetControllingPlayer(), "jointeamone")
        else
            Server.ClientCommand(player:GetClient():GetControllingPlayer(), "jointeamtwo")
        end
    end
end

function MM.ClientConnected(client)
    local p = MM.kPlayers[client:GetUserId()]
    if p == nil then
        return nil
    end
    
    MM.Say(p:GetName() .. " has connected")
    
    p:SetConnectedClient(client)
    return p
end

function MM.CheckConnectedClient(client)
    -- Check if the player is in the match
    local p = MM.ClientConnected(client)
    if p == nil and not MM.kDebug then
        MM.Log("Kicked client " .. tostring(client:GetUserId()) .. " because he is not in the match")
        Server.DisconnectClient(client)
        return
    end
    
    MM.MovePlayerToTeam(p)
end

function MM.SendEndMatch()
    Shared.SendHTTPRequest(MM.kApiRootUrl .. "/api/match", "POST", { status = "end" })
end

function MM.ServerUpdate(callback)
    if not MM.kMatchActive then
        -- Send server status and check for a match
        local data = {
            --startTime = Shared.GetGMTString(false),
            name = Server.GetName(),
            ip = IPAddressToString(Server.GetIpAddress()),
            port = Server.GetPort(),
            version = Shared.GetBuildNumber(),
            token = config.token
        }
        Shared.SendHTTPRequest(MM.kApiRootUrl .. "/server/update", "POST", data, function(response)
            MM.Debug("Match data " .. response)
            res = json.decode(response)
            if res ~= nil then
                MM.ParseMatch(res, callback)
            end
        end )
    elseif MM.kCurrentMatchId ~= nil then
        -- Match is running, send logs
        if table.getn(MM.kCombatEvents) > 0 then
            local events = MM.kCombatEvents
            MM.kCombatEvents = {}

            local data = {
                token = config.token,
                match = MM.kCurrentMatchId,
                events = json.encode(events)
            }
            Shared.SendHTTPRequest(MM.kApiRootUrl .. "/match/update", "POST", data, function(response)
                MM.Debug("Server response " .. response)
            end )
        end
    end
end

-- Fetch match data if we have no active match
-- If the player is not in the active match, or there is no active match, kick the player
-- If the player is in in the active match, then move him to the proper team
local function OnClientConnect(client)
    MM.Log("Client " .. tostring(client:GetUserId()) .. " connected")
    MM.LogPlayerConnected(client:GetUserId())
    
    if not MM.kMatchActive then
        MM.ServerUpdate(function ()
            if MM.kMatchActive then
                MM.CheckConnectedClient(client)
            else
                if not MM.kDebug then
                    MM.Log("Kicked client " .. tostring(client:GetUserId()) .. " because there is no active match")
                    Server.DisconnectClient(client)
                end
            end            
        end )
    else
        MM.CheckConnectedClient(client)
    end
end
Event.Hook("ClientConnect", OnClientConnect)

local function OnClientDisconnect(client)
    MM.Log("Client " .. tostring(client:GetUserId()) .. " disconnected")
    MM.LogPlayerDisconnected(client:GetUserId())

    local p = MM.GetPlayer(client:GetUserId())
    if p ~= nil then
        MM.Say(p:GetName() .. " has disconnected")
        p:ClientDisconnected()
    end
    
    if MM.kMatchActive and Server.GetNumPlayers() <= 1 then
        MM.Log("Match was abandoned")
    end
end
Event.Hook("ClientDisconnect", OnClientDisconnect)

local originalJoinTeam = NS2Gamerules.JoinTeam
function NS2Gamerules:JoinTeam(player, newTeamNumber, force)
    if player ~= nil then
        if not MM.kMatchEnded and newTeamNumber == kTeamReadyRoom then
            newTeamNumber = MM.GetRoundTeam(MM.GetPlayerTeam(player:GetClient():GetUserId()))
        elseif MM.kMatchEnded and newTeamNumber ~= kTeamReadyRoom then
            newTeamNumber = kTeamReadyRoom
        end
    end

    MM.LogJoinTeam(player:GetClient():GetUserId(), newTeamNumber)

    return originalJoinTeam(self, player, newTeamNumber, force)
end

function StartGame()
    Shared.Message("MM.StartGame")
    MM.Say("Round " .. tostring(MM.kCurrentRound) .. " of 2 has started")
    MM.LogRoundStart(MM.kCurrentRound)
    MM.kRoundStarted = true
end

function EndGame(winningTeam, losingTeam)
    Shared.Message("MM.EndGame")
    MM.Say("Round " .. tostring(MM.kCurrentRound) .. " of 2 has ended")
    MM.kRoundStarted = false

    MM.LogRoundEnd(MM.kCurrentRound, winningTeam:GetTeamNumber())
    
    -- Set the next round
    if MM.kCurrentRound == 1 then
        MM.kCurrentRound = 2
        MM.Say("Please stay for the next round...")
    else
        local data = {
            token = config.token,
            match = MM.kCurrentMatchId
        }
        Shared.SendHTTPRequest(MM.kApiRootUrl .. "/match/end", "POST", data, function(response)
            MM.Debug("Server response " .. response)
        end )

        MM.kMatchEnded = true
        MM.Say("Thank you for using the NS2 Matchmaking mod!")
        MM.Say("The server will be recycled in 2 minutes.")
    end
end

local originalCheckGameStart = NS2Gamerules.CheckGameStart
function NS2Gamerules:CheckGameStart()
    if (self:GetGameState() == kGameState.NotStarted or self:GetGameState() == kGameState.PreGame) and not MM.kMatchReady then
        return
    end
    
    originalCheckGameStart(self)
end

local originalUpdateMapCycle = NS2Gamerules.UpdateMapCycle
function NS2Gamerules:UpdateMapCycle()
    if self.timeToCycleMap ~= nil and Shared.GetTime() >= (self.timeToCycleMap - 3) then
        for k, p in pairs(MM.kPlayers) do
            local client = p:GetClient()
            if client ~= nil then
                MM.Log("Kicked client " .. tostring(client:GetUserId()) .. " because the match is over")
                Server.DisconnectClient(client)
            end
        end
    end
    
    originalUpdateMapCycle(self)
end

local originalSetGameState = NS2Gamerules.SetGameState
function NS2Gamerules:SetGameState(state)
    originalSetGameState(self, state)
    
    if state == kGameState.Started then
        StartGame()
    elseif state == kGameState.Team1Won or state == kGameState.Team2Won then    
        -- Disable map cycle for the first round
        if MM.kCurrentRound == 1 then
            self.timeToCycleMap = nil
        else
            self.timeToCycleMap = Shared.GetTime() + MM.kEndGameSocializeTime
        end
        
        local winningTeam = self.team1
        local losingTeam = self.team2
        
        if state == kGameState.Team2Won then
            winningTeam = self.team2
            losingTeam = self.team1
        end
        
        EndGame(winningTeam, losingTeam)
    end
end


local originalOnUpdate = NS2Gamerules.OnUpdate
function NS2Gamerules:OnUpdate(timePassed)
    originalOnUpdate(self, timePassed)

    if Shared.GetTime() - MM.kUpdateTime >= 10 then
        MM.kUpdateTime = Shared.GetTime()
        MM.ServerUpdate()
    end
end

-- Dial home
if not config.token then
    MM.Log("Registering NS2MM Server")
    -- Let the server know we exist
    local data = {
        name = Server.GetName(),
        ip = IPAddressToString(Server.GetIpAddress()),
        port = Server.GetPort(),
        version = Shared.GetBuildNumber(),
    }
    Shared.SendHTTPRequest(MM.kApiRootUrl .. "/server/register", "POST", data, function(response)
        MM.Debug("Register response: " .. response)
        res = json.decode(response)
        if res ~= nil and res.token then
            config.token = res.token
            SaveConfigFile(configFileName, config)
        end
    end )
else
    -- Let the server know we restarted
    local data = {
        name = Server.GetName(),
        ip = IPAddressToString(Server.GetIpAddress()),
        port = Server.GetPort(),
        version = Shared.GetBuildNumber(),
        token = config.token
    }
    Shared.SendHTTPRequest(MM.kApiRootUrl .. "/server/start", "POST", data)
end