fun setUpRaft(numberOfServers:int) : set[Server] {
  var servers: set[Server];
  var serverCounter: int;
  var server: Server;
  servers = default(set[Server]);
  serverCounter = 0;
  while (serverCounter < numberOfServers) {
    servers += (new Server());
    serverCounter = serverCounter + 1;
  }
  foreach(server in servers) {
    send server, eServerInit, (myId=serverCounter, cluster=servers);
    serverCounter = serverCounter - 1;
  }
  return servers;
}

machine LeaderElectionThreeServersFail {
  var timer: Timer;
  var servers: set[Server];
  var fail: bool;
  start state Init {
    entry { 
      servers = setUpRaft(3);
      timer = new Timer(this);
      goto Running;
    }
  }
  state Running {
    entry {
      startTimer(timer, 200);
    }
    on eTimerTimeout do {
      send servers[choose(3)], eInjectError;
      restartTimer(timer, 200);
    }
  }
}

machine LeaderElectionFiveServers {
  start state Init {
    entry { 
      setUpRaft(5);
    }
  }
}