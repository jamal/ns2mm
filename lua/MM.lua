Script.Load('lua/MMPlayer.lua')

class 'MM'

MM.kPlayers = {}
MM.kForBuild = 259
MM.kEnabled = true
MM.kDebug = true
--MM.kApiRootUrl = "http://162.243.30.212"
MM.kApiRootUrl = "http://10.0.1.36:8000"

MM.kEndGameSocializeTime = 10
MM.kCurrentRound = 1
MM.kCurrentMatchId = nil
MM.kMatchActive = false
MM.kRoundStarted = false
MM.kMatchEnded = false
-- MatchReady will be set when all players join the match
MM.kMatchReady = true

function MM.Debug(message)
    if MM.kDebug then
        MM.Log(message)
    end
end

function MM.Log(message)
    Shared.Message("[MM] " .. message)
end

function MM.Say(message)
    Server.SendNetworkMessage("Chat", BuildChatMessage(false, "NS2MM", -1, kTeamReadyRoom, kNeutralTeamType, message), true)
end

function MM.AddPlayer(steamid, name, team)
    MM.Debug("Adding player " .. tostring(steamid) .. " to team " .. tostring(team))
    local p = MMPlayer()
    p.team = team
    p.name = name
    p.steamid = steamid
    MM.kPlayers[steamid] = p
end

function MM.ParseMatch(res, callback)
    MM.kMatchActive = res.match.active
    
    if MM.kMatchActive then
        MM.kCurrentRound = 1
        MM.kCurrentMatchId = res.match.id
        if res.match.team1 ~= nil then
            for i, p in ipairs(res.match.team1) do
                MM.AddPlayer(p.steamid, p.name, 1)
            end
        end
        if res.match.team2 ~= nil then
            for i, p in ipairs(res.match.team2) do
                MM.AddPlayer(p.steamid, p.name, 2)
            end
        end
    end

    if type(callback) == 'function' then
        callback()
    end
end