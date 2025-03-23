/*
    Function: KPLIB_fnc_transferGroupsToHC
    
    Description:
        Transfers multiple groups to headless clients in a non-blocking way.
        Processes each group sequentially with proper delays.
    
    Parameters:
        _groups - [Array] Array of groups to transfer
    
    Returns:
        None
    
    Examples:
        (begin example)
        [_arrayOfGroups] call KPLIB_fnc_transferGroupsToHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

params [
    ["_groups", [], [[]]]
];

if (_groups isEqualTo []) exitWith {};

// Function to process groups recursively
private _fnc_processNextGroup = {
    params ["_remainingGroups", "_index"];
    
    // Get current group
    private _group = _remainingGroups select _index;
    
    // Transfer group to HC
    if (!isNull _group) then {
        [_group] call KPLIB_fnc_transferGroupToHC;
    };
    
    // Process next group if there are more
    if (_index + 1 < count _remainingGroups) then {
        [{
            _this call _fnc_processNextGroup;
        }, [_remainingGroups, _index + 1], 1] call CBA_fnc_waitAndExecute;
    };
};

// Start processing the groups
if (count _groups > 0) then {
    [_groups, 0] call _fnc_processNextGroup;
}; 