async              = require 'async'
DockerHubHandler   = require './handlers/docker-hub-handler'
TravisCIHandler   = require './handlers/travis-ci-handler'

class Worker
  constructor: (options={})->
    { @db, @redis, @queueName, @queueTimeout } = options
    throw new Error('Worker: requires redis') unless @redis?
    throw new Error('Worker: requires queueName') unless @queueName?
    throw new Error('Worker: requires queueTimeout') unless @queueTimeout?
    @shouldStop = false
    @isStopped = false
    @datastore = @db.deployments
    @handlers =
      'docker:hub': new DockerHubHandler datastore: @db['docker-builds']
      'travis:ci': new TravisCIHandler datastore: @db['ci-builds']

  do: (callback) =>
    @redis.brpop @queueName, @queueTimeout, (error, result) =>
      return callback error if error?
      return callback() unless result?

      [ queue, data ] = result
      try
        data = JSON.parse data
      catch error
        return callback error

      @_process data, (error) =>
        console.log error.stack if error?
        callback()

    return # avoid returning promise

  run: =>
    async.doUntil @do, (=> @shouldStop), =>
      @isStopped = true

  stop: (callback) =>
    @shouldStop = true

    timeout = setTimeout =>
      clearInterval interval
      callback new Error 'Stop Timeout Expired'
    , 5000

    interval = setInterval =>
      return unless @isStopped?
      clearInterval interval
      clearTimeout timeout
      callback()
    , 250

  _process: (data, callback) =>
    {
      type
      owner_name
      repo_name
      body
    } = data

    handler = @handlers[type]
    unless handler?
      console.error "No Handler Available: #{type}"
      return callback()

    handler.do { owner_name, repo_name, body }, (error, deployment) =>
      return callback error if error?
      { owner_name, repo_name, tag } = deployment
      dasherized_type = type.replace '.', '-'
      deployment["updated_at.#{dasherized_type}"] = new Date

      @datastore.update { owner_name, repo_name, tag }, { $set: deployment }, (error) =>
        return callback error if error?
        callback null, data

module.exports = Worker
