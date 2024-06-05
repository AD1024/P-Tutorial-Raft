spec SafetySynchronization observes eClientRequest, eRaftResponse {
    var localKVStore: KVStore;
    var requestResultMap: map[Client, map[int, Result]];

    start state Init {
        entry {
            localKVStore = newStore();
            requestResultMap = default(map[Client, map[int, Result]]);
            goto Listening;
        }
    }

    state Listening {
        on eClientRequest do (payload: tClientRequest) {
            if (!(payload.client in keys(requestResultMap))) {
                requestResultMap[payload.client] = default(map[int, Result]);
            }
            requestResultMap[payload.client][payload.transId] = execute(localKVStore, payload.cmd).result;
        }

        on eRaftResponse do (payload: tRaftResponse) {
            assert requestResultMap[payload.client][payload.transId] == payload.result;
        }
    }
}