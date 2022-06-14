#include <botmimic>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>
#include <dhooks>



#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name        = "Bot Mimic Fix",
	author      = "Peace-Maker, 5E Developer Team",
	description = "Bots mimic your movements, fix lots of things",
	version     = "3.0",
	url         = "null"
}


float gF_Tickrate;

// Array of frames
ArrayList gA_PlayerFrames[MAXPLAYERS + 1];
// Is the recording currently paused?
bool gB_PlayerPaused[MAXPLAYERS + 1];
bool gB_SaveFullSnapshot[MAXPLAYERS + 1];
// How many calls to OnPlayerRunCmd were recorded?
int gI_PlayerFrames[MAXPLAYERS + 1];
// What's the last active weapon
int gI_PlayerPreviousWeapon[MAXPLAYERS + 1];
// The name of this recording
char gS_RecordName[MAXPLAYERS + 1][MAX_RECORD_NAME_LENGTH];
char gS_RecordPath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char gS_RecordCategory[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char gS_RecordSubDir[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

StringMap gSM_LoadedMimics;
StringMap gSM_LoadedMimicsCategory;
ArrayList gA_SortedMimicList;
ArrayList gA_SortedCategoryList;

ArrayList gA_BotMimics[MAXPLAYERS + 1] = { null, ... };
int gI_BotMimicTick[MAXPLAYERS + 1] = { 0, ... };
int gI_BotMimicTickCount[MAXPLAYERS + 1] = { 0, ... };
int gI_BotActiveWeapon[MAXPLAYERS + 1] = { -1, ... };
bool gB_BotSwitchedWeapon[MAXPLAYERS + 1];
bool gB_PauseBotMimic[MAXPLAYERS+1] = { false, ... };

float gF_PlaybackSpeed = 1.0;
bool gB_DoMiddleFrame[MAXPLAYERS+1];
bool gB_ShouldLoop[MAXPLAYERS+1];

DynamicHook gH_UpdateStepSound = null;

GlobalForward gH_Forward_OnStartRecording = null;
GlobalForward gH_Forward_OnRecordingPauseStateChanged = null;
GlobalForward gH_Forward_OnStopRecording = null;
GlobalForward gH_Forward_OnRecordSaved = null;
GlobalForward gH_Forward_OnRecordDeleted = null;
GlobalForward gH_Forward_OnPlayerStartsMimicing = null;
GlobalForward gH_Forward_OnPlayerStopsMimicing = null;
GlobalForward gH_Forward_OnPlayerMimicLoopStart = null;
GlobalForward gH_Forward_OnPlayerMimicLoopEnd = null;



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("botmimic");

	CreateNative("BotMimic_StartRecording", StartRecording);
	CreateNative("BotMimic_PauseRecording", PauseRecording);
	CreateNative("BotMimic_ResumeRecording", ResumeRecording);
	CreateNative("BotMimic_IsRecordingPaused", IsRecordingPaused);
	CreateNative("BotMimic_StopRecording", StopRecording);
	CreateNative("BotMimic_DeleteRecord", DeleteRecord);
	CreateNative("BotMimic_IsPlayerRecording", IsPlayerRecording);
	CreateNative("BotMimic_IsPlayerMimicing", IsPlayerMimicing);
	CreateNative("BotMimic_GetRecordPlayerMimics", GetRecordPlayerMimics);
	CreateNative("BotMimic_PlayRecordFromFile", PlayRecordFromFile);
	CreateNative("BotMimic_PlayRecordByName", PlayRecordByName);
	CreateNative("BotMimic_ResetPlayback", ResetPlayback);
	CreateNative("BotMimic_PausePlayerMimic", PausePlayerMimic);
	CreateNative("BotMimic_UnpausePlayerMimic", UnpausePlayerMimic);
	CreateNative("BotMimic_StopPlayerMimic", StopPlayerMimic);
	CreateNative("BotMimic_GetFileHeaders", GetFileHeaders);
	CreateNative("BotMimic_ChangeRecordName", ChangeRecordName);
	CreateNative("BotMimic_GetLoadedRecordCategoryList", GetLoadedRecordCategoryList);
	CreateNative("BotMimic_GetLoadedRecordList", GetLoadedRecordList);
	CreateNative("BotMimic_GetFileCategory", GetFileCategory);
	CreateNative("BotMimic_SetPlayerMimicsLoop", SetPlayerMimicsLoop);

	gH_Forward_OnStartRecording             = new GlobalForward("BotMimic_OnStartRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	gH_Forward_OnRecordingPauseStateChanged = new GlobalForward("BotMimic_OnRecordingPauseStateChanged", ET_Ignore, Param_Cell, Param_Cell);
	gH_Forward_OnStopRecording              = new GlobalForward("BotMimic_OnStopRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_CellByRef);
	gH_Forward_OnRecordSaved                = new GlobalForward("BotMimic_OnRecordSaved", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	gH_Forward_OnRecordDeleted              = new GlobalForward("BotMimic_OnRecordDeleted", ET_Ignore, Param_String, Param_String, Param_String);
	gH_Forward_OnPlayerStartsMimicing       = new GlobalForward("BotMimic_OnPlayerStartsMimicing", ET_Hook, Param_Cell, Param_String, Param_String, Param_String);
	gH_Forward_OnPlayerStopsMimicing        = new GlobalForward("BotMimic_OnPlayerStopsMimicing", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);
	gH_Forward_OnPlayerMimicLoopStart       = new GlobalForward("BotMimic_OnPlayerMimicLoopStart", ET_Ignore, Param_Cell);
	gH_Forward_OnPlayerMimicLoopEnd         = new GlobalForward("BotMimic_OnPlayerMimicLoopEnd", ET_Ignore, Param_Cell);
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_speed", Command_Speed);

	AutoExecConfig();

	gF_Tickrate = (1.0 / GetTickInterval());

	// Maps path to .rec -> record enum
	gSM_LoadedMimics = new StringMap();

	// Maps path to .rec -> record category
	gSM_LoadedMimicsCategory = new StringMap();

	// Save all paths to .rec files in the trie sorted by time
	gA_SortedMimicList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_SortedCategoryList = new ArrayList(ByteCountToCells(64));

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("bomb_planted", Event_OnBomb_Planted);
	HookEvent("bomb_defused", Event_OnBomb_Defused);
	HookEvent("bomb_exploded", Event_OnBomb_Exploded);

	LoadDhooks();

	// lateload
	for(int i = 0; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsFakeClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

void LoadDhooks()
{
	GameData gamedata = new GameData("botmimic.games");

	if (gamedata == null)
	{
		SetFailState("Failed to load botmimic gamedata");
	}

	int iOffset;

	if ((iOffset = GameConfGetOffset(gamedata, "CBasePlayer::UpdateStepSound")) != -1)
	{
		gH_UpdateStepSound = new DynamicHook(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
		gH_UpdateStepSound.AddParam(HookParamType_ObjectPtr);
		gH_UpdateStepSound.AddParam(HookParamType_VectorPtr);
		gH_UpdateStepSound.AddParam(HookParamType_VectorPtr);
	}
	else
	{
		LogError("Couldn't get the offset for \"CBasePlayer::UpdateStepSound\" - make sure your gamedata is updated!");
	}

	delete gamedata;
}

public Action Command_Speed(int client, int args)
{
	if(args == 0)
	{
		return Plugin_Handled;
	}

	char sArg[32];
	GetCmdArg(1, sArg, sizeof(sArg));

	float speed = StringToFloat(sArg);

	if(speed >= 2.0)
	{
		speed = 2.0;
	}
	else if(speed >= 1.0)
	{
		speed = 1.0;
	}
	else
	{
		speed = 0.5;
	}

	gF_PlaybackSpeed = speed;

	PrintToChat(client, "speed -> %f", gF_PlaybackSpeed);

	return Plugin_Handled;
}

public void OnMapStart()
{
	// Clear old records for old map
	int    iSize = gA_SortedMimicList.Length;
	char   sPath[PLATFORM_MAX_PATH];
	FileHeader header;

	for (int i = 0; i < iSize; i++)
	{
		gA_SortedMimicList.GetString(i, sPath, sizeof(sPath));
		if (!gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader)))
		{
			LogError("Internal state error. %s was in the sorted list, but not in the actual storage.", sPath);
			continue;
		}
		if (header.FH_frames != null)
			delete header.FH_frames;
	}
	gSM_LoadedMimics.Clear();
	gSM_LoadedMimicsCategory.Clear();
	gA_SortedMimicList.Clear();
	gA_SortedCategoryList.Clear();

	// Create our record directory
	BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
	if (!DirExists(sPath))
		CreateDirectory(sPath, 511);

	// Check for categories
	DirectoryListing hDir = OpenDirectory(sPath);
	if (hDir == null)
		return;

	char     sFile[64];
	FileType fileType;
	while (hDir.GetNext(sFile, sizeof(sFile), fileType))
	{
		switch (fileType)
		{
			// Check all directories for records on this map
			case FileType_Directory:
			{
				// INFINITE RECURSION ANYONE?
				if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
					continue;

				BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, sFile);
				ParseRecordsInDirectory(sPath, sFile, false);
			}
		}
	}
	delete hDir;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		gH_UpdateStepSound.HookEntity(Hook_Pre, client, Hook_UpdateStepSound_Pre);
		gH_UpdateStepSound.HookEntity(Hook_Post, client, Hook_UpdateStepSound_Post);

		SDKHook(client, SDKHook_OnTakeDamage, Bot_OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamagePost, Bot_OnTakeDamagePost);

		gB_DoMiddleFrame[client] = false;
		gB_ShouldLoop[client] = false;
	}
}

public Action Bot_OnTakeDamage(int victim, int &attacker)
{
	if(gA_BotMimics[victim] == null)
	{
		return Plugin_Continue;
	}

	SetEntityMoveType(victim, MOVETYPE_WALK);

	return Plugin_Continue;
}

public void Bot_OnTakeDamagePost(int victim)
{
	if(gA_BotMimics[victim] == null)
	{
		return;
	}

	SetEntityMoveType(victim, MOVETYPE_NOCLIP);
}

// Remove flags from replay bots that cause CBasePlayer::UpdateStepSound to return without playing a footstep.
public MRESReturn Hook_UpdateStepSound_Pre(int pThis, DHookParam hParams)
{
	if(gA_BotMimics[pThis] == null)
	{
		return MRES_Ignored;
	}

	if (GetEntityMoveType(pThis) == MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(pThis, MOVETYPE_WALK);
	}

	SetEntityFlags(pThis, GetEntityFlags(pThis) & ~FL_ATCONTROLS);

	return MRES_Ignored;
}

// Readd flags to replay bots now that CBasePlayer::UpdateStepSound is done.
public MRESReturn Hook_UpdateStepSound_Post(int pThis, DHookParam hParams)
{
	if(gA_BotMimics[pThis] == null)
	{
		return MRES_Ignored;
	}

	if (GetEntityMoveType(pThis) == MOVETYPE_WALK)
	{
		SetEntityMoveType(pThis, MOVETYPE_NOCLIP);
	}

	SetEntityFlags(pThis, GetEntityFlags(pThis) | FL_ATCONTROLS);

	return MRES_Ignored;
}

public void OnClientDisconnect(int client)
{
	if (gA_PlayerFrames[client] != null)
		BotMimic_StopRecording(client);

	if (gA_BotMimics[client] != null)
		BotMimic_StopPlayerMimic(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	// Client isn't recording or recording is paused.
	if (!BotMimic_IsPlayerRecording(client) || gB_PlayerPaused[client])
	{
		return;
	}

	FrameInfo frame;

	GetClientAbsOrigin(client, frame.pos);

	float ang[3];
	GetClientEyeAngles(client, ang);
	frame.ang[0] = ang[0];
	frame.ang[1] = ang[1];

	frame.buttons = buttons;
	frame.flags = GetEntityFlags(client);
	frame.mt = GetEntityMoveType(client);

	frame.newWeapon     = CSWeapon_NONE;

	int iNewWeapon = -1;

	// Did he change his weapon?
	if (weapon)
	{
		iNewWeapon = weapon;
	}
	// Picked up a new one?
	else
	{
		int iWeapon = Client_GetActiveWeapon(client);

		// He's holding a weapon and
		if (iWeapon != -1 &&
		    // we just started recording. Always save the first weapon!
		    (gI_PlayerFrames[client] == 0 ||
		     // This is a new weapon, he didn't held before.
		     gI_PlayerPreviousWeapon[client] != iWeapon))
		{
			iNewWeapon = iWeapon;
		}
	}

	if (iNewWeapon != -1)
	{
		// Save it
		if (IsValidEntity(iNewWeapon) && IsValidEdict(iNewWeapon))
		{
			gI_PlayerPreviousWeapon[client] = iNewWeapon;

			char sClassName[64];
			GetEdictClassname(iNewWeapon, sClassName, sizeof(sClassName));
			ReplaceString(sClassName, sizeof(sClassName), "weapon_", "", false);

			char sWeaponAlias[64];
			CS_GetTranslatedWeaponAlias(sClassName, sWeaponAlias, sizeof(sWeaponAlias));
			CSWeaponID weaponId = CS_AliasToWeaponID(sWeaponAlias);

			frame.newWeapon = weaponId;
		}
	}

	gA_PlayerFrames[client].PushArray(frame, sizeof(FrameInfo));

	gI_PlayerFrames[client]++;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	// Bot is not mimicing.
	if (gA_BotMimics[client] == null)
	{
		return Plugin_Continue;
	}

	// Is this a valid living bot?
	if (!IsPlayerAlive(client) || !IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	bool reachLimit = gI_BotMimicTick[client] >= gI_BotMimicTickCount[client];

	if (reachLimit)
	{
		Call_StartForward(gH_Forward_OnPlayerMimicLoopEnd);
		Call_PushCell(client);
		Call_Finish();

		if(!gB_ShouldLoop[client]) // not loop anymore, stop them from mimicing
		{
			BotMimic_StopPlayerMimic(client);

			return Plugin_Continue;
		}
		else
		{
			gI_BotMimicTick[client] = 0;
		}
	}

	// Is bot pausing
	// or the game is freezeing
	if(gB_PauseBotMimic[client])
	{
		vel[0] = 0.0;
		vel[1] = 0.0;

		FrameInfo frame;
		gA_BotMimics[client].GetArray(gI_BotMimicTick[client], frame, 6);

		float ang[3];
		ang[0] = frame.ang[0];
		ang[1] = frame.ang[1];

		TeleportEntity(client, frame.pos, ang, NULL_VECTOR);

		buttons = (frame.buttons & IN_DUCK) ? IN_DUCK : 0;

		return Plugin_Changed;
	}

	float vecPreviousPos[3];

	if (gF_PlaybackSpeed == 2.0)
	{
		int previousTick = (gI_BotMimicTick[client] > 0) ? (gI_BotMimicTick[client] - 1) : 0;
		gA_BotMimics[client].GetArray(previousTick, vecPreviousPos, 3);
	}
	else
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", vecPreviousPos);
	}

	FrameInfo frame;
	gA_BotMimics[client].GetArray(gI_BotMimicTick[client], frame, sizeof(FrameInfo));

	buttons = frame.buttons;
	weapon  = 0;

	bool bWalk = false;
	MoveType mt = MOVETYPE_NOCLIP;

	int iReplayFlags = frame.flags;

	int iEntityFlags = GetEntityFlags(client);

	ApplyFlags(iEntityFlags, iReplayFlags, FL_ONGROUND);
	ApplyFlags(iEntityFlags, iReplayFlags, FL_PARTIALGROUND);
	ApplyFlags(iEntityFlags, iReplayFlags, FL_INWATER);
	ApplyFlags(iEntityFlags, iReplayFlags, FL_SWIM);

	SetEntityFlags(client, iEntityFlags);

	if(frame.mt == MOVETYPE_LADDER)
	{
		mt = frame.mt;
	}
	else if(frame.mt == MOVETYPE_WALK && (iReplayFlags & FL_ONGROUND) > 0)
	{
		bWalk = true;
	}

	SetEntityMoveType(client, mt);

	if (gF_PlaybackSpeed == 0.5 && gB_DoMiddleFrame[client] && gI_BotMimicTick[client] + 1 < gI_BotMimicTickCount[client])
	{
		FrameInfo asdf;
		gA_BotMimics[client].GetArray(gI_BotMimicTick[client] + 1, asdf, 5); // 5 is pos + ang

		float middle[3];
		MakeVectorFromPoints(frame.pos, asdf.pos, middle);
		ScaleVector(middle, 0.5);
		AddVectors(frame.pos, middle, frame.pos);

		frame.ang[0] = (frame.ang[0] + asdf.ang[0]) / 2.0;
		float diff = GetAngleDiff(asdf.ang[1], frame.ang[1]);
		frame.ang[1] = AngleNormalize(frame.ang[1] + diff / 2.0);
	}

	float vecVelocity[3];
	MakeVectorFromPoints(vecPreviousPos, frame.pos, vecVelocity);
	ScaleVector(vecVelocity, gF_Tickrate);

	float ang[3];
	ang[0] = frame.ang[0];
	ang[1] = frame.ang[1];

	// replay is going above 10k speed, just teleport at this point
	// bot is on ground.. if the distance between the previous position is much bigger (1.5x) than the expected according
	// to the bot's velocity, teleport to avoid sync issues
	if(gF_PlaybackSpeed == 2.0 || (GetVectorLength(vecVelocity) > 10000.0 ||
		(bWalk && GetVectorDistance(vecPreviousPos, frame.pos) > GetVectorLength(vecVelocity) / gF_Tickrate * 1.5)))
	{
		TeleportEntity(client, frame.pos, ang, gF_PlaybackSpeed == 2.0 ? vecVelocity : NULL_VECTOR);
	}
	else
	{
		TeleportEntity(client, NULL_VECTOR, ang, vecVelocity);
	}

	// This is the first tick.
	if (gI_BotMimicTick[client] == 0)
	{
		Client_RemoveAllWeapons(client);

		Call_StartForward(gH_Forward_OnPlayerMimicLoopStart);
		Call_PushCell(client);
		Call_Finish();
	}

	if (frame.newWeapon != CSWeapon_NONE)
	{
		char sAlias[64];
		CS_WeaponIDToAlias(frame.newWeapon, sAlias, sizeof(sAlias));

		Format(sAlias, sizeof(sAlias), "weapon_%s", sAlias);
		int currentWeapon = GetWeapon(client, sAlias);

		if (gI_BotMimicTick[client] > 0 && currentWeapon != -1)
		{
			weapon                       = currentWeapon;
			gI_BotActiveWeapon[client]   = weapon;
			gB_BotSwitchedWeapon[client] = true;
		}
		else
		{
			weapon = GivePlayerItem(client, sAlias);
			if (weapon != INVALID_ENT_REFERENCE)
			{
				gI_BotActiveWeapon[client]   = weapon;
				// Switch to that new weapon on the next frame.
				gB_BotSwitchedWeapon[client] = true;

				// Grenades shouldn't be equipped.
				if (StrContains(sAlias, "grenade") == -1
				    && StrContains(sAlias, "flashbang") == -1
				    && StrContains(sAlias, "decoy") == -1
				    && StrContains(sAlias, "molotov") == -1)
				{
					EquipPlayerWeapon(client, weapon);
				}
			}
		}
	}
	// Switch the weapon on the next frame after it was selected.
	else if (gB_BotSwitchedWeapon[client])
	{
		gB_BotSwitchedWeapon[client] = false;
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", gI_BotActiveWeapon[client]);
		Client_SetActiveWeapon(client, gI_BotActiveWeapon[client]);
	}

	if(frame.events.bomb_planted.m_bBombPlanted && !GameRules_GetProp("m_bBombPlanted"))
	{
		DoPlantBomb(client, frame.events.bomb_planted.site);
	}

	if (gF_PlaybackSpeed == 2.0)
	{
		gI_BotMimicTick[client] += 2;
	}
	else if (gF_PlaybackSpeed == 1.0)
	{
		gI_BotMimicTick[client] += 1;
	}
	else // if (gF_PlaybackSpeed == 0.5)
	{
		if (gB_DoMiddleFrame[client])
		{
			gI_BotMimicTick[client] += 1;
		}

		gB_DoMiddleFrame[client] = !gB_DoMiddleFrame[client];
	}

	return Plugin_Changed;
}

void ApplyFlags(int &flags1, int flags2, int flag)
{
	if((flags2 & flag) != 0)
	{
		flags1 |= flag;
	}
	else
	{
		flags1 &= ~flag;
	}
}

float GetAngleDiff(float current, float previous)
{
	float diff = current - previous;
	return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}

float AngleNormalize(float flAngle)
{
	if (flAngle > 180.0)
	{
		flAngle -= 360.0;
	}
	else if (flAngle < -180.0)
	{
		flAngle += 360.0;
	}

	return flAngle;
}

/**
 * Event Callbacks
 */
public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	// Restart moving on spawn!
	if (gA_BotMimics[client] != null)
	{
		gI_BotMimicTick[client] = 0;
	}
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	// This one has been recording currently
	if (gA_PlayerFrames[client] != null)
	{
		BotMimic_StopRecording(client, true);
	}
	// This bot has been playing one
	else if (gA_BotMimics[client] != null)
	{
		// Respawn the bot after death!
		gI_BotMimicTick[client] = 0;
	}
}

public void Event_OnBomb_Planted(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client) || !BotMimic_IsPlayerRecording(client))
	{
		return;
	}

	int site = event.GetInt("site");

	int idx = gI_PlayerFrames[client] - 1;
	FrameInfo aFrame;
	gA_PlayerFrames[client].GetArray(idx, aFrame, sizeof(FrameInfo));

	aFrame.events.bomb_planted.m_bBombPlanted = true;
	aFrame.events.bomb_planted.site = site;
	gA_PlayerFrames[client].SetArray(idx, aFrame, sizeof(FrameInfo));
}

public void Event_OnBomb_Defused(Event event, const char[] name, bool dontBroadcast)
{
	CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, CSRoundEnd_CTWin, true);
}

