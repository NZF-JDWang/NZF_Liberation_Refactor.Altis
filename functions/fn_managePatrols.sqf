/*
    Function: KPLIB_fnc_managePatrols
    
    Description:
        Manages the enemy patrol system.
        Creates vehicle and infantry patrols based on combat readiness.
        Uses CBA non-blocking functions to improve performance.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_managePatrols;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-03-23
*/

if (!isServer) exitWith {};

// Define combat triggers based on unitcap
private _combat_triggers = [20, 40, 50, 65, 80, 95];
if (GRLIB_unitcap < 0.9) then { _combat_triggers = [20, 45, 90]; };
if (GRLIB_unitcap > 1.3) then { _combat_triggers = [15, 25, 40, 65, 75, 85, 95]; };

private _combat_triggers_infantry = [15, 35, 45, 60, 70, 85];
if (GRLIB_unitcap < 0.9) then { _combat_triggers_infantry = [15, 40, 80]; };
if (GRLIB_unitcap > 1.3) then { _combat_triggers_infantry = [10, 20, 35, 55, 70, 80, 90]; };

// Wait until mission is initialized and we have enough blufor sectors
[{
    !isNil "blufor_sectors" && {count blufor_sectors > 3}
}, {
    ["Starting patrol management system", "PATROLS"] call KPLIB_fnc_log;
    
    // Spawn vehicle patrols
    if (worldName != "song_bin_tanh") then {
        {
            // Use CBA function to add delay between patrol creations
            [{
                params ["_trigger"];
                [_trigger, false] call KPLIB_fnc_manageOnePatrol;
            }, [_x], _forEachIndex] call CBA_fnc_waitAndExecute;
        } forEach (_this select 0);
    };
    
    // Spawn infantry patrols
    {
        // Use CBA function to add delay between patrol creations
        [{
            params ["_trigger"];
            [_trigger, true] call KPLIB_fnc_manageOnePatrol;
        }, [_x], _forEachIndex + 10] call CBA_fnc_waitAndExecute;
    } forEach (_this select 1);
    
    ["Patrol management system initialized", "PATROLS"] call KPLIB_fnc_log;
}, [_combat_triggers, _combat_triggers_infantry]] call CBA_fnc_waitUntilAndExecute;

true 