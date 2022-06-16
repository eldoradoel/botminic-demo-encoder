#if defined _botmimic_included
  #endinput
#endif
#define _botmimic_included

#define BM_MAGIC 0xdeadbeef

// New in 0x02: bookmarkCount and bookmarks list
// New in 0x03: removed bookmark, change whole frameinfo
// New in 0x04: add tickrate, add events
#define BINARY_FORMAT_VERSION 0x04

#define MAX_RECORD_NAME_LENGTH 64
#define DEFAULT_CATEGORY "default"
#define DEFAULT_RECORD_FOLDER "data/botmimic/"

enum struct event_bomb_planted
{
	int site;
}

enum struct event_item_drop
{
	int entity;
}

enum struct event_player_death
{
	int victim;
	int attacker;
	int hitgroup;
}

enum struct gameevent_t
{
	event_bomb_planted bomb_planted;
	event_item_drop item_drop;
	event_player_death player_death;
}

enum struct FrameInfo
{
	float pos[3];
	float ang[2]; // Ignore roll
	int buttons;
	int flags;
	MoveType mt;
	CSWeaponID newWeapon;
	gameevent_t events;
	int health;
	int armor;
	int hasDefuser;
	int hasHelmet;
}

enum BMError
{
	BM_NoError = 0,
	BM_BadClient, // Provided client index is invalid
	BM_FileNotFound, // The file does not exists or can't be opened
	BM_BadFile, // Not a Bot Mimic record.
	BM_OlderBinaryVersion // The record was recorded with a older version of Bot Mimic and can't be played.
};

enum struct FileHeader
{
	int       FH_binaryFormatVersion;
	int       FH_tickrate;
	int       FH_recordEndTime;
	char      FH_recordName[MAX_RECORD_NAME_LENGTH];
	int       FH_tickCount;
	ArrayList FH_frames;
}

/**
 * Start to record the movements of a player.
 * It's stored in memory until told to write to disk.
 * 
 * Make sure the player isn't recording already.
 * 
 * @param client	The client to record
 * @param name		The name of the record (anything, not the filename)
 * @param category	The category to put this record in. This is used as a directory filename inside /data/botmimic/%CATEGORY%/%MAP_NAME%/stuff.rec
 * @param subdir	The subdirectory to organize records physically. This isn't used or retrieved back anywhere, just to better manage files by hand. /data/botmimic/%CATEGORY%/%MAP_NAME%/%SUBDIR%/stuff.rec
 */
native void BotMimic_StartRecording(int client, const char[] name, const char[] category = "", const char[] subdir = "");

/**
 * Pause recording the current record.
 * 
 * @param client	The recording client, which should pause recording.
 * @error			Invalid client index, client not recording or recording already paused.
 */
native void BotMimic_PauseRecording(int client);

/**
 * Resume recording the current record.
 * 
 * @param client		The recording client, which should resume recording.
 * @error				Invalid client index, client not recording or record not paused.
 */
native void BotMimic_ResumeRecording(int client);

/**
 * Check whether a client is currently paused recording a record.
 *
 * @param client	The client index of the player you want to know if he's paused.
 * @return			True if recording is paused, false otherwise.
 * @error			Invalid client index or client not recording.
 */
native bool BotMimic_IsRecordingPaused(int client);

/**
 * Stop recording and save or discard the record
 * 
 * @param client	The client which was recording
 * @param save		Save the record (true) or discard (false)
 */
native void BotMimic_StopRecording(int client, bool save = true);

/**
 * Deletes a record and does some checks, that the file is really a record.
 * 
 * @param path		The Path to the .rec recording file to delete.
 * @return			Number of bots, which were mimicing this record or -1 on error (file not found/invalid)
 */
native int BotMimic_DeleteRecord(const char[] path);

/**
 * Is the player currently recording something?
 * 
 * @param client	The client to check
 * @return			true, if player is recording, false otherwise
 */
native bool BotMimic_IsPlayerRecording(int client);

/**
 * Is the player currently mimicing something?
 * 
 * @param client	The client to check
 * @return			true, if the player is mimicing, false otherwise
 */
native bool BotMimic_IsPlayerMimicing(int client);

/**
 * Get the path to the record file this player is currently mimicing.
 *
 * @param client	The mimicing client
 * @param path		A String where to store the path
 * @param maxlen	The maximal length of the path
 */
native void BotMimic_GetRecordPlayerMimics(int client, char[] path, int maxlen);

