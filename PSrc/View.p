event eShutdown;

machine View {
    var servers: set[machine];
    var timeoutRate: int;
    var crashRate: int;
    var triggerTimer: Timer;
    var clientsDone: set[machine];
    var numClients: int;

    start state Init {
        entry (setup: (servers: set[machine], numClients: int, timeoutRate: int, crashRate: int)) {
            servers = setup.servers;
            timeoutRate = setup.timeoutRate;
            numClients = setup.numClients;
            crashRate = setup.crashRate;
            send choose(servers), eElectionTimeout;
            triggerTimer = new Timer((user=this, timeoutEvent=eHeartbeatTimeout));
            clientsDone = default(set[machine]);
            goto Monitoring;
        }
    }

    state Monitoring {
        entry {
            startTimer(triggerTimer);
        }

        on eHeartbeatTimeout do {
            var server: machine;
            foreach (server in servers) {
                send server, eHeartbeatTimeout;
                if (choose(100) < crashRate) {
                    send server, eReset;
                } else if (choose(100) < timeoutRate) {
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