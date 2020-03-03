const {HelloRequest, RepeatHelloRequest, HelloResponse} = require('./build/emoji_pb.js');
const {GreeterClient} = require('./build/emoji_grpc_web_pb.js');

// NOTE: no ending /
// use $INGRESS_HOST:$INGRESS_PORT from https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/
// var client = new GreeterClient('http://192.168.99.124:30209');
var client = new GreeterClient(window.location.protocol + '//' + window.location.host, null, {
  'withCredentials': true
});

var editor = document.getElementById('editor');

window.insertEmojis = function() {
  var request = new HelloRequest();
  request.setName(editor.innerText);

  // deadline exceeded
  var deadline = new Date();
  deadline.setSeconds(deadline.getSeconds() + 5);

  client.sayHello(request, {deadline: deadline.getTime()}, (err, response) => {
    if(err) {
      console.log('Got error, code = ' + err.code +
                  ', message = ' + err.message);
    }
    editor.innerText = response.getMessage();
    window.focusEditor();
  });
};

window.focusEditor = function() {
  editor.focus();
  var range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  var sel = window.getSelection();
  sel.removeAllRanges();
  sel.addRange(range);
};

window.focusEditor();
