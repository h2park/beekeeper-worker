_ = require 'lodash'

class DeploymentCreateHandler
  constructor: ({ @db }) ->
    @ciBuilds = @db['ci-builds']
    @dockerBuilds = @db['docker-builds']

  do: ({ body }, callback) =>
    { tag, owner_name, repo_name } = body
    @ciBuilds.findOne { tag, owner_name, repo_name }, { '_id': false }, (error, ciRecord) =>
      return callback error if error?
      ciRecord ?= {}
      @dockerBuilds.findOne { tag, owner_name, repo_name }, { '_id': false }, (error, dockerRecord) =>
        return callback error if error?
        dockerRecord ?= {}
        callback null, _.merge { owner_name, repo_name, tag }, ciRecord, dockerRecord

module.exports = DeploymentCreateHandler
