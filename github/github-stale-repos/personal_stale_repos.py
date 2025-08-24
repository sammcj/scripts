#!/usr/bin/env python3
"""Find stale personal repositories on GitHub."""

import argparse
import json
import os
from datetime import datetime, timezone

import github3
from dateutil.parser import parse


def authenticate_to_github(token):
    """Authenticate to GitHub using a personal access token.

    Args:
        token: GitHub personal access token

    Returns:
        github3.GitHub: Authenticated GitHub connection object
    """
    if not token:
        raise ValueError("GitHub token is required")

    try:
        github_connection = github3.login(token=token)
        # Test the connection
        github_connection.me()
        return github_connection
    except Exception as e:
        raise ValueError(f"Failed to authenticate to GitHub: {e}")


def get_repo_stats(repo):
    """Get additional statistics for a repository.

    Args:
        repo: GitHub repository object

    Returns:
        dict: Repository statistics
    """
    try:
        # Get commit count (approximate from contributors API)
        commit_count = 0
        try:
            for contributor in repo.contributors():
                commit_count += contributor.contributions
        except github3.exceptions.GitHubException:
            # If contributors API fails, try commits API with a limit
            try:
                commits = list(repo.commits(number=1000))  # Limit to avoid rate limits
                commit_count = len(commits)
                if len(commits) == 1000:
                    commit_count = "1000+"
            except github3.exceptions.GitHubException:
                commit_count = "Unknown"

        return {
            'stars': repo.stargazers_count,
            'watchers': repo.watchers_count,
            'forks': repo.forks_count,
            'commits': commit_count,
            'description': repo.description or "No description",
            'language': repo.language or "Unknown",
            'size_kb': repo.size,
            'open_issues': repo.open_issues_count
        }
    except Exception as e:
        print(f"Warning: Could not get stats for {repo.name}: {e}")
        return {
            'stars': 0,
            'watchers': 0,
            'forks': 0,
            'commits': "Unknown",
            'description': "No description",
            'language': "Unknown",
            'size_kb': 0,
            'open_issues': 0
        }


def get_last_commit_date(repo):
    """Get the last commit date for a repository.

    Args:
        repo: GitHub repository object

    Returns:
        datetime or None: Last commit date
    """
    try:
        # Try pushed_at first (most reliable)
        if repo.pushed_at:
            return parse(repo.pushed_at)

        # Fallback to latest commit on default branch
        try:
            commit = repo.branch(repo.default_branch).commit
            return parse(commit.commit.as_dict()["committer"]["date"])
        except github3.exceptions.GitHubException:
            return None

    except Exception as e:
        print(f"Warning: Could not get last commit date for {repo.name}: {e}")
        return None


def find_stale_repos(github_connection, inactive_days=365, include_forks=False, exclude_archived=True):
    """Find stale personal repositories.

    Args:
        github_connection: Authenticated GitHub connection
        inactive_days: Number of days to consider a repo stale
        include_forks: Whether to include forked repositories
        exclude_archived: Whether to exclude archived repositories

    Returns:
        list: List of stale repository data
    """
    stale_repos = []

    print(f"Scanning personal repositories for inactivity over {inactive_days} days...")

    # Get all personal repositories
    repos = github_connection.repositories(type="owner")

    for repo in repos:
        # Skip archived repos if requested
        if exclude_archived and repo.archived:
            continue

        # Skip forks if requested
        if not include_forks and repo.fork:
            continue

        # Get last activity date
        last_commit_date = get_last_commit_date(repo)
        if not last_commit_date:
            print(f"Skipping {repo.name} - could not determine last commit date")
            continue

        # Calculate days inactive
        days_inactive = (datetime.now(timezone.utc) - last_commit_date).days

        if days_inactive > inactive_days:
            # Get additional repo statistics
            stats = get_repo_stats(repo)

            repo_data = {
                'name': repo.name,
                'url': repo.html_url,
                'days_inactive': days_inactive,
                'last_commit_date': last_commit_date.date().isoformat(),
                'visibility': "private" if repo.private else "public",
                'is_fork': repo.fork,
                'is_archived': repo.archived,
                **stats
            }

            stale_repos.append(repo_data)
            print(f"Found stale repo: {repo.name} ({days_inactive} days inactive)")

    # Sort by days inactive (most stale first)
    stale_repos.sort(key=lambda x: x['days_inactive'], reverse=True)

    return stale_repos


