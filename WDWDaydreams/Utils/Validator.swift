import Foundation

/// Custom validation errors
enum ValidationError: Error, LocalizedError {
    case invalidDisplayName
    case displayNameTooShort
    case displayNameTooLong
    case noAlphanumeric
    case invalidEmail
    case passwordTooWeak
    case storyTooLong
    case storyEmpty
    case invalidInvitationCode
    case invalidInput
    case containsProfanity
    case containsSpam
    case containsPersonalInfo
    case excessiveRepetition

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "Display name must contain valid characters"
        case .displayNameTooShort:
            return "Display name must be at least 2 characters"
        case .displayNameTooLong:
            return "Display name must be 50 characters or less"
        case .noAlphanumeric:
            return "Display name must contain at least one letter or number"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .passwordTooWeak:
            return "Password must be at least 8 characters with uppercase, lowercase, and number"
        case .storyTooLong:
            return "Story text must be 10,000 characters or less"
        case .storyEmpty:
            return "Story text cannot be empty"
        case .invalidInvitationCode:
            return "Invitation code must be exactly 6 alphanumeric characters"
        case .invalidInput:
            return "Invalid input provided"
        case .containsProfanity:
            return "Text contains inappropriate content"
        case .containsSpam:
            return "Text appears to contain spam or excessive promotional content"
        case .containsPersonalInfo:
            return "Please do not share personal information like phone numbers or addresses"
        case .excessiveRepetition:
            return "Text contains excessive repetition"
        }
    }
}

/// Input validation and sanitization utility
struct Validator {

    // MARK: - Display Name Validation

    /// Validates and sanitizes display names
    /// - Parameter name: The display name to validate
    /// - Returns: Trimmed and validated display name
    /// - Throws: ValidationError if validation fails
    static func validateDisplayName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check minimum length
        guard trimmed.count >= 2 else {
            throw ValidationError.displayNameTooShort
        }

        // Check maximum length
        guard trimmed.count <= 50 else {
            throw ValidationError.displayNameTooLong
        }

        // Must contain at least one alphanumeric character
        guard trimmed.rangeOfCharacter(from: .alphanumerics) != nil else {
            throw ValidationError.noAlphanumeric
        }

