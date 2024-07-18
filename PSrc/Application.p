enum Op { 
    PUT,
    GET
}
type KeyT = int;
type ValueT = int;
type Command = (op: Op, key: KeyT, value: ValueT);
type Result = (success: bool, value: ValueT);
type ExecutionResult = (newState: KVStore, result: Result);
type KVStore = map[KeyT, ValueT];

fun IsPut(op: Op): bool {
    return op == PUT;
}

fun IsGet(op: Op): bool {
    return op == GET;
}

fun newStore(): KVStore {
    return default(KVStore);
}

fun execute(store: KVStore, command: Command): ExecutionResult {
    if (command.op == PUT) {
        store[command.key] = command.value;
        return (newState=store, result=(success=true, value=-1));
    }
    if (command.op == GET) {
        if (!(command.key in store)) {
            return (newState=store, result=(success=false, value=-1));
        }
        return (newState=store, result=(success=true, value=store[command.key]));
    }
    assert false, "unreachable";
}