class TravisCIHandler
  constructor: ({ @db }) ->
    @datastore = @db['ci-builds']

  do: ({ body }, callback) =>
    { status, branch, repository } = body
    { name, owner_name } = repository
    tag = branch
    repo_name = name

    ci_passing = status == 0

    build = {
      owner_name
      repo_name
      tag
      ci_passing
      created_at: new Date
    }
    @datastore.update { owner_name, repo_name, tag }, { $set: build }, { upsert: true }, (error) =>
      return callback error if error?
      callback null, build

module.exports = TravisCIHandler
