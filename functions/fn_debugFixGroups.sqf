/*
    Function: KPLIB_fnc_debugFixGroups
    
    Description:
        Debug tool to fix AI groups that are standing in place instead of following waypoints.
        Can be called through debug console by authorized players.
        
    Parameters:
        _sector - Optional sector to focus on (if empty, all sectors are checked) [STRING, defaults to ""]
        
    Returns:
        Number of groups fixed [NUMBER]
        
    Examples:
        (begin example)
        [] call KPLIB_fnc_debugFixGroups; // Fix all groups
        ["factory_12"] call KPLIB_fnc_debugFixGroups; // Fix only groups in a specific sector
        (end)
        
    Author: [NZF] JD Wang
    Date: 2024-11-16
*/

params [
    ["_sector", "", [""]]
];

// Only admins or server can use this
if !(isServer || {serverCommandAvailable "#kick"}) exitWith {
    hint "Only admins can execute this command";
    0
};

// Show hint to player that command was received
if (hasInterface) then {
    hint "Attempting to fix AI groups without waypoints...";
};

// Call the fix standing groups function
private _fixedCount = [_sector] call KPLIB_fnc_fixStandingGroups;

// Show result to player if they have interface
if (hasInterface) then {
    hint format ["Fixed %1 groups without proper waypoints", _fixedCount];
};

// Log result
diag_log format ["[KPLIB] Debug command fixed %1 groups without proper waypoints", _fixedCount];

// Return the number of fixed groups
_fixedCount 