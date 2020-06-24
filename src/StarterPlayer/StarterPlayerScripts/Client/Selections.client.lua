--[[
	Notes:
	- None
--]]

-- // Services \\ --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- // Variables \\ --
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local InteractionKey = PlayerGui:WaitForChild("InteractionKey")

local Mouse = Player:GetMouse()

local KitchenFolder = Player:WaitForChild("KitchenFolder")

local ClientModules = script.Parent.Modules
local SharedModules = ReplicatedStorage.Modules

local Remotes = ReplicatedStorage.Remotes
local KitchenRemotes = Remotes.Kitchen
local Bindables = ReplicatedStorage.Bindables
local SelectionBindables = Bindables.Selections

local Assets = ReplicatedStorage.Assets
local KitchenAssets = Assets.Kitchen
local UserInterface = Assets.UserInterface

local Selection = require(ClientModules.Selection)
local ToolFunctions = require(SharedModules.ToolFunctions)
local Sound = require(ClientModules.Sound)
local Recipes = require(SharedModules.Recipes)

local Selectables = {}

local InRange = false
local ViewingOptions = false
local LastSelectable = nil

local ButtonDownEffect = false
local TweeningInteractive = false

local RANGE = 7
local SELECTION_COOLDOWN = 0.5
local KEY = Enum.KeyCode.E

-- // Functions \\ --
local function GetClosestSelectable() -- // Get array of selectables in range 
	local InRange = {}
	for _,v in pairs(Selectables) do
		if v.Selectable.Occupied.Value then continue end
		local mag = (v.PrimaryPart.Position-Player.Character.HumanoidRootPart.Position).Magnitude
		if (mag <= RANGE) and not inAction and not KitchenFolder.inAction.Value then
			table.insert(InRange, {Model = v, Mag = mag})			
		end
	end

	if #InRange > 0 then
		table.sort(InRange, function(a, b)
			return a.Mag < b.Mag
		end)
		return InRange[1].Model
	end

	return nil
end

local function SetupSelectables() --// Sorts all selectables into a table
	for _,v in pairs(workspace:GetDescendants()) do
		--if v:IsA("Model") then
			if v:FindFirstChild("Selectable") then
				table.insert(Selectables, v)
			end
		--end
	end
end

local function CloseInteractive()
	InRange = false
	LastSelectable = nil
	local t = TweenService:Create(
		InteractionKey.Main.Interactive.UIScale, 
		TweenInfo.new(0.1, Enum.EasingStyle.Linear),
		{
			Scale = 0
		}
	)
	TweeningInteractive = true
	t:Play()
	t.Completed:Connect(function() 
		InteractionKey.Adornee = nil
		TweeningInteractive = false
	end)
end

local function CreateOptions(optionsDict)
	if ViewingOptions then print("already viewing options") return end
	ViewingOptions = true
	InteractionKey.Main.Options.UIScale.Scale = 0
	InteractionKey.Main.Interactive.UIScale.Scale = 0

	for name, callback in pairs(optionsDict) do
		local Option = InteractionKey.OptionTemplate:Clone()
		Option.Tween.Text = name
		Option.Parent = InteractionKey.Main.Options
		Option.Visible = true
		Option.MouseButton1Click:Connect(callback)
		print("created option ", name)
	end

	-- // Elastic Effect \\ --
	TweenService:Create(
		InteractionKey.Main.Options.UIScale, 
		TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{
			Scale = 1
		}
	):Play()
	print("tweened")
end

local function DestroyOptions()
	local t = TweenService:Create(
		InteractionKey.Main.Options.UIScale, 
		TweenInfo.new(0.1, Enum.EasingStyle.Linear),
		{
			Scale = 0
		}
	)
	t:Play()
	t.Completed:Connect(function()
		for _,option in pairs(InteractionKey.Main.Options:GetChildren()) do
			if option.Name == "OptionTemplate" then
				option:Destroy()
				print("Destroyed option")
			end
		end
		ViewingOptions = false
	end)
end

-- // Main \\ --
SetupSelectables()

