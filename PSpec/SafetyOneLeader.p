event eBecomeLeader: (term:int, leader:Server);

spec SafetyOneLeader observes eBecomeLeader{
    var termToLeader: map[int, Server];
    start state Init {
        entry {
            termToLeader = default(map[int, Server]);
        }
        on eBecomeLeader do (payload: (term:int, leader:Server)) {
            if (payload.term in keys(termToLeader)) {
                assert termToLeader[payload.term] == payload.leader, format("At term {0} has leaders {1} and {2}.", payload.term, termToLeader[payload.term], payload.leader);
            }
        }
    }
}