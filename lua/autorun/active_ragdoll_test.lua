local enabled = CreateConVar("active_ragdoll_enabled", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagRise = CreateConVar("active_ragdoll_rise_animation", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagChance = CreateConVar("active_ragdoll_chance", "2", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagDMGPercent = CreateConVar("active_ragdoll_dmg_hp_percent", "0.1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagDropWepChance = CreateConVar("active_ragdoll_drop_weapon_chance", "5", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagDropWep = CreateConVar("active_ragdoll_drop_weapon", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagDurationMin = CreateConVar("active_ragdoll_duration_min", "2", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagDurationMax = CreateConVar("active_ragdoll_duration_max", "4", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagExplosion = CreateConVar("active_ragdoll_always_on_explosion", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagAllNPCs = CreateConVar("active_ragdoll_all_npcs", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagCoolDown = CreateConVar("active_ragdoll_cooldown", "3", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagBurn = CreateConVar("active_ragdoll_always_on_burn", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local activeRagTakePhysDMG = CreateConVar("active_ragdoll_phys_dmg", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED))
local REAGDOLL_INSTALLED = file.Exists("autorun/client/reagdoll_menu.lua", "LUA")



if CLIENT then
    
    
    hook.Add("PopulateToolMenu", "ZippyActiveRagdoll", function() spawnmenu.AddToolMenuOption("Options", "Ragdolls", "Active Ragdoll", "Active Ragdoll", "", "", function(panel)

        panel:CheckBox("Enable", "active_ragdoll_enabled")
        panel:Help("Enable addon.")

        panel:CheckBox("Rise Animation", "active_ragdoll_rise_animation")
        panel:Help("Enable rise animations when npc getting up.\nWARNING: Its not working with all models properly.")

        panel:CheckBox("Drop Weapons", "active_ragdoll_drop_weapon")
        panel:Help("Enable weapon dropping.")

        panel:CheckBox("Explosions Ignore Chance", "active_ragdoll_always_on_explosion")
        panel:Help("The chance of ragdolling is always 100% on explosions.")

        panel:CheckBox("Always On Burn", "active_ragdoll_always_on_burn")
        panel:Help("Always ragdoll when on fire.")

        panel:CheckBox("All NPCs", "active_ragdoll_all_npcs")
        panel:Help("Should all NPCs be able to ragdoll, as opposed to only humans?")

        panel:CheckBox("Phys Damage", "active_ragdoll_phys_dmg")
        panel:Help("Should ragdolls take damage from physics?")
    
        if REAGDOLL_INSTALLED then
            panel:CheckBox("ReAgdoll Compatability", "reagdoll_ragdolls")
            panel:Help("Enable compatability with ReAgdoll.")
        end

        panel:NumSlider("Damage Percent", "active_ragdoll_dmg_hp_percent", 0, 1, 2)
        panel:Help("How many percent of the target's HP has to be reduced in order for it to ragdoll?")

        panel:NumSlider("Chance", "active_ragdoll_chance", 1, 20, 0)
        panel:Help("1/X Chance that the target ragdolls.")

        panel:NumSlider("Cooldown", "active_ragdoll_cooldown", 0, 30, 0)
        panel:Help("Time until a target can be ragdolled again after it rises.")

        panel:NumSlider("Duration Min", "active_ragdoll_duration_min", 1, 20, 2)
        panel:Help("Minimum duration of the ragdoll state.")

        panel:NumSlider("Duration Max", "active_ragdoll_duration_max", 1, 20, 2)
        panel:Help("Maximum duration of the ragdoll state.")

        panel:NumSlider("Drop Weapon Chance", "active_ragdoll_drop_weapon_chance", 1, 20, 0)
        panel:Help("1/X Chance that the target drops their active weapon when ragdolled.")
    end) end)
    
    
end


if SERVER then
    local NPCS_IN_RAGDOLL_STATE = {}


    local function ActiveRagdoll_MoveThink( self )
        -- I dunno y it no work lol
        local physcount = self:GetPhysicsObjectCount()

        for i = 0, physcount - 1 do

            local phys = self:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                -- phys:ApplyForceCenter(Vector(0, 0, 1000))
            end

        end
    end


    local function ActiveRagdollThink( self )

        if !IsValid(self.ActiveRagdoll) then return end -- Prevent error


        -- Position on ragdoll
        if !self.IsInActiveRagdollAnimationState then
            self:SetPos( self.ActiveRagdoll:GetPos() - self.PreActiveRagData._OBBCenter )
        end


        -- Save all enemies
        if IsValid(self:GetEnemy()) then
            table.insert( self.PreActiveRagData.enemies, self:GetEnemy() )
        end


        -- Become friendly towards enemies for now
        for _, v in ipairs(self.PreActiveRagData.enemies) do
            if !IsValid(v) then continue end
            self:AddEntityRelationship( v, D_LI, 99 )
        end


        -- Weapon was stripped, remove the fake model too then
        if !IsValid(self:GetActiveWeapon()) && IsValid(self.ActiveRagdoll.ActiveRagdoll_WeaponProp) then
            self.ActiveRagdoll.ActiveRagdoll_WeaponProp:Remove()
        end


        -- In air or moving fast, delay time until rise
        if self.ActiveRagdoll:GetVelocity():LengthSqr() > 10000 then
            self.ActiveRag_StandDelay = CurTime()+1.5
        end


        -- Rise again
        if self.Time_StopActiveRagdoll < CurTime() && self.ActiveRag_StandDelay < CurTime() then
            self:StopActiveRagdoll()
        end


        -- Shittier movement system when reagdoll is not installed
        if !REAGDOLL_INSTALLED then
            self:ActiveRagdoll_MoveThink()
        end

    end

    
    
    local function PostActiveRagdoll_SetPos( self )
        local tr = util.TraceLine({
            start = self:GetPos() + Vector(0, 0, 150),
            endpos = self:GetPos() - Vector(0, 0, 50),
            mask = MASK_NPCWORLDSTATIC,
        })
        self:SetPos(tr.HitPos+tr.HitNormal*( -self:OBBMins().z + 5 ) )
    end
    
    
    local function createRagFromEnt( ent )

        -- Copy a ragdoll version of the ent
        local rag = ents.Create("prop_ragdoll")
        rag:SetModel(ent:GetModel() or "models/error.mdl")
        rag:SetPos(ent:GetPos())
        rag:SetAngles(ent:GetAngles())
        rag:SetColor(ent:GetColor())
        rag:SetMaterial(ent:GetMaterial())
        rag:SetSkin(ent:GetSkin())
        for _, v in ipairs(ent:GetBodyGroups()) do
            rag:SetBodygroup(v.id, ent:GetBodygroup( v.id ))
        end
        rag:Spawn()

        local physcount = rag:GetPhysicsObjectCount()
        if physcount < 2 then
            -- Not a ragdoll
            rag:Remove()
            return NULL
        end

        -- Position ragdoll
        for i = 0, physcount - 1 do
            local physObj = rag:GetPhysicsObjectNum(i)
            local pos, ang = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
            if pos && ang then
                physObj:SetPos( pos )
                physObj:SetAngles( ang )
            end
        end

        return rag

    end

    local function ragToNPCMake(self)
        if !IsValid(self) then return end
    
        table.RemoveByValue(NPCS_IN_RAGDOLL_STATE, self)

        self.IsInActiveRagdollState = false
        self.IsInActiveRagdollAnimationState = false
        self:SetNWBool("ActiveRagdoll", false)

        -- Start hating enemies again
        for _, v in ipairs(self.PreActiveRagData.enemies) do
            if !IsValid(v) then continue end
            self:AddEntityRelationship(v, D_HT, 99)
        end

        if self.IsVJBaseSNPC then
            self.IsAbleToShootWeapon = self.PreActiveRagData.vjCanShootFunc
            self.vACT_StopAttacks = false
        end

        self:SetNoDraw(false)
        self:SetRenderMode(self.PreActiveRagData.renderMode)
        self:SetColor(self.PreActiveRagData.col)

        if IsValid(self:GetActiveWeapon()) then
            self:GetActiveWeapon():SetNoDraw(false)
        end

        self.ActiveRagdoll:Remove()
        self.ActiveRagdoll = nil

        self.TimeUntilActiveRagdoll = CurTime()+activeRagCoolDown:GetInt()
    end
    
    
    local function ragAnimateToEnt(rag, ent, duration)
        if activeRagRise:GetBool() then
            local anm = ents.Create("zippy_ragdoll_animation")
            anm:SetPos(ent:GetPos())
            anm:SetAngles(ent:GetAngles())
            anm:Spawn()
            anm.Ragdoll = rag
            anm.Entity = ent.ActiveRagdoll.ActiveRagdollOwner
            anm:ResetSequence("rise"..math.random(1,9))
            anm.FinishFunc = function()
                local name = "RagAnimateTo"..ent:EntIndex()
                local endT = CurTime()+duration+0.4
                hook.Add("Think", name, function()
                    if !IsValid(ent) or !IsValid(rag) or CurTime() > endT then
                        hook.Remove("Think", name)
                        ragToNPCMake(ent)
                        return
                    end

                    local physcount = rag:GetPhysicsObjectCount()
                    for i = 0, physcount - 1 do

                        local physObj = rag:GetPhysicsObjectNum(i)
                        local idealPos, idealAng = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))

                        local pos, ang = LerpVector(0.05, physObj:GetPos(), idealPos), LerpAngle(0.05, physObj:GetAngles(), idealAng)

                        physObj:SetPos( pos )
                        physObj:SetAngles( ang )

                    end
                end)
            end
        else
            local name = "RagAnimateTo"..ent:EntIndex()
            local endT = CurTime()+duration
            hook.Add("Think", name, function()
                if !IsValid(ent) or !IsValid(rag) or CurTime() > endT then
                    hook.Remove("Think", name)
                    ragToNPCMake(ent)
                    return
                end

                local physcount = rag:GetPhysicsObjectCount()
                for i = 0, physcount - 1 do

                    local physObj = rag:GetPhysicsObjectNum(i)
                    local idealPos, idealAng = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))

                    local pos, ang = LerpVector(0.1, physObj:GetPos(), idealPos), LerpAngle(0.1, physObj:GetAngles(), idealAng)

                    physObj:SetPos( pos )
                    physObj:SetAngles( ang )

                end
            end)
        end
    end
    
    
    local function BecomeActiveRagdoll( self, duration )

        if !self:GetShouldServerRagdoll() then return end
        if self.IsInActiveRagdollState then return end
        if self.TimeUntilActiveRagdoll > CurTime() then return end

        -- Create ragdoll
        self.ActiveRagdoll = createRagFromEnt( self )
        if !IsValid(self.ActiveRagdoll) then
            -- Couldn't create ragdoll
            return
        end
        self.ActiveRagdoll.IsActiveRagdoll = true
        self.ActiveRagdoll.ActiveRagdollOwner = self
        self.ActiveRagdoll:AddEFlags(EFL_DONTBLOCKLOS)
        self.ActiveRagdoll:CallOnRemove("ActiveRagRemoveNPCOwner", function()
            if IsValid(self) && self.IsInActiveRagdollState then
                self:Remove()
            end
        end)

        -- Register
        self.IsInActiveRagdollState = true
        self:SetNWBool("ActiveRagdoll", true)
        table.insert(NPCS_IN_RAGDOLL_STATE, self)

        -- Data
        local min, max = self:GetCollisionBounds()
        self.PreActiveRagData = {
            enemies = {},
            collBounds = {mins=min, maxs=max},
            _OBBCenter = self:OBBCenter(),
            collGr = self:GetCollisionGroup(),
            bloodCol = self:GetBloodColor(),
            col = self:GetColor(),
            renderMode = self:GetRenderMode(),
            vjCanShootFunc = self.IsAbleToShootWeapon,
        }

         -- No collisions
        self:SetCollisionBounds(Vector(), Vector())
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        -- Drop weapon
        if activeRagDropWep:GetBool() && IsValid(self:GetActiveWeapon()) && math.random(1, activeRagDropWepChance:GetInt()) == 1 then
            self:DropWeapon()
        end

        -- Invisible
        self:SetNoDraw(true)
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))

        -- Ragdoll velocity same as NPC
        local phys = self.ActiveRagdoll:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(self:GetMoveVelocity()*10)
        end

        -- Weapon stuff:
        if IsValid(self:GetActiveWeapon()) then

            self:GetActiveWeapon():SetNoDraw(true)

            local att = self:LookupAttachment("anim_attachment_RH")
            if att && self:GetAttachment(att) then
                local wepProp = ents.Create("base_gmodentity")
                wepProp:SetModel( self:GetActiveWeapon():GetModel() )
                wepProp:SetPos( self:GetAttachment(att).Pos)
                wepProp:SetAngles( self:GetAttachment(att).Ang )
                wepProp:Spawn()
                wepProp:SetParent(self.ActiveRagdoll, att)
                wepProp:AddEffects(EF_BONEMERGE)
                self.ActiveRagdoll.ActiveRagdoll_WeaponProp = wepProp
            end

        end

        -- Blood overlay compatability:
        if self.CopyEntDamageOverlays then
            self:CopyEntDamageOverlays( self.ActiveRagdoll )
        end

        if self.IsVJBaseSNPC then
            function self:IsAbleToShootWeapon( ... ) return false end
            self.vACT_StopAttacks = true
        end

        self.Time_StopActiveRagdoll = CurTime() + (duration or math.Rand(activeRagDurationMin:GetFloat(), activeRagDurationMax:GetFloat()))
        self.ActiveRag_StandDelay = CurTime()

    end
    
    
    local function StopActiveRagdoll( self )

        if self.IsInActiveRagdollAnimationState then return end
    
        local animDur = 0.8

        self:SetCollisionBounds(self.PreActiveRagData.collBounds.mins, self.PreActiveRagData.collBounds.maxs)
        self:SetCollisionGroup(self.PreActiveRagData.collGr)
        self.IsInActiveRagdollAnimationState = true
        self:PostActiveRagdoll_SetPos()

        self.ActiveRagdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        ragAnimateToEnt(self.ActiveRagdoll, self, animDur)

    end
    
    
    local function canActiveRagdoll( ent )
        if ent.GetHullType && ent:GetHullType() != HULL_HUMAN && !activeRagAllNPCs:GetBool() then return false end
        return ent.BecomeActiveRagdoll or false
    end
    
    
    local function ragWasHurtVital( rag, dmgpos )
        local bone
        local mindist

        for i = 0, rag:GetPhysicsObjectCount()-1 do
            local phys = rag:GetPhysicsObjectNum( i )
            local dist = phys:GetPos():DistToSqr( dmgpos )

            if !mindist or dist < mindist then
                mindist = dist
                bone = rag:GetBoneName( rag:TranslatePhysBoneToBone(i) )
            end
        end

        local hitGrTrans = {
            ["ValveBiped.Bip01_Head1"] = HITGROUP_HEAD,
            ["Bip01 Neck"] = HITGROUP_HEAD, -- Combine guard hehe
            ["ValveBiped.Bip01_Spine2"] = HITGROUP_CHEST,
            ["ValveBiped.Bip01_Pelvis"] = HITGROUP_STOMACH,
        }

        local hitGr = hitGrTrans[bone]

        return hitGr or false
    end
    
    
    local function vjAllyCheck( ent, attacker, infl )

        if !ent.IsVJBaseSNPC then return true end

        if IsValid(attacker) && ent:CheckRelationship(attacker) == D_LI then
            return false
        end

        if IsValid(infl) && ent:CheckRelationship(infl) == D_LI then
            return false
        end

        return true

    end
    
    
    hook.Add("EntityTakeDamage", "EntityTakeDamage_ActiveRagdoll", function( ent, dmg )

        local becameRagdoll = false
        local attacker = dmg:GetAttacker()
        local infl = dmg:GetAttacker()

        -- Burning
        if canActiveRagdoll( ent ) && ent:IsOnFire() && activeRagBurn:GetBool() then

            local duration = math.Rand(8, 12)
            ent:BecomeActiveRagdoll(duration)

            if IsValid(ent.ActiveRagdoll) then
                -- Burn the ragdoll instead of the NPC
                ent:Extinguish()
                ent.ActiveRagdoll:Ignite(duration, 10)
                becameRagdoll = true
            end

        end

        -- Start active ragdoll
        if canActiveRagdoll( ent ) &&
        dmg:GetDamage() >= (ent:GetMaxHealth()*activeRagDMGPercent:GetFloat()) &&
        (math.random(1, activeRagChance:GetInt()) == 1 or (activeRagExplosion:GetBool() && dmg:IsExplosionDamage())) &&
        vjAllyCheck( ent, attacker, infl ) then
            ent:BecomeActiveRagdoll()

            if IsValid(ent.ActiveRagdoll) then
                becameRagdoll = true
            end

        end

        -- Don't let active ragdolls hurt other ents
        if IsValid(attacker) && attacker.IsActiveRagdoll then
            return true
        end
        if IsValid(infl) && infl.IsActiveRagdoll then
            return true
        end

        -- Don't hurt the NPC when it is in the ragdoll state, unless it's damage inflicted on its active ragdoll
        if ent.IsInActiveRagdollState && !ent.ActiveRagdoll_DamageFromRagdoll && !becameRagdoll then
            return true
        end

        -- Active ragdoll was hurt, send damage to the owner
        if IsValid(ent.ActiveRagdollOwner) && dmg:GetInflictor() != ent.ActiveRagdollOwner then

            -- Don't do phys damage if in animation state, otherwise it might die from the animation
            if ent.ActiveRagdollOwner.IsInActiveRagdollAnimationState && dmg:IsDamageType(DMG_CRUSH) then
                return true
            end

            -- Don't die from a little boop
            if dmg:IsDamageType(DMG_CRUSH) && dmg:GetDamage() < 50 then
                return true
            end

            -- Don't take damage from physics if that is disabled
            if dmg:IsDamageType(DMG_CRUSH) && !activeRagTakePhysDMG:GetBool() then
                return true
            end

            -- Get the hitgroup right
            if dmg:IsBulletDamage() or dmg:IsDamageType(DMG_BUCKSHOT) then
                local hitGr = ragWasHurtVital(ent, dmg:GetDamagePosition())
                if hitGr then
                    hook.Run("ScaleNPCDamage", ent.ActiveRagdollOwner, hitGr, dmg)
                else
                    -- Not vital shot, arm or leg for example
                    dmg:ScaleDamage(0.5)
                end
            end

            -- Send damage
            ent.ActiveRagdollOwner.ActiveRagdoll_DamageFromRagdoll = true
            ent.ActiveRagdollOwner:TakeDamageInfo(dmg)
            ent.ActiveRagdollOwner.ActiveRag_StandDelay = CurTime()+1
            ent.ActiveRagdollOwner.ActiveRagdoll_DamageFromRagdoll = false

            -- Don't hurt the actual ragdoll
            return true

        end
    end)
    
    
    hook.Add("OnEntityCreated", "AddActiveRagdollFuncs", function( ent )
        -- Init
        if enabled:GetBool() && ent:IsNPC() then
            ent.BecomeActiveRagdoll = BecomeActiveRagdoll
            ent.ActiveRagdollThink = ActiveRagdollThink
            ent.PostActiveRagdoll_SetPos = PostActiveRagdoll_SetPos
            ent.DelayActiveRagNormalTimer = DelayActiveRagNormalTimer
            ent.StopActiveRagdoll = StopActiveRagdoll
            ent.ActiveRagdoll_MoveThink = ActiveRagdoll_MoveThink
            ent.TimeUntilActiveRagdoll = CurTime()
        end
    end)
    
    
    local nextThink = CurTime()
    hook.Add("Think", "ActiveRagdollThink", function()

        if nextThink > CurTime() then return end

        for _, v in ipairs(NPCS_IN_RAGDOLL_STATE) do

            if !v.ActiveRagdollThink then
                -- NPC was removed
                table.RemoveByValue(NPCS_IN_RAGDOLL_STATE, v)
                continue
            end

            v:ActiveRagdollThink()

        end

        nextThink = CurTime() + 0.1

    end)
    
    
    hook.Add("CreateEntityRagdoll", "CreateEntityRagdoll_ActiveRagdoll", function( ent, rag )

        -- Give death ragdoll same attributes as active ragdoll
        local data = ent.ActiveRagdollData

        -- print("-------------- CreateEntityRagdoll --------------------")
        -- print(data)

        if data then

            -- Active ragdoll still exist, hide it
            if IsValid(ent.ActiveRagdoll) then
                ent.ActiveRagdoll:SetNoDraw(true)    
            end

            -- Make visible
            rag:SetColor(ent.PreActiveRagData.col)
            rag:SetRenderMode(ent.PreActiveRagData.renderMode)
            rag:SetNoDraw(false)

            -- Position
            rag:SetPos( data.pos )
            rag:SetAngles( data.ang )
            for k, v in pairs(data.bones) do
                local phys = rag:GetPhysicsObjectNum(k)
                if IsValid(phys) then
                    phys:SetPos( v.pos )
                    phys:SetAngles( v.ang )
                end
            end

            -- Copy velocity
            local phys = rag:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(data.vel*2)
            end
        end

    end)
    
    
    local function saveActiveRagData( npc )
        if IsValid(npc.ActiveRagdoll) then

            -- Save data about active ragdoll
            npc.ActiveRagdollData = {
                pos = npc.ActiveRagdoll:GetPos(),
                ang = npc.ActiveRagdoll:GetAngles(),
                vel = npc.ActiveRagdoll:GetVelocity(),
                bones = {},
            }

            -- print(npc)
            -- print("-------------- save activerag data func --------------------")
            -- PrintTable(npc.ActiveRagdollData)

            -- Save all bone positions
            local physcount = npc.ActiveRagdoll:GetPhysicsObjectCount()
            for i = 0, physcount - 1 do
                local physObj = npc.ActiveRagdoll:GetPhysicsObjectNum(i)
                npc.ActiveRagdollData.bones[i] = {pos=physObj:GetPos(), ang=physObj:GetAngles()}
            end

        end
    end
    
    
    hook.Add("InitPostEntity", "ActiveRagdoll_InitPostEntity", function()

        -- Automatic compatability with reagdoll
        if REAGDOLL_INSTALLED then
            RunConsoleCommand("reagdoll_ragdolls", "1")
        end

        timer.Simple(0, function() timer.Simple(0, function() -- lmao, anp base compatability

            local OnNPCKilled = GAMEMODE.OnNPCKilled
            function GAMEMODE:OnNPCKilled(npc, ...)
                -- If the NPC is killed in the active ragdoll state...
                saveActiveRagData( npc )
                OnNPCKilled(self, npc, ...)
            end

        end) end)

    end)
    
    
    hook.Add("EntityRemoved", "EntityRemoved_ActiveRagdoll", function( ent )

        saveActiveRagData( ent )

        if IsValid(ent.ActiveRagdoll) then
            ent.ActiveRagdoll:Remove()
        end

    end)
    
    
end

