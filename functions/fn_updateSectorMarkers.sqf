/*
    Function: KPLIB_fnc_updateSectorMarkers
    
    Description:
        Updates all sector markers based on current game state.
        Runs in unscheduled space for consistent display.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

// Reset all markers to default state
{
    if (_x in blufor_sectors) then {
        _x setMarkerColor GRLIB_color_friendly;
        _x setMarkerAlpha 1;
    } else {
        _x setMarkerColor "ColorGrey";
        _x setMarkerAlpha 0.4;
    };
} forEach sectors_allSectors;

// Find capturable sectors based on proximity to friendly positions
private _capturable_sectors = [];
{
    if (!(_x in blufor_sectors) && {[_x] call KPLIB_fnc_validateSectorCapture}) then {
        _capturable_sectors pushBack _x;
        _x setMarkerColor GRLIB_color_enemy;
        _x setMarkerAlpha 1;
    };
} forEach sectors_allSectors;

diag_log format ["[Server] Updated sector markers - %1 capturable sectors", count _capturable_sectors]; 