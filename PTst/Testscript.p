module LeaderElections = {LeaderElectionThreeServers, LeaderElectionFiveServers};
module LogConsistency = {TestLogMatching};


test threeServersFail [main=LeaderElectionThreeServersFail]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test logConsistency [main=TestLogMatching]:
  assert SafetyOneLeader, LivenessLeaderExists, SafetyLogMatching in
  (union Server, Timer, LogConsistency);