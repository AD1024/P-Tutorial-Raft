event eEntryApplied: (index: int, log: tServerLog);

spec SafetyStateMachine observes eEntryApplied {
    var appliedEntries: map[int, tServerLog];
    start state MonitorEntryApplied {
        entry {
            appliedEntries = default(map[int, tServerLog]);
        }

        on eEntryApplied do (payload: (index: int, log: tServerLog)) {
            if (!(payload.index in keys(appliedEntries))) {
                appliedEntries[payload.index] = payload.log;
            }
            assert appliedEntries[payload.index] == payload.log,
                format("Entry@{0}={1} applied before does not match with {2}", payload.index, appliedEntries[payload.index], payload.log);
        }
    }
} 