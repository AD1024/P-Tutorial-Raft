enum Op { 
    PUT,
    GET
}
type Command = (op: Op, key: string, value: any);
type Result = (success: bool, value: any);
type KVStore = map[string, any];

fun newStore(): KVStore {
    return default(KVStore);
}

fun execute(store: KVStore, command: Command): Result {
    if (command.op == PUT) {
        assert command.value != null;
        store[command.key] = command.value;
        return (success=true, value=null);
    }
    if (command.op == GET) {
        if (!(command.key in store)) {
            return (success=false, value=null);
        }
        return (success=true, value=store[command.key]);
    }
    assert false, "unreachable";
}