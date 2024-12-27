# uncomment if testing with Fastmail's test page or similar
# require ["variables", "body", "fileinto"];

######### Sam's Sieve rules for Customer Satisfaction Spam & SEO Spam #########
# The current logic is:
# 1. If the sender is in the allowlist, skip the rest of the rules
# 2. Check for SEO spam in contact form submissions and discard if found
# 3. Check for customer satisfaction spam patterns and move to folder if found
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
                "found your site",
                "complimentary 14-day trial",
                "SMS Text With Lead",
                "privacy policy",
                "terms & conditions",
                "unsubscribe.aspx",
                "leadgeneration.com",
                "my name is",
                "my name's",
                "just found your site"
            ]
        )
    ) {
        discard;
        stop;
    }

    # Then check for customer satisfaction spam
    if anyof(
        # If the message matches ANY of the following header subjects, move it immediately
        header :contains :comparator "i;ascii-casemap" "Subject" [
            "How would you rate the support you received",
            "What do you think about your store experience",
            "What do you think about your purchase products",
            "Take a few minutes to share your feedback",
            "We value your feedback",
            "Your feedback is important",
            "We would love your feedback",
            "Rate your purchases",
            "Rate your other purchases",
            "How likely are you to recommend"
        ],
        header :matches :comparator "i;ascii-casemap" "Subject" [
            "*We?d love to hear how your*",
            "*Help us*improve by rating*"
        ],

        allof(
            # or, if the message matches any these header and subject conditions - AND - any of the body conditions in the next section
            anyof(
                header :contains "Precedence" "bulk",
                header :contains "Auto-Submitted" "auto-replied",
                header :contains "X-Auto-Response-Suppress" "OOF",
                header :contains "X-Autogenerated" "yes",
                header :contains "X-Autorespond" "yes",
                header :contains "X-ME-CMCategory" "promotion",
                header :contains "X-ME-VSCategory" "commercial:mce",
                header :contains "X-Mailer" [
                    "survey",
                    "feedback"
                ],
                header :contains :comparator "i;ascii-casemap" "From" [
                    "survey",
                    "feedback"
                ],
                header :contains :comparator "i;ascii-casemap" "List-Unsubscribe" [
                    "mailto:",
                    "unsubscribe",
                    "opt-out",
                    "click here",
                    "manage preferences",
                    "update preferences"
                ]
            ),
            # and again - this time in the subject
            anyof(
                header :contains :comparator "i;ascii-casemap" "Subject" [
                    "Are you happy with the response you",
                    "Are you happy with the service you",
                    "Are you happy with the support you",
                    "Click below to rate",
                    "Complete our survey",
                    "customer feedback",
                    "customer survey",
                    "Did I solve your problem",
                    "Did your recent purchase go well?",
                    "give us 5 stars",
                    "give us your feedback",
                    "how are we doing",
                    "How did we do",
                    "How likely are you to recommend",
                    "How likely would you be to recommend",
                    "how satisfied were you",
                    "how was the support",
                    "How would you rate",
                    "If you do not wish to participate in",
                    "Please rate our support",
                    "provide feedback",
                    "Rate your experience",
                    "share your feedback",
                    "tell us how we did",
                    "We want your opinion",
                    "We'd love your feedback",
                    "What do you think of your purchase",
                    "your feedback is important",
                    "We value your feedback",
                    "Rate your other purchases",
                    "Rate your purchases",
                    "bazaarvoice.com"
                ],
                header :matches :comparator "i;ascii-casemap" "Subject" [
                    "*Are you happy with the * you * \?*",
                    "*rate ??? support*",
                    "*Help us*improve by rating*",
                    "*Did * solve your problem*"
                ]
            ),
            # and again - this time in the body
            anyof(
                body :contains :comparator "i;ascii-casemap" [
                    "Click below to rate",
                    "Complete our survey",
                    "customer feedback",
                    "customer survey",
                    "give us 5 stars",
                    "give us your feedback",
                    "how are we doing",
                    "How did we do",
                    "How likely are you to recommend",
                    "How likely would you be to recommend",
                    "how satisfied were you",
                    "how was the support",
                    "How would you rate",
                    "If you do not wish to participate in",
                    "Please rate our support",
                    "provide feedback",
                    "Rate your experience",
                    "share your feedback",
                    "tell us how we did",
                    "We want your opinion",
                    "We'd love your feedback",
                    "We would love your feedback",
                    "What do you think of your purchase",
                    "Did your recent purchase go well?",
                    "your feedback is important",
                    "We value your feedback",
                    "Rate your other purchases",
                    "Rate your purchases",
                    "bazaarvoice.com"
                ],
                body :matches :comparator "i;ascii-casemap" [
                    "*Are you happy with the * you * \?*",
                    "*rate ??? support*",
                    "*Help us*improve by rating*",
                    "*Did * solve your problem*",
                    "*We would love your feedback*"
                ]
            )
        )
    ) {
        # Move the message to "Customer Satisfaction Spam" folder
        fileinto "Customer Satisfaction Spam";
        stop;
    }
}