/**
 * Let a client start to mimic a record from a file.
 *
 * @param client	The client, which should start mimicing
 * @param path		The path to a .rec recording file
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_PlayRecordFromFile(int client, const char[] path);

/**
 * Let a client start to mimic a record by providing the record name.
 * Since record names don't have to be unique, this native picks the most recent one.
 *
 * @param client	The client, which should start mimicing.
 * @param name		The name of the record to play.
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_PlayRecordByName(int client, const char[] name);

/**
 * Have a bot restart the record he's currently playing from the beginning.
 *
 * @param client   The client, who should start over with the record he's currently mimicing.
 */
native void BotMimic_ResetPlayback(int client);

/**
 * Pause a player from mimicing a record.
 *
 * @param client	The client who should pause mimicing
 */
native bool BotMimic_PausePlayerMimic(int client);

/**
 * Unpause a player from mimicing a record.
 *
 * @param client	The client who should unpause mimicing
 */
native bool BotMimic_UnpausePlayerMimic(int client);

/**
 * Stops a player from mimicing a record.
 *
 * @param client	The client who should stop mimicing
 */
native void BotMimic_StopPlayerMimic(int client);

/**
 * Get the Handle to a sorted adt_array, containing a list of paths to all loaded record files.
 * DON'T CLOSE THIS HANDLE!
 * Just use GetArrayString to read the path.
 *
 * @return Handle to sorted adt_array containing all paths to records
 */
native ArrayList BotMimic_GetLoadedRecordList();

/**
 * Get the Handle to a sorted adt_array, containing a list of categorys.
 * DON'T CLOSE THIS HANDLE!
 * Just use GetArrayString to read the category.
 *
 * @return Handle to sorted adt_array containing all categories.
 */
native ArrayList BotMimic_GetLoadedRecordCategoryList();

/**
 * Get the header information of a record. This includes the record name.
 *
 * @param path		The path to the .rec record file
 * @param header	An array to store the file header in.
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_GetFileHeaders(const char[] path, any[] header, int size = sizeof(FileHeader));

/**
 * Get the category of a record.
 *
 * @param path			The path to the .rec record file.
 * @param category	The String where to store the category in.
 * @param maxlen		The maximal length of the category buffer.
 * @return				true if category of file found, false otherwise
 */
native bool BotMimic_GetFileCategory(const char[] path, char[] category, int maxlen);

/**
 * Change the name of a record. This doesn't change the filename, but the stored record name inside the file. (BMTP_recordName)
 *
 * @param path	The path to the .rec record file which name to change.
 * @param name	The new name of the record
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_ChangeRecordName(const char[] path, char[] name);

/**
 * Set a bot should loop mimicing.
 *
 * @param client	The client who should set mimicing loop status.
 * @param set		The status of loop. Loop mimicing at end replay if true.
 */
native void BotMimic_SetPlayerMimicsLoop(int client, bool set);



// ======[ FORWARDS ]======

/**
 * Called when a player starts recording.
 * path is NOT the path to the .rec file, but just the path to the category folder (by default: Path_SM/data/botmimic/%CATEGORY%)
 *
 * @param client	The client index, who's being recorded
 * @param name		The name of the recording (stored in file header)
 * @param category	The category name
 * @param subdir	The subdir used to organize the record files (no further sense..)
 * @param path		The path to the category folder
 * @return			>= Plugin_Handled to abort recording or Plugin_Continue to let it pass and start recording.
 */
forward Action BotMimic_OnStartRecording(int client, char[] name, char[] category, char[] subdir, char[] path);

/**
 * Called when recording a record is paused or resumed.
 *
 * @param client	The client which recording pause state changed
 * @param paused	True when the recording was paused, false when it was unpaused
 */
forward void BotMimic_OnRecordingPauseStateChanged(int client, bool paused);

/**
 * Called when a player stops recording.
 * Change the save param if you want to prevent it from being discarded/written.
 *
 * @param client		The client who was recording.
 * @param name			The name of the record (stored in file header)
 * @param category	The category name.
 * @param subdir		The subdir used to organize the record files (no further sense..)
 * @param path			The path to the category folder
 * @param save			Set to true, if the record should be stored to disk, or false to discard.
 * @return				>= Plugin_Handled to continue recording, Plugin_Continue to let it stop.
 */
forward Action BotMimic_OnStopRecording(int client, char[] name, char[] category, char[] subdir, char[] path, bool &save);

