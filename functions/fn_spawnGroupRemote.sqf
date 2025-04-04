/*
    Function: KPLIB_fnc_spawnGroupRemote
    
    Description:
        Remote execution function that creates a group on the machine that receives the remoteExec call.
        This is designed to be called from fn_spawnGroupOnHC.sqf.
        
    Parameters:
        _classnames - Array of unit classnames to spawn [ARRAY]
        _position   - Position to spawn the group [POSITION]
        _side       - Side of the group to create [SIDE]
        
    Returns:
        The created group [GROUP]
    
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_classnames", [], [[]]],
    ["_position", [0,0,0], [[], objNull], [2, 3]],
    ["_side", GRLIB_side_enemy, [east]]
];

// Create the group
private _group = createGroup [_side, true];

// Log the creation
diag_log format ["[KPLIB][HC] Creating group with %1 units at position %2", count _classnames, _position];

// Spawn each unit
{
    private _unit = _group createUnit [_x, _position, [], 20, "FORM"];
    _unit addMPEventHandler ["MPKilled", {_this spawn kill_manager}];
    [_unit] call KPLIB_fnc_addObjectInit;
} forEach _classnames;

// Return the group
_group 