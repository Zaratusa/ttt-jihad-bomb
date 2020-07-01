--[[Author informations]]--
SWEP.Author = "Zaratusa"
SWEP.Contact = "http://steamcommunity.com/profiles/76561198032479768"

CreateConVar("ttt_jihad_buyable", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Jihad Bomb be buyable for Traitors?")
CreateConVar("ttt_jihad_inloadout", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the Jihad Bomb be in the loadout for Traitors?")

local sound = CreateConVar("ttt_jihad_sound", "weapons/jihad_bomb/jihad.wav", {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "The sound when starting the Jihab Bomb.")

if SERVER then
	AddCSLuaFile()
	resource.AddWorkshop("254177214")
else
	LANG.AddToLanguage("english", "jihad_bomb_name", "Jihad Bomb")
	LANG.AddToLanguage("english", "jihad_bomb_desc", "Sacrifice yourself to Allah.\nYour 72 virgins await.\n\nNOTE: No refund after use.")

	SWEP.PrintName = "jihad_bomb_name"
	SWEP.Slot = 8
	SWEP.Icon = "vgui/ttt/icon_jihad_bomb"

	-- Equipment menu information is only needed on the client
	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "jihad_bomb_desc"
	}

	hook.Add("TTT2ScoreboardAddPlayerRow", "TTTJihadBomb", function(ply)
		local ID64 = ply:SteamID64()
		local ID64String = tostring(ID64)

		if (ID64String == "76561198032479768") then
			AddTTT2AddonDev(ID64)
		end
	end)
end

-- always derive from weapon_tttbase
SWEP.Base = "weapon_tttbase"

--[[Default GMod values]]--
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 5
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false

--[[Model settings]]--
SWEP.HoldType = "slam"

SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54
SWEP.ViewModel = Model("models/weapons/zaratusa/jihad_bomb/v_jb.mdl")
SWEP.WorldModel = Model("models/weapons/zaratusa/jihad_bomb/w_jb.mdl")

--[[TTT config values]]--

-- Kind specifies the category this weapon is in. Players can only carry one of
-- each. Can be: WEAPON_... MELEE, PISTOL, HEAVY, NADE, CARRY, EQUIP1, EQUIP2 or ROLE.
-- Matching SWEP.Slot values: 0      1       2     3      4      6       7        8
SWEP.Kind = WEAPON_ROLE

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2,
-- then this gun can be spawned as a random weapon.
SWEP.AutoSpawnable = false

if (GetConVar("ttt_jihad_buyable"):GetBool()) then
	-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
	-- a role is in this table, those players can buy this.
	SWEP.CanBuy = { ROLE_TRAITOR }

	-- If LimitedStock is true, you can only buy one per round.
	SWEP.LimitedStock = true
end

if (GetConVar("ttt_jihad_inloadout"):GetBool()) then
	-- InLoadoutFor is a table of ROLE_* entries that specifies which roles should
	-- receive this weapon as soon as the round starts.
	SWEP.InLoadoutFor = { ROLE_TRAITOR }
end

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = false

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = true

-- precache sounds and models
function SWEP:Precache()
	util.PrecacheSound("weapons/jihad_bomb/jihad.wav")
	util.PrecacheSound("weapons/jihad_bomb/big_explosion.wav")

	util.PrecacheModel("models/humans/charple01.mdl")
	util.PrecacheModel("models/humans/charple02.mdl")
	util.PrecacheModel("models/humans/charple03.mdl")
	util.PrecacheModel("models/humans/charple04.mdl")
end

function SWEP:Initialize()
	if (CLIENT and self:Clip1() == -1) then
		self:SetClip1(self.Primary.DefaultClip)
	elseif SERVER then
		self.fingerprints = {}
	end

	self:SetDeploySpeed(self.DeploySpeed)

	if (self.SetHoldType) then
		self:SetHoldType(self.HoldType or "pistol")
	end

	self:SetNWBool("Exploding", false)
end

local function ScorchUnderRagdoll(ent)
	-- big scorch at center
	local mid = ent:LocalToWorld(ent:OBBCenter())
	mid.z = mid.z + 25
	util.PaintDown(mid, "Scorch", ent)
end

-- checks if the burn time is over, or if the body is in water
local function RunIgniteTimer(tname, body, burn_destroy)
	if (IsValid(body) and body:IsOnFire()) then
		if (CurTime() > burn_destroy) then
			body:SetNotSolid(true)
			body:Remove()
		elseif (body:WaterLevel() > 0) then
			body:Extinguish()
		end
	else
		timer.Remove(tname)
	end
end

-- burn the body of the user
local function BurnOwnersBody(model)
	local body
	-- Search for all ragdolls and the one with the given model
	for _, ragdoll in pairs(ents.FindByClass("prop_ragdoll")) do
		if (ragdoll:GetModel() == model) then
			body = ragdoll
		end
	end

	ScorchUnderRagdoll(body)

	if SERVER then
		local burn_time = 7.5
		local burn_destroy = CurTime() + burn_time
		local tname = "burn_jihad"
		timer.Simple(0.01, function() if (IsValid(body)) then body:Ignite(burn_time, 100) end end)
		timer.Create(tname, 0.1, math.ceil(1 + burn_time / 0.1), function () RunIgniteTimer(tname, body, burn_destroy) end)
	end
end

-- particle effects / begin attack
function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self.AllowDrop = false

	local effectdata = EffectData()
	effectdata:SetOrigin(self:GetPos())
	effectdata:SetNormal(self:GetPos())
	effectdata:SetMagnitude(8)
	effectdata:SetScale(1)
	effectdata:SetRadius(20)
	util.Effect("Sparks", effectdata)
	self.BaseClass.ShootEffects(self)

	-- The rest is only done on the server
	if SERVER then
		local owner = self:GetOwner()
		self:SetNWBool("Exploding", true)
		-- Only explode, if the code was completely typed in
		timer.Simple(2.05, function() if (IsValid(self) and IsValid(owner) and IsValid(owner:GetActiveWeapon()) and owner:GetActiveWeapon():GetClass() == self:GetClass()) then self:Explode() end end)
		self:GetOwner():EmitSound(sound:GetString(), math.random(100, 150), math.random(95, 105))
	end
end

-- explosion properties
function SWEP:Explode()
	local pos = self:GetPos()
	local dmg = 200
	local dmgowner = self:GetOwner()

	local r_inner = 550
	local r_outer = r_inner * 1.15

	self:EmitSound("weapons/jihad_bomb/big_explosion.wav", 400, math.random(100, 125))

	-- change body to a random charred body
	local model = "models/humans/charple0" .. math.random(1,4) .. ".mdl"
	self:GetOwner():SetModel(model)

	-- damage through walls
	self:SphereDamage(dmgowner, pos, r_inner)

	-- explosion damage
	util.BlastDamage(self, dmgowner, pos, r_outer, dmg)

	local effect = EffectData()
	effect:SetStart(pos)
	effect:SetOrigin(pos)
	effect:SetScale(r_outer)
	effect:SetRadius(r_outer)
	effect:SetMagnitude(dmg)
	util.Effect("Explosion", effect, true, true)

	-- make sure the owner dies anyway
	if (IsValid(dmgowner)) then
		dmgowner:Kill()
	end

	self:Remove()
	BurnOwnersBody(model)
end

-- calculate who is affected by the damage
function SWEP:SphereDamage(dmgowner, center, radius)
	local r = radius ^ 2 -- square so we can compare with length directly

	local d = 0.0
	local diff = nil
	local dmg = 0
	for _, ent in pairs(player.GetAll()) do
		if (IsValid(ent) and ent:Team() == TEAM_TERROR) then
			-- get the squared length of the distance, so we don't have to calculate the square root
			diff = center - ent:GetPos()
			d = diff:LengthSqr()

			if d < r then
				-- deadly up to a certain range, then a falloff
				d = math.max(0, math.sqrt(d) - radius * 0.65)
				dmg = 125 + d * -1

				local dmginfo = DamageInfo()
				dmginfo:SetDamage(dmg)
				dmginfo:SetAttacker(dmgowner)
				-- dmginfo:SetInflictor(self)
				dmginfo:SetDamageType(DMG_BLAST)
				dmginfo:SetDamageForce(diff)
				dmginfo:SetDamagePosition(ent:GetPos())

				ent:TakeDamageInfo(dmginfo)
			end
		end
	end
end

function SWEP:Deploy()
	self:SetNWBool("Exploding", false)
end

function SWEP:Holster()
	return !self:GetNWBool("Exploding")
end

-- Secondary attack does nothing
function SWEP:SecondaryAttack()
end

-- Reload does nothing
function SWEP:Reload()
end
