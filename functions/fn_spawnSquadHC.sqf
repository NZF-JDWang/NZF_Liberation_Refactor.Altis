/*
    File: fn_spawnSquadHC.sqf
    Author: [NZF] JD Wang
    Date: 2024-03-29
    Description:
        Spawns a squad based on a composition variable name directly onto an available Headless Client (HC) or the server.
        Leverages KPLIB_fnc_createGroupOnHC and KPLIB_fnc_createManagedUnit for HC handling.
        Does NOT handle fireteam structure or AI assignment (these should be done via remoteExecCall afterwards).

    Parameter(s):
        _compositionName - Variable name of the squad composition array (e.g., "KPLIB_o_squadStd") [STRING]
        _position        - Position to spawn the group leader (can be sector name string) [ARRAY or OBJECT or STRING]
        _side            - Side for the group [SIDE, defaults to GRLIB_side_enemy]

    Returns:
        [Created Group (Group), Owner Client ID (Number)] or [grpNull, -1] on failure.
*/

params [
    ["_compositionName", "", [""]],
    ["_position", [0,0,0], [[], objNull, ""], [2, 3]],
    ["_side", GRLIB_side_enemy, [east]]
];

// Process potential sector name into position
private _finalPosition = _position;
if (_position isEqualType "" && {_position != ""}) then {
    diag_log format ["[KPLIB] fn_spawnSquadHC: Position is a string '%1', treating as sector name", _position];
    _finalPosition = markerPos _position;
    
    // Validate converted position
    if (_finalPosition isEqualTo [0,0,0]) then {
        diag_log format ["[KPLIB] Error: Invalid sector name '%1' provided to fn_spawnSquadHC, marker not found.", _position];
        _finalPosition = [random 100, random 100, 0]; // Fallback position for debug
    };
    
    diag_log format ["[KPLIB] fn_spawnSquadHC: Converted sector '%1' to position %2", _position, _finalPosition];
};

// 1. Validate and Resolve Composition Name
if (_compositionName isEqualTo "") exitWith {
    diag_log format ["[KPLIB] Error: Empty composition name provided to fn_spawnSquadHC."];
    [grpNull, -1]
};

private _compositionArray = missionNamespace getVariable [_compositionName, []];
if (_compositionArray isEqualTo []) exitWith {
    diag_log format ["[KPLIB] Error: Composition name '%1' not found or is empty in fn_spawnSquadHC.", _compositionName];
    [grpNull, -1]
};

diag_log format ["[KPLIB] fn_spawnSquadHC: Will spawn composition '%1' with %2 units at position %3", 
    _compositionName, count _compositionArray, _finalPosition];

// 2. Create Group on HC/Server
private _group = [_side] call KPLIB_fnc_createGroupOnHC;
if (isNull _group) exitWith {
    diag_log format ["[KPLIB] Error: Failed to create group for composition '%1' in fn_spawnSquadHC.", _compositionName];
    [grpNull, -1]
};

// 3. Determine Group Owner
private _ownerID = groupOwner _group;

diag_log format ["[KPLIB] fn_spawnSquadHC: Created group %1 (Owner: %2) for composition '%3' at %4.", _group, _ownerID, _compositionName, _finalPosition];

// 4. Spawn Units using Managed Unit function (handles remoteExec)
private _spawnedUnits = [];
{
    private _unitType = _x;
    // Spawn unit near the provided position, managed function handles HC locality.
    private _unit = [_unitType, _finalPosition, _group, "PRIVATE", 5] call KPLIB_fnc_createManagedUnit;
    if (!isNull _unit) then {
        // Blacklist the unit from ACE Headless Transfer
        _unit setVariable ["ace_headless_blacklist", true, true]; // Variable, Value, Persist/Broadcast
        _spawnedUnits pushBack _unit;
        diag_log format ["[KPLIB] fn_spawnSquadHC: Successfully spawned unit '%1' for group %2 (Blacklisted: %3)", _unitType, _group, _unit getVariable ["ace_headless_blacklist", false]];
    } else {
        diag_log format ["[KPLIB] Warning: Failed to spawn unit type '%1' for group %2 in fn_spawnSquadHC.", _unitType, _group];
    };
    // Small sleep to prevent overwhelming the engine during loop? Consider if needed.
    // sleep 0.01;
} forEach _compositionArray;

// 5. Final Check and Return
if (count _spawnedUnits != count _compositionArray) then {
    diag_log format ["[KPLIB] Warning: fn_spawnSquadHC - Mismatch between requested (%1) and spawned (%2) units for group %3.", count _compositionArray, count _spawnedUnits, _group];
};

if (count _spawnedUnits == 0 && count _compositionArray > 0) then {
    diag_log format ["[KPLIB] Error: fn_spawnSquadHC - Failed to spawn any units for group %1. Deleting group.", _group];
    deleteGroup _group;
    [grpNull, -1]
} else {
    diag_log format ["[KPLIB] fn_spawnSquadHC: Successfully spawned %1 units for group %2 (Owner: %3).", count _spawnedUnits, _group, _ownerID];
    [_group, _ownerID]
}; 