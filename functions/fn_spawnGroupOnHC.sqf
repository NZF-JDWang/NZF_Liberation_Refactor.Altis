/*
    Function: KPLIB_fnc_spawnGroupOnHC
    
    Description:
        Spawns a group directly on the least loaded headless client.
        If no headless client is available, spawns locally on the server.
        
    Parameters:
        _classnames - Array of unit classnames to spawn [ARRAY]
        _position   - Position to spawn the group [POSITION]
        _side       - Side of the group to create [SIDE, defaults to GRLIB_side_enemy]
        
    Returns:
        The created group [GROUP]
    
    Examples:
        (begin example)
        _group = [["O_Soldier_F", "O_Soldier_GL_F"], getMarkerPos "myMarker", EAST] call KPLIB_fnc_spawnGroupOnHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_classnames", [], [[]]],
    ["_position", [0,0,0], [[], objNull], [2, 3]],
    ["_side", GRLIB_side_enemy, [east]]
];

// Verify parameters
if (_classnames isEqualTo []) exitWith {
    ["KPLIB_fnc_spawnGroupOnHC: Empty classnames array provided"] call BIS_fnc_error;
    grpNull
};

// Get the least loaded headless client
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Execute group creation on target machine
private _group = [_classnames, _position, _side] remoteExecCall ["KPLIB_fnc_spawnGroupRemote", _owner, false];

// Return the group (will be null on machines other than where it was created)
_group 