/*
    Function: KPLIB_fnc_reinforcementsResetter
    
    Description:
        Handles resetting of the reinforcement system after a timeout.
        Uses CBA per frame handler to monitor the reinforcement state
        and resets it when appropriate.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        call KPLIB_fnc_reinforcementsResetter;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-21
*/

// Initialize variables if they don't exist
if (isNil "reinforcements_set") then {
    reinforcements_set = false;
};
if (isNil "reinforcements_sector_under_attack") then {
    reinforcements_sector_under_attack = "";
};

// Define the reset timeout (30 minutes)
private _reset_time = 1800;

// Variable to track the PFH handle
private _pfh_handle = -1;

// Function to handle the reset process when reinforcements are set
private _fnc_startResetTimer = {
    params ["_reset_time"];
    
    private _start_time = time;
    ["Reinforcement resetter activated - timeout in 30 minutes", "REINFORCEMENTS"] call KPLIB_fnc_log;
    
    // Wait until either timeout expires or reinforcements_set changes again
    [{
        params ["_args", "_pfh_handle"];
        _args params ["_start_time", "_reset_time"];
        
        // Check if reinforcements got set again or timeout expired
        if (!reinforcements_set || (time > (_start_time + _reset_time))) then {
            // Only reset sector if no big town attack is active
            if (!reinforcements_set && !([] call KPLIB_fnc_isBigtownActive)) then {
                reinforcements_sector_under_attack = "";
                ["Reinforcement sector reset", "REINFORCEMENTS"] call KPLIB_fnc_log;
            };
            
            // Remove the PFH since we're done
            [_pfh_handle] call CBA_fnc_removePerFrameHandler;
        };
    }, 5, [_start_time, _reset_time]] call CBA_fnc_addPerFrameHandler;
};

// Main monitoring PFH
[{
    params ["_reset_time", "_fnc_startResetTimer"];
    
    // Check if reinforcements have been set
    if (reinforcements_set) then {
        // Reset flag immediately
        reinforcements_set = false;
        
        // Start the reset timer
        [_reset_time] call _fnc_startResetTimer;
    };
}, 1, [_reset_time, _fnc_startResetTimer]] call CBA_fnc_addPerFrameHandler; 