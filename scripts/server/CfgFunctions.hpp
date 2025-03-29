class server_highcommand {
    file = "scripts\server\highcommand";

    class highcommand                   {ext = ".fsm";};
};

class server_sector {
    file = "scripts\server\sector";

    class destroyFob                    {};
    class sectorMonitor                 {ext = ".fsm";};
    class spawnSectorCrates             {};
    class spawnSectorIntel              {};
};

class server_support {
    file = "scripts\server\support";

    class createSuppModules             {};
};

// Game functions
class KPLIB_game {
    file = "functions";
    
    class checkVictoryConditions        {};
    class saveManager                   {};
    class spawnBattlegroup              {};
    class spawnBattlegroupAI            {};
    class spawnAir                      {};
    class troopTransport                {};
    class readinessIncrease             {};
    class randomBattlegroups            {};
    class counterBattlegroup            {};
    class validateSectorCapture         {};
    class validateFOBPlacement          {};
};
