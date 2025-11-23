// OpenPatron Type Definitions
// Centralized type definitions for the OpenPatron platform

import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Blob "mo:base/Blob";

module {
    // ========================================
    // USER & IDENTITY TYPES
    // ========================================
    
    public type Role = {
        #Patron;    // Regular user who subscribes to creators
        #Creator;   // Content creator receiving subscriptions
        #Admin;     // Platform administrator
    };
    
    public type Profile = {
        username: Text;
        bio: ?Text;
        role: Role;
        createdAt: Time.Time;
    };
    
    // ========================================
    // SUBSCRIPTION TYPES
    // ========================================
    
    public type SubscriptionId = Nat32;
    public type Timestamp = Int;
    
    public type Subscription = {
        patron: Principal;
        creator: Principal;
        cadence: Int;          // nanoseconds between invoices
        nextCharge: Timestamp;
        amount: Nat;
        active: Bool;
    };
    
    public type SubscriptionStatus = {
        #Active;
        #Paused;
        #Cancelled;
        #Suspended;  // Due to insufficient funds
    };
    
    // ========================================
    // LEDGER & PAYMENT TYPES (ICRC-1)
    // ========================================
    
    public type Account = { 
        owner: Principal; 
        subaccount: ?Blob 
    };
    
    public type Subaccount = Blob;
    
    public type TransferArgs = {
        to: Account;
        fee: ?Nat;
        memo: ?Blob;
        from_subaccount: ?Blob;
        created_at_time: ?Nat64;
        amount: Nat;
    };
    
    public type TransferResult = { 
        #Ok: Nat; 
        #Err: TransferError 
    };
    
    public type TransferError = {
        #BadFee: { expected_fee: Nat };
        #BadBurn: { min_burn_amount: Nat };
        #InsufficientFunds: { balance: Nat };
        #TooOld;
        #CreatedInFuture: { ledger_time: Nat64 };
        #TemporarilyUnavailable;
        #Duplicate: { duplicate_of: Nat };
        #GenericError: { error_code: Nat; message: Text };
    };
    
    // ========================================
    // LOGGING TYPES
    // ========================================
    
    public type LogLevel = { 
        #info; 
        #warning; 
        #error;
        #debug; 
    };
    
    public type LogEntry = {
        timestamp: Time.Time;
        level: LogLevel;
        message: Text;
    };
    
    // ========================================
    // ANALYTICS TYPES
    // ========================================
    
    public type PlatformStats = {
        totalUsers: Nat;
        totalCreators: Nat;
        totalPatrons: Nat;
        totalSubscriptions: Nat;
        activeSubscriptions: Nat;
        totalRevenue: Nat;
        treasuryBalance: Nat;
        cycleBalance: Nat;
    };
    
    public type UserStats = {
        subscriptionsCreated: Nat;
        totalSpent: Nat;
        activeSubscriptions: Nat;
    };
    
    public type CreatorStats = {
        subscribers: Nat;
        monthlyRevenue: Nat;
        totalEarned: Nat;
        availableBalance: Nat;
    };
    
    // ========================================
    // ERROR TYPES
    // ========================================
    
    public type ErrorCode = {
        #NotAuthenticated;
        #NotAuthorized;
        #NotFound;
        #AlreadyExists;
        #InsufficientFunds;
        #InvalidInput;
        #InternalError;
    };
    
    public type ApiError = {
        code: ErrorCode;
        message: Text;
    };
};

