if (!isServer) exitWith {};

params [ "_new_fob", "_create_fob_building" ];
private [ "_fob_building", "_fob_pos" ];

// Validate FOB placement with the new function
if !([_new_fob] call KPLIB_fnc_validateFOBPlacement) exitWith {
    // Validation function handles the error messaging
    
    // Reset FOB build flag
    FOB_build_in_progress = false;
    publicVariable "FOB_build_in_progress";
};

// Add to FOB list
GRLIB_all_fobs pushback _new_fob;
publicVariable "GRLIB_all_fobs";
diag_log format ["[KPLIB] FOB built at position %1, total FOBs: %2", _new_fob, count GRLIB_all_fobs];

if ( _create_fob_building ) then {
    _fob_pos = [ (_new_fob select 0) + 15, (_new_fob select 1) + 2, 0 ];
    [_fob_pos, 20, true] call KPLIB_fnc_createClearance;
    _fob_building = FOB_typename createVehicle [0, 0, 0]; // Create at origin first
    _fob_building setpos _fob_pos;
    _fob_building setVectorUp [0,0,1];
    [_fob_building] call KPLIB_fnc_addObjectInit;
};

// Update all sector markers using the centralized function
[] call KPLIB_fnc_updateSectorMarkers;

// Schedule save and notification operations
[{
    params ["_new_fob"];
    
    // Save the game state
    [] spawn KPLIB_fnc_doSave;
    
    // Notify clients about the new FOB
    [_new_fob, 0] remoteExec ["remote_call_fob"];
    
    // Update stats
    stats_fobs_built = stats_fobs_built + 1;
    
    // Reset FOB build flag
    FOB_build_in_progress = false;
    publicVariable "FOB_build_in_progress";
    
    diag_log "[KPLIB] FOB build completed and markers updated";
    
}, [_new_fob], 0.5] call CBA_fnc_waitAndExecute;
