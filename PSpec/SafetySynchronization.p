spec SafetySynchronization observes eClientRequest, eRaftResponse {
    var localKVStore: KVStore;
    var requestResultMap: map[Client, map[int, Result]];
    var requestSeq: seq[Command];
    var seenId: map[Client, set[int]];
    var respondedId : map[Client, set[int]];

    start state Init {
        entry {
            localKVStore = newStore();
            requestResultMap = default(map[Client, map[int, Result]]);
            requestSeq = default(seq[Command]);
            seenId = default(map[Client, set[int]]);
            respondedId = default(map[Client, set[int]]);
            goto Listening;
        }
    }

    state Listening {
        on eClientRequest do (payload: tClientRequest) {
            var execResult: ExecutionResult;
            if (!(payload.client in keys(seenId))) {
                seenId[payload.client] = default(set[int]);
            }
            if (!(payload.client in keys(respondedId))) {
                respondedId[payload.client] = default(set[int]);
            }
            if (payload.client == payload.sender && !(payload.transId in seenId[payload.client])) {
                seenId[payload.client] += (payload.transId);
                requestSeq += (sizeof(requestSeq), payload.cmd);
                if (!(payload.client in keys(requestResultMap))) {
                    requestResultMap[payload.client] = default(map[int, Result]);
                }
                execResult = execute(localKVStore, payload.cmd);
                requestResultMap[payload.client][payload.transId] = execResult.result;
                localKVStore = execResult.newState;
            }
            // print format("Forwarded request monitored {0}", payload);
        }

        on eRaftResponse do (payload: tRaftResponse) {
            if (!(payload.client in keys(respondedId))) {
                respondedId[payload.client] += (payload.transId);
                assert requestResultMap[payload.client][payload.transId] == payload.result, format("Expected {0} but got {1}; request history: {2}", requestResultMap[payload.client][payload.transId], payload.result, requestSeq);
            }
        }
    }
}