public void Event_OnBomb_Exploded(Event event, const char[] name, bool dontBroadcast)
{
	CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, CSRoundEnd_TerroristWin, true);
}

/**
 * SDKHooks Callbacks
 */
// Don't allow mimicing players any other weapon than the one recorded!!
public Action Hook_WeaponCanSwitchTo(int client, int weapon)
{
	if (gA_BotMimics[client] == null)
	{
		return Plugin_Continue;
	}

	if (gI_BotActiveWeapon[client] != weapon)
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

/**
 * Natives
 */
public int StartRecording(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (gA_PlayerFrames[client] != null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is already recording.");
		return;
	}

	if (gA_BotMimics[client] != null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is currently mimicing another record.");
		return;
	}

	gA_PlayerFrames[client]                   = new ArrayList(sizeof(FrameInfo));
	gI_PlayerFrames[client]          = 0;

	GetNativeString(2, gS_RecordName[client], MAX_RECORD_NAME_LENGTH);
	GetNativeString(3, gS_RecordCategory[client], PLATFORM_MAX_PATH);
	GetNativeString(4, gS_RecordSubDir[client], PLATFORM_MAX_PATH);

	if (gS_RecordCategory[client][0] == '\0')
		strcopy(gS_RecordCategory[client], sizeof(gS_RecordCategory[]), DEFAULT_CATEGORY);

	// Path:
	// data/botmimic/%CATEGORY%/map_name/%SUBDIR%/record.rec
	// subdir can be omitted, default category is "default"

	// All demos reside in the default path (data/botmimic)
	BuildPath(Path_SM, gS_RecordPath[client], PLATFORM_MAX_PATH, "%s%s", DEFAULT_RECORD_FOLDER, gS_RecordCategory[client]);

	// Remove trailing slashes
	if (gS_RecordPath[client][strlen(gS_RecordPath[client]) - 1] == '\\' || gS_RecordPath[client][strlen(gS_RecordPath[client]) - 1] == '/')
		gS_RecordPath[client][strlen(gS_RecordPath[client]) - 1] = '\0';

	Action result;
	Call_StartForward(gH_Forward_OnStartRecording);
	Call_PushCell(client);
	Call_PushString(gS_RecordName[client]);
	Call_PushString(gS_RecordCategory[client]);
	Call_PushString(gS_RecordSubDir[client]);
	Call_PushString(gS_RecordPath[client]);
	Call_Finish(result);

	if (result >= Plugin_Handled)
		BotMimic_StopRecording(client, false);
}

public int PauseRecording(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (gA_PlayerFrames[client] == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}

	if (gB_PlayerPaused[client])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Recording is already paused.");
		return;
	}

	gB_PlayerPaused[client] = true;

	Call_StartForward(gH_Forward_OnRecordingPauseStateChanged);
	Call_PushCell(client);
	Call_PushCell(true);
	Call_Finish();
}

