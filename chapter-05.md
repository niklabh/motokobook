# Chapter 5: Identity and Access Control

Decentralized applications cannot rely on centralized username/password databases. They must utilize cryptographic primitives.

### 5.1 Internet Identity and Principals

The Internet Computer uses **Principals**—textual representations of public keys (e.g., `2vxsx-fae...`)—as the universal user ID. To prevent user tracking across the ecosystem, the Internet Computer introduces **Internet Identity (II)**.

II uses Chain Key Cryptography to generate a unique "pseudonym" Principal for the user for each Dapp they visit. This prevents OpenPatron from colluding with other Dapps to build a profile of user behavior.

### 5.2 The Frontend-Backend Handshake

Authentication occurs on the frontend. The user logs in via the Internet Identity canister. The frontend receives an `Identity` object, which it uses to sign all subsequent HTTP requests to the backend canister.

On the backend (Motoko), the actor receives the message. The system validates the signature and exposes the authenticated user via `msg.caller`.

To demonstrate these concepts in a production context, we will architect **OpenPatron**, a decentralized content monetization platform. This application requires robust Identity, Tokenomics, and Subscription logic. Its code can be found at [https://github.com/niklabh/motokobook/tree/main/OpenPatron](https://github.com/niklabh/motokobook/tree/main/OpenPatron)

**Code Implementation: The WhoAmI Pattern**

This pattern is essential for verifying that the authentication flow is functioning correctly.

```js
import Principal "mo:base/Principal";

actor OpenPatron {
    // Define a public shared function that accepts a message context (msg)
    public shared (msg) func whoami() : async Text {
        // msg.caller is the cryptographically authenticated Principal
        return Principal.toText(msg.caller);
    };
}
```

### 5.3 Storing User Profiles

We need a scalable way to map these Principals to user data.

-   **Naive Approach:** Use a `List` or `Array`. (O(n) lookup time—disastrous for scaling).
    
-   **Standard Approach:** Use `HashMap`. (O(1) lookup, but harder to persist securely in legacy stable memory).
    
-   **Recommended Approach:** Use `TrieMap` or `RBTree`. These structures are deterministic and easier to serialize for stable storage, or use `StableBTreeMap` for direct stable memory storage.
    

**Table 2: Data Structure Selection Guide**

| Data Structure | Access Time | Upgrade Safety (Legacy) | Recommended Use Case |
|---------------|-------------|------------------------|---------------------|
| **Array** | O(1) | High | Small, fixed configurations. |
| **HashMap** | O(1) | Low (Rehashing cost) | Temporary caches, non-critical data. |
| **TrieMap** | O(log N) | Medium | General user directories. |
| **StableBTreeMap** | O(log N) | Ultra-High | Massive datasets (Users, Transactions). |

### 5.4 Implementing User Profiles

For storing user profiles in OpenPatron, we'll use `StableBTreeMap` from the base library for efficient and upgrade-safe storage.

Here's how to set it up:

```js
import Principal "mo:base/Principal";
import StableBTreeMap "mo:base/StableBTreeMap";
import Text "mo:base/Text";
import Option "mo:base/Option";

actor OpenPatron {
    type Profile = {
        username: Text;
        bio: ?Text;
        // Add more fields like createdAt, etc.
    };

    stable var users : StableBTreeMap.StableBTreeMap<Principal, Profile> = StableBTreeMap.init(Principal.equal, Principal.hash);

    public shared(msg) func register(username: Text, bio: ?Text) : async Bool {
        let caller = msg.caller;
        switch (users.get(caller)) {
            case (?_) { return false; }; // Already registered
            case null {
                let profile : Profile = { username; bio };
                users.insert(caller, profile);
                return true;
            };
        };
    };

    public shared(msg) func getProfile() : async ?Profile {
        users.get(msg.caller);
    };

    public query func getProfileByPrincipal(p: Principal) : async ?Profile {
        users.get(p);
    };
};
```

This allows users to register a profile associated with their Principal.

### 5.5 Access Control Patterns

To ensure only authenticated users can perform certain actions, check against the anonymous Principal.

```js
import Error "mo:base/Error";
import Principal "mo:base/Principal";

func requireAuthenticated(caller: Principal) {
    if (Principal.isAnonymous(caller)) {
        throw Error.reject("Anonymous access not allowed");
    };
};

// Example usage
public shared(msg) func createContent() : async () {
    requireAuthenticated(msg.caller);
    // Proceed with content creation
};
```

### 5.6 Roles and Permissions

In OpenPatron, users can have roles like 'patron', 'creator', or 'admin'. Extend the Profile type:

```js
type Role = { #Patron; #Creator; #Admin };

type Profile = {
    username: Text;
    bio: ?Text;
    role: Role;
};

// In register, set default role, e.g., #Patron

// Function to check role
func requireRole(caller: Principal, required: Role) {
    switch (users.get(caller)) {
        case (?profile) {
            if (profile.role != required) {
                throw Error.reject("Insufficient permissions");
            };
        };
        case null {
            throw Error.reject("User not registered");
        };
    };
};

// Usage
public shared(msg) func adminFunction() : async () {
    requireAuthenticated(msg.caller);
    requireRole(msg.caller, #Admin);
    // Admin logic
};
```

### 5.7 Security Considerations

- **Principal Privacy**: Never log or expose Principals unnecessarily to prevent correlation attacks.
- **Delegation Chains**: Use short-lived delegations for sessions to minimize exposure.
- **Upgrade Safety**: Always use stable variables for critical data.
- **Input Validation**: Sanitize all user inputs to prevent injection attacks.
- **Rate Limiting**: Implement canister-level rate limiting to prevent DDoS.

These practices ensure robust identity management in your Dapp.

### 5.8 Frontend Integration

While this book focuses on Motoko backend, identity requires frontend coordination. Use the `@dfinity/auth-client` library in your JavaScript/TypeScript frontend.

Example login flow:

```javascript
import { AuthClient } from "@dfinity/auth-client";

const authClient = await AuthClient.create();
await authClient.login({
    identityProvider: "https://identity.ic0.app",
    onSuccess: () => {
        const identity = authClient.getIdentity();
        // Use identity to create an actor for your canister
    }
});
```

This handles the delegation and signing for backend calls.

For anonymous access, create an actor with the anonymous identity.

### 5.9 Complete OpenPatron Identity Implementation

Putting it all together, here's a more complete actor for OpenPatron's identity system, incorporating profiles, roles, and access controls. We've added profile update and role assignment functions.

```js
import Principal "mo:base/Principal";
import StableBTreeMap "mo:base/StableBTreeMap";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Error "mo:base/Error";
import Time "mo:base/Time";

actor OpenPatron {
    type Role = { #Patron; #Creator; #Admin };

    type Profile = {
        username: Text;
        bio: ?Text;
        role: Role;
        createdAt: Time.Time;
    };

    stable var users : StableBTreeMap.StableBTreeMap<Principal, Profile> = StableBTreeMap.init(Principal.equal, Principal.hash);
    stable var contents : StableBTreeMap.StableBTreeMap<Principal, [Text]> = StableBTreeMap.init(Principal.equal, Principal.hash);

    // Helper functions
    func requireAuthenticated(caller: Principal) {
        if (Principal.isAnonymous(caller)) {
            throw Error.reject("Anonymous access not allowed");
        };
    };

    func requireRole(caller: Principal, required: Role) {
        switch (users.get(caller)) {
            case (?profile) {
                if (profile.role != required) {
                    throw Error.reject("Insufficient permissions");
                };
            };
            case null {
                throw Error.reject("User not registered");
            };
        };
    };

    // Whoami for testing
    public shared (msg) func whoami() : async Text {
        return Principal.toText(msg.caller);
    };

    // Register new user
    public shared(msg) func register(username: Text, bio: ?Text) : async Bool {
        let caller = msg.caller;
        requireAuthenticated(caller);
        switch (users.get(caller)) {
            case (?_) { return false; }; // Already registered
            case null {
                let profile : Profile = {
                    username;
                    bio;
                    role = #Patron; // Default role
                    createdAt = Time.now();
                };
                users.insert(caller, profile);
                return true;
            };
        };
    };

    // Get own profile
    public shared(msg) func getProfile() : async ?Profile {
        requireAuthenticated(msg.caller);
        users.get(msg.caller);
    };

    // Get profile by principal (public query, but could be restricted)
    public query func getProfileByPrincipal(p: Principal) : async ?Profile {
        users.get(p);
    };

    // Update profile
    public shared(msg) func updateProfile(newUsername: ?Text, newBio: ?Text) : async Bool {
        let caller = msg.caller;
        requireAuthenticated(caller);
        switch (users.get(caller)) {
            case (?profile) {
                let updated : Profile = {
                    username = Option.get(newUsername, profile.username);
                    bio = if (newBio == null) { profile.bio } else { newBio };
                    role = profile.role;
                    createdAt = profile.createdAt;
                };
                users.insert(caller, updated);
                return true;
            };
            case null { return false; };
        };
    };

    // Assign role (admin only)
    public shared(msg) func assignRole(target: Principal, newRole: Role) : async () {
        requireAuthenticated(msg.caller);
        requireRole(msg.caller, #Admin);
        switch (users.get(target)) {
            case (?profile) {
                let updated : Profile = {
                    profile with role = newRole;
                };
                users.insert(target, updated);
            };
            case null {
                throw Error.reject("Target user not registered");
            };
        };
    };

    // Example protected function: Create content (creators only)
    public shared(msg) func createContent(content: Text) : async () {
        requireAuthenticated(msg.caller);
        requireRole(msg.caller, #Creator);
        
        switch (contents.get(msg.caller)) {
            case (?userContents) {
                let updated = Array.append(userContents, [content]);
                contents.insert(msg.caller, updated);
            };
            case null {
                contents.insert(msg.caller, [content]);
            };
        };
    };
};

```

This actor provides a solid foundation for OpenPatron's identity system, ready to integrate with tokenomics in the next chapter.

### 5.10 Testing and Deployment

- **Local Testing**: Use `dfx deploy` and test with `dfx canister call OpenPatron whoami` (expect anonymous principal). Integrate with a frontend for full auth flow.
- **Mainnet Deployment**: Ensure your canister has enough cycles. Use Internet Identity for production auth.
- **Common Pitfalls**: Forgetting to handle anonymous callers, not using stable storage, or exposing sensitive Principal data.
- **Best Practice**: Implement unit tests for all functions, especially guards.

With this, the identity component of OpenPatron is complete, providing secure user management for the platform.

---

