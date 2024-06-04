type tClientRequest = (client: Client, cmd: Command);
event eClientRequest: tClientRequest;

machine Client {
    var worklist: seq[Command];
    var servers: set[Server];
    var ptr: int;

    start state Init {
        entry (config: (server_list: set[Server], requests: seq[Command])) {
            worklist = config.requests;
            servers = config.server_list;
            ptr = 0;
            goto SendOne;
        }
    }

    state SendOne {
        entry {
            var cmd: Command;
            if (sizeof(worklist) == ptr) {
                goto Done;
            } else {
                cmd = worklist[ptr];
                ptr = ptr + 1;
                broadcastRequest(this, cmd);
                goto WaitForResponse;
            }
        }
    }

    state WaitForResponse {
        on eRaftResponse do {
            goto SendOne;
        }
    }

    fun broadcastRequest(client: Client, cmd: Command) {
        var s: Server;
        foreach (s in servers) {
            send s, eClientRequest, (client=client, cmd=cmd);
        }
    }

    state Done {
        ignore eRaftResponse;
    }
}