# uncomment if testing with Fastmail's test page or similar
# require ["variables", "body", "fileinto"];

######### Sam's Sieve rules for Customer Satisfaction Spam & SEO Spam #########
# The current logic is:
# 1. If the sender is in the allowlist, skip the rest of the rules
# 2. Check for SEO spam in contact form submissions and discard if found
# 3. Check for customer satisfaction spam using multiple matching criteria:
#    - Must match multiple patterns to reduce false positives
#    - Checks for "human" indicators to prevent filtering real emails
###################################################################

# :contains = substring match
# :matches = regex glob matching
# :comparator "i;ascii-casemap" = case insensitive

if not anyof(
    # If the sender matches any of these conditions, skip the rest of the rules
    address :matches "From" ["*@alloweddomain1.com", "*@alloweddomain2.com"]
) {
    # First check for SEO spam in contact form submissions
    if allof (
        header :contains "To" "contact-form@smcleod.net",
        anyof (
            body :contains [
                "Web Visitors Into Leads",
                "lead generation",
                "complimentary 14-day trial",
                "SMS Text With Lead",
                "privacy policy",
                "SEO",
                "terms & conditions",
                "unsubscribe.aspx",
                "leadgeneration.com"
            ]
        )
    ) {
        discard;
        stop;
    }

    # Then check for customer satisfaction spam
    # NEW: Requires matching multiple criteria to reduce false positives
    if allof(
        # CRITERIA 1: Must match common survey system indicators
        anyof(
            header :contains "Precedence" "bulk",
            header :contains "Auto-Submitted" "auto-replied",
            header :contains "X-Auto-Response-Suppress" "OOF",
            header :contains "X-Autogenerated" "yes",
            header :contains "X-Autorespond" "yes",
            header :contains "X-ME-CMCategory" "promotion",
            header :contains "X-ME-VSCategory" "commercial:mce",
            header :contains :comparator "i;ascii-casemap" "From" [
                "noreply@",
                "no-reply@",
                "feedback@",
                "survey@",
                "reviews@",
                "ratings@",
                "satisfaction@"
            ]
        ),
        
        # CRITERIA 2: Must match survey content patterns
        anyof(
            # Subject patterns
            header :contains :comparator "i;ascii-casemap" "Subject" [
                "rate your",
                "share your feedback",
                "tell us about your",
                "how was your",
                "quick survey",
                "brief survey",
                "customer satisfaction",
                "your opinion matters",
                "we value your feedback",
                "how likely are you to recommend"
            ],
            # Common survey system domains
            body :contains [
                "bazaarvoice.com",
                "delighted.com",
                "surveymonkey.com",
                "qualtrics.com",
                "typeform.com",
                "medallia.com",
                "trustpilot.com"
            ]
        ),

        # CRITERIA 3: Must NOT contain phrases suggesting human communication
        not anyof(
            body :contains [
                "I noticed",
                "I wanted to",
                "I'm reaching out",
                "I am reaching out",
                "I saw that",
                "I hope you're",
                "I hope you are",
                "Just wanted to",
                "Quick question",
                "trying to",
                "wondering if",
                "thought you might",
                "let me know if"
            ],
            # Add more human phrases above as needed
            
            # Conversation starters
            body :contains [
                "?",
                "Hi,",
                "Hey,",
                "Hello,",
                "Good morning",
                "Good afternoon"
            ]
        ),
        
        # CRITERIA 4: Must contain typical survey/rating language
        anyof(
            body :contains :comparator "i;ascii-casemap" [
                "rate your experience",
                "star rating",
                "scale of 0-10",
                "scale from 0-10",
                "net promoter score",
                "customer satisfaction survey",
                "would you recommend",
                "tell us how we did",
                "help us improve",
                "take a moment to",
                "share your thoughts",
                "leave a review",
                "write a review"
            ]
        )
    ) {
        # Move the message to "Customer Satisfaction Spam" folder
        fileinto "Customer Satisfaction Spam";
        stop;
    }
}
