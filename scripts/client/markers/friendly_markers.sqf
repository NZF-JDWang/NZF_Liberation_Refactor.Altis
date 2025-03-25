/*
    Function: friendly_markers.sqf
    
    Description:
        Sets colors for friendly markers (Operations Base and SPARTAN 6)
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-08-05
*/

// Set Operations Base marker color
if (markerShape "startbase_marker" != "") then {
    "startbase_marker" setMarkerColorLocal GRLIB_color_friendly;
};

// Set SPARTAN 6 marker
"huronmarker" setMarkerTextLocal "SPARTAN 6";
"huronmarker" setMarkerColorLocal GRLIB_color_friendly;

// Continue updating SPARTAN 6 position
if (KP_liberation_mapmarkers) then {
    private ["_huronlocal"];
    
    while { true } do {
        _huronlocal = [] call KPLIB_fnc_potatoScan;
        if (!isNull _huronlocal) then {
            "huronmarker" setmarkerposlocal (getpos _huronlocal);
        } else {
            "huronmarker" setmarkerposlocal markers_reset;
        };
        sleep 4.9;
    };
}; 