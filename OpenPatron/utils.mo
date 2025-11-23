// OpenPatron Utility Functions
// Reusable helper functions for the platform

import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";

module {
    
    // ========================================
    // VALIDATION FUNCTIONS
    // ========================================
    
    /// Validate that a username meets requirements
    public func validateUsername(username: Text): Bool {
        let len = Text.size(username);
        if (len < 3 or len > 20) {
            return false;
        };
        
        // Check for valid characters (alphanumeric and underscore)
        for (char in Text.toIter(username)) {
            if (not (isAlphanumeric(char) or char == '_')) {
                return false;
            };
        };
        
        true
    };
    
    /// Check if a character is alphanumeric
    private func isAlphanumeric(char: Char): Bool {
        (char >= 'a' and char <= 'z') or
        (char >= 'A' and char <= 'Z') or
        (char >= '0' and char <= '9')
    };
    
    /// Validate email format (basic check)
    public func validateEmail(email: Text): Bool {
        Text.contains(email, #text "@") and
        Text.size(email) > 5 and
        Text.contains(email, #text ".")
    };
    
    /// Validate that a principal is not anonymous
    public func isValidPrincipal(p: Principal): Bool {
        not Principal.isAnonymous(p)
    };
    
    /// Validate amount is within reasonable bounds
    public func validateAmount(amount: Nat, min: Nat, max: Nat): Bool {
        amount >= min and amount <= max
    };
    
    // ========================================
    // TEXT PROCESSING
    // ========================================
    
    /// Sanitize text input by removing control characters
    public func sanitizeText(input: Text): Text {
        Text.translate(input, func(c: Char): Text {
            if (c == '\0' or c < ' ') { 
                "" 
            } else { 
                Text.fromChar(c) 
            }
        })
    };
    
    /// Truncate text to maximum length
    public func truncateText(input: Text, maxLen: Nat): Text {
        if (Text.size(input) <= maxLen) {
            return input;
        };
        
        let chars = Iter.toArray(Text.toIter(input));
        let truncated = Array.subArray(chars, 0, maxLen);
        Text.fromIter(truncated.vals())
    };
    
    // ========================================
    // PRINCIPAL UTILITIES
    // ========================================
    
    /// Convert principal to short display format
    public func principalToShortText(p: Principal): Text {
        let full = Principal.toText(p);
        if (Text.size(full) <= 12) {
            return full;
        };
        
        // Show first 5 and last 5 characters
        let chars = Iter.toArray(Text.toIter(full));
        let start = Array.subArray(chars, 0, 5);
        let end = Array.subArray(chars, Array.size(chars) - 5, 5);
        
        Text.fromIter(start.vals()) # "..." # Text.fromIter(end.vals())
    };
    
    // ========================================
    // BLOB UTILITIES
    // ========================================
    
    /// Convert Blob to hex string for display
    public func blobToHex(blob: Blob): Text {
        let bytes = Blob.toArray(blob);
        Array.foldLeft<Nat8, Text>(
            bytes,
            "",
            func(acc, byte) {
                acc # natToHex(Nat8.toNat(byte))
            }
        )
    };
    
    /// Convert single Nat to 2-character hex
    private func natToHex(n: Nat): Text {
        let hex = "0123456789abcdef";
        let high = n / 16;
        let low = n % 16;
        
        let chars = Iter.toArray(Text.toIter(hex));
        let highChar = chars[high];
        let lowChar = chars[low];
        
        Text.fromChar(highChar) # Text.fromChar(lowChar)
    };
    
    // ========================================
    // HASH UTILITIES
    // ========================================
    
    /// Hash a principal for use as HashMap key
    public func hashPrincipal(p: Principal): Hash.Hash {
        let blob = Principal.toBlob(p);
        let bytes = Blob.toArray(blob);
        
        var hash: Nat32 = 0;
        for (byte in bytes.vals()) {
            hash := hash +% Nat32.fromNat(Nat8.toNat(byte));
            hash := hash +% (hash << 10);
            hash := hash ^ (hash >> 6);
        };
        
        hash := hash +% (hash << 3);
        hash := hash ^ (hash >> 11);
        hash := hash +% (hash << 15);
        
        hash
    };
    
    /// Hash text for use as HashMap key
    public func hashText(t: Text): Hash.Hash {
        var hash: Nat32 = 0;
        for (char in Text.toIter(t)) {
            let charCode = Nat32.fromNat(Nat32.toNat(Char.toNat32(char)));
            hash := hash +% charCode;
            hash := hash +% (hash << 10);
            hash := hash ^ (hash >> 6);
        };
        
        hash := hash +% (hash << 3);
        hash := hash ^ (hash >> 11);
        hash := hash +% (hash << 15);
        
        hash
    };
    
    // ========================================
    // TIME UTILITIES
    // ========================================
    
    /// Convert nanoseconds to days
    public func nanosecondsToDays(nanos: Int): Nat {
        let nanosPerDay = 86_400_000_000_000;
        Int.abs(nanos / nanosPerDay)
    };
    
    /// Convert days to nanoseconds
    public func daysToNanoseconds(days: Nat): Int {
        let nanosPerDay = 86_400_000_000_000;
        days * nanosPerDay
    };
    
    /// Convert nanoseconds to hours
    public func nanosecondsToHours(nanos: Int): Nat {
        let nanosPerHour = 3_600_000_000_000;
        Int.abs(nanos / nanosPerHour)
    };
    
    // ========================================
    // NUMERIC UTILITIES
    // ========================================
    
    /// Calculate percentage
    public func percentage(amount: Nat, percent: Nat): Nat {
        (amount * percent) / 100
    };
    
    /// Safe division with default for division by zero
    public func safeDivide(numerator: Nat, denominator: Nat, default: Nat): Nat {
        if (denominator == 0) {
            return default;
        };
        numerator / denominator
    };
    
    /// Calculate average from array of numbers
    public func average(numbers: [Nat]): Nat {
        if (Array.size(numbers) == 0) {
            return 0;
        };
        
        var sum: Nat = 0;
        for (n in numbers.vals()) {
            sum += n;
        };
        
        sum / Array.size(numbers)
    };
    
    // ========================================
    // ARRAY UTILITIES
    // ========================================
    
    /// Check if array contains element
    public func arrayContains<T>(arr: [T], element: T, equal: (T, T) -> Bool): Bool {
        for (item in arr.vals()) {
            if (equal(item, element)) {
                return true;
            };
        };
        false
    };
    
    /// Remove element from array
    public func arrayRemove<T>(arr: [T], element: T, equal: (T, T) -> Bool): [T] {
        Array.filter<T>(arr, func(item) {
            not equal(item, element)
        })
    };
    
    /// Paginate array
    public func paginate<T>(arr: [T], page: Nat, pageSize: Nat): [T] {
        let start = page * pageSize;
        let size = Array.size(arr);
        
        if (start >= size) {
            return [];
        };
        
        let end = Nat.min(start + pageSize, size);
        Array.subArray(arr, start, end - start)
    };
};

