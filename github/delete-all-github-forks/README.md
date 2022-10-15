# Delete GitHub Forks

Clone this repository.

```
$ npm install
$ cp src/config.json.example src/config.json
```

Add your GitHub username and access token to `config.json` and fetch all your forked repositories.

```sh
$ cd src
$ node fetch-repos.js # Writes to a repos.json file.
```

A JSON file, `repos.json` containing an array of your repositories will be written into the same directory. Manually inspect it and remove the forked repositories that you want to keep.

**The repositories that remain inside `repos.json` will be deleted irreversibly!**.

```sh
$ node delete-repos.js # Reads from repos.json and deletes the repos inside it.
```
