/*
    File: fn_createManagedUnit.sqf
    Author: [NZF] JD Wang
    Date: 2024-11-16
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Creates a unit managed by kill tracker, spawning directly on headless client if available.

    Parameter(s):
        _type       - Type of unit              [STRING, defaults to ""]
        _spawnPos   - Where to spawn            [ARRAY|OBJECT|GROUP, defaults to [0, 0, 0]]
        _group      - Group to add the unit to  [GROUP, defaults to grpNull]
        _rank       - Unit rank                 [STRING, defaults to "PRIVATE"]
        _placement  - Placement radius          [NUMBER, defaults to 0]

    Returns:
        Created unit [OBJECT]
*/

params [
    ["_type", "", [""]],
    ["_spawnPos", [0, 0, 0], [[], objNull, grpNull], [2, 3]],
    ["_group", grpNull, [grpNull]],
    ["_rank", "PRIVATE", [""]],
    ["_placement", 0, [0]]
];

// Exit if invalid parameters
if (_type isEqualTo "" || isNull _group) exitWith {
    diag_log format ["[KPLIB] Error in fn_createManagedUnit: Invalid parameters - Type: %1, Group: %2", _type, _group];
    objNull
};

// Get the least loaded headless client
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Create the unit directly on the local machine if we own the target machine
if (_owner == clientOwner) then {
    [_type, _spawnPos, _group, _rank, _placement] call KPLIB_fnc_createManagedUnitRemote
} else {
    // Otherwise create it remotely using JIP to ensure we get the object back
    private _unit = [_type, _spawnPos, _group, _rank, _placement] remoteExecCall ["KPLIB_fnc_createManagedUnitRemote", _owner, true];
    _unit
}
