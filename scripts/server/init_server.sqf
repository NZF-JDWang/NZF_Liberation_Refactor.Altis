// AI
add_civ_waypoints = compileFinal preprocessFileLineNumbers "scripts\server\ai\add_civ_waypoints.sqf";
add_defense_waypoints = compileFinal preprocessFileLineNumbers "scripts\server\ai\add_defense_waypoints.sqf";
// battlegroup_ai = compileFinal preprocessFileLineNumbers "scripts\server\ai\battlegroup_ai.sqf"; // Replaced by KPLIB_fnc_spawnBattlegroupAI
building_defence_ai = compileFinal preprocessFileLineNumbers "scripts\server\ai\building_defence_ai.sqf";
// patrol_ai = compileFinal preprocessFileLineNumbers "scripts\server\ai\patrol_ai.sqf"; // Replaced by KPLIB_fnc_patrolAI
prisonner_ai = compileFinal preprocessFileLineNumbers "scripts\server\ai\prisonner_ai.sqf";
// troup_transport = compileFinal preprocessFileLineNumbers "scripts\server\ai\troup_transport.sqf"; // Replaced by KPLIB_fnc_troopTransport

// Ensure sides are properly set as enemies (important for non-standard side configurations)
GRLIB_side_friendly setFriend [GRLIB_side_enemy, 0];
GRLIB_side_enemy setFriend [GRLIB_side_friendly, 0];

// Battlegroup
// spawn_air = compileFinal preprocessFileLineNumbers "scripts\server\battlegroup\spawn_air.sqf"; // Replaced by KPLIB_fnc_spawnAir
// spawn_battlegroup = compileFinal preprocessFileLineNumbers "scripts\server\battlegroup\spawn_battlegroup.sqf"; // Replaced by KPLIB_fnc_spawnBattlegroup

// Game
// check_victory_conditions = compileFinal preprocessFileLineNumbers "scripts\server\game\check_victory_conditions.sqf";

// Patrol
manage_one_civilian_patrol = compileFinal preprocessFileLineNumbers "scripts\server\patrols\manage_one_civilian_patrol.sqf";
// manage_one_patrol = compileFinal preprocessFileLineNumbers "scripts\server\patrols\manage_one_patrol.sqf"; // Replaced by KPLIB_fnc_manageOnePatrol


// Secondary objectives
fob_hunting = compileFinal preprocessFileLineNumbers "scripts\server\secondary\fob_hunting.sqf";
convoy_hijack = compileFinal preprocessFileLineNumbers "scripts\server\secondary\convoy_hijack.sqf";
search_and_rescue = compileFinal preprocessFileLineNumbers "scripts\server\secondary\search_and_rescue.sqf";

// Sector
// attack_in_progress_fob = compileFinal preprocessFileLineNumbers "scripts\server\sector\attack_in_progress_fob.sqf"; // Replaced by KPLIB_fnc_attackInProgressFOB
ied_manager = compileFinal preprocessFileLineNumbers "scripts\server\sector\ied_manager.sqf";
manage_one_sector = compileFinal preprocessFileLineNumbers "scripts\server\sector\manage_one_sector.sqf";
wait_to_spawn_sector = compileFinal preprocessFileLineNumbers "scripts\server\sector\wait_to_spawn_sector.sqf";

// Compile replacement validation functions
KPLIB_fnc_validateSectorCapture = compileFinal preprocessFileLineNumbers "functions\fn_validateSectorCapture.sqf";
KPLIB_fnc_validateFOBPlacement = compileFinal preprocessFileLineNumbers "functions\fn_validateFOBPlacement.sqf";

// Load admin commands
[] call compileFinal preprocessFileLineNumbers "scripts\server\game\admin_commands.sqf";

addMissionEventHandler ["BuildingChanged", {_this spawn kill_manager}];

// Globals
active_sectors = []; publicVariable "active_sectors";

// Provide backwards compatibility for old script calls
battlegroup_ai = {[_this select 0] call KPLIB_fnc_spawnBattlegroupAI};
spawn_battlegroup = {[_this select 0, _this select 1] call KPLIB_fnc_spawnBattlegroup};
spawn_air = {[_this select 0] call KPLIB_fnc_spawnAir};
troup_transport = {[_this select 0] call KPLIB_fnc_troopTransport};

