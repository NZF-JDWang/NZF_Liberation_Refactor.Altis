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
            
            // Spawn vehicles
            private _fnc_spawnVehicles = {
                params ["_sectorpos", "_vehtospawn", "_managed_units"];
                private _newManagedUnits = +_managed_units;
                
                private _fnc_processVehicle = {
                    params ["_index", "_vehicles", "_sectorpos", "_managed_units"];
                    
                    if (_index >= count _vehicles) exitWith {_managed_units};
                    
                    private _vehicle = [_sectorpos, _vehicles select _index] call KPLIB_fnc_spawnVehicle;
                    [group ((crew _vehicle) select 0), _sectorpos] call add_defense_waypoints;
                    
                    private _updatedUnits = +_managed_units;
                    _updatedUnits pushback _vehicle;
                    {_updatedUnits pushback _x;} foreach (crew _vehicle);
                    
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
                [_grp, _sectorpos] call add_defense_waypoints;
                _managed_units = _managed_units + (units _grp);
            };
            
            if (count _squad2 > 0) then {
                private _grp = [_sector, _squad2] call KPLIB_fnc_spawnRegularSquad;
                [_grp, _sectorpos] call add_defense_waypoints;
                _managed_units = _managed_units + (units _grp);
            };
            
            if (count _squad3 > 0) then {
                private _grp = [_sector, _squad3] call KPLIB_fnc_spawnRegularSquad;
                [_grp, _sectorpos] call add_defense_waypoints;
                _managed_units = _managed_units + (units _grp);
            };
            
            if (count _squad4 > 0) then {
                private _grp = [_sector, _squad4] call KPLIB_fnc_spawnRegularSquad;
                [_grp, _sectorpos] call add_defense_waypoints;
                _managed_units = _managed_units + (units _grp);
            };
            
            // Spawn civilians if enabled
            if (_spawncivs && GRLIB_civilian_activity > 0) then {
                _managed_units = _managed_units + ([_sector] call KPLIB_fnc_spawnCivilians);
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
            
            // Set up the sector lifetime management
            private _activationTime = time;
            
            // Function to handle sector liberation
            private _fnc_liberateSector = {
                params ["_sector", "_managed_units", "_local_capture_size"];
                
                if (isServer) then {
                    [_sector] spawn sector_liberated_remote_call;
                } else {
                    [_sector] remoteExec ["sector_liberated_remote_call", 2];
                };
                
                {[_x] spawn prisonner_ai;} forEach ((markerPos _sector) nearEntities [["Man"], _local_capture_size * 1.2]);
                
                // Remove from active sectors after delay
                [{
                    params ["_sector"];
                    active_sectors = active_sectors - [_sector]; 
                    publicVariable "active_sectors";
                }, [_sector], 60] call CBA_fnc_waitAndExecute;
                
                // Clean up units after a longer delay
                [{
                    params ["_managed_units"];
                    private _groupsDeleted = 0;
                    private _processedGroups = [];
                    
                    {
                        if (!isNull _x) then {
                            if (_x isKindOf "Man") then {
                                if (side group _x != GRLIB_side_friendly) then {
                                    // Track infantry groups for cleanup
                                    private _grp = group _x;
                                    if (!isNull _grp && {!(_grp in _processedGroups)}) then {
                                        _processedGroups pushBack _grp;
                                    };
                                    deleteVehicle _x;
                                }
                            } else {
                                // For vehicles, check if they're not captured
                                if (!(_x getVariable ["KPLIB_captured", false])) then {
                                    // Delete crew members first, then the vehicle
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
                    } forEach _managed_units;
                    
                    // Clean up all tracked groups
                    {
                        if (!isNull _x && {count units _x == 0}) then {
                            deleteGroup _x;
                            _groupsDeleted = _groupsDeleted + 1;
                        };
                    } forEach _processedGroups;
                    
                    diag_log format ["[KPLIB] Delayed cleanup deleted %1 groups", _groupsDeleted];
                }, [_managed_units], 600] call CBA_fnc_waitAndExecute;
                
                true // Return value to indicate sector was liberated
            };
            
            // Add a per-frame handler for the sector lifetime
            private _sectorLifetimeHandler = [{
                params ["_args", "_handle"];
                _args params ["_sector", "_sectorpos", "_local_capture_size", "_managed_units", "_opforcount", 
                              "_sector_despawn_tickets", "_activationTime", "_fnc_liberateSector",
                              "_maximum_additional_tickets"];
                
                // Check if sector was captured
                if (([_sectorpos, _local_capture_size] call KPLIB_fnc_getSectorOwnership == GRLIB_side_friendly) && (GRLIB_endgame == 0)) then {
                    // Handle sector liberation
                    _sectorLiberated = [_sector, _managed_units, _local_capture_size] call _fnc_liberateSector;
                    
                    // Remove this PFH
                    [_handle] call CBA_fnc_removePerFrameHandler;
                } else {
                    // Check for sector abandonment
                    if (([_sectorpos, (([_opforcount] call KPLIB_fnc_getSectorRange) + 300), GRLIB_side_friendly] call KPLIB_fnc_getUnitsCount) == 0) then {
                        _sector_despawn_tickets = _sector_despawn_tickets - 1;
                        _args set [5, _sector_despawn_tickets];
                    } else {
                        // Calculate additional despawn tickets based on time
                        private _runningMinutes = (floor ((time - _activationTime) / 60)) - ADDITIONAL_TICKETS_DELAY;
                        private _additionalTickets = (_runningMinutes * BASE_TICKETS);
                        
                        // Clamp from 0 to "_maximum_additional_tickets"
                        _additionalTickets = (_additionalTickets max 0) min _maximum_additional_tickets;
                        
                        private _newTickets = BASE_TICKETS + _additionalTickets;
                        _args set [5, _newTickets];
                    };
                    
                    // Check if sector should despawn
                    if (_sector_despawn_tickets <= 0) then {
                        diag_log format ["[KPLIB] Sector %1 despawning - processing %2 managed units", _sector, count _managed_units];
                        
                        // Log types of units being processed
                        private _unitTypes = [];
                        {
                            if (!isNull _x) then {
                                _unitTypes pushBack (typeOf _x);
                            } else {
                                _unitTypes pushBack "NULL_REFERENCE";
                            };
                        } forEach _managed_units;
                        diag_log format ["[KPLIB] Sector units to process: %1", _unitTypes];
                        
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
                        
                        // Remove from active sectors
                        active_sectors = active_sectors - [_sector]; 
                        publicVariable "active_sectors";
                        
                        // Remove this PFH
                        [_handle] call CBA_fnc_removePerFrameHandler;
                    };
                };
            }, SECTOR_TICK_TIME, [_sector, _sectorpos, _local_capture_size, _managed_units, _opforcount, 
                                 _sector_despawn_tickets, _activationTime, _fnc_liberateSector,
                                 _maximum_additional_tickets]] call CBA_fnc_addPerFrameHandler;
            
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
    
    [format ["Sector %1 (%2) deactivated - Was managed on: %3", (markerText _sector), _sector, debug_source], "SECTORSPAWN"] remoteExecCall ["KPLIB_fnc_log", 2];
    
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
    
}, [_sector]] call CBA_fnc_waitUntilAndExecute;
