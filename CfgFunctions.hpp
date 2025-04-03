class KPLIB {
    class functions {
        file = "functions";

        class addActionsFob             {};
        class addActionsPlayer          {};
        class addObjectInit             {};
        class addRopeAttachEh           {};
        class allowCrewInImmobile       {};
        class attackInProgressFOB       {};
        class attackInProgressSector    {};
        class checkClass                {};
        class checkCrateValue           {};
        class checkGear                 {};
        class checkWeaponCargo          {};
        class cleanOpforVehicle         {};
        class clearCargo                {};
        class crAddAceAction            {};
        class createClearance           {};
        class createClearanceConfirm    {};
        class createCrate               {};
        class createManagedUnit         {};
        class createManagedUnitRemote   {};
        class crateFromStorage          {};
        class crateToStorage            {};
        class crawlAllItems             {};
        class crGetMulti                {};
        class crGlobalMsg               {};
        class doSave                    {};
        class fillStorage               {};
        class forceBluforCrew           {};
        class getAdaptiveVehicle        {};
        class getBluforRatio            {};
        class getCommander              {};
        class getCrateHeight            {};
        class getFobName                {};
        class getFobResources           {};
        class getGroupType              {};
        class getLessLoadedHC           {};
        class getLoadout                {};
        class getLocalCap               {};
        class getLocationName           {};
        class getMilitaryId             {};
        class getMobileRespawns         {};
        class getNearbyPlayers          {};
        class getNearestBluforObjective {};
        class getNearestFob             {};
        class getNearestSector          {};
        class getNearestTower           {};
        class getNearestViVTransport    {};
        class getOpforCap               {};
        class getOpforFactor            {};
        class getOpforSpawnPoint        {};
        class getPlayerCount            {};
        class getResistanceTier         {};
        class getSaveableParam          {};
        class getSaveData               {};
        class getSectorOwnership        {};
        class getSectorRange            {};
        class getStoragePositions       {};
        class getUnitPositionId         {};
        class getUnitsCount             {};
        class getWeaponComponents       {};
        class handlePlacedZeusObject    {};
        class hasPermission             {};
        class initPlayerNamespace       {};
        class initSectors               {};
        class isBigtownActive           {};
        class isClassUAV                {};
        class isRadio                   {};
        class log                       {};
        class manageOnePatrol           {};
        class managePatrols             {};
        class monitorSectors            {};
        class potatoScan                {};
        class protectObject             {};
        class reinforcementsManager     {};
        class reinforcementsResetter    {};
        class saveSectorUnits           {};
        class secondsToTimer            {};
        class selectSquadComposition    {};
        class sendParatroopers          {};
        class setDiscordState           {};
        class setFobMass                {};
        class setLoadableViV            {};
        class setLoadout                {};
        class setVehicleCaptured        {};
        class setVehicleSeized          {};
        class sortStorage               {};
        class spawnBuildingSquad        {};
        class spawnCivilians            {};
        class spawnGroupOnHC            {};
        class spawnGroupRemote          {};
        class spawnGuerillaGroup        {};
        class spawnMilitaryPostSquad    {};
        class spawnMilitiaCrew          {};
        class spawnMilitiaCrewRemote    {};
        class spawnPatrolGroupOnHC      {};
        class spawnPatrolGroupRemote    {};
        class spawnPersistentUnits      {};
        class spawnRegularSquad         {};
        class spawnSquadHC              {};
        class spawnVehicle              {};
        class swapInventory             {};
        class validateSectorCapture     {};
        class validateFOBPlacement      {};
        class updatePlayerNamespace     {};
        class updateSectorMarkers       {};
    };
    class functions_curator {
        file = "functions\curator";

        class initCuratorHandlers       {
            postInit = 1;
        };
        class requestZeus               {};
    };
    class functions_ui {
        file = "functions\ui";

        class overlayUpdateResources    {};
    };
    
    class KPLIB_AI {
        file = "functions";
        class applyAIBehavior {};
        class applyVehiclePatrol {};
        class createGroupOnHC {};
        class patrolAI {};
        class fixStandingGroups {};
    };
    
    #include "scripts\client\CfgFunctions.hpp"
    #include "scripts\server\CfgFunctions.hpp"
};
