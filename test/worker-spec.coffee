Worker  = require '../src/worker'
Redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
mongojs = require 'mongojs'

describe 'Worker', ->
  beforeEach (done) ->
    client = new Redis 'localhost', dropBufferSupport: true
    client.on 'ready', =>
      @redis = new RedisNS 'test-worker', client
      @redis.del 'work', done

  beforeEach (done) ->
    @db = mongojs 'localhost', ['deployments', 'docker-builds', 'ci-builds']
    @deployments = @db.deployments
    @deployments.remove done

  beforeEach (done) ->
    @ciBuilds = @db['ci-builds']
    @ciBuilds.remove done

  beforeEach (done) ->
    @dockerBuilds = @db['docker-builds']
    @dockerBuilds.remove done

  beforeEach ->
    queueName = 'work'
    queueTimeout = 1
    @sut = new Worker { @db, @redis, queueName, queueTimeout }

  afterEach (done) ->
    @sut.stop done

  describe '->do', ->
    context 'docker:hub', ->
      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
        @deployments.insert record, done

      beforeEach (done) ->
        data =
          type: 'docker:hub'
          body:
            push_data:
              tag: "v1.0.0"
            repository:
              name: 'the-service'
              namespace: 'the-owner'
              repo_name: 'the-owner/the-service'

        record = JSON.stringify data
        @redis.lpush 'work', record, done
        return # stupid promises

      beforeEach (done) ->
        @sut.do done

      it 'should create a docker build', (done) ->
        @dockerBuilds.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', (error, result) =>
          return done error if error?
          expectedDockerBuild =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            docker_url: 'the-owner/the-service:v1.0.0'

          expect(result).to.containSubset expectedDockerBuild
          done()

      it 'should update the deployment', (done) ->
        @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', (error, metric) =>
          return done error if error?
          expectedDeployment =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            docker_url: 'the-owner/the-service:v1.0.0'

          expect(metric).to.containSubset expectedDeployment
          done()
