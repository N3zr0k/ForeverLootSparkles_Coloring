-- Sparkles on ore veins, herbs, quest objects and corpses that still hold
-- loot, as you approach them.
-- Blizzard's soft targeting always picks one interaction target (the
-- "softinteract" unit) and can give it a nameplate. A small cluster of glints,
-- modelled on the quest loot sparkle, is hung on that nameplate. The object
-- type comes from its cursor icon, its state from the interact range check.
-- Adapted from the Lueur addon by the same author.
--
-- Taken over from Forever Loot Sparkles 1.3.1 (SoftTarget.lua, GPL-3.0-or-later),
-- which removed this feature in 2.0.0. Changes in this addon:
--  * glints take the color chosen per category (Coloring options);
--  * soft targeting is paused in combat and, depending on the mode, while it
--    has picked a player or other living unit, so spells cast without a
--    target don't land on that unit (Forever Loot Sparkles issue #10, option
--    "safeSelfCastMode"); NPCs that offer a service are left alone, and no
--    cvar is written while an NPC or mailbox window is open;
--  * the nameplate the sparkle hangs on can be made invisible, so corpses
--    don't show an empty health bar (#12, option "hidePlate");
--  * cvars are only touched once Forever Loot Sparkles 2.x has finished
--    putting its own old values back after login.

local ADDON_NAME, ns = ...;

local SOFT = "softinteract";
local TEXTURE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Textures\\flare";
local FALLBACK_TEXTURE = "Interface\\Cooldown\\star4";

-- Option key per object category; ore and herbs get no sparkle from the game,
-- quest objects already do while the loot sparkle is on, so they default off.
local CATEGORY_OPTIONS = {
	ore = "sparkleOre",
	herb = "sparkleHerbs",
	quest = "sparkleQuest",
	corpseLoot = "sparkleCorpseLoot",
	footlocker = "sparkleFootlocker",
};
local DEFAULTS = {
	sparkleOre = true,
	sparkleHerbs = true,
	sparkleQuest = false,
	sparkleCorpseLoot = true,
	sparkleFootlocker = true,
};

-- Footlockers rogues can pick open, by game object ID (from the GUID). The
-- English name is a fallback for IDs not listed here.
local FOOTLOCKER_IDS = {
	[179486] = true, [179487] = true, [179488] = true, [179490] = true, -- Waterlogged, Battered
	[179496] = true, -- Dented
	[179498] = true, -- Scarlet
	[405633] = true, -- Rockjaw
	[656157] = true, -- Syndicate
};

local RANGE = 60;          -- soft target range in yards, asked as high as Lueur tried; Forever still drops the target past ~15
local ARC = 2;             -- 0 = straight ahead, 1 = in front, 2 = all around
local OFFSET_Y = -45;      -- from the nameplate down to the object (pixels)
local SPREAD = 46;         -- radius the glints appear in (pixels)
local GLINT_SIZE = 34;
local GLINT_COUNT = 7;
local GOLD, GREY = ns.GOLD, ns.GREY;

local POLL_INTERVAL = 0.12; -- re-check of target and state (seconds)
local FADE_IN = 0.35;
local BLEND_TIME = 0.30;    -- fade between states
local STATE_DELAY = 0.15;   -- a state must hold this long before it shows (no flicker at the range edge)
local LOCK_DELAY = 0.60;    -- same for "locked", confirmed more carefully

-- Cvars this module changes; their original values are saved and put back
-- once every category is switched off.
local MANAGED_CVARS = {
	"SoftTargetInteract", "SoftTargetNameplateInteract", "SoftTargetInteractRange",
	"SoftTargetInteractArc", "SoftTargetInteractOnlyInRange", "SoftTargetIconGameObject",
};

local db;
local ready = false;         -- cvars are left alone until Forever Loot Sparkles has restored its own
local gateOpen;             -- is the game's own target nameplate on? nil = apply again
local pendingCVars = false; -- "apply" or "restore" once combat ends
local pendingForce = false; -- the pending "apply" also switches the interact key on
local paused;               -- nil, "unit" or "combat"; declared here because ApplyCVars/RestoreCVars reset it
local directWorks = false;  -- GetNamePlateForUnit("softinteract") has worked for an object
local activeUnits = {};     -- nameplateN token -> true

local sparkle = {};         -- the one sparkle frame and its animation state

local sin, cos, sqrt, random, min, max, pi = math.sin, math.cos, math.sqrt, math.random, math.min, math.max, math.pi;

