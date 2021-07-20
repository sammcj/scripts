// Reads from an SNS topic and POSTs to a HTTP API.
//
// - Requires an IAM policy to allow Subscribe access to the source SNS Topic.
// - Expect environment variables HTTP_HOST (example.com), HTTP_PORT (80) and HTTP_PATH (/api)
//
// Example output:
// {
//   "url": "example.com",      
//   "path": "/apifunction",
//   "body": { "data": "your data"} 
// }

var querystring = require('querystring');
var http = require('http');

let host = process.env.HTTP_HOST;
let port = process.env.HTTP_PORT;
let path = process.env.HTTP_PATH;

exports.handler = function(event, context) {
  var message = event.Records[0].Sns.Message;
  var post_data = querystring.stringify(
    message
  );

  console.log('Message received from SNS:', message);

   // An object of options to indicate where to post to
   var post_options = {
    host: host,
    port: port,
    path: path,
    method: 'POST',
    headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(post_data)
    }
  };

  // Set up the request
  var post_req = http.request(post_options, function(res) {
    res.setEncoding('utf8');
    res.on('data', function (chunk) {
        console.log('Response: ' + chunk);
        context.succeed();
    });
    res.on('error', function (e) {
      console.log("Got error: " + e.message);
      context.done(null, 'FAILURE');
    });

  });

  // post the data
  post_req.write(post_data);
  post_req.end();
};

