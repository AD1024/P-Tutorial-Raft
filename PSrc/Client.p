type tClientRequest = (transId: int, client: Client, cmd: Command);
event eClientRequest: tClientRequest;

machine Client {
    var worklist: seq[Command];
    var servers: set[Server];
    var ptr: int;
    var tId: int;
    var currentCmd: Command;
    var retryTimer: Timer;
    var retryInterval: int;

    start state Init {
        entry (config: (retry_time: int, server_list: set[Server], requests: seq[Command])) {
            worklist = config.requests;
            servers = config.server_list;
            ptr = 0;
            tId = 0;
            retryTimer = new Timer(this);
            retryInterval = config.retry_time;
            goto SendOne;
        }
    }

    state SendOne {
        entry {
            var cmd: Command;
            if (sizeof(worklist) == ptr) {
                goto Done;
            } else {
                currentCmd = worklist[ptr];
                ptr = ptr + 1;
                broadcastToCluster();
                startTimer(retryTimer, retryInterval);
                goto WaitForResponse;
            }
        }
    }

    hot state WaitForResponse {
        on eRaftResponse do (resp: tRaftResponse) {
            if (resp.transId == tId) {
                tId = tId + 1;
                goto SendOne;
            }
        }

        on eTimerTimeout do {
            broadcastToCluster();
            startTimer(retryTimer, retryInterval);
        }
    }

    fun broadcastToCluster() {
        var s: Server;
        foreach (s in servers) {
            send s, eClientRequest, (transId=tId, client=this, cmd=currentCmd);
        }
    }

    cold state Done {
        ignore eRaftResponse, eTimerTimeout;
    }
}