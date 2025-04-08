/*
    Function: manage_one_sector
    
    Description:
        Manages a sector's lifecycle including spawning defenders, handling sector capture, and cleanup
    
    Parameters:
        _sector - The sector marker name
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2024-10-15
*/

// base amount of sector lifetime tickets
// if there are no enemies one ticket is removed every SECTOR_TICK_TIME seconds
// 12 * 5 = 60s by default
#define BASE_TICKETS                12
#define SECTOR_TICK_TIME            5
// delay in minutes from which addional time will be added
#define ADDITIONAL_TICKETS_DELAY    5

params ["_sector"];

// Initialize global tracking for activated sectors if it doesn't exist
if (isNil "KPLIB_activated_sectors") then {
    KPLIB_activated_sectors = [];
};

// Initialize tracking for sectors in transition (loading/saving) to prevent race conditions
if (isNil "KPLIB_sectors_in_transition") then {
    KPLIB_sectors_in_transition = [];
};

// Initialize asymmetric warfare chance if not defined
if (isNil "GRLIB_asym_chance") then {
    GRLIB_asym_chance = 0.5; // Default 50% chance
    publicVariable "GRLIB_asym_chance";
};

// Log sector activation
[format ["Sector %1 (%2) activated - Managed on: %3", (markerText _sector), _sector, debug_source], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];

private _sectorpos = markerPos _sector;
private _stopit = false;
private _spawncivs = false;
private _building_ai_max = 0;
private _infsquad = "army";
private _building_range = 50;
private _local_capture_size = GRLIB_capture_size;
private _iedcount = 0;
private _vehtospawn = [];
private _managed_units = [];
private _squad1 = [];
private _squad2 = [];
private _squad3 = [];
private _squad4 = [];
private _minimum_building_positions = 5;
private _sector_despawn_tickets = BASE_TICKETS;
private _maximum_additional_tickets = (KP_liberation_delayDespawnMax * 60 / SECTOR_TICK_TIME);
private _popfactor = 1;
private _guerilla = false;
private _useMilitiaComps = true;

if (GRLIB_unitcap < 1) then {_popfactor = GRLIB_unitcap;};

