waitUntil {!isNil "save_is_loaded"};
waitUntil {!isNil "GRLIB_all_fobs"};
waitUntil {save_is_loaded};

// Additional safety delay to ensure FOB data is fully loaded
sleep 5;

private _markers = [];
private _markers_mobilespawns = [];

// Ensure FOBs are initialized
if (isNil "GRLIB_all_fobs") then {
    GRLIB_all_fobs = [];
    publicVariable "GRLIB_all_fobs";
};

// Debug message at startup
diag_log format ["FOB Markers Script: GRLIB_all_fobs initialized with %1 FOBs", count GRLIB_all_fobs];

// Force initial marker creation
{deleteMarkerLocal _x;} forEach _markers;
_markers = [];

// Force marker creation on script start
[] spawn {
    sleep 2;
    GRLIB_all_fobs = GRLIB_all_fobs;
    publicVariable "GRLIB_all_fobs";
};

while {true} do {
    // Check the FOB array
    if (isNil "GRLIB_all_fobs") then {
        GRLIB_all_fobs = [];
        publicVariable "GRLIB_all_fobs";
        diag_log "FOB Markers Script: GRLIB_all_fobs was nil, reinitializing";
    };
    
    // Update FOB markers
    if (count _markers != count GRLIB_all_fobs) then {
        diag_log format ["FOB Markers Script: Marker count mismatch. Markers: %1, FOBs: %2", count _markers, count GRLIB_all_fobs];
        {deleteMarkerLocal _x;} forEach _markers;
        _markers = [];

        for "_idx" from 0 to ((count GRLIB_all_fobs) - 1) do {
            private _fobPos = GRLIB_all_fobs select _idx;
            
            // Extra validation for FOB position
            if (!isNil "_fobPos" && {_fobPos isEqualType [] && {count _fobPos >= 2}}) then {
                // Ensure position has valid coordinates
                if ((_fobPos select 0) != 0 || (_fobPos select 1) != 0) then {
                    private _marker = createMarkerLocal [format ["fobmarker%1", _idx], _fobPos];
                    _marker setMarkerTypeLocal "b_hq";
                    _marker setMarkerSizeLocal [1.5, 1.5];
                    _marker setMarkerPosLocal _fobPos;
                    _marker setMarkerTextLocal format ["FOB %1", military_alphabet select (_idx min (count military_alphabet - 1))];
                    _marker setMarkerColorLocal "ColorYellow";
                    _markers pushBack _marker;
                    
                    diag_log format ["FOB Markers Script: Created marker for FOB at position %1", _fobPos];
                } else {
                    diag_log format ["FOB Markers Script: Skipping FOB with zero position at index %1", _idx];
                }
            } else {
                diag_log format ["FOB Markers Script: Invalid FOB position at index %1: %2", _idx, _fobPos];
            };
        };
    } else {
        // Update existing marker positions in case they've moved
        for "_idx" from 0 to ((count GRLIB_all_fobs) - 1) do {
            if (_idx < count _markers && _idx < count GRLIB_all_fobs) then {
                (_markers select _idx) setMarkerPosLocal (GRLIB_all_fobs select _idx);
            };
        };
    };

    if (KP_liberation_mobilerespawn) then {
        private _respawn_trucks = [] call KPLIB_fnc_getMobileRespawns;

        if (count _markers_mobilespawns != count _respawn_trucks) then {
            {deleteMarkerLocal _x;} forEach _markers_mobilespawns;
            _markers_mobilespawns = [];

            for "_idx" from 0 to ((count _respawn_trucks) - 1) do {
                _marker = createMarkerLocal [format ["mobilespawn%1", _idx], markers_reset];
                _marker setMarkerTypeLocal "mil_end";
                _marker setMarkerColorLocal "ColorYellow";
                _markers_mobilespawns pushback _marker;
            };
        };

        if (count _respawn_trucks == count _markers_mobilespawns) then {
            for "_idx" from 0 to ((count _markers_mobilespawns) - 1) do {
                (_markers_mobilespawns select _idx) setMarkerPosLocal getPos (_respawn_trucks select _idx);
                (_markers_mobilespawns select _idx) setMarkerTextLocal format ["%1 %2", localize "STR_RESPAWN_TRUCK", mapGridPosition (_respawn_trucks select _idx)];
            };
        };
    };

    sleep 5;
};
