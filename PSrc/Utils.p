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

fun fillMap(m: map[Server, int], servers: set[Server], value: int) {
    var server: Server;
    foreach(server in servers) {
        m[server] = value;
    }
}

fun broadcastRequest(self: Server, peers: set[Server], e: event, payload: any) {
    var peer: Server;
    foreach(peer in peers) {
        if (peer != self) {
            send peer, e, payload;
        }
    }
}
