module LeaderElections = { LeaderElectionThreeServersFail, LeaderElectionFiveServers };
module ServingTests = { OneClientOneServerReliable,
                        OneClientOneServerUnreliable,
                        OneClientFiveServersReliable,
                        OneClienFiveServersUnreliable};

test threeServersFail [main=LeaderElectionThreeServersFail]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections);

test oneClientOneServerReliable [main=OneClientOneServerReliable]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);


test oneClientOneServerUnreliable [main=OneClientOneServerUnreliable]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);

test oneClientFiveServersReliable [main=OneClientFiveServersReliable]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);

test oneClientFiveServersUnreliable [main=OneClienFiveServersUnreliable]:
  assert SafetyOneLeader, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, ServerWrapper, ServingTests);