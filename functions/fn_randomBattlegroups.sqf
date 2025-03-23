/*
    Function: KPLIB_fnc_randomBattlegroups
    
    Description:
        Periodically spawns random enemy battlegroups based on combat readiness and other factors.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_randomBattlegroups;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

// Initial delay based on aggressivity
[{
    // Initial check function
    private _fnc_checkAndSpawn = {
        // Exit if conditions not met
        if (!(GRLIB_csat_aggressivity > 0.9 && GRLIB_endgame == 0)) exitWith {
            // Clean up handler if conditions are no longer valid
            [_this select 1] call CBA_fnc_removePerFrameHandler;
        };
        
        // Calculate sleep time based on various factors
        private _sleeptime = (1800 + (random 1800)) / (([] call KPLIB_fnc_getOpforFactor) * GRLIB_csat_aggressivity);
        
        // Adjust sleep time based on readiness
        if (combat_readiness >= 80) then {_sleeptime = _sleeptime * 0.75;};
        if (combat_readiness >= 90) then {_sleeptime = _sleeptime * 0.75;};
        if (combat_readiness >= 95) then {_sleeptime = _sleeptime * 0.75;};
        
        // This is now just the next scheduled execution time
        private _nextTime = CBA_missionTime + _sleeptime;
        
        // Wait for battlegroup cooldown if needed
        [{
            // Check if we need to wait for battlegroup cooldown
            if (!isNil "GRLIB_last_battlegroup_time") then {
                // Wait until the cooldown is over
                if (diag_tickTime < (GRLIB_last_battlegroup_time + (2100 / GRLIB_csat_aggressivity))) exitWith {
                    // Reschedule check for later
                    [_this select 0, 5] call CBA_fnc_waitAndExecute;
                };
            };
            
            // Check if conditions for spawning are met
            if (
                (count (allPlayers - entities "HeadlessClient_F") >= (6 / GRLIB_csat_aggressivity))
                && {combat_readiness >= (60 - (5 * GRLIB_csat_aggressivity))}
                && {[] call KPLIB_fnc_getOpforCap < GRLIB_battlegroup_cap}
                && {diag_fps > 15.0}
            ) then {
                ["", (random 100) < 45] call KPLIB_fnc_spawnBattlegroup;
            };
        }, [_nextTime], _sleeptime] call CBA_fnc_waitAndExecute;
    };
    
    // Start the periodic checking
    [_fnc_checkAndSpawn, 0, []] call CBA_fnc_addPerFrameHandler;
    
}, [], 900 / GRLIB_csat_aggressivity] call CBA_fnc_waitAndExecute; 