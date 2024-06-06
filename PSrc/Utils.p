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

fun getLogTerm(log: seq[tServerLog], index: int): int {
    if (index < 0 || index >= sizeof(log)) {
        return 0;
    } else {
        return log[index].term;
    }
}

fun lastLogTerm(log: seq[tServerLog]): int {
    if (sizeof(log) == 0) {
        return 0;
    } else {
        return log[sizeof(log) - 1].term;
    }
}

fun fillMap(m: map[machine, int], servers: set[machine], value: int): map[machine, int] {
    var server: machine;
    foreach(server in servers) {
        m[server] = value;
    }
    return m;
}

fun broadcastRequest(self: Server, peers: set[machine], e: event, payload: any) {
    var peer: machine;
    foreach(peer in peers) {
        if (peer != self) {
            send peer, e, payload;
        }
    }
}
