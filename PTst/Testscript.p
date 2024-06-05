module LeaderElections = { LeaderElectionThreeServersFail, LeaderElectionFiveServers };

test threeServersFail [main=LeaderElectionThreeServersFail]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);