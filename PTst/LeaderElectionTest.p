fun setUpRaft(numberOfServers:int) {
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
}

machine LeaderElectionThreeServers {
  start state Init {
    entry { 
      setUpRaft(3);
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