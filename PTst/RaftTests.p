machine ServerInterface {
    var delayInterval: int;
    var dropRate: int;
    var reorderRate: int;
    var duplicateRate: int;

    var server: Server;
    var timer: Timer;
    var pendingQueue: seq[(e: event, p: any)];
    var delayMap: map[(e: event, p: any), int];

    start state Init {
        entry (setup: (server: Server, delayInterval: int, dropRate: int, reorderRate: int, duplicateRate: int)) {
            server = setup.server;
            delayInterval = delayInterval;
            dropRate = dropRate;
            duplicateRate = duplicateRate;
            pendingQueue = default(seq[(e: event, p: any)]);
            delayMap = default(map[(e: event, p: any), int]);
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
        var k: (e: event, p: any);
        if (choose(100) < dropRate) {
            return;
        }
        foreach (k in keys(delayMap)) {
            delayMap[k] = delayMap[k] - 1;
            if (delayMap[k] == 0) {
                pendingQueue += (sizeof(pendingQueue), k);
                delayMap -= k;
            }
        }
        if (delayInterval > 0) {
            delayMap[(e=e, p=payload)] = choose(delayInterval);
        }
        commitEvents();
    }

    fun commitEvents() {
        var i: int;
        while (sizeof(pendingQueue) > 0) {
            if (choose(100) < reorderRate && sizeof(pendingQueue) > 1) {
                i = choose(sizeof(pendingQueue) - 1) + 1;
                // send server, pendingQueue[i].e, pendingQueue[i].p;
                sendMsg(pendingQueue[i].e, pendingQueue[i].p);
                pendingQueue -= (i);
            }
            sendMsg(pendingQueue[0].e, pendingQueue[0].p);
            pendingQueue -= (0);
        }
    }

    fun sendMsg(e: event, payload: any) {
        var numDups: int;
        numDups = 0;
        if (choose(100) < duplicateRate) {
            numDups = choose(3);
        }
        send server, e, payload;
        while (numDups > 0) {
            send server, e, payload;
            numDups = numDups - 1;
        }
    }
}

fun setUpCluster(numServers: int, delayInterval: int,
                 dropRate: int, reorderRate: int, duplicateRate: int): set[ServerInterface] {
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
        serverInterface = new ServerInterface((server=server, delayInterval=delayInterval,
                                               dropRate=dropRate, reorderRate=reorderRate, duplicateRate=duplicateRate));
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