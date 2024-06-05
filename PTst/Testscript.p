module LeaderElections = { LeaderElectionThreeServers, LeaderElectionFiveServers };

test threeServers [main=LeaderElectionThreeServers]:
  assert RaftAlwaysCorrect, LeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert RaftAlwaysCorrect, LeaderExists in
  (union Server, Timer, LeaderElections);