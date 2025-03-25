private [ "_minfobdist", "_minsectordist", "_distfob", "_clearedtobuildfob", "_distsector", "_clearedtobuildsector", "_idx" ];

if ( count GRLIB_all_fobs >= GRLIB_maximum_fobs ) exitWith {
    hint format [ localize "STR_HINT_FOBS_EXCEEDED", GRLIB_maximum_fobs ];
};

_minsectordist = GRLIB_capture_size + GRLIB_fob_range;
_distsector = 1;
_clearedtobuildsector = true;

FOB_build_in_progress = true;
publicVariable "FOB_build_in_progress";

_idx = 0;
while { (_idx < (count sectors_allSectors)) && _clearedtobuildsector } do {
    if ( player distance (markerPos (sectors_allSectors select _idx)) < _minsectordist ) then {
        _clearedtobuildsector = false;
        _distsector = player distance (markerPos (sectors_allSectors select _idx));
    };
    _idx = _idx + 1;
};

if ( !_clearedtobuildsector ) then {
    hint format [localize "STR_FOB_BUILDING_IMPOSSIBLE_SECTOR",floor _minsectordist,floor _distsector];
    FOB_build_in_progress = false;
    publicVariable "FOB_build_in_progress";
} else {
    buildtype = 99;
    dobuild = 1;
    deleteVehicle (_this select 0);
};
