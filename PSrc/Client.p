type tClientRequest = (transId: int, client: Client, cmd: Command);
event eClientRequest: tClientRequest;
event eClientWaitingResponse: (client: Client, transId: int);
event eClientGotResponse: (client: Client, transId: int);

machine Client {
    var worklist: seq[Command];
    var servers: seq[machine];
    var ptr: int;
    var tId: int;
    var currentCmd: Command;
    var retryTimer: Timer;
    var retryInterval: int;

    start state Init {
        entry (config: (retry_time: int, server_list: seq[machine], requests: seq[Command])) {
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
                goto WaitForResponse;
            }
        }
    }

    state WaitForResponse {
        entry {
            startTimer(retryTimer, retryInterval);
            announce eClientWaitingResponse, (client=this, transId=tId);
        }

        on eRaftResponse do (resp: tRaftResponse) {
            if (resp.transId == tId) {
                announce eClientGotResponse, (client=this, transId=tId);
                tId = tId + 1;
                goto SendOne;
            }
        }

        on eTimerTimeout do {
            broadcastToCluster();
            goto WaitForResponse;
        }
    }

    fun broadcastToCluster() {
        var s: machine;
        var i: int;
        while (i < sizeof(servers)) {
            send servers[i], eClientRequest, (transId=tId, client=this, cmd=currentCmd);
        }
    }

    state Done {
        ignore eRaftResponse, eTimerTimeout;
    }
}