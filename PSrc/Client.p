type tClientRequest = (transId: int, client: Client, cmd: Command, sender: machine);
event eClientRequest: tClientRequest;
event eClientWaitingResponse: (client: Client, transId: int);
event eClientGotResponse: (client: Client, transId: int);
event eClientFinishedMonitor: Client;
event eClientFinished: Client;

machine Client {
    var worklist: seq[Command];
    var servers: set[machine];
    var ptr: int;
    var tId: int;
    var retries: int;
    var currentCmd: Command;
    var view: View;
    var timer: Timer;

    start state Init {
        entry (config: (viewService: View, servers: set[machine], requests: seq[Command])) {
            worklist = config.requests;
            servers = config.servers;
            view = config.viewService;
            ptr = 0;
            tId = 0;
            timer = new Timer((user=this, timeoutEvent=eHeartbeatTimeout));
            goto SendOne;
        }
    }

    state SendOne {
        entry {
            var cmd: Command;
            print format("{0} is at {1}", this, ptr);
            print format("Worklist {0}", worklist);
            if (sizeof(worklist) == ptr) {
                goto Done;
            } else {
                currentCmd = worklist[ptr];
                ptr = ptr + 1;
                tId = tId + 1;
                broadcastToCluster();
                goto WaitForResponse;
            }
        }
    }

    state WaitForResponse {
        entry {
            announce eClientWaitingResponse, (client=this, transId=tId);
            startTimer(timer);
            retries = 0;
        }

        on eHeartbeatTimeout do {
            print format("Client {0} timed out waiting for response {1}; current retries: {2}", this, tId, retries / 50);
            if (retries % 50 == 0) {
                broadcastToCluster();
            }
            retries = retries + 1;
            startTimer(timer);
        }

        on eRaftResponse do (resp: tRaftResponse) {
            if (resp.transId == tId) {
                print format("Client {0} got response {1}; #retries={2}", this, resp.transId, retries / 50);
                announce eClientGotResponse, (client=this, transId=tId);
                retries = 0;
                goto SendOne;
            }
        }
    }

    fun broadcastToCluster() {
        var s: machine;
        foreach (s in servers) {
            send s, eClientRequest, (transId=tId, client=this, cmd=currentCmd, sender=this);
        }
    }

    state Done {
        entry {
            announce eClientFinishedMonitor, this;
            send view, eClientFinished, this;
        }
        ignore eRaftResponse, eHeartbeatTimeout;
    }
}