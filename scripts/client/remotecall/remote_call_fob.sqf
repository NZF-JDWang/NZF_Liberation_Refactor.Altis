if ( isDedicated ) exitWith {};

if ( isNil "sector_timer" ) then { sector_timer = 0 };

params [ "_fob", "_status" ];
private [ "_fobname" ];

// Ensure GRLIB_all_fobs is properly updated on client
if (!isNil "GRLIB_all_fobs") then {
    if (_status == 0 && !(_fob in GRLIB_all_fobs)) then {
        // Add new FOB to array if not already present
        GRLIB_all_fobs pushBack _fob;
        diag_log format ["Remote Call FOB: Added FOB at position %1", _fob];
        
        // Force sector marker refresh when a FOB is placed
        // When the first FOB is placed, request capturable sectors from server
        if (count GRLIB_all_fobs == 1) then {
            // Wait a moment for server to update NZF_capturable_sectors
            sleep 1;
            
            // Force markers to update
            {
                if (!(_x in blufor_sectors) && {[_x] call KPLIB_fnc_validateSectorCapture}) then {
                    _x setMarkerColorLocal GRLIB_color_enemy;
                    _x setMarkerAlphaLocal 1;
                    diag_log format ["[Client] Setting marker as capturable: %1", _x];
                }
            } forEach sectors_allSectors;
        };
    };
    
    if (_status == 2 && (_fob in GRLIB_all_fobs)) then {
        // Remove lost FOB from array
        GRLIB_all_fobs = GRLIB_all_fobs - [_fob];
        diag_log format ["Remote Call FOB: Removed FOB at position %1", _fob];
    };
} else {
    // Initialize if nil
    if (_status == 0) then {
        GRLIB_all_fobs = [_fob];
        diag_log "Remote Call FOB: Initialized GRLIB_all_fobs with new FOB";
    } else {
        GRLIB_all_fobs = [];
        diag_log "Remote Call FOB: Initialized GRLIB_all_fobs as empty";
    };
};

_fobname = [_fob] call KPLIB_fnc_getFobName;

if ( _status == 0 ) then {
    [ "lib_fob_built", [ _fobname ] ] call BIS_fnc_showNotification;
};

if ( _status == 1 ) then {
    [ "lib_fob_attacked", [ _fobname ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal _fob;
    sector_timer = GRLIB_vulnerability_timer;
};

if ( _status == 2 ) then {
    [ "lib_fob_lost", [ _fobname ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal markers_reset;
    sector_timer = 0;
};

if ( _status == 3 ) then {
    [ "lib_fob_safe", [ _fobname ] ] call BIS_fnc_showNotification;
    "opfor_capture_marker" setMarkerPosLocal markers_reset;
    sector_timer = 0;
};

