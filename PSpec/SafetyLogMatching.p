event eAppendEntriesRecv: (node: Server, totalNodes: int, log: seq[tServerLog]);
event eAppendEntriesSent: (node: Server, totalNodes: int, log: seq[tServerLog]);

spec SafetyLogMatching observes eAppendEntriesSent, eAppendEntriesRecv {
    var logsMap: map[Server, seq[tServerLog]];
    var count: int;

    start state Init {
        entry {
            count = 0;
            logsMap = default(map[Server, seq[tServerLog]]);
        }

        on eAppendEntriesRecv do (payload: (node: Server, totalNodes: int, log: seq[tServerLog])) {
            // heartbeat/log recieved by follower
            count = count + 1;
            logsMap[payload.node] = payload.log;
            if(count == payload.totalNodes) {
                goto AllLogsRecieved;
            }

        }
        on eAppendEntriesSent do (payload: (node: Server, totalNodes: int, log: seq[tServerLog])) {
            // heartbeat/log sent by leader
            count = count + 1;
            logsMap[payload.node] = payload.log;
            
        }
    }

    state AllLogsRecieved {

        entry {
            var log1: seq[tServerLog];
            var log2: seq[tServerLog];
            var i: int;
            i = 0;
            // Check each the log of each node against every other node
            // If two logs have an entry with the same term number at the same index
            // every entry up till that point should match
            foreach(log1 in values(logsMap)) {
                foreach(log2 in values(logsMap)) {
                    while(true) {
                        // Check log1 and log2 for matching terms and indexes
                        i = i + 1;
                    }
                }
            }
        }

    }

}
