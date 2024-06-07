module LeaderElections = { LeaderElectionThreeServersFail, LeaderElectionFiveServers };
module ServingTests = { OneClientOneServerReliable,
                        OneClientOneServerUnreliable,
                        OneClientFiveServersReliable,
                        OneClienFiveServersUnreliable,
                        ThreeClientsFiveServersReliable,
                        ThreeClientsFiveServersUnreliable,
                        ThreeClientsOneServerReliable,
                        OneClientOneServerRandomCrashReliable};

test threeServersFail [main=LeaderElectionThreeServersFail]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections, ServerWrapper);

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Timer, LeaderElections, ServerWrapper);

test oneClientOneServerReliable [main=OneClientOneServerReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);


test oneClientOneServerUnreliable [main=OneClientOneServerUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);

test oneClientFiveServersReliable [main=OneClientFiveServersReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);

test oneClientFiveServersUnreliable [main=OneClienFiveServersUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);

test threeClientsOneServerReliable [main=ThreeClientsOneServerReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);

test threeClientsFiveServersReliable [main=ThreeClientsFiveServersReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);

test threeClientsFiveServersUnreliable [main=ThreeClientsFiveServersUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServerWrapper, ServingTests);