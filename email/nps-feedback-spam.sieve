require ["fileinto", "body", "envelope", "mailbox", "variables", "index", "regex", "relational"];

# Define any allowlist items (words, domains, email addresses) here
# This is a comma-separated list of items, and will be checked against the From address and Subject
# e.g. "allowedcontact1@example.com,@alloweddomain.com,allowedword"
# (Note - Fastmail doesn't have any extensions that provide automatic contact lookups)
set "allowlist" "";

# Define any phrases that should trigger immediate filing into the "Customer Satisfaction Spam" folder
set "immediateMatch" "How likely are you to recommend us to a friend or colleague,How would you rate the support you received";

# Define any phrases that should be considered likely to be customer satisfaction surveys
set "bodyRegexes" "how would you rate,How did we do,your feedback is important,how was the support,rate our support,rate the support,give us your feedback,tell us how we did,how satisfied were you,on a scale of 1 to ,complete our survey,customer survey,If you do not wish to participate in future surveys,Rate your experience,We'd love your feedback,We want your opinion,tell us how we did";

if not anyof(
    # Check if From address is in the allowlist
    address :matches "From" ["*${allowlist}*"],
    # Check if Subject contains words from the allowlist
    header :matches "Subject" ["*${allowlist}*"]
) {
  if anyof(
    header :matches "Subject" ["*${immediateMatch}*"],

    allof(
        # Check for matching headers often used by autoresponders and surveys
        anyof(
            header :contains "Precedence" "bulk",
            header :contains "Auto-Submitted" "auto-replied",
            header :contains "X-Auto-Response-Suppress" "OOF",
            header :contains "X-Autogenerated" "yes",
            header :contains "X-Autorespond" "yes",
            header :contains "X-Mailer" ["*survey*", "*feedback*"],
            header :contains "List-Unsubscribe" ["mailto:", "unsubscribe", "opt-out", "click here", "manage preferences", "update preferences"],
            header :matches "Subject" ["*customer survey*", "*provide feedback*", "*rate our*", "*how did we do*", "*your feedback is important*", "*Rate your experience*", "*We'd love your feedback*", "*We want your opinion*", "*tell us how we did*", "*how are we doing*"],
            header :matches "From" ["*survey*", "*feedback*"]
        ),
        # Check for matching phrases in the body
        anyof(
            body :matches ["*${bodyRegexes}*"]
        )
      )
    )
      {
        # Move the message to "Customer Satisfaction Spam" folder
        fileinto "Customer Satisfaction Spam";
    }
}
