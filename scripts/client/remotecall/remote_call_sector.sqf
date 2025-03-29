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

// First set all non-blufor sectors to grey with low alpha
{
    if (!(_x in blufor_sectors)) then {
        _x setMarkerColorLocal "ColorGrey";
        _x setMarkerAlphaLocal 0.4;
    };
} forEach sectors_allSectors;

// Then set blufor sectors to friendly color
{
    _x setMarkerColorLocal GRLIB_color_friendly;
    _x setMarkerAlphaLocal 1;
} forEach blufor_sectors;

// If validateSectorCapture function is available, mark capturable sectors
if (!isNil "KPLIB_fnc_validateSectorCapture") then {
    {
        if (!(_x in blufor_sectors) && {[_x] call KPLIB_fnc_validateSectorCapture}) then {
            _x setMarkerColorLocal GRLIB_color_enemy;
            _x setMarkerAlphaLocal 1;
        };
    } forEach sectors_allSectors;
};

if (_status == 0) then {
    
    if (isServer) then {
        // Handle local game too, in case both host and client execute this
        // Here the action happens on the server
        [_sector] call remote_call_sector_remote_call;
        
        // Skip the remote execution that would happen below
        _execute_script = false;
    };
    
    blufor_sectors pushback _sector; publicVariable "blufor_sectors";

    // Update markers
    _sector setMarkerColor GRLIB_color_friendly;
    _sector setMarkerAlpha 1;
    
    // Dynamically update markers for valid sectors
    {
        if (!(_x in blufor_sectors) && {[_x] call KPLIB_fnc_validateSectorCapture}) then {
            _x setMarkerColor GRLIB_color_enemy;
            _x setMarkerAlpha 1;
        } else {
            if (!(_x in blufor_sectors)) then {
                _x setMarkerColor "ColorGrey";
                _x setMarkerAlpha 0.4;
            };
        };
    } forEach sectors_allSectors;
    
    // Show resource icons on factory sectors
    if (_sector in sectors_factory) then {
        ["lib_factory_captured", [markerText _sector]] call BIS_fnc_showNotification;
        _sector_name = [_sector] call KPLIB_fnc_getLocationName;
        
        // Only display marker for player who captured sector
        if (_sector in KP_liberation_production_markers) then {
            private _marker = "";
            {
                if (_x select 0 == _sector) exitWith {_marker = _x select 1};
            } forEach KP_liberation_production_markers;
            
            if (_marker != "") then {
                _marker setMarkerTextLocal _sector_name;
                _marker setMarkerColorLocal GRLIB_color_friendly;
                _marker setMarkerAlphaLocal 1;
            };
        };
    };
};
