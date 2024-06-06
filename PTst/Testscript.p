module LeaderElections = { LeaderElectionThreeServersFail, LeaderElectionFiveServers };
module ServingTests = { OneClientOneServerReliable,
                        OneClientOneServerUnreliableNetwork};

test threeServersFail [main=LeaderElectionThreeServersFail]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test oneClientOneServerReliable [main=OneClientOneServerReliable]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);


test oneClientOneServerUnreliable [main=OneClientOneServerUnreliableNetwork]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);