/**
 * Called when a record was saved to file.
 *
 * @param client		The client who was recording.
 * @param name			The name of the record (stored in file header)
 * @param category	The category name.
 * @param subdir		The subdir used to organize the record files (no further sense..)
 * @param file			The actual path to the saved .rec file.
 */
forward void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file);

/**
 * Called when a record was deleted.
 * 
 * @param name		The name of the record (stored in file header)
 * @param category	The category of the file. (If it wasn't loaded before it defaults to "default".)
 * @param path		The path to the deleted file.
 */
forward void BotMimic_OnRecordDeleted(char[] name, char[] category, char[] path);

/**
 * Called when a player starts to mimic a record
 *
 * @param client		The client which starts mimicing.
 * @param name			The name of the record (stored in file header)
 * @param category	The category of the file.
 * @param path			The path to the record file.
 * @return 					>= Plugin_Handled to stop the player from mimicing, Plugin_Continue to allow
 */
forward Action BotMimic_OnPlayerStartsMimicing(int client, char[] name, char[] category, char[] path);

/**
 * Called when a player stops mimicing a record.
 *
 * @param client		The client who was mimicing
 * @param name			The name of the record (stored in file header)
 * @param category	The category of the file.
 * @param path			The path to the record file.
 */
forward void BotMimic_OnPlayerStopsMimicing(int client, char[] name, char[] category, char[] path);

/**
 * Called when a mimicing player starts to mimic the record again.
 *
 * @param client		The mimicing client
 */
forward void BotMimic_OnPlayerMimicLoopStart(int client);

/**
 * Called when a mimicing player on end mimicing.
 * (After that, player will mimic again)
 *
 * @param client		The mimicing client
 */
forward void BotMimic_OnPlayerMimicLoopEnd(int client);

/**
 * Translate an error id to a human readable string
 * 
 * @param error		The error id
 * @param str		The string to store the error message in
 * @param maxlen	The maximal length of the error message string
 */
stock void BotMimic_GetErrorString(BMError error, char[] str, int maxlen)
{
	switch(error)
	{
		case BM_BadClient:
		{
			strcopy(str, maxlen, "Invalid client index.");
		}
		case BM_FileNotFound:
		{
			strcopy(str, maxlen, "File not found.");
		}
		case BM_OlderBinaryVersion:
		{
			strcopy(str, maxlen, "The file was recorded with a older version of Bot Mimic and can't be played.");
		}
		case BM_BadFile:
		{
			strcopy(str, maxlen, "The file is not a record. Bad format.");
		}
		case BM_NoError:
		{
			strcopy(str, maxlen, "");
		}
	}
}

public SharedPlugin __pl_botmimic = 
{
	name = "botmimic",
	file = "botmimic.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_botmimic_SetNTVOptional()
{
	MarkNativeAsOptional("BotMimic_StartRecording");
	MarkNativeAsOptional("BotMimic_PauseRecording");
	MarkNativeAsOptional("BotMimic_ResumeRecording");
	MarkNativeAsOptional("BotMimic_IsRecordingPaused");
	MarkNativeAsOptional("BotMimic_StopRecording");
	MarkNativeAsOptional("BotMimic_DeleteRecord");
	MarkNativeAsOptional("BotMimic_IsPlayerRecording");
	MarkNativeAsOptional("BotMimic_IsPlayerMimicing");
	MarkNativeAsOptional("BotMimic_GetRecordPlayerMimics");
	MarkNativeAsOptional("BotMimic_PlayRecordFromFile");
	MarkNativeAsOptional("BotMimic_ResetPlayback");
	MarkNativeAsOptional("BotMimic_PlayRecordByName");
	MarkNativeAsOptional("BotMimic_PausePlayerMimic");
	MarkNativeAsOptional("BotMimic_UnpausePlayerMimic");
	MarkNativeAsOptional("BotMimic_StopPlayerMimic");
	MarkNativeAsOptional("BotMimic_GetLoadedRecordCategoryList");
	MarkNativeAsOptional("BotMimic_GetLoadedRecordList");
	MarkNativeAsOptional("BotMimic_GetFileHeaders");
	MarkNativeAsOptional("BotMimic_GetFileCategory");
	MarkNativeAsOptional("BotMimic_ChangeRecordName");
	MarkNativeAsOptional("BotMimic_SetPlayerMimicsLoop");
}
#endif
