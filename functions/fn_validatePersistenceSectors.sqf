/*
    Function: KPLIB_fnc_validatePersistenceSectors
    
    Description:
        Validates that KPLIB_persistent_sectors is a properly initialized HashMap
        If not, it recreates it and logs a warning
    
    Parameters:
        _caller - String identifying the calling function for logging (optional)
    
    Returns:
        Boolean - True if HashMap was already valid, False if it needed to be recreated
    
    Author: [NZF] JD Wang
    Date: 2024-11-05
*/

params [["_caller", "unknown", [""]]];

private _isValid = (!isNil "KPLIB_persistent_sectors") && {KPLIB_persistent_sectors isEqualType createHashMap};

if (!_isValid) then {
    // If it's not nil but also not a HashMap, log what it is
    private _typeInfo = if (isNil "KPLIB_persistent_sectors") then {
        "nil"
    } else {
        typeName KPLIB_persistent_sectors
    };
    
    diag_log format ["[KPLIB] ERROR: KPLIB_persistent_sectors validation failed in %1! Current type: %2 - Recreating HashMap", _caller, _typeInfo];
    
    // Create a new HashMap
    KPLIB_persistent_sectors = createHashMap;
    publicVariable "KPLIB_persistent_sectors";
    
    // Mark saved units as invalid since we lost the data
    {
        private _sectorSavedVar = format ["KPLIB_sector_%1_saved", _x];
        if (missionNamespace getVariable [_sectorSavedVar, false]) then {
            diag_log format ["[KPLIB] Clearing persistence flag for sector %1 due to HashMap recreation", _x];
            missionNamespace setVariable [_sectorSavedVar, false, true];
        };
    } forEach sectors_allSectors;
};

_isValid 