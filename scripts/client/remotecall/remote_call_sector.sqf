if ( isDedicated ) exitWith {};

if ( isNil "sector_timer" ) then { sector_timer = 0 };

params [ "_sector", "_status" ];

if ( _status == 0 ) then {
    [ "lib_sector_captured", [ markerText _sector ] ] call BIS_fnc_showNotification;
};

if ( _status == 1 ) then {
    [ "lib_sector_attacked", [ markerText _sector ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal ( markerpos _sector );
    sector_timer = GRLIB_vulnerability_timer;
};

if ( _status == 2 ) then {
    [ "lib_sector_lost", [ markerText _sector ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal markers_reset;
    sector_timer = 0;
};

if ( _status == 3 ) then {
    [ "lib_sector_safe", [ markerText _sector ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal markers_reset;
    sector_timer = 0;
};

// For markers that already have a designated status, update them directly
{ _x setMarkerColorLocal GRLIB_color_enemy; } foreach (sectors_allSectors - blufor_sectors);
{ _x setMarkerColorLocal GRLIB_color_friendly; } foreach blufor_sectors;

// For capturable sectors, make sure they're not grey
if (!isNil "NZF_capturable_sectors") then {
    {
        if (!(_x in blufor_sectors)) then {
            _x setMarkerColorLocal GRLIB_color_enemy;
            _x setMarkerAlphaLocal 1;
        };
    } forEach NZF_capturable_sectors;
};

// For invalid sectors, they should be grey and transparent
if (!isNil "NZF_invalid_capture_sectors") then {
    {
        if (!(_x in blufor_sectors) && !(_x in NZF_capturable_sectors)) then {
            _x setMarkerColorLocal "ColorGrey";
            _x setMarkerAlphaLocal 0.4;
        };
    } forEach NZF_invalid_capture_sectors;
};
