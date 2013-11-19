Script.Load("lua/Class.lua")
Script.Load("lua/MM.lua")

-- Matchmaking Menu
local MatchmakingPollTimer = 0
local MatchmakingQueued = false

function CreateMatchmakingPage(self)
    
    MM.Debug("CreateMatchmakingPage")

    self.matchmakingWindow = self:CreateWindow()
    self.matchmakingWindow:SetWindowName("MATCHMAKING")
    self.matchmakingWindow:SetInitialVisible(false)
    self.matchmakingWindow:SetIsVisible(false)
    self.matchmakingWindow:DisableResizeTile()
    self.matchmakingWindow:DisableSlideBar()
    self.matchmakingWindow:DisableContentBox()
    self.matchmakingWindow:SetCSSClass("playnow_window")
    self.matchmakingWindow:DisableCloseButton()
    
    self.matchmakingWindow.UpdateLogic = UpdateMatchmakingWindowLogic
    
    local eventCallbacks =
    {
        OnShow = function(self)
            MM.Log("On Show")
            self.scriptHandle:OnWindowOpened(self)
            MainMenu_OnWindowOpen()
        end,
        
        OnHide = function(self)
            MM.Log("Leaving queue")
            self.scriptHandle:OnWindowClosed(self)
        end
    }
    self.matchmakingWindow:AddEventCallbacks(eventCallbacks)
    
    self.matchmakingWindow.searchingForGameText = CreateMenuElement(self.matchmakingWindow.titleBar, "Font", false)
    self.matchmakingWindow.searchingForGameText:SetCSSClass("playnow_title")
    self.matchmakingWindow.searchingForGameText:SetText("SEARCHING...")
    
    local cancelButton = CreateMenuElement(self.matchmakingWindow, "MenuButton")
    cancelButton:SetCSSClass("playnow_cancel")
    cancelButton:SetText("CANCEL")
    
    cancelButton:AddEventCallbacks({ OnClick = function() 
        self.matchmakingWindow:SetIsVisible(false) 
    end })
    
end

function UpdateMatchmaking(matchmakingWindow)
    if Shared.GetTime() - MatchmakingPollTimer >= 3 then
        MatchmakingPollTimer = Shared.GetTime()

        local endpoint = ""
        local data = {}

        if (MatchmakingQueued) then
            endpoint = "/queue/update"
            data = {
                steamid = Client.GetSteamId()
            }
        else
            endpoint = "/queue/join"
            data = {
                steamid = Client.GetSteamId(),
                name = OptionsDialogUI_GetNickname()
            }
            MatchmakingQueued = true
        end
        
        MM.Debug("API Call: " .. MM.kApiRootUrl .. endpoint)
        MM.Debug("Sending request with data: " .. json.encode(data))
        Shared.SendHTTPRequest(MM.kApiRootUrl .. endpoint, "POST", data, function(response)
            MM.Debug("Queue response: " .. response)
            res = json.decode(response)
            if res ~= nil and res.match.active then
                MM.ParseMatch(res)
                MainMenu_SBJoinServer(res.match.server.ip .. ":" .. tostring(res.match.server.port), res.match.server.password)
            end
        end )
    end
    
end

function UpdateMatchmakingWindowLogic(matchmakingWindow, mainMenu)

    PROFILE("GUIMainMenu:UpdateMatchmakingWindowLogic")
    
    if matchmakingWindow:GetIsVisible() then
    
        matchmakingWindow.searchingForGameText.animateTime = matchmakingWindow.searchingForGameText.animateTime or Shared.GetTime()
        if Shared.GetTime() - matchmakingWindow.searchingForGameText.animateTime > 0.85 then
        
            matchmakingWindow.searchingForGameText.animateTime = Shared.GetTime()
            matchmakingWindow.searchingForGameText.numberOfDots = matchmakingWindow.searchingForGameText.numberOfDots or 3
            matchmakingWindow.searchingForGameText.numberOfDots = matchmakingWindow.searchingForGameText.numberOfDots + 1
            if matchmakingWindow.searchingForGameText.numberOfDots > 3 then
                matchmakingWindow.searchingForGameText.numberOfDots = 0
            end
            
            matchmakingWindow.searchingForGameText:SetText("SEARCHING" .. string.rep(".", matchmakingWindow.searchingForGameText.numberOfDots))
            
        end
        
        UpdateMatchmaking(matchmakingWindow)
        
    end
    
end