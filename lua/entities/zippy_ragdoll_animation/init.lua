include("shared.lua")

AddCSLuaFile("shared.lua")

function ENT:Initialize()
    self:SetModel("models/zippy/rise_animations.mdl")
    self:SetPlaybackRate(math.Rand(0.5,1))
    self:SetNoDraw(true)
    self.Delta = 0
end

function ENT:Think()
    local rag = self.Ragdoll
    if IsValid(rag) then
        local physcount = rag:GetPhysicsObjectCount()
        for i = 0, physcount - 1 do

            local physObj = rag:GetPhysicsObjectNum(i)
            local idealPos, idealAng = self:GetBonePosition(rag:TranslatePhysBoneToBone(i))


            local pos1, ang1 = LerpVector(0.1, physObj:GetPos(), idealPos), LerpAngle(0.1, physObj:GetAngles(), idealAng)
            pos1, ang1 = idealPos, idealAng

            local tr = util.TraceLine( {
                start = pos1,
                endpos = pos1,
                mask = MASK_ALL,
                filter = function(ent) 
                    return ent != self and ent != rag
                end
            })

            if !tr.Hit and self:GetBoneName(rag:TranslatePhysBoneToBone(i)) == rag:GetBoneName(rag:TranslatePhysBoneToBone(i)) then
                local p = {}
                p.secondstoarrive = 0.01
                p.pos = pos1
                p.angle = ang1
                p.maxangular = 400
                p.maxangulardamp = 200
                p.maxspeed = 50
                p.maxspeeddamp = 45
                p.teleportdistance = 0
                p.deltatime = CurTime()-self.Delta

                physObj:Wake()
                physObj:ComputeShadowControl(p)
            end
        end
    end

    if IsValid(self.Entity) then
        self:SetPos(self.Entity:GetPos())
        self:SetAngles(self.Entity:GetAngles())
    end

    if isfunction(self.FinishFunc) and self:GetCycle() == 1 then
        self.FinishFunc()
        self:Remove()
    end

    self.Delta = CurTime()
    self:NextThink(CurTime())
    return true
end