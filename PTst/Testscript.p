module LeaderElections = { LeaderElectionThreeServers, LeaderElectionFiveServers };

test threeServers [main=LeaderElectionThreeServers]:
  assert RaftAlwaysCorrect in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert RaftAlwaysCorrect in
  (union Server, Timer, LeaderElections);