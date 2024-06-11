spec SafetyLogMatching observes eNotifyLog {
    var allLogs: map[Server, seq[tServerLog]];

    start state MonitorLogUpdates {
        entry {
            allLogs = default(map[Server, seq[tServerLog]]);
        }

        on eNotifyLog do (payload: (timestamp: int, server: Server, log: seq[tServerLog])) {
            var i: int;
            var j: int;
            var s1: Server;
            var s2: Server;
            if (!(payload.server in allLogs)) {
                allLogs[payload.server] = payload.log;
            }
            i = 0;
            while (i < sizeof(keys(allLogs))) {
                s1 = keys(allLogs)[i];
                j = i + 1;
                while (j < sizeof(keys(allLogs))) {
                    s2 = keys(allLogs)[j];
                    if (sizeof(allLogs[s1]) > sizeof(allLogs[s2])) {
                        checkLogMatching(s2, s1, allLogs[s2], allLogs[s1]);
                    } else {
                        checkLogMatching(s1, s2, allLogs[s1], allLogs[s2]);
                    }
                    j = j + 1;
                }
                i = i + 1;
            }
        }
    }

    fun checkLogMatching(s1: Server, s2: Server, logsA: seq[tServerLog], logsB: seq[tServerLog]) {
        var i: int;
        var highestMatch: int;
        i = sizeof(logsA) - 1;
        while (i >= 0 && logsA[i] != logsB[i]) {
           i = i - 1;
        }
        highestMatch = i;
        while (i >= 0) {
            assert logsA[i] == logsB[i],
            format("Log not matching between {0} and {1} ({2} != {3}), while the highestMatch={4}",
                    s1, s2, logsA[i], logsB[i], logsA[highestMatch]);
            i = i - 1;
        }
    }
}
