type tRequestMetadata = (client: machine, transId: int);

spec LivenessProgress observes eClientWaitingResponse, eClientGotResponse {
    var clientRequests: set[tRequestMetadata];

    start state Init {
        entry {
            clientRequests = default(set[tRequestMetadata]);
            goto Done;
        }
    }

    hot state PendingRequestsExist {

        // entry {
        //     print format("Exists pending requests {0}", clientRequests);
        // }

        on eClientWaitingResponse do (payload: tRequestMetadata) {
            clientRequests += ((client=payload.client, transId=payload.transId));
            // print format("Received Request{0} | Remaining={1}", payload, clientRequests);
        }

        on eClientGotResponse do (payload: tRequestMetadata) {
            clientRequests -= ((client=payload.client, transId=payload.transId));
            // print format("Processed {0} | Remaining={1}", payload, clientRequests);
            if (sizeof(clientRequests) == 0) {
                goto Done;
            }
        }

    }

    cold state Done {
        on eClientWaitingResponse do (payload: tRequestMetadata) {
            clientRequests += ((client=payload.client, transId=payload.transId));
            goto PendingRequestsExist;
        }
    }
}