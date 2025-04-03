/*
    Function: KPLIB_fnc_initPlayerNamespace
    
    Description:
        Initializes the player namespace tracking. Waits until synchronization flags 
        are set, then starts a per-frame handler to continuously update player state.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_initPlayerNamespace; 
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-04-03
*/

// Use CBA WaitUntilAndExecute to wait for synchronization flags
[
    // Condition Code
    {
        !isNil "one_synchro_done" 
        && {!isNil "one_eco_done"} 
        && {missionNamespace getVariable ["one_synchro_done", false]} 
        && {missionNamespace getVariable ["one_eco_done", false]}
    },
    // Code to execute once condition is met
    {
        // Start the per-frame handler to call the update function every second
        // Store handler in a variable if needed for later removal, but typically runs for mission duration.
        private _pfhID = ["KPLIB_updatePlayerNamespace", 1, [], {
            // Ensure player object exists before calling update logic
            if (!isNull player) then {
                [] call KPLIB_fnc_updatePlayerNamespace;
            };
        }] call CBA_fnc_addPerFrameHandler;
        
        // Optional: Log that the namespace tracking has started
        // diag_log text "[KPLIB] Player Namespace PFH started.";
    },
    // Parameters (if needed by condition or execution code, not needed here)
    [] 
] call CBA_fnc_waitUntilAndExecute; 