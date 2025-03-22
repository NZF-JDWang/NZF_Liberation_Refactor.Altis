/*
    Function: manage_resources
    
    Description:
        Manages the production of resources at captured sectors.
        Periodically updates resource values and creates crates.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2023-10-15
*/

sectors_recalculating = false;
sectors_timer = false;
recalculate_sectors = false;

["Production management initialization started", "PRODUCTION"] call KPLIB_fnc_log;
["Production interval set to " + (str KP_liberation_production_interval) + " minutes", "PRODUCTION"] call KPLIB_fnc_log;

// Wait for save to load using CBA's waitUntilAndExecute
[
    {
        !isNil "save_is_loaded" && 
        !isNil "KP_liberation_production" && 
        save_is_loaded
    },
    {
        // Main production management logic
        ["Production management started", "PRODUCTION"] call KPLIB_fnc_log;
        
        // Initialize our production management PFH - checks regularly but only processes when triggered
        private _productionPFH = [{
            // Skip if recalculate_sectors is false
            if (!recalculate_sectors) exitWith {};
            recalculate_sectors = false;
            
            // Only proceed if there are players and production entries
            if (((count (allPlayers - entities "HeadlessClient_F")) > 0) && ((count KP_liberation_production) > 0)) then {
                // Don't run if already recalculating
                if (sectors_recalculating) exitWith {};
                sectors_recalculating = true;
                
                private _time_update = false;
                if (sectors_timer) then {
                    _time_update = true; 
                    sectors_timer = false;
                };
                
                private _start = diag_tickTime;
                if (KP_liberation_production_debug > 0) then {
                    [format ["Production interval started: %1 - _time_update: %2", diag_tickTime, _time_update], "PRODUCTION"] call KPLIB_fnc_log;
                };
                
                private _tempProduction = [];
                {
                    private _storageArray = [];
                    private _supplyValue = 0;
                    private _ammoValue = 0;
                    private _fuelValue = 0;
                    private _time = _x select 8;
                    
                    private _storage = nearestObjects [(markerPos (_x select 1)), [KP_liberation_small_storage_building], 100];
                    _storage = _storage select {(_x getVariable ["KP_liberation_storage_type",-1]) == 1};
                    
                    if ((count _storage) > 0) then {
                        _storage = (_storage select 0);
                        _storageArray = [(getPosATL _storage),(getDir _storage),(vectorUpVisual _storage)];
                        
                        if (_time_update) then {
                            // This is decremented once per minute
                            if ((_time - 1) < 1) then {
                                // When counter reaches 0, reset to the production interval (in minutes)
                                _time = KP_liberation_production_interval;
                                
                                if (((count (attachedObjects _storage)) < 12) && !((_x select 7) == 3)) then {
                                    private _crateType = KP_liberation_supply_crate;
                                    switch (_x select 7) do {
                                        case 1: {
                                            _crateType = KP_liberation_ammo_crate; 
                                            stats_ammo_produced = stats_ammo_produced + 100;
                                        };
                                        case 2: {
                                            _crateType = KP_liberation_fuel_crate; 
                                            stats_fuel_produced = stats_fuel_produced + 100;
                                        };
                                        default {
                                            _crateType = KP_liberation_supply_crate; 
                                            stats_supplies_produced = stats_supplies_produced + 100;
                                        };
                                    };
                                    
                                    if (KP_liberation_production_debug > 0) then {
                                        [format ["Creating crate at sector %1 - Timer reset to %2 minutes", markerText (_x select 1), KP_liberation_production_interval], "PRODUCTION"] call KPLIB_fnc_log;
                                    };
                                    
                                    private _crate = [_crateType, 100, getPosATL _storage] call KPLIB_fnc_createCrate;
                                    [_crate, _storage] call KPLIB_fnc_crateToStorage;
                                };
                            } else {
                                _time = _time - 1;
                                
                                if (KP_liberation_production_debug > 0) then {
                                    [format ["Sector %1 production timer: %2 minutes remaining", markerText (_x select 1), _time], "PRODUCTION"] call KPLIB_fnc_log;
                                };
                            };
                        };
                        
                        {
                            switch ((typeOf _x)) do {
                                case KP_liberation_supply_crate: {
                                    _supplyValue = _supplyValue + (_x getVariable ["KP_liberation_crate_value",0]);
                                };
                                case KP_liberation_ammo_crate: {
                                    _ammoValue = _ammoValue + (_x getVariable ["KP_liberation_crate_value",0]);
                                };
                                case KP_liberation_fuel_crate: {
                                    _fuelValue = _fuelValue + (_x getVariable ["KP_liberation_crate_value",0]);
                                };
                                default {
                                    [format ["Invalid object (%1) at storage area", (typeOf _x)], "ERROR"] call KPLIB_fnc_log;
                                };
                            };
                        } forEach (attachedObjects _storage);
                    };
                    
                    _tempProduction pushBack [
                        (markerText (_x select 1)),
                        (_x select 1),
                        (_x select 2),
                        _storageArray,
                        (_x select 4),
                        (_x select 5),
                        (_x select 6),
                        (_x select 7),
                        _time,
                        _supplyValue,
                        _ammoValue,
                        _fuelValue
                    ];
                    
                    if (KP_liberation_production_debug > 0) then {
                        [format ["Production Update: %1", _tempProduction select _forEachIndex], "PRODUCTION"] call KPLIB_fnc_log;
                    };
                } forEach KP_liberation_production;
                
                _tempProduction sort true;
                KP_liberation_production = +_tempProduction;
                
                sectors_recalculating = false;
                
                if (KP_liberation_production_debug > 0) then {
                    [format ["Production interval finished - Time needed: %1 seconds", diag_tickTime - _start], "PRODUCTION"] call KPLIB_fnc_log;
                };
            };
        }, 1, []] call CBA_fnc_addPerFrameHandler;
        
        // Add a PFH to manage the timer - triggers every 60 seconds (1 minute)
        // This replaces recalculate_timer_sector.sqf which did the same with uiSleep
        private _timerPFH = [{
            if (GRLIB_endgame == 0) then {
                // Set flags to update minute-based production timers
                sectors_timer = true;
                recalculate_sectors = true;
                
                if (KP_liberation_production_debug > 0) then {
                    ["Minute timer triggered - production timers updated", "PRODUCTION"] call KPLIB_fnc_log;
                };
            } else {
                // If the game has ended, remove both PFHs
                [_this select 1] call CBA_fnc_removePerFrameHandler;
                [_productionPFH] call CBA_fnc_removePerFrameHandler;
            };
        }, 60, []] call CBA_fnc_addPerFrameHandler;
    }
] call CBA_fnc_waitUntilAndExecute;
