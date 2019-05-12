_                = require 'lodash'
UUID             = require 'uuid'
JobManagerBase   = require './base'
AWS              = require 'aws-sdk'

class JobManagerRequester extends JobManagerBase
  constructor: (options={}) ->
    super()
    {
      @jobLogSampleRate      
      @jobLogSampleRateOverrideUuids
      @responseQueueName
      @requestQueueName
    } = options
    @maxQueueLength ?= 10000
    @jobLogSampleRateOverrideUuids ?= []    

    throw new Error 'JobManagerRequester constructor is missing "jobLogSampleRate"' unless @jobLogSampleRate?
    throw new Error 'JobManagerRequester constructor is missing "requestQueueName"' unless @requestQueueName?
    throw new Error 'JobManagerRequester constructor is missing "responseQueueName"' unless @responseQueueName?      
    
    @sqs = new AWS.SQS()

  _addResponseIdToOptions: (options) =>
    { metadata } = options
    metadata = _.clone metadata
    metadata.responseId ?= @generateResponseId()
    options.metadata = metadata
    return options

  _checkMaxQueueLength: (callback) =>
    return _.defer callback      

  createForeverRequest: (options, callback) =>
    options = @_addResponseIdToOptions options
    {metadata,data,rawData} = options

    @_checkMaxQueueLength (error) =>
      return callback error if error?

      metadata.jobLogs = []
      if Math.random() < @jobLogSampleRate
        metadata.jobLogs.push 'sampled'

      uuids = [ metadata.auth?.uuid, metadata.toUuid, metadata.fromUuid, metadata.auth?.as ]
      metadata.jobLogs.push 'override' unless _.isEmpty _.intersection @jobLogSampleRateOverrideUuids, uuids

      @addMetric metadata, 'enqueueRequestAt', (error) =>
        return callback error if error?
        { responseId } = metadata
        data ?= null
        @sqs.sendMessage {QueueUrl: @requestQueueName, MessageBody: JSON.stringify {metadata,data}}, callback
    return # sqs

  createRequest: (options, callback) =>
    process.nextTick =>
      @createForeverRequest options, (error, responseId) =>
        return callback error if error?        
        callback null, responseId

    return # avoid returning redis

  do: (request, callback) =>
    callback = callback
    request = @_addResponseIdToOptions request
    responseId = _.get request, 'metadata.responseId'
    responseTimeout = null
    return _.defer(callback, new Error 'no requires metadata.responseId') unless responseId?

    @createRequest request, (error) =>
      return callback(error) if error?          
      responseTimeout = setTimeout =>
        error = new Error('Response timeout exceeded')
        error.code = 599
        @emit "response:#{responseId}", [ error, null ]
      , @jobTimeoutSeconds * 1000
    return # don't leak anything

  generateResponseId: =>
    UUID.v4()

  start: (callback=_.noop) =>
    _.defer callback

module.exports = JobManagerRequester
