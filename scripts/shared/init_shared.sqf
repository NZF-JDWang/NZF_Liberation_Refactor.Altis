kill_manager = compileFinal preprocessFileLineNumbers "scripts\shared\kill_manager.sqf";

build_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\build_remote_call.sqf";
build_fob_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\build_fob_remote_call.sqf";
cancel_build_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\cancel_build_remote_call.sqf";
prisonner_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\prisonner_remote_call.sqf";
recycle_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\recycle_remote_call.sqf";
reinforcements_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\reinforcements_remote_call.sqf";
sector_liberated_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\sector_liberated_remote_call.sqf";
intel_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\intel_remote_call.sqf";
start_secondary_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\start_secondary_remote_call.sqf";
change_prod_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\change_prod_remote_call.sqf";
build_fac_remote_call = compileFinal preprocessFileLineNumbers "scripts\server\remotecall\build_fac_remote_call.sqf";

remote_call_sector = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_sector.sqf";
remote_call_fob = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_fob.sqf";
remote_call_battlegroup = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_battlegroup.sqf";
remote_call_endgame = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_endgame.sqf";
remote_call_prisonner = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_prisonner.sqf";
remote_call_intel = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_intel.sqf";
remote_call_incoming = compileFinal preprocessFileLineNumbers "scripts\client\remotecall\remote_call_incoming.sqf";

civinfo_notifications = compileFinal preprocessFileLineNumbers "scripts\client\civinformant\civinfo_notifications.sqf";
civinfo_escort = compileFinal preprocessFileLineNumbers "scripts\client\civinformant\civinfo_escort.sqf";
civinfo_delivered = compileFinal preprocessFileLineNumbers "scripts\server\civinformant\civinfo_delivered.sqf";

asymm_notifications = compileFinal preprocessFileLineNumbers "scripts\client\asymmetric\asymm_notifications.sqf";

execVM "scripts\shared\diagnostics.sqf";

// Client-side marker functions
NZF_fnc_refreshClientMarkers = compileFinal preprocessFileLineNumbers "scripts\client\markers\fn_refreshClientMarkers.sqf";
