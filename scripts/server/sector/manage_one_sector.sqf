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

// Wait for combat_readiness variable to be defined before proceeding
[{!isNil "combat_readiness"}, {
    params ["_sector"];
    
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
    
    if (GRLIB_unitcap < 1) then {_popfactor = GRLIB_unitcap;};
    
    if (_sector in active_sectors) exitWith {};
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
                params ["_sector", "_sectorpos", "_opforcount"];
                private ["_spawncivs", "_building_ai_max", "_infsquad", "_building_range", "_local_capture_size", 
                          "_iedcount", "_vehtospawn", "_managed_units", "_squad1", "_squad2", "_squad3", "_squad4", 
                          "_minimum_building_positions", "_sector_despawn_tickets", "_maximum_additional_tickets", 
                          "_popfactor", "_guerilla"];
                
                // Initialize variables with default values
                _spawncivs = false;
                _building_ai_max = 0;
                _infsquad = "army";
                _building_range = 50;
                _local_capture_size = GRLIB_capture_size;
                _iedcount = 0;
                _vehtospawn = [];
                _managed_units = [];
                _squad1 = [];
                _squad2 = [];
                _squad3 = [];
                _squad4 = [];
                _minimum_building_positions = 5;
                _sector_despawn_tickets = BASE_TICKETS;
                _maximum_additional_tickets = (KP_liberation_delayDespawnMax * 60 / SECTOR_TICK_TIME);
                _popfactor = 1;
                _guerilla = false;
                
                if (GRLIB_unitcap < 1) then {_popfactor = GRLIB_unitcap;};
                
                // Different sector type configurations
                if (_sector in sectors_bigtown) then {
                    if (combat_readiness < 30) then {_infsquad = "militia";};
                    
                    _squad1 = ([_infsquad] call KPLIB_fnc_getSquadComp);
                    _squad2 = ([_infsquad] call KPLIB_fnc_getSquadComp);
                    if (GRLIB_unitcap >= 1) then {_squad3 = ([_infsquad] call KPLIB_fnc_getSquadComp);};
                    if (GRLIB_unitcap >= 1.5) then {_squad4 = ([_infsquad] call KPLIB_fnc_getSquadComp);};
                    
                    _vehtospawn = [(selectRandom militia_vehicles),(selectRandom militia_vehicles)];
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if ((random 100) > (50 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if (_infsquad == "army") then {
                        _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                        _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                        if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    };
                    
                    _spawncivs = true;
                    
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then {
                        _guerilla = true;
                    };
                    
                    _building_ai_max = round (50 * _popfactor);
                    _building_range = 200;
                    _local_capture_size = _local_capture_size * 1.4;
                    
                    if (KP_liberation_civ_rep < 0) then {
                        _iedcount = round (2 + (ceil (random 4)) * (round ((KP_liberation_civ_rep * -1) / 33)) * GRLIB_difficulty_modifier);
                    } else {
                        _iedcount = 0;
                    };
                    if (_iedcount > 16) then {_iedcount = 16};
                };
                
                if (_sector in sectors_capture) then {
                    if (combat_readiness < 50) then {_infsquad = "militia";};
                    
                    _squad1 = ([_infsquad] call KPLIB_fnc_getSquadComp);
                    if (GRLIB_unitcap >= 1.25) then {_squad2 = ([_infsquad] call KPLIB_fnc_getSquadComp);};
                    
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    if (_infsquad == "army") then {
                        _vehtospawn pushback (selectRandom militia_vehicles);
                        if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {
                            _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                            _squad3 = ([_infsquad] call KPLIB_fnc_getSquadComp);
                        };
                    };
                    
                    _spawncivs = true;
                    
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then {
                        _guerilla = true;
                    };
                    
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 10 )))) * _popfactor);
                    _building_range = 120;
                    
                    if (KP_liberation_civ_rep < 0) then {
                        _iedcount = round ((ceil (random 4)) * (round ((KP_liberation_civ_rep * -1) / 33)) * GRLIB_difficulty_modifier);
                    } else {
                        _iedcount = 0;
                    };
                    if (_iedcount > 12) then {_iedcount = 12};
                };
                
                if (_sector in sectors_military) then {
                    _squad1 = ([] call KPLIB_fnc_getSquadComp);
                    _squad2 = ([] call KPLIB_fnc_getSquadComp);
                    if (GRLIB_unitcap >= 1.5) then {_squad3 = ([] call KPLIB_fnc_getSquadComp);};
                    
                    _vehtospawn = [([] call KPLIB_fnc_getAdaptiveVehicle),([] call KPLIB_fnc_getAdaptiveVehicle)];
                    if ((random 100) > (33 / GRLIB_difficulty_modifier)) then {
                        _vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);
                        _squad4 = ([] call KPLIB_fnc_getSquadComp);
                    };
                    if ((random 100) > (66 / GRLIB_difficulty_modifier)) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    
                    _spawncivs = false;
                    
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 4 )))) * _popfactor);
                    _building_range = 120;
                };
                
                if (_sector in sectors_factory) then {
                    if (combat_readiness < 40) then {_infsquad = "militia";};
                    
                    _squad1 = ([_infsquad] call KPLIB_fnc_getSquadComp);
                    if (GRLIB_unitcap >= 1.25) then {_squad2 = ([_infsquad] call KPLIB_fnc_getSquadComp);};
                    
                    if ((random 100) > 66) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    if ((random 100) > 33) then {_vehtospawn pushback (selectRandom militia_vehicles);};
                    
                    _spawncivs = false;
                    
                    if (((random 100) <= KP_liberation_resistance_sector_chance) && (([] call KPLIB_fnc_crGetMulti) > 0)) then {
                        _guerilla = true;
                    };
                    
                    _building_ai_max = round ((floor (18 + (round (combat_readiness / 10 )))) * _popfactor);
                    _building_range = 120;
                    
                    if (KP_liberation_civ_rep < 0) then {
                        _iedcount = round ((ceil (random 3)) * (round ((KP_liberation_civ_rep * -1) / 33)) * GRLIB_difficulty_modifier);
                    } else {
                        _iedcount = 0;
                    };
                    if (_iedcount > 8) then {_iedcount = 8};
                };
                
                if (_sector in sectors_tower) then {
                    _squad1 = ([] call KPLIB_fnc_getSquadComp);
                    if (combat_readiness > 30) then {_squad2 = ([] call KPLIB_fnc_getSquadComp);};
                    if (GRLIB_unitcap >= 1.5) then {_squad3 = ([] call KPLIB_fnc_getSquadComp);};
                    
                    if((random 100) > 95) then {_vehtospawn pushback ([] call KPLIB_fnc_getAdaptiveVehicle);};
                    
                    _spawncivs = false;
                    
                    _building_ai_max = 0;
                };
                
                _vehtospawn = _vehtospawn select {!(isNil "_x")};
                
                if (KP_liberation_sectorspawn_debug > 0) then {
                    [format ["Sector %1 (%2) - manage_one_sector calculated -> _infsquad: %3 - _squad1: %4 - _squad2: %5 - _squad3: %6 - _squad4: %7 - _vehtospawn: %8 - _building_ai_max: %9", 
                    (markerText _sector), _sector, _infsquad, (count _squad1), (count _squad2), (count _squad3), (count _squad4), (count _vehtospawn), _building_ai_max], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
                };
                
                if (_building_ai_max > 0 && GRLIB_adaptive_opfor) then {
                    _building_ai_max = round (_building_ai_max * ([] call KPLIB_fnc_getOpforFactor));
                };
                
                // Return all the sector configuration variables as an array
                [_spawncivs, _building_ai_max, _infsquad, _building_range, _local_capture_size, _iedcount, 
                 _vehtospawn, _managed_units, _squad1, _squad2, _squad3, _squad4, _minimum_building_positions, 
                 _sector_despawn_tickets, _maximum_additional_tickets, _popfactor, _guerilla]
            };
            
            // Configure sector based on its type
            private _sectorConfig = [_sector, _sectorpos, _opforcount] call _fnc_configureSector;
            _sectorConfig params ["_spawncivs", "_building_ai_max", "_infsquad", "_building_range", "_local_capture_size", 
                                "_iedcount", "_vehtospawn", "_managed_units", "_squad1", "_squad2", "_squad3", "_squad4", 
                                "_minimum_building_positions", "_sector_despawn_tickets", "_maximum_additional_tickets", 
                                "_popfactor", "_guerilla"];
            
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
                                    _vehGroup setSpeedMode "NORMAL";
                                    _vehGroup enableAttack true;
                                    
                                    // Make sure crew follows leader
                                    {_x doFollow (leader _vehGroup)} forEach (units _vehGroup);
                                    
                                    // Apply AI with sector marker position - use specialized vehicle patrol function
                                    [_vehGroup, markerPos _sector, GRLIB_sector_size * 0.75] call KPLIB_fnc_applyVehiclePatrol;
                                    if (KP_liberation_debug) then {
                                        diag_log format ["[KPLIB] Applied vehicle patrol for %1 in sector %2", typeOf _vehicle, _sector];
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
                if (_building_ai_max > 0) then {
                    _allbuildings = (nearestObjects [_sectorpos, ["House"], _building_range]) select {alive _x};
                    _buildingpositions = [];
                    {
                        _buildingpositions = _buildingpositions + ([_x] call BIS_fnc_buildingPositions);
                    } forEach _allbuildings;
                    
                    if (KP_liberation_sectorspawn_debug > 0) then {
                        [format ["Sector %1 (%2) - manage_one_sector found %3 building positions", (markerText _sector), _sector, (count _buildingpositions)], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
                    };
                    
                    if (count _buildingpositions > _minimum_building_positions) then {
                        _managed_units = _managed_units + ([_infsquad, _building_ai_max, _buildingpositions, _sector] call KPLIB_fnc_spawnBuildingSquad);
                    };
                };
                
                _managed_units = _managed_units + ([_sectorpos] call KPLIB_fnc_spawnMilitaryPostSquad);
                
                // Spawn regular squads
                if (count _squad1 > 0) then {
                    private _grp = [_sector, _squad1] call KPLIB_fnc_spawnRegularSquad;
                    
                    // Validate group before adding waypoints
                    if (!isNull _grp && {count units _grp > 0}) then {
                        [_grp, _sectorpos, "patrol", GRLIB_sector_size * 0.75, _sector] call KPLIB_fnc_applySquadAI;
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Invalid group for squad1 in sector %1", _sector];
                        };
                    };
                    
                    _managed_units = _managed_units + (units _grp);
                };
                
                if (count _squad2 > 0) then {
                    private _grp = [_sector, _squad2] call KPLIB_fnc_spawnRegularSquad;
                    
                    // Validate group before adding waypoints
                    if (!isNull _grp && {count units _grp > 0}) then {
                        [_grp, _sectorpos, "patrol", GRLIB_sector_size * 0.75, _sector] call KPLIB_fnc_applySquadAI;
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Invalid group for squad2 in sector %1", _sector];
                        };
                    };
                    
                    _managed_units = _managed_units + (units _grp);
                };
                
                if (count _squad3 > 0) then {
                    private _grp = [_sector, _squad3] call KPLIB_fnc_spawnRegularSquad;
                    
                    // Validate group before adding waypoints
                    if (!isNull _grp && {count units _grp > 0}) then {
                        [_grp, _sectorpos, "patrol", GRLIB_sector_size * 0.75, _sector] call KPLIB_fnc_applySquadAI;
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Invalid group for squad3 in sector %1", _sector];
                        };
                    };
                    
                    _managed_units = _managed_units + (units _grp);
                };
                
                if (count _squad4 > 0) then {
                    private _grp = [_sector, _squad4] call KPLIB_fnc_spawnRegularSquad;
                    
                    // Validate group before adding waypoints
                    if (!isNull _grp && {count units _grp > 0}) then {
                        [_grp, _sectorpos, "patrol", GRLIB_sector_size * 0.75, _sector] call KPLIB_fnc_applySquadAI;
                    } else {
                        if (KP_liberation_debug) then {
                            diag_log format ["[KPLIB] Invalid group for squad4 in sector %1", _sector];
                        };
                    };
                    
                    _managed_units = _managed_units + (units _grp);
                };
                
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
    
    [format ["Sector %1 (%2) deactivated - Was managed on: %3", (markerText _sector), _sector, debug_source], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
    
}, [_sector]] call CBA_fnc_waitUntilAndExecute;
