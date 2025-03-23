/*
    Function: KPLIB_fnc_monitorSectors
    
    Description:
        Monitors all sectors and FOBs to detect when they are taken by enemy forces.
        When a sector or FOB is detected as enemy-controlled, triggers the appropriate attack process.
        Uses CBA non-blocking functions to improve performance.
    
    Parameters:
        None
    
    Returns:
        None
    
    Examples:
        (begin example)
        [] call KPLIB_fnc_monitorSectors;
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-28
*/

if (!isServer) exitWith {};

// First wait until global variables are initialized
[{
    !isNil "GRLIB_all_fobs" && !isNil "blufor_sectors"
}, {
    ["Starting sector monitor", "SECTORS"] call KPLIB_fnc_log;
    
    // Set the global attack in progress variable
    attack_in_progress = false;
    
    // Main monitoring loop using CBA's per-frame handler
    private _sectorMonitorHandle = [{
        params ["_args", "_handle"];
        
        // Exit if endgame has been triggered
        if (GRLIB_endgame != 0) exitWith {
            [_handle] call CBA_fnc_removePerFrameHandler;
            ["Sector monitor stopped due to endgame", "SECTORS"] call KPLIB_fnc_log;
        };
        
        // Process blufor sectors with ownership check
        {
            private _ownership = [markerPos _x] call KPLIB_fnc_getSectorOwnership;
            if (_ownership == GRLIB_side_enemy) then {
                [_x] call KPLIB_fnc_attackInProgressSector;
            };
        } forEach blufor_sectors;
        
        // Process FOBs with ownership check
        {
            private _ownership = [_x] call KPLIB_fnc_getSectorOwnership;
            if (_ownership == GRLIB_side_enemy) then {
                [_x] call KPLIB_fnc_attackInProgressFOB;
            };
        } forEach GRLIB_all_fobs;
        
    }, 2, []] call CBA_fnc_addPerFrameHandler;
    
    // Log that the monitor has started
    [format ["Sector monitor started with handle: %1", _sectorMonitorHandle], "SECTORS"] call KPLIB_fnc_log;
    
}, []] call CBA_fnc_waitUntilAndExecute;

true 