{describe,context,beforeEach,afterEach,it} = global
{expect} = require 'chai'
Worker   = require '../src/worker'
Redis    = require 'ioredis'
RedisNS  = require '@octoblu/redis-ns'
mongojs  = require 'mongojs'

describe 'Worker', ->
  beforeEach (done) ->
    client = new Redis 'localhost', dropBufferSupport: true
    client.on 'ready', =>
      @redis = new RedisNS 'test-worker', client
      @redis.del 'work', done

  beforeEach (done) ->
    @db = mongojs 'test-beekeeper-worker', ['deployments', 'docker-builds', 'ci-builds']
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
        @dockerBuilds.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, result) =>
          return done error if error?
          expectedDockerBuild =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            docker_url: 'the-owner/the-service:v1.0.0'

          expect(result).to.containSubset expectedDockerBuild
          done()

      it 'should update the deployment', (done) ->
        @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, metric) =>
          return done error if error?
          expectedDeployment =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            docker_url: 'the-owner/the-service:v1.0.0'

          expect(metric).to.containSubset expectedDeployment
          done()

  describe '->do', ->
    context 'travis:ci', ->
      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
        @deployments.insert record, done

      beforeEach (done) ->
        data =
          type: 'travis:ci'
          body:
            status: 0
            branch: 'v1.0.0'
            repository:
              name: 'the-service'
              owner_name: 'the-owner'

        record = JSON.stringify data
        @redis.lpush 'work', record, done
        return # stupid promises

      beforeEach (done) ->
        @sut.do done

      it 'should create a ci build', (done) ->
        @ciBuilds.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, result) =>
          return done error if error?
          expectedCiBuild =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            ci_passing: true

          expect(result).to.containSubset expectedCiBuild
          done()

      it 'should update the deployment', (done) ->
        @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, metric) =>
          return done error if error?
          expectedDeployment =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            ci_passing: true

          expect(metric).to.containSubset expectedDeployment
          done()

  describe '->do', ->
    context 'deployment:create', ->
      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
        @deployments.insert record, done

      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
          ci_passing: true
        @ciBuilds.insert record, done

      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
          docker_url: 'the-owner/the-service:v1.0.0'

        @dockerBuilds.insert record, done

      beforeEach (done) ->
        data =
          type: 'deployment:create'
          body:
            tag: 'v1.0.0'
            owner_name: 'the-owner'
            repo_name: 'the-service'

        record = JSON.stringify data
        @redis.lpush 'work', record, done
        return # stupid promises

      beforeEach (done) ->
        @sut.do done

      it 'should update the deployment', (done) ->
        @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, metric) =>
          return done error if error?
          expectedDeployment =
            owner_name: 'the-owner'
            repo_name: 'the-service'
            tag: 'v1.0.0'
            ci_passing: true
            docker_url: 'the-owner/the-service:v1.0.0'

          expect(metric).to.containSubset expectedDeployment
          done()

  describe '->do', ->
    context 'codefresh', ->
      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
        @deployments.insert record, done

      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'
          ci_passing: false
        @ciBuilds.insert record, done

      beforeEach (done) ->
        record =
          owner_name: 'the-owner'
          repo_name: 'the-service'
          tag: 'v1.0.0'

        @dockerBuilds.insert record, done

      describe 'when ci is passing', ->
        beforeEach (done) ->
          data =
            type: 'codefresh'
            tag: 'v1.0.0'
            owner_name: 'the-owner'
            repo_name: 'the-service'
            body:
              ci_passing: true

          record = JSON.stringify data
          @redis.lpush 'work', record, done
          return # stupid promises

        beforeEach (done) ->
          @sut.do done

        it 'should update the deployment', (done) ->
          @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, metric) =>
            return done error if error?
            expectedDeployment =
              owner_name: 'the-owner'
              repo_name: 'the-service'
              tag: 'v1.0.0'
              ci_passing: true
              docker_url: 'the-owner/the-service:v1.0.0'

            expect(metric).to.containSubset expectedDeployment
            done()

      describe 'when ci is not passing', ->
        beforeEach (done) ->
          data =
            type: 'codefresh'
            tag: 'v1.0.0'
            owner_name: 'the-owner'
            repo_name: 'the-service'
            body:
              ci_passing: false

          record = JSON.stringify data
          @redis.lpush 'work', record, done
          return # stupid promises

        beforeEach (done) ->
          @sut.do done

        it 'should update the deployment', (done) ->
          @deployments.findOne owner_name: 'the-owner', repo_name: 'the-service', tag: 'v1.0.0', { '_id': false }, (error, metric) =>
            return done error if error?
            expectedDeployment =
              owner_name: 'the-owner'
              repo_name: 'the-service'
              tag: 'v1.0.0'
              docker_url: 'the-owner/the-service:v1.0.0'

            expect(metric).to.containSubset expectedDeployment
            done()