-- shared helpers from Coloring.lua
local IsSecret, SafeCall = ns.IsSecret, ns.SafeCall;
local GetCVarValue, SetCVarValue = ns.GetCVarValue, ns.SetCVarValue;
local Classify = ns.ClassifyObject;

local function Lerp(a, b, t)
	return a + (b - a) * t;
end

local function Approach(value, target, step)
	if value < target then
		return min(value + step, target);
	end
	return max(value - step, target);
end

local function IsActive()
	if not db then
		return false;
	end
	for _, key in pairs(CATEGORY_OPTIONS) do
		if db[key] then
			return true;
		end
	end
	return false;
end

---------------------------------------------------------------------------
-- Cvars
---------------------------------------------------------------------------

-- The game's nameplate on the interaction target, which the sparkle hangs on.
-- It is only switched on for objects that get a sparkle, so NPCs, mailboxes
-- and the like still work with the interact key without a nameplate popping up.
local function SetGate(open)
	if open == gateOpen or InCombatLockdown() then
		return;
	end
	gateOpen = open;
	SetCVarValue("SoftTargetNameplateInteract", open and 1 or 0);
end

local Evaluate;

-- SoftTargetInteract ("Enable Interact Key") and SoftTargetIconGameObject (part
-- of "Interact Key Icons") are the player's settings too. They are switched on
-- when the sparkles start and whenever a sparkle option is switched on (force);
-- at login a player who switched them off afterwards keeps them off.
local function ApplyCVars(force)
	if InCombatLockdown() then
		pendingCVars = "apply";
		pendingForce = pendingForce or force == true;
		return;
	end
	db.savedCVars = db.savedCVars or {};
	if db.savedCVars.SoftTargetInteract == nil or db.savedCVars.SoftTargetIconGameObject == nil then
		force = true;
	end
	for _, name in ipairs(MANAGED_CVARS) do
		if db.savedCVars[name] == nil then
			db.savedCVars[name] = GetCVarValue(name) or false;
		end
	end
	if force then
		paused, db.pausedInteract = nil, nil;
		SetCVarValue("SoftTargetInteract", 3);      -- interaction soft target always on
		SetCVarValue("SoftTargetIconGameObject", 1); -- world objects get a nameplate
	end
	SetCVarValue("SoftTargetInteractRange", RANGE);
	SetCVarValue("SoftTargetInteractArc", ARC);
	SetCVarValue("SoftTargetInteractOnlyInRange", 0); -- also find objects outside interact range
	gateOpen = nil;
	Evaluate();
end

local function RestoreCVars()
	if InCombatLockdown() then
		pendingCVars = "restore";
		return;
	end
	paused = nil;
	db.pausedInteract = nil;
	if not db.savedCVars then
		return;
	end
	for name, value in pairs(db.savedCVars) do
		if value ~= false then
			SetCVarValue(name, value);
		end
	end
	db.savedCVars = nil;
	gateOpen = nil;
end

---------------------------------------------------------------------------
-- Pausing soft targeting (safe self-cast)
---------------------------------------------------------------------------