UserInputService.InputBegan:Connect(function(Input, GameProcessed) -- // On Key pressed
	if GameProcessed or TweeningInteractive then return end
	if Input.KeyCode == KEY then
		local closestSelectable = GetClosestSelectable()
		if closestSelectable then
			local selectable = closestSelectable.Selectable
			if selectable.Occupied.Value == false then
				SelectionBindables[selectable.Bindable.Value]:Fire(selectable)
			end

			-- // Button Down Effect \\ --
			if not ButtonDownEffect then
				ButtonDownEffect = true
				local ButtonDownTween = TweenService:Create(
					InteractionKey.Main.Interactive.Label,
					TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, true),
					{
						Position = UDim2.fromScale(0, 0)
					}
				)
				ButtonDownTween:Play()
				ButtonDownTween.Completed:Connect(function()
					ButtonDownEffect = false
				end)
			end
		end
	end
end)

RunService.RenderStepped:Connect(function() -- // Selectable effect handler
	if not Player.Character then
		return
	end

	local closestSelectable = GetClosestSelectable()
	if closestSelectable then -- // Tween In
		InteractionKey.Adornee = closestSelectable.PrimaryPart
		if not InRange or LastSelectable ~= closestSelectable then
			if ViewingOptions then
				print("Destroyed!")
				DestroyOptions()
			end
			LastSelectable = closestSelectable
			InRange = true
			Sound:Add(424002310, 1, 1)
			InteractionKey.Main.Interactive.UIScale.Scale = 0
			local t = TweenService:Create(
				InteractionKey.Main.Interactive.UIScale, 
				TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
				{
					Scale = 1
				}
			)
			TweeningInteractive = true
			t:Play()
			t.Completed:Connect(function()
				TweeningInteractive = false
			end)
		end
	else -- // Tween Out
		if InRange then		
			DestroyOptions()
			CloseInteractive()
		end
	end
end)

-- // Selection Events \\ --
SelectionBindables.Eggs.Event:Connect(function()
	local Tools = ToolFunctions.GetTools(Player)
	if ToolFunctions.FindToolFromName(Tools, "Eggs") == nil then
		KitchenRemotes.GiveEggs:FireServer()
	end
end)

SelectionBindables.Flour.Event:Connect(function()
	local Tools = ToolFunctions.GetTools(Player)
	if ToolFunctions.FindToolFromName(Tools, "Flour") == nil then
		KitchenRemotes.GiveFlour:FireServer()
	end
end)

SelectionBindables.Vanilla.Event:Connect(function()
	local Tools = ToolFunctions.GetTools(Player)
	if ToolFunctions.FindToolFromName(Tools, "Vanilla Extract") == nil then
		KitchenRemotes.GiveVanilla:FireServer()
	end
end)

SelectionBindables.OvenOptions.Event:Connect(function()
	local OptionsDict = {
		["Stove"] = function()
			DestroyOptions()
		end,

		["Oven"] = function()
			DestroyOptions()
		end
	}


	CreateOptions(OptionsDict)
	print("Created options")
end)

SelectionBindables.Mix.Event:Connect(function(Selected)
	local Tools = ToolFunctions.GetTools(Player)

	local function ChooseRecipe(food)
		KitchenRemotes.Mix:FireServer(Selected, food)
	end

	if Tools then
		local AvailableRecipes = Recipes.FindRecipes("Mixing Bowl", Tools)
		if AvailableRecipes ~= nil then -- // Makes sure they have the tools to mix something 
			inAction = true
			local UI = UserInterface.MixUI:Clone()

			local function Close() -- // Closes mixing UI
				UI.Main:TweenPosition(
					UDim2.new(0.345, 0, 1.231, 0), 
					"Out", 
					"Linear", 
					0.3, 
					false, 
					function()
						UI:Destroy()
						inAction = false
					end
				)	
			end

			for food, content in pairs(AvailableRecipes) do
				UI.Main.ScrollingFrame.CanvasSize = UDim2.new(
					0, 
					0, 
					UI.Main.ScrollingFrame.CanvasSize.Y.Scale + 0.03,
					0
				)

				local Template = UI.Template:Clone()
				Template.RecipeLabel.Text = food
				Template.Visible = true
				Template.Parent = UI.Main.ScrollingFrame
				Template.Choose.MouseButton1Click:Connect(function()
					ChooseRecipe(food)
					Close()
				end)
			end

			UI.Parent = Player.PlayerGui
			UI.Main:TweenPosition(UDim2.new(0.345, 0, 0.231, 0), "In", "Linear", 0.3)
			UI.Main.Close.MouseButton1Click:Connect(Close)			
		end
	end
end)