
local ACF = ACF
local AmmoTypes = ACF.Classes.AmmoTypes
local Ammo, BulletData

local function CopySettings(Settings)
	local Copy = {}

	if Settings then
		for K, V in pairs(Settings) do
			Copy[K] = V
		end
	end

	return Copy
end

local function GetAmmoList(Class)
	local Result = {}

	for K, V in pairs(AmmoTypes) do
		if V.Unlistable then continue end
		if V.Blacklist[Class] then continue end

		Result[K] = V
	end

	return Result
end

local function AddPreview(Base, Settings, ToolData)
	if Settings.SuppressPreview then return end

	local Preview = Base:AddModelPreview()
	Preview:SetCamPos(Vector(45, 45, 30))
	Preview:SetHeight(120)
	Preview:SetFOV(50)

	if Ammo.AddAmmoPreview then
		Ammo:AddAmmoPreview(Preview, ToolData, BulletData)
	end

	hook.Run("ACF_AddAmmoPreview", Preview, ToolData, Ammo, BulletData)
end

local function AddControls(Base, Settings, ToolData)
	if Settings.SuppressControls then return end

	local RoundLength = Base:AddLabel()
	RoundLength:TrackClientData("Projectile", "SetText", "GetText")
	RoundLength:TrackClientData("Propellant")
	RoundLength:TrackClientData("Tracer")
	RoundLength:DefineSetter(function()
		local Text = "Round Length: %s / %s cm"
		local CurLength = BulletData.ProjLength + BulletData.PropLength + BulletData.Tracer
		local MaxLength = BulletData.MaxRoundLength

		return Text:format(CurLength, MaxLength)
	end)

	local Projectile = Base:AddSlider("Projectile Length", 0, BulletData.MaxRoundLength, 2)
	Projectile:SetClientData("Projectile", "OnValueChanged")
	Projectile:DefineSetter(function(Panel, _, _, Value, IsTracked)
		ToolData.Projectile = Value

		if not IsTracked then
			BulletData.Priority = "Projectile"
		end

		Ammo:UpdateRoundData(ToolData, BulletData)

		ACF.SetClientData("Propellant", BulletData.PropLength)

		Panel:SetValue(BulletData.ProjLength)

		return BulletData.ProjLength
	end)

	local Propellant = Base:AddSlider("Propellant Length", 0, BulletData.MaxRoundLength, 2)
	Propellant:SetClientData("Propellant", "OnValueChanged")
	Propellant:DefineSetter(function(Panel, _, _, Value, IsTracked)
		ToolData.Propellant = Value

		if not IsTracked then
			BulletData.Priority = "Propellant"
		end

		Ammo:UpdateRoundData(ToolData, BulletData)

		ACF.SetClientData("Projectile", BulletData.ProjLength)

		Panel:SetValue(BulletData.PropLength)

		return BulletData.PropLength
	end)

	if Ammo.AddAmmoControls then
		Ammo:AddAmmoControls(Base, ToolData, BulletData)
	end

	hook.Run("ACF_AddAmmoControls", Base, ToolData, Ammo, BulletData)

	-- We'll create the tracer checkbox after all the other controls
	if not Settings.SuppressTracer then
		local Tracer = Base:AddCheckBox("Tracer")
		Tracer:SetClientData("Tracer", "OnChange")
		Tracer:DefineSetter(function(Panel, _, _, Value)
			ToolData.Tracer = Value

			Ammo:UpdateRoundData(ToolData, BulletData)

			ACF.SetClientData("Projectile", BulletData.ProjLength)
			ACF.SetClientData("Propellant", BulletData.PropLength)

			Panel:SetText("Tracer : " .. BulletData.Tracer .. " cm")
			Panel:SetValue(ToolData.Tracer)

			return ToolData.Tracer
		end)
	else
		ACF.SetClientData("Tracer", false) -- Disabling the tracer, as it takes up spaces on ammo.
	end
end

local function AddInformation(Base, Settings, ToolData)
	if Settings.SuppressInformation then return end

	if Ammo.AddAmmoInformation then
		Ammo:AddAmmoInformation(Base, ToolData, BulletData)
	end

	hook.Run("ACF_AddAmmoInformation", Base, ToolData, Ammo, BulletData)
end

function ACF.GetCurrentAmmoData()
	return BulletData
end

function ACF.UpdateAmmoMenu(Menu, Settings)
	if not Ammo then return end

	local ToolData = ACF.GetAllClientData()
	local Base = Menu.AmmoBase

	BulletData = Ammo:ClientConvert(ToolData)
	Settings   = CopySettings(Settings)

	if Ammo.SetupAmmoMenuSettings then
		Ammo:SetupAmmoMenuSettings(Settings, ToolData, BulletData)
	end

	hook.Run("ACF_SetupAmmoMenuSettings", Settings, ToolData, Ammo, BulletData)

	Menu:ClearTemporal(Base)
	Menu:StartTemporal(Base)

	if not Settings.SuppressMenu then
		AddPreview(Base, Settings, ToolData)
		AddControls(Base, Settings, ToolData)
		AddInformation(Base, Settings, ToolData)
	end

	Base:AddLabel("This entity can be fully parented.")

	Menu:EndTemporal(Base)
end

function ACF.CreateAmmoMenu(Menu, Settings)
	Menu:AddTitle("Ammo Settings")

	local List = Menu:AddComboBox()

	local SizeX = Menu:AddSlider("Crate Width", 6, 96, 2)
	SizeX:SetClientData("CrateSizeX", "OnValueChanged")
	SizeX:DefineSetter(function(Panel, _, _, Value)
		Panel:SetValue(Value)

		return Value
	end)

	local SizeY = Menu:AddSlider("Crate Height", 6, 96, 2)
	SizeY:SetClientData("CrateSizeY", "OnValueChanged")
	SizeY:DefineSetter(function(Panel, _, _, Value)
		Panel:SetValue(Value)

		return Value
	end)

	local SizeZ = Menu:AddSlider("Crate Depth", 6, 96, 2)
	SizeZ:SetClientData("CrateSizeZ", "OnValueChanged")
	SizeZ:DefineSetter(function(Panel, _, _, Value)
		Panel:SetValue(Value)

		return Value
	end)

	local Base = Menu:AddCollapsible("Ammo Information")
	local Desc = Base:AddLabel()

	function List:LoadEntries(Class)
		ACF.LoadSortedList(self, GetAmmoList(Class), "Name")
	end

	function List:OnSelect(Index, _, Data)
		if self.Selected == Data then return end

		self.ListData.Index = Index
		self.Selected = Data

		Ammo = Data

		ACF.SetClientData("AmmoType", Data.ID)

		Desc:SetText(Data.Description)

		ACF.UpdateAmmoMenu(Menu, Settings)

		-- Best patch 2021
		ACF.SetClientData("Projectile", ACF.GetClientNumber("Projectile"), true)
	end

	Menu.AmmoBase = Base

	return List
end