-- Spells cast without a target can land on the soft interact target when it
-- is a living unit (a player or NPC next to you). Only objects and corpses
-- need it for the sparkle, so soft targeting is switched off in combat and,
-- in the "units" mode, as soon as it picks a living unit, and back on once you
-- have moved a few yards (or after a few seconds where the game won't give
-- your position). The value it had is kept in db.pausedInteract, so a logout
-- during a pause can't leave it off.
--
-- Modes (db.safeSelfCastMode):
--   "off"    never paused;
--   "combat" paused in combat only;
--   "units"  also while it has picked a player or other living unit, except
--            NPCs that offer a service (vendor, auctioneer, banker ...), so the
--            interact key keeps working on them.
-- While db.safeSelfCastAuto is set (the player hasn't picked a mode yet) the
-- mode follows the player's own interact key setting: "combat" if they had it
-- switched on before this addon touched it, "units" otherwise.
local SAFE_CAST_MODES = { off = true, combat = true, units = true };
local RESUME_DISTANCE = 5; -- yards
local RESUME_TIME = 3;     -- seconds, without a position
local BACKOFF_WINDOW = 10; -- seconds: the same unit picked again this soon after a resume ...
local BACKOFF_MAX = 4;     -- ... doubles the wait, up to 2^4 = 16 times RESUME_TIME
local pausedAt, pausedY, pausedX;
local pausedGUID, resumedAt, backoff = nil, nil, 0;

local function SafeCastMode()
	local mode = db and db.safeSelfCastMode;
	return SAFE_CAST_MODES[mode] and mode or "units";
end

-- true: the player had the interact key on before this addon switched it on;
-- false: it was off; nil: unknown
local function PlayerUsesInteractKey()
	local original;
	if db.savedCVars then
		original = db.savedCVars.SoftTargetInteract;
	elseif db.pausedInteract ~= nil then
		original = db.pausedInteract;
	else
		original = GetCVarValue("SoftTargetInteract");
	end
	if type(original) ~= "string" then
		return nil;
	end
	return original ~= "0";
end

-- Picks the mode from the player's interact key while they haven't chosen one
local function ApplyAutoMode()
	if not db.safeSelfCastAuto then
		return;
	end
	db.safeSelfCastMode = PlayerUsesInteractKey() and "combat" or "units";
	db.safeSelfCast = true;
end

---------------------------------------------------------------------------
-- NPC windows
---------------------------------------------------------------------------

-- While a window opened by talking to an NPC or using a mailbox is open, no
-- cvar is written: every write runs Blizzard's CVAR_UPDATE handlers with this
-- addon's taint, which addons working in those windows (Auctionator ...) then
-- trip over. The frames are checked directly, so a missed "closed" event
-- can't leave the addon frozen.
local INTERACTION_FRAMES = {
	"AuctionFrame", "AuctionHouseFrame", "MerchantFrame", "MailFrame", "BankFrame",
	"GossipFrame", "QuestFrame", "TaxiFrame", "ClassTrainerFrame", "TradeFrame",
	"GuildRegistrarFrame", "PetStableFrame", "TabardFrame",
};
local interactionTypes = {}; -- PLAYER_INTERACTION_MANAGER_FRAME_SHOW type -> true

local function InteractionWindowOpen()
	if next(interactionTypes) then
		return true;
	end
	for _, name in ipairs(INTERACTION_FRAMES) do
		local frame = _G[name];
		if type(frame) == "table" and frame.IsShown then
			local ok, shown = pcall(frame.IsShown, frame);
			if ok and shown == true then
				return true;
			end
		end
	end
	return false;
end

local function PlayerPosition()
	if not UnitPosition then
		return nil;
	end
	local ok, y, x = pcall(UnitPosition, "player");
	if ok and type(y) == "number" and type(x) == "number" and not IsSecret(y) and not IsSecret(x) then
		return y, x;
	end
end

-- guid: the unit soft targeting had picked ("unit" pauses). The paused soft
-- targeting can't show when that unit is gone, so the pause ends by moving or
-- waiting; if the same unit is picked again right after, the wait doubles,
-- so standing next to it doesn't switch the interact key on and off every
-- few seconds.
local function Pause(reason, guid)
	if paused then
		if reason == "combat" then
			paused = "combat";
		end
		return;
	end
	if InCombatLockdown() then
		return;
	end
	local current = GetCVarValue("SoftTargetInteract");
	if current == nil or current == "0" then
		return;
	end
	local now = GetTime();
	if reason == "unit" then
		if guid and guid == pausedGUID and resumedAt and now - resumedAt < BACKOFF_WINDOW then
			backoff = min(backoff + 1, BACKOFF_MAX);
		else
			backoff = 0;
		end
		pausedGUID = guid;
	end
	db.pausedInteract = current;
	paused = reason;
	pausedAt = now;
	pausedY, pausedX = PlayerPosition();
	SetCVarValue("SoftTargetInteract", 0);
end

local function Resume()
	if InCombatLockdown() then
		return;
	end
	if paused == "unit" then
		resumedAt = GetTime();
	end
	paused = nil;
	if db.pausedInteract ~= nil then
		if GetCVarValue("SoftTargetInteract") == "0" then
			SetCVarValue("SoftTargetInteract", db.pausedInteract);
		end
		db.pausedInteract = nil;
	end
	gateOpen = nil;
end

local function ReadyToResume()
	local waited = GetTime() - pausedAt;
	if waited < RESUME_TIME * (2 ^ backoff) - RESUME_TIME then
		return false; -- the same unit came back right after the last resume
	end
	local y, x = PlayerPosition();
	if y and pausedY then
		local dy, dx = y - pausedY, x - pausedX;
		return dy * dy + dx * dx >= RESUME_DISTANCE * RESUME_DISTANCE;
	end
	return waited >= RESUME_TIME * (2 ^ backoff);
end

local function IsLivingUnit(unit)
	return SafeCall(UnitIsDead, unit) == false and SafeCall(UnitExists, unit) == true;
end

-- Cursor icons of NPCs that offer a service. Read as fileIDs where the client
-- knows the paths, otherwise as keywords in the path or atlas name.
local SERVICE_CURSORS = {
	"Speak", "Buy", "Repair", "Taxi", "Trainer", "Innkeeper", "Mail", "Directions",
	"Quest", "QuestRepeatable", "QuestTurnIn", "Interact", "Transmogrify", "Reforge",
};
local SERVICE_KEYWORDS = {
	"speak", "buy", "repair", "taxi", "trainer", "innkeeper", "mail", "directions",
	"quest", "interact", "transmog", "reforge", "bank", "auction",
};
local serviceCursorIDs = {};
if GetFileIDFromPath then
	for _, name in ipairs(SERVICE_CURSORS) do
		for _, prefix in ipairs({ "", "Unable" }) do
			local path = "Interface\\Cursor\\" .. prefix .. name;
			local id = SafeCall(GetFileIDFromPath, path) or SafeCall(GetFileIDFromPath, path .. ".blp");
			if id then
				serviceCursorIDs[id] = true;
			end
		end
	end
end

local function IsServiceCursorName(name)
	if type(name) ~= "string" then
		return false;
	end
	name = name:lower();
	for _, keyword in ipairs(SERVICE_KEYWORDS) do
		if name:find(keyword, 1, true) then
			return true;
		end
	end
	return false;
end

-- An NPC you talk to rather than cast on: vendor, auctioneer, banker, flight
-- master, trainer, innkeeper, quest giver, guard giving directions ... Players,
-- pets, enemies and NPCs whose cursor can't be read are not.
local function IsServiceNPC(unit)
	if SafeCall(UnitIsPlayer, unit) ~= false or SafeCall(UnitPlayerControlled, unit) == true
		or SafeCall(UnitCanAttack, "player", unit) == true then
		return false;
	end
	local texture, atlas = ns.CursorTexture(unit);
	if type(texture) == "number" and serviceCursorIDs[texture] then
		return true;
	end
	return IsServiceCursorName(texture) or IsServiceCursorName(atlas);
end

---------------------------------------------------------------------------
-- Classification
---------------------------------------------------------------------------

-- Does the corpse still hold loot this character may take? pcall instead of
-- SafeCall: both return values are needed.
local function HasLootLeft(unit)
	local guid = SafeCall(UnitGUID, unit);
	if not (guid and CanLootUnit) then
		return false;
	end
	local ok, hasLoot, canLoot = pcall(CanLootUnit, guid);
	if not ok or IsSecret(hasLoot) or IsSecret(canLoot) then
		return false;
	end
	return hasLoot == true and canLoot ~= false;
end

-- UnitIsCorpse is false for dead mobs (checked in the client), UnitIsDead isn't
local function IsCorpseWithLoot(unit)
	return SafeCall(UnitIsDead, unit) == true and HasLootLeft(unit);
end

-- "ready": can interact; "far": too far; "locked": in range but the game
-- refuses (skill too low, object locked …)
local function ReadState(unit, blocked)
	local inRange = UnitIsInInteractRange and SafeCall(UnitIsInInteractRange, unit);
	if inRange == false then
		return "far";
	end
	if blocked then
		return inRange == true and "locked" or "far";
	end
	return "ready";
end

-- Game object ID from a GUID like "GameObject-0-1-2-3-179488-0000"
local function ObjectID(unit)
	local guid = SafeCall(UnitGUID, unit);
	if type(guid) ~= "string" then
		return nil;
	end
	local kind, _, _, _, _, id = strsplit("-", guid);
	if kind == "GameObject" then
		return tonumber(id);
	end
end

local function IsFootlocker(unit, name)
	local id = ObjectID(unit);
	if id and FOOTLOCKER_IDS[id] then
		return true;
	end
	return type(name) == "string" and not IsSecret(name) and name:lower():find("footlocker", 1, true) ~= nil;
end

---------------------------------------------------------------------------
-- Target
---------------------------------------------------------------------------

local function GetNamePlate(unit)
	return C_NamePlate and SafeCall(C_NamePlate.GetNamePlateForUnit, unit);
end

-- true, false, or nil when the client won't say (secret values). A world
-- object does not "exist" as far as UnitExists is concerned.
local function SoftTargetExists()
	local isUnit, isObject = SafeCall(UnitExists, SOFT), SafeCall(UnitIsGameObject, SOFT);
	if isUnit == true or isObject == true then
		return true;
	end
	if isUnit == false and isObject == false then
		return false;
	end
	return nil;
end

-- Returns the unit token to query, its nameplate (nil if the game doesn't show
-- it, or not yet) and, without a readable target, whether that is for lack of
-- knowing. Until "softinteract" has given the nameplate of a world object on
-- this client, the visible nameplates are searched as well.
local function ResolveTarget()
	local exists = SoftTargetExists();
	if exists == false then
		return nil;
	end
	local plate = GetNamePlate(SOFT);
	if plate then
		if not directWorks and SafeCall(UnitIsGameObject, SOFT) == true then
			directWorks = true;
		end
		return SOFT, plate;
	end
	if not directWorks then
		for unit in pairs(activeUnits) do
			if SafeCall(UnitIsGameObject, unit) == true or SafeCall(UnitIsUnit, unit, SOFT) == true then
				plate = GetNamePlate(unit);
				if plate then
					return unit, plate;
				end
			end
		end
	end
	if exists then
		return SOFT, nil;
	end
	return nil, nil, true;
end

---------------------------------------------------------------------------
-- Sparkle
---------------------------------------------------------------------------

-- Places a glint somewhere new in a flattened disc, after a short dark pause
local function Respawn(glint, now)
	local angle, reach = random() * 2 * pi, sqrt(random());
	glint.x, glint.y = cos(angle) * reach * SPREAD, sin(angle) * reach * SPREAD * 0.75;
	glint.life = 0.6 + 0.8 * random();
	glint.scale = 0.5 + 0.7 * random();
	glint.angle = random() * 2 * pi;
	glint.turn = (random() - 0.5) * 2;
	glint.age = now and 0 or -0.6 * random();
end

local function Animate(self, elapsed)
	if elapsed > 0.1 then
		elapsed = 0.1; -- no jump after a frame freeze
	end
	sparkle.appear = Approach(sparkle.appear, 1, elapsed / FADE_IN);
	sparkle.ready = Approach(sparkle.ready, sparkle.state == "ready" and 1 or 0, elapsed / BLEND_TIME);
	sparkle.locked = Approach(sparkle.locked, sparkle.state == "locked" and 1 or 0, elapsed / BLEND_TIME);

	local ready, locked = sparkle.ready, sparkle.locked;
	-- dimmer and calmer out of range, grey and slow on a locked object
	local alpha = sparkle.appear * Lerp(0.55, 1, ready) * (1 - 0.55 * locked);
	local speed = Lerp(0.8, 1.2, ready) * (1 - 0.5 * locked);
	local base = GOLD;
	if db.enabled and sparkle.category and db.colors and db.colors[sparkle.category] then
		base = db.colors[sparkle.category];
	end
	local r = Lerp(base[1], GREY[1], locked);
	local g = Lerp(base[2], GREY[2], locked);
	local b = Lerp(base[3], GREY[3], locked);

	for _, glint in ipairs(sparkle.glints) do
		glint.age = glint.age + elapsed * speed;
		if glint.age >= glint.life then
			Respawn(glint);
		end
		local shine = glint.age > 0 and sin(pi * glint.age / glint.life) or 0;
		local texture = glint.texture;
		texture:SetPoint("CENTER", self, "CENTER", glint.x, glint.y + 10 * max(glint.age, 0));
		local size = max(GLINT_SIZE * glint.scale * (0.35 + 0.65 * shine), 0.01);
		texture:SetSize(size, size);
		texture:SetRotation(glint.angle + glint.turn * max(glint.age, 0));
		texture:SetVertexColor(r, g, b, min(alpha * shine, 1));
	end
end

local function CreateSparkle()
	local frame = CreateFrame("Frame");
	frame:SetSize(1, 1);
	frame:Hide();
	sparkle.glints = {};
	for i = 1, GLINT_COUNT do
		local texture = frame:CreateTexture(nil, "OVERLAY");
		if texture:SetTexture(TEXTURE) == false then
			texture:SetTexture(FALLBACK_TEXTURE);
		end
		texture:SetBlendMode("ADD");
		texture:SetVertexColor(1, 1, 1, 0);
		if texture.SetSnapToPixelGrid then
			texture:SetSnapToPixelGrid(false);
			texture:SetTexelSnappingBias(0);
		end
		sparkle.glints[i] = { texture = texture };
	end
	frame:SetScript("OnUpdate", Animate);
	sparkle.frame = frame;
	return frame;
end

-- The nameplate's own content (health bar, name, icon) under the sparkle.
-- The sparkle frame ignores its parent's alpha, so it stays visible.
local veiled;          -- the UnitFrame made invisible, if any
local reveiling = false;
local veilHooked = {};
local function KeepVeiled(frame, alpha)
	if frame == veiled and alpha ~= 0 and not reveiling then
		reveiling = true;
		pcall(frame.SetAlpha, frame, 0);
		reveiling = false;
	end
end

local function Unveil()
	if veiled then
		local frame = veiled;
		veiled = nil;
		pcall(frame.SetAlpha, frame, 1);
	end
end

local function Veil(plate)
	Unveil();
	local frame = db.hidePlate and plate and plate.UnitFrame;
	if type(frame) ~= "table" or not frame.SetAlpha then
		return;
	end
	if not veilHooked[frame] and hooksecurefunc then
		veilHooked[frame] = true;
		pcall(hooksecurefunc, frame, "SetAlpha", KeepVeiled);
	end
	veiled = frame;
	pcall(frame.SetAlpha, frame, 0);
end

local function Release()
	Unveil();
	if not sparkle.anchor then
		return;
	end
	sparkle.frame:Hide();
	sparkle.frame:ClearAllPoints();
	sparkle.frame:SetParent(nil);
	sparkle.anchor, sparkle.retarget = nil, nil;
end

local function Attach(plate, state, category)
	local frame = sparkle.frame or CreateSparkle();
	sparkle.category = category;
	Veil(plate);
	frame:SetParent(plate);
	-- below the nameplate content, so its text stays readable
	local ok, level = pcall(plate.GetFrameLevel, plate);
	if ok and level and not IsSecret(level) then
		frame:SetFrameLevel(max(level - 1, 0));
	end
	frame:ClearAllPoints();
	frame:SetPoint("CENTER", plate, "CENTER", 0, OFFSET_Y);
	frame:SetIgnoreParentAlpha(true);

	sparkle.anchor = plate;
	sparkle.state, sparkle.pending = state, nil;
	sparkle.ready = state == "ready" and 1 or 0;
	sparkle.locked = state == "locked" and 1 or 0;
	sparkle.appear = 0;
	for _, glint in ipairs(sparkle.glints) do
		Respawn(glint);
	end
	frame:Show();
end

-- A new state only shows once it is stable
local function ProposeState(state)
	if state == sparkle.state then
		sparkle.pending = nil;
		return;
	end
	local now = GetTime();
	if sparkle.pending ~= state then
		sparkle.pending, sparkle.pendingSince = state, now;
	elseif now - sparkle.pendingSince >= (state == "locked" and LOCK_DELAY or STATE_DELAY) then
		sparkle.pending = nil;
		sparkle.state = state;
		if state == "ready" then
			-- every glint starts over at once: the "in range" burst
			for _, glint in ipairs(sparkle.glints) do
				Respawn(glint, true);
			end
		end
	end
end

-- Finds the current interaction target, then brings the game's nameplate (on
-- only for objects that get a sparkle) and the sparkle itself in line with it
function Evaluate()
	if not ready then
		return;
	end
	if InteractionWindowOpen() then
		return; -- nothing is written while an NPC window is open; checked again once it closes
	end
	if not IsActive() then
		Release();
		return;
	end
	local unit, plate, unknown = ResolveTarget();
	if not unit then
		SetGate(unknown == true); -- when in doubt, let the game show its target
		Release();
		return;
	end

	-- world objects sparkle, and of the units only corpses with loot left
	local category, blocked;
	if SafeCall(UnitIsGameObject, unit) == true then
		local name = SafeCall(UnitName, unit);
		category, blocked = Classify(unit, name);
		if IsFootlocker(unit, name) then
			category = "footlocker"; -- "blocked" from the lockpicking cursor: grey when the skill is too low
		end
	elseif db.sparkleCorpseLoot and IsCorpseWithLoot(unit) then
		category, blocked = "corpseLoot", false;
	else
		SetGate(false);
		Release();
		if SafeCastMode() == "units" and IsLivingUnit(unit) and not IsServiceNPC(unit) then
			Pause("unit", SafeCall(UnitGUID, unit));
		end
		return;
	end
	local option = CATEGORY_OPTIONS[category];
	local wanted = option ~= nil and db[option] == true;
	SetGate(wanted);
	if not wanted or not plate then
		-- without a plate it has just been asked for; the sparkle follows when it arrives
		Release();
		return;
	end

	local state = ReadState(unit, blocked);
	if sparkle.anchor ~= plate or sparkle.retarget then
		Release();
		Attach(plate, state, category);
	else
		sparkle.category = category;
		ProposeState(state);
	end