if (_sector in active_sectors) exitWith {
    // Log exit reason
    [format["manage_one_sector.sqf WARNING: Sector %1 already in active_sectors. Exiting.", _sector], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
};
active_sectors pushback _sector; publicVariable "active_sectors";

private _opforcount = [] call KPLIB_fnc_getOpforCap;

// Use CBA_fnc_waitUntilAndExecute to wait for sector spawn
[_sector, _opforcount] call wait_to_spawn_sector;

// Main sector setup and unit spawn logic
private _fnc_setupSector = {
    params ["_sector", "_opforcount", "_sectorpos"];
    
    // Check for sector activation conditions
    if ((!(_sector in blufor_sectors)) && (([markerPos _sector, [_opforcount] call KPLIB_fnc_getSectorRange, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount) > 0)) then {
        private _fnc_configureSector = {
            params ["_sectorType", "_sector", "_sectorpos", "_opforcount"];
            private ["_spawncivs", "_building_ai_max", "_building_range", "_local_capture_size", 
                      "_iedcount", "_vehtospawn", "_managed_units", "_minimum_building_positions", "_sector_despawn_tickets", "_maximum_additional_tickets", 
                      "_popfactor", "_guerilla", "_infSquadCount", "_squadRoles"];
            
            // Initialize variables with default values
            _spawncivs = false;
            _building_ai_max = 0;
            _building_range = 50;
            _local_capture_size = GRLIB_capture_size;
            _iedcount = 0;
            _vehtospawn = [];
            _managed_units = [];
            _minimum_building_positions = 5;
            _sector_despawn_tickets = BASE_TICKETS;
            _maximum_additional_tickets = (KP_liberation_delayDespawnMax * 60 / SECTOR_TICK_TIME);
            _popfactor = 1;
            _guerilla = false;
            _infSquadCount = 0;
            _squadRoles = [];
            
            if (GRLIB_unitcap < 1) then {_popfactor = GRLIB_unitcap;};
            
            // Temp variable to track if militia compositions should be considered (based on old _infsquad logic)
            private _useMilitiaComps = true;
            
            // Different sector type configurations
            switch (_sectorType) do {
                case "bigtown": {
                    if (combat_readiness < 30) then {_useMilitiaComps = true;};
                    _infSquadCount = 2;
                    if (GRLIB_unitcap >= 1) then { _infSquadCount = _infSquadCount + 1; };
                    if (GRLIB_unitcap >= 1.5) then { _infSquadCount = _infSquadCount + 1; };
                    // Role Assignment
                    if (_infSquadCount >= 1) then { _squadRoles pushBack "GARRISON_CENTER"; };
                    if (_infSquadCount >= 2) then { _squadRoles pushBack "PATROL_INNER"; };
                    if (_infSquadCount >= 3) then { _squadRoles pushBack "PATROL_OUTER"; };
                    if (_infSquadCount >= 4) then { _squadRoles pushBack "CAMP_SECTOR"; };
                    
                    _vehtospawn = [(selectRandom militia_vehicles),(selectRandom militia_vehicles)];
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if ((random 100) > (50 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if (!_useMilitiaComps) then { // Replaces _infsquad == "army"
                        _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                        _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                        if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    };
                    _spawncivs = true;
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then { _guerilla = true; };
                    _building_ai_max = round (50 * _popfactor);
                    _building_range = 200;
                    _local_capture_size = _local_capture_size * 1.4;
                    if (KP_liberation_civ_rep < 0) then { _iedcount = round (2 + (ceil (random 4)) * (round ((KP_liberation_civ_rep * -1) / 33)) * GRLIB_difficulty_modifier); } else { _iedcount = 0; };
                    if (_iedcount > 16) then {_iedcount = 16};
                };
                case "capture": {
                    _spawncivs = true;
                    _infsquad = "garrison"; // Not directly used now, roles are
                    _minimum_building_positions = 5;
                    _building_range = GRLIB_capture_size;
                    _building_ai_max = round (6 * _popfactor); // Still used for old building garrison? Check usage
                    _iedcount = round (8 * GRLIB_difficulty_modifier * 0.5); // Using direct value instead of GRLIB_asym_chance

                    // Determine infantry squad count
                    _infSquadCount = 1;
                    if (GRLIB_unitcap >= 0.75) then { _infSquadCount = _infSquadCount + 1; };
                    if (GRLIB_unitcap >= 1.25) then { _infSquadCount = _infSquadCount + 1; };
                    if (random 100 < (30 * GRLIB_difficulty_modifier)) then {
                        _infSquadCount = _infSquadCount + 1;
                    };

                    // *** Ensure minimum of 3 squads for capture sectors ***
                    _infSquadCount = _infSquadCount max 3;

                    // Assign roles based on the count
                    _squadRoles = ["GARRISON_CENTER"];
                    if (_infSquadCount >= 2) then { _squadRoles pushBack "PATROL_INNER"; };
                    if (_infSquadCount >= 3) then { _squadRoles pushBack "CAMP_SECTOR"; }; // Maybe another patrol?
                    if (_infSquadCount >= 4) then { _squadRoles pushBack "GARRISON_OUTER"; }; // Add outer garrison if high count
                    
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if (!_useMilitiaComps) then { // Replaces _infsquad == "army"
                        _vehtospawn pushback (selectRandom militia_vehicles);
                        if ((random 100) > (33 / GRLIB_difficulty_modifier)) then { _vehtospawn pushBack ([] call KPLIB_fnc_getAdaptiveVehicle); };
                    };
                    _spawncivs = true;
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then { _guerilla = true; };
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 10 )))) * _popfactor);
                    _building_range = 120;
                };
                case "military": {
                    _useMilitiaComps = false; // Military always uses army
                    _infSquadCount = 2;
                    if (GRLIB_unitcap >= 1.5) then { _infSquadCount = _infSquadCount + 1; };
                    if ((random 100) > (33 / GRLIB_difficulty_modifier)) then { _infSquadCount = _infSquadCount + 1; };
                    // Role Assignment
                    if (_infSquadCount >= 1) then { _squadRoles pushBack "DEFEND_AREA"; };
                    if (_infSquadCount >= 2) then { _squadRoles pushBack "CAMP_SECTOR"; };
                    if (_infSquadCount >= 3) then { _squadRoles pushBack "PATROL_OUTER"; };
                    if (_infSquadCount >= 4) then { _squadRoles pushBack "DEFEND_AREA"; };
                    
                    _vehtospawn = [([] call KPLIB_fnc_getAdaptiveVehicle),([] call KPLIB_fnc_getAdaptiveVehicle)];
                    if ((random 100) > (33 / GRLIB_difficulty_modifier)) then { _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle); };
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    _spawncivs = false;
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 4 )))) * _popfactor);
                    _building_range = 120;
                };
                case "factory": {
                    if (combat_readiness < 40) then {_useMilitiaComps = true;};
                    _infSquadCount = 1;
                    if (GRLIB_unitcap >= 1.25) then { _infSquadCount = _infSquadCount + 1; };
                    // Role Assignment
                    if (_infSquadCount >= 1) then { _squadRoles pushBack "DEFEND_AREA"; };
                    if (_infSquadCount >= 2) then { _squadRoles pushBack "PATROL_INNER"; };

                    if ((random 100) > 66) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    if ((random 100) > 33) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    _spawncivs = false;
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then { _guerilla = true; };
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 10 )))) * _popfactor);
                    _building_range = 120;
                    if (KP_liberation_civ_rep < 0) then { _iedcount = round ((ceil (random 3)) * (round ((KP_liberation_civ_rep * -1) / 33)) * GRLIB_difficulty_modifier); } else { _iedcount = 0; };
                    if (_iedcount > 8) then {_iedcount = 8};
                };
                case "tower": {
                    _useMilitiaComps = false; // Towers always use army?
                    _infSquadCount = 1;
                    if (combat_readiness > 30) then { _infSquadCount = _infSquadCount + 1; };
                    if (GRLIB_unitcap >= 1.5) then { _infSquadCount = _infSquadCount + 1; };
                    // Role Assignment
                    if (_infSquadCount >= 1) then { _squadRoles pushBack "GARRISON_CENTER"; };
                    if (_infSquadCount >= 2) then { _squadRoles pushBack "DEFEND_AREA"; };
                    if (_infSquadCount >= 3) then { _squadRoles pushBack "PATROL_OUTER"; };
                    
                    if((random 100) > 95) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    _spawncivs = false;
                    _building_ai_max = 0;
                };
                default {
                    // Default case - assign 1 default patrol
                    _infSquadCount = 1;
                    _squadRoles = ["PATROL_DEFAULT"];
                    _building_ai_max = round (20 * _popfactor);
                    _building_range = 100;
                    _local_capture_size = GRLIB_capture_size;
                };
            };
            
            // Ensure roles list matches the final count
            if (count _squadRoles > _infSquadCount) then {
                 _squadRoles = _squadRoles select [0, _infSquadCount];
            };
            while {count _squadRoles < _infSquadCount} do {
                _squadRoles pushBack "PATROL_DEFAULT"; // Add default patrols if count exceeds defined roles
            };
            
            _vehtospawn = _vehtospawn select {!(isNil "_x")};
            
            if (KP_liberation_sectorspawn_debug > 0) then {
                [format ["Sector %1 (%2) - manage_one_sector calculated -> Squad Roles: %3 (Count: %4) - Vehicles: %5 - Building AI: %6", 
                (markerText _sector), _sector, _squadRoles, _infSquadCount, (count _vehtospawn), _building_ai_max], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
            };
            
            if (_building_ai_max > 0 && GRLIB_adaptive_opfor) then {
                _building_ai_max = round (_building_ai_max * ([] call KPLIB_fnc_getOpforFactor));
            };
            
            // Return all the sector configuration variables as an array
            [_spawncivs, _building_ai_max, _building_range, _local_capture_size, _iedcount, 
             _vehtospawn, _minimum_building_positions, _sector_despawn_tickets, _maximum_additional_tickets, _popfactor, _guerilla, 
             _infSquadCount, _squadRoles]
        };
        
        // Determine Sector Type
        private _sectorType = "unknown";
        if (_sector in sectors_bigtown) then { _sectorType = "bigtown"; }
        else { if (_sector in sectors_capture) then { _sectorType = "capture"; }
        else { if (_sector in sectors_military) then { _sectorType = "military"; }
        else { if (_sector in sectors_factory) then { _sectorType = "factory"; }
        else { if (_sector in sectors_tower) then { _sectorType = "tower"; }; }; }; }; };
        
        // Configure sector based on its type
        private _sectorConfig = [_sectorType, _sector, _sectorpos, _opforcount] call _fnc_configureSector;
        _sectorConfig params ["_spawncivs", "_building_ai_max", "_building_range", "_local_capture_size", 
                            "_iedcount", "_vehtospawn", "_minimum_building_positions", "_sector_despawn_tickets", "_maximum_additional_tickets", 
                            "_popfactor", "_guerilla", "_infSquadCount", "_squadRoles"];
        
        // Initialize managed_units here
        private _managed_units = [];
        
        // Check for persistent units first - moved variable declaration outside
        private _hasPersistentUnits = false;
        
        // Pre-define the sector saved variable
        private _sectorSavedVar = format ["KPLIB_sector_%1_saved", _sector];
        private _sectorHasSavedData = missionNamespace getVariable [_sectorSavedVar, false];
        
        // DEBUGGING: Always check the state of variables related to persistence
        diag_log format ["[KPLIB] Sector %1 persistence state - Has saved flag: %2, KPLIB_persistent_sectors exists: %3", 
            _sector, 
            _sectorHasSavedData, 
            (!isNil "KPLIB_persistent_sectors")
        ];
        
        // Check if there's actual saved data in the persistence map
        private _hasDataInMap = false;
        if (!isNil "KPLIB_persistent_sectors") then {
            if (KPLIB_persistent_sectors isEqualType createHashMap) then {
                _hasDataInMap = _sector in keys KPLIB_persistent_sectors;
                if (_hasDataInMap) then {
                    diag_log format ["[KPLIB] Sector %1 - Found in persistence map with data", _sector];
                };
            } else {
                diag_log format ["[KPLIB] ERROR: KPLIB_persistent_sectors is not a HashMap but a %1 - Creating new HashMap", typeName KPLIB_persistent_sectors];
                KPLIB_persistent_sectors = createHashMap;
                publicVariable "KPLIB_persistent_sectors";
            };
        };
        
        if (_sectorHasSavedData) then {
            diag_log format ["[KPLIB] Sector %1 - Has persistence flag", _sector];
            
            // Check if there's actual saved data in the persistence map
            if (_hasDataInMap) then {
                diag_log format ["[KPLIB] Sector %1 - Loading persistent units from data", _sector];
                
                // Mark sector as in transition
                KPLIB_sectors_in_transition pushBack _sector;
                
                // Immediately mark the data as used to prevent duplicate spawning
                // Make a local copy first
                private _localSectorData = KPLIB_persistent_sectors get _sector;
                
                // Delete from the persistent map
                KPLIB_persistent_sectors deleteAt _sector;
                publicVariable "KPLIB_persistent_sectors";
                
                // Spawn the saved units using the local copy
                private _persistentUnits = [_sector, _sectorpos, _localSectorData] call KPLIB_fnc_spawnPersistentUnits;
                
                if (count _persistentUnits > 0) then {
                    _hasPersistentUnits = true;
                    _managed_units = _managed_units + _persistentUnits;
                    diag_log format ["[KPLIB] Sector %1 - Restored %2 persistent units", _sector, count _persistentUnits];
                    
                    // Units need brief time to initialize - use CBA instead of sleep
                    [{
                        diag_log "[KPLIB] Persistent units initialization complete";
                    }, [], 0.5] call CBA_fnc_waitAndExecute;
                } else {
                    diag_log format ["[KPLIB] Sector %1 - No units were restored from persistence data", _sector];
                };
                
                // Remove from transition list after delay
                [{
                    params ["_sector"];
                    KPLIB_sectors_in_transition = KPLIB_sectors_in_transition - [_sector];
                }, [_sector], 5] call CBA_fnc_waitAndExecute;
            } else {
                diag_log format ["[KPLIB] Sector %1 - Marked as saved but no data found in KPLIB_persistent_sectors map", _sector];
                missionNamespace setVariable [_sectorSavedVar, false, true];
            };
        } else {
            diag_log format ["[KPLIB] Sector %1 - No persistence flag found, will spawn new units", _sector];
        };
        
        // Only spawn new units if no persistent units were found
        if (!_hasPersistentUnits) then {
            diag_log format ["[KPLIB] Sector %1 - No persistent units found, spawning new units", _sector];
            // Spawn vehicles
            private _fnc_spawnVehicles = {
                params ["_sectorpos", "_vehtospawn", "_managed_units"];
                private _newManagedUnits = +_managed_units;
                
                private _fnc_processVehicle = {
                    params ["_index", "_vehicles", "_sectorpos", "_managed_units"];
                    
                    if (_index >= count _vehicles) exitWith {_managed_units};
                    
                    // Use optimized spawn vehicle function which already implements the [0,0,0] creation method
                    private _vehicle = [_sectorpos, _vehicles select _index] call KPLIB_fnc_spawnVehicle;
                    
                    // Create crew
                    private _crew = [];
                    private _crewType = "";
                    
                    // Determine crew type based on vehicle class
                    private _isArmored = _vehicle isKindOf "Tank" || _vehicle isKindOf "Wheeled_APC_F";
                    
                    // Use appropriate crew type based on vehicle type
                    if (_isArmored) then {
                        // For tanks and APCs, use dedicated crew
                        _crewType = opfor_crewman;
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Using specialized crew (%1) for armored vehicle %2", _crewType, typeOf _vehicle];
                        };
                    } else {
                        // For other vehicles, use regular infantry
                        _crewType = opfor_rifleman;
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Using infantry crew (%1) for vehicle %2", _crewType, typeOf _vehicle];
                        };
                    };
                    
                    // Ensure crew type is a string
                    if (!(_crewType isEqualType "")) then {
                        diag_log format ["[KPLIB] ERROR: Invalid crew type %1 for vehicle %2, using fallback unit", _crewType, typeOf _vehicle];
                        _crewType = "O_Soldier_F";
                    };
                    
                    // Create crew manually
                    private _grp = createGroup [GRLIB_side_enemy, true];
                    private _driver = objNull;
                    private _gunner = objNull;
                    private _commander = objNull;
                    
                    // Create driver if needed
                    if (_vehicle emptyPositions "driver" > 0) then {
                        try {
                            _driver = _grp createUnit [_crewType, _sectorpos, [], 0, "NONE"];
                            _driver moveInDriver _vehicle;
                            _crew pushBack _driver;
                            if (KP_liberation_debug) then {
                                diag_log format ["[KPLIB] Created driver %1 for vehicle %2", _driver, _vehicle];
                            };
                        } catch {
                            diag_log format ["[KPLIB] ERROR creating driver for vehicle %1: %2", _vehicle, _exception];
                        };
                    };
                    
                    // Create gunner if needed
                    if (_vehicle emptyPositions "gunner" > 0) then {
                        try {
                            _gunner = _grp createUnit [_crewType, _sectorpos, [], 0, "NONE"];
                            _gunner moveInGunner _vehicle;
                            _crew pushBack _gunner;
                            if (KP_liberation_debug) then {
                                diag_log format ["[KPLIB] Created gunner %1 for vehicle %2", _gunner, _vehicle];
                            };
                        } catch {
                            diag_log format ["[KPLIB] ERROR creating gunner for vehicle %1: %2", _vehicle, _exception];
                        };
                    };
                    
                    // Create commander if needed
                    if (_vehicle emptyPositions "commander" > 0) then {
                        try {
                            _commander = _grp createUnit [_crewType, _sectorpos, [], 0, "NONE"];
                            _commander moveInCommander _vehicle;
                            _crew pushBack _commander;
                            if (KP_liberation_debug) then {
                                diag_log format ["[KPLIB] Created commander %1 for vehicle %2", _commander, _vehicle];
                            };
                        } catch {
                            diag_log format ["[KPLIB] ERROR creating commander for vehicle %1: %2", _vehicle, _exception];
                        };
                    };
                    
                    // Add to cargo if needed
                    if (count _crew == 0) then {
                        _driver = _grp createUnit [_crewType, _sectorpos, [], 0, "NONE"];
                        _driver moveInCargo _vehicle;
                        _crew pushBack _driver;
                    };
                    
                    // Log crew creation result
                    if (KP_liberation_debug) then {
                        diag_log format ["[KPLIB] Created %1 crew members for vehicle %2", count _crew, typeOf _vehicle];
                    };
                    
                    if (count _crew > 0 && {!isNull group (_crew select 0)}) then {
                        // Add a delay to ensure vehicle is fully initialized before applying waypoints
                        [{
                            params ["_vehGroup", "_sector", "_vehicle"];
                            
                            if (!isNull _vehGroup && {count units _vehGroup > 0}) then {
                                // Set group behavior
                                _vehGroup setBehaviour "AWARE";
                                _vehGroup setCombatMode "YELLOW";
                                _vehGroup enableAttack true;
                                
                                // Make sure crew follows leader
                                {_x doFollow (leader _vehGroup)} forEach (units _vehGroup);
                                
                                // 50/50 chance to apply patrol waypoints
                                if (random 1 > 0.5) then {
                                    // Apply AI with sector marker position - use specialized vehicle patrol function
                                    [_vehGroup, markerPos _sector, GRLIB_sector_size * 0.75] call KPLIB_fnc_applyVehiclePatrol;
                                    if (KP_liberation_debug) then {
                                        diag_log format ["[KPLIB] Applied vehicle patrol for %1 in sector %2", typeOf _vehicle, _sector];
                                    };
                                } else {
                                    if (KP_liberation_debug) then {
                                        diag_log format ["[KPLIB] Skipped vehicle patrol waypoints for %1 in sector %2", typeOf _vehicle, _sector];
                                    };
                                };
                            } else {
                                if (KP_liberation_debug) then {
                                    diag_log format ["[KPLIB] WARNING: Vehicle group %1 is null or empty, cannot apply AI", _vehGroup];
                                };
                            };
                        }, [group (_crew select 0), _sector, _vehicle], 3] call CBA_fnc_waitAndExecute;
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] WARNING: No crew created for vehicle %1, cannot apply AI", _vehicle];
                        };
                    };
                    
                    private _updatedUnits = +_managed_units;
                    _updatedUnits pushback _vehicle;
                    {_updatedUnits pushback _x;} foreach _crew;
                    
                    // Process next vehicle after delay
                    [_fnc_processVehicle, [_index + 1, _vehicles, _sectorpos, _updatedUnits], 0.25] call CBA_fnc_waitAndExecute;
                    
                    _updatedUnits
                };
                
                // Start processing vehicles
                if (count _vehtospawn > 0) then {
                    _newManagedUnits = [0, _vehtospawn, _sectorpos, _newManagedUnits] call _fnc_processVehicle;
                };
                
                _newManagedUnits
            };
            
            // Spawn vehicles
            _managed_units = [_sectorpos, _vehtospawn, _managed_units] call _fnc_spawnVehicles;
            
            // Spawn building squad if buildings available
            // DISABLED - Replaced by new squad spawning and AI behavior
            
            _managed_units = _managed_units + ([_sectorpos] call KPLIB_fnc_spawnMilitaryPostSquad);
            
            // --- Check for Overwatch Position BEFORE Spawning Regular Squads ---
            private _overwatchPos = [_sectorpos, 600, 200, 5, _sectorpos] call lambs_main_fnc_findOverwatch;
            if (!(_overwatchPos isEqualTo [0,0,0]) && {_overwatchPos distance2D _sectorpos > 50}) then {
                // Randomly choose comp size
                private _overwatchCompVar = selectRandom ["KPLIB_o_fireteamAssault", "KPLIB_o_squadStd"];

                // Spawn the overwatch squad
                private _spawnResult = [_overwatchCompVar, _overwatchPos] call KPLIB_fnc_spawnSquadHC;
                private _overwatchGroup = _spawnResult select 0;
                private _overwatchOwnerID = _spawnResult select 1;

                if (!isNull _overwatchGroup) then {
                    private _groupNetID = netId _overwatchGroup;
                    _overwatchOwnerID = groupOwner _overwatchGroup;
                    // Assign behavior with position override
                    [_groupNetID, _sector, "DEFEND_AREA", _overwatchPos] remoteExecCall ["KPLIB_fnc_applyAIBehavior", _overwatchOwnerID];
                } else {
                    diag_log format ["[KPLIB] Sector %1: ERROR - Failed to spawn Overwatch squad (%2) at %3", _sector, _overwatchCompVar, _overwatchPos];
                };
            } else {
                // diag_log format ["[KPLIB] Sector %1: No suitable overwatch position found.", _sector];
            };
            // --- END Overwatch Check ---
            
            // --- START NEW Infantry Spawning Logic (Generalized Prioritization) ---
            if (count _squadRoles > 0) then {

                // --- START Role & Composition Prioritization Logic ---
                private _roleCompInfo = []; // Array to store [role, compVar, size]
                private _validCompVars = []; // Just the composition variable names

                // 1. Gather Composition Info for each Role
                {
                    private _role = _x;
                    private _compVar = [_sector, _role, _sectorType] call KPLIB_fnc_selectSquadComposition;
                    if !(isNil "_compVar" || {_compVar == ""} || {isNil {missionNamespace getVariable _compVar}}) then {
                        private _compArray = missionNamespace getVariable [_compVar, []];
                        private _compSize = count _compArray;
                        _roleCompInfo pushBack [_role, _compVar, _compSize];
                        _validCompVars pushBack _compVar; // Keep track of valid compVars separately
                    } else {
                       _roleCompInfo pushBack [_role, nil, 0]; // Mark as invalid if compVar is bad
                    };
                } forEach _squadRoles;

                // Ensure we only consider roles with valid compositions for assignment matching
                private _assignableRoles = _roleCompInfo select {!isNil (_x select 1)};
                if (count _assignableRoles != count _squadRoles) then {
                     diag_log format ["[KPLIB] Sector %1: WARNING - Mismatch between requested roles (%2) and valid compositions found (%3). Proceeding with valid ones.", _sector, count _squadRoles, count _assignableRoles];
                     // Potentially problematic if KPLIB_fnc_selectSquadComposition fails, but we proceed.
                };
                
                // 2. Separate Compositions by Size Preference
                private _largeCompVars = [];
                private _smallCompVars = [];
                {
                    private _size = _x select 2;
                    private _compVar = _x select 1;
                    if (_size >= 8) then {
                        _largeCompVars pushBack _compVar;
                    } else {
                        _smallCompVars pushBack _compVar;
                    };
                } forEach _assignableRoles; // Use assignableRoles which only has valid compVars

                // Shuffle to add randomness within size categories
                _largeCompVars = [_largeCompVars] call CBA_fnc_shuffle;
                _smallCompVars = [_smallCompVars] call CBA_fnc_shuffle;

                // 3. Define Role Priority Order
                // Roles not listed here will be handled as 'other'/'lowest' priority.
                private _rolePriority = [
                    "GARRISON_CENTER",
                    "CAMP_SECTOR",
                    "DEFEND_AREA",
                    "PATROL_INNER",
                    "PATROL_OUTER",
                    "PATROL_DEFAULT"
                    // Add other specific roles here if they need priority ranking
                ];
                private _highPriorityDefensive = ["GARRISON_CENTER", "CAMP_SECTOR", "DEFEND_AREA"];
                private _lowPriorityPatrol = ["PATROL_INNER", "PATROL_OUTER", "PATROL_DEFAULT"];

                // 4. Assign Roles to Compositions based on Priority
                private _assignments = createHashMap; // Stores: role => assignedCompVar
                private _rolesToAssign = +_squadRoles; // Create a mutable copy

                // --- Function to attempt assignment ---
                private _fnc_tryAssign = {
                    params ["_role", "_preferredCompList", "_fallbackCompList", "_assignments"];
                    private _assignedCompVar = nil;
                    
                    if (count _preferredCompList > 0) then {
                        _assignedCompVar = _preferredCompList deleteAt 0; // Take from preferred list
                    } else {
                        if (count _fallbackCompList > 0) then {
                            _assignedCompVar = _fallbackCompList deleteAt 0; // Take from fallback list
                        } else {
                            diag_log format ["[KPLIB] Sector %1: WARNING - No compositions left to assign role '%2'", _sector, _role];
                        };
                    };
                    
                    if !(isNil "_assignedCompVar") then {
                        _assignments set [_role, _assignedCompVar];
                    };
                    _assignedCompVar // Return compVar or nil
                };
                // --- End Function ---

                // Iterate through priority list
                {
                    private _currentRole = _x;
                    if (_currentRole in _rolesToAssign) then { // Check if this role needs assignment
                        private _assignedCompVar = nil;
                         if (_currentRole in _highPriorityDefensive) then {
                            _assignedCompVar = [_currentRole, _largeCompVars, _smallCompVars, _assignments] call _fnc_tryAssign;
                        };
                        if (isNil "_assignedCompVar" && {_currentRole in _lowPriorityPatrol}) then { // Check if not already assigned
                            _assignedCompVar = [_currentRole, _smallCompVars, _largeCompVars, _assignments] call _fnc_tryAssign;
                        };
                        
                        // If a composition was successfully assigned in this iteration, remove the role from the list
                        if !(isNil "_assignedCompVar") then {
                            _rolesToAssign = _rolesToAssign - [_currentRole];
                        };
                    };
                } forEach _rolePriority;

                // Assign any remaining roles (those not in the priority list or left over)
                if (count _rolesToAssign > 0) then {
                    private _remainingComps = _largeCompVars + _smallCompVars; // Combine remaining comps, large first
                     {
                        private _role = _x;
                        if (count _remainingComps > 0) then {
                            private _compVar = _remainingComps deleteAt 0;
                            _assignments set [_role, _compVar];
                        } else {
                            diag_log format ["[KPLIB] Sector %1: ERROR - Ran out of compositions while assigning leftover role '%2'.", _sector, _role];
                            _assignments set [_role, nil]; // Mark as unassignable
                        };
                    } forEach _rolesToAssign;
                };
                // --- END Role & Composition Prioritization Logic ---


                // --- START Spawning Loop (Using Assignments) ---
                {
                    private _roleIndex = _forEachIndex;
                    private _role = _x; // Get role from original _squadRoles list

                    // Get the composition variable assigned to this role
                    private _compositionVar = _assignments getOrDefault [_role, nil];

                    if (isNil "_compositionVar") then {
                         diag_log format ["[KPLIB] Sector %1: ERROR - No composition assigned for role '%2' at index %3. Skipping spawn.", _sector, _role, _roleIndex];
                         continue; // Skip to next iteration
                    };
                    
                    // --- Spawn logic using _role and _compositionVar ---
                    private ["_spawnResult", "_group", "_ownerID"];
                    _spawnResult = [_compositionVar, _sector] call KPLIB_fnc_spawnSquadHC;
                    _group = _spawnResult select 0;
                    _ownerID = _spawnResult select 1;

                    if (!isNull _group) then {
                        private _groupNetID = netId _group;
                        _ownerID = groupOwner _group;
                        [_groupNetID, _sector, _role] remoteExecCall ["KPLIB_fnc_applyAIBehavior", _ownerID];
                    } else {
                        diag_log format ["[KPLIB] Sector %1: ERROR - KPLIB_fnc_spawnSquadHC returned null group for assigned role %2 with comp %3", _sector, _role, _compositionVar];
                    };
                    // --- End of spawn logic ---
                        
                } forEach _squadRoles; // Iterate through the original list of roles for the sector
                // --- END Spawning Loop ---

            };
            // --- END NEW Infantry Spawning Logic ---
            
            // Spawn civilians if enabled
            if (_spawncivs && GRLIB_civilian_activity > 0) then {
                _managed_units = _managed_units + ([_sector] call KPLIB_fnc_spawnCivilians);
            };
        };
        
        // IED management
        if (KP_liberation_asymmetric_debug > 0) then {
            [format ["Sector %1 (%2) - Range: %3 - Count: %4", (markerText _sector), _sector, _building_range, _iedcount], "ASYMMETRIC"] remoteExecCall ["KPLIB_fnc_log", 2];
        };
        [_sector, _building_range, _iedcount] call ied_manager;
        
        // Guerrilla activation
        if (_guerilla) then {
            [_sector] call sector_guerilla;
        };
        
        // Call reinforcements after delay
        [{
            params ["_sector"];
            
            if ((_sector in sectors_factory) || (_sector in sectors_capture) || (_sector in sectors_bigtown) || (_sector in sectors_military)) then {
                [_sector] remoteExec ["reinforcements_remote_call", 2];
            };
            
            if (KP_liberation_sectorspawn_debug > 0) then {
                [format ["Sector %1 (%2) - populating done", (markerText _sector), _sector], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
            };
        }, [_sector], 10] call CBA_fnc_waitAndExecute;
        
    } else {
        // If sector doesn't need to be populated, just wait and deactivate
        [{
            params ["_sector"];
            active_sectors = active_sectors - [_sector]; 
            publicVariable "active_sectors";
        }, [_sector], 40] call CBA_fnc_waitAndExecute;
    }; // End of main sector processing
};

