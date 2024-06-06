type tRequestMetadata = (client: machine, transId: int);

spec LivenessProgress observes eClientRequest, eRaftResponse {
    var clientRequests: set[tRequestMetadata];
    var responded: set[tRequestMetadata];

    start state Init {
        entry {
            clientRequests = default(set[tRequestMetadata]);
            responded = default(set[tRequestMetadata]);
            goto Done;
        }
    }

    hot state PendingRequestsExist {

        // entry {
        //     print format("Exists pending requests {0}", clientRequests);
        // }

        on eClientRequest do (payload: tClientRequest) {
            if (!((client=payload.client, transId=payload.transId) in responded)) {
                clientRequests += ((client=payload.client, transId=payload.transId));
            }
            // print format("Received Request{0} | Remaining={1}", payload, clientRequests);
        }

        on eRaftResponse do (payload: tRaftResponse) {
            clientRequests -= ((client=payload.client, transId=payload.transId));
            responded += ((client=payload.client, transId=payload.transId));
            // print format("Processed {0} | Remaining={1}", payload, clientRequests);
            if (sizeof(clientRequests) == 0) {
                goto Done;
            }
        }

    }

    cold state Done {
        on eClientRequest do (payload: tClientRequest) {
            clientRequests += ((client=payload.client, transId=payload.transId));
            goto PendingRequestsExist;
        }
    }
}