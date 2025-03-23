/*
    Function: KPLIB_fnc_counterBattlegroup
    
    Description:
        Monitors player vehicles and spawns counter-attack air groups against tanks or aircraft.
        Uses non-blocking CBA functions instead of scheduled execution.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_counterBattlegroup;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-30
*/

// Initialize weights if needed
if (isNil "infantry_weight") then {infantry_weight = 33;};
if (isNil "armor_weight") then {armor_weight = 33;};
if (isNil "air_weight") then {air_weight = 33;};

// Start the counter battlegroup system with initial delay
[{
    // Main monitoring function
    [{
        params ["_args", "_handle"];
        
        // Exit if conditions not met
        if (!(GRLIB_csat_aggressivity >= 0.9 && GRLIB_endgame == 0)) exitWith {
            [_handle] call CBA_fnc_removePerFrameHandler;
        };
        
        // Calculate sleep time based on various factors
        private _sleeptime = (1800 + (random 1800)) / (([] call KPLIB_fnc_getOpforFactor) * GRLIB_csat_aggressivity);
        
        // Adjust sleep time based on readiness
        if (combat_readiness >= 80) then {_sleeptime = _sleeptime * 0.75;};
        if (combat_readiness >= 90) then {_sleeptime = _sleeptime * 0.75;};
        if (combat_readiness >= 95) then {_sleeptime = _sleeptime * 0.75;};
        
        // Schedule next check after proper delay
        [_handle] call CBA_fnc_removePerFrameHandler;
        [{
            // Check combat readiness and armor/air weights
            if (combat_readiness < 70 || {armor_weight < 50 && air_weight < 50}) exitWith {
                // Start a new counter battlegroup cycle
                [] call KPLIB_fnc_counterBattlegroup;
            };
            
            // Look for players in tanks or aircraft
            private _target_player = objNull;
            {
                if (
                    (armor_weight >= 50 && {(objectParent _x) isKindOf "Tank"})
                    || (air_weight >= 50 && {(objectParent _x) isKindOf "Air"})
                ) exitWith {
                    _target_player = _x;
                };
            } forEach (allPlayers - entities "HeadlessClient_F");
            
            // Spawn air attack if valid target found
            if (!isNull _target_player) then {
                private _target_pos = [99999, getPos _target_player] call KPLIB_fnc_getNearestSector;
                if !(_target_pos isEqualTo "") then {
                    [_target_pos] call KPLIB_fnc_spawnAir;
                };
            };
            
            // Start a new counter battlegroup cycle
            [] call KPLIB_fnc_counterBattlegroup;
            
        }, [], _sleeptime] call CBA_fnc_waitAndExecute;
        
    }, 0, []] call CBA_fnc_addPerFrameHandler;
    
}, [], 1800] call CBA_fnc_waitAndExecute; 