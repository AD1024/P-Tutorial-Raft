module LeaderElections = { LeaderElectionThreeServers, LeaderElectionFiveServers };

test threeServers [main=LeaderElectionThreeServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LeaderExists in
  (union Server, Timer, LeaderElections);