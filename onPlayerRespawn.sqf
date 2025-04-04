waitUntil {!isNil "KPLIB_initServer"};

params ["_newUnit", "_oldUnit"];

build_confirmed = 0; // Initialize build status

// Ensure player namespace variables are calculated at least once before adding actions
if (!isNull player) then { // Safety check
    // Call the full namespace update
    [] call KPLIB_fnc_updatePlayerNamespace;
    
    // Additional direct check for startbase proximity to force the variable
    if (!isNil "startbase") then {
        private _isNearStart = (player distance2d startbase) < 200;
        player setVariable ["KPLIB_isNearStart", _isNearStart];
        diag_log format ["[KPLIB] [DIAGNOSTIC] onPlayerRespawn - Directly setting KPLIB_isNearStart: %1 (distance: %2)", _isNearStart, player distance2d startbase];
    } else {
        diag_log "[KPLIB] [DIAGNOSTIC] onPlayerRespawn - WARNING: startbase is nil during respawn!";
    };
};

if (isNil "GRLIB_respawn_loadout") then {
    removeAllWeapons player;
    removeAllItems player;
    removeAllAssignedItems player;
    removeVest player;
    removeBackpack player;
    removeHeadgear player;
    removeGoggles player;
    player linkItem "ItemMap";
    player linkItem "ItemCompass";
    player linkItem "ItemWatch";
    player linkItem "ItemRadio";
} else {
    sleep 4;
    [player, GRLIB_respawn_loadout] call KPLIB_fnc_setLoadout;
};

[] call KPLIB_fnc_addActionsPlayer;

// Support Module handling
if ([
    false,
    player isEqualTo ([] call KPLIB_fnc_getCommander) || (getPlayerUID player) in KP_liberation_suppMod_whitelist,
    true
] select KP_liberation_suppMod) then {
    waitUntil {!isNil "KPLIB_suppMod_req" && !isNil "KPLIB_suppMod_arty" && time > 5};

    // Remove link to corpse, if respawned
    if (!isNull _oldUnit) then {
        KPLIB_suppMod_req synchronizeObjectsRemove [_oldUnit];
        _oldUnit synchronizeObjectsRemove [KPLIB_suppMod_req];
    };

    // Link player to support modules
    [player, KPLIB_suppMod_req, KPLIB_suppMod_arty] call BIS_fnc_addSupportLink;

    // Init modules, if newly joined and not client host
    if (isNull _oldUnit && !isServer) then {
        [KPLIB_suppMod_req] call BIS_fnc_moduleSupportsInitRequester;
        [KPLIB_suppMod_arty] call BIS_fnc_moduleSupportsInitProvider;
    };
};
