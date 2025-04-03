if (isServer) then {
    params ["_liberated_sector"];

    private _combat_readiness_increase = 0;
    switch (true) do {
        case (_liberated_sector in sectors_bigtown):    {_combat_readiness_increase = floor (random 10) * GRLIB_difficulty_modifier;};
        case (_liberated_sector in sectors_capture):    {_combat_readiness_increase = floor (random 6) * GRLIB_difficulty_modifier;};
        case (_liberated_sector in sectors_military):   {_combat_readiness_increase = 5 + (floor (random 11)) * GRLIB_difficulty_modifier;};
        case (_liberated_sector in sectors_factory):    {_combat_readiness_increase = 3 + (floor (random 7)) * GRLIB_difficulty_modifier;};
        case (_liberated_sector in sectors_tower):      {_combat_readiness_increase = floor (random 4);};
    };

    combat_readiness = combat_readiness + _combat_readiness_increase;
    if (combat_readiness > 100.0 && GRLIB_difficulty_modifier <= 2.0) then {combat_readiness = 100.0};
    stats_readiness_earned = stats_readiness_earned + _combat_readiness_increase;

    [_liberated_sector, 0] remoteExecCall ["remote_call_sector"];
    blufor_sectors pushback _liberated_sector; publicVariable "blufor_sectors";
    stats_sectors_liberated = stats_sectors_liberated + 1;

    reset_battlegroups_ai = true; publicVariable "reset_battlegroups_ai";

    if (_liberated_sector in sectors_factory) then {
        {
            if (_liberated_sector in _x) exitWith {KP_liberation_production = KP_liberation_production - [_x];};
        } forEach KP_liberation_production;

        private _sectorFacilities = (KP_liberation_production_markers select {_liberated_sector == (_x select 0)}) select 0;
        KP_liberation_production pushBack [
            markerText _liberated_sector,
            _liberated_sector,
            1,
            [],
            _sectorFacilities select 1,
            _sectorFacilities select 2,
            _sectorFacilities select 3,
            3,
            KP_liberation_production_interval,
            0,
            0,
            0
        ];
    };

    [_liberated_sector] spawn F_cr_liberatedSector;

    if ((random 100) <= KP_liberation_cr_wounded_chance || (count blufor_sectors) == 1) then {
        [_liberated_sector] spawn civrep_wounded_civs;
    };

    asymm_blocked_sectors pushBack [_liberated_sector, time];
    publicVariable "asymm_blocked_sectors";

    // Log sector liberation
    diag_log format ["[KPLIB] Sector %1 has been liberated", _liberated_sector];

    // Update all sector markers using the centralized function
    {KPLIB_fsm_sectorMonitor setFSMVariable ["_availableSectors", sectors_available_markers, true]} remoteExec ["call", KPLIB_fsm_sectorMonitor getVariable "owner"];

    // Notify clients to update their markers
    [] remoteExecCall ["KPLIB_fnc_updateSectorMarkers", [0, -2] call CBA_fnc_players];

    // Check victory conditions in unscheduled space
    [] call check_victory_conditions;

    // Schedule save operation after a short delay
    [{
        [] spawn KPLIB_fnc_doSave;
        
        // Schedule battlegroup check after save completes
        [{
            params ["_liberated_sector"];
            
            if (GRLIB_endgame == 0) then {
                if (
                    !(_liberated_sector in sectors_tower)
                    && {
                        (random (150 / (GRLIB_difficulty_modifier * GRLIB_csat_aggressivity))) < (combat_readiness - 15)
                        || _liberated_sector in sectors_bigtown
                    }
                    && {[] call KPLIB_fnc_getOpforCap < GRLIB_battlegroup_cap}
                ) then {
                    [_liberated_sector, (random 100) < 45] spawn spawn_battlegroup;
                };
            };
        }, [_liberated_sector], 45] call CBA_fnc_waitAndExecute;
        
    }, [], 1] call CBA_fnc_waitAndExecute;
};