public int ResumeRecording(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (gA_PlayerFrames[client] == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}

	if (!gB_PlayerPaused[client])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Recording is not paused.");
		return;
	}

	// Save the new full position, angles and velocity.
	gB_SaveFullSnapshot[client] = true;

	gB_PlayerPaused[client] = false;

	Call_StartForward(gH_Forward_OnRecordingPauseStateChanged);
	Call_PushCell(client);
	Call_PushCell(false);
	Call_Finish();
}

public int IsRecordingPaused(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}

	if (gA_PlayerFrames[client] == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return false;
	}

	return gB_PlayerPaused[client];
}

public int StopRecording(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	// Not recording..
	if (gA_PlayerFrames[client] == null)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}

	bool save = GetNativeCell(2);

	Action result;
	Call_StartForward(gH_Forward_OnStopRecording);
	Call_PushCell(client);
	Call_PushString(gS_RecordName[client]);
	Call_PushString(gS_RecordCategory[client]);
	Call_PushString(gS_RecordSubDir[client]);
	Call_PushString(gS_RecordPath[client]);
	Call_PushCellRef(save);
	Call_Finish(result);

	// Don't stop recording?
	if (result >= Plugin_Handled)
		return;

	if (save)
	{
		int iEndTime = GetTime();

		char sMapName[64], sPath[PLATFORM_MAX_PATH];
		GetCurrentMap(sMapName, sizeof(sMapName));

		// Check if the default record folder exists?
		BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
		// Remove trailing slashes
		if (sPath[strlen(sPath) - 1] == '\\' || sPath[strlen(sPath) - 1] == '/')
			sPath[strlen(sPath) - 1] = '\0';

		if (!CheckCreateDirectory(sPath, 511))
			return;

		// Check if the category folder exists?
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, gS_RecordCategory[client]);
		if (!CheckCreateDirectory(sPath, 511))
			return;

		// Check, if there is a folder for this map already
		Format(sPath, sizeof(sPath), "%s/%s", gS_RecordPath[client], sMapName);
		if (!CheckCreateDirectory(sPath, 511))
			return;

		// Check if the subdirectory exists
		if (gS_RecordSubDir[client][0] != '\0')
		{
			Format(sPath, sizeof(sPath), "%s/%s", sPath, gS_RecordSubDir[client]);
			if (!CheckCreateDirectory(sPath, 511))
				return;
		}

		Format(sPath, sizeof(sPath), "%s/%s.rec", sPath, gS_RecordName[client]);

		// Add to our loaded record list
		FileHeader header;
		header.FH_binaryFormatVersion = BINARY_FORMAT_VERSION;
		header.FH_tickrate            = RoundFloat(gF_Tickrate);
		header.FH_recordEndTime       = iEndTime;
		header.FH_tickCount           = gA_PlayerFrames[client].Length;
		strcopy(header.FH_recordName, MAX_RECORD_NAME_LENGTH, gS_RecordName[client]);
		header.FH_frames = gA_PlayerFrames[client];

		WriteRecordToDisk(sPath, header);

		gSM_LoadedMimics.SetArray(sPath, header, sizeof(FileHeader));
		gSM_LoadedMimicsCategory.SetString(sPath, gS_RecordCategory[client]);
		gA_SortedMimicList.PushString(sPath);
		if (gA_SortedCategoryList.FindString(gS_RecordCategory[client]) == -1)
			gA_SortedCategoryList.PushString(gS_RecordCategory[client]);
		SortRecordList();

		Call_StartForward(gH_Forward_OnRecordSaved);
		Call_PushCell(client);
		Call_PushString(gS_RecordName[client]);
		Call_PushString(gS_RecordCategory[client]);
		Call_PushString(gS_RecordSubDir[client]);
		Call_PushString(sPath);
		Call_Finish();
	}
	else
	{
		delete gA_PlayerFrames[client];
	}

	gA_PlayerFrames[client]                      = null;
	gI_PlayerFrames[client]                  = 0;
	gI_PlayerPreviousWeapon[client]           = 0;
	gS_RecordName[client][0]                  = 0;
	gS_RecordPath[client][0]                  = 0;
	gS_RecordCategory[client][0]              = 0;
	gS_RecordSubDir[client][0]                = 0;
	gB_PlayerPaused[client]                = false;
	gB_SaveFullSnapshot[client]               = false;
}

