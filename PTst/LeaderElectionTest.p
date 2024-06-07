fun setUpRaft(numberOfServers:int, numClients: int) : View {
  return new View((numServers=numberOfServers, numClients=numClients, timeoutRate=0, crashRate=0, numFailures=0));
}

machine LeaderElectionFiveServers {
  start state Init {
    entry { 
      setUpRaft(5, 0);
    }
  }
}