// Start sector setup
[_sector, _opforcount, _sectorpos] call _fnc_setupSector;

// Set up sector lifetime PFH to decrement tickets when no enemies present
private _tickTime = time;
private _additionalTicketsAdded = false;
private _handle = [{
    params ["_args", "_handle"];
    _args params ["_sector", "_sectorpos", "_managed_units", "_sector_despawn_tickets", "_maximum_additional_tickets", "_tickTime", "_additionalTicketsAdded", "_local_capture_size"];
    
    // Check if sector is captured by blufor
    if (_sector in blufor_sectors) exitWith {
        diag_log format ["[KPLIB] Sector %1 - already captured by blufor, removing PFH", _sector];
        [_handle] call CBA_fnc_removePerFrameHandler;
    };
    
    // Check for active capture conditions
    if (([_sectorpos, _local_capture_size] call KPLIB_fnc_getSectorOwnership == GRLIB_side_friendly) && (GRLIB_endgame == 0)) then {
        // Log the capture attempt
        diag_log format ["[KPLIB] Sector %1 - friendly control detected, validating capture", _sector];
        
        // Validate the sector capture attempt
        private _valid = [_sector] call KPLIB_fnc_validateSectorCapture;
        
        diag_log format ["[KPLIB] Sector %1 - capture validation result: %2", _sector, _valid];
        
        if (_valid) then {
            // Additional check for enemy presence
            private _enemiesInSector = [_sectorpos, _local_capture_size, GRLIB_side_enemy] call KPLIB_fnc_getUnitsCount;
            
            if (_enemiesInSector > 0) then {
                diag_log format ["[KPLIB] Sector %1 - Enemies still present (%2) despite capture conditions being met - waiting for elimination", _sector, _enemiesInSector];
            } else {
                diag_log format ["[KPLIB] Sector %1 - conditions met for capture, calling liberation", _sector];
                
                // Use isServer check to avoid redundant calls
                if (isServer) then {
                    [_sector] call sector_liberated_remote_call;
                } else {
                    [_sector] remoteExec ["sector_liberated_remote_call", 2];
                };
                
                // Clean up PFH
                [_handle] call CBA_fnc_removePerFrameHandler;
            }
        } else {
            diag_log format ["[KPLIB] Sector %1 - invalid capture attempt (too far from friendly territory)", _sector];
            
            // Send notification to players
            ["Sector capture failed: Too far from friendly territory"] remoteExec ["hint", 0];
        };
    };
    
    // Check for player/friendly presence
    private _friendlies_near = ([_sectorpos, GRLIB_sector_size, GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount);
    
    // If no friendlies (players) are present, decrement tickets
    if (_friendlies_near == 0) then {
        _args set [3, _sector_despawn_tickets - 1]; // Decrement tickets
        
        // Add additional time (once) if sector has been active for a while
        if (!_additionalTicketsAdded && (time > (_tickTime + (ADDITIONAL_TICKETS_DELAY * 60)))) then {
            _args set [3, _sector_despawn_tickets + _maximum_additional_tickets];
            _args set [6, true]; // Mark additional tickets as added
            diag_log format ["[KPLIB] Sector %1 - Adding %2 additional despawn tickets", _sector, _maximum_additional_tickets];
        };
        
        // Debug message every 5 tickets
        if ((_sector_despawn_tickets mod 5) == 0) then {
            diag_log format ["[KPLIB] Sector %1 despawn countdown: %2 tickets left", _sector, _sector_despawn_tickets];
        };
    } else {
        // Reset the timer if friendlies appear
        _args set [5, time];
    };
    
    // Check if sector should despawn
    if (_sector_despawn_tickets <= 0) then {
        diag_log format ["[KPLIB] Sector %1 despawning - processing %2 managed units", _sector, count _managed_units];
        
        // Clear sector from active sectors list first - helps prevent race conditions
        active_sectors = active_sectors - [_sector]; 
        publicVariable "active_sectors";
        
        // Check if we need to save persistent units
        private _isAlreadyLoading = _sector in KPLIB_sectors_in_transition;
        
        if (_isAlreadyLoading) then {
            // Skip saving if already loading - prevents race condition
            diag_log format ["[KPLIB] Sector %1 - Already in transition, skipping persistence save", _sector];
        } else {
            // Mark as in transition
            KPLIB_sectors_in_transition pushBack _sector;
            
            // Save the units for persistence before cleanup
            [_sector, _sectorpos, _managed_units] call KPLIB_fnc_saveSectorUnits;
            
            // Remove from transition list after short delay
            [{
                params ["_sector"];
                KPLIB_sectors_in_transition = KPLIB_sectors_in_transition - [_sector];
            }, [_sector], 5] call CBA_fnc_waitAndExecute;
        };
        
        // Ensure save completed before continuing
        [{
            params ["_sector", "_sectorpos", "_managed_units", "_handle"];
            
            // Verify the persistence flag is set
            private _sectorSavedVar = format ["KPLIB_sector_%1_saved", _sector];
            diag_log format ["[KPLIB] Sector %1 - Persistence saving completed, flag is: %2", 
                _sector, missionNamespace getVariable [_sectorSavedVar, false]];
            
            // If the flag is not set by saveSectorUnits, set it explicitly
            if !(missionNamespace getVariable [_sectorSavedVar, false]) then {
                diag_log format ["[KPLIB] Sector %1 - Persistence flag was not set by saveSectorUnits, setting it now", _sector];
                missionNamespace setVariable [_sectorSavedVar, true, true];
            };
            
            // SIMPLIFIED APPROACH: Find and delete all OPFOR units in sector area
            private _sectorRange = 500; // Large enough to catch everything
            private _allUnits = _sectorpos nearEntities [["Man", "Car", "Tank", "Air", "Ship"], _sectorRange];
            
            // Count units by type for logging
            private _infantryCount = 0;
            private _vehicleCount = 0;
            private _groupsDeleted = 0;
            private _processedGroups = [];
            
            {
                // Only process enemy units
                if ((side _x == GRLIB_side_enemy) || (side _x == GRLIB_side_civilian && {_x getVariable ["KPLIB_insurgent", false]})) then {
                    if (_x isKindOf "Man") then {
                        _infantryCount = _infantryCount + 1;
                        // Track infantry groups for cleanup
                        private _grp = group _x;
                        if (!isNull _grp && {!(_grp in _processedGroups)}) then {
                            _processedGroups pushBack _grp;
                        };
                        deleteVehicle _x;
                    } else {
                        // For vehicles, check if they're not captured
                        if (!(_x getVariable ["KPLIB_captured", false])) then {
                            _vehicleCount = _vehicleCount + 1;
                            
                            // Delete crew first, then vehicle
                            private _crewGroup = group driver _x;
                            if (!isNull _crewGroup && {!(_crewGroup in _processedGroups)}) then {
                                _processedGroups pushBack _crewGroup;
                            };
                            
                            // Log and delete crew
                            private _crew = crew _x;
                            diag_log format ["[KPLIB] Deleting %1 crew members from vehicle %2", count _crew, _x];
                            {deleteVehicle _x} forEach _crew;
                            
                            diag_log format ["[KPLIB] Deleting sector vehicle: %1 (Type: %2) at position %3", _x, typeOf _x, getPosASL _x];
                            [_x] call KPLIB_fnc_cleanOpforVehicle;
                        };
                    };
                };
            } forEach _allUnits;
            
            // Clean up all tracked groups
            {
                if (!isNull _x && {count units _x == 0}) then {
                    deleteGroup _x;
                    _groupsDeleted = _groupsDeleted + 1;
                };
            } forEach _processedGroups;
            
            diag_log format ["[KPLIB] Sector cleanup deleted %1 infantry, %2 vehicles, and %3 groups", _infantryCount, _vehicleCount, _groupsDeleted];
            
            // Remove this PFH after cleanup is complete
            [_handle] call CBA_fnc_removePerFrameHandler;
            
            // Now scan for nearby vehicles that might not be in the managed_units array
            private _nearbyVehicles = _sectorpos nearEntities [["Car", "Tank", "Air", "Ship"], 300];
            private _unmanagedVehicles = _nearbyVehicles - _managed_units;
            if (count _unmanagedVehicles > 0) then {
                diag_log format ["[KPLIB] Found %1 nearby vehicles NOT in managed_units for sector %2", count _unmanagedVehicles, _sector];
                {
                    private _nearVeh = _x;
                    private _nearVehSector = _nearVeh getVariable ["KPLIB_sectorOrigin", "unknown"];
                    private _nearVehCaptured = _nearVeh getVariable ["KPLIB_captured", false];
                    diag_log format ["[KPLIB] Unmanaged vehicle: %1 (Type: %2) from sector %3, captured: %4", _nearVeh, typeOf _nearVeh, _nearVehSector, _nearVehCaptured];
                    
                    // Cleanup unmanaged vehicles that belong to this sector and aren't captured
                    if (_nearVehSector == _sector && !_nearVehCaptured) then {
                        // Delete crew members first, track their group
                        private _crewGroup = group driver _nearVeh;
                        private _crew = crew _nearVeh;
                        diag_log format ["[KPLIB] Deleting %1 crew members from unmanaged vehicle %2", count _crew, _nearVeh];
                        {deleteVehicle _x} forEach _crew;
                        
                        diag_log format ["[KPLIB] Cleaning unmanaged vehicle: %1 from sector %2", _nearVeh, _sector];
                        [_nearVeh] call KPLIB_fnc_cleanOpforVehicle;
                        
                        // Delete the group if it's now empty
                        if (!isNull _crewGroup && {count units _crewGroup == 0}) then {
                            deleteGroup _crewGroup;
                            diag_log format ["[KPLIB] Deleted empty group from unmanaged vehicle"];
                        };
                    };
                } forEach _unmanagedVehicles;
            };
        }, [_sector, _sectorpos, _managed_units, _handle], 1] call CBA_fnc_waitAndExecute; // short delay to ensure save completes
        
        // Return early since cleanup is handled in the above code block
        // Do NOT remove the PFH here as it's done in the delayed execution block
    };
}, SECTOR_TICK_TIME, [_sector, _sectorpos, _managed_units, _sector_despawn_tickets, _maximum_additional_tickets, _tickTime, _additionalTicketsAdded, _local_capture_size]] call CBA_fnc_addPerFrameHandler;

[format ["Sector %1 (%2) initial setup complete - Was managed on: %3", (markerText _sector), _sector, debug_source], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
