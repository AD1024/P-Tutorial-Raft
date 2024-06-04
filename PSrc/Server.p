type ServerId = int;
type tRaftResponse = (success: bool, result: any);
event eRaftResponse: tRaftResponse;

type tRequestVote = (term: int, candidate: Server, lastLogIndex: int, lastLogTerm: int);
event eRequestVote: tRequestVote;
type tRequestVoteReply = (term: int, voteGranted: bool);
event eRequestVoteReply: tRequestVoteReply;

type tAppendEntries = (term: int, leader: Server, prevLogIndex: int,
                       prevLogTerm: int, entries: seq[tServerLog], leaderCommit: int);
event eAppendEntries: tAppendEntries;

enum CmdStatus {
    ACCEPTED,
    COMITTED
}

type tServerLog = (term: int, command: Command, status: CmdStatus);
// AppendEntries
type tAppendEntriesRequest = (
    sender: ServerId,
    term: int,
    prevLogIndex: int,
    logs: seq[tServerLog]
);

fun startTimer(timer: Timer, timeout: int) {
    send timer, eStartTimer, timeout;
}

fun cancelTimer(timer: Timer) {
    send timer, eCancelTimer;
}

fun restartTimer(timer: Timer, timeout: int) {
    cancelTimer(timer);
    startTimer(timer, timeout);
}

fun lastIndex(log: seq[tServerLog]): int {
    return sizeof(log);
}

fun broadcastRequest(self: Server, peers: set[Server], e: event, payload: any) {
    var peer: Server;
    foreach(peer in peers) {
        if (peer != self) {
            send peer, e, payload;
        }
    }
}

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
        entry (setup: (myId: ServerId, cluster: set[Server])) {
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
    }

    state Follower {
        entry {
            restartTimer(electionTimer, 150 + choose(150));
        }

        on eRequestVote do (payload: tRequestVote) {
            if (currentTerm <= payload.term && votedFor == null as Server) {
                // TODO: log up-to-date check
                send payload.candidate, eRequestVoteReply, (term=currentTerm, voteGranted=true);
                restartTimer(electionTimer, 150 + choose(150));
            } else {
                send payload.candidate, eRequestVoteReply, (term=currentTerm, voteGranted=false);
            }
        }

        on eAppendEntries do (payload: tAppendEntries) {
            restartTimer(electionTimer, 150 + choose(150));
        }

        on eTimerTimeout do {
            goto Candidate;
        }
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
                if (sizeof(logs) == 0) {
                    lastTerm = 0;
                } else {
                    lastTerm = logs[-1].term;
                }
                foreach (peer in peers) {
                    if (peer != this) {
                        send peer, eRequestVote,
                            (term=currentTerm,
                             candidate=this,
                             lastLogIndex=sizeof(logs),
                             lastLogTerm=lastTerm);
                    }
                }
            }
        }
        
        on eRequestVote do (payload: tRequestVote)  {
            send payload.candidate, eRequestVoteReply, (term=currentTerm, voteGranted=false);
        }
    }

    state Leader {
        entry {
            var heartBeat: tAppendEntries;
            leader = this;
            heartBeat = (term=currentTerm, leader=this,
                prevLogIndex=0, prevLogTerm=1,
                entries=default(seq[tServerLog]),
                leaderCommit=0);
            // nextIndex
            restartTimer(electionTimer, 50);
            broadcastRequest(this, peers, eAppendEntries, heartBeat);
        }

        on eTimerTimeout do {
            var heartBeat: tAppendEntries;
            heartBeat = (term=currentTerm, leader=this,
                prevLogIndex=0, prevLogTerm=1,
                entries=default(seq[tServerLog]),
                leaderCommit=0);
            broadcastRequest(this, peers, eAppendEntries, heartBeat);
            startTimer(electionTimer, 50);
        }
    }
}