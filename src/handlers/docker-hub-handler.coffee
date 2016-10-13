class DockerHubHandler
  constructor: ({ @db }) ->
    @datastore = @db['docker-builds']

  do: ({ body }, callback) =>
    { push_data, repository } = body
    { tag } = push_data
    { namespace, name } = repository
    owner_name = namespace
    repo_name = name

    build = {
      owner_name
      repo_name
      tag
      docker_url: "#{owner_name}/#{repo_name}:#{tag}"
      created_at: new Date
    }
    @datastore.update { owner_name, repo_name, tag }, { $set: build }, { upsert: true }, (error) =>
      return callback error if error?
      callback null, build

module.exports = DockerHubHandler