public int DeleteRecord(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen + 1];
	GetNativeString(1, sPath, iLen + 1);

	// Do we have this record loaded?
	FileHeader header;
	if (!gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader)))
	{
		if (!FileExists(sPath))
			return -1;

		// Try to load it to make sure it's a record file we're deleting here!
		BMError error = LoadRecordFromFile(sPath, DEFAULT_CATEGORY, header, true, false);
		if (error == BM_FileNotFound || error == BM_BadFile)
			return -1;
	}

	int iCount;
	if (header.FH_frames != null)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			// Stop the bots from mimicing this one
			if (gA_BotMimics[i] == header.FH_frames)
			{
				BotMimic_StopPlayerMimic(i);
				iCount++;
			}
		}

		// Discard the frames
		delete header.FH_frames;
	}

	char sCategory[64];
	gSM_LoadedMimicsCategory.GetString(sPath, sCategory, sizeof(sCategory));

	gSM_LoadedMimics.Remove(sPath);
	gSM_LoadedMimicsCategory.Remove(sPath);
	gA_SortedMimicList.Erase(gA_SortedMimicList.FindString(sPath));

	// Delete the file
	if (FileExists(sPath))
	{
		DeleteFile(sPath);
	}

	Call_StartForward(gH_Forward_OnRecordDeleted);
	Call_PushString(header.FH_recordName);
	Call_PushString(sCategory);
	Call_PushString(sPath);
	Call_Finish();

	return iCount;
}

