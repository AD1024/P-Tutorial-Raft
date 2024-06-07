type ServerId = int;
type tRaftResponse = (client: Client, transId: int, result: any);
event eRaftResponse: tRaftResponse;

event eServerInit: (myId: ServerId, cluster: set[Server], viewServer: View);

type tRequestVote = (term: int, candidate: Server, lastLogIndex: int, lastLogTerm: int);
event eRequestVote: tRequestVote;
type tRequestVoteReply = (sender: Server, term: int, voteGranted: bool);
event eRequestVoteReply: tRequestVoteReply;

type tAppendEntries = (term: int, leader: Server, prevLogIndex: int,
                       prevLogTerm: int, entries: seq[tServerLog], leaderCommit: int);
event eAppendEntries: tAppendEntries;

type tAppendEntriesReply = (sender: Server, term: int, success: bool, matchedIndex: int);
event eInjectError;
event eAppendEntriesReply: tAppendEntriesReply;

type tPacket = (target: machine, e: event, p: any);
event eForwardPls: tPacket;

event eReset;

type tServerLog = (term: int, command: Command, client: Client, transId: int);
// AppendEntries
type tAppendEntriesRequest = (
    sender: ServerId,
    term: int,
    prevLogIndex: int,
    logs: seq[tServerLog]
);

