/*
    Function: kill_manager
    
    Description:
        Handles all aspects of unit or vehicle destruction including statistics tracking,
        combat readiness adjustments, player death handling and body/wreck cleanup.
        
        This function has been updated to use CBA's non-blocking functions and should be
        called directly rather than spawned.
    
    Parameters:
        _unit - The unit or vehicle that was killed [OBJECT]
        _killer - The unit that caused the kill [OBJECT]
    
    Example:
        Event Handler:
        unit addMPEventHandler ["MPKilled", {[{_this call kill_manager}, _this] call CBA_fnc_directCall}];
    
    Returns:
        Nothing
    
    Author: [NZF] JD Wang
    Date: 2023-10-15
*/

params ["_unit", "_killer"];

// Local function to process kills on server - reduces code duplication
private _fnc_processKill = {
    params ["_unit", "_killer"];
    
    // Failsafe if something gets killed before the save manager is finished
    if (isNil "infantry_weight") then {infantry_weight = 33};
    if (isNil "armor_weight") then {armor_weight = 33};
    if (isNil "air_weight") then {air_weight = 33};

    // BLUFOR Killer handling
    if ((side _killer) == GRLIB_side_friendly) then {
        // Increase combat readiness for kills near a capital
        private _nearby_bigtown = sectors_bigtown select {!(_x in blufor_sectors) && (_unit distance (markerpos _x) < 250)};
        if (count _nearby_bigtown > 0) then {
            combat_readiness = combat_readiness + (0.5 * GRLIB_difficulty_modifier);
            stats_readiness_earned = stats_readiness_earned + (0.5 * GRLIB_difficulty_modifier);
            if (combat_readiness > 100.0 && GRLIB_difficulty_modifier < 2) then {combat_readiness = 100.0};
        };

        // Weights adjustments depending on what vehicle the BLUFOR killer used
        if (_killer isKindOf "Man") then {
            infantry_weight = infantry_weight + 1;
            armor_weight = armor_weight - 0.66;
            air_weight = air_weight - 0.66;
        } else {
            if ((toLower (typeOf (vehicle _killer))) in KPLIB_allLandVeh_classes) then {
                infantry_weight = infantry_weight - 0.66;
                armor_weight = armor_weight + 1;
                air_weight = air_weight - 0.66;
            };
            if ((toLower (typeOf (vehicle _killer))) in KPLIB_allAirVeh_classes) then {
                infantry_weight = infantry_weight - 0.66;
                armor_weight = armor_weight - 0.66;
                air_weight = air_weight + 1;
            };
        };

        // Keep within ranges
        infantry_weight = 0 max (infantry_weight min 100);
        armor_weight = 0 max (armor_weight min 100);
        air_weight = 0 max (air_weight min 100);
    };

    // Player was killed
    if (isPlayer _unit) then {
        stats_player_deaths = stats_player_deaths + 1;
        // Disconnect UAV from player on death
        _unit connectTerminalToUAV objNull;
        // Eject Player from vehicle
        if (vehicle _unit != _unit) then {moveOut _unit};
    };

    // Check for Man or Vehicle
    if (_unit isKindOf "Man") then {
        // OPFOR casualty
        if (side (group _unit) == GRLIB_side_enemy) then {
            // Killed by BLUFOR
            if (side _killer == GRLIB_side_friendly) then {
                stats_opfor_soldiers_killed = stats_opfor_soldiers_killed + 1;
            };

            // Killed by a player
            if (isplayer _killer) then {
                stats_opfor_killed_by_players = stats_opfor_killed_by_players + 1;
            };
        };

        // BLUFOR casualty
        if (side (group _unit) == GRLIB_side_friendly) then {
            stats_blufor_soldiers_killed = stats_blufor_soldiers_killed + 1;

            // Killed by BLUFOR
            if (side _killer == GRLIB_side_friendly) then {
                stats_blufor_teamkills = stats_blufor_teamkills + 1;
            };
        };

        // Resistance casualty
        if (side (group _unit) == GRLIB_side_resistance) then {
            KP_liberation_guerilla_strength = KP_liberation_guerilla_strength - 1;
            stats_resistance_killed = stats_resistance_killed + 1;

            // Resistance is friendly to BLUFOR
            if ((GRLIB_side_friendly getFriend GRLIB_side_resistance) >= 0.6) then {
                // Killed by BLUFOR
                if (side _killer == GRLIB_side_friendly) then {
                    if (KP_liberation_asymmetric_debug > 0) then {
                        [format ["Guerilla unit killed by: %1", name _killer], "ASYMMETRIC"] call KPLIB_fnc_log;
                    };
                    [3, [(name _unit)]] remoteExec ["KPLIB_fnc_crGlobalMsg"];
                    stats_resistance_teamkills = stats_resistance_teamkills + 1;
                    
                    // Apply CR penalty
                    [
                        {
                            params ["_penalty"];
                            [_penalty, true] call F_cr_changeCR;
                        },
                        [KP_liberation_cr_resistance_penalty],
                        0.1
                    ] call CBA_fnc_waitAndExecute;
                };

                // Killed by a player
                if (isplayer _killer) then {
                    stats_resistance_teamkills_by_players = stats_resistance_teamkills_by_players + 1;
                };
            };
        };

        // Civilian casualty
        if (side (group _unit) == GRLIB_side_civilian) then {
            stats_civilians_killed = stats_civilians_killed + 1;

            // Killed by BLUFOR
            if (side _killer == GRLIB_side_friendly) then {
                if (KP_liberation_civrep_debug > 0) then {
                    [format ["Civilian killed by: %1", name _killer], "CIVREP"] call KPLIB_fnc_log;
                };
                [2, [(name _unit)]] remoteExec ["KPLIB_fnc_crGlobalMsg"];
                
                // Apply CR penalty
                [
                    {
                        params ["_penalty"];
                        [_penalty, true] call F_cr_changeCR;
                    },
                    [KP_liberation_cr_kill_penalty],
                    0.1
                ] call CBA_fnc_waitAndExecute;
            };

            // Killed by a player
            if (isPlayer _killer) then {
                stats_civilians_killed_by_players = stats_civilians_killed_by_players + 1;
            };
        };
    } else {
        // Enemy vehicle casualty
        if ((toLower (typeof _unit)) in KPLIB_o_allVeh_classes) then {
            stats_opfor_vehicles_killed = stats_opfor_vehicles_killed + 1;

            // Destroyed by player
            if (isplayer _killer) then {
                stats_opfor_vehicles_killed_by_players = stats_opfor_vehicles_killed_by_players + 1;
            };
        } else {
            // Civilian vehicle casualty
            if (typeOf _unit in civilian_vehicles) then {
                stats_civilian_vehicles_killed = stats_civilian_vehicles_killed + 1;

                // Destroyed by player
                if (isplayer _killer) then {
                    stats_civilian_vehicles_killed_by_players = stats_civilian_vehicles_killed_by_players + 1;
                };
            } else {
                // It has to be a BLUFOR vehicle then
                stats_blufor_vehicles_killed = stats_blufor_vehicles_killed + 1;
            };
        };
    };
};