public int IsPlayerRecording(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}

	return gA_PlayerFrames[client] != null;
}

public int IsPlayerMimicing(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}

	return gA_BotMimics[client] != null;
}

public int GetRecordPlayerMimics(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}

	int iLen     = GetNativeCell(3);
	char[] sPath = new char[iLen];
	GetFileFromFrameHandle(gA_BotMimics[client], sPath, iLen);
	SetNativeString(2, sPath, iLen);
}

public any PausePlayerMimic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client) || !BotMimic_IsPlayerMimicing(client))
	{
		return false;
	}

	gB_PauseBotMimic[client] = true;

	return true;
}

public any UnpausePlayerMimic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client) || !BotMimic_IsPlayerMimicing(client))
	{
		return false;
	}

	gB_PauseBotMimic[client] = false;

	return true;
}

public int StopPlayerMimic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}

	char sPath[PLATFORM_MAX_PATH];
	GetFileFromFrameHandle(gA_BotMimics[client], sPath, sizeof(sPath));

	gA_BotMimics[client]                     = null;
	gI_BotMimicTick[client]                        = 0;
	gI_BotMimicTickCount[client]             = 0;

	FileHeader header;
	gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader));

	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);

	char sCategory[64];
	gSM_LoadedMimicsCategory.GetString(sPath, sCategory, sizeof(sCategory));

	Call_StartForward(gH_Forward_OnPlayerStopsMimicing);
	Call_PushCell(client);
	Call_PushString(header.FH_recordName);
	Call_PushString(sCategory);
	Call_PushString(sPath);
	Call_Finish();
}

