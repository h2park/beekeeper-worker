class DockerHubHandler
  constructor: ({ @datastore }) ->

  do: ({ body }, callback) =>
    { push_data, repository } = body
    { tag } = push_data
    { namespace, name } = repository
    owner_name = namespace
    repo_name = name

    dockerBuild = {
      owner_name
      repo_name
      tag
      docker_url: "#{owner_name}/#{repo_name}:#{tag}"
      created_at: new Date
    }
    @datastore.update { owner_name, repo_name, tag }, { $set: dockerBuild }, { upsert: true }, (error) =>
      return callback error if error?
      callback null, dockerBuild

module.exports = DockerHubHandler
