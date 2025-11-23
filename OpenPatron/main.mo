// OpenPatron: A Decentralized Content Monetization Platform
// Complete Implementation from "Mastering Motoko" Book

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Error "mo:base/Error";
import Time "mo:base/Time";
import Timer "mo:base/Timer";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";

actor OpenPatron {
    
    // ========================================
    // TYPES
    // ========================================
    
    type Role = { #Patron; #Creator; #Admin };
    
    type Profile = {
        username: Text;
        bio: ?Text;
        role: Role;
        createdAt: Time.Time;
    };
    
    type SubscriptionId = Nat32;
    type Timestamp = Int;
    
    type Subscription = {
        patron: Principal;
        creator: Principal;
        cadence: Int;          // nanoseconds between invoices
        nextCharge: Timestamp;
        amount: Nat;
        active: Bool;
    };
    
    // ICRC-1 Ledger Types
    type Account = { 
        owner: Principal; 
        subaccount: ?Blob 
    };
    
    type TransferArgs = {
        to: Account;
        fee: ?Nat;
        memo: ?Blob;
        from_subaccount: ?Blob;
        created_at_time: ?Nat64;
        amount: Nat;
    };
    
    type TransferResult = { 
        #Ok: Nat; 
        #Err: TransferError 
    };
    
    type TransferError = {
        #BadFee: { expected_fee: Nat };
        #BadBurn: { min_burn_amount: Nat };
        #InsufficientFunds: { balance: Nat };
        #TooOld;
        #CreatedInFuture: { ledger_time: Nat64 };
        #TemporarilyUnavailable;
        #Duplicate: { duplicate_of: Nat };
        #GenericError: { error_code: Nat; message: Text };
    };
    
    type LogLevel = { #info; #warning; #error };
    
    type LogEntry = {
        timestamp: Time.Time;
        level: LogLevel;
        message: Text;
    };
    
    // ========================================
    // STATE
    // ========================================
    
    // User Management
    private stable var usersEntries: [(Principal, Profile)] = [];
    private var users = HashMap.HashMap<Principal, Profile>(10, Principal.equal, Principal.hash);
    
    // Balances (Virtual Accounting)
    private stable var balancesEntries: [(Principal, Nat)] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(10, Principal.equal, Principal.hash);
    
    // Subscriptions
    private stable var nextSubscriptionId: SubscriptionId = 0;
    private stable var subscriptionsEntries: [(SubscriptionId, Subscription)] = [];
    private var subscriptions = HashMap.HashMap<SubscriptionId, Subscription>(10, Nat32.equal, func(n: Nat32): Nat32 { n });
    
    // Economics
    private let PLATFORM_FEE_PERCENT: Nat = 1;
    private stable var treasuryBalance: Nat = 0;
    private let MINIMUM_CYCLES: Nat = 1_000_000_000_000; // 1T cycles
    private let CYCLES_REFILL_THRESHOLD: Nat = 2_000_000_000_000; // 2T cycles
    
    // Logging
    private stable var logs: [LogEntry] = [];
    private let logBuffer = Buffer.Buffer<LogEntry>(100);
    
    // Timer Configuration
    private let SUBSCRIPTION_CHECK_INTERVAL: Nat64 = 86_400_000_000_000; // 1 day in nanoseconds
    private stable var timerId: ?Timer.TimerId = null;
    
    // Ledger Integration (example using ICRC-1)
    // Replace with actual ledger canister ID in production
    private let ledgerId = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");
    private let ledger = actor(Principal.toText(ledgerId)): actor {
        icrc1_transfer: (TransferArgs) -> async TransferResult;
        icrc1_balance_of: (Account) -> async Nat;
    };
    
    // ========================================
    // HELPER FUNCTIONS
    // ========================================
    
    private func requireAuthenticated(caller: Principal) {
        if (Principal.isAnonymous(caller)) {
            throw Error.reject("Anonymous access not allowed");
        };
    };
    
    private func requireRole(caller: Principal, required: Role) {
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
    
    private func log(level: LogLevel, message: Text) {
        let entry: LogEntry = {
            timestamp = Time.now();
            level = level;
            message = message;
        };
        
        logBuffer.add(entry);
        Debug.print("[" # debug_show(level) # "] " # message);
        
        // Keep buffer size manageable
        if (logBuffer.size() > 1000) {
            ignore logBuffer.remove(0);
        };
    };
    
    private func getBalance(user: Principal): Nat {
        switch (balances.get(user)) {
            case (?bal) { bal };
            case null { 0 };
        };
    };
    
    // Deterministic subaccount derivation for deposits
    private func supporterSubaccount(user: Principal): Blob {
        let namespace = "OpenPatron";
        let input = Text.encodeUtf8(namespace) # Principal.toBlob(user);
        // In production, use proper SHA256 hashing
        // For now, using simplified approach
        Blob.fromArray(Array.tabulate<Nat8>(32, func(i) { 0 }))
    };
    
    // ========================================
    // IDENTITY & ACCESS CONTROL (Chapter 5)
    // ========================================
    
    public shared(msg) func whoami(): async Text {
        return Principal.toText(msg.caller);
    };
    
    public shared(msg) func register(username: Text, bio: ?Text): async Bool {
        let caller = msg.caller;
        requireAuthenticated(caller);
        
        switch (users.get(caller)) {
            case (?_) { 
                log(#warning, "User already registered: " # Principal.toText(caller));
                return false; 
            };
            case null {
                let profile: Profile = {
                    username;
                    bio;
                    role = #Patron; // Default role
                    createdAt = Time.now();
                };
                users.put(caller, profile);
                log(#info, "New user registered: " # username);
                return true;
            };
        };
    };
    
    public shared(msg) func getProfile(): async ?Profile {
        requireAuthenticated(msg.caller);
        users.get(msg.caller);
    };
    
    public query func getProfileByPrincipal(p: Principal): async ?Profile {
        users.get(p);
    };
    
    public shared(msg) func updateProfile(newUsername: ?Text, newBio: ?Text): async Bool {
        let caller = msg.caller;
        requireAuthenticated(caller);
        
        switch (users.get(caller)) {
            case (?profile) {
                let updated: Profile = {
                    username = Option.get(newUsername, profile.username);
                    bio = if (newBio == null) { profile.bio } else { newBio };
                    role = profile.role;
                    createdAt = profile.createdAt;
                };
                users.put(caller, updated);
                log(#info, "Profile updated: " # updated.username);
                return true;
            };
            case null { return false; };
        };
    };
    
    public shared(msg) func assignRole(target: Principal, newRole: Role): async () {
        requireAuthenticated(msg.caller);
        requireRole(msg.caller, #Admin);
        
        switch (users.get(target)) {
            case (?profile) {
                let updated: Profile = {
                    profile with role = newRole;
                };
                users.put(target, updated);
                log(#info, "Role assigned to " # Principal.toText(target));
            };
            case null {
                throw Error.reject("Target user not registered");
            };
        };
    };
    
    // ========================================
    // TOKENOMICS & LEDGER (Chapter 6)
    // ========================================
    
    public shared(msg) func getDepositAddress(): async Text {
        requireAuthenticated(msg.caller);
        let subaccount = supporterSubaccount(msg.caller);
        // Return formatted deposit address
        return Principal.toText(Principal.fromActor(OpenPatron)) # "-" # debug_show(subaccount);
    };
    
    public shared(msg) func notifyDeposit(expected: Nat): async Result.Result<Nat, Text> {
        requireAuthenticated(msg.caller);
        
        let account: Account = { 
            owner = Principal.fromActor(OpenPatron); 
            subaccount = ?Blob.toArray(supporterSubaccount(msg.caller)) 
        };
        
        try {
            let balance = await ledger.icrc1_balance_of(account);
            
            if (balance >= expected) {
                // Credit internal balance
                let currentBalance = getBalance(msg.caller);
                balances.put(msg.caller, currentBalance + balance);
                log(#info, "Deposit verified: " # debug_show(balance));
                return #ok(balance);
            } else {
                return #err("Insufficient balance on ledger");
            };
        } catch (e) {
            log(#error, "Deposit verification failed: " # Error.message(e));
            return #err("Ledger query failed");
        };
    };
    
    public query func getBalance(user: Principal): async Nat {
        switch (balances.get(user)) {
            case (?bal) { bal };
            case null { 0 };
        };
    };
    
    public shared(msg) func withdraw(amount: Nat): async Result.Result<(), Text> {
        let user = msg.caller;
        requireAuthenticated(user);
        
        let currentBal = getBalance(user);
        
        if (currentBal < amount) {
            return #err("Insufficient funds");
        };
        
        // OPTIMISTIC ACCOUNTING: Update state BEFORE await
        balances.put(user, currentBal - amount);
        
        let args: TransferArgs = {
            to = { owner = user; subaccount = null };
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            amount = amount;
        };
        
        try {
            let result = await ledger.icrc1_transfer(args);
            
            switch (result) {
                case (#Ok(_)) {
                    log(#info, "Withdrawal successful: " # debug_show(amount));
                    return #ok();
                };
                case (#Err(err)) {
                    // Rollback on failure
                    let newBal = getBalance(user);
                    balances.put(user, newBal + amount);
                    log(#error, "Withdrawal failed, refunded");
                    return #err("Transfer failed");
                };
            };
        } catch (e) {
            // Rollback on exception
            let newBal = getBalance(user);
            balances.put(user, newBal + amount);
            log(#error, "Withdrawal exception: " # Error.message(e));
            return #err("Transfer exception");
        };
    };
    
    // ========================================
    // SUBSCRIPTIONS (Chapter 7)
    // ========================================
    
    public shared(msg) func subscribe(
        creator: Principal, 
        amount: Nat, 
        cadenceNanoseconds: Int
    ): async Result.Result<SubscriptionId, Text> {
        requireAuthenticated(msg.caller);
        
        // Verify patron has sufficient balance
        let patronBalance = getBalance(msg.caller);
        if (patronBalance < amount) {
            return #err("Insufficient balance for subscription");
        };
        
        // Create subscription
        let subId = nextSubscriptionId;
        nextSubscriptionId += 1;
        
        let subscription: Subscription = {
            patron = msg.caller;
            creator = creator;
            cadence = cadenceNanoseconds;
            nextCharge = Time.now() + cadenceNanoseconds;
            amount = amount;
            active = true;
        };
        
        subscriptions.put(subId, subscription);
        log(#info, "Subscription created: #" # debug_show(subId));
        
        return #ok(subId);
    };
    
    public shared(msg) func cancelSubscription(subId: SubscriptionId): async Result.Result<(), Text> {
        requireAuthenticated(msg.caller);
        
        switch (subscriptions.get(subId)) {
            case (?sub) {
                if (sub.patron != msg.caller) {
                    return #err("Not authorized to cancel this subscription");
                };
                
                let updated: Subscription = {
                    sub with active = false
                };
                subscriptions.put(subId, updated);
                log(#info, "Subscription cancelled: #" # debug_show(subId));
                return #ok();
            };
            case null {
                return #err("Subscription not found");
            };
        };
    };
    
    public query func getSubscription(subId: SubscriptionId): async ?Subscription {
        subscriptions.get(subId);
    };
    
    public query func getActiveSubscriptions(): async [(SubscriptionId, Subscription)] {
        let entries = Buffer.Buffer<(SubscriptionId, Subscription)>(0);
        
        for ((id, sub) in subscriptions.entries()) {
            if (sub.active) {
                entries.add((id, sub));
            };
        };
        
        Buffer.toArray(entries)
    };
    
    // Process subscriptions automatically (called by timer)
    private func processSubscriptions(): async () {
        let now = Time.now();
        log(#info, "Processing subscriptions at " # debug_show(now));
        
        for ((id, sub) in subscriptions.entries()) {
            if (sub.active and sub.nextCharge <= now) {
                // Process payment
                let patronBalance = getBalance(sub.patron);
                
                if (patronBalance >= sub.amount) {
                    // Calculate platform fee
                    let platformFee = (sub.amount * PLATFORM_FEE_PERCENT) / 100;
                    let creatorPayment = sub.amount - platformFee;
                    
                    // Deduct from patron
                    balances.put(sub.patron, patronBalance - sub.amount);
                    
                    // Credit creator
                    let creatorBalance = getBalance(sub.creator);
                    balances.put(sub.creator, creatorBalance + creatorPayment);
                    
                    // Add to treasury
                    treasuryBalance += platformFee;
                    
                    // Update next charge time
                    let updated: Subscription = {
                        sub with nextCharge = now + sub.cadence
                    };
                    subscriptions.put(id, updated);
                    
                    log(#info, "Subscription #" # debug_show(id) # " processed");
                } else {
                    // Suspend subscription if insufficient funds
                    let updated: Subscription = {
                        sub with active = false
                    };
                    subscriptions.put(id, updated);
                    log(#warning, "Subscription #" # debug_show(id) # " suspended: insufficient funds");
                };
            };
        };
    };
    
    // ========================================
    // CYCLE MANAGEMENT (Chapter 12)
    // ========================================
    
    public query func getCycleBalance(): async Nat {
        return Cycles.balance();
    };
    
    public func checkHealth(): async Text {
        let balance = Cycles.balance();
        if (balance < MINIMUM_CYCLES) {
            return "⚠️ WARNING: Low cycle balance. Refill needed!";
        } else {
            return "✅ Healthy: " # debug_show(balance) # " cycles remaining";
        };
    };
    
    public func acceptCycles(): async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        log(#info, "Accepted " # debug_show(accepted) # " cycles");
        return accepted;
    };
    
    public query func getTreasuryBalance(): async Nat {
        return treasuryBalance;
    };
    
    // ========================================
    // LOGGING & MONITORING
    // ========================================
    
    public query func getLogs(count: Nat): async [LogEntry] {
        let size = logBuffer.size();
        let start = if (size > count) { size - count } else { 0 };
        let result = Buffer.Buffer<LogEntry>(count);
        
        var i = start;
        while (i < size) {
            result.add(logBuffer.get(i));
            i += 1;
        };
        
        Buffer.toArray(result)
    };
    
    public query func getStats(): async {
        totalUsers: Nat;
        totalSubscriptions: Nat;
        activeSubscriptions: Nat;
        treasuryBalance: Nat;
        cycleBalance: Nat;
    } {
        var activeCount = 0;
        for ((_, sub) in subscriptions.entries()) {
            if (sub.active) {
                activeCount += 1;
            };
        };
        
        {
            totalUsers = users.size();
            totalSubscriptions = subscriptions.size();
            activeSubscriptions = activeCount;
            treasuryBalance = treasuryBalance;
            cycleBalance = Cycles.balance();
        }
    };
    
    // ========================================
    // LIFECYCLE HOOKS
    // ========================================
    
    system func preupgrade() {
        log(#info, "Preparing for upgrade...");
        usersEntries := Array.map<(Principal, Profile), (Principal, Profile)>(
            Array.filter<(Principal, Profile)>(
                Array.tabulate<(Principal, Profile)>(users.size(), func _ = (Principal.fromText("aaaaa-aa"), { username = ""; bio = null; role = #Patron; createdAt = 0 })),
                func _ = true
            ),
            func(entry) = entry
        );
        // Properly collect entries
        let userBuffer = Buffer.Buffer<(Principal, Profile)>(users.size());
        for ((k, v) in users.entries()) {
            userBuffer.add((k, v));
        };
        usersEntries := Buffer.toArray(userBuffer);
        
        let balanceBuffer = Buffer.Buffer<(Principal, Nat)>(balances.size());
        for ((k, v) in balances.entries()) {
            balanceBuffer.add((k, v));
        };
        balancesEntries := Buffer.toArray(balanceBuffer);
        
        let subscriptionBuffer = Buffer.Buffer<(SubscriptionId, Subscription)>(subscriptions.size());
        for ((k, v) in subscriptions.entries()) {
            subscriptionBuffer.add((k, v));
        };
        subscriptionsEntries := Buffer.toArray(subscriptionBuffer);
        
        let logArray = Buffer.toArray(logBuffer);
        logs := logArray;
    };
    
    system func postupgrade() {
        log(#info, "Upgrade complete, restoring state...");
        
        users := HashMap.fromIter<Principal, Profile>(
            usersEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        usersEntries := [];
        
        balances := HashMap.fromIter<Principal, Nat>(
            balancesEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        balancesEntries := [];
        
        subscriptions := HashMap.fromIter<SubscriptionId, Subscription>(
            subscriptionsEntries.vals(),
            10,
            Nat32.equal,
            func(n: Nat32): Nat32 { n }
        );
        subscriptionsEntries := [];
        
        for (entry in logs.vals()) {
            logBuffer.add(entry);
        };
        
        // Restart timer
        initTimer();
    };
    
    // ========================================
    // TIMER INITIALIZATION
    // ========================================
    
    private func initTimer() {
        let id = Timer.recurringTimer(
            #nanoseconds(SUBSCRIPTION_CHECK_INTERVAL), 
            processSubscriptions
        );
        timerId := ?id;
        log(#info, "Subscription timer initialized");
    };
    
    // Start timer on first deployment
    system func init() {
        log(#info, "OpenPatron initialized");
        initTimer();
    };
};

