/*
    Function: KPLIB_fnc_checkVictoryConditions
    
    Description:
        Checks victory conditions and ends the mission when all sectors are liberated.
        Displays mission statistics and handles cleanup.
    
    Parameters:
        None
    
    Returns:
        Nothing
    
    Example:
        (begin example)
        [] call KPLIB_fnc_checkVictoryConditions
        (end)
    
    Author: [NZF] JD Wang
    Date: 2024-10-29
*/

// Wait until save is fully loaded before starting victory condition checks
[{
    // Check if save is fully loaded
    if (!isNil "save_is_loaded" && {save_is_loaded}) then {
        // Start the victory condition check process
        ["Victory condition checks starting - save is loaded", "VICTORY"] call KPLIB_fnc_log;
        [{
            // First check victory conditions with additional safety check
            if (([] call KP_liberation_victoryCheck) && {GRLIB_endgame != 1}) then {
                ["Victory conditions met - initiating mission end sequence", "VICTORY"] call KPLIB_fnc_log;
                
                // Force a save before ending the game to ensure no data loss
                if (!isNil "KPLIB_fnc_doSave") then {
                    ["Performing final save before ending mission", "VICTORY"] call KPLIB_fnc_log;
                    [] call KPLIB_fnc_doSave;
                    sleep 2; // Brief delay to ensure save completes
                };
                
                GRLIB_endgame = 1;
                publicVariable "GRLIB_endgame";
                
                ["GRLIB_endgame flag set to 1", "VICTORY"] call KPLIB_fnc_log;
                {_x allowDamage false; (vehicle _x) allowDamage false;} forEach allPlayers;

                private _rabbits = round (random 75) + round (random 80);

                publicstats = [];
                publicstats pushback stats_ammo_produced;
                publicstats pushback stats_ammo_spent;
                publicstats pushback stats_blufor_soldiers_killed;
                publicstats pushback stats_blufor_soldiers_recruited;
                publicstats pushback stats_blufor_teamkills;
                publicstats pushback stats_blufor_vehicles_built;
                publicstats pushback stats_blufor_vehicles_killed;
                publicstats pushback stats_civilian_buildings_destroyed;
                publicstats pushback stats_civilian_vehicles_killed;
                publicstats pushback stats_civilian_vehicles_killed_by_players;
                publicstats pushback stats_civilian_vehicles_seized;
                publicstats pushback stats_civilians_healed;
                publicstats pushback stats_civilians_killed;
                publicstats pushback stats_civilians_killed_by_players;
                publicstats pushback stats_fobs_built;
                publicstats pushback stats_fobs_lost;
                publicstats pushback stats_fuel_produced;
                publicstats pushback stats_fuel_spent;
                publicstats pushback stats_hostile_battlegroups;
                publicstats pushback stats_ieds_detonated;
                publicstats pushback stats_opfor_killed_by_players;
                publicstats pushback stats_opfor_soldiers_killed;
                publicstats pushback stats_opfor_vehicles_killed;
                publicstats pushback stats_opfor_vehicles_killed_by_players;
                publicstats pushback stats_player_deaths;
                publicstats pushback stats_playtime;
                publicstats pushback stats_prisoners_captured;
                publicstats pushback stats_readiness_earned;
                publicstats pushback stats_reinforcements_called;
                publicstats pushback stats_resistance_killed;
                publicstats pushback stats_resistance_teamkills;
                publicstats pushback stats_resistance_teamkills_by_players;
                publicstats pushback stats_secondary_objectives;
                publicstats pushback stats_sectors_liberated;
                publicstats pushback stats_sectors_lost;
                publicstats pushback stats_spartan_respawns;
                publicstats pushback stats_supplies_produced;
                publicstats pushback stats_supplies_spent;
                publicstats pushback stats_vehicles_recycled;
                publicstats pushback _rabbits;

                publicstats remoteExec ["remote_call_endgame"];
                ["End game statistics sent to all clients", "VICTORY"] call KPLIB_fnc_log;

                private _playtime_days = floor (stats_playtime / 86400);
                private _playtime_hours = floor ((stats_playtime % 86400) / 3600);
                private _playtime_minutes = floor ((stats_playtime % 3600) / 60);
                private _playtime_seconds = stats_playtime % 60;

                ["------------------------------------", "MISSION END"] call KPLIB_fnc_log;
                [format ["Playtime: %1 days, %2 hours, %3 minutes, %4 seconds", _playtime_days, _playtime_hours, _playtime_minutes, _playtime_seconds], "MISSION END"] call KPLIB_fnc_log;
                [format ["OPFOR infantry killed: %1", stats_opfor_soldiers_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["OPFOR infantry killed by players: %1", stats_opfor_killed_by_players], "MISSION END"] call KPLIB_fnc_log;
                [format ["OPFOR vehicles destroyed: %1", stats_opfor_vehicles_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["OPFOR vehicles destroyed by players: %1", stats_opfor_vehicles_killed_by_players], "MISSION END"] call KPLIB_fnc_log;
                [format ["BLUFOR infantry recruited: %1", stats_blufor_soldiers_recruited], "MISSION END"] call KPLIB_fnc_log;
                [format ["BLUFOR infantry killed: %1", stats_blufor_soldiers_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["BLUFOR vehicles built: %1", stats_blufor_vehicles_built], "MISSION END"] call KPLIB_fnc_log;
                [format ["BLUFOR vehicles destroyed: %1", stats_blufor_vehicles_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Player deaths: %1", stats_player_deaths], "MISSION END"] call KPLIB_fnc_log;
                [format ["BLUFOR friendly fire incidents: %1", stats_blufor_teamkills], "MISSION END"] call KPLIB_fnc_log;
                [format ["Resistance fighters killed: %1", stats_resistance_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Resistance fighters (friendly) killed: %1", stats_resistance_teamkills], "MISSION END"] call KPLIB_fnc_log;
                [format ["Resistance fighters (friendly) killed by players: %1", stats_resistance_teamkills_by_players], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilians killed: %1", stats_civilians_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilians killed by players: %1", stats_civilians_killed_by_players], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilians healed: %1", stats_civilians_healed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilian vehicles destroyed: %1", stats_civilian_vehicles_killed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilian vehicles destroyed by players: %1", stats_civilian_vehicles_killed_by_players], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilian vehicles seized: %1", stats_civilian_vehicles_seized], "MISSION END"] call KPLIB_fnc_log;
                [format ["Civilian buildings destroyed: %1", stats_civilian_buildings_destroyed], "MISSION END"] call KPLIB_fnc_log;
                [format ["Vehicles recycled: %1", stats_vehicles_recycled], "MISSION END"] call KPLIB_fnc_log;
                [format ["Ammunition units produced: %1", stats_ammo_produced], "MISSION END"] call KPLIB_fnc_log;
                [format ["Ammunition units spent: %1", stats_ammo_spent], "MISSION END"] call KPLIB_fnc_log;
                [format ["Fuel units produced: %1", stats_fuel_produced], "MISSION END"] call KPLIB_fnc_log;
                [format ["Fuel units spent: %1", stats_fuel_spent], "MISSION END"] call KPLIB_fnc_log;
                [format ["Supply units produced: %1", stats_supplies_produced], "MISSION END"] call KPLIB_fnc_log;
                [format ["Supply units spent: %1", stats_supplies_spent], "MISSION END"] call KPLIB_fnc_log;
                [format ["Sectors liberated: %1", stats_sectors_liberated], "MISSION END"] call KPLIB_fnc_log;
                [format ["Sectors lost: %1", stats_sectors_lost], "MISSION END"] call KPLIB_fnc_log;
                [format ["FOBs built: %1", stats_fobs_built], "MISSION END"] call KPLIB_fnc_log;
                [format ["FOBs lost: %1", stats_fobs_lost], "MISSION END"] call KPLIB_fnc_log;
                [format ["Secondary objectives accomplished: %1", stats_secondary_objectives], "MISSION END"] call KPLIB_fnc_log;
                [format ["Prisoners captured: %1", stats_prisoners_captured], "MISSION END"] call KPLIB_fnc_log;
                [format ["Hostile battlegroups called: %1", stats_hostile_battlegroups], "MISSION END"] call KPLIB_fnc_log;
                [format ["Hostile reinforcements called: %1", stats_reinforcements_called], "MISSION END"] call KPLIB_fnc_log;
                [format ["Total combat readiness raised: %1", round stats_readiness_earned], "MISSION END"] call KPLIB_fnc_log;
                [format ["IEDs detonated: %1", stats_ieds_detonated], "MISSION END"] call KPLIB_fnc_log;
                [format ["Number of SPARTAN 6 losses: %1", stats_spartan_respawns], "MISSION END"] call KPLIB_fnc_log;
                [format ["Rabbits killed: %1", _rabbits], "MISSION END"] call KPLIB_fnc_log;
                ["------------------------------------", "MISSION END"] call KPLIB_fnc_log;

                // Schedule final cleanup after a delay using CBA
                [{
                    ["Performing final cleanup of AI units", "VICTORY"] call KPLIB_fnc_log;
                    {if !(isPlayer _x) then {deleteVehicle _x;}} forEach allUnits;
                }, [], 20] call CBA_fnc_waitAndExecute;
            } else {
                // Only for debug
                if (KP_liberation_savegame_debug > 0) then {
                    ["Victory conditions not met, continuing checks", "VICTORY"] call KPLIB_fnc_log;
                };
            };
            
            // Continue checking victory conditions in a non-blocking way if game not ended
            if (GRLIB_endgame != 1) then {
                [KPLIB_fnc_checkVictoryConditions, [], 5] call CBA_fnc_waitAndExecute;
            } else {
                ["Victory check loop terminated - game ended", "VICTORY"] call KPLIB_fnc_log;
            };
        }, [], 5] call CBA_fnc_waitAndExecute;
    } else {
        // Save not loaded yet, check again in 3 seconds
        ["Waiting for save to load before starting victory condition checks", "VICTORY"] call KPLIB_fnc_log;
        [_this select 0, [], 3] call CBA_fnc_waitAndExecute;
    };
}, [], 3] call CBA_fnc_waitAndExecute; 