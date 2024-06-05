// Some utility functions
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

fun lastLogIndex(log: seq[tServerLog]): int {
    return sizeof(log) - 1;
}

fun lastLogTerm(log: seq[tServerLog]): int {
    if (sizeof(log) == 0) {
        return 0;
    } else {
        return log[sizeof(log) - 1].term;
    }
}

fun fillMap(m: map[Server, int], servers: set[Server], value: int): map[Server, int] {
    var server: Server;
    foreach(server in servers) {
        m[server] = value;
    }
    return m;
}

fun broadcastRequest(self: Server, peers: set[Server], e: event, payload: any) {
    var peer: Server;
    foreach(peer in peers) {
        if (peer != self) {
            send peer, e, payload;
        }
    }
}

fun broadcastAppendEntries(self: Server, currentTerm: int, commitIndex:int, logs: seq[tServerLog], peers: set[Server], nextIndex: map[Server, int]) {
    var target: Server;
    var i: int;
    var j: int;
    var prevIndex: int;
    var prevTerm: int;
    var entries: seq[tServerLog];
    foreach (target in peers) {
        if (self != target) {
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
                                                leader=self,
                                                prevLogIndex=prevIndex,
                                                prevLogTerm=prevTerm,
                                                entries=entries,
                                                leaderCommit=commitIndex);
            } else {
                // send empty heartbeat
                send target, eAppendEntries, (term=currentTerm,
                                                leader=self,
                                                prevLogIndex=prevIndex,
                                                prevLogTerm=prevTerm,
                                                entries=entries,
                                                leaderCommit=commitIndex);
            }
        }
    }
}