public int PlayRecordFromFile(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return view_as<int>(BM_BadClient);
	}

	int iLen;
	GetNativeStringLength(2, iLen);
	char[] sPath = new char[iLen + 1];
	GetNativeString(2, sPath, iLen + 1);

	if (!FileExists(sPath))
		return view_as<int>(BM_FileNotFound);

	return view_as<int>(PlayRecord(client, sPath));
}

public int PlayRecordByName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return view_as<int>(BM_BadClient);
	}

	int iLen;
	GetNativeStringLength(2, iLen);
	char[] sName = new char[iLen + 1];
	GetNativeString(2, sName, iLen + 1);

	char sPath[PLATFORM_MAX_PATH];
	int  iSize = gA_SortedMimicList.Length;
	FileHeader header;
	int iRecentTimeStamp;
	char sRecentPath[PLATFORM_MAX_PATH];
	for (int i = 0; i < iSize; i++)
	{
		gA_SortedMimicList.GetString(i, sPath, sizeof(sPath));
		gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader));
		if (StrEqual(sName, header.FH_recordName))
		{
			if (iRecentTimeStamp == 0 || iRecentTimeStamp < header.FH_recordEndTime)
			{
				iRecentTimeStamp = header.FH_recordEndTime;
				strcopy(sRecentPath, sizeof(sRecentPath), sPath);
			}
		}
	}

	if (!iRecentTimeStamp || !FileExists(sRecentPath))
		return view_as<int>(BM_FileNotFound);

	return view_as<int>(PlayRecord(client, sRecentPath));
}

public int ResetPlayback(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}

	if (!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}

	gI_BotMimicTick[client] = 0;
}

public int GetFileHeaders(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen + 1];
	GetNativeString(1, sPath, iLen + 1);

	if (!FileExists(sPath))
	{
		return view_as<int>(BM_FileNotFound);
	}

	FileHeader header;
	if (!gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader)))
	{
		char sCategory[64];
		if (!gSM_LoadedMimicsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		BMError error = LoadRecordFromFile(sPath, sCategory, header, true, false);
		if (error != BM_NoError)
			return view_as<int>(error);
	}

	int iSize = sizeof(FileHeader);
	if (numParams > 2)
		iSize = GetNativeCell(3);
	if (iSize > sizeof(FileHeader))
		iSize = sizeof(FileHeader);

	SetNativeArray(2, header, iSize);

	return view_as<int>(BM_NoError);
}

public int ChangeRecordName(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen + 1];
	GetNativeString(1, sPath, iLen + 1);

	if (!FileExists(sPath))
	{
		return view_as<int>(BM_FileNotFound);
	}

	char sCategory[64];
	if (!gSM_LoadedMimicsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
		strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);

	FileHeader header;
	if (!gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader)))
	{
		BMError error = LoadRecordFromFile(sPath, sCategory, header, false, false);
		if (error != BM_NoError)
			return view_as<int>(error);
	}

	// Load the whole record first or we'd lose the frames!
	if (header.FH_frames == null)
		LoadRecordFromFile(sPath, sCategory, header, false, true);

	GetNativeStringLength(2, iLen);
	char[] sName = new char[iLen + 1];
	GetNativeString(2, sName, iLen + 1);

	strcopy(header.FH_recordName, MAX_RECORD_NAME_LENGTH, sName);
	gSM_LoadedMimics.SetArray(sPath, header, sizeof(FileHeader));

	WriteRecordToDisk(sPath, header);

	return view_as<int>(BM_NoError);
}

public int GetLoadedRecordCategoryList(Handle plugin, int numParams)
{
	return view_as<int>(gA_SortedCategoryList);
}

public int GetLoadedRecordList(Handle plugin, int numParams)
{
	return view_as<int>(gA_SortedMimicList);
}

public int GetFileCategory(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen + 1];
	GetNativeString(1, sPath, iLen + 1);

	iLen             = GetNativeCell(3);
	char[] sCategory = new char[iLen];
	bool bFound      = gSM_LoadedMimicsCategory.GetString(sPath, sCategory, iLen);

	SetNativeString(2, sCategory, iLen);
	return view_as<int>(bFound);
}

