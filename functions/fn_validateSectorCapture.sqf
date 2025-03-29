/*
    Function: KPLIB_fnc_validateSectorCapture
    
    Description:
        Validates if a sector can be captured based on proximity to friendly sectors/FOBs
        Makes sectors that are closest to any friendly position capturable
    
    Parameters:
        _sector - Sector marker name to validate for capture
    
    Returns:
        Boolean - True if sector can be captured, false otherwise
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

params ["_sector"];

// Exit if sector is already owned by blufor
if (_sector in blufor_sectors) exitWith {
    diag_log format ["[KPLIB] Sector %1 already captured by blufor", _sector];
    false
};

// Get the position of the sector
private _sectorPos = markerPos _sector;

// Private variables for sector determination
private _isValidSector = false;
private _nearestSectors = [];

// For each friendly position (sectors and FOBs), find the nearest enemy sector
// First gather all friendly positions
private _friendlyPositions = [];

// Add all captured sectors
{
    _friendlyPositions pushBack [_x, markerPos _x];
} forEach blufor_sectors;

// Add all FOBs
{
    _friendlyPositions pushBack ["FOB_" + str _forEachIndex, _x];
} forEach GRLIB_all_fobs;

// If no friendly positions, allow capture of any sector
if (count _friendlyPositions == 0) exitWith {
    diag_log "[KPLIB] No friendly positions found, any sector should be capturable";
    true
};

// For each friendly position, find the nearest enemy sector
{
    _x params ["_friendlyName", "_friendlyPos"];
    private _nearestEnemy = "";
    private _minDistance = 999999;
    
    // Find the nearest enemy sector to this friendly position
    {
        // Skip if already blufor sector
        if (!(_x in blufor_sectors)) then {
            private _enemyPos = markerPos _x;
            private _distance = _friendlyPos distance2D _enemyPos;
            
            if (_distance < _minDistance) then {
                _minDistance = _distance;
                _nearestEnemy = _x;
            };
        };
    } forEach sectors_allSectors;
    
    // Add to list of nearest sectors if not already in the list
    if (_nearestEnemy != "" && !(_nearestEnemy in _nearestSectors)) then {
        _nearestSectors pushBack _nearestEnemy;
    };
} forEach _friendlyPositions;

// The sector is valid if it's one of the nearest sectors to a friendly position
_isValidSector = _sector in _nearestSectors;

// Log the result
diag_log format ["[KPLIB] Sector %1 capture validation: %2", _sector, ["Invalid", "Valid - nearest to friendly position"] select _isValidSector];

// Return validation result
_isValidSector 