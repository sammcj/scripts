// Reads from an SNS topic and forwards the message to another.
//
// - Requires an IAM policy to allow Subscribe access to the source SNS Topic.
// - Requires an IAM policy to allow Publish to the destination Topic.
//

var AWS = require("aws-sdk");
let publishARN = process.env.publishARN

exports.handler = function(event, context) {
  var message = event.Records[0].Sns.Message;
  console.log('Message received from SNS:', message);

  var sns = new AWS.SNS();
  var params = {
      Message: message, 
      Subject: 'Forwarding SNS via Lambda:',
      TopicArn: publishARN
  };
  sns.publish(params, context.done);
};