public any SetPlayerMimicsLoop(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	gB_ShouldLoop[client] = view_as<bool>(GetNativeCell(2));
}

/**
 * Helper functions
 */

void ParseRecordsInDirectory(const char[] sPath, const char[] sCategory, bool subdir)
{
	char sMapFilePath[PLATFORM_MAX_PATH];
	// We already are in the map folder? Don't add it again!
	if (subdir)
	{
		strcopy(sMapFilePath, sizeof(sMapFilePath), sPath);
	}
	// We're in a category. add the mapname to load the correct records for the current map
	else
	{
		char sMapName[64];
		GetCurrentMap(sMapName, sizeof(sMapName));
		Format(sMapFilePath, sizeof(sMapFilePath), "%s/%s", sPath, sMapName);
	}

	DirectoryListing hDir = OpenDirectory(sMapFilePath);
	if (hDir == null)
		return;

	char     sFile[64], sFilePath[PLATFORM_MAX_PATH];
	FileType fileType;
	FileHeader header;
	while (hDir.GetNext(sFile, sizeof(sFile), fileType))
	{
		switch (fileType)
		{
			// This is a record for this map.
			case FileType_File:
			{
				Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
				LoadRecordFromFile(sFilePath, sCategory, header, true, false);
			}
			// There's a subdir containing more records.
			case FileType_Directory:
			{
				// INFINITE RECURSION ANYONE?
				if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
					continue;

				Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
				ParseRecordsInDirectory(sFilePath, sCategory, true);
			}
		}
	}

	delete hDir;
}

void WriteRecordToDisk(const char[] sPath, FileHeader header)
{
	File hFile = OpenFile(sPath, "wb");
	if (hFile == null)
	{
		LogError("Can't open the record file for writing! (%s)", sPath);
		return;
	}

	hFile.WriteInt32(BM_MAGIC);
	hFile.WriteInt8(header.FH_binaryFormatVersion);
	hFile.WriteInt16(header.FH_tickrate);
	hFile.WriteInt32(header.FH_recordEndTime);
	hFile.WriteInt8(strlen(header.FH_recordName));
	hFile.WriteString(header.FH_recordName, false);

	int iTickCount = header.FH_tickCount;
	hFile.WriteInt32(iTickCount);

	any aFrameData[sizeof(FrameInfo)];
	for (int i = 0; i < iTickCount; i++)
	{
		header.FH_frames.GetArray(i, aFrameData, sizeof(FrameInfo));
		hFile.Write(aFrameData, sizeof(FrameInfo), 4);
	}

	delete hFile;
}

BMError LoadRecordFromFile(const char[] path, const char[] sCategory, FileHeader header, bool onlyHeader, bool forceReload)
{
	if (!FileExists(path))
		return BM_FileNotFound;

	// Make sure the handle references are null in the input structure.
	header.FH_frames    = null;

	// Already loaded that file?
	bool bAlreadyLoaded = false;
	if (gSM_LoadedMimics.GetArray(path, header, sizeof(FileHeader)))
	{
		// Header already loaded.
		if (onlyHeader && !forceReload)
			return BM_NoError;

		bAlreadyLoaded = true;
	}

	File hFile = OpenFile(path, "rb");
	if (hFile == null)
		return BM_FileNotFound;

	int iMagic;
	hFile.ReadInt32(iMagic);
	if (iMagic != BM_MAGIC)
	{
		delete hFile;
		return BM_BadFile;
	}

	int iBinaryFormatVersion;
	hFile.ReadUint8(iBinaryFormatVersion);
	header.FH_binaryFormatVersion = iBinaryFormatVersion;

	if (iBinaryFormatVersion < BINARY_FORMAT_VERSION)
	{
		delete hFile;
		return BM_OlderBinaryVersion;
	}

	hFile.ReadInt16(header.FH_tickrate);

	if (header.FH_tickrate != RoundFloat(gF_Tickrate))
	{
		gF_PlaybackSpeed = 0.5;
	}

	int iRecordTime, iNameLength;
	hFile.ReadInt32(iRecordTime);
	hFile.ReadUint8(iNameLength);
	char[] sRecordName = new char[iNameLength + 1];
	hFile.ReadString(sRecordName, iNameLength + 1, iNameLength);
	sRecordName[iNameLength] = '\0';

	int iTickCount;
	hFile.ReadInt32(iTickCount);

	header.FH_recordEndTime = iRecordTime;
	strcopy(header.FH_recordName, MAX_RECORD_NAME_LENGTH, sRecordName);
	header.FH_tickCount = iTickCount;

	delete header.FH_frames;

	gSM_LoadedMimics.SetArray(path, header, sizeof(FileHeader));
	gSM_LoadedMimicsCategory.SetString(path, sCategory);

	if (!bAlreadyLoaded)
		gA_SortedMimicList.PushString(path);

	if (gA_SortedCategoryList.FindString(sCategory) == -1)
		gA_SortedCategoryList.PushString(sCategory);

	// Sort it by record end time
	SortRecordList();

	if (onlyHeader)
	{
		delete hFile;
		return BM_NoError;
	}

	// Read in all the saved frames
	ArrayList hRecordFrames       = new ArrayList(sizeof(FrameInfo));

	any aFrameData[sizeof(FrameInfo)];
	for (int i = 0; i < iTickCount; i++)
	{
		hFile.Read(aFrameData, sizeof(FrameInfo), 4);
		hRecordFrames.PushArray(aFrameData, sizeof(FrameInfo));
	}

	header.FH_frames = hRecordFrames;

	gSM_LoadedMimics.SetArray(path, header, sizeof(FileHeader));

	delete hFile;

	return BM_NoError;
}

void SortRecordList()
{
	SortADTArrayCustom(gA_SortedMimicList, SortFuncADT_ByEndTime);
	SortADTArray(gA_SortedCategoryList, Sort_Descending, Sort_String);
}

