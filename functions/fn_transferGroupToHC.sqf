/*
    Function: KPLIB_fnc_transferGroupToHC
    
    Description:
        Transfers a group to the least loaded headless client if available.
        Does nothing if the group is not local or no headless clients are present.
        
    Parameters:
        _group - The group to transfer [GROUP]
        
    Returns:
        Boolean - True if transfer was attempted, false if skipped due to conditions
    
    Examples:
        (begin example)
        [_myGroup] call KPLIB_fnc_transferGroupToHC;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-16
*/

params [
    ["_group", grpNull, [grpNull]]
];

// Exit if invalid group or not local
if (isNull _group || !local _group) exitWith {
    diag_log format ["[KPLIB] Skipping HC transfer for group %1 - Not local or null", _group];
    false
};

// Find the least loaded headless client
private _headless_client = [] call KPLIB_fnc_getLessLoadedHC;

// If we have a valid headless client, transfer the group
if (!isNull _headless_client) then {
    diag_log format ["[KPLIB] Transferring group %1 to headless client %2", _group, _headless_client];
    _group setGroupOwner (owner _headless_client);
    true
} else {
    diag_log "[KPLIB] No headless clients available for group transfer";
    false
}; 