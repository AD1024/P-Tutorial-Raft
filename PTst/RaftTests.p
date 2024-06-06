module ServerWrapper = { ServerInterface };
// Network configuration:
// - delayInterval: the delay for [0, delayInterval) messages for each message
// - dropRate: the probability of a message being dropped (0-100)
// - reorderRate: the probability of a message being reordered (0-100)
// - duplicateRate: the probability of a message being duplicated (0-100)
type NetworkConfig = (delayInterval: int, dropRate: int, reorderRate: int, duplicateRate: int);

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
        if (delayInterval > 0) {
            delayMap[(e=e, p=payload)] = choose(delayInterval);
        } else {
            pendingQueue += (sizeof(pendingQueue), (e=e, p=payload));
        }
        foreach (k in keys(delayMap)) {
            delayMap[k] = delayMap[k] - 1;
            if (delayMap[k] <= 0) {
                pendingQueue += (sizeof(pendingQueue), k);
                delayMap -= k;
            }
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
        print format("Sending {0} to {1} with payload {2}", e, server, payload);
        send server, e, payload;
        while (numDups > 0) {
            send server, e, payload;
            numDups = numDups - 1;
        }
    }
}

fun setUpCluster(numServers: int, networkCfg: NetworkConfig): seq[machine] {
    var servers: seq[Server];
    var interfaces: set[ServerInterface];
    var server: Server;
    var serverInterface: ServerInterface;
    var i: int;
    var j: int;
    servers = default(seq[Server]);
    interfaces = default(set[ServerInterface]);
    i = 0;
    while (i < numServers) {
        servers += (i, new Server());
        i = i + 1;
    }
    i = 0;
    j = 0;
    while (i < numServers) {
        interfaces = default(set[ServerInterface]);
        j = 0;
        while (j < numServers) {
            if (i != j) {
                serverInterface = new ServerInterface((server=servers[j],
                    delayInterval=networkCfg.delayInterval,
                    dropRate=networkCfg.dropRate, reorderRate=networkCfg.reorderRate,
                    duplicateRate=networkCfg.duplicateRate));
                interfaces += (serverInterface);
            }
            j = j + 1;
        }
        send servers[i], eServerInit, (myId=i, cluster=interfaces);
        i = i + 1;
    }

    return servers;
}

fun randomWorkload(numCmd: int): seq[Command] {
    var cmds: seq[Command];
    var puts: set[int];
    var i: int;
    var key: int;
    assert numCmd <= 100, "Too many commands!";
    cmds = default(seq[Command]);
    puts = default(set[int]);
    i = 0;
    while (i < numCmd) {
        // choose an existing key or a new key
        // non-deterministically
        if (sizeof(puts) > 0 && $) {
            key = choose(puts);
        } else {
            key = choose(1024);
        }
        if ($) {
            // PUT
            cmds += (i, (op=PUT, key=key, value=choose(1024)));
        } else {
            // GET
            cmds += (i, (op=GET, key=key, value=null));
        }
        i = i + 1;
    }
    return cmds;
}

machine OneClientOneServerReliable {
    var client: Client;
    var servers: seq[machine];

    start state Init {
        entry {
            client = new Client((retry_time=30, server_list=setUpCluster(1, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0)), requests=randomWorkload(5)));
        }
    }
}

machine OneClientOneServerUnreliable {
    var client: Client;

    start state Init {
        entry {
            client = new Client((retry_time=30,
                server_list=setUpCluster(1, (delayInterval=3, dropRate=10, reorderRate=10, duplicateRate=5)),
                requests=randomWorkload(5)));
        }
    }
}

machine OneClientFiveServersReliable {
    start state Init {
        entry {
            var client: Client;
            client = new Client((retry_time=30, server_list=setUpCluster(5, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0)),
                        requests=randomWorkload(10)));
        }
    }
}

machine OneClienFiveServersUnreliable {
    start state Init {
        entry {
            var client: Client;
            client = new Client((retry_time=30, server_list=setUpCluster(5, (delayInterval=3, dropRate=10, reorderRate=10, duplicateRate=5)),
                        requests=randomWorkload(10)));
        }
    }
}
