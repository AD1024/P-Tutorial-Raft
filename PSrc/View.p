event eShutdown;

machine View {
    var servers: seq[machine];
    var timeoutRate: int;
    var crashRate: int;
    var triggerTimer: Timer;
    var clientsDone: set[machine];

    start state Init {
        entry (setup: (servers: seq[machine], numClients: int, timeoutRate: int, crashRate: int)) {
            servers = setup.servers;
            timeoutRate = setup.timeoutRate;
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
            var i: int;
            i = 0;
            while (i < sizeof(servers)) {
                send servers[i], eHeartbeatTimeout;
                if (choose(100) < crashRate) {
                    send servers[i], eReset;
                } else if (choose(100) < timeoutRate) {
                    send servers[i], eElectionTimeout;
                }
                i = i + 1;
            }
        }

        on eClientFinished do (client: machine) {
            var i: int;
            clientsDone += (client);
            if (sizeof(clientsDone) == sizeof(servers)) {
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