end

---------------------------------------------------------------------------
-- Events and options
---------------------------------------------------------------------------

local function Refresh(force)
	if IsActive() then
		ApplyCVars(force);
	else
		Release();
		RestoreCVars();
	end
end

local poller = CreateFrame("Frame");
poller:Hide();
local sinceCheck = 0;
poller:SetScript("OnUpdate", function(_, elapsed)
	sinceCheck = sinceCheck + elapsed;
	if sinceCheck >= POLL_INTERVAL then
		sinceCheck = 0;
		if paused == "unit" and ReadyToResume() and not InteractionWindowOpen() then
			Resume();
		end
		Evaluate();
	end
end);

local function UpdatePoller()
	poller:SetShown(ready and IsActive());
end

local handlers = {};

-- Forever Loot Sparkles 2.x puts its old soft targeting values back at login
-- and once more 5 seconds later. This module starts after that.
local START_DELAY = 6;
local startAt;

local function TryStart()
	if ForeverLootSparklesDB and ForeverLootSparklesDB.savedCVars and GetTime() < startAt + 30 then
		C_Timer.After(0.5, TryStart); -- its restore hasn't run yet (combat): wait for it
		return;
	end
	ready = true;
	-- a pause left over from the last session (logout while paused)
	ApplyAutoMode(); -- before Resume, which forgets db.pausedInteract
	if db.pausedInteract ~= nil and not InCombatLockdown() then
		Resume();
	end
	if IsActive() then
		ApplyCVars();
	end
	UpdatePoller();
