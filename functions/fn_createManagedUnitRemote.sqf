/*
    File: fn_createManagedUnitRemote.sqf
    Author: [NZF] JD Wang
    Date: 2024-11-16
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Remote execution function that creates a unit on the machine that receives the remoteExec call.
        This is designed to be called from fn_createManagedUnit.sqf.

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

// Create the unit directly
private _unit = _group createUnit [_type, _spawnPos, [], _placement, "FORM"];

// Set rank and add kill manager
_unit setRank _rank;
_unit addMPEventHandler ["MPKilled", {_this spawn kill_manager}];

// Process KP object init
[_unit] call KPLIB_fnc_addObjectInit;

// Return the unit
_unit 