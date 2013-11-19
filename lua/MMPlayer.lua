Script.Load('lua/MM.lua')

class 'MMPlayer'

function MMPlayer:OnCreate(steamid, team)
    Shared.Message("MMPlayer:OnCreate")
    self.steamid = nil
    self.name = nil
    self.clientid = nil
    self.connected = false
    self.team = nil
end

function MMPlayer:GetSteamId()
    return self.steamid
end

function MMPlayer:IsConnected()
    return self.connected
end   

function MMPlayer:GetTeam()
    return self.team
end

function MMPlayer:GetName()
    return self.name
end    

function MMPlayer:GetClient()
    MM.Debug("Getting client with steamid " .. self.steamid)
    if not self.connected then
        return nil
    end
    
    return Server.GetClientById(self.clientid)
end

function MMPlayer:SetConnectedClient(client)
    MM.Debug("Player " .. self.steamid .. " is connected with client id " .. client:GetId())
    self.clientid = client:GetId()
    self.connected = true
end

function MMPlayer:ClientDisconnected()
    MM.Debug("Player " .. self.steamid .. " is no longer connected")
    self.clientid = nil
    self.connected = false
end