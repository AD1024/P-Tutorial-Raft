machine ServerInterface {
    var delayInterval: int;
    var dropRate: int;
    var server: Server;
    var timer: Timer;

    start state Init {
        entry (setup: (server: Server, delayInterval: int, dropRate: int)) {
            server = setup.server;
            delayInterval = delayInterval;
            dropRate = dropRate;
            timer = new Timer(this);
        }

        on eRequestVote do (payload: tRequestVote) {
            sendEvent(eRequestVote, payload);
        }

        on eRequestVoteReply do (payload: tRequestVoteReply) {
            sendEvent(eRequestVoteReply, payload);
        }

        on eAppendEntries do (payload: tAppendEntries) {
            sendEvent(eAppendEntries, payload);
        }

        on eAppendEntriesReply do (payload: tAppendEntriesReply) {
            sendEvent(eAppendEntriesReply, payload);
        }

        on eClientRequest do (payload: tClientRequest) {
            sendEvent(eClientRequest, payload);
        }
    }

    fun sendEvent(e: event, payload: any) {
        if (choose(100) <= dropRate) {
            return;
        }
        if (delayInterval > 0) {
            startTimer(timer, choose(delayInterval));
        }
        receive { 
            case eTimerTimeout: {
                send server, e, payload;
            }
        }
    }
}

fun setUpCluster(numServers: int, delayInterval: int, dropRate: int): set[ServerInterface] {
    var servers: set[Server];
    var interfaces: set[ServerInterface];
    var server: Server;
    var serverInterface: ServerInterface;
    var i: int;
    servers = default(set[Server]);
    interfaces = default(set[ServerInterface]);
    i = 0;
    while (i < numServers) {
        server = new Server();
        serverInterface = new ServerInterface((server=server, delayInterval=delayInterval, dropRate=dropRate));
        servers += (server);
        interfaces += (serverInterface);
    }
    i = 0;
    foreach (server in servers) {
        send server, eServerInit, (myId=i, cluster=interfaces);
        i = i + 1;
    }

    return interfaces;
}