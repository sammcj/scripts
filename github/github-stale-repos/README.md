# Personal Stale Repository Finder

A lightweight Python script to identify your personal GitHub repositories that haven't been committed to in a configurable time period. Built using patterns from the official GitHub stale-repos action.

## Features

- Finds repos you haven't committed to in X days (default: 1 year)
- Shows detailed metrics for each stale repo:
  - Stars, watchers, forks
  - Commit count (approximate)
  - Repository description
  - Language, size, open issues
  - Last commit date
  - Visibility (public/private)
- Generates Markdown, JSON, and TXT reports
- **Archive repositories directly from the command line**
- Configurable options for including forks and archived repos

## Setup

1. Create a venv:
  ```bash
  uv venv .venv
  source .venv/bin/activate
  ```
2. Install dependencies:
  ```bash
  pip install -r personal-requirements.txt
  ```
3. Create a GitHub Personal Access Token:
   - Go to https://github.com/settings/tokens
   - Create a token with `public_repo` scope (and `repo` scope if you want to scan private repos)
   - **Important**: To archive repositories, you need `repo` scope for write access

## Usage

```bash
# Using environment variable
export GITHUB_TOKEN="your_github_token_here"
python3 personal_stale_repos.py

# Or pass token directly
python3 personal_stale_repos.py --token your_github_token_here
```

```bash
# Custom inactivity threshold (e.g., 6 months)
python3 personal_stale_repos.py --days 180

# Include forked repositories
python3 personal_stale_repos.py --include-forks

# Include archived repositories
python3 personal_stale_repos.py --include-archived

# Output only TXT (URLs only)
python3 personal_stale_repos.py --output-format txt

# Custom filenames
python3 personal_stale_repos.py --markdown-file my_stale_repos.md --json-file my_stale_repos.json --txt-file my_urls.txt
```

### Archiving Repositories:

```bash
# Step 1: Generate a list of stale repo URLs
python3 personal_stale_repos.py --output-format txt

# Step 2: Edit stale_repos_urls.txt - remove any URLs you want to keep

# Step 3: Archive the remaining repositories
python3 personal_stale_repos.py --archive-from-file stale_repos_urls.txt
```

## Output

The script generates three files by default:

### Markdown Report (`personal_stale_repos.md`)
- Summary table with key metrics
- Detailed information for each repository
- Human-readable format for review

### JSON Report (`personal_stale_repos.json`)
- Machine-readable format
- All repository data in structured format
- Suitable for further processing

### TXT Report (`stale_repos_urls.txt`)
- Simple list of repository URLs
- Edit this file to remove repos you want to keep
- Use with `--archive-from-file` to archive remaining repos

## Example Output

```
Authenticated as: yourusername
Scanning personal repositories for inactivity over 365 days...
Found stale repo: old-project (732 days inactive)
Found stale repo: abandoned-tool (504 days inactive)

Found 2 stale repositories.
Report written to personal_stale_repos.md
JSON report written to personal_stale_repos.json
TXT report written to stale_repos_urls.txt

Top 5 most stale repositories:
1. old-project - 732 days inactive (15 stars)
2. abandoned-tool - 504 days inactive (3 stars)
```

### Archive Example

```
$ python3 personal_stale_repos.py --archive-from-file stale_repos_urls.txt

Reading URLs from: stale_repos_urls.txt

Found 2 repositories to archive:
1. old-project - https://github.com/username/old-project
2. test-repo - https://github.com/username/test-repo

⚠️  WARNING: This will archive 2 repositories!
Archived repositories become read-only and cannot be pushed to.
You can unarchive them later if needed.

Are you sure you want to archive these 2 repositories? (yes/no): yes

Archiving 2 repositories...
✓ Archived: old-project
✓ Archived: test-repo

📊 Archive Results:
✓ Successfully archived: 2
✗ Failed: 0
```

## Options

| Option                | Description                              | Default                   |
|-----------------------|------------------------------------------|---------------------------|
| `--days`              | Days of inactivity threshold             | 365                       |
| `--include-forks`     | Include forked repositories              | False                     |
| `--include-archived`  | Include archived repositories            | False                     |
| `--output-format`     | Output format (markdown, json, txt, all) | all                       |
| `--markdown-file`     | Markdown output filename                 | personal_stale_repos.md   |
| `--json-file`         | JSON output filename                     | personal_stale_repos.json |
| `--txt-file`          | TXT output filename (URLs only)          | stale_repos_urls.txt      |
| `--archive-from-file` | Archive repos listed in specified file   | None                      |

## Rate Limiting

The script respects GitHub API rate limits. For users with many repositories, consider:
- Running during off-peak hours
- Using a GitHub App token for higher rate limits if needed
- The script will show warnings if it encounters rate limit issues

## What Makes a Repo "Stale"?

A repository is considered stale if:
- No commits in the specified number of days (based on `pushed_at` timestamp)
- Not archived (unless `--include-archived` is used)
- Not a fork (unless `--include-forks` is used)

The script uses the same activity detection logic as the official GitHub stale-repos action.
