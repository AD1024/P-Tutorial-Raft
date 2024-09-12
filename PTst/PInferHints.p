hint exact SingleLeader (e1: eBecomeLeader, e2: eBecomeLeader) {
    num_guards = 1;
    exists = 0;
    arity = 2;
    include_guards = e1.term == e2.term;
}

hint GetReqResp (e1: eClientGetRequest, e2: eRaftGetResponse) {
}