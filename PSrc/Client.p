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
        }

        on eHeartbeatTimeout do {
            print format("Client {0} timed out waiting for response {1}", this, tId);
            broadcastToCluster();
            startTimer(timer);
        }

        on eRaftResponse do (resp: tRaftResponse) {
            print format("Client {0} got response {1}", this, resp.transId);
            if (resp.transId == tId) {
                announce eClientGotResponse, (client=this, transId=tId);
                goto SendOne;
            }
        }
    }

    fun broadcastToCluster() {
        var s: machine;
        var i: int;
        foreach (s in servers) {
            send s, eClientRequest, (transId=tId, client=this, cmd=currentCmd, sender=this);
            i = i + 1;
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