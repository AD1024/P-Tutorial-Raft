type ServerId = int;
type tRaftResponse = (client: Client, transId: int, result: any);
event eRaftResponse: tRaftResponse;

event eServerInit: (myId: ServerId, cluster: set[Server]);

type tRequestVote = (term: int, candidate: Server, lastLogIndex: int, lastLogTerm: int);
event eRequestVote: tRequestVote;
type tRequestVoteReply = (sender: Server, term: int, voteGranted: bool);
event eRequestVoteReply: tRequestVoteReply;

type tAppendEntries = (term: int, leader: Server, prevLogIndex: int,
                       prevLogTerm: int, entries: seq[tServerLog], leaderCommit: int);
event eAppendEntries: tAppendEntries;

type tAppendEntriesReply = (sender: Server, term: int, success: bool, firstIndexUnmatched: int);
event eAppendEntriesReply: tAppendEntriesReply;

event eReset;

type tServerLog = (term: int, command: Command);
// AppendEntries
type tAppendEntriesRequest = (
    sender: ServerId,
    term: int,
    prevLogIndex: int,
    logs: seq[tServerLog]
);

machine Server {
    var serverId: ServerId;
    var kvStore: KVStore;
    var leader: Server;
    var clusterSize: int;
    var peers: set[Server];

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

    var electionTimer: Timer;

    start state Init {
        entry {}
        on eServerInit do (setup: (myId: ServerId, cluster: set[Server])) {
            kvStore = newStore();
            serverId = setup.myId;
            clusterSize = sizeof(setup.cluster);
            peers = setup.cluster;
            nextIndex = default(map[Server, int]);
            matchIndex = default(map[Server, int]);
            votesReceived = default(set[Server]);
            logs = default(seq[tServerLog]);

            currentTerm = 0;
            votedFor = null as Server;
            commitIndex = -1;
            lastApplied = -1;
            leader = null as Server;
            electionTimer = new Timer(this);
            goto Follower;
        }
        ignore eReset;
    }

    state Follower {
        entry {
            restartTimer(electionTimer, 150 + choose(150));
        }

        on eReset do {
            reset();
        }

        on eRequestVote do (payload: tRequestVote) {
            handleRequestVote(payload);
        }

        on eClientRequest do (payload: tClientRequest) {
            if (leader != this && leader != null) {
                send leader, eClientRequest, payload;
            }
        }

        on eAppendEntries do (payload: tAppendEntries) {
            restartTimer(electionTimer, 150 + choose(150));
        }

        on eTimerTimeout goto Candidate;

        ignore eRequestVoteReply, eAppendEntriesReply;
    }

    state Candidate {
        entry {
            var peer: Server;
            var lastTerm: int;
            cancelTimer(electionTimer);
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
            startTimer(electionTimer, 150 + choose(150));
        }

        on eAppendEntries do (payload: tAppendEntries) {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                goto Follower;
            }
        }

        on eRequestVoteReply do (payload: tRequestVoteReply) {
            if (payload.term > currentTerm) {
                currentTerm = payload.term;
                goto Follower;
            } else if (payload.voteGranted) {
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
            }
        }

        on eReset do {
            reset();
        }

        on eTimerTimeout do {
            goto Candidate;
        }

        ignore eClientRequest;
    }

    state Leader {
        entry {
            leader = this;
            nextIndex = fillMap(nextIndex, peers, lastLogIndex(logs) + 1);
            matchIndex = fillMap(matchIndex, peers, 0);
            restartTimer(electionTimer, 50);
            announce eBecomeLeader, (term=currentTerm, leader=this);
            broadcastAppendEntries();
        }

        on eRequestVote do (payload: tRequestVote) {
            if (currentTerm < payload.term) {
                becomeFollower(payload.term);
            } else {
                send payload.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }

        on eTimerTimeout do {
            broadcastAppendEntries();
        }

        on eAppendEntries do (payload: tAppendEntries) {
            if (payload.term > currentTerm && logUpToDateCheck(payload.prevLogIndex, payload.prevLogTerm)) {
                becomeFollower(payload.term);
            } else if (payload.term < currentTerm) {
                send payload.leader, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
            }
        }

        on eClientRequest do (payload: tClientRequest) {
            var newEntry: tServerLog;
            var target: Server;
            var entries: seq[tServerLog];
            var i: int;
            if (payload.cmd.op == GET) {
                send payload.client, eRaftResponse, (client=payload.client, transId=payload.transId, result=execute(kvStore, payload.cmd).result);
            } else {
                newEntry = (term=currentTerm, command=payload.cmd);
                if (!(newEntry in logs)) {
                    logs += (lastLogIndex(logs) + 1, newEntry);
                }
                // use info of nextIndex and matchIndex to broadcast to peers
                foreach (target in peers) {
                    if (target != this && nextIndex[target] <= lastLogIndex(logs)) {
                        entries = default(seq[tServerLog]);
                        i = nextIndex[target];

                    }
                }
            }
        }

        on eReset do {
            reset();
        }

        ignore eRequestVoteReply;
    }

    fun handleRequestVote(reply: tRequestVote) {
        leader = null as Server;
        if (reply.term < currentTerm) {
            send reply.candidate, eRequestVoteReply, (sender=this, term=currentTerm, voteGranted=false);
        } else {
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
        if (resp.term > currentTerm) {
            becomeFollower(resp.term);
        } else if (resp.term < currentTerm) {
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, firstIndexUnmatched=-1);
        } else if (sizeof(logs) <= resp.prevLogIndex) {
            // If the log is very outdated
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=false, firstIndexUnmatched=sizeof(logs)); 
        } else if (logs[resp.prevLogIndex].term != resp.prevLogTerm) {
            // Log consistency check failed here;
            // search for the first occurence of the mismatched
            // term and notify the leader.
            ptr = resp.prevLogIndex;
            mismatchedTerm = logs[ptr].term;
            while (ptr > 0 && logs[ptr].term == mismatchedTerm) {
                ptr = ptr - 1;
            }
            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm,
                                                    success=false, firstIndexUnmatched=ptr);
        } else {
            // Check if any entries disagree; delete all entries after it.
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
                logs[resp.prevLogIndex + 1 + j] = resp.entries[j];
                j = j + 1;
            }
            if (resp.leaderCommit > commitIndex) {
                if (resp.leaderCommit > lastLogIndex(logs)) {
                    commitIndex = lastLogIndex(logs);
                } else {
                    commitIndex = resp.leaderCommit;
                }
            }
            executeCommands();

            send resp.leader, eAppendEntriesReply, (sender=this, term=currentTerm, success=true, firstIndexUnmatched=lastLogIndex(logs) + 1);
        }

        announce eAppendEntriesRecv, (mylog=logs,);

    }
    
    fun broadcastAppendEntries() {

        var target: Server;
        var i: int;
        var j: int;
        var prevIndex: int;
        var prevTerm: int;
        var entries: seq[tServerLog];
        assert this == leader, "Only leader can broadcast AppendEntries";
        foreach (target in peers) {
            if (this != target) {
                entries = default(seq[tServerLog]);
                prevIndex = nextIndex[target] - 1;
                if (prevIndex >= 0) {
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
        announce eAppendEntriesSent, (mylog=logs,);

    }

    fun executeCommands() {
        while (commitIndex > lastApplied) {
            lastApplied = lastApplied + 1;
            execute(kvStore, logs[lastApplied].command);
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
        cancelTimer(electionTimer);
        currentTerm = term;
        goto Follower;
    }

    fun reset() {
        commitIndex = 0;
        lastApplied = -1;
        nextIndex = fillMap(nextIndex, peers, 0);
        matchIndex = fillMap(matchIndex, peers, 0);
        goto Follower;
    }
}