machine Server {
    var serverId: ServerId;
    var crashRate: int;
    var kvStore: KVStore;
    var leader: Server;
    var clusterSize: int;
    var peers: set[Server];
    // var executionResults: map[Client, map[int, Result]];

    // Leader state (volatile)
    var nextIndex: map[Server, int];
    var matchIndex: map[Server, int];

    // Leader state (persistent)
    var currentTerm: int;
    var logs: seq[tServerLog];

    var votedFor: Server;
    var votesReceived: set[Server];

    // all servers
    var commitIndex: int;
    var lastApplied: int;

    // var heartbeatTimer: Timer;
    var clientRequestQueue: seq[tClientRequest];

    start state Init {
        entry {}
        on eServerInit do (setup: (myId: ServerId, cluster: set[Server], viewServer: View)) {
            kvStore = newStore();
            serverId = setup.myId;
            clusterSize = sizeof(setup.cluster);
            peers = setup.cluster;
            nextIndex = default(map[Server, int]);
            matchIndex = default(map[Server, int]);
            votesReceived = default(set[Server]);
            logs = default(seq[tServerLog]);
            clientRequestQueue = default(seq[tClientRequest]);
            // executionResults = default(map[Client, map[int, Result]]);

            currentTerm = 0;
            votedFor = null as Server;
            commitIndex = -1;
            lastApplied = -1;
            leader = null as Server;
            // electionTimer = new Timer((user=this, timeoutEvent=eElectionTimeout));
            // heartbeatTimer = new Timer((user=this, timeoutEvent=eHeartbeatTimeout));
            goto Follower;
        }
        ignore eReset, eElectionTimeout, eHeartbeatTimeout;
    }

    state Follower {
        entry {
            // restartTimer(electionTimer);
            leader = null as Server;
            // votedFor = null as Server;
        }

        on eShutdown do {
            goto FinishedServing;
        }

        on eReset do {
            reset();
        }

        on eRequestVote do (payload: tRequestVote) {
            handleRequestVote(payload);
        }

        on eClientRequest do (payload: tClientRequest) {
            if (leader != null) {
                send leader, eClientRequest, forwardedRequest(payload);
            } else {
                clientRequestQueue += (sizeof(clientRequestQueue), payload);
            }
        }

        on eAppendEntries do (payload: tAppendEntries) {
            // cancelTimer(electionTimer);
            if (payload.term > currentTerm) {
                votedFor = null as Server;
                currentTerm = payload.term;
            }
            handleAppendEntries(payload);
            if (leader != null) {
                while (sizeof(clientRequestQueue) > 0) {
                    send leader, eClientRequest, forwardedRequest(clientRequestQueue[0]);
                    clientRequestQueue -= (0);
                }
            }
            // restartTimer(electionTimer);
        }

        on eElectionTimeout goto Candidate;

        on eInjectError do {
            announce eBecomeLeader, (term=currentTerm, leader=this);
        }

        ignore eRequestVoteReply, eAppendEntriesReply, eHeartbeatTimeout;
    }

    state Candidate {
        entry {
            var peer: Server;
            var lastTerm: int;
            // cancelTimer(electionTimer);
            currentTerm = currentTerm + 1;
            votedFor = null as Server;
            votesReceived = default(set[Server]);
            votesReceived += (this);
            if (sizeof(votesReceived) > clusterSize / 2) {
                goto Leader;
            } else {
                broadcastRequest(this, peers, eRequestVote,
                                    (term=currentTerm,
                                        candidate=this,
                                        lastLogIndex=lastLogIndex(logs),
                                        lastLogTerm=lastLogTerm(logs)));
            }
            // startTimer(electionTimer);
        }

        on eClientRequest do (payload: tClientRequest) {
            clientRequestQueue += (sizeof(clientRequestQueue), payload);
        }

        on eShutdown do {
            goto FinishedServing;
        }

        on eAppendEntries do (payload: tAppendEntries) {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                votedFor = null as Server;
                handleAppendEntries(payload);
                goto Follower;
            } else {
                handleAppendEntries(payload);
            }
        }

        on eAppendEntriesReply do (payload: tAppendEntriesReply) {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                votedFor = null as Server;
                goto Follower;
            }
        }

        on eRequestVoteReply do (payload: tRequestVoteReply) {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                goto Follower;
            } else if (payload.voteGranted && payload.term == currentTerm) {
                votesReceived += (payload.sender);
                if (sizeof(votesReceived) > clusterSize / 2) {
                    goto Leader;
                }
            }
        }
        
        on eRequestVote do (payload: tRequestVote)  {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                handleRequestVote(payload);
                goto Follower;
            } else {
                send payload.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }

        on eReset do {
            reset();
        }

        on eElectionTimeout do {
            goto Candidate;
        }

        on eInjectError do {
            announce eBecomeLeader, (term=currentTerm, leader=this);
        }

        ignore eHeartbeatTimeout;
    }

    state Leader {
        entry {
            leader = this;
            nextIndex = fillMap(this, nextIndex, peers, sizeof(logs));
            matchIndex = fillMap(this, matchIndex, peers, -1);
            // restartTimer(heartbeatTimer);
            announce eBecomeLeader, (term=currentTerm, leader=this);
            while (sizeof(clientRequestQueue) > 0) {
                send this, eClientRequest, forwardedRequest(clientRequestQueue[0]);
                clientRequestQueue -= (0);
            }
            broadcastAppendEntries();
        }

        on eShutdown do {
            goto FinishedServing;
        }

        on eRequestVote do (payload: tRequestVote) {
            if (currentTerm < payload.term) {
                becomeFollower(payload.term);
            } else {
                send payload.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }

        on eHeartbeatTimeout do {
            leaderCommits();
            broadcastAppendEntries();
        }

        on eAppendEntries do (payload: tAppendEntries) {
            if (payload.term > currentTerm && logUpToDateCheck(payload.prevLogIndex, payload.prevLogTerm)) {
                currentTerm = payload.term;
                handleAppendEntries(payload);
                becomeFollower(payload.term);
            } else if (payload.term < currentTerm) {
                // send payload.leader, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
                send payload.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=false, matchedIndex=-1);
                leaderCommits();
            }
        }

        on eAppendEntriesReply do (payload: tAppendEntriesReply) {
            if (payload.term < currentTerm) {
                return;
            }
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                votedFor = null as Server;
                leader = null as Server;
                goto Follower;
            }
            if (payload.success) {
                nextIndex[payload.sender] = payload.matchedIndex + 1;
                matchIndex[payload.sender] = payload.matchedIndex;
                leaderCommits();
            } else {
                // rejected because of log mismatch
                // now, payload.matchedIndex is the index of the (potentially) first mismatched term
                assert payload.matchedIndex >= 0, "matchedIndex should be non-negative";
                nextIndex[payload.sender] = payload.matchedIndex;
            }
        }

        on eClientRequest do (payload: tClientRequest) {
            var newEntry: tServerLog;
            var target: Server;
            var entries: seq[tServerLog];
            var i: int;
            // print format("Received client request {0}", payload);
            if (payload.cmd.op == GET) {
                print format("Server processed (by {0}) request {1}", this, payload);
                // For simplicity, we assume reliable delivery to the client
                // Network failures are easy to handle in this case, though
                send payload.client, eRaftResponse, (client=payload.client,
                                                     transId=payload.transId,
                                                     result=execute(kvStore, payload.cmd).result);
            } else {
                newEntry = (term=currentTerm, command=payload.cmd, client=payload.client, transId=payload.transId);
                if (!(newEntry in logs)) {
                    logs += (sizeof(logs), newEntry);
                }
                print format("Current logs: {0}", logs);
                // use info of nextIndex and matchIndex to broadcast to peers
                foreach (target in peers) {
                    if (target != this && nextIndex[target] < sizeof(logs)) {
                        entries = default(seq[tServerLog]);
                        i = nextIndex[target];
                        while (i < sizeof(logs)) {
                            entries += (i - nextIndex[target], logs[i]);
                            i = i + 1;
                        }
                        send target, eAppendEntries, (term=currentTerm,
                                                    leader=this,
                                                    prevLogIndex=nextIndex[target] - 1,
                                                    prevLogTerm=getLogTerm(logs, nextIndex[target] - 1),
                                                    entries=entries,
                                                    leaderCommit=commitIndex);
                    }
                }
            }
            leaderCommits();
        }

        on eReset do {
            reset();
        }

        on eInjectError do {
            announce eBecomeLeader, (term=currentTerm, leader=this);
        }

        ignore eRequestVoteReply, eElectionTimeout;
    }

    state FinishedServing {
        entry {
            print format("{0} is shutting down", this);
            // send electionTimer, eShutdown;
            // send heartbeatTimer, eShutdown;
        }
        ignore eShutdown, eRequestVote, eRequestVoteReply, eAppendEntries, eAppendEntriesReply, eClientRequest, eHeartbeatTimeout, eElectionTimeout;
    }

    fun forwardedRequest(req: tClientRequest): tClientRequest {
        return (transId=req.transId, client=req.client, cmd=req.cmd, sender=this);
    }

    fun handleRequestVote(reply: tRequestVote) {
        leader = null as Server;
        if (reply.term < currentTerm) {
            send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
        } else {
            currentTerm = reply.term;
            if ((votedFor == null as Server || votedFor == reply.candidate)
                    && logUpToDateCheck(reply.lastLogIndex, reply.lastLogTerm)) {
                votedFor = reply.candidate;
                send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=true);
            } else {
                send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }
    }

    fun handleAppendEntries(resp: tAppendEntries) {
        var myLastIndex: int;
        var myLastTerm: int;
        var ptr: int;
        var mismatchedTerm: int;
        var i: int;
        var j: int;
        if (resp.term < currentTerm) {
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, matchedIndex=-1);
        } else if (sizeof(logs) <= resp.prevLogIndex) {
            // If the log is very outdated
            leader = resp.leader;
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=false, matchedIndex=sizeof(logs));
        } else if (resp.prevLogIndex >= 0 && logs[resp.prevLogIndex].term != resp.prevLogTerm) {
            // Log consistency check failed here;
            // search for the first occurence of the mismatched
            // term and notify the leader.
            leader = resp.leader;
            ptr = resp.prevLogIndex;
            mismatchedTerm = logs[ptr].term;
            while (ptr > 0 && logs[ptr].term == mismatchedTerm) {
                ptr = ptr - 1;
            }
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, matchedIndex=ptr);
        } else {
            // Check if any entries disagree; delete all entries after it.
            leader = resp.leader;
            i = resp.prevLogIndex + 1;
            j = 0;
            while (i < sizeof(logs) && j < sizeof(resp.entries)) {
                if (logs[i].term != resp.entries[j].term) {
                    break;
                }
                i = i + 1;
                j = j + 1;
            }
            while (i < sizeof(logs)) {
                logs -= (lastLogIndex(logs));
            }
            // Append entries
            j = 0;
            while (j < sizeof(resp.entries)) {
                logs += (resp.prevLogIndex + 1 + j, resp.entries[j]);
                j = j + 1;
            }
            print format("{0}: leaderCommit={1} commitIndex={2}", this, resp.leaderCommit, commitIndex);
            if (resp.leaderCommit > commitIndex) {
                if (resp.leaderCommit > lastLogIndex(logs)) {
                    commitIndex = lastLogIndex(logs);
                } else {
                    commitIndex = resp.leaderCommit;
                }
            }
            print format("{0}'s log after AppendEntries: {1}", this, logs);
            executeCommands();
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=true, matchedIndex=lastLogIndex(logs));
        }
    }
    
    fun broadcastAppendEntries() {
        var target: Server;
        var i: int;
        var j: int;
        var prevIndex: int;
        var prevTerm: int;
        var entries: seq[tServerLog];
        assert this == leader, "Only leader can broadcast AppendEntries";
        print format("Broadcasting AppendEntries with log {0}", logs);
        foreach (target in peers) {
            if (this != target) {
                entries = default(seq[tServerLog]);
                prevIndex = nextIndex[target] - 1;
                if (prevIndex >= 0 && prevIndex < sizeof(logs)) {
                    prevTerm = logs[prevIndex].term;
                } else {
                    prevTerm = 0;
                }
                if (nextIndex[target] < sizeof(logs)) {
                    // if the current lead has something to send (nextIndex within range of logs)
                    i = 0;
                    j = nextIndex[target];
                    while (j < sizeof(logs)) {
                        entries += (i, logs[j]);
                        i = i + 1;
                        j = j + 1;
                    }
                    print format("Entries for {0} is {1}", target, entries);
                    send target, eAppendEntries, (term=currentTerm,
                                                    leader=this,
                                                    prevLogIndex=prevIndex,
                                                    prevLogTerm=prevTerm,
                                                    entries=entries,
                                                    leaderCommit=commitIndex);
                } else {
                    // send empty heartbeat
                    send target, eAppendEntries, (term=currentTerm,
                                                    leader=this,
                                                    prevLogIndex=prevIndex,
                                                    prevLogTerm=prevTerm,
                                                    entries=entries,
                                                    leaderCommit=commitIndex);

                }
            }
        }
        // restartTimer(heartbeatTimer);
    }

    fun leaderCommits() {
        var execResult: ExecutionResult;
        var nextCommit: int; // the next commit index
        var validMatchIndices: int; // the number of match indices that are greater than or equal to nextCommit
        var i: int;
        var target: Server;
        assert this == leader, "Only leader can execute the log on its own";
        // iteratively search for that index
        nextCommit = lastLogIndex(logs);
        print format("{0} state; nextCommit={1} commitIndex={2} matchIndex={3}", this, nextCommit, commitIndex, matchIndex);
        while (nextCommit > commitIndex) {
            // counting itself first
            validMatchIndices = 1;
            foreach (target in peers) {
                if (target == this) {
                    continue;
                }
                if (matchIndex[target] >= nextCommit && logs[nextCommit].term == currentTerm) {
                    validMatchIndices = validMatchIndices + 1;
                }
            }
            if (validMatchIndices > clusterSize / 2) {
                break;
            }
            nextCommit = nextCommit - 1;
        }
        commitIndex = nextCommit;
        while (lastApplied < commitIndex) {
            lastApplied = lastApplied + 1;
            execResult = execute(kvStore, logs[lastApplied].command);
            kvStore = execResult.newState;
            print format("Server committed and processed (by {0}), log: {1}", this, logs[lastApplied]);
            send logs[lastApplied].client, eRaftResponse, (client=logs[lastApplied].client, transId=logs[lastApplied].transId, result=execResult.result);
        }
    }

    fun executeCommands() {
        print format("{0}: commitIndex={1} lastApplied={2}", this, commitIndex, lastApplied);
        while (commitIndex > lastApplied) {
            lastApplied = lastApplied + 1;
            kvStore = execute(kvStore, logs[lastApplied].command).newState;
        }
    }

    fun logUpToDateCheck(lastIndex: int, lastTerm: int): bool {
        if (lastTerm > lastLogTerm(logs)) {
            return true;
        }
        if (lastTerm < lastLogTerm(logs)) {
            return false;
        }
        return lastIndex >= lastLogIndex(logs);
    }

    fun becomeFollower(term: int) {
        // cancelTimer(electionTimer);
        currentTerm = term;
        goto Follower;
    }

    fun reset() {
        commitIndex = -1;
        lastApplied = -1;
        nextIndex = fillMap(this, nextIndex, peers, 0);
        matchIndex = fillMap(this, matchIndex, peers, -1);
        goto Follower;
    }
}