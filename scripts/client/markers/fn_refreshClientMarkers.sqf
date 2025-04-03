/*
    Function: refreshClientMarkers
    
    Description:
        Simple client-side marker refresh. With markers updated globally by the server,
        this is mostly just for catching up if client markers get desynced.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

// Client-side only
if (!hasInterface) exitWith {};

// Check if necessary variables exist
if (isNil "sectors_allSectors" || isNil "blufor_sectors") exitWith {
    diag_log "[Client] Missing sector variables, can't refresh markers";
};

diag_log "[Client] Refreshing sector markers from server data";

// Force refresh local marker colors for all sectors - COMMENTED OUT
/*
// First set all to grey with low alpha
{
    _x setMarkerColorLocal "ColorGrey";
    _x setMarkerAlphaLocal 0.4;
} forEach sectors_allSectors;

// Then set only blufor sectors to friendly color
{
    _x setMarkerColorLocal GRLIB_color_friendly;
    _x setMarkerAlphaLocal 1;
} forEach blufor_sectors;
*/

diag_log "[Client] Local sector markers refreshed (Relying on server global updates)"; 
