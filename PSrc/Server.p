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
event eAppendEntriesReply: tAppendEntriesReply;
event eReset;

event eViewChangedFollower: Server;
event eViewChangedLeader: Server;
event eViewChangedCandidate: Server;

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
    var viewServer: View;

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

    var role: string;
    var logNotifyTimestamp: int;

    // var heartbeatTimer: Timer;
    var clientRequestQueue: seq[tClientRequest];

    start state Init {
        entry {}
        on eServerInit do (setup: (myId: ServerId, cluster: set[Server], viewServer: View)) {
            kvStore = newStore();
            serverId = setup.myId;
            assert this in setup.cluster, "Server should be in the cluster";
            clusterSize = sizeof(setup.cluster);
            peers = setup.cluster;
            nextIndex = default(map[Server, int]);
            matchIndex = default(map[Server, int]);
            votesReceived = default(set[Server]);
            logs = default(seq[tServerLog]);
            clientRequestQueue = default(seq[tClientRequest]);
            viewServer = setup.viewServer;

            currentTerm = 0;
            logNotifyTimestamp = 0;
            votedFor = null as Server;
            commitIndex = -1;
            lastApplied = -1;
            leader = null as Server;
            role = "Uninitialized";
            // electionTimer = new Timer((user=this, timeoutEvent=eElectionTimeout));
            // heartbeatTimer = new Timer((user=this, timeoutEvent=eHeartbeatTimeout));
            goto Follower;
        }
        ignore eReset, eElectionTimeout, eHeartbeatTimeout;
    }

    state Follower {
        entry {
            role = "F";
            leader = null as Server;
            printLog("Become follower");
            send viewServer, eViewChangedFollower, this;
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
            if (payload.term >= currentTerm) {
                printLog(format("heartbeat updated term from {0} to {1}", currentTerm, payload.term));
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

        on eElectionTimeout do {
            printLog("Election timeout");
            goto Candidate;
        }

        on eHeartbeatTimeout do {
            notifyViewLog();
        }

        ignore eRequestVoteReply, eAppendEntriesReply;
    }

    state Candidate {
        entry {
            var peer: Server;
            var lastTerm: int;
            role = "C";
            printLog("Become candidate");
            // cancelTimer(electionTimer);
            send viewServer, eViewChangedCandidate, this;
            currentTerm = currentTerm + 1;
            votedFor = null as Server;
            votesReceived = default(set[Server]);
            votesReceived += (this);
            if (sizeof(votesReceived) > clusterSize / 2) {
                goto Leader;
            } else {
                printLog(format("RequestVote with term {0}", currentTerm));
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
                printLog(format("Received heartbeat from a leader with higher term {0}", payload.term));
                currentTerm = payload.term;
                votedFor = null as Server;
                handleAppendEntries(payload);
                goto Follower;
            } else {
                printLog(format("Received smaller term heartbeat from {0}", payload.leader));
                handleAppendEntries(payload);
            }
        }

        on eAppendEntriesReply do (payload: tAppendEntriesReply) {
            if (payload.term > currentTerm) {
                printLog(format("Received AppendEntriesReply with higher term {0}", payload.term));
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
                printLog(format("vote granted by {0}; now vote={1}", payload.sender, votesReceived));
                if (sizeof(votesReceived) > clusterSize / 2) {
                    printLog(format("majority votes: {0}", votesReceived));
                    goto Leader;
                }
            } else {
                printLog(format("Received rejection/invalid reply: {0}", payload));
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

        on eHeartbeatTimeout do {
            notifyViewLog();
        }
    }

    state Leader {
        entry {
            role = "L";
            send viewServer, eViewChangedLeader, this;
            leader = this;
            nextIndex = fillMap(this, nextIndex, peers, sizeof(logs));
            matchIndex = fillMap(this, matchIndex, peers, -1);
            // restartTimer(heartbeatTimer);
            announce eBecomeLeader, (term=currentTerm, leader=this);
            while (sizeof(clientRequestQueue) > 0) {
                send this, eClientRequest, forwardedRequest(clientRequestQueue[0]);
                clientRequestQueue -= (0);
            }
            printLog(format("Become leader with Log={0}, commiteIndex={1}, lastApplied={2}", logs, commitIndex, lastApplied));
            broadcastAppendEntries();
        }

        on eShutdown do {
            goto FinishedServing;
        }

        on eRequestVote do (payload: tRequestVote) {
            if (currentTerm < payload.term) {
                printLog(format("Saw higher term as a leader: currentTerm={0}, payload.term={1}", currentTerm, payload.term));
                handleRequestVote(payload);
                becomeFollower(payload.term);
            } else {
                printLog(format("Reject proposal from {0} with term {1}", payload.candidate, payload.term));
                send payload.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }

        on eRequestVoteReply do (payload: tRequestVoteReply) {
            if (payload.term > currentTerm) {
                printLog(format("received RequestVoteReply with higher term {0}", payload.term));
                currentTerm = payload.term;
                votedFor = null as Server;
                leader = null as Server;
                goto Follower;
            }
        }

        on eHeartbeatTimeout do {
            broadcastAppendEntries();
            leaderCommits();
            notifyViewLog();
        }

        on eAppendEntries do (payload: tAppendEntries) {
            if (payload.term > currentTerm) {
                printLog(format("received AppendEntries with higher term {0}; handle then step down", payload.term));
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
            // print format("Leader({0}) received AppendEntriesReply from {1}: {2}", this, payload.sender, payload);
            printLog(format("Leader({0}, {1}) received AppendEntriesReply from {2}: {3}", this, currentTerm, payload.sender, payload));
            if (payload.term < currentTerm) {
                printLog("Ignore AppendEntriesReply with outdated term");
                return;
            }
            if (payload.term > currentTerm) {
                printLog(format("received reply from another leader with term {0} > currentTerm {1}", payload.term, currentTerm));
                currentTerm = payload.term;
                votedFor = null as Server;
                leader = null as Server;
                goto Follower;
            }
            if (payload.success) {
                printLog(format("entries accepted by {0}; matchIndex={1}", payload.sender, payload.matchedIndex));
                nextIndex[payload.sender] = Max(nextIndex[payload.sender], payload.matchedIndex + 1);
                matchIndex[payload.sender] = Max(matchIndex[payload.sender], payload.matchedIndex);
                leaderCommits();
            } else {
                // rejected because of log mismatch
                // now, payload.matchedIndex is the index of the (potentially) first mismatched term
                printLog(format("re-sync with {0} at index {1}", payload.sender, payload.matchedIndex));
                assert payload.matchedIndex >= 0, "matchedIndex should be non-negative";
                nextIndex[payload.sender] = Min(payload.matchedIndex, nextIndex[payload.sender]);
            }
        }

        on eClientRequest do (payload: tClientRequest) {
            var newEntry: tServerLog;
            var target: Server;
            var entries: seq[tServerLog];
            var i: int;
            // print format("Received client request {0}", payload);
            if (payload.cmd.op == GET) {
                // printLog(format("Leader received GET request from {0} with {1}", payload.client, payload));
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
                printLog(format("Current leader logs={0}", logs));
                printLog(format("nextIndex={0}, matchIndex={1}", nextIndex, matchIndex));
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

        ignore eElectionTimeout;
    }

    state FinishedServing {
        entry {
            printLog("Service ended. Shutdown.");
        }
        ignore eShutdown, eRequestVote, eRequestVoteReply, eAppendEntries, eAppendEntriesReply, eClientRequest, eHeartbeatTimeout, eElectionTimeout;
    }

    fun forwardedRequest(req: tClientRequest): tClientRequest {
        return (transId=req.transId, client=req.client, cmd=req.cmd, sender=this);
    }

    fun handleRequestVote(reply: tRequestVote) {
        leader = null as Server;
        if (reply.term < currentTerm) {
            printLog(format("Reject vote with term {0} < currentTerm {1}", reply.term, currentTerm));
            send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
        } else {
            currentTerm = reply.term;
            if ((votedFor == null as Server || votedFor == reply.candidate)
                    && logUpToDateCheck(reply.lastLogIndex, reply.lastLogTerm)) {
                printLog(format("Grant vote to {0}", reply.candidate));
                votedFor = reply.candidate;
                send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=true);
            } else {
                printLog(format("Reject vote with votedFor={0} and logUpToDate={1}", votedFor, logUpToDateCheck(reply.lastLogIndex, reply.lastLogTerm)));
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
        printLog(format("Received AppendEntries({0}) from Leader({1}) with {2}; currentTerm={3}, log={4}", resp.entries, resp.leader, resp, currentTerm, logs));
        if (resp.term < currentTerm) {
            printLog(format("Reject AppendEntries with term {0} < currentTerm {1}", resp.term, currentTerm));
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, matchedIndex=-1);
        } else if (sizeof(logs) <= resp.prevLogIndex) {
            // If the log is very outdated
            leader = resp.leader;
            printLog(format("prevLogIndex={0} is out of range of sizeof(log)={1}", resp.prevLogIndex, sizeof(logs)));
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=false, matchedIndex=sizeof(logs));
        } else if (resp.prevLogIndex >= 0 && logs[resp.prevLogIndex].term != resp.prevLogTerm) {
            // Log consistency check failed here;
            // search for the first occurence of the mismatched
            // term and notify the leader.
            printLog(format("Log inconsistency at index {0}: log[i].term={1} v.s. prevTerm={2}", resp.prevLogIndex, logs[resp.prevLogIndex].term, resp.prevLogTerm));
            leader = resp.leader;
            ptr = resp.prevLogIndex;
            mismatchedTerm = logs[ptr].term;
            while (ptr > 0 && logs[ptr].term == mismatchedTerm) {
                ptr = ptr - 1;
            }
            printLog(format("requesting sync. log terms={0}, mismatchedTerm={1}, prevLogIndex={2}, ptr={3}", termsOfLos(), mismatchedTerm, resp.prevLogIndex, ptr));
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, matchedIndex=ptr);
        } else {
            // Check if any entries disagree; delete all entries after it.
            printLog(format("Sync log with log={0} at index {1}. Entries={2}", logs, resp.prevLogIndex + 1, resp.entries));
            leader = resp.leader;
            i = resp.prevLogIndex + 1;
            j = 0;
            printLog(format("Before sync: logs={0}", logs));
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
            printLog(format("Inconsistency removal: logs={0}", logs));
            // Append entries
            j = 0;
            while (j < sizeof(resp.entries)) {
                if (!(resp.entries[j] in logs)) {
                    logs += (resp.prevLogIndex + 1 + j, resp.entries[j]);
                } else {
                    assert resp.entries[j] == logs[resp.prevLogIndex + 1 + j], "Inconsistent log entry";
                }
                j = j + 1;
            }
            printLog(format("After sync: logs={0}, leaderCommit={1}, commitIndex={2}", logs, resp.leaderCommit, commitIndex));
            if (resp.leaderCommit > commitIndex) {
                if (resp.leaderCommit > lastLogIndex(logs)) {
                    commitIndex = lastLogIndex(logs);
                } else {
                    commitIndex = resp.leaderCommit;
                }
            }
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
        printLog(format("state: nextCommit={0} commitIndex={1} matchIndex={2}", nextCommit, commitIndex, matchIndex));
        while (nextCommit > commitIndex) {
            // counting itself first
            validMatchIndices = 1;
            foreach (target in peers) {
                if (target == this) {
                    continue;
                }
                if (matchIndex[target] >= nextCommit) {
                    validMatchIndices = validMatchIndices + 1;
                }
            }
            if (validMatchIndices > clusterSize / 2 && logs[nextCommit].term == currentTerm) {
                commitIndex = nextCommit;
                break;
            }
            if (commitIndex == nextCommit) {
                break;
            }
            nextCommit = nextCommit - 1;
        }
        // commitIndex = nextCommit;
        printLog(format("leader commits decision: matchIndex={0} commitIndex={1} currentTerm={2} logs={3}", matchIndex, commitIndex, currentTerm, logs));
        while (lastApplied < commitIndex) {
            lastApplied = lastApplied + 1;
            execResult = execute(kvStore, logs[lastApplied].command);
            kvStore = execResult.newState;
            printLog(format("leader committed and processed (by {0}), log: {1}", this, logs[lastApplied]));
            send logs[lastApplied].client, eRaftResponse, (client=logs[lastApplied].client, transId=logs[lastApplied].transId, result=execResult.result);
        }
    }

    fun printLog(msg: string) {
        print format("{0}[{1}@{2}]: {3}", role, this, currentTerm, msg);
    }

    fun executeCommands() {
        printLog(format("commitIndex={0} lastApplied={1}", commitIndex, lastApplied));
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

    fun notifyViewLog() {
        logNotifyTimestamp = logNotifyTimestamp + 1;
        send viewServer, eNotifyLog, (timestamp=logNotifyTimestamp, server=this, log=logs);
    }

    fun becomeFollower(term: int) {
        // cancelTimer(electionTimer);
        currentTerm = term;
        goto Follower;
    }

    fun termsOfLos(): seq[int] {
        var terms: seq[int];
        var i: int;
        terms = default(seq[int]);
        i = 0;
        while (i < sizeof(logs)) {
            terms += (sizeof(terms), logs[i].term);
            i = i + 1;
        }
        return terms;
    }

    fun reset() {
        commitIndex = -1;
        lastApplied = -1;
        nextIndex = fillMap(this, nextIndex, peers, 0);
        matchIndex = fillMap(this, matchIndex, peers, -1);
        goto Follower;
    }
}