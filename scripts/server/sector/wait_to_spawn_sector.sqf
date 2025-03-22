/*
    Function: wait_to_spawn_sector
    
    Description:
        Waits for appropriate conditions before spawning sector units.
        Implements progressive delays based on friendly unit count in sector.
    
    Parameters:
        _sector - The sector marker to manage
        _opforcount - Number of opfor units
    
    Returns:
        None
    
    Author: [NZF] JD Wang
    Date: 2023-10-15
*/

params ["_sector", "_opforcount"];

private _start = diag_tickTime;
[format ["Sector %1 (%2) - Waiting to spawn sector...", (markerText _sector), _sector], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];

private _corrected_size = [_opforcount] call KPLIB_fnc_getSectorRange;

// Array of unit count thresholds that trigger delays
private _unitThresholds = [10, 6, 4, 3, 2, 1];
private _currentCheckIndex = 0;

// Function to perform the next check in sequence
private _fnc_performNextCheck = {
    params ["_sector", "_corrected_size", "_start", "_unitThresholds", "_currentCheckIndex"];
    
    // If we've checked all thresholds, log completion and exit
    if (_currentCheckIndex >= count _unitThresholds) exitWith {
        [format ["Sector %1 (%2) - Waiting done - Time needed: %3 seconds", 
            (markerText _sector), _sector, diag_tickTime - _start], 
        "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
    };
    
    // Get the current threshold to check
    private _currentThreshold = _unitThresholds select _currentCheckIndex;
    
    // Get current units count
    private _unitscount = [markerPos _sector, _corrected_size, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount;
    
    // Check against threshold - units > 0 for all except last check where we only check if == 1
    private _thresholdMet = false;
    if (_currentCheckIndex == (count _unitThresholds) - 1) then {
        _thresholdMet = (_unitscount == _currentThreshold);
    } else {
        _thresholdMet = (_unitscount > 0 && _unitscount <= _currentThreshold);
    };
    
    // If threshold is met, wait 5 seconds before next check
    if (_thresholdMet) then {
        [
            _fnc_performNextCheck, 
            [_sector, _corrected_size, _start, _unitThresholds, _currentCheckIndex + 1],
            5
        ] call CBA_fnc_waitAndExecute;
    } else {
        // If threshold not met, continue to next check with minimal delay
        [
            _fnc_performNextCheck, 
            [_sector, _corrected_size, _start, _unitThresholds, _currentCheckIndex + 1],
            0.1
        ] call CBA_fnc_waitAndExecute;
    };
};

// Start checking sequence
[_fnc_performNextCheck, [_sector, _corrected_size, _start, _unitThresholds, 0], 0.1] call CBA_fnc_waitAndExecute;
