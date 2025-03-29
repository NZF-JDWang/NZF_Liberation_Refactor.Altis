/*
    File: fn_spawnGuerillaGroup.sqf
    Author: KP Liberation Dev Team - https://github.com/KillahPotatoes
    Date: 2017-10-08
    Last Update: 2020-04-05
    License: MIT License - http://www.opensource.org/licenses/MIT

    Description:
        Spawns a group of guerilla units with random gear depending on guerilla strength.

    Parameter(s):
        _pos    - Position where to spawn the group                             [POSITION, defaults to [0, 0, 0]]
        _amount - Amount of units for the group. 0 for automatic calculation    [NUMBER, defaults to 0]

    Returns:
        Spawned group [GROUP]
*/

params [
    ["_pos", [0, 0, 0], []],
    ["_amount", 0, []]
];

// Get tier and civilian reputation depending values
private _tier = [] call KPLIB_fnc_getResistanceTier;
private _cr_multi = [] call KPLIB_fnc_crGetMulti;
if (_amount == 0) then {_amount = (6 + (round (random _cr_multi)) + (round (random _tier)));};
private _weapons = missionNamespace getVariable ("KP_liberation_guerilla_weapons_" + str _tier);
private _uniforms = missionNamespace getVariable ("KP_liberation_guerilla_uniforms_" + str _tier);
private _vests = missionNamespace getVariable ("KP_liberation_guerilla_vests_" + str _tier);
private _headgear = missionNamespace getVariable ("KP_liberation_guerilla_headgear_" + str _tier);

// Spawn guerilla units
private _grp = createGroup [GRLIB_side_resistance, true];
private _unit = objNull;
private _weapon = [];
for "_i" from 1 to _amount do {
    // Create unit
    _unit = [selectRandom KP_liberation_guerilla_units, _pos, _grp, "PRIVATE", 5] call KPLIB_fnc_createManagedUnit;

    // Clear inventory
    removeAllWeapons _unit;
    removeAllItems _unit;
    removeAllAssignedItems _unit;
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;

    // Add uniform etc.
    _unit forceAddUniform (selectRandom _uniforms);
    _unit addItemToUniform "FirstAidKit";
    _unit addItemToUniform "MiniGrenade";
    _unit addVest (selectRandom _vests);
    _unit addHeadgear (selectRandom _headgear);
    if (_tier > 1) then {_unit addGoggles (selectRandom KP_liberation_guerilla_facegear);};

    // Add standard items
    _unit linkItem "ItemMap";
    _unit linkItem "ItemCompass";
    _unit linkItem "ItemWatch";
    _unit linkItem "ItemRadio";

    // Add weapon
    _weapon = selectRandom _weapons;
    _unit addWeapon (_weapon select 0);
    for "_i" from 1 to (_weapon select 2) do {_unit addItemToVest (_weapon select 1);};
    _unit addPrimaryWeaponItem (_weapon select 3);
    _unit addPrimaryWeaponItem (_weapon select 4);

    // Add possible RPG launcher
    if ((_tier > 1) && ((random 100) <= KP_liberation_resistance_at_chance)) then {
        _unit addBackpack "B_FieldPack_cbr";
        for "_i" from 1 to 3 do {_unit addItemToBackpack "RPG7_F";};
        _unit addWeapon "launch_RPG7_F";
    };
};

// Make units follow the leader
{_x doFollow (leader _grp)} forEach (units _grp);

// Apply LAMBS waypoints if available
if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
    [_grp] call lambs_wp_fnc_taskReset;
    
    // Use a search radius based on tier
    private _searchRadius = 150 + (50 * _tier);
    
    // Determine AI behavior based on weighted choice
    private _behaviorChoice = selectRandomWeighted [
        "hunt", 0.4,    // 40% chance for hunt - aggressive behavior
        "patrol", 0.3,  // 30% chance for patrol
        "camp", 0.2,    // 20% chance for camp - ambush-like behavior
        "rush", 0.1     // 10% chance for rush - very aggressive
    ];
    
    switch (_behaviorChoice) do {
        case "hunt": {
            // Hunt behavior - actively search for enemies
            [_grp, _pos, _searchRadius] call lambs_wp_fnc_taskHunt;
            [format ["Guerilla group using LAMBS taskHunt at %1 with radius %2", _pos, _searchRadius], "INFO"] call KPLIB_fnc_log;
        };
        case "patrol": {
            // Patrol behavior
            [_grp, getPos (leader _grp), _searchRadius] call lambs_wp_fnc_taskPatrol;
            [format ["Guerilla group using LAMBS taskPatrol at %1 with radius %2", _pos, _searchRadius], "INFO"] call KPLIB_fnc_log;
        };
        case "camp": {
            // Camp behavior - set up ambush
            [_grp, _pos, [], 50, true, true, true, true, true] call lambs_wp_fnc_taskCamp;
            [format ["Guerilla group using LAMBS taskCamp at %1", _pos], "INFO"] call KPLIB_fnc_log;
        };
        case "rush": {
            // Rush behavior - very aggressive
            [_grp, _pos, _searchRadius] call lambs_wp_fnc_taskRush;
            [format ["Guerilla group using LAMBS taskRush at %1 with radius %2", _pos, _searchRadius], "INFO"] call KPLIB_fnc_log;
        };
    };
    
    // Add a small delay before transferring to headless client
    // This ensures the waypoints are fully processed by the server
    [
        {
            params ["_group"];
            // Additional check to ensure units are actively following waypoints
            {
                _x doFollow (leader _group);
                _x setUnitPos "AUTO";
            } forEach (units _group);
            
            // Only transfer to HC if the group still exists
            if (!isNull _group) then {
                // Transfer to headless client after waypoints are established
                [_group] call KPLIB_fnc_transferGroupToHC;
            };
        },
        [_grp],
        1.0  // 1 second delay before HC transfer
    ] call CBA_fnc_waitAndExecute;
} else {
    // If no LAMBS, transfer immediately
    [_grp] call KPLIB_fnc_transferGroupToHC;
};

_grp
