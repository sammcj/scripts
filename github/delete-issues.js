// set const for @octokit/graphql and @octokit/rest
const { graphql } = require('@octokit/graphql')
const { Octokit } = require('@octokit/rest')

const GITHUB_TOKEN = process.env.GITHUB_TOKEN

const octokit = new Octokit({ auth: GITHUB_TOKEN })

const data1 = await octokit.request('GET /repos/{owner}/{repo}/issues', {
  owner: 'user',
  repo: 'repo',
  per_page: 100,
})

for (let issue of data1.data) {
  console.log('deleting issue ' + issue.title)
  await graphql(
    `

                mutation {
                    deleteIssue(input: { issueId: "${issue.node_id}" }) {
                        repository {
                            name
                        }
                    }
                }

        `,
    {
      headers: {
        authorization: 'token ' + GITHUB_TOKEN,
      },
    },
  )
}
