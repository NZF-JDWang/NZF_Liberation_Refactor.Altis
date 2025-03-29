// Add this near the end of the file, before publicVariable statements

// Check for LAMBS modules and functions
diag_log "[KPLIB] Checking for LAMBS AI module compatibility:";
diag_log format ["[KPLIB] LAMBS Main Module: %1", isClass (configFile >> "CfgPatches" >> "lambs_main")]; 
diag_log format ["[KPLIB] LAMBS Waypoint Module: %1", isClass (configFile >> "CfgPatches" >> "lambs_wp")];
diag_log format ["[KPLIB] LAMBS Danger Module: %1", isClass (configFile >> "CfgPatches" >> "lambs_danger")];

// Check if key functions exist
if (isClass (configFile >> "CfgPatches" >> "lambs_wp")) then {
    diag_log format ["[KPLIB] LAMBS taskReset function: %1", !isNil "lambs_wp_fnc_taskReset"];
    diag_log format ["[KPLIB] LAMBS taskPatrol function: %1", !isNil "lambs_wp_fnc_taskPatrol"];
    diag_log format ["[KPLIB] LAMBS taskDefend function: %1", !isNil "lambs_wp_fnc_taskDefend"];
    diag_log format ["[KPLIB] LAMBS taskGarrison function: %1", !isNil "lambs_wp_fnc_taskGarrison"];
    diag_log format ["[KPLIB] LAMBS taskCamp function: %1", !isNil "lambs_wp_fnc_taskCamp"];
}; 