end

function handlers.PLAYER_LOGIN()
	startAt = GetTime() + START_DELAY;
	C_Timer.After(START_DELAY, TryStart);
end

-- Account-synced settings can arrive after PLAYER_LOGIN and overwrite ours
function handlers.VARIABLES_LOADED()
	if ready and IsActive() then
		ApplyCVars();
	end
end

function handlers.PLAYER_ENTERING_WORLD()
	wipe(interactionTypes); -- a loading screen closes every NPC window
	handlers.VARIABLES_LOADED();
end

-- Cvars can't change in combat: close the nameplate just before. Left open, every
-- lootable corpse would keep a 0% health nameplate until the fight ends; the
-- price is that nodes don't sparkle during combat.
function handlers.PLAYER_REGEN_DISABLED()
	if ready and IsActive() then
		SetGate(false);
		Release();
		if SafeCastMode() ~= "off" then
			Pause("combat");
		end
	end
end

function handlers.PLAYER_REGEN_ENABLED()
	if pendingCVars == "apply" then
		ApplyCVars(pendingForce);
	elseif pendingCVars == "restore" then
		RestoreCVars();
	end
	pendingCVars, pendingForce = false, false;
	if paused == "combat" then
		Resume();
	end
	Evaluate();
end

function handlers.NAME_PLATE_UNIT_ADDED(unit)
	activeUnits[unit] = true;
	Evaluate();
