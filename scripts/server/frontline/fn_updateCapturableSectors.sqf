/*
    Function: NZF_fnc_updateCapturableSectors
    
    Description:
        Updates the list of sectors that can be captured based on proximity to friendly sectors and FOBs
    
    Parameters:
        None
    
    Returns:
        Array of capturable sector objects
    
    Author: [NZF] JD Wang
    Date: 2023-04-25
*/

// Initialize or clear the capturable sectors array
if (isNil "NZF_capturable_sectors") then {
    NZF_capturable_sectors = [];
} else {
    NZF_capturable_sectors = [];
};

// Initialize invalid capture sectors array if it doesn't exist yet
if (isNil "NZF_invalid_capture_sectors") then {
    // Start with all opfor sectors as invalid
    NZF_invalid_capture_sectors = sectors_allSectors - blufor_sectors;
    publicVariable "NZF_invalid_capture_sectors";
};

// Initialize first FOB placed flag if it doesn't exist
if (isNil "NZF_first_fob_placed") then {
    NZF_first_fob_placed = false;
    publicVariable "NZF_first_fob_placed";
};

private _capturable_sectors = [];

// Skip if no FOBs placed yet
if (!NZF_first_fob_placed) exitWith {
    // When no FOBs placed, no sectors should be capturable
    _capturable_sectors = [];
    
    NZF_capturable_sectors = _capturable_sectors;
    publicVariable "NZF_capturable_sectors";
    
    // Make sure all sectors are invalid
    NZF_invalid_capture_sectors = sectors_allSectors - blufor_sectors;
    publicVariable "NZF_invalid_capture_sectors";
    
    // Update markers
    [_capturable_sectors] call NZF_fnc_updateSectorMarkers;
    
    _capturable_sectors
};

// Create an array of friendly positions (both captured sectors and FOBs)
private _friendly_positions = [];

// Add all captured sectors
{
    // Only add if it's actually a blufor sector (this prevents any data issues)
    if (_x in sectors_allSectors) then {
        _friendly_positions pushBack [_x, markerPos _x];
    };
} forEach blufor_sectors;

// Add all FOBs - treat them as friendly positions too
{
    _friendly_positions pushBack ["FOB_" + str _forEachIndex, _x];
} forEach GRLIB_all_fobs;

// For each friendly position (sectors and FOBs), find the nearest enemy sector
{
    _x params ["_friendly_name", "_friendly_pos"];
    private _nearest_enemy = "";
    private _min_distance = 999999;
    
    // Find the nearest enemy sector to this friendly position
    {
        // Skip if already blufor sector
        if (!(_x in blufor_sectors)) then {
            private _enemy_pos = markerPos _x;
            private _distance = _friendly_pos distance2D _enemy_pos;
            
            if (_distance < _min_distance) then {
                _min_distance = _distance;
                _nearest_enemy = _x;
            };
        };
    } forEach sectors_allSectors;
    
    // Add to capturable sectors if not already in the list and within max distance (2000m)
    if (_nearest_enemy != "" && !(_nearest_enemy in _capturable_sectors) && _min_distance <= 2000) then {
        // Critical check - make sure it's not already in blufor_sectors
        if !(_nearest_enemy in blufor_sectors) then {
            _capturable_sectors pushBack _nearest_enemy;
            
            // Remove from invalid list
            NZF_invalid_capture_sectors = NZF_invalid_capture_sectors - [_nearest_enemy];
        };
    };
} forEach _friendly_positions;

// Store the result and make it public
NZF_capturable_sectors = _capturable_sectors;
publicVariable "NZF_capturable_sectors";
publicVariable "NZF_invalid_capture_sectors";

// Debug message
diag_log format ["[NZF Frontline] Updated capturable sectors: %1", _capturable_sectors];
diag_log format ["[NZF Frontline] Current blufor sectors: %1", blufor_sectors];

// Update markers
[_capturable_sectors] call NZF_fnc_updateSectorMarkers;

// Return the array of capturable sectors
_capturable_sectors 