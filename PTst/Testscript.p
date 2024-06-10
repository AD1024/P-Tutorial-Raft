module LeaderElections = { LeaderElectionFiveServers };
module ServingTests = { OneClientOneServerReliable,
                        OneClientFiveServersReliable,
                        OneClientFiveServersUnreliable,
                        TwoClientsThreeServersReliable,
                        TwoClientsThreeServersUnreliable,
                        ThreeClientsFiveServersReliable,
                        ThreeClientsFiveServersUnreliable,
                        ThreeClientsOneServerReliable};

test fiveServers [main=LeaderElectionFiveServers]:
  assert SafetyOneLeader, LivenessLeaderExists in
  (union Server, Client, Timer, LeaderElections, View);

test oneClientOneServerReliable [main=OneClientOneServerReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test oneClientFiveServersReliable [main=OneClientFiveServersReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test oneClientFiveServersUnreliable [main=OneClientFiveServersUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test threeClientsOneServerReliable [main=ThreeClientsOneServerReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test threeClientsFiveServersReliable [main=ThreeClientsFiveServersReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test threeClientsFiveServersUnreliable [main=ThreeClientsFiveServersUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test twoClientsThreeServersReliable [main=TwoClientsThreeServersReliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);

test twoClientsThreeServersUnreliable [main=TwoClientsThreeServersUnreliable]:
  assert SafetyOneLeader, LivenessClientsDone, LivenessLeaderExists, LivenessProgress, SafetySynchronization in
  (union Server, Timer, Client, View, ServingTests);