end

function handlers.NAME_PLATE_UNIT_REMOVED(unit)
	activeUnits[unit] = nil;
	local plate = GetNamePlate(unit);
	if plate and plate == sparkle.anchor then
		Release();
	end
end

-- Windows opened through the interaction manager (most NPC windows in newer clients)
function handlers.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(interactionType)
	interactionTypes[interactionType or "?"] = true;
end

function handlers.PLAYER_INTERACTION_MANAGER_FRAME_HIDE(interactionType)
	if interactionType ~= nil and interactionTypes[interactionType] then
		interactionTypes[interactionType] = nil;
	else
		wipe(interactionTypes);
	end
	Evaluate();
end

function handlers.PLAYER_SOFT_INTERACT_CHANGED(oldTarget, newTarget)
	-- a nameplate recycled from one target to the next doesn't show the change by itself
	if not IsSecret(oldTarget) and not IsSecret(newTarget) and oldTarget and newTarget and oldTarget ~= newTarget then
		sparkle.retarget = sparkle.anchor ~= nil;
	end
	Evaluate();
end

local events = CreateFrame("Frame");
events:SetScript("OnEvent", function(_, event, ...)
	if db then
		handlers[event](...);
	end
end);
for event in pairs(handlers) do
	pcall(events.RegisterEvent, events, event);