def write_markdown_report(stale_repos, inactive_days, filename="personal_stale_repos.md"):
    """Write stale repositories report to markdown file.

    Args:
        stale_repos: List of stale repository data
        inactive_days: Threshold used for staleness
        filename: Output filename
    """
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("# Personal Stale Repositories Report\n\n")
        f.write(f"Repositories with no commits in the last {inactive_days} days.\n\n")
        f.write(f"Found {len(stale_repos)} stale repositories.\n\n")

        if not stale_repos:
            f.write("No stale repositories found! 🎉\n")
            return

        # Summary table
        f.write("## Summary\n\n")
        f.write("| Repository | Days Inactive | Stars | Commits | Watchers | Description |\n")
        f.write("|------------|---------------|-------|---------|----------|-------------|\n")

        for repo in stale_repos:
            f.write(f"| [{repo['name']}]({repo['url']}) | {repo['days_inactive']} | "
                   f"{repo['stars']} | {repo['commits']} | {repo['watchers']} | "
                   f"{repo['description'][:50]}{'...' if len(repo['description']) > 50 else ''} |\n")

        # Detailed section
        f.write("\n## Detailed Information\n\n")

        for repo in stale_repos:
            f.write(f"### [{repo['name']}]({repo['url']})\n\n")
            f.write(f"- **Days Inactive:** {repo['days_inactive']}\n")
            f.write(f"- **Last Commit:** {repo['last_commit_date']}\n")
            f.write(f"- **Visibility:** {repo['visibility']}\n")
            f.write(f"- **Stars:** {repo['stars']}\n")
            f.write(f"- **Watchers:** {repo['watchers']}\n")
            f.write(f"- **Forks:** {repo['forks']}\n")
            f.write(f"- **Commits:** {repo['commits']}\n")
            f.write(f"- **Language:** {repo['language']}\n")
            f.write(f"- **Size:** {repo['size_kb']} KB\n")
            f.write(f"- **Open Issues:** {repo['open_issues']}\n")
            f.write(f"- **Is Fork:** {'Yes' if repo['is_fork'] else 'No'}\n")
            f.write(f"- **Description:** {repo['description']}\n\n")

    print(f"Report written to {filename}")


def write_json_report(stale_repos, filename="personal_stale_repos.json"):
    """Write stale repositories report to JSON file.

    Args:
        stale_repos: List of stale repository data
        filename: Output filename
    """
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(stale_repos, f, indent=2)

    print(f"JSON report written to {filename}")


def write_txt_report(stale_repos, filename="stale_repos_urls.txt"):
    """Write stale repositories URLs to a text file.

    Args:
        stale_repos: List of stale repository data
        filename: Output filename
    """
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("# Stale Repository URLs\n")
        f.write("# Remove any URLs you want to keep from this list\n")
        f.write("# Then use: python3 personal_stale_repos.py --archive-from-file stale_repos_urls.txt\n\n")
        for repo in stale_repos:
            f.write(f"{repo['url']}\n")

    print(f"TXT report written to {filename}")


def read_urls_from_file(filename):
    """Read repository URLs from a text file.

    Args:
        filename: Path to file containing URLs

    Returns:
        list: List of repository URLs (excluding comments)
    """
    urls = []
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if line and not line.startswith('#'):
                    urls.append(line)
        return urls
    except FileNotFoundError:
        raise ValueError(f"File not found: {filename}")


def archive_repositories(github_connection, repo_urls):
    """Archive repositories from a list of URLs.

    Args:
        github_connection: Authenticated GitHub connection
        repo_urls: List of repository URLs to archive

    Returns:
        tuple: (successful_count, failed_repos)
    """
    successful_count = 0
    failed_repos = []

    for url in repo_urls:
        try:
            # Extract owner/repo from URL
            parts = url.replace('https://github.com/', '').split('/')
            if len(parts) < 2:
                print(f"Invalid URL format: {url}")
                failed_repos.append((url, "Invalid URL format"))
                continue

            owner, repo_name = parts[0], parts[1]

            # Get the repository
            repo = github_connection.repository(owner, repo_name)

            # Archive the repository
            repo.edit(repo.name, archived=True)
            print(f"✓ Archived: {repo.name}")
            successful_count += 1

        except github3.exceptions.NotFoundError:
            error_msg = f"Repository not found or no access"
            print(f"✗ Failed to archive {url}: {error_msg}")
            failed_repos.append((url, error_msg))
        except github3.exceptions.GitHubException as e:
            error_msg = f"GitHub API error: {e}"
            print(f"✗ Failed to archive {url}: {error_msg}")
            failed_repos.append((url, error_msg))
        except Exception as e:
            error_msg = f"Unexpected error: {e}"
            print(f"✗ Failed to archive {url}: {error_msg}")
            failed_repos.append((url, error_msg))

    return successful_count, failed_repos


