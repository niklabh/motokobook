## Chapter 9: External Integrations

The Internet Computer is unique among blockchains in its ability to interact directly with the outside world without relying on centralized bridges or oracles. This capability, known as **Chain Key Cryptography**, enables two revolutionary features: **HTTP Outcalls** and **Native Bitcoin Integration**.

In this chapter, we will extend OpenPatron to interact with Web2 APIs and the Bitcoin network, transforming it from an isolated silo into a connected platform.

### 9.1 HTTP Outcalls

Traditionally, blockchains are deterministic closed systems. They cannot just "fetch a URL" because every node in the network must agree on the result. If one node fetches a price of $100 and another fetches $101, consensus fails.

The Internet Computer solves this with **HTTP Outcalls**. When a canister makes an HTTP request:
1.  The request is sent by all nodes in the subnet.
2.  The responses are collected and **consensus** is reached on the result.
3.  The canonical response is returned to the canister.

#### Making a GET Request

Let's add a feature to OpenPatron to verify a creator's identity using a Web2 API (e.g., checking a GitHub profile).

```js
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Debug "mo:base/Debug";

// Import the Management Canister (virtual actor)
import IC "mo:base/ExperimentalInternetComputer";

actor OpenPatron {

    // Define the HTTP Header type
    type HttpHeader = {
        name : Text;
        value : Text;
    };

    // Define the HTTP Response type
    type HttpResponse = {
        status : Nat;
        headers : [HttpHeader];
        body : Blob;
    };

    // Define the HTTP Request type
    type HttpRequest = {
        url : Text;
        method : Text; // "GET", "POST", "HEAD"
        headers : [HttpHeader];
        body : ?Blob;
        transform : ?{
            function : shared query (HttpResponse) -> async HttpResponse;
            context : Blob;
        };
    };

    public func verifyGitHubProfile(username : Text) : async Bool {
        let url = "https://api.github.com/users/" # username;
        
        let request : HttpRequest = {
            url = url;
            method = "GET";
            headers = [
                { name = "User-Agent"; value = "OpenPatron-Canister" }
            ];
            body = null;
            // Transformation is crucial for consensus!
            transform = ?{
                function = transformResponse;
                context = Blob.fromArray([]);
            };
        };

        try {
            // 20 billion cycles is a safe baseline for HTTP outcalls
            let cycles = 20_000_000_000; 
            let response : HttpResponse = await IC.http_request(request) with { cycles = cycles };
            
            if (response.status == 200) {
                return true;
            } else {
                return false;
            };
        } catch (e) {
            Debug.print("Error: " # Error.message(e));
            return false;
        };
    };

    // The transform function strips non-deterministic fields (like timestamps)
    // so nodes can reach consensus on the response.
    public query func transformResponse(raw : HttpResponse) : async HttpResponse {
        return {
            status = raw.status;
            headers = []; // Headers often contain timestamps/nonces, so we drop them
            body = raw.body;
        };
    };
};
```

> [!IMPORTANT]
> **Consensus & Idempotency**: The `transform` function is mandatory if the API response varies slightly between nodes (e.g., timestamps). It sanitizes the response to ensure bit-wise equality across replicas.

#### Making a POST Request (Idempotency Keys)

When sending data (POST), you must ensure the external server handles duplicate requests gracefully, as multiple nodes may send the request. Always use **Idempotency Keys**.

```js
    public func sendNotification(message : Text) : async () {
        let url = "https://api.webhook.site/...";
        
        // Generate a unique key for this specific action
        let idempotencyKey = "req_" # Int.toText(Time.now());

        let request : HttpRequest = {
            url = url;
            method = "POST";
            headers = [
                { name = "Content-Type"; value = "application/json" },
                { name = "Idempotency-Key"; value = idempotencyKey }
            ];
            body = ?Text.encodeUtf8("{\"text\": \"" # message # "\"}");
            transform = null; // POST usually returns simple confirmations
        };
        
        // ... send request ...
    };
```

### 9.2 Native Bitcoin Integration

The Internet Computer integrates directly with the Bitcoin network. Canisters can hold BTC addresses, receive funds, and sign transactions without a private key (using **Threshold ECDSA**).

#### The Bitcoin API

The Management Canister exposes the Bitcoin API.

```js
    type BitcoinNetwork = { #mainnet; #testnet };
    
    type Satoshi = Nat64;

    type OutPoint = {
        txid : Blob;
        vout : Nat32;
    };

    type Utxo = {
        outpoint : OutPoint;
        value : Satoshi;
        height : Nat32;
    };

    // Management Canister Interface for Bitcoin
    // (Simplified for brevity)
    let BITCOIN_API_FEE : Nat = 10_000_000_000; // Cycles
```

#### Generating a Bitcoin Address

Your canister can derive a Bitcoin address for itself (or for each user).

```js
    public func getBitcoinAddress(userPrincipal : Principal) : async Text {
        // Derive a unique path for the user
        let derivationPath = [ Blob.toArray(Principal.toBlob(userPrincipal)) ];
        
        let address = await IC.bitcoin_get_p2pkh_address({
            network = #testnet;
            derivation_path = derivationPath;
        });
        
        return address;
    };
```

#### Sending Bitcoin

Sending Bitcoin involves:
1.  Getting the current balance/UTXOs.
2.  Building a transaction.
3.  Signing it with Threshold ECDSA.
4.  Broadcasting it.

This is complex to implement manually. In production, use a library like `motoko-bitcoin` or the **ckBTC** (Chain Key Bitcoin) standard.

### 9.3 ckBTC: The Practical Solution

While native Bitcoin integration is powerful, it is slow (Bitcoin block times) and expensive (Bitcoin fees). **ckBTC** is an ICRC-1 token on ICP that is 1:1 backed by real BTC.

For OpenPatron, we should use **ckBTC** for payments:
1.  **Fast**: 1-2 second finality.
2.  **Cheap**: Negligible fees.
3.  **Standard**: Works with all ICRC-1 tools (like the Ledger code we wrote in Chapter 6).

Users can deposit real BTC to the ckBTC minter, which mints ckBTC to their principal. OpenPatron then just handles it like any other token.

### 9.4 Summary

By leveraging HTTP Outcalls and Bitcoin integration, OpenPatron becomes a "World Computer" application:
-   **Verifiable**: Check Web2 identities via API.
-   **Connected**: Trigger Web2 webhooks.
-   **Financial**: Accept the world's hardest money (BTC) directly or via ckBTC.

In the next chapter, we will solve the final piece of the puzzle: the Frontend.

---
