/*
    File: fn_spawnMilitaryPostSquad.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2019-12-03
    Last Update: 2020-04-05
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns soldiers inside military cargo towers around given position.
        Uses LAMBS AI for enhanced defense behavior.
        Creates group directly on headless client for proper locality.

    Parameter(s):
        _pos - Center position of the area to look for military cargo towers [ARRAY, defaults to [0, 0, 0]]

    Returns:
        Spawned units [ARRAY]
    
    Author: [NZF] JD Wang
    Date: 2024-10-15
*/

params [
    ["_pos", [0, 0, 0], [[]]]
];

if (_pos isEqualTo [0, 0, 0]) exitWith {["No or zero pos given"] call BIS_fnc_error; []};

// Get all military patrol towers near given position
private _allPosts = (
    nearestObjects [_pos, ["Land_Cargo_Patrol_V1_F","Land_Cargo_Patrol_V2_F","Land_Cargo_Patrol_V3_F","Land_Cargo_Patrol_V4_F"], GRLIB_capture_size, true]
) select {alive _x};

// Exit if no patrol towers were found
if (_allPosts isEqualTo []) exitWith {[]};

// Get nearest sector marker
private _nearestSector = "";
private _shortestDistance = 9999;
{
    private _distance = _pos distance2D (markerPos _x);
    if (_distance < _shortestDistance) then {
        _shortestDistance = _distance;
        _nearestSector = _x;
    };
} forEach (sectors_allSectors select {_x in active_sectors});

// Get the least loaded headless client for spawning
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Create the group directly on the HC/server
private _grp = if (_owner == clientOwner) then {
    // Local creation if we are the target machine
    createGroup [GRLIB_side_enemy, true]
} else {
    // Remote create group on HC - needs to be done via remoteExec JIP
    private _groupNetId = [GRLIB_side_enemy] remoteExecCall ["createGroup", _owner, true];
    // Wait for the group to be created
    private _group = grpNull;
    waitUntil {
        _group = _groupNetId call BIS_fnc_groupFromNetId;
        !isNull _group
    };
    _group
};

// Log what's happening
diag_log format ["[KPLIB] Creating military post squad at %1 on machine %2 - Group: %3", _pos, _owner, _grp];

// Spawn units
private _unit = objNull;
private _units = [];
{
    _unit = [[opfor_marksman, opfor_machinegunner] select (random 100 > 50), _pos, _grp] call KPLIB_fnc_createManagedUnit;
    _unit setdir (180 + (getdir _x));
    _unit setpos (([_x] call BIS_fnc_buildingPositions) select 1);
    
    // Set unit position stance to UP
    _unit setUnitPos 'UP';
    
    // Start building defense AI with sector info
    [_unit, _nearestSector] spawn building_defence_ai;
    
    _units pushback _unit;
} forEach _allPosts;

// If LAMBS is available and multiple towers exist, coordinate defense
if (count _allPosts > 1) then {
    // Apply AI behavior to the entire group using our unified function
    [_grp, _owner, _nearestSector, "building_defense"] call KPLIB_fnc_applyAIBehavior;
} else {
    // For a single tower, we're using the individual building_defence_ai script
    // Units are already on the HC through fn_createManagedUnit.sqf
    diag_log format ["[KPLIB] Single tower post at %1 using individual building defense AI", _pos];
};

_units
