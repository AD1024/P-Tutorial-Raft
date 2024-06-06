type tClientRequest = (transId: int, client: Client, cmd: Command);
event eClientRequest: tClientRequest;
event eClientWaitingResponse: (client: Client, transId: int);
event eClientGotResponse: (client: Client, transId: int);
event eClientFinished: Client;

machine Client {
    var worklist: seq[Command];
    var servers: seq[machine];
    var ptr: int;
    var tId: int;
    var currentCmd: Command;
    var view: View;

    start state Init {
        entry (config: (retry_time: int, viewService: View, server_list: seq[machine], requests: seq[Command])) {
            worklist = config.requests;
            servers = config.server_list;
            view = config.viewService;
            ptr = 0;
            tId = 0;
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
        while (i < sizeof(servers)) {
            send servers[i], eClientRequest, (transId=tId, client=this, cmd=currentCmd);
            i = i + 1;
        }
    }

    state Done {
        entry {
            announce eClientFinished, this;
            send view, eClientFinished, this;
        }
        ignore eRaftResponse, eHeartbeatTimeout;
    }
}