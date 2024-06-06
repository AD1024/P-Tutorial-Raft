fun setUpRaft(numberOfServers:int) : seq[Server] {
  var servers: seq[Server];
  var peers: set[Server];
  var serverCounter: int;
  var server: Server;
  var i: int;
  var j: int;
  servers = default(seq[Server]);
  serverCounter = 0;
  while (serverCounter < numberOfServers) {
    servers += (sizeof(servers), new Server());
    serverCounter = serverCounter + 1;
  }
  i = 0;
  while (i < numberOfServers) {
    peers = default(set[Server]);
    j = 0;
    while (j < numberOfServers) {
      if (i != j) {
        peers += (servers[j]);
      }
      j = j + 1;
    }
    send servers[i], eServerInit, (myId=i, cluster=peers);
    i = i + 1;
  }
  return servers;
}

machine LeaderElectionThreeServersFail {
  var timer: Timer;
  var servers: seq[Server];
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