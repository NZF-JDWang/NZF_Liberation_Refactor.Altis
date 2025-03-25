if (!isServer) exitWith {};

params [ "_new_fob", "_create_fob_building" ];
private [ "_fob_building", "_fob_pos" ];

// Validate FOB placement
if !([_new_fob] call NZF_fnc_validateFOBPlacement) exitWith {
    // No need to send notification here anymore, it's handled in the validation function
    
    // Reset FOB build flag
    FOB_build_in_progress = false;
    publicVariable "FOB_build_in_progress";
};

// Add to FOB list
GRLIB_all_fobs pushback _new_fob;
publicVariable "GRLIB_all_fobs";
diag_log format ["[NZF Frontline] FOB built at position %1, total FOBs: %2", _new_fob, count GRLIB_all_fobs];

// Set the first FOB placed flag if not already set
if (!NZF_first_fob_placed) then {
    NZF_first_fob_placed = true;
    publicVariable "NZF_first_fob_placed";
    diag_log "[NZF Frontline] First FOB has been placed";
    
    // Update capturable sectors now that a FOB has been placed
    private _capturable = [] call NZF_fnc_updateCapturableSectors;
    diag_log format ["[NZF Frontline] After first FOB placement, capturable sectors: %1", _capturable];
    
    // Force a direct update of the markers to make sure they're visible
    [_capturable] call NZF_fnc_updateSectorMarkers;
};

if ( _create_fob_building ) then {
    _fob_pos = [ (_new_fob select 0) + 15, (_new_fob select 1) + 2, 0 ];
    [_fob_pos, 20, true] call KPLIB_fnc_createClearance;
    _fob_building = FOB_typename createVehicle _fob_pos;
    _fob_building setpos _fob_pos;
    _fob_building setVectorUp [0,0,1];
    [_fob_building] call KPLIB_fnc_addObjectInit;
    sleep 1;
};

[] spawn KPLIB_fnc_doSave;

// Small delay to allow marker updates to complete
sleep 1;

// Notify clients about the new FOB
[_new_fob, 0] remoteExec ["remote_call_fob"];

stats_fobs_built = stats_fobs_built + 1;

FOB_build_in_progress = false;
publicVariable "FOB_build_in_progress";
