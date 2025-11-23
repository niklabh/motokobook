## Chapter 10: Frontend Integration & Asset Storage

A "Full-Stack" dapp on the Internet Computer is truly full-stack: both the backend logic and the frontend assets (HTML, CSS, JS) are hosted on-chain. This eliminates the need for AWS, Vercel, or Netlify, making your application censorship-resistant and unstoppable.

### 10.1 The Asset Canister

The standard way to host a frontend is using the **Asset Canister**. This is a pre-built canister provided by DFINITY that is optimized for serving static files.

#### Configuration

In your `dfx.json`, you define a frontend canister:

```json
{
  "canisters": {
    "openpatron_backend": {
      "main": "src/openpatron_backend/main.mo",
      "type": "motoko"
    },
    "openpatron_frontend": {
      "dependencies": [
        "openpatron_backend"
      ],
      "source": [
        "src/openpatron_frontend/dist"
      ],
      "type": "assets",
      "workspace": "openpatron_frontend"
    }
  }
}
```

When you run `dfx deploy`, the SDK:
1.  Builds your frontend (e.g., `npm run build`).
2.  Uploads the contents of the `dist` folder to the Asset Canister.
3.  Configures the canister to serve `index.html` for unknown routes (SPA routing).

### 10.2 Connecting Frontend to Backend

Your frontend needs to talk to your backend canister. The `dfx` build process automatically generates **Actor Declarations**—TypeScript bindings for your Motoko code.

#### Using the Generated Declarations

```typescript
// src/openpatron_frontend/src/index.ts

import { openpatron_backend } from "../../declarations/openpatron_backend";

async function init() {
  // Call a public query function
  const profile = await openpatron_backend.getMyProfile();
  
  if (profile.length > 0) {
    console.log("User is logged in:", profile[0]);
  } else {
    console.log("User is anonymous");
  }
}

init();
```

This type-safe bridge ensures that if you change your Motoko API, your frontend build will fail until you update the client code.

### 10.3 Certified Variables and Security

When you visit a website like `google.com`, your browser checks the TLS certificate to ensure the server is authentic. On the Internet Computer, we don't rely on a central Certificate Authority (CA). Instead, we use **Chain Key Cryptography**.

#### How it Works

1.  **Certification**: The subnet signs the root hash of the canister's state tree.
2.  **Service Worker**: When you load a canister URL (`https://<canister-id>.ic0.app`), a Service Worker is installed in your browser.
3.  **Verification**: The Service Worker intercepts network requests, fetches the content *and* a certificate (merkle proof). It verifies the signature against the subnet's public key.

If the verification fails, the Service Worker rejects the content. This guarantees that the frontend you see is exactly what the canister served, preventing "Man-in-the-Middle" attacks.

#### Certified Assets

The standard Asset Canister handles this automatically. Every file uploaded is hashed and added to the certified state tree.

#### Certified Data in Motoko

If you want to serve dynamic data securely (e.g., an API endpoint), you must manually certify it using `CertifiedData`.

```motoko
import CertifiedData "mo:base/CertifiedData";
import Blob "mo:base/Blob";

actor {
    // 1. Store data
    var myData : Blob = Blob.fromText("Hello Secure World");

    // 2. Update the certificate when data changes
    public func updateData(newData : Text) {
        myData := Blob.fromText(newData);
        
        // Set the certified data (32-byte hash)
        CertifiedData.set(sha256(myData));
    };
    
    // 3. Serve the data with the certificate
    // (Usually done via http_request, not a query call)
}
```

### 10.4 Custom Domains

While `ic0.app` domains are functional, production apps need custom domains (e.g., `openpatron.com`).

1.  **Register Domain**: Buy your domain.
2.  **Configure DNS**: Add a CNAME record pointing to the Internet Computer boundary nodes.
3.  **Add Domain to Canister**: Use the `ic-asset` tool or a `boundary_nodes` configuration file to map the domain to your canister.

This process ensures that even with a custom domain, the Service Worker verification still protects your users.

### 10.5 Summary

With the frontend deployed to an Asset Canister, OpenPatron is now a complete **dapp**:
-   **Backend**: Motoko canister handling logic, data, and money.
-   **Frontend**: React/Vue/Svelte app served from an Asset Canister.
-   **Security**: End-to-end verification via Certified Variables.

We have built the application. Now, we must look at the ecosystem tools that will help us maintain and scale it.

---
