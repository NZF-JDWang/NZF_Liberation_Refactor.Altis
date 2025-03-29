// Add this towards the end of the file, with the other PFH initializations

// Setup periodic check for standing AI groups - runs every 5 minutes
if (isServer) then {
    [{
        // Check for standing AI groups and fix them
        private _fixedCount = [] call KPLIB_fnc_fixStandingGroups;
        if (_fixedCount > 0) then {
            diag_log format ["[KPLIB] Periodic AI group check fixed %1 groups without proper waypoints", _fixedCount];
        };
    }, 300, []] call CBA_fnc_addPerFrameHandler;
}; 