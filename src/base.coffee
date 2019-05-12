_                = require 'lodash'
moment           = require 'moment'
{ EventEmitter } = require 'events'

class JobManagerBase extends EventEmitter
  constructor: (options={}) ->
    super()    
    @_heartbeat = moment()
    
  addMetric: (metadata, metricName, callback) =>
    return _.defer callback if _.isEmpty metadata.jobLogs
    metadata.metrics ?= {}
    metadata.metrics[metricName] = Date.now()
    _.defer callback

  
  healthcheck: (callback) =>
    healthy = @_heartbeat.isAfter moment().subtract @jobTimeoutSeconds * 2, 'seconds'
    _.defer callback, null, healthy

  _updateHeartbeat: =>
    @_heartbeat = moment()

module.exports = JobManagerBase
