type ServerId = int;
type tRaftResponse = (success: bool, result: any);
event eRaftResponse: tRaftResponse;

type tRequestVote = (term: int, candidate: machine, lastLogIndex: int, lastLogTerm: int);
event eRequestVote: tRequestVote;
type tRequestVoteReply = (term: int, voteGranted: bool);
event eRequestVoteReply: tRequestVoteReply;

type tAppendEntries = (term: int, leaderId: ServerId, prevLogIndex: int,
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

fun lastIndex(log: seq[tServerLog]): int {
    return sizeof(log);
}

machine Server {
    var serverId: ServerId;
    var kvStore: KVStore;
    var leaderId: ServerId;
    var clusterSize: int;
    var peers: set[Server];

    // Leader state (volatile)
    var nextIndex: map[ServerId, int];
    var matchIndex: map[ServerId, int];

    // Leader state (persistent)
    var currentTerm: int;
    var logs: seq[tServerLog];

    var votedFor: ServerId;
    var votesReceived: set[ServerId];

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
            nextIndex = default(map[ServerId, int]);
            matchIndex = default(map[ServerId, int]);
            votesReceived = default(set[ServerId]);
            logs = default(seq[tServerLog]);

            currentTerm = 0;
            votedFor = -1;
            commitIndex = -1;
            lastApplied = -1;
            leaderId = -1;
            electionTimer = new Timer(this);
            goto Follower;
        }
    }

    state Follower {
        entry {
            cancelTimer(electionTimer);
            startTimer(electionTimer, 150 + choose(150));
        }

        on eRequestVote do (payload: tRequestVote) {
            if (currentTerm <= payload.term && votedFor == -1) {
                // TODO: log up-to-date check
                send payload.candidate, eRequestVoteReply, (term=currentTerm, voteGranted=true);
                cancelTimer(electionTimer);
                startTimer(electionTimer, 150 + choose(150));
            } else {
                send payload.candidate, eRequestVoteReply, (term=currentTerm, voteGranted=false);
            }
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
            votedFor = serverId;
            votesReceived = default(set[ServerId]);
            votesReceived += (serverId);
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

        }
    }
}