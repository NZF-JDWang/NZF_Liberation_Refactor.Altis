/*
    Function: NZF_fnc_updateSectorMarkers
    
    Description:
        Updates sector markers based on whether they are capturable or not
    
    Parameters:
        _capturable_sectors - Array of sector markers that can be captured
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2023-04-25
*/

params [["_capturable_sectors", []]];

// Get all sectors that are not blufor and not capturable
private _non_capturable = (sectors_allSectors - blufor_sectors) - _capturable_sectors;

// Check if first FOB has been placed
private _fob_placed = false;
if (!isNil "NZF_first_fob_placed") then {
    _fob_placed = NZF_first_fob_placed;
};

// If no FOB has been placed, all non-blufor sectors should be grey
if (!_fob_placed && (count GRLIB_all_fobs == 0)) then {
    _non_capturable = sectors_allSectors - blufor_sectors;
    _capturable_sectors = [];
};

// Debug message
diag_log format ["[NZF Frontline] Updating markers - Capturable: %1, Non-capturable: %2", count _capturable_sectors, count _non_capturable];

// Store original colors for all markers if not already done
{
    private _markerColor = markerColor _x;
    private _origColorVar = format ["NZF_origColor_%1", _x];
    
    if (isNil {missionNamespace getVariable _origColorVar}) then {
        missionNamespace setVariable [_origColorVar, _markerColor];
        publicVariable _origColorVar;
    };
} forEach sectors_allSectors;

// First, reset marker colors based on ownership
{
    if (_x in blufor_sectors) then {
        _x setMarkerColor GRLIB_color_friendly;
        _x setMarkerAlpha 1;
    } else {
        // Default for enemy sectors
        _x setMarkerColor GRLIB_color_enemy;
        _x setMarkerAlpha 1;
    };
} forEach sectors_allSectors;

// Then, mark capturable sectors with full brightness enemy color
{
    if !(_x in blufor_sectors) then {
        _x setMarkerColor GRLIB_color_enemy;
        _x setMarkerAlpha 1;
        
        // Add a debug log for each capturable sector
        diag_log format ["[NZF Frontline] Marking sector as capturable: %1", _x];
    };
} forEach _capturable_sectors;

// Finally, mark non-capturable sectors with grey and low alpha
{
    if !(_x in blufor_sectors) then {
        // Set to grey with low alpha - use waitAndExecute to ensure it runs after other color settings
        private _marker = _x;
        [
            {
                params ["_marker"];
                _marker setMarkerColor "ColorGrey";
                _marker setMarkerAlpha 0.4;
            },
            [_marker],
            0.5  // Half second delay to ensure it runs after other marker settings
        ] call CBA_fnc_waitAndExecute;
    };
} forEach _non_capturable; 