AddCSLuaFile()
DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName       = "Wire Forcer"
ENT.RenderGroup		= RENDERGROUP_BOTH
ENT.WireDebugName	= "Forcer"

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "BeamLength" )
	self:NetworkVar( "Bool",  0, "ShowBeam" )
	self:NetworkVar( "Bool",  1, "BeamHighlight" )
end

if CLIENT then return end -- No more client

function ENT:Initialize()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	self.Force = 0
	self.OffsetForce = 0
	self.Velocity = 0

	self.Inputs = WireLib.CreateInputs( self, { "Force", "OffsetForce", "Velocity", "Length" } )

	self:Setup(0, 100, true, false)
end

function ENT:Setup( Force, Length, ShowBeam, Reaction )
	self.ForceMul = Force or 1
	self.Reaction = Reaction or false
	if Length then self:SetBeamLength(Length) end
	if ShowBeam ~= nil then self:SetShowBeam(ShowBeam) end
	self:ShowOutput()
end

function ENT:TriggerInput( name, value )
	if (name == "Force") then
		self.Force = value
		self:SetBeamHighlight(value != 0)
		self:ShowOutput()
	elseif (name == "OffsetForce") then
		self.OffsetForce = value
		self:SetBeamHighlight(value != 0)
		self:ShowOutput()
	elseif (name == "Velocity") then
		self.Velocity = math.Clamp(value,-100000,100000)
		self:SetBeamHighlight(value != 0)
		self:ShowOutput()
	elseif (name == "Length") then
		self:SetBeamLength(math.Round(value))
		self:ShowOutput()
	end
end

function ENT:Think()
	if (self.Force != 0 or self.OffsetForce != 0 or self.Velocity != 0) then
		local Forward = self:GetUp()
		local StartPos = self:GetPos() + Forward * self:OBBMaxs().z

		local tr = {}
		tr.start = StartPos
		tr.endpos = StartPos + self:GetBeamLength() * Forward
		tr.filter = self
		local trace = util.TraceLine( tr )
		if (trace) then
			if (trace.Entity and trace.Entity:IsValid()) then
				if (trace.Entity:GetMoveType() == MOVETYPE_VPHYSICS) then
					local phys = trace.Entity:GetPhysicsObject()
					if (phys:IsValid()) then
						if (self.Force != 0) then phys:ApplyForceCenter( Forward * self.Force * self.ForceMul ) end
						if (self.OffsetForce != 0) then phys:ApplyForceOffset( Forward * self.OffsetForce * self.ForceMul, trace.HitPos ) end
						if (self.Velocity != 0) then phys:SetVelocityInstantaneous( Forward * self.Velocity ) end
					end
				else
					if (self.Velocity != 0) then trace.Entity:SetVelocity( Forward * self.Velocity ) end
				end
			end
		end

		if (self.Reaction) then
			local phys = self:GetPhysicsObject()
			if (phys:IsValid()) then
				if (self.Force != 0 or self.OffsetForce != 0) then phys:ApplyForceCenter( Forward * -self.Force * self.ForceMul ) end
			end
		end
	end
	self:NextThink( CurTime() )
	return true
end

function ENT:ShowOutput()
	self:SetOverlayText(
		"Center Force = "..math.Round(self.ForceMul * self.Force)..
		"\nOffset Force = "..math.Round(self.ForceMul * self.OffsetForce)..
		"\nVelocity = "..math.Round(self.Velocity)..
		"\nLength = " .. math.Round(self:GetBeamLength())
	)
end

function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	info.ForceMul = self.ForceMul
	info.Reaction = self.Reaction
	return info
end


function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	--Moves old "A" input to new "Force" input for older saves
	if info.Wires and info.Wires.A then
		info.Wires.Force = info.Wires.A
		info.Wires.A = nil
	end

	self:Setup( info.ForceMul, info.Length, info.ShowBeam, info.Reaction )

	self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
end

duplicator.RegisterEntityClass("gmod_wire_forcer", WireLib.MakeWireEnt, "Data", "Force", "Length", "ShowBeam", "Reaction")