public int SortFuncADT_ByEndTime(int index1, int index2, Handle arrayHndl, Handle hndl)
{
	char      path1[PLATFORM_MAX_PATH], path2[PLATFORM_MAX_PATH];
	ArrayList array = view_as<ArrayList>(arrayHndl);
	array.GetString(index1, path1, sizeof(path1));
	array.GetString(index2, path2, sizeof(path2));

	FileHeader header1, header2;
	gSM_LoadedMimics.GetArray(path1, header1, sizeof(FileHeader));
	gSM_LoadedMimics.GetArray(path2, header2, sizeof(FileHeader));

	return header1.FH_recordEndTime - header2.FH_recordEndTime;
}

BMError PlayRecord(int client, const char[] path)
{
	// He's currently recording. Don't start to play some record on him at the same time.
	if (gA_PlayerFrames[client] != null)
	{
		return BM_BadClient;
	}

	FileHeader header;
	gSM_LoadedMimics.GetArray(path, header, sizeof(FileHeader));

	// That record isn't fully loaded yet. Do that now.
	if (header.FH_frames == null)
	{
		char sCategory[64];
		if (!gSM_LoadedMimicsCategory.GetString(path, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		BMError error = LoadRecordFromFile(path, sCategory, header, false, true);
		if (error != BM_NoError)
			return error;
	}

	gA_BotMimics[client]                = header.FH_frames;
	gI_BotMimicTick[client]                   = 0;
	gI_BotMimicTickCount[client]        = header.FH_tickCount;
	gI_BotActiveWeapon[client]                = INVALID_ENT_REFERENCE;
	gB_BotSwitchedWeapon[client]              = false;

	SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

	// Respawn him to get him moving!
	if (IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T)
		CS_RespawnPlayer(client);

	char sCategory[64];
	gSM_LoadedMimicsCategory.GetString(path, sCategory, sizeof(sCategory));

	Action result;
	Call_StartForward(gH_Forward_OnPlayerStartsMimicing);
	Call_PushCell(client);
	Call_PushString(header.FH_recordName);
	Call_PushString(sCategory);
	Call_PushString(path);
	Call_Finish(result);

	// Someone doesn't want this guy to play that record.
	if (result >= Plugin_Handled)
	{
		gA_BotMimics[client]                     = null;
		gI_BotMimicTickCount[client]             = 0;
	}

	SetClientName(client, header.FH_recordName);

	return BM_NoError;
}

stock bool CheckCreateDirectory(const char[] sPath, int mode)
{
	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, mode);
		if (!DirExists(sPath))
		{
			LogError("Can't create a new directory. Please create one manually! (%s)", sPath);
			return false;
		}
	}
	return true;
}

stock void GetFileFromFrameHandle(ArrayList frames, char[] path, int maxlen)
{
	int  iSize = gA_SortedMimicList.Length;
	char sPath[PLATFORM_MAX_PATH];
	FileHeader header;
	for (int i = 0; i < iSize; i++)
	{
		gA_SortedMimicList.GetString(i, sPath, sizeof(sPath));
		gSM_LoadedMimics.GetArray(sPath, header, sizeof(FileHeader));
		if (header.FH_frames != frames)
			continue;

		strcopy(path, maxlen, sPath);
		break;
	}
}

stock bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}

/* -1 if not found */
stock int GetWeapon(int client, const char[] sClassname)
{
	char sBuffer[128];
	int iMaxWeapons = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");

	ArrayList arr = new ArrayList(ByteCountToCells(128));
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

		if (!IsValidEntity(iWeapon))
		{
			continue;
		}

		GetEntityClassname(iWeapon, sBuffer, sizeof(sBuffer));
		arr.PushString(sBuffer);

		if (StrEqual(sBuffer, sClassname, false) ||
			(StrEqual("weapon_hkp2000", sBuffer, false) && StrEqual("weapon_usp_silencer", sClassname, false)) ||
			(StrEqual("weapon_m4a1", sBuffer, false) && StrEqual("weapon_m4a1_silencer", sClassname, false)))
		{
			delete arr;
			return iWeapon;
		}
	}

	PrintToConsoleAll("client %N dont have weapon [%s], check pls!", client, sClassname);

	for(int i = 0; i < arr.Length; i++)
	{
		char sWeapon[128];
		arr.GetString(i, sWeapon, sizeof(sWeapon));
		PrintToConsoleAll(sWeapon);
	}

	delete arr;

	return -1;
}

void DoPlantBomb(int client, int site)
{
	int bombEntity = CreateEntityByName("planted_c4");

	GameRules_SetProp("m_bBombPlanted", 1);
	SetEntData(bombEntity, FindSendPropInfo("CPlantedC4", "m_bBombTicking"), 1, 1, true);

	Event event = CreateEvent("bomb_planted");

	if (event != null)
	{
		event.SetInt("userid", GetClientUserId(client));
		event.SetInt("site", site);
		event.Fire();
	}

	if (DispatchSpawn(bombEntity))
	{
		ActivateEntity(bombEntity);

		float pos[3];
		GetClientAbsOrigin(client, pos);
		TeleportEntity(bombEntity, pos, NULL_VECTOR, NULL_VECTOR);

		GroundEntity(bombEntity);
	}

	int c4 = GetPlayerWeaponSlot(client, 4);
	RemovePlayerItem(client, c4);
	RemoveEdict(c4);
}

void GroundEntity(int entity)
{
	float flPos[3], flAng[3];
	
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", flPos);
	flAng[0] = 90.0;
	flAng[1] = 0.0;
	flAng[2] = 0.0;
	Handle hTrace = TR_TraceRayFilterEx(flPos, flAng, MASK_SHOT, RayType_Infinite, TraceFilterIgnorePlayers, entity);
	if (hTrace != INVALID_HANDLE && TR_DidHit(hTrace))
	{
		float endPos[3];
		TR_GetEndPosition(endPos, hTrace);
		CloseHandle(hTrace);
		TeleportEntity(entity, endPos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		PrintToServer("Attempted to put entity on ground, but no end point found!");
	}
}

public bool TraceFilterIgnorePlayers(int entity, int contentsMask, int client)
{
	if (entity >= 1 && entity <= MaxClients)
	{
		return false;
	}

	return true;
}