if (isServer) then {
    if (KP_liberation_kill_debug > 0) then {
        [format ["Kill Manager executed - _unit: %1 (%2) - _killer: %3 (%4)", typeOf _unit, _unit, typeOf _killer, _killer], "KILL"] call KPLIB_fnc_log;
    };

    // Handle kill processing using ACE lastDamageSource if available
    if (local _unit) then {
        if (KP_liberation_kill_debug > 0) then {
            ["_unit is local to server", "KILL"] call KPLIB_fnc_log;
        };
        
        // Get actual killer from ACE medical
        private _actualKiller = _unit getVariable ["ace_medical_lastDamageSource", _killer];
        
        // Process the kill 
        [_unit, _actualKiller] call _fnc_processKill;
    } else {
        if (KP_liberation_kill_debug > 0) then {
            ["_unit is not local to server", "KILL"] call KPLIB_fnc_log;
        };
        
        // Initialize ACE killer variable if needed
        if (isNil "KP_liberation_ace_killer") then {
            KP_liberation_ace_killer = objNull;
        };
        
        // Wait for ACE killer data using CBA non-blocking function
        [
            {
                params ["_unit", "_killer", "_fnc_processKill"];
                
                if (KP_liberation_kill_debug > 0) then {
                    ["KP_liberation_ace_killer received on server", "KILL"] call KPLIB_fnc_log;
                };
                
                // Get the actual killer from the public variable
                private _actualKiller = KP_liberation_ace_killer;
                KP_liberation_ace_killer = objNull;
                publicVariable "KP_liberation_ace_killer";
                
                // Process the kill with the ACE-provided killer
                [_unit, _actualKiller] call _fnc_processKill;
            },
            {!(isNull KP_liberation_ace_killer)},
            [_unit, _killer, _fnc_processKill],
            30,
            {
                // Timeout handler - if we don't get the killer data within 30 seconds
                params ["_unit", "_killer", "_fnc_processKill"];
                
                // Process the kill with the original killer if ACE data not available
                [_unit, _killer] call _fnc_processKill;
            }
        ] call CBA_fnc_waitUntilAndExecute;
    };
} else {
    // Client-side: Send killer data to server via public variable
    if (local _unit) then {
        if (KP_liberation_kill_debug > 0) then {
            [format ["_unit is local to: %1", debug_source], "KILL"] remoteExecCall ["KPLIB_fnc_log", 2];
        };
        KP_liberation_ace_killer = _unit getVariable ["ace_medical_lastDamageSource", _killer];
        publicVariable "KP_liberation_ace_killer";
    };
};

// Body/Wreck deletion after cleanup delay - using CBA_fnc_waitAndExecute for better performance
if (isServer && !isPlayer _unit) then {
    [
        {
            params ["_unit"];
            hideBody _unit;
            
            [
                {
                    params ["_unit"];
                    deleteVehicle _unit;
                },
                [_unit],
                10
            ] call CBA_fnc_waitAndExecute;
        },
        [_unit],
        GRLIB_cleanup_delay
    ] call CBA_fnc_waitAndExecute;
};
