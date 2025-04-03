/*
    Function: KPLIB_fnc_synchroniseVars
    
    Description:
        Initializes the periodic check for various global game state variables and synchronizes them
        across the network using publicVariable when changes are detected.
        This function runs on the server only and should be called once during init.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-07-27
*/

// No function assignment wrapper needed when using CfgFunctions with file/class structure

// Initialize global variable for synchronization if needed
if (isNil "sync_vars") then {
    sync_vars = []; 
    publicVariable "sync_vars";
};

// Wait until all necessary variables are initialized and save is loaded
[
    { // Condition Code
        !(isNil "save_is_loaded") &&
        !(isNil "KP_liberation_fob_resources") &&
        !(isNil "KP_liberation_supplies_global") &&
        !(isNil "KP_liberation_ammo_global") &&
        !(isNil "KP_liberation_fuel_global") &&
        !(isNil "combat_readiness") &&
        !(isNil "unitcap") &&
        !(isNil "KP_liberation_heli_count") &&
        !(isNil "KP_liberation_plane_count") &&
        !(isNil "KP_liberation_heli_slots") &&
        !(isNil "KP_liberation_plane_slots") &&
        !(isNil "resources_intel") &&
        !(isNil "infantry_cap") &&
        !(isNil "KP_liberation_civ_rep") &&
        !(isNil "KP_liberation_guerilla_strength") &&
        !(isNil "infantry_weight") &&
        !(isNil "armor_weight") &&
        !(isNil "air_weight") &&
        !(isNil "GRLIB_all_fobs") &&
        save_is_loaded
    },
    { // Code to execute once condition is met
        // Define _old variables here. They are private to this scope but accessible by the PFEH below.
        private _KP_liberation_fob_resources_old = +KP_liberation_fob_resources;
        private _KP_liberation_supplies_global_old = KP_liberation_supplies_global;
        private _KP_liberation_ammo_global_old = KP_liberation_ammo_global;
        private _KP_liberation_fuel_global_old = KP_liberation_fuel_global;
        private _unitcap_old = unitcap;
        private _KP_liberation_heli_count_old = KP_liberation_heli_count;
        private _KP_liberation_plane_count_old = KP_liberation_plane_count;
        private _KP_liberation_heli_slots_old = KP_liberation_heli_slots;
        private _KP_liberation_plane_slots_old = KP_liberation_plane_slots;
        private _combat_readiness_old = combat_readiness;
        private _resources_intel_old = resources_intel;
        private _infantry_cap_old = infantry_cap;
        private _KP_liberation_civ_rep_old = KP_liberation_civ_rep;
        private _KP_liberation_guerilla_strength_old = KP_liberation_guerilla_strength;
        private _infantry_weight_old = infantry_weight;
        private _armor_weight_old = armor_weight;
        private _air_weight_old = air_weight;
        private _GRLIB_all_fobs_old = +GRLIB_all_fobs;

        // Add a per-frame handler to perform the checks periodically
        _null = [
            { // PFEH Code Block
                private _changed = false;
                
                // Check if any variable has changed against the persistent _old variables
                if (!(_KP_liberation_fob_resources_old isEqualTo KP_liberation_fob_resources)) then { _changed = true; };
                if (_KP_liberation_supplies_global_old != KP_liberation_supplies_global) then { _changed = true; };
                if (_KP_liberation_ammo_global_old != KP_liberation_ammo_global) then { _changed = true; };
                if (_KP_liberation_fuel_global_old != KP_liberation_fuel_global) then { _changed = true; };
                if (_unitcap_old != unitcap) then { _changed = true; };
                if (_KP_liberation_heli_count_old != KP_liberation_heli_count) then { _changed = true; };
                if (_KP_liberation_plane_count_old != KP_liberation_plane_count) then { _changed = true; };
                if (_KP_liberation_heli_slots_old != KP_liberation_heli_slots) then { _changed = true; };
                if (_KP_liberation_plane_slots_old != KP_liberation_plane_slots) then { _changed = true; };
                if (_combat_readiness_old != combat_readiness) then { _changed = true; };
                if (_resources_intel_old != resources_intel) then { _changed = true; };
                if (_infantry_cap_old != infantry_cap) then { _changed = true; };
                if (_KP_liberation_civ_rep_old != KP_liberation_civ_rep) then { _changed = true; };
                if (_KP_liberation_guerilla_strength_old != KP_liberation_guerilla_strength) then { _changed = true; };
                if (_infantry_weight_old != infantry_weight) then { _changed = true; };
                if (_armor_weight_old != armor_weight) then { _changed = true; };
                if (_air_weight_old != air_weight) then { _changed = true; };
                if (!(_GRLIB_all_fobs_old isEqualTo GRLIB_all_fobs)) then { _changed = true; };

                // If any variable changed, update and broadcast
                if (_changed) then {
                    // Ensure guerilla strength doesn't go below 0
                    if (KP_liberation_guerilla_strength < 0) then { KP_liberation_guerilla_strength = 0; };

                    // Update the synchronized variables array
                    sync_vars = [
                        KP_liberation_fob_resources,
                        KP_liberation_supplies_global,
                        KP_liberation_ammo_global,
                        KP_liberation_fuel_global,
                        unitcap,
                        KP_liberation_heli_count,
                        KP_liberation_plane_count,
                        KP_liberation_heli_slots,
                        KP_liberation_plane_slots,
                        combat_readiness,
                        resources_intel,
                        infantry_cap,
                        KP_liberation_civ_rep,
                        KP_liberation_guerilla_strength,
                        infantry_weight,
                        armor_weight,
                        air_weight,
                        GRLIB_all_fobs
                    ];
                    publicVariable "sync_vars";
                    // Ensure FOB positions are always synchronized separately as well
                    publicVariable "GRLIB_all_fobs"; 

                    // Update the persistent _old variables for the next check
                    _KP_liberation_fob_resources_old = +KP_liberation_fob_resources;
                    _KP_liberation_supplies_global_old = KP_liberation_supplies_global;
                    _KP_liberation_ammo_global_old = KP_liberation_ammo_global;
                    _KP_liberation_fuel_global_old = KP_liberation_fuel_global;
                    _unitcap_old = unitcap;
                    _KP_liberation_heli_count_old = KP_liberation_heli_count;
                    _KP_liberation_plane_count_old = KP_liberation_plane_count;
                    _KP_liberation_heli_slots_old = KP_liberation_heli_slots;
                    _KP_liberation_plane_slots_old = KP_liberation_plane_slots;
                    _combat_readiness_old = combat_readiness;
                    _resources_intel_old = resources_intel;
                    _infantry_cap_old = infantry_cap;
                    _KP_liberation_civ_rep_old = KP_liberation_civ_rep;
                    _KP_liberation_guerilla_strength_old = KP_liberation_guerilla_strength;
                    _infantry_weight_old = infantry_weight;
                    _armor_weight_old = armor_weight;
                    _air_weight_old = air_weight;
                    _GRLIB_all_fobs_old = +GRLIB_all_fobs;
                };
                
                // Return the delay until the next execution
                0.25 
            }
        ] call CBA_fnc_addPerFrameHandler;
    }
] call CBA_fnc_waitUntilAndExecute; 