def main():
    """Main function to run the stale repo finder."""
    parser = argparse.ArgumentParser(description="Find stale personal GitHub repositories")
    parser.add_argument("--token", help="GitHub personal access token (or set GITHUB_TOKEN env var)")
    parser.add_argument("--days", type=int, default=365, help="Days of inactivity threshold (default: 365)")
    parser.add_argument("--include-forks", action="store_true", help="Include forked repositories")
    parser.add_argument("--include-archived", action="store_true", help="Include archived repositories")
    parser.add_argument("--output-format", choices=["markdown", "json", "txt", "all"], default="all",
                       help="Output format (default: all)")
    parser.add_argument("--markdown-file", default="personal_stale_repos.md", help="Markdown output filename")
    parser.add_argument("--json-file", default="personal_stale_repos.json", help="JSON output filename")
    parser.add_argument("--txt-file", default="stale_repos_urls.txt", help="TXT output filename (URLs only)")
    parser.add_argument("--archive-from-file", help="Archive repositories listed in the specified file")

    args = parser.parse_args()

    # Get GitHub token
    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("Error: GitHub token required. Use --token or set GITHUB_TOKEN environment variable.")
        print("Create a token at: https://github.com/settings/tokens")
        return 1

    try:
        # Authenticate to GitHub
        github_connection = authenticate_to_github(token)
        user = github_connection.me()
        print(f"Authenticated as: {user.login}")

        # Handle archive command
        if args.archive_from_file:
            print(f"\nReading URLs from: {args.archive_from_file}")

            # Read URLs from file
            urls = read_urls_from_file(args.archive_from_file)

            if not urls:
                print("No repository URLs found in file.")
                return 0

            print(f"\nFound {len(urls)} repositories to archive:")
            for i, url in enumerate(urls, 1):
                repo_name = url.split('/')[-1] if url else "Unknown"
                print(f"{i}. {repo_name} - {url}")

            # Confirmation prompt
            print(f"\n⚠️  WARNING: This will archive {len(urls)} repositories!")
            print("Archived repositories become read-only and cannot be pushed to.")
            print("You can unarchive them later if needed.")

            confirmation = input(f"\nAre you sure you want to archive these {len(urls)} repositories? (yes/no): ").lower().strip()

            if confirmation not in ['yes', 'y']:
                print("Archive operation cancelled.")
                return 0

            print(f"\nArchiving {len(urls)} repositories...")
            successful_count, failed_repos = archive_repositories(github_connection, urls)

            print(f"\n📊 Archive Results:")
            print(f"✓ Successfully archived: {successful_count}")
            print(f"✗ Failed: {len(failed_repos)}")

            if failed_repos:
                print(f"\nFailed repositories:")
                for url, error in failed_repos:
                    repo_name = url.split('/')[-1] if url else "Unknown"
                    print(f"- {repo_name}: {error}")

            return 0

        # Normal stale repo finding mode
        # Find stale repositories
        stale_repos = find_stale_repos(
            github_connection,
            inactive_days=args.days,
            include_forks=args.include_forks,
            exclude_archived=not args.include_archived
        )

        print(f"\nFound {len(stale_repos)} stale repositories.")

        # Generate reports
        if args.output_format in ["markdown", "all"]:
            write_markdown_report(stale_repos, args.days, args.markdown_file)

        if args.output_format in ["json", "all"]:
            write_json_report(stale_repos, args.json_file)

        if args.output_format in ["txt", "all"]:
            write_txt_report(stale_repos, args.txt_file)

        # Print top 5 stale repos
        if stale_repos:
            print(f"\nTop 5 most stale repositories:")
            for i, repo in enumerate(stale_repos[:5]):
                print(f"{i+1}. {repo['name']} - {repo['days_inactive']} days inactive ({repo['stars']} stars)")

        return 0

    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
