test threeServers [main=testLeaderElection]:
  assert RaftAlwaysCorrect in
  (union Server, Timer, testLeaderElection);