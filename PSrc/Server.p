type ServerId = int;
type tRaftResponse = (success: bool, result: any);
event eRaftResponse: tRaftResponse;

type tRequestVote = (term: int, candidateId: ServerId, lastLogIndex: int, lastLogTerm: int);
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

machine Server {
    var serverId: ServerId;
    var kvStore: KVStore;
    var leaderId: ServerId;

    // Leader state (volatile)
    var nextIndex: map[ServerId, int];
    var matchIndex: map[ServerId, int];

    // Leader state (persistent)
    var currentTerm: int;
    var logs: seq[tServerLog];
    var votedFor: ServerId;

    // all servers
    var commitIndex: int;
    var lastApplied: int;

    var electionTimer: Timer;    

    start state Init {
        entry (setup: (myId: ServerId, cluster: set[Server])) {
            kvStore = newStore();
            serverId = setup.myId;
            nextIndex = default(map[ServerId, int]);
            matchIndex = default(map[ServerId, int]);

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

        on eTimerTimeout do {
            goto Candidate;
        }
    }

    state Candidate {
        entry {
            
        }
    }
}