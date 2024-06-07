event eShutdown;

machine View {
    var servers: set[Server];
    var timeoutRate: int;
    var crashRate: int;
    var numFailures: int;
    var triggerTimer: Timer;
    var clientsDone: set[machine];
    var numClients: int;

    start state Init {
        entry (setup: (numServers: int, numClients: int, timeoutRate: int, crashRate: int, numFailures: int)) {
            var i: int;
            var server: Server;
            timeoutRate = setup.timeoutRate;
            numClients = setup.numClients;
            crashRate = setup.crashRate;
            numFailures = setup.numFailures;
            while (i < setup.numServers) {
                servers += (new Server());
                i = i + 1;
            }
            i = 0;
            foreach (server in servers) {
                send server, eServerInit, (myId=i, cluster=servers, viewServer=this);
            }
            triggerTimer = new Timer((user=this, timeoutEvent=eHeartbeatTimeout));
            clientsDone = default(set[machine]);
            i = 0;
            while (i < numClients) {
                new Client((viewService=this, servers=servers, requests=randomWorkload(choose(5) + 1)));
                i = i + 1;
            } 
            send choose(servers), eElectionTimeout;
            goto Monitoring;
        }
    }

    state Monitoring {
        entry {
            startTimer(triggerTimer);
        }

        on eHeartbeatTimeout do {
            var server: Server;
            foreach (server in servers) {
                send server, eHeartbeatTimeout;
                if (choose(100) < crashRate && numFailures > 0) {
                    send server, eReset;
                } else if (choose(100) < timeoutRate && numFailures > 0) {
                    send server, eElectionTimeout;
                }
            }
            startTimer(triggerTimer);
        }

        on eClientFinished do (client: machine) {
            var i: int;
            clientsDone += (client);
            if (sizeof(clientsDone) == numClients) {
                i = 0;
                while (i < sizeof(servers)) {
                    send servers[i], eShutdown;
                    i = i + 1;
                }
                goto ViewServiceEnd;   
            }
        }
    }

    state ViewServiceEnd {
        entry {
            send triggerTimer, eShutdown;
        }

        ignore eClientFinished, eHeartbeatTimeout;
    }
}