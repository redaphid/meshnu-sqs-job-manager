JobManager = require '../src/requester'
AWS = require 'aws-sdk'

sqs = new AWS.SQS()
sqs.getQueueUrl {QueueName: "meshnu-dispatcher-in"}, (error, response) =>
  return console.log error.message if error?
  
  console.log response
  job =
    metadata:
      runtime:'meatadata'
    data: 
      uuid: "Aaron"
      says: "hi"

  jobManager = new JobManager 
    jobLogSampleRate: 0
    jobLogSampleRateOverrideUuids: []
    responseQueueName: "doesnt-exist"
    requestQueueName: response.QueueUrl
    
  jobManager.do job, (error, jobResponse) =>
    console.log('done')
    console.log(error?.message)
    console.log({job, jobResponse})