        // Check for valid characters (alphanumeric, spaces, hyphens, apostrophes)
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))

        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            throw ValidationError.invalidDisplayName
        }

        // Basic profanity check (expandable)
        try checkForProfanity(trimmed)

        return trimmed
    }

    // MARK: - Email Validation

    /// Validates email format
    /// - Parameter email: The email address to validate
    /// - Returns: Trimmed and lowercased email
    /// - Throws: ValidationError if validation fails
    static func validateEmail(_ email: String) throws -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Basic email regex pattern
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmed) else {
            throw ValidationError.invalidEmail
        }

        return trimmed
    }

    // MARK: - Password Validation

    /// Validates password strength
    /// - Parameter password: The password to validate
    /// - Returns: The validated password
    /// - Throws: ValidationError if validation fails
    static func validatePassword(_ password: String) throws -> String {
        // Minimum 8 characters
        guard password.count >= 8 else {
            throw ValidationError.passwordTooWeak
        }

        // Must contain uppercase
        guard password.rangeOfCharacter(from: .uppercaseLetters) != nil else {
            throw ValidationError.passwordTooWeak
        }

        // Must contain lowercase
        guard password.rangeOfCharacter(from: .lowercaseLetters) != nil else {
            throw ValidationError.passwordTooWeak
        }

        // Must contain number
        guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
            throw ValidationError.passwordTooWeak
        }

        return password
    }

    // MARK: - Story Text Validation

    /// Validates and sanitizes story text
    /// - Parameter text: The story text to validate
    /// - Returns: Trimmed story text
    /// - Throws: ValidationError if validation fails
    static func validateStoryText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check not empty
        guard !trimmed.isEmpty else {
            throw ValidationError.storyEmpty
        }

        // Check maximum length (10,000 characters)
        guard trimmed.count <= 10000 else {
            throw ValidationError.storyTooLong
        }

        // Content moderation checks
        try checkForProfanity(trimmed)
        try checkForSpam(trimmed)
        try checkForPersonalInfo(trimmed)
        try checkForExcessiveRepetition(trimmed)

        // Sanitize potential XSS/injection attempts
        let sanitized = sanitizeText(trimmed)

        return sanitized
    }

    // MARK: - Invitation Code Validation

    /// Validates and sanitizes invitation codes
    /// - Parameter code: The invitation code to validate
    /// - Returns: Uppercase, trimmed invitation code
    /// - Throws: ValidationError if validation fails
    static func validateInvitationCode(_ code: String) throws -> String {
        let cleaned = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Must be exactly 6 characters
        guard cleaned.count == 6 else {
            throw ValidationError.invalidInvitationCode
        }

        // Must contain only alphanumeric characters
        guard cleaned.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw ValidationError.invalidInvitationCode
        }

        return cleaned
    }

    // MARK: - Bio Validation

    /// Validates user bio text
    /// - Parameter bio: The bio text to validate
    /// - Returns: Trimmed bio text
    /// - Throws: ValidationError if validation fails
    static func validateBio(_ bio: String) throws -> String {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        // Maximum 500 characters for bio
        guard trimmed.count <= 500 else {
            throw ValidationError.invalidInput
        }

        // Sanitize text
        let sanitized = sanitizeText(trimmed)

        return sanitized
    }

    // MARK: - Helper Methods

    /// Sanitizes text to prevent XSS and injection attacks
    /// - Parameter text: The text to sanitize
    /// - Returns: Sanitized text
    private static func sanitizeText(_ text: String) -> String {
        // Remove potential HTML/script tags
        var sanitized = text

        // Replace < and > to prevent HTML injection
        sanitized = sanitized.replacingOccurrences(of: "<", with: "")
        sanitized = sanitized.replacingOccurrences(of: ">", with: "")

        // Remove zero-width characters and other invisible Unicode
        let invisibleCharacters = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        sanitized = sanitized.components(separatedBy: invisibleCharacters).joined()

        return sanitized
    }

    // MARK: - Content Moderation

    /// Enhanced profanity and inappropriate content filter
    /// - Parameter text: Text to check
    /// - Throws: ValidationError.containsProfanity if profanity detected
    private static func checkForProfanity(_ text: String) throws {
        // Comprehensive profanity list covering common inappropriate terms
        // Note: This is a basic implementation. For production, consider using
        // a third-party service like Google Cloud Natural Language API,
        // AWS Comprehend, or OpenAI Moderation API for more robust filtering
        let profanityList = [
            // Common profanity (partial list for demonstration)
            "damn", "hell", "crap", "piss", "bastard",
            // Slurs and hate speech indicators
            "hate", "kill", "die", "death",
            // Sexual content
            "sex", "porn", "xxx", "nude",
            // Add more terms as needed, including leetspeak variants
            "d4mn", "h3ll", "k1ll", "d1e"
        ]

        // Normalize text for checking (lowercase, remove special chars for leetspeak)
        let normalized = normalizeForModeration(text)

        for word in profanityList {
            // Check for whole word matches to avoid false positives
            let pattern = "\\b\(word)\\b"
            if normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                throw ValidationError.containsProfanity
            }
        }
    }

    /// Check for spam patterns
    /// - Parameter text: Text to check
    /// - Throws: ValidationError.containsSpam if spam detected
    private static func checkForSpam(_ text: String) throws {
        let lowercased = text.lowercased()

        // Check for excessive URLs
        let urlPattern = "(https?://|www\\.)"
        let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive)
        let urlMatches = urlRegex?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0

        // More than 3 URLs is suspicious
        if urlMatches > 3 {
            throw ValidationError.containsSpam
        }

        // Check for spam keywords
        let spamKeywords = [
            "click here", "buy now", "limited time", "act now",
            "free money", "earn cash", "work from home",
            "lose weight", "get rich", "subscribe",
            "follow me", "check out my", "visit my"
        ]

        for keyword in spamKeywords {
            if lowercased.contains(keyword) {
                throw ValidationError.containsSpam
            }
        }

        // Check for excessive capitalization (>30% caps is suspicious)
        let uppercaseCount = text.filter { $0.isUppercase }.count
        let letterCount = text.filter { $0.isLetter }.count
        if letterCount > 0 && Double(uppercaseCount) / Double(letterCount) > 0.3 {
            throw ValidationError.containsSpam
        }
    }

    /// Check for personal information (PII)
    /// - Parameter text: Text to check
    /// - Throws: ValidationError.containsPersonalInfo if PII detected
    private static func checkForPersonalInfo(_ text: String) throws {
        // Phone number patterns
        let phonePattern = "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b|\\(\\d{3}\\)\\s*\\d{3}[-.]?\\d{4}"
        if text.range(of: phonePattern, options: .regularExpression) != nil {
            throw ValidationError.containsPersonalInfo
        }

        // Email pattern (outside of proper email fields)
        let emailPattern = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
        if text.range(of: emailPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            throw ValidationError.containsPersonalInfo
        }

        // Address patterns (basic check for numbers + street types)
        let addressPattern = "\\b\\d+\\s+(st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|ct|court)\\b"
        if text.range(of: addressPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            throw ValidationError.containsPersonalInfo
        }

        // Social Security Number pattern
        let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        if text.range(of: ssnPattern, options: .regularExpression) != nil {
            throw ValidationError.containsPersonalInfo
        }
    }

    /// Check for excessive character repetition
    /// - Parameter text: Text to check
    /// - Throws: ValidationError.excessiveRepetition if excessive repetition detected
    private static func checkForExcessiveRepetition(_ text: String) throws {
        // Check for same character repeated >10 times
        let charRepeatPattern = "(.)\\1{10,}"
        if text.range(of: charRepeatPattern, options: .regularExpression) != nil {
            throw ValidationError.excessiveRepetition
        }

        // Check for same word repeated >5 times consecutively
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var consecutiveCount = 1
        var previousWord = ""

        for word in words where !word.isEmpty {
            let normalized = word.lowercased()
            if normalized == previousWord {
                consecutiveCount += 1
                if consecutiveCount > 5 {
                    throw ValidationError.excessiveRepetition
                }
            } else {
                consecutiveCount = 1
                previousWord = normalized
            }
        }
    }

    /// Normalize text for moderation checking
    /// Handles leetspeak and special character substitutions
    /// - Parameter text: Text to normalize
    /// - Returns: Normalized text
    private static func normalizeForModeration(_ text: String) -> String {
        var normalized = text.lowercased()

        // Common leetspeak substitutions
        let substitutions: [String: String] = [
            "0": "o",
            "1": "i",
            "3": "e",
            "4": "a",
            "5": "s",
            "7": "t",
            "@": "a",
            "$": "s",
            "!": "i"
        ]

        for (leet, normal) in substitutions {
            normalized = normalized.replacingOccurrences(of: leet, with: normal)
        }

        return normalized
    }

    /// Validates that a string is not empty after trimming
    /// - Parameter text: Text to validate
    /// - Returns: Trimmed text
    /// - Throws: ValidationError.invalidInput if empty
    static func validateNotEmpty(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.invalidInput
        }
        return trimmed
    }
}