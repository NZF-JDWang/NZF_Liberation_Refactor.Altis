/*
    File: fn_selectSquadComposition.sqf
    Author: [NZF] JD Wang
    Date: 2024-04-01 // Updated Date
    Description:
        Selects an appropriate squad composition based on the required role and sector type.
        Returns the variable name containing the squad composition array.

    Parameter(s):
        _sectorNameString - Name of the sector (e.g. "capture_33") [STRING]
        _role - The required role for the squad (e.g. "GARRISON_CENTER", "PATROL_OUTER") [STRING]
        _sectorType - Type of sector (e.g. "military", "factory", "bigtown") [STRING]

    Returns:
        String containing the variable name of the squad composition to use [STRING]
*/

params [
    ["_sectorNameString", "", [""]],
    ["_role", "", [""]],
    ["_sectorType", "", [""]]
];

// Define a default composition variable name
private _compositionVar = "KPLIB_o_squadStd";

// First check if required composition variables exist
if (isNil "KPLIB_o_squadStd") then {
    // Define a basic fallback squad if the main variable is missing
    KPLIB_o_squadStd = ["I_Soldier_SL_F", "I_Soldier_M_F", "I_Soldier_AR_F"];
};

if (isNil "KPLIB_o_squadSupport") then {
    // Define a basic support squad fallback
    KPLIB_o_squadSupport = KPLIB_o_squadStd + ["I_Soldier_LAT_F", "I_Soldier_GL_F"];
};

if (isNil "KPLIB_o_squadAssault") then {
    // Define a basic assault squad fallback
    KPLIB_o_squadAssault = ["I_Soldier_SL_F", "I_Soldier_TL_F", "I_Soldier_AR_F", "I_Soldier_GL_F", "I_Soldier_LAT_F"];
};

// Select composition based on role and sector type
switch (toUpper _role) do {
    case "GARRISON_CENTER": {
        // Center garrison usually gets a standard squad
        _compositionVar = "KPLIB_o_squadStd";
    };
    case "DEFEND_AREA": {
        // Defend roles might get standard or support depending on sector type
        if (_sectorType in ["military", "factory"]) then {
            _compositionVar = "KPLIB_o_squadSupport";
        } else {
            _compositionVar = "KPLIB_o_squadStd";
        };
    };
    case "PATROL_INNER": {
        // Inner patrols often use standard/assault squads or assault/standard fireteams
        _compositionVar = selectRandom [
            "KPLIB_o_squadStd",
            "KPLIB_o_fireteamAssault",
            "KPLIB_o_fireteamStd",
            "KPLIB_o_fireteamSupport"
        ];
    };
    case "PATROL_OUTER": {
        // Outer patrols might be standard/support squads or standard/support fireteams
         _compositionVar = selectRandom [
            "KPLIB_o_squadAssault", 
            "KPLIB_o_fireteamStd",
            "KPLIB_o_fireteamSupport",
            "KPLIB_o_fireteamAssault"
        ];
    };
    case "CAMP_SECTOR": {
        // Camp roles might get support or standard
         if (random 1 > 0.5) then {
            _compositionVar = "KPLIB_o_squadSupport";
        } else {
            _compositionVar = "KPLIB_o_squadStd";
        };
    };
    // Add more cases here for other specific roles as needed
    // e.g., ANTI_ARMOR, ANTI_AIR, HEAVY_INFANTRY etc.
    case "PATROL_DEFAULT": {
        // Default patrol role gets a mix of standard/assault squads or fireteams
         _compositionVar = selectRandom [
            "KPLIB_o_squadStd",
            "KPLIB_o_squadAssault",
            "KPLIB_o_fireteamStd",
            "KPLIB_o_fireteamAssault",
            "KPLIB_o_fireteamSupport"
        ];
    };
    default {
        // Using default squad for unhandled role
        _compositionVar = "KPLIB_o_squadStd";
    };
};

// Return the variable name (string)
_compositionVar 