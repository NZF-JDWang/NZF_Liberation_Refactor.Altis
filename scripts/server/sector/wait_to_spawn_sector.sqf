/*
    Function: wait_to_spawn_sector
    
    Description:
        Waits for appropriate conditions before spawning sector units.
        Implements progressive delays based on friendly unit count in sector.
    
    Parameters:
        _sector - The sector marker to manage
        _opforcount - Number of opfor units
        _callbackFn - Function to call after waiting conditions are met
        _callbackParams - Additional parameters for the callback

    Returns:
        None
    
    Author: [NZF] JD Wang
    Date: 2023-10-15
*/

params [
    ["_sector", "", [""]],
    ["_opforcount", 0, [0]],
    ["_callbackFn", {}, [{}]],
    ["_callbackParams", [], [[], objNull]]
];

// Initialize active_sectors if it doesn't exist
if (isNil "active_sectors") then {
    active_sectors = [];
};

// Ensure sector is in active_sectors
if !(_sector in active_sectors) then {
    active_sectors pushbackUnique _sector;
    publicVariable "active_sectors";
};

private _start = diag_tickTime;
[format ["Sector %1 (%2) - Waiting to spawn sector...", (markerText _sector), _sector], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];

private _corrected_size = [_opforcount] call KPLIB_fnc_getSectorRange;

// Array of unit count thresholds that trigger delays
private _unitThresholds = [10, 6, 4, 3, 2, 1];
private _currentCheckIndex = 0;

// Function to perform the next check in sequence
private _fnc_performNextCheck = {
    params ["_sector", "_corrected_size", "_start", "_unitThresholds", "_currentCheckIndex", "_callbackFn", "_callbackParams", "_opforcount"];
    
    // If we've checked all thresholds, log completion and exit
    if (_currentCheckIndex >= count _unitThresholds) exitWith {
        [format ["Sector %1 (%2) - Waiting done - Time needed: %3 seconds", 
            (markerText _sector), _sector, diag_tickTime - _start], 
        "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
        
        // Execute the callback function with the provided params
        if (!isNil "_callbackFn") then {
            // When calling from manage_one_sector, _callbackParams should be passed as the third parameter
            diag_log format ["[KPLIB] DEBUG: Executing callback for sector %1. Sector: %2, OpforCount: %3, CallbackParams: %4", 
                _sector, _sector, _opforcount, _callbackParams];
            
            // Call the callback - ensure parameters match what the function expects
            [_sector, _opforcount, _callbackParams] call _callbackFn;
            
            // Only remove from active_sectors after callback is complete and a short delay
            [{
                params ["_sector"];
                if (_sector in active_sectors) then {
                    active_sectors = active_sectors - [_sector];
                    publicVariable "active_sectors";
                    [format ["Sector %1 (%2) deactivated - Was managed on: %3", (markerText _sector), _sector, debug_source], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
                };
            }, [_sector], 2] call CBA_fnc_waitAndExecute;
        };
    };
    
    // Get the current threshold to check
    private _currentThreshold = _unitThresholds select _currentCheckIndex;
    
    // Get current units count
    private _unitscount = [markerPos _sector, _corrected_size, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount;
    
    // Log current check
    if (KP_liberation_sectorspawn_debug > 0) then {
        [format ["Sector %1 (%2) - Check %3: Units count %4 / Threshold %5", 
            (markerText _sector), _sector, _currentCheckIndex, _unitscount, _currentThreshold], 
        "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
    };
    
    // Check against threshold - units > 0 for all except last check where we only check if == 1
    private _thresholdMet = false;
    if (_currentCheckIndex == (count _unitThresholds) - 1) then {
        _thresholdMet = (_unitscount == _currentThreshold);
    } else {
        _thresholdMet = (_unitscount > 0 && _unitscount <= _currentThreshold);
    };
    
    // If threshold is met, wait 5 seconds before next check
    if (_thresholdMet) then {
        if (KP_liberation_sectorspawn_debug > 0) then {
            [format ["Sector %1 (%2) - Threshold %3 met, waiting 5 seconds...", 
                (markerText _sector), _sector, _currentThreshold], 
            "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
        };
        
        [
            _fnc_performNextCheck, 
            [_sector, _corrected_size, _start, _unitThresholds, _currentCheckIndex + 1, _callbackFn, _callbackParams, _opforcount],
            5
        ] call CBA_fnc_waitAndExecute;
    } else {
        // If threshold not met, continue to next check with minimal delay
        [
            _fnc_performNextCheck, 
            [_sector, _corrected_size, _start, _unitThresholds, _currentCheckIndex + 1, _callbackFn, _callbackParams, _opforcount],
            0.1
        ] call CBA_fnc_waitAndExecute;
    };
};

// Start checking sequence
[_fnc_performNextCheck, [_sector, _corrected_size, _start, _unitThresholds, 0, _callbackFn, _callbackParams, _opforcount], 0.1] call CBA_fnc_waitAndExecute;
