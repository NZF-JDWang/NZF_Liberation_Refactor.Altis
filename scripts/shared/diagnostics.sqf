private _source = "Server";

["------------------------------------", "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Name: %1", (localize "STR_MISSION_TITLE")], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["World: %1", worldName], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Version: %1", (localize "STR_MISSION_VERSION")], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Author: %1", [missionConfigFile] call BIS_fnc_overviewAuthor], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Blufor: %1", KP_liberation_preset_blufor], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Opfor: %1", KP_liberation_preset_opfor], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Resistance: %1", KP_liberation_preset_resistance], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Civilians: %1", KP_liberation_preset_civilians], "MISSIONSTART"] call KPLIB_fnc_log;
[format ["Arsenal: %1", KP_liberation_arsenal], "MISSIONSTART"] call KPLIB_fnc_log;
["------------------------------------", "MISSIONSTART"] call KPLIB_fnc_log;

// Wait until active_sectors is defined, then start diagnostics PFH
[
    {
        !isNil "active_sectors"
    },
    {
        // Start the diagnostics PFH with fixed delay of 120 seconds
        [
            {
                // Log server stats
                [
                    format [
                        "Server - FPS: %1 - Players: %2 - Local groups: %3 - Local units: %4 - Active Sectors: %5 - Active Scripts: [spawn: %6, execVM: %7, exec: %8, execFSM: %9]",
                        ((round (diag_fps * 100.0)) / 100.0),
                        count allPlayers,
                        {local _x} count allGroups,
                        {local _x} count allUnits,
                        count active_sectors,
                        diag_activeScripts select 0,
                        diag_activeScripts select 1,
                        diag_activeScripts select 2,
                        diag_activeScripts select 3
                    ],
                    "STATS"
                ] call KPLIB_fnc_log;
            },
            120,
            []
        ] call CBA_fnc_addPerFrameHandler;
    }
] call CBA_fnc_waitUntilAndExecute;