end

---------------------------------------------------------------------------
-- /flscolor target: what the addon sees on the current interaction target
---------------------------------------------------------------------------

function ns.DebugTarget()
	local function out(...)
		local parts = {};
		for i = 1, select("#", ...) do
			parts[#parts + 1] = tostring((select(i, ...)));
		end
		print("  " .. table.concat(parts, " "));
	end
	print("|cffffd200Forever Loot Sparkles - Herbs & Ores:|r interaction target");
	out("ready=", ready, "active=", db and IsActive(), "paused=", paused, "gate=", gateOpen);
	out("safeCast=", db and SafeCastMode(), "auto=", db and db.safeSelfCastAuto, "backoff=", backoff,
		"npcWindow=", InteractionWindowOpen(), "service=", IsServiceNPC(SOFT));
	out("cvars: Interact=", GetCVarValue("SoftTargetInteract"), "IconGameObject=", GetCVarValue("SoftTargetIconGameObject"),
		"NameplateInteract=", GetCVarValue("SoftTargetNameplateInteract"), "Range=", GetCVarValue("SoftTargetInteractRange"));
	local unit, plate, unknown = ResolveTarget();
	out("unit=", unit, "plate=", plate ~= nil, "unknown=", unknown);
	local u = unit or SOFT;
	local name = SafeCall(UnitName, u);
	local guid = SafeCall(UnitGUID, u);
	out("name=", name, "guid=", guid, "objectID=", ObjectID(u));
	out("gameObject=", SafeCall(UnitIsGameObject, u), "exists=", SafeCall(UnitExists, u), "dead=", SafeCall(UnitIsDead, u));
	local texture, atlas = ns.CursorTexture(u);
	out("cursor texture=", texture, "atlas=", atlas);
	local category, blocked = Classify(u, name);
	out("classified=", category, "blocked=", blocked, "footlocker=", IsFootlocker(u, name),
		"option=", db and db.sparkleFootlocker);
	out("sparkle shown=", sparkle.frame and sparkle.frame:IsShown(), "category=", sparkle.category);
end

---------------------------------------------------------------------------
-- Interface for Options.lua
---------------------------------------------------------------------------

ns.SPARKLE_DEFAULTS = DEFAULTS;

-- Called at ADDON_LOADED with this addon's saved variables
function ns.SparkleInit(savedVariables)
	db = savedVariables;
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil then
			db[key] = value;
		end
	end
	-- 2.2.4 and older had a checkbox (safeSelfCast); unticked means "off"
	if not SAFE_CAST_MODES[db.safeSelfCastMode] then
		if db.safeSelfCast == false then
			db.safeSelfCastMode, db.safeSelfCastAuto = "off", false;
		else
			db.safeSelfCastAuto = true;
		end
	end
	if db.safeSelfCastAuto == nil then
		db.safeSelfCastAuto = false;
	end
	ApplyAutoMode();
	if not SAFE_CAST_MODES[db.safeSelfCastMode] then
		db.safeSelfCastMode = "units";
	end
	db.safeSelfCast = db.safeSelfCastMode ~= "off";
	if db.hidePlate == nil then
		db.hidePlate = true;
	end
	UpdatePoller();
end

-- A sparkle checkbox changed (value: its new state)
function ns.SparkleOptionChanged(value)
	if not ready then
		return;
	end
	Refresh(value == true);
	UpdatePoller();
end

-- The player picked a mode (dropdown, or the checkbox where there is no dropdown)
function ns.SafeSelfCastChanged()
	db.safeSelfCastAuto = false;
	if not SAFE_CAST_MODES[db.safeSelfCastMode] then
		db.safeSelfCastMode = "units";
	end
	db.safeSelfCast = db.safeSelfCastMode ~= "off";
	local mode = db.safeSelfCastMode;
	if paused and (mode == "off" or (mode == "combat" and paused == "unit")) then
		Resume();
	end
	backoff = 0;
end

ns.SAFE_CAST_MODES = { "off", "combat", "units" };
ns.InteractionWindowOpen = InteractionWindowOpen; -- also used by IconHider.lua
function ns.SafeCastMode()
	return SafeCastMode();
end

function ns.HidePlateChanged()
	if db.hidePlate and sparkle.anchor then
		Veil(sparkle.anchor);
	else
		Unveil();
	end
end
