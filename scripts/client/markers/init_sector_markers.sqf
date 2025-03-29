/*
    Script: init_sector_markers.sqf
    
    Description:
        Ensures all sector markers are properly initialized for clients
        This prevents server/client marker color mismatches
    
    Author: [NZF] JD Wang
    Date: 2024-11-08
*/

// Wait for core variables with safety timeout
private _timeout = time + 15;
waitUntil {
    sleep 0.5;
    if (time > _timeout) exitWith {
        diag_log "[Client] Timed out waiting for sector variables";
        true
    };
    !isNil "sectors_allSectors" && !isNil "blufor_sectors"
};

// Ensure we have valid data
if (isNil "sectors_allSectors") then { sectors_allSectors = []; };
if (isNil "blufor_sectors") then { blufor_sectors = []; };

diag_log format ["[Client] Initializing markers: %1 sectors, %2 blufor", count sectors_allSectors, count blufor_sectors];

// No need to calculate capturable sectors locally anymore
// The server handles all marker updates globally
// This is just a fallback initialization

// Force refresh local marker colors for all sectors just in case
[] call kplib_fnc_refreshClientMarkers;

diag_log "[Client] Initial sector markers synchronized with server"; 