execVM "scripts\server\base\startgame.sqf";
execVM "scripts\server\base\huron_manager.sqf";
execVM "scripts\server\base\startvehicle_spawn.sqf";
[] call KPLIB_fnc_createSuppModules;
// execVM "scripts\server\battlegroup\counter_battlegroup.sqf"; // Replaced by KPLIB_fnc_counterBattlegroup
// execVM "scripts\server\battlegroup\random_battlegroups.sqf"; // Replaced by KPLIB_fnc_randomBattlegroups
// execVM "scripts\server\battlegroup\readiness_increase.sqf"; // Replaced by KPLIB_fnc_readinessIncrease
[] call KPLIB_fnc_counterBattlegroup;
[] call KPLIB_fnc_randomBattlegroups;
[] call KPLIB_fnc_readinessIncrease;
execVM "scripts\server\game\apply_default_permissions.sqf";
execVM "scripts\server\game\cleanup_vehicles.sqf";
if (!KP_liberation_fog_param) then {execVM "scripts\server\game\fucking_set_fog.sqf";};
execVM "scripts\server\game\manage_time.sqf";
execVM "scripts\server\game\manage_weather.sqf";
execVM "scripts\server\game\playtime.sqf";
// execVM "scripts\server\game\check_victory_conditions.sqf";
[] call KPLIB_fnc_checkVictoryConditions;
[] call KPLIB_fnc_saveManager;
execVM "scripts\server\game\spawn_radio_towers.sqf";
// execVM "scripts\server\game\synchronise_vars.sqf"; // Replaced with function call
[] call KPLIB_fnc_synchroniseVars;
execVM "scripts\server\game\synchronise_eco.sqf";
execVM "scripts\server\game\zeus_synchro.sqf";
execVM "scripts\server\offloading\show_fps.sqf";
execVM "scripts\server\patrols\civilian_patrols.sqf";
[] call KPLIB_fnc_managePatrols;
[] call KPLIB_fnc_reinforcementsResetter;
execVM "scripts\server\resources\manage_resources.sqf";
execVM "scripts\server\resources\recalculate_resources.sqf";
execVM "scripts\server\resources\recalculate_timer.sqf";
execVM "scripts\server\resources\unit_cap.sqf";
[] call KPLIB_fnc_monitorSectors;

// Start Sector Monitor FSM *after* startgame.sqf and save manager are ready
[{
    (!isNil "KPLIB_startgame_complete" && {KPLIB_startgame_complete}) && 
    (!isNil "KPLIB_saveManager_ready" && {KPLIB_saveManager_ready})
}, {
    ["Starting Sector Monitor FSM after startgame and save manager ready", "INIT"] call KPLIB_fnc_log;
    KPLIB_fsm_sectorMonitor = [] call KPLIB_fnc_sectorMonitor;
}, []] call CBA_fnc_waitUntilAndExecute;

// KPLIB_fsm_sectorMonitor = [] call KPLIB_fnc_sectorMonitor; // Original direct call commented out
if (KP_liberation_high_command) then {KPLIB_fsm_highcommand = [] call KPLIB_fnc_highcommand;};

// Select FOB templates
switch (KP_liberation_preset_opfor) do {
    case 1: {
        KPLIB_fob_templates = [
            "scripts\fob_templates\apex\template1.sqf",
            "scripts\fob_templates\apex\template2.sqf",
            "scripts\fob_templates\apex\template3.sqf",
            "scripts\fob_templates\apex\template4.sqf",
            "scripts\fob_templates\apex\template5.sqf"
        ];
    };
    case 12: {
        KPLIB_fob_templates = [
            "scripts\fob_templates\unsung\template1.sqf",
            "scripts\fob_templates\unsung\template2.sqf",
            "scripts\fob_templates\unsung\template3.sqf",
            "scripts\fob_templates\unsung\template4.sqf",
            "scripts\fob_templates\unsung\template5.sqf"
        ];
    };
    default {
        KPLIB_fob_templates = [
            "scripts\fob_templates\default\template1.sqf",
            "scripts\fob_templates\default\template2.sqf",
            "scripts\fob_templates\default\template3.sqf",
            "scripts\fob_templates\default\template4.sqf",
            "scripts\fob_templates\default\template5.sqf",
            "scripts\fob_templates\default\template6.sqf",
            "scripts\fob_templates\default\template7.sqf",
            "scripts\fob_templates\default\template8.sqf",
            "scripts\fob_templates\default\template9.sqf",
            "scripts\fob_templates\default\template10.sqf"
        ];
    };
};

// Civil Reputation
execVM "scripts\server\civrep\init_module.sqf";

// Civil Informant
execVM "scripts\server\civinformant\init_module.sqf";

// Asymmetric Threats
execVM "scripts\server\asymmetric\init_module.sqf";

// Groupcheck for deletion when empty
execVM "scripts\server\offloading\group_diag.sqf";

{
    if ((_x != player) && (_x distance (markerPos GRLIB_respawn_marker) < 200 )) then {
        deleteVehicle _x;
    };
} forEach allUnits;

// Server Restart Script from K4s0
if (KP_liberation_restart > 0) then {
    execVM "scripts\server\game\server_restart.sqf";
};

// Initialize sector marker colors at mission start 
// Start with all sectors grey with low alpha
{
    _x setMarkerColor "ColorGrey";
    _x setMarkerAlpha 0.4;
} forEach sectors_allSectors;

// Set blufor sectors to their designated color
{
    _x setMarkerColor GRLIB_color_friendly;
    _x setMarkerAlpha 1;
} forEach blufor_sectors;

// Initial call removed - now handled by init_client.sqf for each joining player
// [] call KPLIB_fnc_updateSectorMarkers;
