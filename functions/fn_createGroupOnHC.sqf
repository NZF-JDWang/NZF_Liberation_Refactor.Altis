/*
    Function: KPLIB_fnc_createGroupOnHC
    
    Description:
        Creates a group on the headless client if available, otherwise locally.
        This is a unified, simplified way to ensure all group creation happens on HC.
        
    Parameters:
        _side - Side of the group [SIDE]
        
    Returns:
        Group - The created group [GROUP]
    
    Examples:
        (begin example)
        _group = [GRLIB_side_enemy] call KPLIB_fnc_createGroupOnHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-11-17
*/

params [
    ["_side", GRLIB_side_enemy, [east]]
];

// Find the least loaded headless client
private _hc = [] call KPLIB_fnc_getLessLoadedHC;

// Create the group either on HC or locally
private _group = grpNull;

if (!isNull _hc) then {
    // HC available - create remotely on HC
    private _owner = owner _hc;
    
    // Create group remotely with a proper netId return value
    private _groupNetId = [_side] remoteExecCall ["createGroup", _owner, true];
    
    // Convert netId back to group object
    _group = _groupNetId call BIS_fnc_groupFromNetId;
    
    diag_log format ["[KPLIB] Created group %1 remotely on HC %2", _group, _hc];
} else {
    // No HC - create locally
    _group = createGroup [_side, true];
    diag_log format ["[KPLIB] Created group %1 locally (no HC available)", _group];
};

// Return the created group
_group 