/*
    Function: KPLIB_fnc_spawnPatrolGroupOnHC
    
    Description:
        Spawns a patrol group directly on a headless client with standard patrol waypoints.
        
    Parameters:
        _classnames    - Array of unit classnames to spawn [ARRAY]
        _position      - Position to spawn the group [POSITION]
        _patrolCenter  - Center position for patrol [POSITION]
        _patrolRadius  - Radius for patrol [NUMBER, defaults to 100]
        _side          - Side of the group to create [SIDE, defaults to GRLIB_side_enemy]
        
    Returns:
        The created group [GROUP]
    
    Examples:
        (begin example)
        _group = [["O_Soldier_F", "O_Soldier_GL_F"], getPos player, getMarkerPos "patrol_center", 200] call KPLIB_fnc_spawnPatrolGroupOnHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_classnames", [], [[]]],
    ["_position", [0,0,0], [[], objNull], [2, 3]],
    ["_patrolCenter", [0,0,0], [[], objNull], [2, 3]],
    ["_patrolRadius", 100, [0]],
    ["_side", GRLIB_side_enemy, [east]]
];

// Verify parameters
if (_classnames isEqualTo []) exitWith {
    ["KPLIB_fnc_spawnPatrolGroupOnHC: Empty classnames array provided"] call BIS_fnc_error;
    grpNull
};

// Get the least loaded headless client
private _hc = [] call KPLIB_fnc_getLessLoadedHC;
private _owner = if (isNull _hc) then {2} else {owner _hc};

// Execute group creation on target machine
private _group = [_classnames, _position, _patrolCenter, _patrolRadius, _side] remoteExecCall ["KPLIB_fnc_spawnPatrolGroupRemote", _owner, false];

// Return the group
_group 