_ = require 'lodash'

class CodefreshHandler
  constructor: ({ @db }) ->
    @ciBuilds = @db['ci-builds']
    @dockerBuilds = @db['docker-builds']

  do: ({ owner_name, repo_name, body }, callback) =>
    tag =_.get body, 'tag'
    return callback null unless tag?
    @_updateCiBuild { owner_name, repo_name, tag, body }, (error, ciRecord={}) =>
      return callback error if error?
      @_updateDockerBuild { owner_name, repo_name, tag }, (error, dockerRecord={}) =>
        return callback error if error?
        callback null, _.merge { owner_name, repo_name }, ciRecord, dockerRecord

  _updateCiBuild: ({ owner_name, repo_name, body, tag }, callback) =>
    ci_passing =_.get body, 'ci_passing', false
    return callback null unless ci_passing
    build = {
      owner_name
      repo_name
      tag
      ci_passing: true
      created_at: new Date
    }
    @dockerBuilds.update { owner_name, repo_name, tag }, { $set: build }, { upsert: true }, (error) =>
      return callback error if error?
      callback null, build

  _updateDockerBuild: ({ owner_name, repo_name, tag }, callback) =>
    build = {
      owner_name
      repo_name
      tag
      docker_url: "#{owner_name}/#{repo_name}:#{tag}"
      created_at: new Date
    }
    @dockerBuilds.update { owner_name, repo_name, tag }, { $set: build }, { upsert: true }, (error) =>
      return callback error if error?
      callback null, build

module.exports = CodefreshHandler
