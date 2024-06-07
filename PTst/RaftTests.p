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

    var timer: Timer;
    var pendingQueue: seq[tPacket];
    var delayMap: map[tPacket, int];

    start state Init {
        entry (setup: (delayInterval: int, dropRate: int, reorderRate: int, duplicateRate: int)) {
            delayInterval = delayInterval;
            dropRate = dropRate;
            duplicateRate = duplicateRate;
            pendingQueue = default(seq[tPacket]);
            delayMap = default(map[tPacket, int]);
        }

        on eForwardPls do (payload: tPacket) {
            sendEvent(payload);
        }
    }

    fun sendEvent(packet: tPacket) {
        var k: tPacket;
        if (choose(100) < dropRate) {
            return;
        }
        if (delayInterval > 0) {
            delayMap[packet] = choose(delayInterval);
        } else {
            pendingQueue += (sizeof(pendingQueue), packet);
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
                sendMsg(pendingQueue[i]);
                pendingQueue -= (i);
            }
            sendMsg(pendingQueue[0]);
            pendingQueue -= (0);
        }
    }

    fun sendMsg(packet: tPacket) {
        var numDups: int;
        numDups = 0;
        if (choose(100) < duplicateRate) {
            numDups = choose(3);
        }
        print format("Sending {0} to {1} with payload {2}", packet.e, packet.target, packet.p);
        send packet.target, packet.e, packet.p;
        while (numDups > 0) {
            send packet.target, packet.e, packet.p;
            numDups = numDups - 1;
        }
    }
}

fun newSwitch(): ServerInterface {
    return new ServerInterface((delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
}

fun setUpCluster(numServers: int, networkCfg: NetworkConfig): set[Server] {
    var servers: set[Server];
    var interfaces: set[machine];
    var server: Server;
    var hub: ServerInterface;
    var i: int;
    var j: int;
    servers = default(set[Server]);
    hub = new ServerInterface((delayInterval=networkCfg.delayInterval,
        dropRate=networkCfg.dropRate, reorderRate=networkCfg.reorderRate,
        duplicateRate=networkCfg.duplicateRate));
    i = 0;
    while (i < numServers) {
        servers += (new Server());
        i = i + 1;
    }
    i = 0;
    foreach (server in servers) {
        send server, eServerInit, (myId=i, cluster=servers, centralSwitch=hub);
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
            puts += (key);
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
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(1, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
            viewService = new View((servers=servers, numClients=1, timeoutRate=0, crashRate=0));
            client = new Client((retry_time=30,
                viewService=viewService,
                servers=servers,
                requests=randomWorkload(5)));
        }
    }
}

machine OneClientOneServerUnreliable {
    var client: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(1, (delayInterval=3, dropRate=40, reorderRate=10, duplicateRate=5));
            viewService = new View((servers=servers, numClients=1, timeoutRate=0, crashRate=0));
            client = new Client((retry_time=30,
                viewService=viewService,
                servers=servers,
                requests=randomWorkload(5)));
        }
    }
}

machine OneClientFiveServersReliable {
    var client: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(5, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
            viewService = new View((servers=servers, numClients=1, timeoutRate=0, crashRate=0));
            client = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
        }
    }
}

machine OneClienFiveServersUnreliable {
    var client: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(5, (delayInterval=3, dropRate=40, reorderRate=40, duplicateRate=40));
            viewService = new View((servers=servers, numClients=1, timeoutRate=0, crashRate=0));
            client = new Client((retry_time=30,
                        viewService=viewService, 
                        servers=servers,
                        requests=randomWorkload(10)));
        }
    }
}

machine ThreeClientsOneServerReliable {
    var client1: Client;
    var client2: Client;
    var client3: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(5, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
            viewService = new View((servers=servers, numClients=3, timeoutRate=0, crashRate=0));
            client1 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client2 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client3 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
        }
    }
}

machine ThreeClientsFiveServersReliable {
    var client1: Client;
    var client2: Client;
    var client3: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(5, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
            viewService = new View((servers=servers, numClients=3, timeoutRate=0, crashRate=0));
            client1 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client2 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client3 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
        }
    }
}

machine ThreeClientsFiveServersUnreliable {
    var client1: Client;
    var client2: Client;
    var client3: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(5, (delayInterval=3, dropRate=40, reorderRate=40, duplicateRate=40));
            viewService = new View((servers=servers, numClients=3, timeoutRate=0, crashRate=0));
            client1 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client2 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
            client3 = new Client((retry_time=30,
                        viewService=viewService,
                        servers=servers,
                        requests=randomWorkload(5)));
        }
    }
}

machine OneClientOneServerRandomCrashReliable {
    var client: Client;
    var servers: set[machine];
    var viewService: View;

    start state Init {
        entry {
            servers = setUpCluster(1, (delayInterval=0, dropRate=0, reorderRate=0, duplicateRate=0));
            viewService = new View((servers=servers, numClients=1, timeoutRate=0, crashRate=50));
            client = new Client((retry_time=30,
                viewService=viewService,
                servers=servers,
                requests=randomWorkload(5)));
        }
    }
}